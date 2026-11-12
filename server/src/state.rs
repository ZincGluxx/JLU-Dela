use std::sync::Arc;

use sqlx::PgPool;

use crate::{calendar::source::CalendarSources, sync::SyncRegistry};

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub build_id: Arc<str>,
    pub sync: Arc<SyncRegistry>,
    /// 已注册的日历来源。空集合表示没有任何来源接入，`sources` 返回空数组。
    pub calendar_sources: Arc<CalendarSources>,
}

impl AppState {
    pub fn new(pool: PgPool, build_id: impl Into<Arc<str>>) -> Self {
        Self::with_sync(pool, build_id, SyncRegistry::empty())
    }

    pub fn with_sync(pool: PgPool, build_id: impl Into<Arc<str>>, sync: SyncRegistry) -> Self {
        Self::with_sources(pool, build_id, sync, CalendarSources::new())
    }

    pub fn with_sources(
        pool: PgPool,
        build_id: impl Into<Arc<str>>,
        sync: SyncRegistry,
        calendar_sources: CalendarSources,
    ) -> Self {
        Self {
            pool,
            build_id: build_id.into(),
            sync: Arc::new(sync),
            calendar_sources: Arc::new(calendar_sources),
        }
    }
}
