use sqlx::PgPool;
use uuid::Uuid;

use crate::{
    auth::password,
    error::{AppError, FieldError},
};

#[derive(Debug, sqlx::FromRow)]
pub struct Account {
    pub username: Option<String>,
    pub display_name: String,
    pub password_set: bool,
}

pub fn validate_username(username: &str) -> Result<(), AppError> {
    if !(6..=10).contains(&username.len())
        || !username
            .bytes()
            .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit())
    {
        return Err(AppError::Validation(vec![FieldError::new(
            "username",
            "invalid_format",
        )]));
    }
    Ok(())
}

pub async fn get(pool: &PgPool, user_id: Uuid) -> Result<Account, AppError> {
    sqlx::query_as("SELECT login AS username, display_name, password_hash IS NOT NULL AS password_set FROM users WHERE id = $1 AND disabled_at IS NULL")
        .bind(user_id).fetch_optional(pool).await.map_err(store_error)?
        .ok_or(AppError::AuthRequired)
}

pub async fn update(
    pool: &PgPool,
    user_id: Uuid,
    username: Option<&str>,
    display_name: Option<&str>,
    password_value: Option<&str>,
) -> Result<Account, AppError> {
    if let Some(username) = username {
        validate_username(username)?;
    }
    let display_name = display_name.map(str::trim);
    if let Some(display_name) = display_name
        && (display_name.is_empty() || display_name.chars().count() > 128)
    {
        return Err(AppError::Validation(vec![FieldError::new(
            "display_name",
            "invalid_length",
        )]));
    }
    if let Some(value) = password_value {
        password::validate_new(value)?;
    }
    let mut transaction = pool.begin().await.map_err(store_error)?;
    let current: Option<Option<String>> = sqlx::query_scalar(
        "SELECT login FROM users WHERE id = $1 AND disabled_at IS NULL FOR UPDATE",
    )
    .bind(user_id)
    .fetch_optional(&mut *transaction)
    .await
    .map_err(store_error)?;
    current.ok_or(AppError::AuthRequired)?;
    let password_hash = if let Some(value) = password_value {
        Some(password::hash_async(value).await?)
    } else {
        None
    };
    let account = sqlx::query_as("UPDATE users SET login = COALESCE($2, login), display_name = COALESCE($3, display_name), password_hash = COALESCE($4, password_hash) WHERE id = $1 RETURNING login AS username, display_name, password_hash IS NOT NULL AS password_set")
        .bind(user_id).bind(username).bind(display_name).bind(password_hash)
        .fetch_one(&mut *transaction).await.map_err(|error| {
            if error.as_database_error().and_then(|error| error.constraint()) == Some("users_login_key") {
                AppError::UsernameTaken
            } else { store_error(error) }
        })?;
    transaction.commit().await.map_err(store_error)?;
    Ok(account)
}

fn store_error(error: sqlx::Error) -> AppError {
    tracing::error!(
        error_kind = crate::db::error_kind(&error),
        "account store operation failed"
    );
    AppError::Internal
}
