use std::time::Duration;

use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use sha2::{Digest, Sha256};

pub const ACCESS_TTL: Duration = Duration::from_secs(15 * 60);
pub const REFRESH_TTL: Duration = Duration::from_secs(30 * 24 * 60 * 60);

const TOKEN_BYTES: usize = 32;

pub struct TokenPair {
    pub access: String,
    pub refresh: String,
}

impl TokenPair {
    pub fn issue() -> Self {
        Self {
            access: format!("at_{}", random_token()),
            refresh: format!("rt_{}", random_token()),
        }
    }
}

pub fn digest(token: &str) -> String {
    hex::encode(Sha256::digest(token.as_bytes()))
}

fn random_token() -> String {
    let mut bytes = [0_u8; TOKEN_BYTES];
    getrandom::fill(&mut bytes).expect("operating system randomness is available");
    URL_SAFE_NO_PAD.encode(bytes)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn issued_tokens_are_unique_and_digests_are_stable() {
        let first = TokenPair::issue();
        let second = TokenPair::issue();

        assert!(first.access.starts_with("at_"));
        assert!(first.refresh.starts_with("rt_"));
        assert_ne!(first.access, second.access);
        assert_eq!(digest(&first.access), digest(&first.access));
        assert_eq!(digest(&first.access).len(), 64);
        assert_ne!(digest(&first.access), digest(&first.refresh));
    }
}
