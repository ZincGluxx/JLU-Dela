//! 待办 DTO 与字段校验。
//!
//! 校验统一产出 `fields[{path, code}]`。长度按 Unicode 字符（`char`）计，不按字节
//! 或 UTF-16 码元，因此 200 个 emoji 仍是合法标题。

use std::fmt::Write as _;

use chrono::{DateTime, NaiveDate, SecondsFormat, Utc};
use serde::{Deserialize, Deserializer, Serialize};
use serde_json::{Map, Value};
use sha2::{Digest, Sha256};
use uuid::Uuid;

use super::error::FieldError;

pub const TITLE_MAX_CHARS: usize = 200;
pub const NOTES_MAX_CHARS: usize = 20_000;

const CREATE_ALLOWED: [&str; 7] = [
    "title",
    "notes",
    "due_kind",
    "due_date",
    "due_at",
    "color",
    "show_in_calendar",
];
const CREATE_FORBIDDEN: [&str; 4] = ["id", "revision", "owner_id", "source_status"];
const UPDATE_ALLOWED: [&str; 9] = [
    "revision",
    "title",
    "notes",
    "due_kind",
    "due_date",
    "due_at",
    "color",
    "completed",
    "show_in_calendar",
];
const UPDATE_FORBIDDEN: [&str; 3] = ["id", "owner_id", "source_status"];

/// 个人待办的截止三态。`relative` / `unknown` 只属于 Assignment，这里不出现。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DueKind {
    None,
    DateOnly,
    Exact,
}

impl DueKind {
    pub fn parse(raw: &str) -> Option<Self> {
        match raw {
            "none" => Some(Self::None),
            "date_only" => Some(Self::DateOnly),
            "exact" => Some(Self::Exact),
            _ => None,
        }
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::None => "none",
            Self::DateOnly => "date_only",
            Self::Exact => "exact",
        }
    }
}

/// 日历配色键，与 `app/src/shared/timetable.ts` 的 `calendarEventColors` 一一对应。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Color {
    Rose,
    Peach,
    Sand,
    Sage,
    Teal,
    Blue,
    Lilac,
    Slate,
}

impl Color {
    pub fn parse(raw: &str) -> Option<Self> {
        match raw {
            "rose" => Some(Self::Rose),
            "peach" => Some(Self::Peach),
            "sand" => Some(Self::Sand),
            "sage" => Some(Self::Sage),
            "teal" => Some(Self::Teal),
            "blue" => Some(Self::Blue),
            "lilac" => Some(Self::Lilac),
            "slate" => Some(Self::Slate),
            _ => None,
        }
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::Rose => "rose",
            Self::Peach => "peach",
            Self::Sand => "sand",
            Self::Sage => "sage",
            Self::Teal => "teal",
            Self::Blue => "blue",
            Self::Lilac => "lilac",
            Self::Slate => "slate",
        }
    }
}

/// 截止信息整组：`kind` 判别，另两个字段必须与它互斥。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct Due {
    pub kind: DueKind,
    pub date: Option<NaiveDate>,
    pub at: Option<DateTime<Utc>>,
}

/// 对外输出的待办。`user_id` 与 `deleted_at` 不进入响应。
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Todo {
    pub id: Uuid,
    pub title: String,
    pub notes: String,
    pub due_kind: DueKind,
    pub due_date: Option<NaiveDate>,
    pub due_at: Option<DateTime<Utc>>,
    pub color: Option<Color>,
    pub completed: bool,
    pub show_in_calendar: bool,
    pub revision: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 已校验的创建请求。
#[derive(Debug, Clone)]
pub struct CreateTodo {
    pub title: String,
    pub notes: String,
    pub due: Due,
    pub color: Option<Color>,
    pub show_in_calendar: bool,
}

/// 已校验的更新请求。
///
/// `due`：`Some` 表示请求给了 `due_kind`，三个字段整组替换；`None` 整组保持原值。
/// `color` 三态：`None` 缺省保留、`Some(None)` 显式 null 恢复默认、`Some(Some(_))` 设值。
#[derive(Debug, Clone, Default)]
pub struct UpdateTodo {
    pub revision: i32,
    pub title: Option<String>,
    pub notes: Option<String>,
    pub due: Option<Due>,
    pub color: Option<Option<Color>>,
    pub completed: Option<bool>,
    pub show_in_calendar: Option<bool>,
}

pub fn parse_create(body: &Value) -> Result<CreateTodo, Vec<FieldError>> {
    let map = body
        .as_object()
        .ok_or_else(|| vec![FieldError::new("body", "INVALID_TYPE")])?;
    let mut fields = Vec::new();
    check_fields(map, &CREATE_ALLOWED, &CREATE_FORBIDDEN, &mut fields);

    let title = required_title(map.get("title"), &mut fields);
    let notes = match map.get("notes") {
        None => Some(String::new()),
        Some(value) => notes_value(value, &mut fields),
    };
    let due = create_due_group(map, &mut fields).flatten();
    let color = color_value(map.get("color"), &mut fields).flatten();
    let show_in_calendar = match map.get("show_in_calendar") {
        None => Some(true),
        Some(value) => bool_value(value, "show_in_calendar", &mut fields),
    };

    if !fields.is_empty() {
        return Err(fields);
    }
    match (title, notes, due, show_in_calendar) {
        (Some(title), Some(notes), Some(due), Some(show_in_calendar)) => Ok(CreateTodo {
            title,
            notes,
            due,
            color,
            show_in_calendar,
        }),
        _ => Err(vec![FieldError::new("body", "INVALID_TYPE")]),
    }
}

pub fn parse_update(body: &Value) -> Result<UpdateTodo, Vec<FieldError>> {
    let map = body
        .as_object()
        .ok_or_else(|| vec![FieldError::new("body", "INVALID_TYPE")])?;
    let mut fields = Vec::new();
    check_fields(map, &UPDATE_ALLOWED, &UPDATE_FORBIDDEN, &mut fields);

    let revision = match map.get("revision") {
        None => {
            fields.push(FieldError::new("revision", "REQUIRED"));
            None
        }
        Some(value) => revision_value(value, &mut fields),
    };
    let title = match map.get("title") {
        None => None,
        Some(value) => title_value(value, &mut fields),
    };
    let notes = match map.get("notes") {
        None => None,
        Some(value) => notes_value(value, &mut fields),
    };
    let due = due_group(map, None, &mut fields);
    let color = color_value(map.get("color"), &mut fields);
    let completed = match map.get("completed") {
        None => None,
        Some(value) => bool_value(value, "completed", &mut fields),
    };
    let show_in_calendar = match map.get("show_in_calendar") {
        None => None,
        Some(value) => bool_value(value, "show_in_calendar", &mut fields),
    };

    if !fields.is_empty() {
        return Err(fields);
    }
    match revision {
        Some(revision) => Ok(UpdateTodo {
            revision,
            title,
            notes,
            due: due.flatten(),
            color,
            completed,
            show_in_calendar,
        }),
        None => Err(vec![FieldError::new("revision", "REQUIRED")]),
    }
}

/// 幂等摘要：只覆盖参与创建语义的字段，`due_at` 归一成 UTC RFC 3339。
pub fn request_hash(request: &CreateTodo) -> String {
    let canonical = serde_json::json!({
        "title": request.title,
        "notes": request.notes,
        "due_kind": request.due.kind,
        "due_date": request.due.date,
        "due_at": request.due.at.map(|due_at| due_at.to_rfc3339_opts(SecondsFormat::AutoSi, true)),
        "color": request.color,
        "show_in_calendar": request.show_in_calendar,
    });
    hex(&Sha256::digest(canonical.to_string()))
}

/// 区分「字段缺省」与「显式 null」：缺省由 `default` 填成 `None`，
/// 显式 null 走这里得到 `Some(None)`。
pub fn deserialize_some<'de, D, T>(deserializer: D) -> Result<Option<T>, D::Error>
where
    D: Deserializer<'de>,
    T: Deserialize<'de>,
{
    T::deserialize(deserializer).map(Some)
}

/// `color` 的三态载体。
#[derive(Debug, Default, Deserialize)]
pub struct ColorPatch {
    #[serde(default, deserialize_with = "deserialize_some")]
    pub color: Option<Option<Color>>,
}

fn check_fields(
    map: &Map<String, Value>,
    allowed: &[&str],
    forbidden: &[&str],
    fields: &mut Vec<FieldError>,
) {
    for key in map.keys() {
        if forbidden.contains(&key.as_str()) {
            fields.push(FieldError::new(key, "FORBIDDEN_FIELD"));
        } else if !allowed.contains(&key.as_str()) {
            fields.push(FieldError::new(key, "UNKNOWN_FIELD"));
        }
    }
}

fn required_title(value: Option<&Value>, fields: &mut Vec<FieldError>) -> Option<String> {
    match value {
        None => {
            fields.push(FieldError::new("title", "REQUIRED"));
            None
        }
        Some(value) => title_value(value, fields),
    }
}

fn title_value(value: &Value, fields: &mut Vec<FieldError>) -> Option<String> {
    let Some(raw) = value.as_str() else {
        fields.push(FieldError::new("title", "INVALID_TYPE"));
        return None;
    };
    let title = raw.trim();
    let chars = title.chars().count();
    if chars == 0 {
        fields.push(FieldError::new("title", "TOO_SHORT"));
        return None;
    }
    if chars > TITLE_MAX_CHARS {
        fields.push(FieldError::new("title", "TOO_LONG"));
        return None;
    }
    Some(title.to_owned())
}

fn notes_value(value: &Value, fields: &mut Vec<FieldError>) -> Option<String> {
    let Some(raw) = value.as_str() else {
        fields.push(FieldError::new("notes", "INVALID_TYPE"));
        return None;
    };
    if raw.chars().count() > NOTES_MAX_CHARS {
        fields.push(FieldError::new("notes", "TOO_LONG"));
        return None;
    }
    Some(raw.to_owned())
}

/// 创建时的截止三字段：`due_kind` 缺省则按值推断（A 的裁决）。
///
/// 只给 `due_at` → `exact`；只给 `due_date` → `date_only`；都不给（或都为 null）
/// → `none`；两者都给 → 422。给了 `due_kind` 时按它校验，不做推断。
fn create_due_group(map: &Map<String, Value>, fields: &mut Vec<FieldError>) -> Option<Option<Due>> {
    if map.contains_key("due_kind") {
        return due_group(map, None, fields);
    }
    let date = match map.get("due_date") {
        None => Some(None),
        Some(value) => due_date_value(value, fields),
    }?;
    let at = match map.get("due_at") {
        None => Some(None),
        Some(value) => due_at_value(value, fields),
    }?;
    let due = match (date, at) {
        (Some(_), Some(_)) => {
            fields.push(FieldError::new("due_kind", "DUE_KIND_MISMATCH"));
            None
        }
        (None, Some(at)) => Some(Due {
            kind: DueKind::Exact,
            date: None,
            at: Some(at),
        }),
        (Some(date), None) => Some(Due {
            kind: DueKind::DateOnly,
            date: Some(date),
            at: None,
        }),
        (None, None) => Some(Due {
            kind: DueKind::None,
            date: None,
            at: None,
        }),
    };
    Some(due)
}

/// 截止三字段。`fallback` 是请求里没给 `due_kind` 时的既定值：更新传 `None`
/// （整组保持原值）。
///
/// 更新路径的组例外：没给 `due_kind` 却给了 `due_date` / `due_at`（含显式 null）
/// 一律 422，否则客户端发 `Optional.present(null)` 会以为清空了截止，而服务端
/// 静默保持原值。清空必须显式 `due_kind: "none"`。
///
/// 外层 `None` 表示字段本身解析失败，`Some(None)` 表示「保持原值」。
fn due_group(
    map: &Map<String, Value>,
    fallback: Option<DueKind>,
    fields: &mut Vec<FieldError>,
) -> Option<Option<Due>> {
    let kind = match map.get("due_kind") {
        None => {
            if fallback.is_none() {
                let mut stray = false;
                for path in ["due_date", "due_at"] {
                    if map.contains_key(path) {
                        fields.push(FieldError::new(path, "DUE_KIND_MISMATCH"));
                        stray = true;
                    }
                }
                if stray {
                    return None;
                }
            }
            fallback
        }
        Some(value) => due_kind_value(value, fields).map(Some)?,
    };
    let date = match map.get("due_date") {
        None => Some(None),
        Some(value) => due_date_value(value, fields),
    }?;
    let at = match map.get("due_at") {
        None => Some(None),
        Some(value) => due_at_value(value, fields),
    }?;

    let due = match kind {
        None | Some(DueKind::None) => {
            if date.is_some() {
                fields.push(FieldError::new("due_date", "DUE_KIND_MISMATCH"));
            }
            if at.is_some() {
                fields.push(FieldError::new("due_at", "DUE_KIND_MISMATCH"));
            }
            kind.map(|kind| Due {
                kind,
                date: None,
                at: None,
            })
        }
        Some(DueKind::DateOnly) => {
            if date.is_none() {
                fields.push(FieldError::new("due_date", "REQUIRED"));
            }
            if at.is_some() {
                fields.push(FieldError::new("due_at", "DUE_KIND_MISMATCH"));
            }
            Some(Due {
                kind: DueKind::DateOnly,
                date,
                at: None,
            })
        }
        Some(DueKind::Exact) => {
            if at.is_none() {
                fields.push(FieldError::new("due_at", "REQUIRED"));
            }
            if date.is_some() {
                fields.push(FieldError::new("due_date", "DUE_KIND_MISMATCH"));
            }
            Some(Due {
                kind: DueKind::Exact,
                date: None,
                at,
            })
        }
    };
    Some(due)
}

fn due_kind_value(value: &Value, fields: &mut Vec<FieldError>) -> Option<DueKind> {
    let Some(raw) = value.as_str() else {
        fields.push(FieldError::new("due_kind", "INVALID_TYPE"));
        return None;
    };
    match DueKind::parse(raw) {
        Some(kind) => Some(kind),
        None => {
            fields.push(FieldError::new("due_kind", "INVALID_VALUE"));
            None
        }
    }
}

fn due_date_value(value: &Value, fields: &mut Vec<FieldError>) -> Option<Option<NaiveDate>> {
    if value.is_null() {
        return Some(None);
    }
    let Some(raw) = value.as_str() else {
        fields.push(FieldError::new("due_date", "INVALID_TYPE"));
        return None;
    };
    match NaiveDate::parse_from_str(raw, "%Y-%m-%d") {
        Ok(date) => Some(Some(date)),
        Err(_) => {
            fields.push(FieldError::new("due_date", "INVALID_FORMAT"));
            None
        }
    }
}

fn due_at_value(value: &Value, fields: &mut Vec<FieldError>) -> Option<Option<DateTime<Utc>>> {
    if value.is_null() {
        return Some(None);
    }
    let Some(raw) = value.as_str() else {
        fields.push(FieldError::new("due_at", "INVALID_TYPE"));
        return None;
    };
    match DateTime::parse_from_rfc3339(raw) {
        Ok(parsed) => Some(Some(parsed.with_timezone(&Utc))),
        Err(_) => {
            fields.push(FieldError::new("due_at", "INVALID_FORMAT"));
            None
        }
    }
}

/// `None` 表示字段缺省，`Some(None)` 表示显式 null；解析失败记入 `fields` 并同样返回 `None`。
fn color_value(value: Option<&Value>, fields: &mut Vec<FieldError>) -> Option<Option<Color>> {
    let value = value?;
    if !value.is_null() && !value.is_string() {
        fields.push(FieldError::new("color", "INVALID_TYPE"));
        return None;
    }
    let mut patch = Map::new();
    patch.insert("color".to_owned(), value.clone());
    match serde_json::from_value::<ColorPatch>(Value::Object(patch)) {
        Ok(patch) => patch.color,
        Err(_) => {
            fields.push(FieldError::new("color", "INVALID_VALUE"));
            None
        }
    }
}

fn bool_value(value: &Value, path: &'static str, fields: &mut Vec<FieldError>) -> Option<bool> {
    match value.as_bool() {
        Some(flag) => Some(flag),
        None => {
            fields.push(FieldError::new(path, "INVALID_TYPE"));
            None
        }
    }
}

fn revision_value(value: &Value, fields: &mut Vec<FieldError>) -> Option<i32> {
    let Some(raw) = value.as_i64() else {
        fields.push(FieldError::new("revision", "INVALID_TYPE"));
        return None;
    };
    if raw < 1 || raw > i64::from(i32::MAX) {
        fields.push(FieldError::new("revision", "OUT_OF_RANGE"));
        return None;
    }
    Some(raw as i32)
}

fn hex(bytes: &[u8]) -> String {
    let mut output = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        write!(&mut output, "{byte:02x}").expect("写入 String 不会失败");
    }
    output
}
