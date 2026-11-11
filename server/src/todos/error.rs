//! 待办的契约错误体。
//!
//! 与 `crate::error::AppError` 使用同一信封
//! `{error:{code,message,request_id,retryable,fields}}`，但需要携带
//! `fields[]` 明细与 409 冲突时的服务器当前版本，所以在本模块内单独实现。
//! `request_id` 一律来自 `tower_http` 的 `RequestId` 扩展，保证与响应头
//! `X-Request-Id`、`meta.request_id` 三处一致。

use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde::Serialize;

use super::model::Todo;

#[derive(Debug, Clone, Serialize)]
pub struct FieldError {
    pub path: String,
    pub code: &'static str,
}

impl FieldError {
    pub fn new(path: impl Into<String>, code: &'static str) -> Self {
        Self {
            path: path.into(),
            code,
        }
    }
}

#[derive(Debug)]
pub struct ApiError {
    status: StatusCode,
    code: &'static str,
    message: &'static str,
    retryable: bool,
    fields: Vec<FieldError>,
    current: Option<Box<Todo>>,
}

#[derive(Serialize)]
struct ErrorBody {
    error: ErrorDetail,
}

#[derive(Serialize)]
struct ErrorDetail {
    code: &'static str,
    message: &'static str,
    request_id: String,
    retryable: bool,
    fields: Vec<FieldError>,
    #[serde(skip_serializing_if = "Option::is_none")]
    current: Option<Box<Todo>>,
}

impl ApiError {
    pub fn validation(fields: Vec<FieldError>) -> Self {
        Self {
            status: StatusCode::UNPROCESSABLE_ENTITY,
            code: "VALIDATION_FAILED",
            message: "Request fields failed validation.",
            retryable: false,
            fields,
            current: None,
        }
    }

    pub fn bad_cursor() -> Self {
        Self {
            status: StatusCode::BAD_REQUEST,
            code: "BAD_CURSOR",
            message: "Cursor is malformed or does not match the current filters.",
            retryable: false,
            fields: Vec::new(),
            current: None,
        }
    }

    pub fn not_found() -> Self {
        Self {
            status: StatusCode::NOT_FOUND,
            code: "NOT_FOUND",
            message: "Todo not found.",
            retryable: false,
            fields: Vec::new(),
            current: None,
        }
    }

    pub fn idempotency_conflict() -> Self {
        Self {
            status: StatusCode::CONFLICT,
            code: "IDEMPOTENCY_CONFLICT",
            message: "The idempotency key was already used with a different request.",
            retryable: false,
            fields: Vec::new(),
            current: None,
        }
    }

    pub fn revision_conflict(current: Todo) -> Self {
        Self {
            status: StatusCode::CONFLICT,
            code: "REVISION_CONFLICT",
            message: "The todo was modified by another client.",
            retryable: false,
            fields: Vec::new(),
            current: Some(Box::new(current)),
        }
    }

    pub fn database_unavailable() -> Self {
        Self {
            status: StatusCode::SERVICE_UNAVAILABLE,
            code: "DATABASE_UNAVAILABLE",
            message: "Database is unavailable.",
            retryable: true,
            fields: Vec::new(),
            current: None,
        }
    }

    pub fn unsupported_media_type() -> Self {
        Self {
            status: StatusCode::UNSUPPORTED_MEDIA_TYPE,
            code: "UNSUPPORTED_MEDIA_TYPE",
            message: "Content-Type must be application/json.",
            retryable: false,
            fields: Vec::new(),
            current: None,
        }
    }

    pub fn response(self, request_id: &str) -> Response {
        let body = ErrorBody {
            error: ErrorDetail {
                code: self.code,
                message: self.message,
                request_id: request_id.to_owned(),
                retryable: self.retryable,
                fields: self.fields,
                current: self.current,
            },
        };
        (self.status, Json(body)).into_response()
    }
}

impl From<sqlx::Error> for ApiError {
    fn from(error: sqlx::Error) -> Self {
        tracing::error!(
            kind = crate::db::error_kind(&error),
            error = %error,
            "todo persistence failed"
        );
        Self::database_unavailable()
    }
}
