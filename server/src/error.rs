use axum::{
    Json,
    http::{Extensions, HeaderValue, StatusCode, header},
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
    UnsupportedMediaType,
    InvalidBody,
    Validation(Vec<FieldError>),
    UnsupportedSource,
    UnsupportedResource,
    SyncJobNotFound,
    AuthRequired,
    InvalidToken,
    TokenExpired,
    SessionRevoked,
    Internal,
}

#[derive(Debug, Serialize)]
pub struct FieldError {
    pub path: String,
    pub code: String,
}

impl FieldError {
    pub fn new(path: impl Into<String>, code: impl Into<String>) -> Self {
        Self {
            path: path.into(),
            code: code.into(),
        }
    }
}

#[derive(Debug, Serialize)]
struct ErrorBody {
    error: ErrorDetail,
}

#[derive(Debug, Serialize)]
struct ErrorDetail {
    code: &'static str,
    message: String,
    request_id: String,
    retryable: bool,
    fields: Vec<FieldError>,
}

pub struct ApiErrorResponse {
    error: AppError,
    request_id: String,
}

impl ApiErrorResponse {
    pub fn new(error: AppError, extensions: &Extensions) -> Self {
        Self {
            error,
            request_id: request_id_from_extensions(extensions),
        }
    }

    pub fn with_request_id(error: AppError, request_id: String) -> Self {
        Self { error, request_id }
    }
}

impl IntoResponse for ApiErrorResponse {
    fn into_response(self) -> Response {
        self.error.response(&self.request_id)
    }
}

impl AppError {
    pub fn response(self, request_id: &str) -> Response {
        let (status, code, message, retryable, fields) = match self {
            Self::DatabaseUnavailable => (
                StatusCode::SERVICE_UNAVAILABLE,
                "DATABASE_UNAVAILABLE",
                "Database is unavailable.".to_owned(),
                true,
                Vec::new(),
            ),
            Self::DatabaseSchemaMissing => (
                StatusCode::SERVICE_UNAVAILABLE,
                "DATABASE_SCHEMA_MISSING",
                "Database schema is not ready.".to_owned(),
                true,
                Vec::new(),
            ),
            Self::NotFound => (
                StatusCode::NOT_FOUND,
                "NOT_FOUND",
                "Route not found.".to_owned(),
                false,
                Vec::new(),
            ),
            Self::MethodNotAllowed => (
                StatusCode::METHOD_NOT_ALLOWED,
                "METHOD_NOT_ALLOWED",
                "Method not allowed.".to_owned(),
                false,
                Vec::new(),
            ),
            Self::PayloadTooLarge => (
                StatusCode::PAYLOAD_TOO_LARGE,
                "PAYLOAD_TOO_LARGE",
                "Request body is too large.".to_owned(),
                false,
                Vec::new(),
            ),
            Self::RequestTimeout => (
                StatusCode::REQUEST_TIMEOUT,
                "REQUEST_TIMEOUT",
                "Request timed out.".to_owned(),
                true,
                Vec::new(),
            ),
            Self::UnsupportedMediaType => (
                StatusCode::UNSUPPORTED_MEDIA_TYPE,
                "UNSUPPORTED_MEDIA_TYPE",
                "Content-Type must be application/json.".to_owned(),
                false,
                Vec::new(),
            ),
            Self::InvalidBody => (
                StatusCode::UNPROCESSABLE_ENTITY,
                "INVALID_REQUEST_BODY",
                "Request body is invalid or contains unknown fields.".to_owned(),
                false,
                Vec::new(),
            ),
            Self::Validation(fields) => (
                StatusCode::UNPROCESSABLE_ENTITY,
                "VALIDATION_FAILED",
                "Request validation failed.".to_owned(),
                false,
                fields,
            ),
            Self::UnsupportedSource => (
                StatusCode::UNPROCESSABLE_ENTITY,
                "UNSUPPORTED_SOURCE",
                "No source adapter is registered for this source.".to_owned(),
                false,
                Vec::new(),
            ),
            Self::UnsupportedResource => (
                StatusCode::UNPROCESSABLE_ENTITY,
                "UNSUPPORTED_RESOURCE",
                "The source does not support this resource.".to_owned(),
                false,
                Vec::new(),
            ),
            Self::SyncJobNotFound => (
                StatusCode::NOT_FOUND,
                "SYNC_JOB_NOT_FOUND",
                "Sync job not found.".to_owned(),
                false,
                Vec::new(),
            ),
            Self::AuthRequired => (
                StatusCode::UNAUTHORIZED,
                "AUTH_REQUIRED",
                "Authentication required.".to_owned(),
                false,
                Vec::new(),
            ),
            Self::InvalidToken => (
                StatusCode::UNAUTHORIZED,
                "INVALID_TOKEN",
                "The access token is invalid or no longer current.".to_owned(),
                false,
                Vec::new(),
            ),
            Self::TokenExpired => (
                StatusCode::UNAUTHORIZED,
                "TOKEN_EXPIRED",
                "The access token has expired.".to_owned(),
                false,
                Vec::new(),
            ),
            Self::SessionRevoked => (
                StatusCode::UNAUTHORIZED,
                "SESSION_REVOKED",
                "The session has been revoked.".to_owned(),
                false,
                Vec::new(),
            ),
            Self::Internal => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "INTERNAL_ERROR",
                "The service could not complete the request.".to_owned(),
                true,
                Vec::new(),
            ),
        };

        let body = ErrorBody {
            error: ErrorDetail {
                code,
                message,
                request_id: request_id.to_owned(),
                retryable,
                fields,
            },
        };
        let mut response = (status, Json(body)).into_response();
        if status == StatusCode::UNAUTHORIZED {
            response
                .headers_mut()
                .insert(header::WWW_AUTHENTICATE, HeaderValue::from_static("Bearer"));
        }
        response
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
