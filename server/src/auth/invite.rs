use std::fmt;

use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use sqlx::PgPool;
use time::{Duration, OffsetDateTime};
use uuid::Uuid;

use crate::{
    auth::{
        password,
        session::{self, IssuedSession},
        token,
    },
    error::AppError,
};

const TOKEN_PREFIX: &str = "inv_";
const TOKEN_BYTES: usize = 32;

pub struct IssuedInvite {
    pub token: String,
    pub expires_at: OffsetDateTime,
}

pub enum CreateError {
    LoginExists,
    ActiveInvitation,
    Store(sqlx::Error),
}

impl fmt::Display for CreateError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::LoginExists => write!(formatter, "the login already has a workbench account"),
            Self::ActiveInvitation => {
                write!(formatter, "the login already has an active invitation")
            }
            Self::Store(_) => write!(formatter, "the invitation could not be stored"),
        }
    }
}

impl fmt::Debug for CreateError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(self, formatter)
    }
}

impl std::error::Error for CreateError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::Store(error) => Some(error),
            _ => None,
        }
    }
}

pub async fn create(
    pool: &PgPool,
    login: &str,
    display_name: &str,
    ttl: Duration,
) -> Result<IssuedInvite, CreateError> {
    let mut transaction = pool.begin().await.map_err(CreateError::Store)?;

    let existing: Option<Uuid> = sqlx::query_scalar("SELECT id FROM users WHERE login = $1")
        .bind(login)
        .fetch_optional(&mut *transaction)
        .await
        .map_err(CreateError::Store)?;
    if existing.is_some() {
        return Err(CreateError::LoginExists);
    }

    sqlx::query(
        "UPDATE invites SET used_at = now()
         WHERE login = $1 AND used_at IS NULL AND expires_at <= now()",
    )
    .bind(login)
    .execute(&mut *transaction)
    .await
    .map_err(CreateError::Store)?;

    let token = issue_token();
    let token_hash = token::digest(&token);
    let now = OffsetDateTime::now_utc();
    let expires_at = now + ttl;

    sqlx::query(
        "INSERT INTO invites (id, login, display_name, token_hash, expires_at, created_at)
         VALUES ($1, $2, $3, $4, $5, $6)",
    )
    .bind(Uuid::new_v4())
    .bind(login)
    .bind(display_name)
    .bind(token_hash)
    .bind(expires_at)
    .bind(now)
    .execute(&mut *transaction)
    .await
    .map_err(active_invitation_or_store)?;

    transaction.commit().await.map_err(CreateError::Store)?;

    Ok(IssuedInvite { token, expires_at })
}

pub async fn activate(
    pool: &PgPool,
    token_value: &str,
    password_value: &str,
) -> Result<IssuedSession, AppError> {
    let mut transaction = pool.begin().await.map_err(store_error)?;

    let invite: Option<InviteRow> = sqlx::query_as(
        "SELECT id, login, display_name, used_at, expires_at
         FROM invites
         WHERE token_hash = $1
         FOR UPDATE",
    )
    .bind(token::digest(token_value))
    .fetch_optional(&mut *transaction)
    .await
    .map_err(store_error)?;

    let now = OffsetDateTime::now_utc();
    let Some(invite) = invite else {
        return Err(AppError::InvalidInvite);
    };
    if invite.used_at.is_some() || invite.expires_at <= now {
        return Err(AppError::InvalidInvite);
    }

    password::ensure_differs_from_login(password_value, &invite.login)?;
    let password_hash = password::hash_async(password_value).await?;
    let user_id = Uuid::new_v4();

    sqlx::query(
        "INSERT INTO users (id, login, display_name, timezone, password_hash, created_at)
         VALUES ($1, $2, $3, 'Asia/Shanghai', $4, $5)",
    )
    .bind(user_id)
    .bind(&invite.login)
    .bind(&invite.display_name)
    .bind(password_hash)
    .bind(now)
    .execute(&mut *transaction)
    .await
    .map_err(store_error)?;

    sqlx::query("UPDATE invites SET used_at = $2, used_by = $3 WHERE id = $1")
        .bind(invite.id)
        .bind(now)
        .bind(user_id)
        .execute(&mut *transaction)
        .await
        .map_err(store_error)?;

    let issued = session::issue_for_user(&mut *transaction, user_id).await?;
    transaction.commit().await.map_err(store_error)?;

    Ok(issued)
}

#[derive(sqlx::FromRow)]
struct InviteRow {
    id: Uuid,
    login: String,
    display_name: String,
    used_at: Option<OffsetDateTime>,
    expires_at: OffsetDateTime,
}

fn issue_token() -> String {
    let mut bytes = [0_u8; TOKEN_BYTES];
    getrandom::fill(&mut bytes).expect("operating system randomness is available");
    format!("{TOKEN_PREFIX}{}", URL_SAFE_NO_PAD.encode(bytes))
}

fn active_invitation_or_store(error: sqlx::Error) -> CreateError {
    let is_active_login = error
        .as_database_error()
        .and_then(|database_error| database_error.constraint())
        .is_some_and(|constraint| constraint == "invites_active_login_key");
    if is_active_login {
        CreateError::ActiveInvitation
    } else {
        CreateError::Store(error)
    }
}

fn store_error(error: sqlx::Error) -> AppError {
    tracing::error!(
        error_kind = crate::db::error_kind(&error),
        "invitation store operation failed"
    );
    AppError::Internal
}
