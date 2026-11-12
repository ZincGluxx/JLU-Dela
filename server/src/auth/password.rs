use argon2::{
    Argon2,
    password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
};

use crate::error::{AppError, FieldError};

pub const MIN_LENGTH: usize = 12;
pub const MAX_LENGTH: usize = 128;

const SALT_BYTES: usize = 16;

const DUMMY_PASSWORD_HASH: &str = "$argon2id$v=19$m=19456,t=2,p=1$6arGup2Jfr+m9q5kxXZ4cw$JyqyJ3cSGq19f/Lt98kLrczPU0wnx8NMEB1f8oGjvXA";

pub fn validate_new(password: &str) -> Result<(), AppError> {
    let length = password.chars().count();
    if length < MIN_LENGTH {
        return Err(AppError::Validation(vec![FieldError::new(
            "password",
            "too_short",
        )]));
    }
    if length > MAX_LENGTH {
        return Err(AppError::Validation(vec![FieldError::new(
            "password", "too_long",
        )]));
    }
    Ok(())
}

pub fn validate_attempt(password: &str) -> Result<(), AppError> {
    if password.is_empty() {
        return Err(AppError::Validation(vec![FieldError::new(
            "password", "required",
        )]));
    }
    if password.chars().count() > MAX_LENGTH {
        return Err(AppError::Validation(vec![FieldError::new(
            "password", "too_long",
        )]));
    }
    Ok(())
}

pub fn ensure_differs_from_login(password: &str, login: &str) -> Result<(), AppError> {
    if password == login {
        return Err(AppError::Validation(vec![FieldError::new(
            "password",
            "matches_login",
        )]));
    }
    Ok(())
}

pub fn hash(password: &str) -> Result<String, AppError> {
    let mut salt_bytes = [0_u8; SALT_BYTES];
    getrandom::fill(&mut salt_bytes).map_err(|_| AppError::Internal)?;
    let salt = SaltString::encode_b64(&salt_bytes).map_err(|_| AppError::Internal)?;
    Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .map(|hash| hash.to_string())
        .map_err(|error| {
            tracing::error!(%error, "password hashing failed");
            AppError::Internal
        })
}

pub fn verify(password: &str, encoded: &str) -> bool {
    PasswordHash::new(encoded).is_ok_and(|hash| {
        Argon2::default()
            .verify_password(password.as_bytes(), &hash)
            .is_ok()
    })
}

pub fn verify_dummy(password: &str) {
    let _ = verify(password, DUMMY_PASSWORD_HASH);
}
