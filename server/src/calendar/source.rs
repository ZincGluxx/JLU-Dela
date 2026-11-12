//! 校园来源接入点。
//!
//! B/C 落地课表与作业后，各自实现 `CalendarSource` 并注册到 `AppState`；本模块的
//! 聚合、排序与响应形状不再改动。来源只负责把区间内的条目取出来，以及报告自己
//! 当前的状态——取不到数据不能连累其他来源，也不能把用户登出工作台。

use std::{future::Future, pin::Pin, sync::Arc};

use chrono::{DateTime, NaiveDate, Utc};
use uuid::Uuid;

use super::model::{CalendarItem, SourceState};

/// 查询区间：`from` 含、`to` 不含，均为 Asia/Shanghai 日历日。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CalendarRange {
    pub from: NaiveDate,
    pub to: NaiveDate,
}

/// 一次来源查询的结果。
pub struct SourceResult {
    pub status: SourceState,
    pub last_success_at: Option<DateTime<Utc>>,
    pub items: Vec<CalendarItem>,
}

/// 已注册的日历来源集合。
pub type CalendarSources = Vec<Arc<dyn CalendarSource>>;

pub trait CalendarSource: Send + Sync {
    /// 来源标识，取自 `SourceStatus.source` 的枚举。
    fn source(&self) -> &'static str;

    /// 返回落在区间内的条目，以及该来源当前状态。
    fn items<'a>(
        &'a self,
        user_id: Uuid,
        range: &'a CalendarRange,
    ) -> Pin<Box<dyn Future<Output = SourceResult> + Send + 'a>>;
}
