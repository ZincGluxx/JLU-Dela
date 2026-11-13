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
    FileNotFound,
    FileInUse,
    FileStorageUnavailable,
    MethodNotAllowed,
    PayloadTooLarge,
    RequestTimeout,
    UnsupportedMediaType,
    InvalidBody,
    Validation(Vec<FieldError>),
    UnsupportedSource,
    UnsupportedResource,
    SyncJobNotFound,
    AcademicCalendarNotFound,
    AuthRequired,
    InvalidToken,
    TokenExpired,
    SessionRevoked,
    InvalidInvite,
    InvalidCredentials,
    RateLimited { retry_after: u64 },
    SmsUnavailable,
    SmsSendFailed,
    InvalidSmsCode,
    SmsCodeExpired,
    UsernameTaken,
    StudentReportInvalid,
    StudentReportRestricted,
    StudentReportParseFailed,
    StudentNotEligible,
    StudentVerificationUnavailable,
    StudentRequired,
    CollegeRequired,
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
        let (status, code, message, retryable, fields, retry_after) = match self {
            Self::DatabaseUnavailable => (
                StatusCode::SERVICE_UNAVAILABLE,
                "DATABASE_UNAVAILABLE",
                "Database is unavailable.".to_owned(),
                true,
                Vec::new(),
                None,
            ),
            Self::DatabaseSchemaMissing => (
                StatusCode::SERVICE_UNAVAILABLE,
                "DATABASE_SCHEMA_MISSING",
                "Database schema is not ready.".to_owned(),
                true,
                Vec::new(),
                None,
            ),
            Self::FileNotFound => (
                StatusCode::NOT_FOUND,
                "FILE_NOT_FOUND",
                "File not found.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::FileInUse => (
                StatusCode::CONFLICT,
                "FILE_IN_USE",
                "File is attached to a business object.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::FileStorageUnavailable => (
                StatusCode::SERVICE_UNAVAILABLE,
                "FILE_STORAGE_UNAVAILABLE",
                "File storage is unavailable.".to_owned(),
                true,
                Vec::new(),
                None,
            ),
            Self::NotFound => (
                StatusCode::NOT_FOUND,
                "NOT_FOUND",
                "Route not found.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::MethodNotAllowed => (
                StatusCode::METHOD_NOT_ALLOWED,
                "METHOD_NOT_ALLOWED",
                "Method not allowed.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::PayloadTooLarge => (
                StatusCode::PAYLOAD_TOO_LARGE,
                "PAYLOAD_TOO_LARGE",
                "Request body is too large.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::RequestTimeout => (
                StatusCode::REQUEST_TIMEOUT,
                "REQUEST_TIMEOUT",
                "Request timed out.".to_owned(),
                true,
                Vec::new(),
                None,
            ),
            Self::UnsupportedMediaType => (
                StatusCode::UNSUPPORTED_MEDIA_TYPE,
                "UNSUPPORTED_MEDIA_TYPE",
                "Content-Type must be application/json.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::InvalidBody => (
                StatusCode::UNPROCESSABLE_ENTITY,
                "INVALID_REQUEST_BODY",
                "Request body is invalid or contains unknown fields.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::Validation(fields) => (
                StatusCode::UNPROCESSABLE_ENTITY,
                "VALIDATION_FAILED",
                "Request validation failed.".to_owned(),
                false,
                fields,
                None,
            ),
            Self::UnsupportedSource => (
                StatusCode::UNPROCESSABLE_ENTITY,
                "UNSUPPORTED_SOURCE",
                "No source adapter is registered for this source.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::UnsupportedResource => (
                StatusCode::UNPROCESSABLE_ENTITY,
                "UNSUPPORTED_RESOURCE",
                "The source does not support this resource.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::AcademicCalendarNotFound => (
                StatusCode::NOT_FOUND,
                "ACADEMIC_CALENDAR_NOT_FOUND",
                "Academic calendar not found for the requested academic year.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::SyncJobNotFound => (
                StatusCode::NOT_FOUND,
                "SYNC_JOB_NOT_FOUND",
                "Sync job not found.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::AuthRequired => (
                StatusCode::UNAUTHORIZED,
                "AUTH_REQUIRED",
                "Authentication required.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::InvalidToken => (
                StatusCode::UNAUTHORIZED,
                "INVALID_TOKEN",
                "The access token is invalid or no longer current.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::TokenExpired => (
                StatusCode::UNAUTHORIZED,
                "TOKEN_EXPIRED",
                "The access token has expired.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::SessionRevoked => (
                StatusCode::UNAUTHORIZED,
                "SESSION_REVOKED",
                "The session has been revoked.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::InvalidInvite => (
                StatusCode::UNAUTHORIZED,
                "INVALID_INVITE",
                "The invitation is invalid, expired or already used.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::InvalidCredentials => (
                StatusCode::UNAUTHORIZED,
                "INVALID_CREDENTIALS",
                "The login or password is invalid.".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::RateLimited { retry_after } => (
                StatusCode::TOO_MANY_REQUESTS,
                "RATE_LIMITED",
                "Too many login attempts. Try again later.".to_owned(),
                true,
                Vec::new(),
                Some(retry_after),
            ),
            Self::SmsUnavailable => (
                StatusCode::SERVICE_UNAVAILABLE,
                "SMS_UNAVAILABLE",
                "短信服务未配置，暂时无法发送验证码。".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::SmsSendFailed => (
                StatusCode::SERVICE_UNAVAILABLE,
                "SMS_SEND_FAILED",
                "短信发送失败，请稍后重试。".to_owned(),
                true,
                Vec::new(),
                None,
            ),
            Self::InvalidSmsCode => (
                StatusCode::UNPROCESSABLE_ENTITY,
                "INVALID_SMS_CODE",
                "短信验证码错误或已使用，请重新获取。".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::SmsCodeExpired => (
                StatusCode::UNPROCESSABLE_ENTITY,
                "SMS_CODE_EXPIRED",
                "短信验证码已过期，请重新获取。".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::UsernameTaken => (
                StatusCode::CONFLICT,
                "USERNAME_TAKEN",
                "用户名已被使用，请更换".to_owned(),
                false,
                vec![FieldError::new("username", "already_used")],
                None,
            ),
            Self::StudentReportInvalid => (
                StatusCode::UNPROCESSABLE_ENTITY,
                "STUDENT_REPORT_INVALID",
                "报告在线验证码无效。".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::StudentReportRestricted => (
                StatusCode::SERVICE_UNAVAILABLE,
                "STUDENT_REPORT_RESTRICTED",
                "学信网查询需要人工交互或暂时受限，请稍后重试。".to_owned(),
                true,
                Vec::new(),
                None,
            ),
            Self::StudentReportParseFailed => (
                StatusCode::SERVICE_UNAVAILABLE,
                "STUDENT_REPORT_PARSE_FAILED",
                "暂时无法确认报告内容，学籍报告核验未通过。".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::StudentNotEligible => (
                StatusCode::UNPROCESSABLE_ENTITY,
                "STUDENT_NOT_ELIGIBLE",
                "报告未能确认吉林大学学籍。".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::StudentVerificationUnavailable => (
                StatusCode::SERVICE_UNAVAILABLE,
                "STUDENT_VERIFICATION_UNAVAILABLE",
                "学籍报告查询暂时不可用。".to_owned(),
                true,
                Vec::new(),
                None,
            ),
            Self::StudentRequired => (
                StatusCode::FORBIDDEN,
                "STUDENT_REQUIRED",
                "此操作需要通过学籍报告核验。".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::CollegeRequired => (
                StatusCode::FORBIDDEN,
                "COLLEGE_REQUIRED",
                "当前账号没有该学院的访问资格。".to_owned(),
                false,
                Vec::new(),
                None,
            ),
            Self::Internal => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "INTERNAL_ERROR",
                "The service could not complete the request.".to_owned(),
                true,
                Vec::new(),
                None,
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
        if let Some(seconds) = retry_after {
            response
                .headers_mut()
                .insert(header::RETRY_AFTER, HeaderValue::from(seconds));
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
