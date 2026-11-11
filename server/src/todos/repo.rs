//! 待办持久化。
//!
//! 这里全部使用 `sqlx::query_as` 运行时 API，而不是 `query!` / `query_as!` 编译期宏：
//! 宏在编译时连接 PostgreSQL 读取 catalog，本机与 CI 的常规测试都没有数据库实例，
//! 宏会让 crate 直接编不过。等 `cargo sqlx prepare` 的离线缓存纳入流程后，再逐个换成
//! 宏以获得列名与类型的编译期校验；SQL 语义不需要改。
//!
//! 连接池由 `AppState` 提供（见 `docs/foundation.md` 第 6 节），本模块不持有全局状态。

use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use sqlx::{FromRow, PgPool, Postgres, QueryBuilder, Row, postgres::PgRow};
use uuid::Uuid;

use super::model::{Color, Due, DueKind, Todo};

pub const CREATE_ENDPOINT: &str = "POST /todos";

// sqlx 0.9 只接受 `&'static str` 作为 `query_as` 的 SQL（`SqlSafeStr`）。列清单用宏拼进
// 字面量：单一来源，也不需要 `AssertSqlSafe` 绕过安全检查。
macro_rules! todo_columns {
    () => {
        "id, title, notes, due_kind, due_date, due_at, color, completed, show_in_calendar, revision, created_at, updated_at"
    };
}

/// 列表排序键（time-semantics §5.1）：`date_only` 的 00:00 是北京时间零点，UTC 上是
/// 前一天 16:00，所以 `due_date::timestamp AT TIME ZONE 'Asia/Shanghai'` 而不是直接转型。
const SORT_KEY: &str = "COALESCE(due_at, due_date::timestamp AT TIME ZONE 'Asia/Shanghai')";

impl<'r> FromRow<'r, PgRow> for Todo {
    fn from_row(row: &'r PgRow) -> Result<Self, sqlx::Error> {
        Ok(Self {
            id: row.try_get("id")?,
            title: row.try_get("title")?,
            notes: row.try_get("notes")?,
            due_kind: due_kind(row.try_get("due_kind")?)?,
            due_date: row.try_get("due_date")?,
            due_at: row.try_get("due_at")?,
            color: color(row.try_get("color")?)?,
            completed: row.try_get("completed")?,
            show_in_calendar: row.try_get("show_in_calendar")?,
            revision: row.try_get("revision")?,
            created_at: row.try_get("created_at")?,
            updated_at: row.try_get("updated_at")?,
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

/// 列表游标：绑定 `completed` 筛选，并记住上一页最后一行的 `sort_key` 与 `id`。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Cursor {
    pub completed: Option<bool>,
    pub sort_key: Option<DateTime<Utc>>,
    pub id: Uuid,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CursorError {
    Malformed,
    FilterMismatch,
}

impl Cursor {
    pub fn encode(&self) -> String {
        let bytes = serde_json::to_vec(self).expect("cursor serialization cannot fail");
        URL_SAFE_NO_PAD.encode(bytes)
    }

    pub fn decode(raw: &str) -> Result<Self, CursorError> {
        let bytes = URL_SAFE_NO_PAD
            .decode(raw)
            .map_err(|_| CursorError::Malformed)?;
        serde_json::from_slice(&bytes).map_err(|_| CursorError::Malformed)
    }

    pub fn ensure_filter(&self, completed: Option<bool>) -> Result<(), CursorError> {
        if self.completed == completed {
            Ok(())
        } else {
            Err(CursorError::FilterMismatch)
        }
    }
}

pub struct ListParams {
    pub completed: Option<bool>,
    pub limit: i64,
    pub cursor: Option<Cursor>,
}

pub struct TodoPage {
    pub todos: Vec<Todo>,
    pub has_more: bool,
    pub next_cursor: Option<Cursor>,
}

struct ListRow {
    todo: Todo,
    sort_key: Option<DateTime<Utc>>,
}

impl<'r> FromRow<'r, PgRow> for ListRow {
    fn from_row(row: &'r PgRow) -> Result<Self, sqlx::Error> {
        Ok(Self {
            todo: Todo::from_row(row)?,
            sort_key: row.try_get("sort_key")?,
        })
    }
}

pub async fn list(
    pool: &PgPool,
    user_id: Uuid,
    params: ListParams,
) -> Result<TodoPage, sqlx::Error> {
    let mut query = QueryBuilder::<Postgres>::new(concat!("SELECT ", todo_columns!(), ", "));
    query
        .push(SORT_KEY)
        .push(" AS sort_key FROM todos WHERE user_id = ")
        .push_bind(user_id)
        .push(" AND deleted_at IS NULL");
    if let Some(completed) = params.completed {
        query.push(" AND completed = ").push_bind(completed);
    }
    if let Some(cursor) = &params.cursor {
        match cursor.sort_key {
            Some(sort_key) => {
                // 排序是 `ASC NULLS LAST`：从有排序键的行翻页时，NULL 行排在所有非 NULL
                // 行之后，所以「严格大于」之外还必须放行 `IS NULL`，否则 `limit` 一旦
                // 在有日期与无日期之间切开，无日期的那批就永远取不到。
                query
                    .push(" AND (")
                    .push(SORT_KEY)
                    .push(" > ")
                    .push_bind(sort_key)
                    .push(" OR (")
                    .push(SORT_KEY)
                    .push(" = ")
                    .push_bind(sort_key)
                    .push(" AND id > ")
                    .push_bind(cursor.id)
                    .push(") OR ")
                    .push(SORT_KEY)
                    .push(" IS NULL)");
            }
            None => {
                query
                    .push(" AND ")
                    .push(SORT_KEY)
                    .push(" IS NULL AND id > ")
                    .push_bind(cursor.id);
            }
        }
    }
    query
        .push(" ORDER BY ")
        .push(SORT_KEY)
        .push(" ASC NULLS LAST, id ASC LIMIT ")
        .push_bind(params.limit + 1);

    let mut rows = query.build_query_as::<ListRow>().fetch_all(pool).await?;
    let has_more = rows.len() as i64 > params.limit;
    if has_more {
        rows.truncate(params.limit as usize);
    }
    let next_cursor = match (has_more, rows.last()) {
        (true, Some(last)) => Some(Cursor {
            completed: params.completed,
            sort_key: last.sort_key,
            id: last.todo.id,
        }),
        _ => None,
    };
    Ok(TodoPage {
        todos: rows.into_iter().map(|row| row.todo).collect(),
        has_more,
        next_cursor,
    })
}

pub struct CreateParams<'a> {
    pub idempotency_key: Uuid,
    pub request_hash: &'a str,
    pub title: &'a str,
    pub notes: &'a str,
    pub due_kind: DueKind,
    pub due_date: Option<NaiveDate>,
    pub due_at: Option<DateTime<Utc>>,
    pub color: Option<Color>,
    pub show_in_calendar: bool,
}

#[derive(Debug)]
pub enum CreateError {
    IdempotencyConflict,
    Db(sqlx::Error),
}

impl From<sqlx::Error> for CreateError {
    fn from(error: sqlx::Error) -> Self {
        Self::Db(error)
    }
}

/// 幂等记录与待办写入在同一个事务里完成：先占住幂等键，再插待办，最后回填结果。
/// 同一键的并发重试会阻塞在唯一约束上，等首个事务提交后读到 `status_code`。
pub async fn create(
    pool: &PgPool,
    user_id: Uuid,
    params: CreateParams<'_>,
) -> Result<Todo, CreateError> {
    let mut tx = pool.begin().await?;

    let claimed = sqlx::query(
        "INSERT INTO idempotency_keys (user_id, endpoint, key, request_hash)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (user_id, endpoint, key) DO UPDATE
         SET request_hash = EXCLUDED.request_hash, status_code = NULL, response = NULL,
             created_at = now()
         WHERE idempotency_keys.created_at <= now() - interval '24 hours'",
    )
    .bind(user_id)
    .bind(CREATE_ENDPOINT)
    .bind(params.idempotency_key)
    .bind(params.request_hash)
    .execute(&mut *tx)
    .await?;

    if claimed.rows_affected() == 0 {
        let existing: Option<(String, Option<i16>, Option<serde_json::Value>)> = sqlx::query_as(
            "SELECT request_hash, status_code, response
             FROM idempotency_keys
             WHERE user_id = $1 AND endpoint = $2 AND key = $3",
        )
        .bind(user_id)
        .bind(CREATE_ENDPOINT)
        .bind(params.idempotency_key)
        .fetch_optional(&mut *tx)
        .await?;

        let Some((request_hash, status_code, response)) = existing else {
            return Err(sqlx::Error::RowNotFound.into());
        };
        if request_hash != params.request_hash {
            return Err(CreateError::IdempotencyConflict);
        }
        let (Some(_), Some(response)) = (status_code, response) else {
            return Err(CreateError::IdempotencyConflict);
        };
        let todo: Todo = serde_json::from_value(response)
            .map_err(|_| sqlx::Error::Decode("idempotency record is not a todo".into()))?;
        tx.commit().await?;
        return Ok(todo);
    }

    let todo: Todo = sqlx::query_as(concat!(
        "INSERT INTO todos (user_id, title, notes, due_kind, due_date, due_at, color, show_in_calendar)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING ",
        todo_columns!()
    ))
    .bind(user_id)
    .bind(params.title)
    .bind(params.notes)
    .bind(params.due_kind.as_str())
    .bind(params.due_date)
    .bind(params.due_at)
    .bind(params.color.map(Color::as_str))
    .bind(params.show_in_calendar)
    .fetch_one(&mut *tx)
    .await?;

    sqlx::query(
        "UPDATE idempotency_keys SET status_code = $4, response = $5
         WHERE user_id = $1 AND endpoint = $2 AND key = $3",
    )
    .bind(user_id)
    .bind(CREATE_ENDPOINT)
    .bind(params.idempotency_key)
    .bind(201_i16)
    .bind(serde_json::to_value(&todo).expect("todo serialization cannot fail"))
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(todo)
}

pub struct PatchParams<'a> {
    pub revision: i32,
    pub title: Option<&'a str>,
    pub notes: Option<&'a str>,
    /// 整组替换：`Some` 时三个字段一起写，未提供的清成 null。
    pub due: Option<Due>,
    /// `None` 保留原值、`Some(None)` 存 null、`Some(Some(_))` 设值。
    pub color: Option<Option<Color>>,
    pub completed: Option<bool>,
    pub show_in_calendar: Option<bool>,
}

#[derive(Debug)]
pub enum PatchError {
    NotFound,
    RevisionConflict(Todo),
    Db(sqlx::Error),
}

impl From<sqlx::Error> for PatchError {
    fn from(error: sqlx::Error) -> Self {
        Self::Db(error)
    }
}

pub async fn patch(
    pool: &PgPool,
    user_id: Uuid,
    id: Uuid,
    params: PatchParams<'_>,
) -> Result<Todo, PatchError> {
    let mut query = QueryBuilder::<Postgres>::new(
        "UPDATE todos SET revision = revision + 1, updated_at = now()",
    );
    if let Some(title) = params.title {
        query.push(", title = ").push_bind(title);
    }
    if let Some(notes) = params.notes {
        query.push(", notes = ").push_bind(notes);
    }
    if let Some(due) = params.due {
        query
            .push(", due_kind = ")
            .push_bind(due.kind.as_str())
            .push(", due_date = ")
            .push_bind(due.date)
            .push(", due_at = ")
            .push_bind(due.at);
    }
    if let Some(color) = params.color {
        query.push(", color = ").push_bind(color.map(Color::as_str));
    }
    if let Some(completed) = params.completed {
        query.push(", completed = ").push_bind(completed);
    }
    if let Some(show_in_calendar) = params.show_in_calendar {
        query
            .push(", show_in_calendar = ")
            .push_bind(show_in_calendar);
    }
    query
        .push(" WHERE id = ")
        .push_bind(id)
        .push(" AND user_id = ")
        .push_bind(user_id)
        .push(" AND revision = ")
        .push_bind(params.revision)
        .push(" AND deleted_at IS NULL RETURNING ")
        .push(todo_columns!());

    let updated = query.build_query_as::<Todo>().fetch_optional(pool).await?;
    match updated {
        Some(todo) => Ok(todo),
        None => match current(pool, user_id, id).await? {
            Some(current) => Err(PatchError::RevisionConflict(current)),
            None => Err(PatchError::NotFound),
        },
    }
}

#[derive(Debug)]
pub enum DeleteError {
    NotFound,
    RevisionConflict(Todo),
    Db(sqlx::Error),
}

impl From<sqlx::Error> for DeleteError {
    fn from(error: sqlx::Error) -> Self {
        Self::Db(error)
    }
}

pub async fn delete(
    pool: &PgPool,
    user_id: Uuid,
    id: Uuid,
    revision: i32,
) -> Result<(), DeleteError> {
    let result = sqlx::query(
        "UPDATE todos SET deleted_at = now(), updated_at = now()
         WHERE id = $1 AND user_id = $2 AND revision = $3 AND deleted_at IS NULL",
    )
    .bind(id)
    .bind(user_id)
    .bind(revision)
    .execute(pool)
    .await?;

    if result.rows_affected() == 1 {
        return Ok(());
    }
    match current(pool, user_id, id).await? {
        Some(current) => Err(DeleteError::RevisionConflict(current)),
        None => Err(DeleteError::NotFound),
    }
}

async fn current(pool: &PgPool, user_id: Uuid, id: Uuid) -> Result<Option<Todo>, sqlx::Error> {
    sqlx::query_as::<_, Todo>(concat!(
        "SELECT ",
        todo_columns!(),
        " FROM todos WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL"
    ))
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
}
