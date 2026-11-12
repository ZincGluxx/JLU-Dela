//! 日历响应的判别联合与来源状态。
//!
//! 字段与 `contracts/openapi.yaml` 的 `CalendarData` / `CalendarItem` /
//! `SourceStatus` 一一对应。`kind` 由 serde 的标签承担，结构体本身不重复声明。

use chrono::{DateTime, NaiveDate, Utc};
use serde::Serialize;
use uuid::Uuid;

use super::shanghai_midnight;
use crate::todos::model::{Color, DueKind};

#[derive(Debug, Serialize)]
pub struct CalendarData {
    pub from: NaiveDate,
    pub to: NaiveDate,
    pub items: Vec<CalendarItem>,
    pub sources: Vec<SourceStatus>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum CalendarItem {
    Lesson(LessonItem),
    Assignment(AssignmentItem),
    Todo(TodoItem),
}

impl CalendarItem {
    /// 排序时间。`None` 表示来源没给出可比较的时刻，排在所有条目之后。
    pub fn at(&self) -> Option<DateTime<Utc>> {
        match self {
            Self::Lesson(item) => Some(item.starts_at),
            Self::Assignment(item) => item.due_at,
            Self::Todo(item) => item.at(),
        }
    }

    /// 契约固定的 kind 序：lesson < assignment < todo。
    pub fn kind_rank(&self) -> u8 {
        match self {
            Self::Lesson(_) => 0,
            Self::Assignment(_) => 1,
            Self::Todo(_) => 2,
        }
    }

    pub fn title(&self) -> &str {
        match self {
            Self::Lesson(item) => &item.title,
            Self::Assignment(item) => &item.title,
            Self::Todo(item) => &item.title,
        }
    }

    pub fn id(&self) -> &str {
        match self {
            Self::Lesson(item) => &item.id,
            Self::Assignment(item) => &item.id,
            Self::Todo(item) => &item.id,
        }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct LessonItem {
    pub id: String,
    pub lesson_id: String,
    pub course_offering_id: String,
    pub title: String,
    pub starts_at: DateTime<Utc>,
    pub ends_at: DateTime<Utc>,
    pub location: Option<String>,
    pub period_start: Option<i32>,
    pub period_end: Option<i32>,
}

/// 作业的截止四态。`relative` / `unknown` 只保留来源原文，没有可比较的时刻。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum AssignmentDueKind {
    Exact,
    DateOnly,
    Relative,
    Unknown,
}

#[derive(Debug, Clone, Serialize)]
pub struct AssignmentItem {
    pub id: String,
    pub assignment_id: String,
    pub course_offering_id: Option<String>,
    pub title: String,
    pub due_at: Option<DateTime<Utc>>,
    pub due_kind: AssignmentDueKind,
    pub timing_text: String,
    pub source_status: String,
    pub read_at: Option<DateTime<Utc>>,
    pub muted_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize)]
pub struct TodoItem {
    pub id: String,
    pub todo_id: Uuid,
    pub title: String,
    /// 只可能是 `date_only` / `exact`：`none` 不进日历。
    pub due_kind: DueKind,
    pub due_date: Option<NaiveDate>,
    pub due_at: Option<DateTime<Utc>>,
    pub color: Option<Color>,
    pub show_in_calendar: bool,
    pub completed: bool,
}

impl TodoItem {
    /// `date_only` 占据整个日历日，排序按当天北京时间零点。
    fn at(&self) -> Option<DateTime<Utc>> {
        self.due_at.or_else(|| self.due_date.map(shanghai_midnight))
    }
}

/// 来源当前状态，取自 `SourceStatus.status` 的枚举。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum SourceState {
    Connected,
    AuthRequired,
    Disconnected,
}

#[derive(Debug, Serialize)]
pub struct SourceStatus {
    pub source: &'static str,
    pub status: SourceState,
    /// 首次成功同步前为 null。
    pub last_success_at: Option<DateTime<Utc>>,
}
