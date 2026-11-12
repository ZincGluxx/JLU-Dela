//! 学习日历（owner: E，`GET /api/v1/calendar` 唯一实现者）。
//!
//! 契约要点：
//! - `from` 含、`to` 不含，均按 Asia/Shanghai 日历日解释；首期跨度上限 93 天；
//! - 返回判别联合：`kind = lesson | assignment | todo`；
//! - lesson / assignment 由 B/C 以 `CalendarSource` 接入，todo 由本模块自读；
//! - 作业不得被复制成待办。
//!
//! 排序固定为：时间升序 → kind 序（lesson、assignment、todo）→ title → id。
//! 没有可比较时刻的条目排在最后。

pub mod model;
pub mod repo;
pub mod source;

use std::collections::HashMap;

use axum::{
    Extension, Json, Router,
    extract::{Query, State},
    response::{IntoResponse, Response},
    routing::get,
};
use chrono::{DateTime, FixedOffset, NaiveDate, Utc};
use tower_http::request_id::RequestId;
use uuid::Uuid;

use crate::{
    auth::AuthenticatedUser,
    error::{AppError, FieldError, request_id},
    response::ApiResponse,
    state::AppState,
};

use model::{CalendarData, CalendarItem, SourceStatus};
use source::CalendarRange;

const MAX_SPAN_DAYS: i64 = 93;
const SHANGHAI_OFFSET_SECONDS: i32 = 8 * 3600;

pub fn router() -> Router<AppState> {
    Router::new().route("/api/v1/calendar", get(get_calendar))
}

async fn get_calendar(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
    Query(query): Query<HashMap<String, String>>,
) -> Response {
    let request_id = request_id(&request_id_value);
    match calendar(&state, user.user_id, &query).await {
        Ok(data) => Json(ApiResponse::new(data, request_id)).into_response(),
        Err(error) => error.response(&request_id),
    }
}

async fn calendar(
    state: &AppState,
    user_id: Uuid,
    query: &HashMap<String, String>,
) -> Result<CalendarData, AppError> {
    let range = parse_range(query)?;

    let mut items: Vec<CalendarItem> = repo::todos(&state.pool, user_id, &range)
        .await
        .map_err(|error| {
            tracing::error!(
                kind = crate::db::error_kind(&error),
                error = %error,
                "calendar todos query failed"
            );
            AppError::DatabaseUnavailable
        })?
        .into_iter()
        .map(CalendarItem::Todo)
        .collect();

    let mut sources = Vec::with_capacity(state.calendar_sources.len());
    for source in state.calendar_sources.iter() {
        let result = source.items(user_id, &range).await;
        sources.push(SourceStatus {
            source: source.source(),
            status: result.status,
            last_success_at: result.last_success_at,
        });
        items.extend(result.items);
    }

    sort_items(&mut items);

    Ok(CalendarData {
        from: range.from,
        to: range.to,
        items,
        sources,
    })
}

fn parse_range(query: &HashMap<String, String>) -> Result<CalendarRange, AppError> {
    let from = parse_day(query.get("from"), "from");
    let to = parse_day(query.get("to"), "to");
    let (from, to) = match (from, to) {
        (Ok(from), Ok(to)) => (from, to),
        (from, to) => {
            return Err(AppError::Validation(
                [from.err(), to.err()].into_iter().flatten().collect(),
            ));
        }
    };

    if from >= to {
        return Err(AppError::Validation(vec![FieldError::new(
            "to",
            "INVALID_RANGE",
        )]));
    }
    if (to - from).num_days() > MAX_SPAN_DAYS {
        return Err(AppError::Validation(vec![FieldError::new(
            "to",
            "RANGE_TOO_WIDE",
        )]));
    }
    Ok(CalendarRange { from, to })
}

/// 只接受补零的 `YYYY-MM-DD`：`chrono` 的解析对 `2026-1-1` 也放行，而契约的
/// `format: date` 只覆盖规范写法。
fn parse_day(raw: Option<&String>, path: &'static str) -> Result<NaiveDate, FieldError> {
    let Some(raw) = raw else {
        return Err(FieldError::new(path, "REQUIRED"));
    };
    NaiveDate::parse_from_str(raw, "%Y-%m-%d")
        .ok()
        .filter(|date| date.format("%Y-%m-%d").to_string() == *raw)
        .ok_or_else(|| FieldError::new(path, "INVALID_FORMAT"))
}

/// 某个 Asia/Shanghai 日历日的零点，折成 UTC 时刻。
pub fn shanghai_midnight(date: NaiveDate) -> DateTime<Utc> {
    let offset = FixedOffset::east_opt(SHANGHAI_OFFSET_SECONDS).expect("UTC+8 是合法偏移");
    date.and_hms_opt(0, 0, 0)
        .expect("零点合法")
        .and_local_timezone(offset)
        .single()
        .expect("固定偏移没有歧义")
        .with_timezone(&Utc)
}

fn sort_items(items: &mut [CalendarItem]) {
    items.sort_by(|a, b| {
        let (a_at, b_at) = (a.at(), b.at());
        a_at.is_none()
            .cmp(&b_at.is_none())
            .then_with(|| a_at.cmp(&b_at))
            .then_with(|| a.kind_rank().cmp(&b.kind_rank()))
            .then_with(|| a.title().cmp(b.title()))
            .then_with(|| a.id().cmp(b.id()))
    });
}
