use std::time::Duration;

use axum::{
    Json,
    extract::{Extension, State},
    response::{IntoResponse, Response},
};
use serde::Serialize;
use tower_http::request_id::RequestId;

use crate::{
    error::{AppError, request_id},
    response::ApiResponse,
    state::AppState,
};

const READINESS_TIMEOUT: Duration = Duration::from_secs(2);

#[derive(Debug, Serialize)]
pub struct LiveData {
    pub status: &'static str,
}

#[derive(Debug, Serialize)]
pub struct ReadyData {
    pub status: &'static str,
    pub schema_version: String,
}

pub async fn live(
    Extension(request_id_value): Extension<RequestId>,
) -> Json<ApiResponse<LiveData>> {
    Json(ApiResponse::new(
        LiveData { status: "ok" },
        request_id(&request_id_value),
    ))
}

pub async fn ready(
    State(state): State<AppState>,
    Extension(request_id_value): Extension<RequestId>,
) -> Response {
    let request_id = request_id(&request_id_value);
    let schema_version = tokio::time::timeout(
        READINESS_TIMEOUT,
        sqlx::query_scalar::<_, String>(
            "SELECT value FROM service_meta WHERE key = 'schema_version'",
        )
        .fetch_one(&state.pool),
    )
    .await;

    match schema_version {
        Ok(Ok(schema_version)) => Json(ApiResponse::new(
            ReadyData {
                status: "ready",
                schema_version,
            },
            request_id,
        ))
        .into_response(),
        Ok(Err(sqlx::Error::RowNotFound)) => {
            tracing::warn!("database schema metadata is missing");
            AppError::DatabaseSchemaMissing.response(&request_id)
        }
        Ok(Err(error)) => {
            tracing::warn!(
                error_kind = crate::db::error_kind(&error),
                "database readiness check failed"
            );
            AppError::DatabaseUnavailable.response(&request_id)
        }
        Err(_) => {
            tracing::warn!("database readiness check timed out");
            AppError::DatabaseUnavailable.response(&request_id)
        }
    }
}
