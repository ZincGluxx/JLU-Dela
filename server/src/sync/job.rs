use serde::Serialize;
use serde_json::Value;
use sha2::{Digest, Sha256};
use sqlx::{AssertSqlSafe, PgPool};
use time::{OffsetDateTime, format_description::well_known::Rfc3339};
use uuid::Uuid;

use crate::{error::AppError, sync::registry::SyncOutcome};

const COLUMNS: &str = "id, source, resource, scope, status, attempts, error_code, error_retryable, complete, snapshot_version, created_at, started_at, finished_at, updated_at";

#[derive(Debug, sqlx::FromRow)]
pub struct JobRow {
    pub id: Uuid,
    pub source: String,
    pub resource: String,
    pub scope: Value,
    pub status: String,
    pub attempts: i32,
    pub error_code: Option<String>,
    pub error_retryable: Option<bool>,
    pub complete: Option<bool>,
    pub snapshot_version: Option<i64>,
    pub created_at: OffsetDateTime,
    pub started_at: Option<OffsetDateTime>,
    pub finished_at: Option<OffsetDateTime>,
    pub updated_at: OffsetDateTime,
}

#[derive(Debug, Serialize)]
pub struct JobData {
    pub id: String,
    pub source: String,
    pub resource: String,
    pub scope: Value,
    pub status: String,
    pub attempts: i32,
    pub created_at: String,
    pub started_at: Option<String>,
    pub finished_at: Option<String>,
    pub updated_at: String,
    pub error: Option<JobError>,
    pub complete: Option<bool>,
    pub snapshot_version: Option<i64>,
}

#[derive(Debug, Serialize)]
pub struct JobError {
    pub code: String,
    pub retryable: bool,
}

#[derive(Debug, Serialize)]
pub struct AcceptedJob {
    #[serde(flatten)]
    pub job: JobData,
    pub reused: bool,
}

pub struct CreatedJob {
    pub job: JobRow,
    pub reused: bool,
}

impl From<JobRow> for JobData {
    fn from(row: JobRow) -> Self {
        Self {
            id: row.id.to_string(),
            source: row.source,
            resource: row.resource,
            scope: row.scope,
            status: row.status,
            attempts: row.attempts,
            created_at: timestamp(row.created_at),
            started_at: row.started_at.map(timestamp),
            finished_at: row.finished_at.map(timestamp),
            updated_at: timestamp(row.updated_at),
            error: row.error_code.map(|code| JobError {
                code,
                retryable: row.error_retryable.unwrap_or(false),
            }),
            complete: row.complete,
            snapshot_version: row.snapshot_version,
        }
    }
}

pub async fn create(
    pool: &PgPool,
    user_id: Uuid,
    source: &str,
    resource: &str,
    scope: Value,
) -> Result<CreatedJob, AppError> {
    let scope_key = scope_key(&scope);

    for _ in 0..2 {
        let insert_sql = format!(
            "INSERT INTO sync_jobs (
                id, user_id, source, resource, scope, scope_key,
                status, attempts, created_at, updated_at
             ) VALUES ($1, $2, $3, $4, $5, $6, 'queued', 0, now(), now())
             ON CONFLICT (user_id, source, resource, scope_key)
                 WHERE status IN ('queued', 'running')
                 DO NOTHING
             RETURNING {COLUMNS}"
        );
        let inserted: Option<JobRow> = sqlx::query_as(AssertSqlSafe(insert_sql))
            .bind(Uuid::new_v4())
            .bind(user_id)
            .bind(source)
            .bind(resource)
            .bind(&scope)
            .bind(&scope_key)
            .fetch_optional(pool)
            .await
            .map_err(store_error)?;

        if let Some(job) = inserted {
            return Ok(CreatedJob { job, reused: false });
        }

        let existing_sql = format!(
            "SELECT {COLUMNS} FROM sync_jobs
             WHERE user_id = $1 AND source = $2 AND resource = $3 AND scope_key = $4
               AND status IN ('queued', 'running')"
        );
        let existing: Option<JobRow> = sqlx::query_as(AssertSqlSafe(existing_sql))
            .bind(user_id)
            .bind(source)
            .bind(resource)
            .bind(&scope_key)
            .fetch_optional(pool)
            .await
            .map_err(store_error)?;

        if let Some(job) = existing {
            return Ok(CreatedJob { job, reused: true });
        }
    }

    tracing::error!("sync job disappeared between insert conflict and reuse lookup");
    Err(AppError::Internal)
}

pub async fn get(pool: &PgPool, user_id: Uuid, job_id: Uuid) -> Result<JobRow, AppError> {
    let select_sql = format!("SELECT {COLUMNS} FROM sync_jobs WHERE id = $1 AND user_id = $2");
    sqlx::query_as(AssertSqlSafe(select_sql))
        .bind(job_id)
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .map_err(store_error)?
        .ok_or(AppError::SyncJobNotFound)
}

pub async fn finish_succeeded(
    pool: &PgPool,
    job_id: Uuid,
    attempts: i32,
    outcome: SyncOutcome,
) -> Result<(), AppError> {
    let updated = sqlx::query(
        "UPDATE sync_jobs SET
            status = 'succeeded',
            finished_at = now(),
            updated_at = now(),
            lease_expires_at = NULL,
            complete = $2,
            snapshot_version = $3,
            error_code = NULL,
            error_retryable = NULL
         WHERE id = $1 AND status = 'running' AND attempts = $4",
    )
    .bind(job_id)
    .bind(outcome.complete)
    .bind(outcome.snapshot_version)
    .bind(attempts)
    .execute(pool)
    .await
    .map_err(store_error)?;
    warn_if_untouched(updated.rows_affected(), job_id, attempts);
    Ok(())
}

pub async fn finish_failed(
    pool: &PgPool,
    job_id: Uuid,
    attempts: i32,
    failure: &crate::sync::registry::SyncFailure,
) -> Result<(), AppError> {
    let updated = sqlx::query(
        "UPDATE sync_jobs SET
            status = 'failed',
            finished_at = now(),
            updated_at = now(),
            lease_expires_at = NULL,
            complete = NULL,
            snapshot_version = NULL,
            error_code = $2,
            error_retryable = $3
         WHERE id = $1 AND status = 'running' AND attempts = $4",
    )
    .bind(job_id)
    .bind(failure.code)
    .bind(failure.retryable)
    .bind(attempts)
    .execute(pool)
    .await
    .map_err(store_error)?;
    warn_if_untouched(updated.rows_affected(), job_id, attempts);
    Ok(())
}

fn warn_if_untouched(rows: u64, job_id: Uuid, attempts: i32) {
    if rows == 0 {
        tracing::warn!(
            %job_id,
            attempts,
            "sync job attempt was no longer current when it settled"
        );
    }
}

pub fn scope_key(scope: &Value) -> String {
    let canonical = serde_json::to_vec(scope).expect("JSON values serialize");
    hex::encode(Sha256::digest(canonical))
}

fn timestamp(value: OffsetDateTime) -> String {
    value
        .format(&Rfc3339)
        .expect("stored timestamps are representable as RFC 3339")
}

fn store_error(error: sqlx::Error) -> AppError {
    tracing::error!(
        error_kind = crate::db::error_kind(&error),
        "sync job store operation failed"
    );
    AppError::Internal
}
