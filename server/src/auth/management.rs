use axum::{
    Json, Router,
    extract::{Extension, Request, State},
    http::{HeaderValue, header},
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::get,
};
use serde::Serialize;
use sqlx::PgPool;
use time::OffsetDateTime;
use tower_http::request_id::RequestId;
use uuid::Uuid;

use crate::{
    auth::AuthenticatedUser,
    error::{AppError, request_id},
    response::ApiResponse,
    state::AppState,
};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ManagementScope {
    Campus,
    College(String),
}

impl ManagementScope {
    fn stored(&self) -> (&str, &str) {
        match self {
            Self::Campus => ("campus", ""),
            Self::College(id) => ("college", id),
        }
    }
}

#[derive(Debug, Serialize, PartialEq, Eq)]
pub struct ManagementGrants {
    pub campus: bool,
    pub college_ids: Vec<String>,
}

pub async fn list(pool: &PgPool, user_id: Uuid) -> Result<ManagementGrants, AppError> {
    let rows: Vec<(String, String)> = sqlx::query_as(
        "SELECT scope, college_id FROM management_grants
         WHERE user_id = $1 ORDER BY scope, college_id",
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(store_error)?;

    let mut grants = ManagementGrants {
        campus: false,
        college_ids: Vec::new(),
    };
    for (scope, college_id) in rows {
        if scope == "campus" {
            grants.campus = true;
        } else {
            grants.college_ids.push(college_id);
        }
    }
    Ok(grants)
}

pub async fn require_scope(
    pool: &PgPool,
    user: &AuthenticatedUser,
    scope: &ManagementScope,
) -> Result<(), AppError> {
    let (scope, college_id) = scope.stored();
    let allowed: bool = sqlx::query_scalar(
        "SELECT EXISTS (
            SELECT 1 FROM management_grants g
            JOIN users u ON u.id = g.user_id
            WHERE g.user_id = $1 AND u.disabled_at IS NULL
              AND (g.scope = 'campus' OR (g.scope = $2 AND g.college_id = $3))
         )",
    )
    .bind(user.user_id)
    .bind(scope)
    .bind(college_id)
    .fetch_one(pool)
    .await
    .map_err(store_error)?;

    if allowed {
        Ok(())
    } else {
        Err(AppError::ManagementRequired)
    }
}

pub async fn grant(pool: &PgPool, user_id: Uuid, scope: &ManagementScope) -> anyhow::Result<bool> {
    let mut transaction = pool.begin().await?;
    let disabled_at: Option<Option<OffsetDateTime>> =
        sqlx::query_scalar("SELECT disabled_at FROM users WHERE id = $1 FOR UPDATE")
            .bind(user_id)
            .fetch_optional(&mut *transaction)
            .await?;
    match disabled_at {
        None => anyhow::bail!("target user does not exist: {user_id}"),
        Some(Some(_)) => anyhow::bail!("cannot grant management to a disabled user: {user_id}"),
        Some(None) => {}
    }
    let (scope, college_id) = scope.stored();
    let result = sqlx::query(
        "INSERT INTO management_grants (user_id, scope, college_id)
         VALUES ($1, $2, $3) ON CONFLICT DO NOTHING",
    )
    .bind(user_id)
    .bind(scope)
    .bind(college_id)
    .execute(&mut *transaction)
    .await?;
    transaction.commit().await?;
    Ok(result.rows_affected() != 0)
}

pub async fn revoke(pool: &PgPool, user_id: Uuid, scope: &ManagementScope) -> anyhow::Result<bool> {
    let mut transaction = pool.begin().await?;
    let exists: Option<Uuid> = sqlx::query_scalar("SELECT id FROM users WHERE id = $1 FOR UPDATE")
        .bind(user_id)
        .fetch_optional(&mut *transaction)
        .await?;
    if exists.is_none() {
        anyhow::bail!("target user does not exist: {user_id}");
    }
    let (scope, college_id) = scope.stored();
    let result = sqlx::query(
        "DELETE FROM management_grants WHERE user_id = $1 AND scope = $2 AND college_id = $3",
    )
    .bind(user_id)
    .bind(scope)
    .bind(college_id)
    .execute(&mut *transaction)
    .await?;
    transaction.commit().await?;
    Ok(result.rows_affected() != 0)
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/me/management", get(me))
        .layer(middleware::from_fn(private_response))
}

async fn private_response(request: Request, next: Next) -> Response {
    let mut response = next.run(request).await;
    response.headers_mut().insert(
        header::CACHE_CONTROL,
        HeaderValue::from_static("private, no-store"),
    );
    response
}

async fn me(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(id): Extension<RequestId>,
) -> Response {
    let id = request_id(&id);
    match list(&state.pool, user.user_id).await {
        Ok(grants) => Json(ApiResponse::new(grants, id)).into_response(),
        Err(error) => error.response(&id),
    }
}

fn store_error(error: sqlx::Error) -> AppError {
    tracing::error!(
        error_kind = crate::db::error_kind(&error),
        "management grant store operation failed"
    );
    AppError::Internal
}
