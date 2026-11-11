use axum::{
    extract::FromRequestParts,
    http::{header, request::Parts},
};
use uuid::Uuid;

use crate::{
    auth::session,
    error::{ApiErrorResponse, AppError},
    state::AppState,
};

#[derive(Clone, Debug)]
pub struct AuthenticatedUser {
    pub user_id: Uuid,
    pub session_id: Uuid,
    pub display_name: String,
    pub timezone: String,
}

impl FromRequestParts<AppState> for AuthenticatedUser {
    type Rejection = ApiErrorResponse;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let token = bearer_token(parts)
            .ok_or_else(|| ApiErrorResponse::new(AppError::AuthRequired, &parts.extensions))?;

        let session = session::authenticate(&state.pool, token)
            .await
            .map_err(|error| ApiErrorResponse::new(error, &parts.extensions))?;
        Ok(Self {
            user_id: session.user_id,
            session_id: session.session_id,
            display_name: session.display_name,
            timezone: session.timezone,
        })
    }
}

fn bearer_token(parts: &Parts) -> Option<&str> {
    let authorization = parts.headers.get(header::AUTHORIZATION)?.to_str().ok()?;
    let (scheme, token) = authorization.split_once(' ')?;
    if !scheme.eq_ignore_ascii_case("bearer") {
        return None;
    }
    let token = token.trim();
    (!token.is_empty()).then_some(token)
}
