use std::sync::Arc;

use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub build_id: Arc<str>,
}

impl AppState {
    pub fn new(pool: PgPool, build_id: impl Into<Arc<str>>) -> Self {
        Self {
            pool,
            build_id: build_id.into(),
        }
    }
}
