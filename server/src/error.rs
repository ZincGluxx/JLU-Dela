use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde::Serialize;
use tower_http::request_id::RequestId;

#[derive(Debug)]
pub enum AppError {
    DatabaseUnavailable,
    DatabaseSchemaMissing,
    NotFound,
    MethodNotAllowed,
    PayloadTooLarge,
    RequestTimeout,
}

#[derive(Debug, Serialize)]
struct ErrorBody {
    error: ErrorDetail,
}

#[derive(Debug, Serialize)]
struct ErrorDetail {
    code: &'static str,
    message: &'static str,
    request_id: String,
    retryable: bool,
    fields: Vec<FieldError>,
}

#[derive(Debug, Serialize)]
struct FieldError {
    path: String,
    code: String,
}

impl AppError {
    pub fn response(self, request_id: &str) -> Response {
        let (status, code, message, retryable) = match self {
            Self::DatabaseUnavailable => (
                StatusCode::SERVICE_UNAVAILABLE,
                "DATABASE_UNAVAILABLE",
                "Database is unavailable.",
                true,
            ),
            Self::DatabaseSchemaMissing => (
                StatusCode::SERVICE_UNAVAILABLE,
                "DATABASE_SCHEMA_MISSING",
                "Database schema is not ready.",
                true,
            ),
            Self::NotFound => (
                StatusCode::NOT_FOUND,
                "NOT_FOUND",
                "Route not found.",
                false,
            ),
            Self::MethodNotAllowed => (
                StatusCode::METHOD_NOT_ALLOWED,
                "METHOD_NOT_ALLOWED",
                "Method not allowed.",
                false,
            ),
            Self::PayloadTooLarge => (
                StatusCode::PAYLOAD_TOO_LARGE,
                "PAYLOAD_TOO_LARGE",
                "Request body is too large.",
                false,
            ),
            Self::RequestTimeout => (
                StatusCode::REQUEST_TIMEOUT,
                "REQUEST_TIMEOUT",
                "Request timed out.",
                true,
            ),
        };

        let body = ErrorBody {
            error: ErrorDetail {
                code,
                message,
                request_id: request_id.to_owned(),
                retryable,
                fields: Vec::new(),
            },
        };
        (status, Json(body)).into_response()
    }
}

pub fn request_id(request_id: &RequestId) -> String {
    request_id
        .header_value()
        .to_str()
        .map_or_else(|_| "unknown".to_owned(), str::to_owned)
}

pub fn request_id_from_extensions(extensions: &axum::http::Extensions) -> String {
    extensions
        .get::<RequestId>()
        .map_or_else(|| "unknown".to_owned(), request_id)
}
