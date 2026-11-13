use std::{future::Future, pin::Pin};

use sqlx::PgPool;
use time::{Duration, OffsetDateTime};
use uuid::Uuid;

use crate::{
    auth::{
        password,
        session::{self, IssuedSession},
    },
    error::{AppError, FieldError},
};

pub const CODE_TTL: Duration = Duration::minutes(5);
pub const SEND_COOLDOWN: Duration = Duration::seconds(60);
pub const MAX_ATTEMPTS: i32 = 5;
pub const MAX_SENDS_PER_HOUR: i32 = 10;

pub type SendFuture<'a> = Pin<Box<dyn Future<Output = Result<(), AppError>> + Send + 'a>>;

pub trait SmsSender: Send + Sync {
    fn send<'a>(&'a self, phone: &'a str, code: &'a str) -> SendFuture<'a>;

    fn dev_mode(&self) -> bool {
        false
    }
}

pub fn configured_sender(config: &crate::config::Config) -> std::sync::Arc<dyn SmsSender> {
    #[cfg(debug_assertions)]
    if config.dev_sms_fixed_code_enabled && config.host.is_loopback() {
        return std::sync::Arc::new(DevelopmentSmsSender);
    }
    #[cfg(not(debug_assertions))]
    let _ = config;
    std::sync::Arc::new(UnavailableSmsSender)
}

#[cfg(debug_assertions)]
struct DevelopmentSmsSender;

#[cfg(debug_assertions)]
impl SmsSender for DevelopmentSmsSender {
    fn send<'a>(&'a self, _phone: &'a str, _code: &'a str) -> SendFuture<'a> {
        Box::pin(async { Ok(()) })
    }

    fn dev_mode(&self) -> bool {
        true
    }
}

pub struct UnavailableSmsSender;

impl SmsSender for UnavailableSmsSender {
    fn send<'a>(&'a self, _phone: &'a str, _code: &'a str) -> SendFuture<'a> {
        Box::pin(async { Err(AppError::SmsUnavailable) })
    }
}

pub fn normalize(phone: &str) -> Result<String, AppError> {
    let phone = phone.trim();
    let local = phone.strip_prefix("+86").unwrap_or(phone);
    if local.len() != 11
        || !local.bytes().all(|byte| byte.is_ascii_digit())
        || !local.starts_with('1')
        || !(b'3'..=b'9').contains(&local.as_bytes()[1])
    {
        return Err(AppError::Validation(vec![FieldError::new(
            "phone",
            "invalid_format",
        )]));
    }
    Ok(format!("+86{local}"))
}

#[derive(sqlx::FromRow)]
struct CodeRow {
    code_hash: String,
    expires_at: OffsetDateTime,
    sent_at: OffsetDateTime,
    failures: i32,
    consumed_at: Option<OffsetDateTime>,
    window_started_at: OffsetDateTime,
    send_attempts: i32,
}

pub async fn request_code(
    pool: &PgPool,
    sender: &dyn SmsSender,
    phone: &str,
) -> Result<(), AppError> {
    let phone = normalize(phone)?;
    let mut transaction = pool.begin().await.map_err(store_error)?;
    sqlx::query("INSERT INTO phone_verification_codes (phone, code_hash, expires_at, sent_at, window_started_at, send_attempts, consumed_at) VALUES ($1, '', now(), now() - interval '1 hour', now(), 0, now()) ON CONFLICT (phone) DO NOTHING")
        .bind(&phone).execute(&mut *transaction).await.map_err(store_error)?;
    let row: CodeRow = sqlx::query_as("SELECT code_hash, expires_at, sent_at, failures, consumed_at, window_started_at, send_attempts FROM phone_verification_codes WHERE phone = $1 FOR UPDATE")
        .bind(&phone).fetch_one(&mut *transaction).await.map_err(store_error)?;
    let now = OffsetDateTime::now_utc();
    if row.sent_at + SEND_COOLDOWN > now {
        return Err(AppError::RateLimited {
            retry_after: remaining_seconds(row.sent_at + SEND_COOLDOWN - now),
        });
    }
    let window_active = row.window_started_at + Duration::hours(1) > now;
    if window_active && row.send_attempts >= MAX_SENDS_PER_HOUR {
        return Err(AppError::RateLimited {
            retry_after: remaining_seconds(row.window_started_at + Duration::hours(1) - now),
        });
    }
    let mut code = String::with_capacity(6);
    while code.len() < 6 {
        let mut bytes = [0_u8; 16];
        getrandom::fill(&mut bytes).map_err(|_| AppError::Internal)?;
        for byte in bytes {
            if byte < 250 && code.len() < 6 {
                code.push(char::from(b'0' + byte % 10));
            }
        }
    }
    #[cfg(debug_assertions)]
    if sender.dev_mode() {
        code = "114514".to_owned();
    }
    let code_hash = password::hash_async(&code).await?;
    let delivery = tokio::time::timeout(
        std::time::Duration::from_secs(8),
        sender.send(&phone, &code),
    )
    .await
    .unwrap_or(Err(AppError::SmsSendFailed));
    sqlx::query("UPDATE phone_verification_codes SET code_hash = $2, expires_at = $3, sent_at = $4, failures = 0, consumed_at = $5, window_started_at = $6, send_attempts = $7 WHERE phone = $1")
        .bind(&phone).bind(code_hash).bind(now + CODE_TTL).bind(now)
        .bind(if delivery.is_ok() { None } else { Some(now) })
        .bind(if window_active { row.window_started_at } else { now })
        .bind(if window_active { row.send_attempts + 1 } else { 1 })
        .execute(&mut *transaction).await.map_err(store_error)?;
    transaction.commit().await.map_err(store_error)?;
    delivery
}

pub async fn authenticate(
    pool: &PgPool,
    phone: &str,
    code: &str,
) -> Result<IssuedSession, AppError> {
    let phone = normalize(phone)?;
    let mut transaction = pool.begin().await.map_err(store_error)?;
    let row: Option<CodeRow> = sqlx::query_as("SELECT code_hash, expires_at, sent_at, failures, consumed_at, window_started_at, send_attempts FROM phone_verification_codes WHERE phone = $1 FOR UPDATE")
        .bind(&phone).fetch_optional(&mut *transaction).await.map_err(store_error)?;
    let Some(row) = row else {
        return Err(AppError::InvalidSmsCode);
    };
    let now = OffsetDateTime::now_utc();
    if row.consumed_at.is_some() || row.failures >= MAX_ATTEMPTS {
        return Err(AppError::InvalidSmsCode);
    }
    if row.expires_at <= now {
        return Err(AppError::SmsCodeExpired);
    }
    let valid_format = code.len() == 6 && code.bytes().all(|byte| byte.is_ascii_digit());
    if !valid_format || !password::verify_async(code, &row.code_hash).await {
        sqlx::query("UPDATE phone_verification_codes SET failures = failures + 1 WHERE phone = $1")
            .bind(&phone)
            .execute(&mut *transaction)
            .await
            .map_err(store_error)?;
        transaction.commit().await.map_err(store_error)?;
        return Err(AppError::InvalidSmsCode);
    }
    sqlx::query("UPDATE phone_verification_codes SET consumed_at = $2 WHERE phone = $1")
        .bind(&phone)
        .bind(now)
        .execute(&mut *transaction)
        .await
        .map_err(store_error)?;
    let user: (Uuid, Option<OffsetDateTime>) = sqlx::query_as(
        "INSERT INTO users (id, phone, display_name, timezone, created_at) VALUES ($1, $2, '新用户', 'Asia/Shanghai', $3) ON CONFLICT (phone) DO UPDATE SET phone = EXCLUDED.phone RETURNING id, disabled_at"
    ).bind(Uuid::new_v4()).bind(&phone).bind(now)
        .fetch_one(&mut *transaction).await.map_err(store_error)?;
    if user.1.is_some() {
        transaction.commit().await.map_err(store_error)?;
        return Err(AppError::InvalidCredentials);
    }
    let issued = session::issue_for_user(&mut *transaction, user.0).await?;
    transaction.commit().await.map_err(store_error)?;
    Ok(issued)
}

fn remaining_seconds(duration: Duration) -> u64 {
    duration.as_seconds_f64().ceil().max(1.0) as u64
}

fn store_error(error: sqlx::Error) -> AppError {
    tracing::error!(
        error_kind = crate::db::error_kind(&error),
        "phone store operation failed"
    );
    AppError::Internal
}
