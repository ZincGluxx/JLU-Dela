//! 待办的纯函数测试：不连数据库，只覆盖字段校验、幂等摘要与游标。

use chrono::{DateTime, FixedOffset, NaiveDate, TimeZone, Utc};
use serde_json::{Value, json};
use uuid::Uuid;

use super::model::{self, Color, ColorPatch, Due, DueKind, NOTES_MAX_CHARS, TITLE_MAX_CHARS};
use super::repo::{Cursor, CursorError};

fn title_codes(title: &str) -> Vec<&'static str> {
    match model::parse_create(&json!({ "title": title })) {
        Ok(_) => Vec::new(),
        Err(fields) => fields.into_iter().map(|field| field.code).collect(),
    }
}

fn create_errors(body: Value) -> Vec<(String, &'static str)> {
    match model::parse_create(&body) {
        Ok(_) => Vec::new(),
        Err(fields) => fields
            .into_iter()
            .map(|field| (field.path, field.code))
            .collect(),
    }
}

fn update_errors(body: Value) -> Vec<(String, &'static str)> {
    match model::parse_update(&body) {
        Ok(_) => Vec::new(),
        Err(fields) => fields
            .into_iter()
            .map(|field| (field.path, field.code))
            .collect(),
    }
}

fn date(year: i32, month: u32, day: u32) -> NaiveDate {
    NaiveDate::from_ymd_opt(year, month, day).expect("合法日期")
}

fn instant(hour: u32) -> DateTime<Utc> {
    Utc.with_ymd_and_hms(2026, 11, 12, hour, 0, 0).unwrap()
}

#[test]
fn title_accepts_one_hundred_ninety_nine_and_two_hundred() {
    assert!(title_codes(&"a".repeat(TITLE_MAX_CHARS - 1)).is_empty());
    assert!(title_codes(&"a".repeat(TITLE_MAX_CHARS)).is_empty());
    assert_eq!(title_codes(&"a".repeat(TITLE_MAX_CHARS + 1)), ["TOO_LONG"]);
}

#[test]
fn title_counts_unicode_chars_not_bytes() {
    assert!(title_codes(&"🎓".repeat(TITLE_MAX_CHARS)).is_empty());
    assert_eq!(title_codes(&"🎓".repeat(TITLE_MAX_CHARS + 1)), ["TOO_LONG"]);
}

#[test]
fn title_is_trimmed_before_validation_and_storage() {
    let todo = model::parse_create(&json!({ "title": "  整理课堂笔记  " })).expect("合法标题");
    assert_eq!(todo.title, "整理课堂笔记");
    assert_eq!(title_codes("   "), ["TOO_SHORT"]);
}

#[test]
fn notes_boundary_is_twenty_thousand_chars() {
    let at_limit = json!({ "title": "t", "notes": "n".repeat(NOTES_MAX_CHARS) });
    assert!(model::parse_create(&at_limit).is_ok());

    let over_limit = json!({ "title": "t", "notes": "n".repeat(NOTES_MAX_CHARS + 1) });
    let fields = model::parse_create(&over_limit).expect_err("超长 notes 应被拒绝");
    assert_eq!(fields.len(), 1);
    assert_eq!(
        (fields[0].path.as_str(), fields[0].code),
        ("notes", "TOO_LONG")
    );
}

#[test]
fn create_rejects_forbidden_and_unknown_fields() {
    let body = json!({
        "title": "t",
        "id": Uuid::nil(),
        "revision": 1,
        "owner_id": Uuid::nil(),
        "source_status": "pending",
        "extra": true,
    });
    let fields = model::parse_create(&body).expect_err("应拒绝受管字段");
    let pairs: Vec<(&str, &str)> = fields
        .iter()
        .map(|field| (field.path.as_str(), field.code))
        .collect();
    assert_eq!(
        pairs,
        [
            ("extra", "UNKNOWN_FIELD"),
            ("id", "FORBIDDEN_FIELD"),
            ("owner_id", "FORBIDDEN_FIELD"),
            ("revision", "FORBIDDEN_FIELD"),
            ("source_status", "FORBIDDEN_FIELD"),
        ]
    );
}

#[test]
fn create_requires_title() {
    let fields = model::parse_create(&json!({ "notes": "" })).expect_err("缺 title");
    assert_eq!(
        (fields[0].path.as_str(), fields[0].code),
        ("title", "REQUIRED")
    );
}

#[test]
fn update_requires_revision_and_allows_clearing_due() {
    let fields = model::parse_update(&json!({ "title": "t" })).expect_err("缺 revision");
    assert_eq!(
        (fields[0].path.as_str(), fields[0].code),
        ("revision", "REQUIRED")
    );

    let update =
        model::parse_update(&json!({ "revision": 2, "due_kind": "none" })).expect("合法更新");
    assert_eq!(
        update.due,
        Some(Due {
            kind: DueKind::None,
            date: None,
            at: None,
        })
    );
    assert!(update.title.is_none());
}

#[test]
fn create_defaults_due_to_none_when_omitted() {
    let todo = model::parse_create(&json!({ "title": "t" })).expect("合法创建");
    assert_eq!(
        todo.due,
        Due {
            kind: DueKind::None,
            date: None,
            at: None,
        }
    );
    assert!(todo.due.date.is_none());
    assert!(todo.due.at.is_none());
    assert!(todo.color.is_none());
}

#[test]
fn create_accepts_each_due_shape() {
    let date_only = model::parse_create(&json!({
        "title": "t",
        "due_kind": "date_only",
        "due_date": "2026-11-13",
    }))
    .expect("合法创建");
    assert_eq!(
        date_only.due,
        Due {
            kind: DueKind::DateOnly,
            date: Some(date(2026, 11, 13)),
            at: None,
        }
    );

    let exact = model::parse_create(&json!({
        "title": "t",
        "due_kind": "exact",
        "due_at": "2026-11-12T09:00:00Z",
    }))
    .expect("合法创建");
    assert_eq!(
        exact.due,
        Due {
            kind: DueKind::Exact,
            date: None,
            at: Some(instant(9)),
        }
    );
}

#[test]
fn due_kind_rejects_values_from_another_shape() {
    assert_eq!(
        update_errors(json!({
            "revision": 2,
            "due_kind": "date_only",
            "due_date": "2026-11-13",
            "due_at": "2026-11-12T09:00:00Z",
        })),
        [("due_at".to_owned(), "DUE_KIND_MISMATCH")]
    );
    assert_eq!(
        update_errors(json!({
            "revision": 2,
            "due_kind": "exact",
            "due_date": "2026-11-13",
            "due_at": "2026-11-12T09:00:00Z",
        })),
        [("due_date".to_owned(), "DUE_KIND_MISMATCH")]
    );
    assert_eq!(
        update_errors(
            json!({ "revision": 2, "due_kind": "none", "due_at": "2026-11-12T09:00:00Z" })
        ),
        [("due_at".to_owned(), "DUE_KIND_MISMATCH")]
    );
    assert_eq!(
        update_errors(json!({ "revision": 2, "due_kind": "none", "due_date": "2026-11-13" })),
        [("due_date".to_owned(), "DUE_KIND_MISMATCH")]
    );
}

#[test]
fn due_kind_requires_its_own_value() {
    assert_eq!(
        create_errors(json!({ "title": "t", "due_kind": "relative" })),
        [("due_kind".to_owned(), "INVALID_VALUE")]
    );
    assert_eq!(
        create_errors(json!({ "title": "t", "due_kind": "date_only" })),
        [("due_date".to_owned(), "REQUIRED")]
    );
    assert_eq!(
        create_errors(json!({ "title": "t", "due_kind": "exact" })),
        [("due_at".to_owned(), "REQUIRED")]
    );
    assert_eq!(
        create_errors(json!({ "title": "t", "due_kind": "exact", "due_at": "2026-11-12" })),
        [("due_at".to_owned(), "INVALID_FORMAT")]
    );
}

#[test]
fn update_due_kind_replaces_the_whole_group() {
    let switched = model::parse_update(&json!({
        "revision": 2,
        "due_kind": "date_only",
        "due_date": "2026-11-13",
    }))
    .expect("合法更新");
    assert_eq!(
        switched.due,
        Some(Due {
            kind: DueKind::DateOnly,
            date: Some(date(2026, 11, 13)),
            at: None,
        })
    );

    let cleared =
        model::parse_update(&json!({ "revision": 2, "due_kind": "none" })).expect("合法更新");
    assert_eq!(
        cleared.due,
        Some(Due {
            kind: DueKind::None,
            date: None,
            at: None,
        })
    );
}

#[test]
fn update_without_due_kind_keeps_the_group() {
    let update = model::parse_update(&json!({ "revision": 2, "title": "t" })).expect("合法更新");
    assert!(update.due.is_none());

    assert_eq!(
        update_errors(json!({ "revision": 2, "due_at": "2026-11-12T09:00:00Z" })),
        [("due_at".to_owned(), "DUE_KIND_MISMATCH")]
    );
}

/// 显式 null 也是「给了 due_date / due_at」：更新不推断类型，必须 422，
/// 否则客户端发 `Optional.present(null)` 会以为清空了截止。
#[test]
fn update_rejects_explicit_null_due_fields_without_due_kind() {
    assert_eq!(
        update_errors(json!({ "revision": 2, "due_date": null })),
        [("due_date".to_owned(), "DUE_KIND_MISMATCH")]
    );
    assert_eq!(
        update_errors(json!({ "revision": 2, "due_at": null })),
        [("due_at".to_owned(), "DUE_KIND_MISMATCH")]
    );
    assert_eq!(
        update_errors(json!({ "revision": 2, "due_date": null, "due_at": null })),
        [
            ("due_date".to_owned(), "DUE_KIND_MISMATCH"),
            ("due_at".to_owned(), "DUE_KIND_MISMATCH"),
        ]
    );

    // 显式 due_kind 才是清空的正路
    let cleared = model::parse_update(&json!({ "revision": 2, "due_kind": "none" }))
        .expect("显式 due_kind 清空合法");
    assert_eq!(
        cleared.due,
        Some(Due {
            kind: DueKind::None,
            date: None,
            at: None,
        })
    );
}

/// 创建时 `due_kind` 缺省按值推断（A 的裁决），更新时一律不推断。
#[test]
fn create_infers_due_kind_from_the_supplied_values() {
    let from_at = model::parse_create(&json!({
        "title": "t",
        "due_at": "2026-11-12T09:00:00Z",
    }))
    .expect("只给 due_at 合法");
    assert_eq!(
        from_at.due,
        Due {
            kind: DueKind::Exact,
            date: None,
            at: Some(instant(9)),
        }
    );

    let from_date = model::parse_create(&json!({
        "title": "t",
        "due_date": "2026-11-13",
    }))
    .expect("只给 due_date 合法");
    assert_eq!(
        from_date.due,
        Due {
            kind: DueKind::DateOnly,
            date: Some(date(2026, 11, 13)),
            at: None,
        }
    );

    // 显式 null 等同于没给，落到 none
    let from_nulls = model::parse_create(&json!({
        "title": "t",
        "due_date": null,
        "due_at": null,
    }))
    .expect("两个 null 合法");
    assert_eq!(from_nulls.due.kind, DueKind::None);

    // 两者都给无法推断
    assert_eq!(
        create_errors(json!({
            "title": "t",
            "due_date": "2026-11-13",
            "due_at": "2026-11-13T09:00:00Z",
        })),
        [("due_kind".to_owned(), "DUE_KIND_MISMATCH")]
    );
}

#[test]
fn color_patch_distinguishes_absent_null_and_value() {
    let absent: ColorPatch = serde_json::from_value(json!({})).expect("合法补丁");
    assert_eq!(absent.color, None);

    let explicit_null: ColorPatch =
        serde_json::from_value(json!({ "color": null })).expect("合法补丁");
    assert_eq!(explicit_null.color, Some(None));

    let teal: ColorPatch = serde_json::from_value(json!({ "color": "teal" })).expect("合法补丁");
    assert_eq!(teal.color, Some(Some(Color::Teal)));
}

#[test]
fn update_color_tristate_matches_the_wire() {
    assert_eq!(
        model::parse_update(&json!({ "revision": 2 }))
            .expect("合法更新")
            .color,
        None
    );
    assert_eq!(
        model::parse_update(&json!({ "revision": 2, "color": null }))
            .expect("合法更新")
            .color,
        Some(None)
    );
    assert_eq!(
        model::parse_update(&json!({ "revision": 2, "color": "teal" }))
            .expect("合法更新")
            .color,
        Some(Some(Color::Teal))
    );
    assert_eq!(
        update_errors(json!({ "revision": 2, "color": "pink" })),
        [("color".to_owned(), "INVALID_VALUE")]
    );
    assert_eq!(
        create_errors(json!({ "title": "t", "color": 3 })),
        [("color".to_owned(), "INVALID_TYPE")]
    );
}

#[test]
fn request_hash_is_stable_and_content_sensitive() {
    let first = model::parse_create(&json!({
        "title": "整理",
        "notes": "",
        "due_kind": "exact",
        "due_at": "2026-11-12T09:00:00Z",
        "show_in_calendar": true,
    }))
    .expect("合法请求");
    let equivalent = model::parse_create(&json!({
        "title": "  整理  ",
        "due_kind": "exact",
        "due_at": "2026-11-12T09:00:00+00:00",
    }))
    .expect("合法请求");
    let changed = model::parse_create(&json!({
        "title": "整理",
        "due_kind": "exact",
        "due_at": "2026-11-12T09:00:01Z",
    }))
    .expect("合法请求");
    let recolored = model::parse_create(&json!({
        "title": "整理",
        "due_kind": "exact",
        "due_at": "2026-11-12T09:00:00Z",
        "color": "teal",
    }))
    .expect("合法请求");

    assert_eq!(model::request_hash(&first), model::request_hash(&first));
    assert_eq!(
        model::request_hash(&first),
        model::request_hash(&equivalent)
    );
    assert_ne!(model::request_hash(&first), model::request_hash(&changed));
    assert_ne!(model::request_hash(&first), model::request_hash(&recolored));
}

#[test]
fn wire_names_match_the_sql_literals() {
    for kind in [DueKind::None, DueKind::DateOnly, DueKind::Exact] {
        assert_eq!(serde_json::to_value(kind).unwrap(), json!(kind.as_str()));
        assert_eq!(DueKind::parse(kind.as_str()), Some(kind));
    }
    for color in [
        Color::Rose,
        Color::Peach,
        Color::Sand,
        Color::Sage,
        Color::Teal,
        Color::Blue,
        Color::Lilac,
        Color::Slate,
    ] {
        assert_eq!(serde_json::to_value(color).unwrap(), json!(color.as_str()));
        assert_eq!(Color::parse(color.as_str()), Some(color));
    }
    assert_eq!(
        serde_json::to_value(date(2026, 11, 13)).unwrap(),
        json!("2026-11-13")
    );
}

/// §5.1：`date_only` 的 00:00 是北京时间零点，UTC 上是前一天 16:00。
fn beijing_midnight(year: i32, month: u32, day: u32) -> DateTime<Utc> {
    let offset = FixedOffset::east_opt(8 * 3600).expect("固定偏移合法");
    offset
        .from_local_datetime(
            &date(year, month, day)
                .and_hms_opt(0, 0, 0)
                .expect("00:00 存在"),
        )
        .single()
        .expect("固定偏移无歧义")
        .with_timezone(&Utc)
}

fn sample_cursor() -> Cursor {
    Cursor {
        completed: Some(true),
        sort_key: Some(instant(9)),
        id: Uuid::nil(),
    }
}

#[test]
fn cursor_roundtrip_is_url_safe_and_lossless() {
    let cursor = sample_cursor();
    let encoded = cursor.encode();
    assert!(!encoded.contains('='), "URL_SAFE_NO_PAD 不应带填充");
    assert_eq!(Cursor::decode(&encoded), Ok(cursor));
}

#[test]
fn cursor_roundtrip_keeps_sort_key_of_date_only() {
    let cursor = Cursor {
        completed: None,
        sort_key: Some(beijing_midnight(2026, 11, 13)),
        id: Uuid::nil(),
    };
    assert_eq!(
        beijing_midnight(2026, 11, 13),
        Utc.with_ymd_and_hms(2026, 11, 12, 16, 0, 0).unwrap()
    );
    assert_eq!(Cursor::decode(&cursor.encode()), Ok(cursor));
}

#[test]
fn cursor_rejects_garbage_and_foreign_filters() {
    assert_eq!(Cursor::decode("not-a-cursor"), Err(CursorError::Malformed));

    let cursor = sample_cursor();
    assert_eq!(cursor.ensure_filter(None), Err(CursorError::FilterMismatch));
    assert_eq!(
        cursor.ensure_filter(Some(false)),
        Err(CursorError::FilterMismatch)
    );
    assert_eq!(cursor.ensure_filter(Some(true)), Ok(()));
}
