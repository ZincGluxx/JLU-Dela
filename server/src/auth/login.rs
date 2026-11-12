use sqlx::PgPool;
use time::{Duration, OffsetDateTime};

use crate::{
    auth::{
        password,
        session::{self, IssuedSession},
        token,
    },
    db,
    error::{AppError, FieldError},
};

pub const MAX_FAILURES: i32 = 5;
pub const FAILURE_WINDOW_MINUTES: i32 = 15;
pub const LOCK: Duration = Duration::minutes(15);

#[derive(sqlx::FromRow)]
struct UserRow {
    id: uuid::Uuid,
    password_hash: Option<String>,
    disabled_at: Option<OffsetDateTime>,
}

pub fn normalize(login: &str) -> String {
    login.trim().to_lowercase()
}

pub fn validate(login: &str) -> Result<(), AppError> {
    let length = login.chars().count();
    if length < 4 {
        return Err(AppError::Validation(vec![FieldError::new(
            "login",
            "too_short",
        )]));
    }
    if length > 64 {
        return Err(AppError::Validation(vec![FieldError::new(
            "login", "too_long",
        )]));
    }
    if !login.chars().all(|character| {
        character.is_ascii_lowercase() || character.is_ascii_digit() || "._-".contains(character)
    }) {
        return Err(AppError::Validation(vec![FieldError::new(
            "login",
            "invalid_format",
        )]));
    }
    Ok(())
}

pub async fn authenticate(
    pool: &PgPool,
    login: &str,
    password: &str,
) -> Result<IssuedSession, AppError> {
    let now = OffsetDateTime::now_utc();
    let login_hash = token::digest(login);

    sqlx::query("DELETE FROM login_attempts WHERE window_started_at < now() - interval '1 day'")
        .execute(pool)
        .await
        .map_err(store_error)?;

    if let Some(locked_until) = locked_until(pool, &login_hash).await?
        && locked_until > now
    {
        return Err(AppError::RateLimited {
            retry_after: retry_after_seconds(locked_until - now),
        });
    }

    let user: Option<UserRow> =
        sqlx::query_as("SELECT id, password_hash, disabled_at FROM users WHERE login = $1")
            .bind(login)
            .fetch_optional(pool)
            .await
            .map_err(store_error)?;

    let Some(user) = user else {
        password::verify_dummy(password);
        record_failure(pool, &login_hash, now).await?;
        return Err(AppError::InvalidCredentials);
    };

    let verified = match user.password_hash.as_deref() {
        Some(encoded) if user.disabled_at.is_none() => password::verify(password, encoded),
        _ => {
            password::verify_dummy(password);
            false
        }
    };
    if !verified {
        record_failure(pool, &login_hash, now).await?;
        return Err(AppError::InvalidCredentials);
    }

    sqlx::query("DELETE FROM login_attempts WHERE login_hash = $1")
        .bind(&login_hash)
        .execute(pool)
        .await
        .map_err(store_error)?;

    session::issue_for_user(pool, user.id).await
}

async fn locked_until(pool: &PgPool, login_hash: &str) -> Result<Option<OffsetDateTime>, AppError> {
    let locked = sqlx::query_scalar::<_, Option<OffsetDateTime>>(
        "SELECT locked_until FROM login_attempts WHERE login_hash = $1",
    )
    .bind(login_hash)
    .fetch_optional(pool)
    .await
    .map_err(store_error)?;
    Ok(locked.flatten())
}

async fn record_failure(
    pool: &PgPool,
    login_hash: &str,
    now: OffsetDateTime,
) -> Result<(), AppError> {
    let failures: i32 = sqlx::query_scalar(
        "INSERT INTO login_attempts (login_hash, failures, window_started_at, locked_until)
         VALUES ($1, 1, $2, NULL)
         ON CONFLICT (login_hash) DO UPDATE SET
             failures = CASE
                 WHEN login_attempts.locked_until IS NOT NULL AND login_attempts.locked_until <= $2 THEN 1
                 WHEN login_attempts.window_started_at <= $2 - make_interval(mins => $3) THEN 1
                 ELSE login_attempts.failures + 1
             END,
             window_started_at = CASE
                 WHEN login_attempts.locked_until IS NOT NULL AND login_attempts.locked_until <= $2 THEN $2
                 WHEN login_attempts.window_started_at <= $2 - make_interval(mins => $3) THEN $2
                 ELSE login_attempts.window_started_at
             END,
             locked_until = NULL
         RETURNING failures",
    )
    .bind(login_hash)
    .bind(now)
    .bind(FAILURE_WINDOW_MINUTES)
    .fetch_one(pool)
    .await
    .map_err(store_error)?;

    if failures >= MAX_FAILURES {
        sqlx::query(
            "UPDATE login_attempts SET locked_until = $2 WHERE login_hash = $1 AND locked_until IS NULL",
        )
        .bind(login_hash)
        .bind(now + LOCK)
        .execute(pool)
        .await
        .map_err(store_error)?;
    }
    Ok(())
}

fn retry_after_seconds(remaining: Duration) -> u64 {
    remaining.as_seconds_f64().ceil().max(1.0) as u64
}

fn store_error(error: sqlx::Error) -> AppError {
    tracing::error!(
        error_kind = db::error_kind(&error),
        "login store operation failed"
    );
    AppError::Internal
}
