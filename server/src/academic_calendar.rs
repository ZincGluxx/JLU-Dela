use std::collections::HashMap;

use axum::{
    Extension, Json,
    extract::{Query, State},
    response::{IntoResponse, Response},
};
use serde_json::Value;
use tower_http::request_id::RequestId;

use crate::{
    error::{AppError, request_id},
    response::ApiResponse,
    state::AppState,
};

pub async fn get(
    State(state): State<AppState>,
    Extension(request_id_value): Extension<RequestId>,
    Query(query): Query<HashMap<String, String>>,
) -> Response {
    let request_id = request_id(&request_id_value);
    let academic_year = query
        .get("academic_year")
        .map(String::as_str)
        .unwrap_or("2026-2027");
    match sqlx::query_scalar::<_, Value>(
        "SELECT document FROM academic_calendars WHERE academic_year = $1",
    )
    .bind(academic_year)
    .fetch_optional(&state.pool)
    .await
    {
        Ok(Some(document)) => Json(ApiResponse::new(document, request_id)).into_response(),
        Ok(None) => AppError::AcademicCalendarNotFound.response(&request_id),
        Err(error) => {
            tracing::error!(kind = crate::db::error_kind(&error), %error, "academic calendar query failed");
            AppError::DatabaseUnavailable.response(&request_id)
        }
    }
}
