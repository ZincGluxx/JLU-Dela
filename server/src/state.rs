use std::sync::Arc;

use sqlx::PgPool;

use crate::{calendar::source::CalendarSources, sync::SyncRegistry};

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub files: crate::files::FileStorageConfig,
    pub build_id: Arc<str>,
    pub sync: Arc<SyncRegistry>,
    /// 已注册的日历来源。空集合表示没有任何来源接入，`sources` 返回空数组。
    pub calendar_sources: Arc<CalendarSources>,
    pub sms_sender: Arc<dyn crate::auth::phone::SmsSender>,
}

impl AppState {
    pub fn from_config(pool: PgPool, config: &crate::config::Config) -> Self {
        let mut state = Self::new(pool, config.build_id.clone());
        state.files = config.files.clone();
        state.sms_sender = crate::auth::phone::configured_sender(config);
        state
    }

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
            files: crate::files::FileStorageConfig::default(),
            build_id: build_id.into(),
            sync: Arc::new(sync),
            calendar_sources: Arc::new(calendar_sources),
            sms_sender: Arc::new(crate::auth::phone::UnavailableSmsSender),
        }
    }
}
