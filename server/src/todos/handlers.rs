//! `/api/v1/todos` 系列路由。
//!
//! 装配遵循 `docs/foundation.md` 第 6 节：handler 用 `State<AppState>` 取 `PgPool`，
//! 成功响应复用 `response::ApiResponse`，`request_id` 取自 `tower_http` 的
//! `RequestId` 扩展（与 `meta.rs`、`health.rs` 一致），因此与响应头
//! `X-Request-Id` 恒等。

use std::collections::HashMap;

use axum::{
    Extension, Json, Router,
    body::Bytes,
    extract::{Path, Query, State},
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, patch},
};
use serde::Serialize;
use serde_json::Value;
use tower_http::request_id::RequestId;
use uuid::Uuid;

use crate::{auth::AuthenticatedUser, error::request_id, response::ApiResponse, state::AppState};

use super::error::{ApiError, FieldError};
use super::model::{self, Todo};
use super::repo::{
    self, CreateError, CreateParams, Cursor, DeleteError, ListParams, PatchError, PatchParams,
};

const DEFAULT_LIMIT: i64 = 50;
const MAX_LIMIT: i64 = 100;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/todos", get(list_todos).post(create_todo))
        .route("/api/v1/todos/{id}", patch(update_todo).delete(delete_todo))
}

#[derive(Serialize)]
struct ListEnvelope {
    data: Vec<Todo>,
    meta: ListMeta,
}

#[derive(Serialize)]
struct ListMeta {
    request_id: String,
    next_cursor: Option<String>,
    has_more: bool,
}

async fn list_todos(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
    Query(query): Query<HashMap<String, String>>,
) -> Response {
    let request_id = request_id(&request_id_value);
    match list_todos_inner(&state, user.user_id, &query).await {
        Ok(page) => Json(ListEnvelope {
            data: page.todos,
            meta: ListMeta {
                request_id,
                next_cursor: page.next_cursor.map(|cursor| cursor.encode()),
                has_more: page.has_more,
            },
        })
        .into_response(),
        Err(error) => error.response(&request_id),
    }
}

async fn list_todos_inner(
    state: &AppState,
    user_id: Uuid,
    query: &HashMap<String, String>,
) -> Result<repo::TodoPage, ApiError> {
    let completed = match query.get("completed") {
        None => None,
        Some(raw) => Some(raw.parse::<bool>().map_err(|_| {
            ApiError::validation(vec![FieldError::new("completed", "INVALID_TYPE")])
        })?),
    };
    let limit = match query.get("limit") {
        None => DEFAULT_LIMIT,
        Some(raw) => {
            let limit = raw.parse::<i64>().map_err(|_| {
                ApiError::validation(vec![FieldError::new("limit", "INVALID_TYPE")])
            })?;
            if !(1..=MAX_LIMIT).contains(&limit) {
                return Err(ApiError::validation(vec![FieldError::new(
                    "limit",
                    "OUT_OF_RANGE",
                )]));
            }
            limit
        }
    };
    let cursor = match query.get("cursor") {
        None => None,
        Some(raw) => {
            let cursor = Cursor::decode(raw).map_err(|_| ApiError::bad_cursor())?;
            cursor
                .ensure_filter(completed)
                .map_err(|_| ApiError::bad_cursor())?;
            Some(cursor)
        }
    };

    Ok(repo::list(
        &state.pool,
        user_id,
        ListParams {
            completed,
            limit,
            cursor,
        },
    )
    .await?)
}

async fn create_todo(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
    headers: HeaderMap,
    body: Bytes,
) -> Response {
    let request_id = request_id(&request_id_value);
    match create_todo_inner(&state, user.user_id, &headers, &body).await {
        Ok(todo) => (
            StatusCode::CREATED,
            Json(ApiResponse::new(todo, request_id)),
        )
            .into_response(),
        Err(error) => error.response(&request_id),
    }
}

async fn create_todo_inner(
    state: &AppState,
    user_id: Uuid,
    headers: &HeaderMap,
    body: &Bytes,
) -> Result<Todo, ApiError> {
    let idempotency_key = idempotency_key(headers)?;
    require_json(headers)?;

    let request = model::parse_create(&parse_json(body)?).map_err(ApiError::validation)?;
    let request_hash = model::request_hash(&request);
    repo::create(
        &state.pool,
        user_id,
        CreateParams {
            idempotency_key,
            request_hash: &request_hash,
            title: &request.title,
            notes: &request.notes,
            due_kind: request.due.kind,
            due_date: request.due.date,
            due_at: request.due.at,
            color: request.color,
            show_in_calendar: request.show_in_calendar,
        },
    )
    .await
    .map_err(|error| match error {
        CreateError::IdempotencyConflict => ApiError::idempotency_conflict(),
        CreateError::Db(error) => ApiError::from(error),
    })
}

async fn update_todo(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
    Path(id): Path<String>,
    headers: HeaderMap,
    body: Bytes,
) -> Response {
    let request_id = request_id(&request_id_value);
    match update_todo_inner(&state, user.user_id, &id, &headers, &body).await {
        Ok(todo) => Json(ApiResponse::new(todo, request_id)).into_response(),
        Err(error) => error.response(&request_id),
    }
}

async fn update_todo_inner(
    state: &AppState,
    user_id: Uuid,
    id: &str,
    headers: &HeaderMap,
    body: &Bytes,
) -> Result<Todo, ApiError> {
    require_json(headers)?;
    let id = parse_id(id)?;

    let request = model::parse_update(&parse_json(body)?).map_err(ApiError::validation)?;
    repo::patch(
        &state.pool,
        user_id,
        id,
        PatchParams {
            revision: request.revision,
            title: request.title.as_deref(),
            notes: request.notes.as_deref(),
            due: request.due,
            color: request.color,
            completed: request.completed,
            show_in_calendar: request.show_in_calendar,
        },
    )
    .await
    .map_err(|error| match error {
        PatchError::NotFound => ApiError::not_found(),
        PatchError::RevisionConflict(current) => ApiError::revision_conflict(current),
        PatchError::Db(error) => ApiError::from(error),
    })
}

async fn delete_todo(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
    headers: HeaderMap,
    Path(id): Path<String>,
) -> Response {
    let request_id = request_id(&request_id_value);
    match delete_todo_inner(&state, user.user_id, &headers, &id).await {
        Ok(()) => StatusCode::NO_CONTENT.into_response(),
        Err(error) => error.response(&request_id),
    }
}

async fn delete_todo_inner(
    state: &AppState,
    user_id: Uuid,
    headers: &HeaderMap,
    id: &str,
) -> Result<(), ApiError> {
    let id = parse_id(id)?;
    let revision = if_match(headers)?;

    repo::delete(&state.pool, user_id, id, revision)
        .await
        .map_err(|error| match error {
            DeleteError::NotFound => ApiError::not_found(),
            DeleteError::RevisionConflict(current) => ApiError::revision_conflict(current),
            DeleteError::Db(error) => ApiError::from(error),
        })
}

fn idempotency_key(headers: &HeaderMap) -> Result<Uuid, ApiError> {
    match headers.get("idempotency-key") {
        None => Err(ApiError::validation(vec![FieldError::new(
            "Idempotency-Key",
            "REQUIRED",
        )])),
        Some(value) => value
            .to_str()
            .ok()
            .and_then(|raw| Uuid::parse_str(raw.trim()).ok())
            .ok_or_else(|| {
                ApiError::validation(vec![FieldError::new("Idempotency-Key", "INVALID_FORMAT")])
            }),
    }
}

fn if_match(headers: &HeaderMap) -> Result<i32, ApiError> {
    let Some(value) = headers.get("if-match") else {
        return Err(ApiError::validation(vec![FieldError::new(
            "If-Match", "REQUIRED",
        )]));
    };
    let revision = value
        .to_str()
        .ok()
        .map(|raw| raw.trim().trim_start_matches("W/").trim_matches('"'))
        .and_then(|raw| raw.parse::<i32>().ok())
        .filter(|revision| *revision >= 1);

    revision
        .ok_or_else(|| ApiError::validation(vec![FieldError::new("If-Match", "INVALID_FORMAT")]))
}

fn parse_id(raw: &str) -> Result<Uuid, ApiError> {
    Uuid::parse_str(raw).map_err(|_| ApiError::not_found())
}

fn parse_json(body: &Bytes) -> Result<Value, ApiError> {
    serde_json::from_slice(body)
        .map_err(|_| ApiError::validation(vec![FieldError::new("body", "INVALID_JSON")]))
}

/// 写端点直接收 `Bytes`（为了保留 `Idempotency-Key` 与 `If-Match` 的先后顺序），
/// 因此自己守 Content-Type，与 `ApiJson` 的 415 行为一致。
fn require_json(headers: &HeaderMap) -> Result<(), ApiError> {
    let Some(value) = headers.get(axum::http::header::CONTENT_TYPE) else {
        return Err(ApiError::unsupported_media_type());
    };
    let is_json = value
        .to_str()
        .map(|raw| {
            let media_type = raw.split(';').next().unwrap_or_default().trim();
            media_type.eq_ignore_ascii_case("application/json")
        })
        .unwrap_or(false);
    if is_json {
        Ok(())
    } else {
        Err(ApiError::unsupported_media_type())
    }
}
