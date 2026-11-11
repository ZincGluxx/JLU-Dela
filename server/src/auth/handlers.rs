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
        },
        request_id(&request_id_value),
    ))
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
