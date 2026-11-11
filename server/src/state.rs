use std::sync::Arc;

use sqlx::PgPool;

use crate::sync::SyncRegistry;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub build_id: Arc<str>,
    pub sync: Arc<SyncRegistry>,
}

impl AppState {
    pub fn new(pool: PgPool, build_id: impl Into<Arc<str>>) -> Self {
        Self::with_sync(pool, build_id, SyncRegistry::empty())
    }

    pub fn with_sync(pool: PgPool, build_id: impl Into<Arc<str>>, sync: SyncRegistry) -> Self {
        Self {
            pool,
            build_id: build_id.into(),
            sync: Arc::new(sync),
        }
    }
}
