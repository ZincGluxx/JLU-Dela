//! 学习日历（owner: E，`GET /api/v1/calendar` 唯一实现者）。
//!
//! 契约要点：
//! - `from` 含、`to` 不含；首期跨度上限 93 天；
//! - 返回判别联合：`kind = lesson | assignment | todo`；
//! - lesson 来自 B 的课表事件，assignment 来自 C 的作业事件，todo 由本模块自读；
//! - 作业不得被复制成待办。
//!
//! 当前为骨架：参数校验与聚合逻辑待 B/C 的来源契约落地后实现。身份校验已按
//! 契约接上，未认证的调用在这里就返回 401，不会走到聚合逻辑。

use axum::{
    Extension, Json, Router,
    extract::{Query, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
};
use serde::Deserialize;
use serde_json::json;
use tower_http::request_id::RequestId;

use crate::{auth::AuthenticatedUser, error::request_id, state::AppState};

pub fn router() -> Router<AppState> {
    Router::new().route("/api/v1/calendar", get(get_calendar))
}

#[derive(Debug, Deserialize)]
struct CalendarQuery {
    from: Option<String>,
    to: Option<String>,
}

async fn get_calendar(
    State(_state): State<AppState>,
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
    Query(query): Query<CalendarQuery>,
) -> Response {
    let request_id = request_id(&request_id_value);
    tracing::debug!(
        user_id = %user.user_id,
        from = ?query.from,
        to = ?query.to,
        "calendar stub"
    );
    (
        StatusCode::NOT_IMPLEMENTED,
        Json(json!({
            "error": {
                "code": "NOT_IMPLEMENTED",
                "message": "GET /calendar is not implemented yet.",
                "request_id": request_id,
                "retryable": false,
                "fields": []
            }
        })),
    )
        .into_response()
}
