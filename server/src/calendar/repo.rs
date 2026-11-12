//! 日历区间的待办查询。
//!
//! 与 `todos::repo` 一样使用 `sqlx::query_as` 运行时 API：`query!` 系列宏在编译期
//! 连接数据库，常规构建没有实例，会让 crate 编不过。
//!
//! 区间语义（`from` 含、`to` 不含）：
//! - `exact` 比 UTC 时刻，边界是当天北京时间的零点；
//! - `date_only` 直接比日期，不再折成时刻。

use chrono::{DateTime, NaiveDate, Utc};
use sqlx::{FromRow, PgPool, Row, postgres::PgRow};
use uuid::Uuid;

use super::{model::TodoItem, shanghai_midnight, source::CalendarRange};
use crate::todos::model::{Color, DueKind};

const QUERY: &str = "
SELECT id, title, due_kind, due_date, due_at, color, show_in_calendar, completed
FROM todos
WHERE user_id = $1
  AND deleted_at IS NULL
  AND show_in_calendar
  AND (
    (due_kind = 'exact' AND due_at >= $2 AND due_at < $3)
    OR (due_kind = 'date_only' AND due_date >= $4 AND due_date < $5)
  )";

struct TodoRow {
    id: Uuid,
    title: String,
    due_kind: DueKind,
    due_date: Option<NaiveDate>,
    due_at: Option<DateTime<Utc>>,
    color: Option<Color>,
    show_in_calendar: bool,
    completed: bool,
}

impl<'r> FromRow<'r, PgRow> for TodoRow {
    fn from_row(row: &'r PgRow) -> Result<Self, sqlx::Error> {
        Ok(Self {
            id: row.try_get("id")?,
            title: row.try_get("title")?,
            due_kind: due_kind(row.try_get("due_kind")?)?,
            due_date: row.try_get("due_date")?,
            due_at: row.try_get("due_at")?,
            color: color(row.try_get("color")?)?,
            show_in_calendar: row.try_get("show_in_calendar")?,
            completed: row.try_get("completed")?,
        })
    }
}

fn due_kind(raw: String) -> Result<DueKind, sqlx::Error> {
    DueKind::parse(&raw)
        .ok_or_else(|| sqlx::Error::Decode(format!("unknown due_kind: {raw}").into()))
}

fn color(raw: Option<String>) -> Result<Option<Color>, sqlx::Error> {
    match raw {
        None => Ok(None),
        Some(raw) => Color::parse(&raw)
            .map(Some)
            .ok_or_else(|| sqlx::Error::Decode(format!("unknown color: {raw}").into())),
    }
}

pub async fn todos(
    pool: &PgPool,
    user_id: Uuid,
    range: &CalendarRange,
) -> Result<Vec<TodoItem>, sqlx::Error> {
    let rows = sqlx::query_as::<_, TodoRow>(QUERY)
        .bind(user_id)
        .bind(shanghai_midnight(range.from))
        .bind(shanghai_midnight(range.to))
        .bind(range.from)
        .bind(range.to)
        .fetch_all(pool)
        .await?;

    Ok(rows
        .into_iter()
        .map(|row| TodoItem {
            id: format!("todo:{}", row.id),
            todo_id: row.id,
            title: row.title,
            due_kind: row.due_kind,
            due_date: row.due_date,
            due_at: row.due_at,
            color: row.color,
            show_in_calendar: row.show_in_calendar,
            completed: row.completed,
        })
        .collect())
}
