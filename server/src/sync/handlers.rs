use axum::{
    Json,
    extract::{Extension, Path, State},
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde::Deserialize;
use serde_json::Value;
use tower_http::request_id::RequestId;
use uuid::Uuid;

use crate::{
    auth::AuthenticatedUser,
    error::{AppError, FieldError, request_id},
    json::ApiJson,
    response::ApiResponse,
    state::AppState,
    sync::job::{self, AcceptedJob, CreatedJob, JobData},
};

const MAX_SCOPE_BYTES: usize = 4096;

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CreateSyncJobRequest {
    pub source: String,
    pub resource: String,
    pub scope: Value,
}

pub async fn create(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
    ApiJson(body): ApiJson<CreateSyncJobRequest>,
) -> Response {
    let request_id = request_id(&request_id_value);
    match create_job(&state, user.user_id, body).await {
        Ok(created) => {
            let data = AcceptedJob {
                job: JobData::from(created.job),
                reused: created.reused,
            };
            (
                StatusCode::ACCEPTED,
                Json(ApiResponse::new(data, request_id)),
            )
                .into_response()
        }
        Err(error) => error.response(&request_id),
    }
}

pub async fn get(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
    Path(job_id): Path<String>,
) -> Response {
    let request_id = request_id(&request_id_value);
    match read_job(&state, user.user_id, &job_id).await {
        Ok(data) => Json(ApiResponse::new(data, request_id)).into_response(),
        Err(error) => error.response(&request_id),
    }
}

async fn create_job(
    state: &AppState,
    user_id: Uuid,
    body: CreateSyncJobRequest,
) -> Result<CreatedJob, AppError> {
    let source = validate_name(&body.source, "source")?;
    let resource = validate_name(&body.resource, "resource")?;

    if !state.sync.supports_source(source) {
        return Err(AppError::UnsupportedSource);
    }
    if !state.sync.supports(source, resource) {
        return Err(AppError::UnsupportedResource);
    }
    if !body.scope.is_object() {
        return Err(AppError::Validation(vec![FieldError::new(
            "scope",
            "must_be_object",
        )]));
    }
    let scope_bytes = serde_json::to_vec(&body.scope).map_err(|_| AppError::InvalidBody)?;
    if scope_bytes.len() > MAX_SCOPE_BYTES {
        return Err(AppError::Validation(vec![FieldError::new(
            "scope",
            "too_large",
        )]));
    }

    job::create(&state.pool, user_id, source, resource, body.scope).await
}

async fn read_job(state: &AppState, user_id: Uuid, raw_id: &str) -> Result<JobData, AppError> {
    let job_id = Uuid::parse_str(raw_id).map_err(|_| AppError::SyncJobNotFound)?;
    job::get(&state.pool, user_id, job_id)
        .await
        .map(JobData::from)
}

fn validate_name<'a>(value: &'a str, field: &str) -> Result<&'a str, AppError> {
    let value = value.trim();
    if value.is_empty() {
        return Err(AppError::Validation(vec![FieldError::new(
            field, "required",
        )]));
    }
    if value.len() > 64
        || !value.chars().all(|character| {
            character.is_ascii_lowercase() || character.is_ascii_digit() || character == '_'
        })
    {
        return Err(AppError::Validation(vec![FieldError::new(
            field,
            "invalid_format",
        )]));
    }
    Ok(value)
}
