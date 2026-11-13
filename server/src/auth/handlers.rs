use axum::{
    Json,
    extract::{Extension, State},
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde::{Deserialize, Serialize};
use tower_http::request_id::RequestId;

use crate::{
    auth::{
        extractor::AuthenticatedUser,
        invite, login as login_service, password,
        session::{self, IssuedSession},
        token,
    },
    error::{AppError, FieldError, request_id},
    json::ApiJson,
    response::ApiResponse,
    state::AppState,
};

#[derive(Debug, Serialize)]
pub struct MeData {
    pub id: String,
    pub display_name: String,
    pub timezone: String,
    pub username: Option<String>,
    pub password_set: bool,
    pub student_verified: bool,
    pub college: Option<session::College>,
}

#[derive(Debug, Serialize)]
pub struct TokenData {
    pub access_token: String,
    pub refresh_token: String,
    pub token_type: &'static str,
    pub expires_in: u64,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ActivateRequest {
    pub invite_token: String,
    pub password: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LoginRequest {
    pub login: String,
    pub password: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RefreshRequest {
    pub refresh_token: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LogoutRequest {
    pub refresh_token: String,
}

pub async fn me(
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
) -> Json<ApiResponse<MeData>> {
    Json(ApiResponse::new(
        MeData {
            id: user.user_id.to_string(),
            display_name: user.display_name,
            timezone: user.timezone,
            username: user.username,
            password_set: user.password_set,
            student_verified: user.student_verified,
            college: user.college,
        },
        request_id(&request_id_value),
    ))
}

pub async fn activate(
    State(state): State<AppState>,
    Extension(request_id_value): Extension<RequestId>,
    ApiJson(body): ApiJson<ActivateRequest>,
) -> Response {
    let request_id = request_id(&request_id_value);
    match activate_account(&state, body).await {
        Ok(issued) => Json(ApiResponse::new(TokenData::from(issued), request_id)).into_response(),
        Err(error) => error.response(&request_id),
    }
}

pub async fn login(
    State(state): State<AppState>,
    Extension(request_id_value): Extension<RequestId>,
    ApiJson(body): ApiJson<LoginRequest>,
) -> Response {
    let request_id = request_id(&request_id_value);
    match login_account(&state, body).await {
        Ok(issued) => Json(ApiResponse::new(TokenData::from(issued), request_id)).into_response(),
        Err(error) => error.response(&request_id),
    }
}

pub async fn refresh(
    State(state): State<AppState>,
    Extension(request_id_value): Extension<RequestId>,
    ApiJson(body): ApiJson<RefreshRequest>,
) -> Response {
    let request_id = request_id(&request_id_value);
    match rotate(&state, &body.refresh_token).await {
        Ok(issued) => Json(ApiResponse::new(TokenData::from(issued), request_id)).into_response(),
        Err(error) => error.response(&request_id),
    }
}

pub async fn logout(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
    ApiJson(body): ApiJson<LogoutRequest>,
) -> Response {
    let request_id = request_id(&request_id_value);
    match revoke(&state, &user, &body.refresh_token).await {
        Ok(()) => {
            tracing::info!(
                request_id,
                user_id = %user.user_id,
                session_id = %user.session_id,
                "session revoked"
            );
            StatusCode::NO_CONTENT.into_response()
        }
        Err(error) => error.response(&request_id),
    }
}

async fn activate_account(
    state: &AppState,
    body: ActivateRequest,
) -> Result<IssuedSession, AppError> {
    validate_invite_token(&body.invite_token)?;
    password::validate_new(&body.password)?;
    invite::activate(&state.pool, &body.invite_token, &body.password).await
}

async fn login_account(state: &AppState, body: LoginRequest) -> Result<IssuedSession, AppError> {
    let login = login_service::normalize(&body.login);
    login_service::validate(&login)?;
    password::validate_attempt(&body.password)?;
    login_service::authenticate(&state.pool, &login, &body.password).await
}

async fn rotate(state: &AppState, refresh_token: &str) -> Result<IssuedSession, AppError> {
    validate_refresh_token(refresh_token)?;
    session::rotate(&state.pool, refresh_token).await
}

async fn revoke(
    state: &AppState,
    user: &AuthenticatedUser,
    refresh_token: &str,
) -> Result<(), AppError> {
    validate_refresh_token(refresh_token)?;
    session::revoke(&state.pool, user.session_id, refresh_token).await
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PhoneCodeRequest {
    pub phone: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PhoneLoginRequest {
    pub phone: String,
    pub sms_code: String,
}

#[derive(Serialize)]
pub struct PhoneCodeData {
    pub expires_in: u64,
    pub retry_after: u64,
    pub dev_mode: bool,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AccountUpdateRequest {
    #[serde(default, deserialize_with = "present_string")]
    pub username: Option<String>,
    #[serde(default, deserialize_with = "present_string")]
    pub display_name: Option<String>,
    #[serde(default, deserialize_with = "present_string")]
    pub password: Option<String>,
}

fn present_string<'de, D>(deserializer: D) -> Result<Option<String>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    String::deserialize(deserializer).map(Some)
}

pub async fn send_phone_code(
    State(state): State<AppState>,
    Extension(id): Extension<RequestId>,
    ApiJson(body): ApiJson<PhoneCodeRequest>,
) -> Response {
    let id = request_id(&id);
    match super::phone::request_code(&state.pool, state.sms_sender.as_ref(), &body.phone).await {
        Ok(()) => Json(ApiResponse::new(
            PhoneCodeData {
                expires_in: 300,
                retry_after: 60,
                dev_mode: state.sms_sender.dev_mode(),
            },
            id,
        ))
        .into_response(),
        Err(error) => error.response(&id),
    }
}

pub async fn phone_login(
    State(state): State<AppState>,
    Extension(id): Extension<RequestId>,
    ApiJson(body): ApiJson<PhoneLoginRequest>,
) -> Response {
    let id = request_id(&id);
    match super::phone::authenticate(&state.pool, &body.phone, &body.sms_code).await {
        Ok(issued) => Json(ApiResponse::new(TokenData::from(issued), id)).into_response(),
        Err(error) => error.response(&id),
    }
}

pub async fn update_account(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(id): Extension<RequestId>,
    ApiJson(body): ApiJson<AccountUpdateRequest>,
) -> Response {
    let request_id_value = request_id(&id);
    match super::account::update(
        &state.pool,
        user.user_id,
        body.username.as_deref(),
        body.display_name.as_deref(),
        body.password.as_deref(),
    )
    .await
    {
        Ok(account) => {
            let updated = AuthenticatedUser {
                username: account.username,
                display_name: account.display_name,
                password_set: account.password_set,
                ..user
            };
            me(updated, Extension(id)).await.into_response()
        }
        Err(error) => error.response(&request_id_value),
    }
}

pub async fn verify_student_report(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(id): Extension<RequestId>,
    ApiJson(body): ApiJson<super::student::StudentReportRequest>,
) -> Response {
    let request_id_value = request_id(&id);
    let result = async {
        super::student::StudentVerifier::new()?
            .verify_and_bind(&state.pool, user.user_id, &body.report_code)
            .await
    }
    .await;
    match result {
        Ok(identity) => me(
            AuthenticatedUser {
                student_verified: identity.student_verified,
                college: identity.college,
                ..user
            },
            Extension(id),
        )
        .await
        .into_response(),
        Err(error) => student_error(error).response(&request_id_value),
    }
}

fn student_error(error: super::student::StudentReportError) -> AppError {
    use super::student::StudentReportError;
    match error {
        StudentReportError::Invalid => AppError::StudentReportInvalid,
        StudentReportError::Restricted => AppError::StudentReportRestricted,
        StudentReportError::ParseFailed => AppError::StudentReportParseFailed,
        StudentReportError::NotEligible => AppError::StudentNotEligible,
        StudentReportError::Unavailable => AppError::StudentVerificationUnavailable,
        StudentReportError::Store => AppError::Internal,
    }
}

impl From<IssuedSession> for TokenData {
    fn from(issued: IssuedSession) -> Self {
        Self {
            access_token: issued.access_token,
            refresh_token: issued.refresh_token,
            token_type: "Bearer",
            expires_in: token::ACCESS_TTL.as_secs(),
        }
    }
}

fn validate_invite_token(value: &str) -> Result<(), AppError> {
    if value.trim().is_empty() {
        return Err(AppError::Validation(vec![FieldError::new(
            "invite_token",
            "required",
        )]));
    }
    if value.len() > 512 {
        return Err(AppError::Validation(vec![FieldError::new(
            "invite_token",
            "too_long",
        )]));
    }
    Ok(())
}

fn validate_refresh_token(value: &str) -> Result<(), AppError> {
    if value.trim().is_empty() {
        return Err(AppError::Validation(vec![FieldError::new(
            "refresh_token",
            "required",
        )]));
    }
    if value.len() > 512 {
        return Err(AppError::Validation(vec![FieldError::new(
            "refresh_token",
            "too_long",
        )]));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn restricted_report_query_is_not_an_account_authentication_failure() {
        let response = student_error(super::super::student::StudentReportError::Restricted)
            .response("report-restricted-test");
        assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
        assert!(
            !response
                .headers()
                .contains_key(axum::http::header::WWW_AUTHENTICATE)
        );
        let bytes = axum::body::to_bytes(response.into_body(), 4096)
            .await
            .unwrap();
        let body: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
        assert_eq!(body["error"]["code"], "STUDENT_REPORT_RESTRICTED");
        assert_eq!(body["error"]["retryable"], true);
        assert!(body.get("data").is_none());
    }
}
