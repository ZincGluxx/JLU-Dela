use std::{future::Future, path::PathBuf};

use axum::{
    Json, Router,
    extract::{DefaultBodyLimit, Extension, Multipart, Path, State, multipart::MultipartError},
    http::{StatusCode, header},
    response::{IntoResponse, Response},
    routing::{get, post},
};
use chrono::{DateTime, Utc};
use serde::Serialize;
use sqlx::{FromRow, PgConnection};
use tokio::io::AsyncWriteExt;
use tower_http::request_id::RequestId;
use uuid::Uuid;

use crate::{
    auth::AuthenticatedUser,
    error::{AppError, FieldError, request_id},
    response::ApiResponse,
    state::AppState,
};

#[derive(Clone, Debug)]
pub struct FileStorageConfig {
    pub dir: PathBuf,
    pub max_bytes: usize,
}

impl Default for FileStorageConfig {
    fn default() -> Self {
        Self {
            dir: "./data/files".into(),
            max_bytes: 10 * 1024 * 1024,
        }
    }
}

#[derive(Debug, Serialize, FromRow)]
pub struct StoredFile {
    pub id: Uuid,
    pub uploader_id: Uuid,
    pub original_name: String,
    pub size_bytes: i64,
    pub media_type: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Clone, Copy, Debug)]
pub enum FileUse {
    Material,
    CommunityImage,
}

impl FileUse {
    fn as_str(self) -> &'static str {
        match self {
            Self::Material => "material",
            Self::CommunityImage => "community_image",
        }
    }
}

pub struct FileContent {
    pub metadata: StoredFile,
    pub bytes: Vec<u8>,
}

impl IntoResponse for FileContent {
    fn into_response(self) -> Response {
        let encoded: String = self
            .metadata
            .original_name
            .bytes()
            .map(|b| {
                if b.is_ascii_alphanumeric() || b"!#$&+-.^_`|~".contains(&b) {
                    (b as char).to_string()
                } else {
                    format!("%{b:02X}")
                }
            })
            .collect();
        (
            [
                (header::CONTENT_TYPE, "application/octet-stream".to_owned()),
                (
                    header::CONTENT_DISPOSITION,
                    format!("attachment; filename=\"download\"; filename*=UTF-8''{encoded}"),
                ),
                (header::X_CONTENT_TYPE_OPTIONS, "nosniff".to_owned()),
                (header::CACHE_CONTROL, "private, no-store".to_owned()),
            ],
            self.bytes,
        )
            .into_response()
    }
}

pub fn router(max_bytes: usize) -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/files",
            post(upload).layer(DefaultBodyLimit::max(max_bytes + 64 * 1024)),
        )
        .route("/api/v1/files/{id}", get(metadata).delete(delete))
        .route("/api/v1/files/{id}/content", get(content))
}

fn validation(code: &str) -> AppError {
    AppError::Validation(vec![FieldError::new("file", code)])
}

fn multipart_error(error: MultipartError) -> AppError {
    if error.status() == StatusCode::PAYLOAD_TOO_LARGE {
        AppError::PayloadTooLarge
    } else {
        validation("invalid_multipart")
    }
}

async fn upload(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(rid): Extension<RequestId>,
    multipart: Result<Multipart, axum::extract::multipart::MultipartRejection>,
) -> Response {
    let result = async {
        let mut multipart = multipart.map_err(|_| validation("invalid_multipart"))?;
        let mut field = multipart.next_field().await.map_err(multipart_error)?.ok_or_else(|| validation("required"))?;
        if field.name() != Some("file") { return Err(validation("single_file_required")); }
        let original_name = field.file_name().ok_or_else(|| validation("filename_required"))?.to_owned();
        if original_name.is_empty() || original_name.chars().count() > 255 || original_name.chars().any(char::is_control) {
            return Err(validation("invalid_filename"));
        }
        let media_type = field.content_type().unwrap_or("application/octet-stream").to_owned();
        let mut bytes = Vec::new();
        while let Some(chunk) = field.chunk().await.map_err(multipart_error)? {
            if chunk.len() > state.files.max_bytes - bytes.len() { return Err(AppError::PayloadTooLarge); }
            bytes.extend_from_slice(&chunk);
        }
        if bytes.is_empty() { return Err(validation("empty")); }
        drop(field);
        if multipart.next_field().await.map_err(multipart_error)?.is_some() { return Err(validation("single_file_required")); }
        let id = Uuid::new_v4();
        let path = state.files.dir.join(id.to_string());
        tokio::fs::create_dir_all(&state.files.dir).await.map_err(|_| AppError::FileStorageUnavailable)?;
        let mut file = tokio::fs::OpenOptions::new().write(true).create_new(true).open(&path).await.map_err(|_| AppError::FileStorageUnavailable)?;
        let written = async {
            file.write_all(&bytes).await?;
            file.flush().await?;
            file.sync_all().await
        }.await;
        drop(file);
        if written.is_err() {
            let _ = tokio::fs::remove_file(&path).await;
            return Err(AppError::FileStorageUnavailable);
        }
        let saved = sqlx::query_as::<_, StoredFile>("INSERT INTO files (id,uploader_id,original_name,size_bytes,media_type) VALUES ($1,$2,$3,$4,$5) RETURNING id,uploader_id,original_name,size_bytes,media_type,created_at")
            .bind(id).bind(user.user_id).bind(original_name).bind(bytes.len() as i64).bind(media_type).fetch_one(&state.pool).await;
        match saved {
            Ok(file) => Ok(file),
            Err(_) => { let _ = tokio::fs::remove_file(&path).await; Err(AppError::DatabaseUnavailable) }
        }
    }.await;
    match result {
        Ok(file) => (
            StatusCode::CREATED,
            Json(ApiResponse::new(file, request_id(&rid))),
        )
            .into_response(),
        Err(error) => error.response(&request_id(&rid)),
    }
}

async fn private_file(
    connection: &mut PgConnection,
    id: Uuid,
    uploader: Uuid,
) -> Result<StoredFile, AppError> {
    sqlx::query_as("SELECT id,uploader_id,original_name,size_bytes,media_type,created_at FROM files WHERE id=$1 AND uploader_id=$2 AND use_kind IS NULL AND NOT deleting FOR SHARE")
        .bind(id).bind(uploader).fetch_optional(connection).await.map_err(|_| AppError::DatabaseUnavailable)?.ok_or(AppError::FileNotFound)
}

async fn metadata(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(id): Path<String>,
    Extension(rid): Extension<RequestId>,
) -> Response {
    let result = async {
        let id = Uuid::parse_str(&id).map_err(|_| AppError::FileNotFound)?;
        let mut connection = state
            .pool
            .acquire()
            .await
            .map_err(|_| AppError::DatabaseUnavailable)?;
        private_file(&mut connection, id, user.user_id).await
    }
    .await;
    match result {
        Ok(file) => Json(ApiResponse::new(file, request_id(&rid))).into_response(),
        Err(error) => error.response(&request_id(&rid)),
    }
}

async fn content(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(id): Path<String>,
    Extension(rid): Extension<RequestId>,
) -> Response {
    let result = async {
        let id = Uuid::parse_str(&id).map_err(|_| AppError::FileNotFound)?;
        let mut tx = state
            .pool
            .begin()
            .await
            .map_err(|_| AppError::DatabaseUnavailable)?;
        let metadata = private_file(&mut tx, id, user.user_id).await?;
        let bytes = read_bytes(&state, &metadata).await?;
        tx.commit()
            .await
            .map_err(|_| AppError::DatabaseUnavailable)?;
        Ok::<_, AppError>(FileContent { metadata, bytes })
    }
    .await;
    match result {
        Ok(file) => file.into_response(),
        Err(error) => error.response(&request_id(&rid)),
    }
}

async fn read_bytes(state: &AppState, metadata: &StoredFile) -> Result<Vec<u8>, AppError> {
    tokio::fs::read(state.files.dir.join(metadata.id.to_string()))
        .await
        .map_err(|error| {
            if error.kind() == std::io::ErrorKind::NotFound {
                AppError::FileNotFound
            } else {
                AppError::FileStorageUnavailable
            }
        })
}

pub async fn attach(
    connection: &mut PgConnection,
    file_id: Uuid,
    uploader_id: Uuid,
    use_kind: FileUse,
    business_id: Uuid,
) -> Result<(), AppError> {
    let row: Option<(Option<String>,)> = sqlx::query_as(
        "SELECT use_kind FROM files WHERE id=$1 AND uploader_id=$2 AND NOT deleting FOR UPDATE",
    )
    .bind(file_id)
    .bind(uploader_id)
    .fetch_optional(&mut *connection)
    .await
    .map_err(|_| AppError::DatabaseUnavailable)?;
    match row {
        None => return Err(AppError::FileNotFound),
        Some((Some(_),)) => return Err(AppError::FileInUse),
        _ => {}
    }
    sqlx::query("UPDATE files SET use_kind=$2,business_id=$3 WHERE id=$1")
        .bind(file_id)
        .bind(use_kind.as_str())
        .bind(business_id)
        .execute(connection)
        .await
        .map_err(|_| AppError::DatabaseUnavailable)?;
    Ok(())
}

pub async fn detach(
    connection: &mut PgConnection,
    file_id: Uuid,
    use_kind: FileUse,
    business_id: Uuid,
) -> Result<(), AppError> {
    let result = sqlx::query("UPDATE files SET use_kind=NULL,business_id=NULL WHERE id=$1 AND use_kind=$2 AND business_id=$3 AND NOT deleting")
        .bind(file_id).bind(use_kind.as_str()).bind(business_id).execute(connection).await.map_err(|_| AppError::DatabaseUnavailable)?;
    if result.rows_affected() == 0 {
        return Err(AppError::FileNotFound);
    }
    Ok(())
}

pub async fn read_for_business<F, Fut>(
    state: &AppState,
    file_id: Uuid,
    use_kind: FileUse,
    business_id: Uuid,
    authorize: F,
) -> Result<FileContent, AppError>
where
    F: FnOnce() -> Fut,
    Fut: Future<Output = Result<(), AppError>>,
{
    let mut tx = state
        .pool
        .begin()
        .await
        .map_err(|_| AppError::DatabaseUnavailable)?;
    let metadata: StoredFile = sqlx::query_as("SELECT id,uploader_id,original_name,size_bytes,media_type,created_at FROM files WHERE id=$1 AND use_kind=$2 AND business_id=$3 AND NOT deleting FOR SHARE")
        .bind(file_id).bind(use_kind.as_str()).bind(business_id).fetch_optional(&mut *tx).await.map_err(|_| AppError::DatabaseUnavailable)?.ok_or(AppError::FileNotFound)?;
    authorize().await?;
    let bytes = read_bytes(state, &metadata).await?;
    tx.commit()
        .await
        .map_err(|_| AppError::DatabaseUnavailable)?;
    Ok(FileContent { metadata, bytes })
}

async fn delete(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(id): Path<String>,
    Extension(rid): Extension<RequestId>,
) -> Response {
    let result = async {
        let id = Uuid::parse_str(&id).map_err(|_| AppError::FileNotFound)?;
        let mut tx = state
            .pool
            .begin()
            .await
            .map_err(|_| AppError::DatabaseUnavailable)?;
        let row: Option<(Option<String>,)> =
            sqlx::query_as("SELECT use_kind FROM files WHERE id=$1 AND uploader_id=$2 FOR UPDATE")
                .bind(id)
                .bind(user.user_id)
                .fetch_optional(&mut *tx)
                .await
                .map_err(|_| AppError::DatabaseUnavailable)?;
        match row {
            None => return Err(AppError::FileNotFound),
            Some((Some(_),)) => return Err(AppError::FileInUse),
            _ => {}
        }
        sqlx::query("UPDATE files SET deleting=true WHERE id=$1")
            .bind(id)
            .execute(&mut *tx)
            .await
            .map_err(|_| AppError::DatabaseUnavailable)?;
        tx.commit()
            .await
            .map_err(|_| AppError::DatabaseUnavailable)?;
        match tokio::fs::remove_file(state.files.dir.join(id.to_string())).await {
            Ok(()) => {}
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
            Err(_) => return Err(AppError::FileStorageUnavailable),
        }
        sqlx::query("DELETE FROM files WHERE id=$1 AND deleting")
            .bind(id)
            .execute(&state.pool)
            .await
            .map_err(|_| AppError::DatabaseUnavailable)?;
        Ok(())
    }
    .await;
    match result {
        Ok(()) => StatusCode::NO_CONTENT.into_response(),
        Err(error) => error.response(&request_id(&rid)),
    }
}
