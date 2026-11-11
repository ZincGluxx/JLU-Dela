use std::time::Duration;

use serde_json::Value;
use sqlx::PgPool;
use tokio::task::JoinHandle;
use uuid::Uuid;

use crate::{
    error::AppError,
    state::AppState,
    sync::{
        job,
        registry::{SyncContext, SyncFailure},
    },
};

pub const LEASE: Duration = Duration::from_secs(120);
pub const MAX_ATTEMPTS: i32 = 3;

#[derive(Debug, sqlx::FromRow)]
pub struct ClaimedJob {
    pub id: Uuid,
    pub user_id: Uuid,
    pub source: String,
    pub resource: String,
    pub scope: Value,
    pub attempts: i32,
}

pub fn spawn(state: AppState) -> Option<JoinHandle<()>> {
    if state.sync.is_empty() {
        return None;
    }

    Some(tokio::spawn(async move {
        let mut ticker = tokio::time::interval(Duration::from_secs(5));
        loop {
            ticker.tick().await;
            if let Err(error) = drain(&state).await {
                tracing::warn!(error = ?error, "sync worker iteration failed");
            }
        }
    }))
}

pub async fn drain(state: &AppState) -> Result<(), AppError> {
    requeue_expired(&state.pool).await?;
    while run_once(state).await?.is_some() {}
    Ok(())
}

pub async fn run_once(state: &AppState) -> Result<Option<Uuid>, AppError> {
    let Some(claimed) = claim(&state.pool).await? else {
        return Ok(None);
    };

    let Some(handler) = state.sync.handler(&claimed.source) else {
        job::finish_failed(
            &state.pool,
            claimed.id,
            claimed.attempts,
            &SyncFailure::new("SYNC_HANDLER_MISSING", false),
        )
        .await?;
        return Ok(Some(claimed.id));
    };

    let context = SyncContext {
        job_id: claimed.id,
        user_id: claimed.user_id,
        source: &claimed.source,
        resource: &claimed.resource,
        scope: &claimed.scope,
    };

    match handler.execute(context).await {
        Ok(outcome) => {
            job::finish_succeeded(&state.pool, claimed.id, claimed.attempts, outcome).await?
        }
        Err(failure) => {
            job::finish_failed(&state.pool, claimed.id, claimed.attempts, &failure).await?
        }
    }
    tracing::info!(
        job_id = %claimed.id,
        source = %claimed.source,
        resource = %claimed.resource,
        attempts = claimed.attempts,
        "sync job settled"
    );
    Ok(Some(claimed.id))
}

pub async fn claim(pool: &PgPool) -> Result<Option<ClaimedJob>, AppError> {
    sqlx::query_as(
        "UPDATE sync_jobs SET
            status = 'running',
            attempts = attempts + 1,
            started_at = now(),
            lease_expires_at = now() + make_interval(secs => $1),
            updated_at = now()
         WHERE id = (
             SELECT id FROM sync_jobs
             WHERE status = 'queued'
             ORDER BY created_at
             FOR UPDATE SKIP LOCKED
             LIMIT 1
         )
         RETURNING id, user_id, source, resource, scope, attempts",
    )
    .bind(LEASE.as_secs() as f64)
    .fetch_optional(pool)
    .await
    .map_err(store_error)
}

pub async fn requeue_expired(pool: &PgPool) -> Result<u64, AppError> {
    let failed = sqlx::query(
        "UPDATE sync_jobs SET
            status = 'failed',
            error_code = 'SYNC_INTERRUPTED',
            error_retryable = true,
            complete = NULL,
            snapshot_version = NULL,
            finished_at = now(),
            updated_at = now(),
            lease_expires_at = NULL
         WHERE status = 'running' AND lease_expires_at < now() AND attempts >= $1",
    )
    .bind(MAX_ATTEMPTS)
    .execute(pool)
    .await
    .map_err(store_error)?;

    let requeued = sqlx::query(
        "UPDATE sync_jobs SET
            status = 'queued',
            lease_expires_at = NULL,
            updated_at = now()
         WHERE status = 'running' AND lease_expires_at < now()",
    )
    .execute(pool)
    .await
    .map_err(store_error)?;

    Ok(failed.rows_affected() + requeued.rows_affected())
}

fn store_error(error: sqlx::Error) -> AppError {
    tracing::error!(
        error_kind = crate::db::error_kind(&error),
        "sync worker store operation failed"
    );
    AppError::Internal
}
