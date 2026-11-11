#![cfg(feature = "integration")]

mod common;

use axum::{
    Router,
    body::Body,
    http::{Method, Request, StatusCode, header},
};
use jlu_dela_api::{
    auth::session::{self, IssuedSession},
    config::Config,
    db, http,
    state::AppState,
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

fn post_with_key(token: &str, key: Uuid, body: Value) -> Request<Body> {
    builder(Method::POST, "/api/v1/todos", Some(token))
        .header(header::CONTENT_TYPE, "application/json")
        .header("idempotency-key", key.to_string())
        .body(Body::from(body.to_string()))
        .unwrap()
}

fn post_todo(token: Option<&str>, body: Value) -> Request<Body> {
    let token = token.expect("a token is required for todo writes");
    post_with_key(token, Uuid::new_v4(), body)
}

fn patch_todo(token: Option<&str>, id: &str, body: Value) -> Request<Body> {
    builder(Method::PATCH, &format!("/api/v1/todos/{id}"), token)
        .header(header::CONTENT_TYPE, "application/json")
        .body(Body::from(body.to_string()))
        .unwrap()
}

fn delete_todo(token: Option<&str>, id: &str, revision: i32) -> Request<Body> {
    builder(Method::DELETE, &format!("/api/v1/todos/{id}"), token)
        .header(header::IF_MATCH, revision.to_string())
        .body(Body::empty())
        .unwrap()
}

fn get_todos(token: Option<&str>, query: &str) -> Request<Body> {
    builder(Method::GET, &format!("/api/v1/todos{query}"), token)
        .body(Body::empty())
        .unwrap()
}

async fn create_todo(app: Router, token: &str, body: Value) -> Value {
    let (status, _, response) = common::send(app, post_todo(Some(token), body)).await;
    assert_eq!(status, StatusCode::CREATED, "{response}");
    response["data"].clone()
}

#[tokio::test]
async fn todos_require_a_bearer_session() {
    let (config, pool) = setup().await;
    let user = create_user(&pool, "no-token").await;
    let app = router(&config, &pool);

    // 没有 Authorization 头
    let (status, _, body) = common::send(app.clone(), get_todos(None, "")).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "AUTH_REQUIRED");

    // 只给 X-User-Id 也不行：身份只能来自会话
    let forged = builder(Method::GET, "/api/v1/todos", None)
        .header("x-user-id", user.to_string())
        .body(Body::empty())
        .unwrap();
    let (status, _, body) = common::send(app.clone(), forged).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "AUTH_REQUIRED");

    // 令牌无效
    let (status, _, body) = common::send(app, get_todos(Some("not-a-token"), "")).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "INVALID_TOKEN");
}

#[tokio::test]
async fn forged_user_id_header_never_changes_the_owner() {
    let (config, pool) = setup().await;
    let alice = create_user(&pool, "alice").await;
    let bob = create_user(&pool, "bob").await;
    let alice_session = issue(&pool, alice).await;
    let app = router(&config, &pool);

    create_todo(
        app.clone(),
        &alice_session.access_token,
        json!({ "title": "alice 的待办" }),
    )
    .await;

    // alice 的令牌 + bob 的 X-User-Id：结果必须只属于 alice
    let forged = builder(
        Method::GET,
        "/api/v1/todos",
        Some(&alice_session.access_token),
    )
    .header("x-user-id", bob.to_string())
    .body(Body::empty())
    .unwrap();
    let (status, _, body) = common::send(app.clone(), forged).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"].as_array().map(Vec::len), Some(1));

    // bob 自己看不到 alice 的待办
    let bob_session = issue(&pool, bob).await;
    let (status, _, body) = common::send(app, get_todos(Some(&bob_session.access_token), "")).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"].as_array().map(Vec::len), Some(0));
}

#[tokio::test]
async fn cross_user_writes_are_reported_as_not_found() {
    let (config, pool) = setup().await;
    let alice = create_user(&pool, "owner").await;
    let bob = create_user(&pool, "intruder").await;
    let alice_session = issue(&pool, alice).await;
    let bob_session = issue(&pool, bob).await;
    let app = router(&config, &pool);

    let todo = create_todo(
        app.clone(),
        &alice_session.access_token,
        json!({ "title": "只有 alice 能动" }),
    )
    .await;
    let id = todo["id"].as_str().expect("id is a string").to_owned();

    let (status, _, body) = common::send(
        app.clone(),
        patch_todo(
            Some(&bob_session.access_token),
            &id,
            json!({ "revision": 1, "completed": true }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(body["error"]["code"], "NOT_FOUND");

    let (status, _, body) = common::send(
        app.clone(),
        delete_todo(Some(&bob_session.access_token), &id, 1),
    )
    .await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(body["error"]["code"], "NOT_FOUND");

    // 伪造 X-User-Id 也不能越权
    let forged = builder(
        Method::PATCH,
        &format!("/api/v1/todos/{id}"),
        Some(&bob_session.access_token),
    )
    .header(header::CONTENT_TYPE, "application/json")
    .header("x-user-id", alice.to_string())
    .body(Body::from(
        json!({ "revision": 1, "completed": true }).to_string(),
    ))
    .unwrap();
    let (status, _, _) = common::send(app.clone(), forged).await;
    assert_eq!(status, StatusCode::NOT_FOUND);

    // 主人自己的令牌照常工作
    let (status, _, body) = common::send(
        app,
        patch_todo(
            Some(&alice_session.access_token),
            &id,
            json!({ "revision": 1, "completed": true }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["completed"], true);
}

#[tokio::test]
async fn pagination_reaches_todos_without_a_due_date() {
    let (config, pool) = setup().await;
    let user = create_user(&pool, "paging").await;
    let session = issue(&pool, user).await;
    let app = router(&config, &pool);

    create_todo(
        app.clone(),
        &session.access_token,
        json!({ "title": "有截止", "due_kind": "exact", "due_at": "2026-11-20T09:00:00Z" }),
    )
    .await;
    create_todo(
        app.clone(),
        &session.access_token,
        json!({ "title": "无截止" }),
    )
    .await;

    let (status, _, first) = common::send(
        app.clone(),
        get_todos(Some(&session.access_token), "?limit=1"),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(first["data"].as_array().map(Vec::len), Some(1));
    assert_eq!(first["data"][0]["title"], "有截止");
    assert_eq!(first["meta"]["has_more"], true);
    let cursor = first["meta"]["next_cursor"]
        .as_str()
        .expect("cursor is a string")
        .to_owned();

    let (status, _, second) = common::send(
        app.clone(),
        get_todos(
            Some(&session.access_token),
            &format!("?limit=1&cursor={cursor}"),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        second["data"].as_array().map(Vec::len),
        Some(1),
        "无截止的待办不能被分页漏掉: {second}"
    );
    assert_eq!(second["data"][0]["title"], "无截止");
    assert_eq!(second["meta"]["has_more"], false);
}

#[tokio::test]
async fn partial_update_keeps_unspecified_fields_and_clears_colour_explicitly() {
    let (config, pool) = setup().await;
    let user = create_user(&pool, "patcher").await;
    let session = issue(&pool, user).await;
    let app = router(&config, &pool);

    let todo = create_todo(
        app.clone(),
        &session.access_token,
        json!({ "title": "只改完成状态", "notes": "保留这段备注", "color": "teal" }),
    )
    .await;
    let id = todo["id"].as_str().expect("id is a string").to_owned();
    assert_eq!(todo["color"], "teal");

    // ① 只改完成状态：其余字段保持原值
    let (status, _, body) = common::send(
        app.clone(),
        patch_todo(
            Some(&session.access_token),
            &id,
            json!({ "revision": 1, "completed": true }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(body["data"]["completed"], true);
    assert_eq!(body["data"]["title"], "只改完成状态");
    assert_eq!(body["data"]["notes"], "保留这段备注");
    assert_eq!(body["data"]["color"], "teal");
    assert_eq!(body["data"]["revision"], 2);

    // ② 显式 null 恢复默认色
    let (status, _, body) = common::send(
        app.clone(),
        patch_todo(
            Some(&session.access_token),
            &id,
            json!({ "revision": 2, "color": null }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(body["data"]["color"], Value::Null);
    assert_eq!(body["data"]["notes"], "保留这段备注");
    assert_eq!(body["data"]["revision"], 3);

    // ③ 再显式设一个颜色
    let (status, _, body) = common::send(
        app.clone(),
        patch_todo(
            Some(&session.access_token),
            &id,
            json!({ "revision": 3, "color": "rose" }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(body["data"]["color"], "rose");
    assert_eq!(body["data"]["revision"], 4);
}

/// 幂等三件事：同键同请求重放返回原结果、同键异内容 409、并发同键只建一条。
#[tokio::test]
async fn idempotent_creation_replays_and_rejects_a_different_body() {
    let (config, pool) = setup().await;
    let user = create_user(&pool, "idempotent").await;
    let session = issue(&pool, user).await;
    let app = router(&config, &pool);

    let key = Uuid::new_v4();
    let body = json!({ "title": "重放我", "due_date": "2026-11-13" });

    let (status, _, first) = common::send(
        app.clone(),
        post_with_key(&session.access_token, key, body.clone()),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "{first}");
    let first_id = first["data"]["id"].as_str().expect("id").to_owned();
    assert_eq!(first["data"]["due_kind"], "date_only");

    // 同键同请求：返回同一个待办，不新建
    let (status, _, replay) = common::send(
        app.clone(),
        post_with_key(&session.access_token, key, body.clone()),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "{replay}");
    assert_eq!(replay["data"]["id"], first_id.as_str());

    // 同键异内容：409，且不能把第二条写进库
    let (status, _, conflict) = common::send(
        app.clone(),
        post_with_key(&session.access_token, key, json!({ "title": "换个内容" })),
    )
    .await;
    assert_eq!(status, StatusCode::CONFLICT, "{conflict}");
    assert_eq!(conflict["error"]["code"], "IDEMPOTENCY_CONFLICT");

    let (status, _, list) = common::send(app, get_todos(Some(&session.access_token), "")).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        list["data"].as_array().map(Vec::len),
        Some(1),
        "幂等重放与冲突都不能留下多余记录: {list}"
    );
}

/// 同一个键并发提交：唯一约束让后到的等首个事务提交，结果只有一条待办。
#[tokio::test]
async fn concurrent_creation_with_one_key_writes_a_single_todo() {
    let (config, pool) = setup().await;
    let user = create_user(&pool, "racer").await;
    let session = issue(&pool, user).await;
    let app = router(&config, &pool);
    let key = Uuid::new_v4();
    let body = json!({ "title": "只应存在一条" });

    let mut handles = Vec::new();
    for _ in 0..4 {
        let app = app.clone();
        let token = session.access_token.clone();
        let body = body.clone();
        handles.push(tokio::spawn(async move {
            common::send(app, post_with_key(&token, key, body)).await.0
        }));
    }
    for handle in handles {
        let status = handle.await.expect("task completes");
        assert_eq!(status, StatusCode::CREATED, "并发同键都应返回 201");
    }

    let (status, _, list) = common::send(app, get_todos(Some(&session.access_token), "")).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        list["data"].as_array().map(Vec::len),
        Some(1),
        "并发同键只能建一条: {list}"
    );
}

/// 旧 revision 的 PATCH 与 DELETE 都 409，且 `error.current` 带服务器当前版本。
#[tokio::test]
async fn stale_revision_conflicts_carry_the_current_todo() {
    let (config, pool) = setup().await;
    let user = create_user(&pool, "stale").await;
    let session = issue(&pool, user).await;
    let app = router(&config, &pool);

    let todo = create_todo(
        app.clone(),
        &session.access_token,
        json!({ "title": "两次写入" }),
    )
    .await;
    let id = todo["id"].as_str().expect("id").to_owned();

    // 第一次写入把 revision 推到 2
    let (status, _, _) = common::send(
        app.clone(),
        patch_todo(
            Some(&session.access_token),
            &id,
            json!({ "revision": 1, "title": "第一次" }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    // 再用 revision 1 写：409，current 是服务器上的 revision 2
    let (status, _, body) = common::send(
        app.clone(),
        patch_todo(
            Some(&session.access_token),
            &id,
            json!({ "revision": 1, "title": "第二次" }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::CONFLICT, "{body}");
    assert_eq!(body["error"]["code"], "REVISION_CONFLICT");
    assert_eq!(body["error"]["current"]["id"], id.as_str());
    assert_eq!(body["error"]["current"]["title"], "第一次");
    assert_eq!(body["error"]["current"]["revision"], 2);

    // DELETE 用旧 revision 同样 409
    let (status, _, body) = common::send(
        app.clone(),
        delete_todo(Some(&session.access_token), &id, 1),
    )
    .await;
    assert_eq!(status, StatusCode::CONFLICT, "{body}");
    assert_eq!(body["error"]["code"], "REVISION_CONFLICT");
    assert_eq!(body["error"]["current"]["revision"], 2);

    // 正确 revision 删除 204，重删 404
    let (status, _, _) = common::send(
        app.clone(),
        delete_todo(Some(&session.access_token), &id, 2),
    )
    .await;
    assert_eq!(status, StatusCode::NO_CONTENT);

    let (status, _, body) =
        common::send(app, delete_todo(Some(&session.access_token), &id, 2)).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(body["error"]["code"], "NOT_FOUND");
}

/// 截止三态在真库里的往返：创建推断、显式清空、再设回。
#[tokio::test]
async fn due_kind_round_trips_through_creation_and_patch() {
    let (config, pool) = setup().await;
    let user = create_user(&pool, "due").await;
    let session = issue(&pool, user).await;
    let app = router(&config, &pool);

    // 创建只给 due_at → 推断成 exact
    let todo = create_todo(
        app.clone(),
        &session.access_token,
        json!({ "title": "推断", "due_at": "2026-11-13T09:00:00Z" }),
    )
    .await;
    let id = todo["id"].as_str().expect("id").to_owned();
    assert_eq!(todo["due_kind"], "exact");
    assert_eq!(todo["due_at"], "2026-11-13T09:00:00Z");
    assert_eq!(todo["due_date"], Value::Null);

    // 显式 due_kind:none 清空
    let (status, _, body) = common::send(
        app.clone(),
        patch_todo(
            Some(&session.access_token),
            &id,
            json!({ "revision": 1, "due_kind": "none" }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(body["data"]["due_kind"], "none");
    assert_eq!(body["data"]["due_at"], Value::Null);
    assert_eq!(body["data"]["due_date"], Value::Null);

    // 不带 due_kind 只发 due_date（含 null）：422，不能静默忽略
    let (status, _, body) = common::send(
        app.clone(),
        patch_todo(
            Some(&session.access_token),
            &id,
            json!({ "revision": 2, "due_date": "2026-11-20" }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{body}");
    assert_eq!(body["error"]["fields"][0]["path"], "due_date");
    assert_eq!(body["error"]["fields"][0]["code"], "DUE_KIND_MISMATCH");

    let (status, _, body) = common::send(
        app.clone(),
        patch_todo(
            Some(&session.access_token),
            &id,
            json!({ "revision": 2, "due_at": null }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{body}");
    assert_eq!(body["error"]["fields"][0]["path"], "due_at");

    // 改成 date_only
    let (status, _, body) = common::send(
        app.clone(),
        patch_todo(
            Some(&session.access_token),
            &id,
            json!({ "revision": 2, "due_kind": "date_only", "due_date": "2026-11-20" }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(body["data"]["due_kind"], "date_only");
    assert_eq!(body["data"]["due_date"], "2026-11-20");
    assert_eq!(body["data"]["due_at"], Value::Null);
    assert_eq!(body["data"]["revision"], 3);
}

/// 写端点直接收 Bytes，必须自己守 Content-Type。
#[tokio::test]
async fn writes_require_a_json_content_type() {
    let (config, pool) = setup().await;
    let user = create_user(&pool, "media-type").await;
    let session = issue(&pool, user).await;
    let app = router(&config, &pool);

    let no_type = builder(Method::POST, "/api/v1/todos", Some(&session.access_token))
        .header("idempotency-key", Uuid::new_v4().to_string())
        .body(Body::from(json!({ "title": "没有类型" }).to_string()))
        .unwrap();
    let (status, _, body) = common::send(app.clone(), no_type).await;
    assert_eq!(status, StatusCode::UNSUPPORTED_MEDIA_TYPE, "{body}");
    assert_eq!(body["error"]["code"], "UNSUPPORTED_MEDIA_TYPE");

    let wrong_type = builder(Method::POST, "/api/v1/todos", Some(&session.access_token))
        .header(header::CONTENT_TYPE, "text/plain")
        .header("idempotency-key", Uuid::new_v4().to_string())
        .body(Body::from(json!({ "title": "文本" }).to_string()))
        .unwrap();
    let (status, _, body) = common::send(app.clone(), wrong_type).await;
    assert_eq!(status, StatusCode::UNSUPPORTED_MEDIA_TYPE, "{body}");

    // PATCH 同样要守
    let todo = create_todo(
        app.clone(),
        &session.access_token,
        json!({ "title": "先建一个" }),
    )
    .await;
    let id = todo["id"].as_str().expect("id").to_owned();
    let patch_no_type = builder(
        Method::PATCH,
        &format!("/api/v1/todos/{id}"),
        Some(&session.access_token),
    )
    .body(Body::from(json!({ "revision": 1 }).to_string()))
    .unwrap();
    let (status, _, body) = common::send(app, patch_no_type).await;
    assert_eq!(status, StatusCode::UNSUPPORTED_MEDIA_TYPE, "{body}");
}

#[tokio::test]
async fn expired_idempotency_keys_allow_a_new_creation_and_replay_it() {
    let (config, pool) = setup().await;
    let user = create_user(&pool, "expired-key").await;
    let session = issue(&pool, user).await;
    let app = router(&config, &pool);
    for same_body in [true, false] {
        let key = Uuid::new_v4();
        let body = json!({ "title": "Original" });
        let (status, _, first) = common::send(
            app.clone(),
            post_with_key(&session.access_token, key, body.clone()),
        )
        .await;
        assert_eq!(status, StatusCode::CREATED, "{first}");
        sqlx::query(
            "UPDATE idempotency_keys SET created_at = now() - interval '24 hours'
             WHERE user_id = $1 AND endpoint = 'POST /todos' AND key = $2",
        )
        .bind(user)
        .bind(key)
        .execute(&pool)
        .await
        .expect("key is expired");
        let body = if same_body {
            body
        } else {
            json!({ "title": "New request" })
        };
        let mut handles = Vec::new();
        for _ in 0..4 {
            let app = app.clone();
            let token = session.access_token.clone();
            let body = body.clone();
            handles.push(tokio::spawn(async move {
                common::send(app, post_with_key(&token, key, body)).await
            }));
        }
        let mut new_id = None;
        for handle in handles {
            let (status, _, response) = handle.await.expect("request completes");
            assert_eq!(status, StatusCode::CREATED, "{response}");
            let id = response["data"]["id"].clone();
            assert_ne!(id, first["data"]["id"]);
            assert_eq!(response["data"]["title"], body["title"]);
            if let Some(expected) = &new_id {
                assert_eq!(&id, expected);
            } else {
                new_id = Some(id);
            }
        }
        let (status, _, replay) =
            common::send(app.clone(), post_with_key(&session.access_token, key, body)).await;
        assert_eq!(status, StatusCode::CREATED, "{replay}");
        assert_eq!(Some(replay["data"]["id"].clone()), new_id);
    }
    let count: i64 = sqlx::query_scalar("SELECT count(*) FROM todos WHERE user_id = $1")
        .bind(user)
        .fetch_one(&pool)
        .await
        .expect("todos are counted");
    assert_eq!(count, 4);
}
