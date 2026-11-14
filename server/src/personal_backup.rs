use std::collections::HashSet;

use axum::{
    Extension, Json, Router,
    extract::{Request, State},
    http::{HeaderMap, HeaderValue, StatusCode, header},
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::get,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;
use sha2::{Digest, Sha256};
use sqlx::{FromRow, PgPool};
use tower_http::request_id::RequestId;
use uuid::Uuid;

use crate::{
    auth::AuthenticatedUser,
    error::{AppError, FieldError, request_id},
    json::ApiJson,
    response::ApiResponse,
    state::AppState,
};

const PUT_ENDPOINT: &str = "PUT /personal-backup/notes";
const DELETE_ENDPOINT: &str = "DELETE /personal-backup/notes";
const MAX_NOTES_BYTES: usize = 512 * 1024;

#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
struct BackupNote {
    id: Uuid,
    title: String,
    body: String,
    #[serde(deserialize_with = "required_nullable")]
    course_offering_id: Option<String>,
    #[serde(deserialize_with = "required_nullable")]
    lesson_id: Option<String>,
    #[serde(deserialize_with = "required_nullable")]
    replay_source: Option<String>,
    #[serde(deserialize_with = "required_nullable")]
    replay_id: Option<String>,
    #[serde(deserialize_with = "required_nullable")]
    replay_title: Option<String>,
    #[serde(deserialize_with = "required_nullable")]
    position_ms: Option<i64>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

fn required_nullable<'de, D, T>(deserializer: D) -> Result<Option<T>, D::Error>
where
    D: serde::Deserializer<'de>,
    T: Deserialize<'de>,
{
    Option::<T>::deserialize(deserializer)
}

#[derive(Debug, Serialize, FromRow)]
struct BackupSnapshot {
    revision: i32,
    deleted: bool,
    #[sqlx(json)]
    notes: Vec<BackupNote>,
    updated_at: Option<DateTime<Utc>>,
}

impl Default for BackupSnapshot {
    fn default() -> Self {
        Self {
            revision: 0,
            deleted: true,
            notes: Vec::new(),
            updated_at: None,
        }
    }
}

#[derive(Debug, Deserialize, Serialize, FromRow)]
#[serde(deny_unknown_fields)]
struct BackupReceipt {
    revision: i32,
    deleted: bool,
    updated_at: DateTime<Utc>,
}

#[derive(Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
struct PutBackup {
    expected_revision: i32,
    notes: Vec<BackupNote>,
}

#[derive(Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
struct DeleteBackup {
    expected_revision: i32,
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/personal-backup/notes",
            get(read).put(put).delete(delete),
        )
        .layer(middleware::from_fn(private_response))
}

async fn private_response(request: Request, next: Next) -> Response {
    let mut response = next.run(request).await;
    response.headers_mut().insert(
        header::CACHE_CONTROL,
        HeaderValue::from_static("private, no-store"),
    );
    response
}

async fn read(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
) -> Response {
    let request_id = request_id(&request_id_value);
    match sqlx::query_as::<_, BackupSnapshot>(
        "SELECT revision, deleted, notes, updated_at FROM personal_backups WHERE user_id = $1",
    )
    .bind(user.user_id)
    .fetch_optional(&state.pool)
    .await
    {
        Ok(snapshot) => {
            Json(ApiResponse::new(snapshot.unwrap_or_default(), request_id)).into_response()
        }
        Err(_) => AppError::DatabaseUnavailable.response(&request_id),
    }
}

async fn put(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
    headers: HeaderMap,
    ApiJson(body): ApiJson<PutBackup>,
) -> Response {
    let request_id = request_id(&request_id_value);
    let key = match idempotency_key(&headers) {
        Ok(key) => key,
        Err(error) => return error.response(&request_id),
    };
    if let Err(error) = validate(body.expected_revision, &body.notes) {
        return error.response(&request_id);
    }
    let request_hash = hex::encode(Sha256::digest(
        serde_json::to_vec(&body).expect("backup request serializes"),
    ));
    match write(
        &state.pool,
        user.user_id,
        PUT_ENDPOINT,
        key,
        &request_hash,
        body.expected_revision,
        Some(&body.notes),
    )
    .await
    {
        Ok(receipt) => Json(ApiResponse::new(receipt, request_id)).into_response(),
        Err(error) => error.response(&request_id),
    }
}

async fn delete(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
    headers: HeaderMap,
    ApiJson(body): ApiJson<DeleteBackup>,
) -> Response {
    let request_id = request_id(&request_id_value);
    let key = match idempotency_key(&headers) {
        Ok(key) => key,
        Err(error) => return error.response(&request_id),
    };
    if let Err(error) = validate(body.expected_revision, &[]) {
        return error.response(&request_id);
    }
    let request_hash = hex::encode(Sha256::digest(
        serde_json::to_vec(&body).expect("backup request serializes"),
    ));
    match write(
        &state.pool,
        user.user_id,
        DELETE_ENDPOINT,
        key,
        &request_hash,
        body.expected_revision,
        None,
    )
    .await
    {
        Ok(receipt) => Json(ApiResponse::new(receipt, request_id)).into_response(),
        Err(error) => error.response(&request_id),
    }
}

fn invalid(path: impl Into<String>, code: &str) -> AppError {
    AppError::Validation(vec![FieldError::new(path, code)])
}

fn idempotency_key(headers: &HeaderMap) -> Result<Uuid, AppError> {
    let value = headers
        .get("idempotency-key")
        .ok_or_else(|| invalid("Idempotency-Key", "REQUIRED"))?;
    value
        .to_str()
        .ok()
        .and_then(|raw| Uuid::parse_str(raw).ok())
        .ok_or_else(|| invalid("Idempotency-Key", "INVALID_FORMAT"))
}

fn validate(expected_revision: i32, notes: &[BackupNote]) -> Result<(), AppError> {
    if expected_revision < 0 {
        return Err(invalid("expected_revision", "OUT_OF_RANGE"));
    }
    if notes.len() > 100 {
        return Err(invalid("notes", "TOO_MANY_ITEMS"));
    }
    let mut ids = HashSet::new();
    for (index, note) in notes.iter().enumerate() {
        if !ids.insert(note.id) {
            return Err(invalid(format!("notes[{index}].id"), "DUPLICATE"));
        }
        for (field, value, limit) in [
            ("title", Some(note.title.as_str()), 200),
            ("body", Some(note.body.as_str()), 20_000),
            (
                "course_offering_id",
                note.course_offering_id.as_deref(),
                300,
            ),
            ("lesson_id", note.lesson_id.as_deref(), 300),
            ("replay_source", note.replay_source.as_deref(), 300),
            ("replay_id", note.replay_id.as_deref(), 300),
            ("replay_title", note.replay_title.as_deref(), 300),
        ] {
            if value.is_some_and(|value| value.chars().count() > limit) {
                return Err(invalid(format!("notes[{index}].{field}"), "TOO_LONG"));
            }
        }
        let source = note.replay_source.as_deref();
        let replay_id = note.replay_id.as_deref();
        if source.is_some() != replay_id.is_some()
            || source.is_some_and(|value| value.trim().is_empty())
            || replay_id.is_some_and(|value| value.trim().is_empty())
        {
            return Err(invalid(
                format!("notes[{index}].replay_id"),
                "REPLAY_PAIR_REQUIRED",
            ));
        }
        if let Some(position) = note.position_ms
            && (position < 0 || source.is_none())
        {
            return Err(invalid(
                format!("notes[{index}].position_ms"),
                "INVALID_POSITION",
            ));
        }
        if note.created_at > note.updated_at {
            return Err(invalid(
                format!("notes[{index}].updated_at"),
                "BEFORE_CREATED_AT",
            ));
        }
    }
    if serde_json::to_vec(notes)
        .expect("backup notes serialize")
        .len()
        > MAX_NOTES_BYTES
    {
        return Err(invalid("notes", "TOO_LARGE"));
    }
    Ok(())
}

enum WriteError {
    IdempotencyConflict,
    RevisionConflict(BackupSnapshot),
    App(AppError),
}

impl From<sqlx::Error> for WriteError {
    fn from(_: sqlx::Error) -> Self {
        Self::App(AppError::DatabaseUnavailable)
    }
}

impl WriteError {
    fn response(self, request_id: &str) -> Response {
        let (code, message, current) = match self {
            Self::App(error) => return error.response(request_id),
            Self::IdempotencyConflict => (
                "IDEMPOTENCY_CONFLICT",
                "Idempotency key was used for a different request.",
                None,
            ),
            Self::RevisionConflict(snapshot) => (
                "BACKUP_REVISION_CONFLICT",
                "Backup revision does not match.",
                Some(snapshot),
            ),
        };
        let mut error = json!({
            "code": code,
            "message": message,
            "request_id": request_id,
            "retryable": false,
            "fields": [],
        });
        if let Some(current) = current {
            error["current"] = json!(current);
        }
        (StatusCode::CONFLICT, Json(json!({ "error": error }))).into_response()
    }
}

async fn write(
    pool: &PgPool,
    user_id: Uuid,
    endpoint: &str,
    key: Uuid,
    request_hash: &str,
    expected_revision: i32,
    notes: Option<&[BackupNote]>,
) -> Result<BackupReceipt, WriteError> {
    let mut tx = pool.begin().await?;
    let claimed = sqlx::query(
        "INSERT INTO idempotency_keys (user_id, endpoint, key, request_hash)
         VALUES ($1, $2, $3, $4) ON CONFLICT (user_id, endpoint, key) DO NOTHING",
    )
    .bind(user_id)
    .bind(endpoint)
    .bind(key)
    .bind(request_hash)
    .execute(&mut *tx)
    .await?;
    if claimed.rows_affected() == 0 {
        let (existing_hash, status, response): (String, Option<i16>, Option<serde_json::Value>) =
            sqlx::query_as(
                "SELECT request_hash, status_code, response FROM idempotency_keys
                 WHERE user_id = $1 AND endpoint = $2 AND key = $3",
            )
            .bind(user_id)
            .bind(endpoint)
            .bind(key)
            .fetch_one(&mut *tx)
            .await?;
        if existing_hash != request_hash || status != Some(200) {
            return Err(WriteError::IdempotencyConflict);
        }
        let receipt = serde_json::from_value(response.ok_or(sqlx::Error::RowNotFound)?)
            .map_err(|_| sqlx::Error::Decode("invalid backup receipt".into()))?;
        tx.commit().await?;
        return Ok(receipt);
    }
    sqlx::query("INSERT INTO personal_backups (user_id) VALUES ($1) ON CONFLICT DO NOTHING")
        .bind(user_id)
        .execute(&mut *tx)
        .await?;
    let current: BackupSnapshot = sqlx::query_as(
        "SELECT revision, deleted, notes, updated_at FROM personal_backups
         WHERE user_id = $1 FOR UPDATE",
    )
    .bind(user_id)
    .fetch_one(&mut *tx)
    .await?;
    if current.revision != expected_revision {
        return Err(WriteError::RevisionConflict(current));
    }
    let revision = expected_revision
        .checked_add(1)
        .ok_or_else(|| WriteError::App(invalid("expected_revision", "OUT_OF_RANGE")))?;
    let receipt: BackupReceipt = sqlx::query_as(
        "UPDATE personal_backups SET revision = $2, deleted = $3, notes = $4, updated_at = now()
         WHERE user_id = $1 RETURNING revision, deleted, updated_at",
    )
    .bind(user_id)
    .bind(revision)
    .bind(notes.is_none())
    .bind(sqlx::types::Json(notes.unwrap_or(&[])))
    .fetch_one(&mut *tx)
    .await?;
    sqlx::query(
        "UPDATE idempotency_keys SET status_code = 200, response = $4
         WHERE user_id = $1 AND endpoint = $2 AND key = $3",
    )
    .bind(user_id)
    .bind(endpoint)
    .bind(key)
    .bind(sqlx::types::Json(&receipt))
    .execute(&mut *tx)
    .await?;
    tx.commit().await?;
    Ok(receipt)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn nullable_note_fields_are_serialized_and_unknown_fields_are_rejected() {
        let note = json!({
            "id": Uuid::new_v4(), "title": "", "body": "",
            "course_offering_id": null, "lesson_id": null, "replay_source": null,
            "replay_id": null, "replay_title": null, "position_ms": null,
            "created_at": "2026-11-14T08:00:00+08:00", "updated_at": "2026-11-14T00:00:00Z",
        });
        let parsed: BackupNote = serde_json::from_value(note.clone()).unwrap();
        assert!(validate(0, &[parsed]).is_ok());
        let parsed: BackupNote = serde_json::from_value(note.clone()).unwrap();
        let encoded = serde_json::to_value(parsed).unwrap();
        assert_eq!(encoded["created_at"], "2026-11-14T00:00:00Z");
        for field in [
            "course_offering_id",
            "lesson_id",
            "replay_source",
            "replay_id",
            "replay_title",
            "position_ms",
        ] {
            assert!(encoded.get(field).is_some_and(serde_json::Value::is_null));
        }
        let mut unknown = note;
        unknown["user_id"] = json!(Uuid::new_v4());
        assert!(serde_json::from_value::<BackupNote>(unknown).is_err());
    }
}
