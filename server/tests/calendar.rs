#![cfg(feature = "integration")]

mod common;

use std::sync::Arc;

use axum::{
    Router,
    body::Body,
    http::{Method, Request, StatusCode, header},
};
use jlu_dela_api::{
    auth::session::{self, IssuedSession},
    calendar::{
        model::{AssignmentDueKind, AssignmentItem, CalendarItem, LessonItem, SourceState},
        source::{CalendarRange, CalendarSource, SourceResult},
    },
    config::Config,
    db, http,
    state::AppState,
    sync::SyncRegistry,
};
use serde_json::{Value, json};
use sqlx::PgPool;
use uuid::Uuid;

async fn setup() -> (Config, PgPool) {
    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL is required when running with --features integration");
    let config = common::config(&[("DATABASE_URL", &database_url)]);
    let pool = db::connect(&config).await.expect("PostgreSQL is reachable");
    db::run_migrations(&pool).await.expect("migrations apply");
    (config, pool)
}

fn router(config: &Config, pool: &PgPool) -> Router {
    http::router(AppState::new(pool.clone(), config.build_id.clone()), config)
}

fn router_with(config: &Config, pool: &PgPool, sources: Vec<Arc<dyn CalendarSource>>) -> Router {
    http::router(
        AppState::with_sources(
            pool.clone(),
            config.build_id.clone(),
            SyncRegistry::empty(),
            sources,
        ),
        config,
    )
}

async fn create_user(pool: &PgPool, display_name: &str) -> Uuid {
    let id = Uuid::new_v4();
    sqlx::query(
        "INSERT INTO users (id, login, display_name, timezone, created_at)
         VALUES ($1, $2, $3, 'Asia/Shanghai', now())",
    )
    .bind(id)
    .bind(format!("{display_name}-{id}"))
    .bind(display_name)
    .execute(pool)
    .await
    .expect("user is created");
    id
}

async fn issue(pool: &PgPool, user_id: Uuid) -> IssuedSession {
    session::issue_for_user(pool, user_id)
        .await
        .expect("session is issued")
}

fn builder(method: Method, uri: &str, token: Option<&str>) -> axum::http::request::Builder {
    let mut builder = Request::builder().method(method).uri(uri);
    if let Some(token) = token {
        builder = builder.header(header::AUTHORIZATION, format!("Bearer {token}"));
    }
    builder
}

fn get_calendar(token: Option<&str>, query: &str) -> Request<Body> {
    builder(Method::GET, &format!("/api/v1/calendar{query}"), token)
        .body(Body::empty())
        .unwrap()
}

async fn calendar(app: Router, token: &str, query: &str) -> Value {
    let (status, _, body) = common::send(app, get_calendar(Some(token), query)).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    body["data"].clone()
}

async fn create_todo(app: Router, token: &str, body: Value) -> Value {
    let request = builder(Method::POST, "/api/v1/todos", Some(token))
        .header(header::CONTENT_TYPE, "application/json")
        .header("idempotency-key", Uuid::new_v4().to_string())
        .body(Body::from(body.to_string()))
        .unwrap();
    let (status, _, response) = common::send(app, request).await;
    assert_eq!(status, StatusCode::CREATED, "{response}");
    response["data"].clone()
}

async fn patch_todo(app: Router, token: &str, id: &str, body: Value) -> Value {
    let request = builder(Method::PATCH, &format!("/api/v1/todos/{id}"), Some(token))
        .header(header::CONTENT_TYPE, "application/json")
        .body(Body::from(body.to_string()))
        .unwrap();
    let (status, _, response) = common::send(app, request).await;
    assert_eq!(status, StatusCode::OK, "{response}");
    response["data"].clone()
}

async fn delete_todo(app: Router, token: &str, id: &str, revision: i32) {
    let request = builder(Method::DELETE, &format!("/api/v1/todos/{id}"), Some(token))
        .header(header::IF_MATCH, revision.to_string())
        .body(Body::empty())
        .unwrap();
    let (status, _, response) = common::send(app, request).await;
    assert_eq!(status, StatusCode::NO_CONTENT, "{response}");
}

fn todo_ids(data: &Value) -> Vec<String> {
    data["items"]
        .as_array()
        .expect("items is an array")
        .iter()
        .map(|item| {
            assert_eq!(item["kind"], "todo", "{item}");
            item["todo_id"].as_str().expect("todo_id").to_owned()
        })
        .collect()
}

fn validation_field(body: &Value) -> (String, String) {
    assert_eq!(body["error"]["code"], "VALIDATION_FAILED", "{body}");
    let fields = body["error"]["fields"]
        .as_array()
        .expect("fields is an array");
    assert_eq!(fields.len(), 1, "{body}");
    (
        fields[0]["path"].as_str().expect("path").to_owned(),
        fields[0]["code"].as_str().expect("code").to_owned(),
    )
}

#[tokio::test]
async fn calendar_requires_a_bearer_session() {
    let (config, pool) = setup().await;
    let app = router(&config, &pool);

    let (status, _, body) =
        common::send(app, get_calendar(None, "?from=2026-11-10&to=2026-11-17")).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "AUTH_REQUIRED");
}

#[tokio::test]
async fn calendar_requires_both_bounds() {
    let (config, pool) = setup().await;
    let alice = create_user(&pool, "alice").await;
    let session = issue(&pool, alice).await;
    let app = router(&config, &pool);

    let (status, _, body) = common::send(
        app.clone(),
        get_calendar(Some(&session.access_token), "?to=2026-11-17"),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(validation_field(&body), ("from".into(), "REQUIRED".into()));

    let (status, _, body) = common::send(
        app,
        get_calendar(Some(&session.access_token), "?from=2026-11-10"),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(validation_field(&body), ("to".into(), "REQUIRED".into()));
}

#[tokio::test]
async fn calendar_rejects_malformed_days() {
    let (config, pool) = setup().await;
    let alice = create_user(&pool, "alice").await;
    let session = issue(&pool, alice).await;
    let app = router(&config, &pool);

    for query in [
        "?from=2026-11-1&to=2026-11-17",
        "?from=2026-13-01&to=2026-11-17",
        "?from=&to=2026-11-17",
        "?from=2026-11-10T00:00:00Z&to=2026-11-17",
    ] {
        let (status, _, body) = common::send(
            app.clone(),
            get_calendar(Some(&session.access_token), query),
        )
        .await;
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{query}");
        assert_eq!(
            validation_field(&body),
            ("from".into(), "INVALID_FORMAT".into()),
            "{query}"
        );
    }
}

#[tokio::test]
async fn calendar_rejects_reversed_and_oversized_ranges() {
    let (config, pool) = setup().await;
    let alice = create_user(&pool, "alice").await;
    let session = issue(&pool, alice).await;
    let app = router(&config, &pool);

    let (status, _, body) = common::send(
        app.clone(),
        get_calendar(
            Some(&session.access_token),
            "?from=2026-11-10&to=2026-11-10",
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(
        validation_field(&body),
        ("to".into(), "INVALID_RANGE".into())
    );

    let (status, _, body) = common::send(
        app.clone(),
        get_calendar(
            Some(&session.access_token),
            "?from=2026-11-17&to=2026-11-10",
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(
        validation_field(&body),
        ("to".into(), "INVALID_RANGE".into())
    );

    // 2026-01-01 起 94 天，超出 93 天上限
    let (status, _, body) = common::send(
        app.clone(),
        get_calendar(
            Some(&session.access_token),
            "?from=2026-01-01&to=2026-04-05",
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(
        validation_field(&body),
        ("to".into(), "RANGE_TOO_WIDE".into())
    );

    // 恰好 93 天是允许的上限
    let data = calendar(app, &session.access_token, "?from=2026-01-01&to=2026-04-04").await;
    assert_eq!(data["from"], "2026-01-01");
    assert_eq!(data["to"], "2026-04-04");
    assert_eq!(data["items"].as_array().expect("items").len(), 0);
}

#[tokio::test]
async fn exact_todos_use_half_open_utc_bounds() {
    let (config, pool) = setup().await;
    let alice = create_user(&pool, "alice").await;
    let session = issue(&pool, alice).await;
    let token = &session.access_token;
    let app = router(&config, &pool);

    // 2026-11-13 北京时间零点 = 2026-11-12T16:00:00Z
    let inside = create_todo(
        app.clone(),
        token,
        json!({ "title": "区间内", "due_kind": "exact", "due_at": "2026-11-13T00:00:00Z" }),
    )
    .await;
    let at_lower = create_todo(
        app.clone(),
        token,
        json!({ "title": "下界", "due_kind": "exact", "due_at": "2026-11-12T16:00:00Z" }),
    )
    .await;
    let at_upper = create_todo(
        app.clone(),
        token,
        json!({ "title": "上界", "due_kind": "exact", "due_at": "2026-11-13T16:00:00Z" }),
    )
    .await;
    let before = create_todo(
        app.clone(),
        token,
        json!({ "title": "下界之前", "due_kind": "exact", "due_at": "2026-11-12T15:59:59Z" }),
    )
    .await;

    let data = calendar(app, token, "?from=2026-11-13&to=2026-11-14").await;
    let ids = todo_ids(&data);
    assert_eq!(
        ids,
        vec![
            at_lower["id"].as_str().unwrap().to_owned(),
            inside["id"].as_str().unwrap().to_owned(),
        ]
    );
    assert!(!ids.contains(&at_upper["id"].as_str().unwrap().to_owned()));
    assert!(!ids.contains(&before["id"].as_str().unwrap().to_owned()));

    let item = &data["items"][0];
    assert_eq!(item["due_kind"], "exact");
    assert_eq!(item["due_at"], "2026-11-12T16:00:00Z");
    assert_eq!(item["due_date"], Value::Null);
    assert_eq!(item["show_in_calendar"], true);
    assert_eq!(item["completed"], false);
    assert_eq!(
        item["id"],
        format!("todo:{}", item["todo_id"].as_str().unwrap())
    );
}

#[tokio::test]
async fn date_only_todos_compare_calendar_days() {
    let (config, pool) = setup().await;
    let alice = create_user(&pool, "alice").await;
    let session = issue(&pool, alice).await;
    let token = &session.access_token;
    let app = router(&config, &pool);

    let at_lower = create_todo(
        app.clone(),
        token,
        json!({ "title": "起始日", "due_kind": "date_only", "due_date": "2026-11-13" }),
    )
    .await;
    let last_day = create_todo(
        app.clone(),
        token,
        json!({ "title": "最后一天", "due_kind": "date_only", "due_date": "2026-11-14" }),
    )
    .await;
    let at_upper = create_todo(
        app.clone(),
        token,
        json!({ "title": "结束日", "due_kind": "date_only", "due_date": "2026-11-15" }),
    )
    .await;

    let data = calendar(app, token, "?from=2026-11-13&to=2026-11-15").await;
    let ids = todo_ids(&data);
    assert_eq!(
        ids,
        vec![
            at_lower["id"].as_str().unwrap().to_owned(),
            last_day["id"].as_str().unwrap().to_owned(),
        ]
    );
    assert!(!ids.contains(&at_upper["id"].as_str().unwrap().to_owned()));

    let item = &data["items"][0];
    assert_eq!(item["due_kind"], "date_only");
    assert_eq!(item["due_date"], "2026-11-13");
    assert_eq!(item["due_at"], Value::Null);
}

#[tokio::test]
async fn undated_hidden_and_deleted_todos_stay_out() {
    let (config, pool) = setup().await;
    let alice = create_user(&pool, "alice").await;
    let session = issue(&pool, alice).await;
    let token = &session.access_token;
    let app = router(&config, &pool);

    let undated = create_todo(
        app.clone(),
        token,
        json!({ "title": "无日期", "due_kind": "none" }),
    )
    .await;
    let hidden = create_todo(
        app.clone(),
        token,
        json!({
            "title": "不进日历",
            "due_kind": "date_only",
            "due_date": "2026-11-13",
            "show_in_calendar": false,
        }),
    )
    .await;
    let deleted = create_todo(
        app.clone(),
        token,
        json!({ "title": "已删除", "due_kind": "date_only", "due_date": "2026-11-13" }),
    )
    .await;
    delete_todo(app.clone(), token, deleted["id"].as_str().unwrap(), 1).await;

    let visible = create_todo(
        app.clone(),
        token,
        json!({ "title": "可见", "due_kind": "date_only", "due_date": "2026-11-13" }),
    )
    .await;

    let data = calendar(app, token, "?from=2026-11-13&to=2026-11-14").await;
    assert_eq!(
        todo_ids(&data),
        vec![visible["id"].as_str().unwrap().to_owned()]
    );
    let raw = data["items"].to_string();
    assert!(!raw.contains(undated["id"].as_str().unwrap()));
    assert!(!raw.contains(hidden["id"].as_str().unwrap()));
    assert!(!raw.contains(deleted["id"].as_str().unwrap()));
}

#[tokio::test]
async fn completed_todos_are_reported_as_completed() {
    let (config, pool) = setup().await;
    let alice = create_user(&pool, "alice").await;
    let session = issue(&pool, alice).await;
    let token = &session.access_token;
    let app = router(&config, &pool);

    let todo = create_todo(
        app.clone(),
        token,
        json!({ "title": "已完成的", "due_kind": "exact", "due_at": "2026-11-13T02:00:00Z" }),
    )
    .await;
    patch_todo(
        app.clone(),
        token,
        todo["id"].as_str().unwrap(),
        json!({ "revision": 1, "completed": true }),
    )
    .await;

    let data = calendar(app, token, "?from=2026-11-13&to=2026-11-14").await;
    assert_eq!(
        todo_ids(&data),
        vec![todo["id"].as_str().unwrap().to_owned()]
    );
    assert_eq!(data["items"][0]["completed"], true);
}

#[tokio::test]
async fn calendar_is_isolated_per_user() {
    let (config, pool) = setup().await;
    let alice = create_user(&pool, "alice").await;
    let bob = create_user(&pool, "bob").await;
    let alice_session = issue(&pool, alice).await;
    let bob_session = issue(&pool, bob).await;
    let app = router(&config, &pool);

    let alice_todo = create_todo(
        app.clone(),
        &alice_session.access_token,
        json!({ "title": "alice 的", "due_kind": "date_only", "due_date": "2026-11-13" }),
    )
    .await;
    let bob_todo = create_todo(
        app.clone(),
        &bob_session.access_token,
        json!({ "title": "bob 的", "due_kind": "date_only", "due_date": "2026-11-13" }),
    )
    .await;

    let data = calendar(
        app.clone(),
        &alice_session.access_token,
        "?from=2026-11-13&to=2026-11-14",
    )
    .await;
    assert_eq!(
        todo_ids(&data),
        vec![alice_todo["id"].as_str().unwrap().to_owned()]
    );
    assert!(
        !data["items"]
            .to_string()
            .contains(bob_todo["id"].as_str().unwrap())
    );

    let data = calendar(
        app,
        &bob_session.access_token,
        "?from=2026-11-13&to=2026-11-14",
    )
    .await;
    assert_eq!(
        todo_ids(&data),
        vec![bob_todo["id"].as_str().unwrap().to_owned()]
    );
}

#[tokio::test]
async fn sources_is_empty_without_registered_adapters() {
    let (config, pool) = setup().await;
    let alice = create_user(&pool, "alice").await;
    let session = issue(&pool, alice).await;
    let app = router(&config, &pool);

    let (status, headers, body) = common::send(
        app,
        get_calendar(
            Some(&session.access_token),
            "?from=2026-11-10&to=2026-11-17",
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["sources"], json!([]));
    assert_eq!(body["data"]["items"], json!([]));
    assert!(headers.contains_key("x-request-id"));
    assert_eq!(
        body["meta"]["request_id"],
        headers["x-request-id"].to_str().unwrap()
    );
}

/// 固定返回几条条目的来源，用来验证 kind 序与来源状态透出。
struct FixedSource;

impl CalendarSource for FixedSource {
    fn source(&self) -> &'static str {
        "jlu_iedu"
    }

    fn items<'a>(
        &'a self,
        _user_id: Uuid,
        _range: &'a CalendarRange,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = SourceResult> + Send + 'a>> {
        Box::pin(async move {
            SourceResult {
                status: SourceState::AuthRequired,
                last_success_at: None,
                items: vec![
                    CalendarItem::Assignment(AssignmentItem {
                        id: "assignment:456".into(),
                        assignment_id: "456".into(),
                        course_offering_id: None,
                        title: "同一时刻的作业".into(),
                        due_at: Some("2026-11-13T00:00:00Z".parse().unwrap()),
                        due_kind: AssignmentDueKind::Exact,
                        timing_text: String::new(),
                        source_status: "pending".into(),
                        read_at: None,
                        muted_at: None,
                    }),
                    CalendarItem::Lesson(LessonItem {
                        id: "lesson:123:2026-11-13T00:00:00Z".into(),
                        lesson_id: "123".into(),
                        course_offering_id: "7f1c2a64-0b7b-4b9c-9f4f-0d1f0c8e6a11".into(),
                        title: "同一时刻的课".into(),
                        starts_at: "2026-11-13T00:00:00Z".parse().unwrap(),
                        ends_at: "2026-11-13T01:40:00Z".parse().unwrap(),
                        location: None,
                        period_start: None,
                        period_end: None,
                    }),
                    CalendarItem::Assignment(AssignmentItem {
                        id: "assignment:789".into(),
                        assignment_id: "789".into(),
                        course_offering_id: None,
                        title: "没有时刻的作业".into(),
                        due_at: None,
                        due_kind: AssignmentDueKind::Relative,
                        timing_text: "3 days left".into(),
                        source_status: "pending".into(),
                        read_at: None,
                        muted_at: None,
                    }),
                ],
            }
        })
    }
}

#[tokio::test]
async fn items_are_sorted_by_time_then_kind() {
    let (config, pool) = setup().await;
    let alice = create_user(&pool, "alice").await;
    let session = issue(&pool, alice).await;
    let token = &session.access_token;
    let app = router_with(&config, &pool, vec![Arc::new(FixedSource)]);

    // 与来源同一时刻的待办：kind 序应把它排在同刻的 lesson / assignment 之后
    let same_instant = create_todo(
        app.clone(),
        token,
        json!({ "title": "同一时刻的待办", "due_kind": "exact", "due_at": "2026-11-13T00:00:00Z" }),
    )
    .await;
    // 更早的时刻，跨来源也排在最前
    let earlier = create_todo(
        app.clone(),
        token,
        json!({ "title": "更早的待办", "due_kind": "date_only", "due_date": "2026-11-12" }),
    )
    .await;

    let data = calendar(app, token, "?from=2026-11-12&to=2026-11-14").await;
    let items = data["items"].as_array().expect("items is an array");
    let order: Vec<&str> = items
        .iter()
        .map(|item| item["id"].as_str().expect("id"))
        .collect();
    assert_eq!(
        order,
        vec![
            format!("todo:{}", earlier["id"].as_str().unwrap()),
            "lesson:123:2026-11-13T00:00:00Z".to_owned(),
            "assignment:456".to_owned(),
            format!("todo:{}", same_instant["id"].as_str().unwrap()),
            "assignment:789".to_owned(),
        ]
    );

    assert_eq!(data["sources"].as_array().expect("sources").len(), 1);
    assert_eq!(data["sources"][0]["source"], "jlu_iedu");
    assert_eq!(data["sources"][0]["status"], "auth_required");
    assert_eq!(data["sources"][0]["last_success_at"], Value::Null);
}
