use sqlx::{Executor, PgPool, Postgres};
use time::OffsetDateTime;
use uuid::Uuid;

use crate::{
    auth::token::{self, TokenPair},
    error::AppError,
};

#[derive(Debug)]
pub struct IssuedSession {
    pub session_id: Uuid,
    pub access_token: String,
    pub refresh_token: String,
    pub access_expires_at: OffsetDateTime,
    pub refresh_expires_at: OffsetDateTime,
}

#[derive(Clone, Debug, serde::Serialize)]
pub struct College {
    pub id: String,
    pub name: String,
}

#[derive(Debug)]
pub struct AuthenticatedSession {
    pub session_id: Uuid,
    pub user_id: Uuid,
    pub display_name: String,
    pub timezone: String,
    pub username: Option<String>,
    pub password_set: bool,
    pub student_verified: bool,
    pub college: Option<College>,
}

#[derive(sqlx::FromRow)]
struct AuthRow {
    session_id: Uuid,
    user_id: Uuid,
    display_name: String,
    timezone: String,
    username: Option<String>,
    password_set: bool,
    access_expires_at: OffsetDateTime,
    revoked_at: Option<OffsetDateTime>,
    disabled_at: Option<OffsetDateTime>,
}

pub async fn issue_for_user<'e, E>(executor: E, user_id: Uuid) -> Result<IssuedSession, AppError>
where
    E: Executor<'e, Database = Postgres>,
{
    let now = OffsetDateTime::now_utc();
    let tokens = TokenPair::issue();
    let session_id = Uuid::new_v4();
    let access_expires_at = now + token::ACCESS_TTL;
    let refresh_expires_at = now + token::REFRESH_TTL;

    sqlx::query(
        "INSERT INTO sessions (
            id, user_id, access_token_hash, refresh_token_hash,
            access_expires_at, refresh_expires_at, created_at, last_used_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $7)",
    )
    .bind(session_id)
    .bind(user_id)
    .bind(token::digest(&tokens.access))
    .bind(token::digest(&tokens.refresh))
    .bind(access_expires_at)
    .bind(refresh_expires_at)
    .bind(now)
    .execute(executor)
    .await
    .map_err(store_error)?;

    Ok(IssuedSession {
        session_id,
        access_token: tokens.access,
        refresh_token: tokens.refresh,
        access_expires_at,
        refresh_expires_at,
    })
}

pub async fn rotate(pool: &PgPool, refresh_token: &str) -> Result<IssuedSession, AppError> {
    let now = OffsetDateTime::now_utc();
    let mut transaction = pool.begin().await.map_err(store_error)?;

    let existing: Option<(Uuid, OffsetDateTime)> = sqlx::query_as(
        "SELECT id, refresh_expires_at
         FROM sessions
         WHERE refresh_token_hash = $1 AND revoked_at IS NULL
         FOR UPDATE",
    )
    .bind(token::digest(refresh_token))
    .fetch_optional(&mut *transaction)
    .await
    .map_err(store_error)?;

    let Some((session_id, refresh_expires_at)) = existing else {
        transaction.rollback().await.map_err(store_error)?;
        return Err(AppError::InvalidToken);
    };

    if refresh_expires_at <= now {
        sqlx::query(
            "UPDATE sessions SET revoked_at = $2, revoked_reason = 'refresh_expired' WHERE id = $1",
        )
        .bind(session_id)
        .bind(now)
        .execute(&mut *transaction)
        .await
        .map_err(store_error)?;
        transaction.commit().await.map_err(store_error)?;
        return Err(AppError::TokenExpired);
    }

    let tokens = TokenPair::issue();
    let access_expires_at = now + token::ACCESS_TTL;
    let next_refresh_expires_at = now + token::REFRESH_TTL;

    sqlx::query(
        "UPDATE sessions SET
            access_token_hash = $2,
            refresh_token_hash = $3,
            access_expires_at = $4,
            refresh_expires_at = $5,
            last_used_at = $6
         WHERE id = $1",
    )
    .bind(session_id)
    .bind(token::digest(&tokens.access))
    .bind(token::digest(&tokens.refresh))
    .bind(access_expires_at)
    .bind(next_refresh_expires_at)
    .bind(now)
    .execute(&mut *transaction)
    .await
    .map_err(store_error)?;

    transaction.commit().await.map_err(store_error)?;

    Ok(IssuedSession {
        session_id,
        access_token: tokens.access,
        refresh_token: tokens.refresh,
        access_expires_at,
        refresh_expires_at: next_refresh_expires_at,
    })
}

pub async fn revoke(pool: &PgPool, session_id: Uuid, refresh_token: &str) -> Result<(), AppError> {
    let updated = sqlx::query(
        "UPDATE sessions
         SET revoked_at = $3, revoked_reason = 'logout'
         WHERE id = $1 AND refresh_token_hash = $2 AND revoked_at IS NULL",
    )
    .bind(session_id)
    .bind(token::digest(refresh_token))
    .bind(OffsetDateTime::now_utc())
    .execute(pool)
    .await
    .map_err(store_error)?;

    if updated.rows_affected() == 0 {
        return Err(AppError::InvalidToken);
    }
    Ok(())
}

pub async fn authenticate(
    pool: &PgPool,
    access_token: &str,
) -> Result<AuthenticatedSession, AppError> {
    let row: Option<AuthRow> = sqlx::query_as(
        "SELECT
            s.id AS session_id,
            s.user_id,
            u.display_name,
            u.timezone,
            u.login AS username,
            (u.password_hash IS NOT NULL) AS password_set,
            s.access_expires_at,
            s.revoked_at,
            u.disabled_at
         FROM sessions s
         JOIN users u ON u.id = s.user_id
         WHERE s.access_token_hash = $1",
    )
    .bind(token::digest(access_token))
    .fetch_optional(pool)
    .await
    .map_err(store_error)?;

    let Some(row) = row else {
        return Err(AppError::InvalidToken);
    };
    if row.revoked_at.is_some() {
        return Err(AppError::SessionRevoked);
    }
    if row.disabled_at.is_some() {
        return Err(AppError::InvalidToken);
    }
    if row.access_expires_at <= OffsetDateTime::now_utc() {
        return Err(AppError::TokenExpired);
    }

    let identity = super::student::load_identity(pool, row.user_id)
        .await
        .map_err(|_| AppError::Internal)?;
    Ok(AuthenticatedSession {
        session_id: row.session_id,
        user_id: row.user_id,
        display_name: row.display_name,
        timezone: row.timezone,
        username: row.username,
        password_set: row.password_set,
        student_verified: identity.student_verified,
        college: identity.college,
    })
}

fn store_error(error: sqlx::Error) -> AppError {
    tracing::error!(
        error_kind = crate::db::error_kind(&error),
        "session store operation failed"
    );
    AppError::Internal
}
