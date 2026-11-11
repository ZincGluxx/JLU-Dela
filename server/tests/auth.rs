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

fn get(uri: &str, token: Option<&str>) -> Request<Body> {
    let mut builder = Request::builder().method(Method::GET).uri(uri);
    if let Some(token) = token {
        builder = builder.header(header::AUTHORIZATION, format!("Bearer {token}"));
    }
    builder.body(Body::empty()).unwrap()
}

fn post_json(uri: &str, token: Option<&str>, body: Value) -> Request<Body> {
    let mut builder = Request::builder()
        .method(Method::POST)
        .uri(uri)
        .header(header::CONTENT_TYPE, "application/json");
    if let Some(token) = token {
        builder = builder.header(header::AUTHORIZATION, format!("Bearer {token}"));
    }
    builder.body(Body::from(body.to_string())).unwrap()
}

fn refresh_body(token: &str) -> Value {
    json!({ "refresh_token": token })
}

#[tokio::test]
async fn two_users_receive_only_their_own_identity() {
    let (config, pool) = setup().await;
    let alice = create_user(&pool, "alice").await;
    let bob = create_user(&pool, "bob").await;
    let alice_session = issue(&pool, alice).await;
    let bob_session = issue(&pool, bob).await;
    let app = router(&config, &pool);

    let (status, _, body) = common::send(
        app.clone(),
        get("/api/v1/me", Some(&alice_session.access_token)),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["id"], alice.to_string());
    assert_eq!(body["data"]["display_name"], "alice");
    assert_eq!(body["data"]["timezone"], "Asia/Shanghai");

    let (status, _, body) =
        common::send(app, get("/api/v1/me", Some(&bob_session.access_token))).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["id"], bob.to_string());
    assert_eq!(body["data"]["display_name"], "bob");
    assert_ne!(body["data"]["id"], alice.to_string());
    assert!(!body.to_string().contains("access_token"));
}

#[tokio::test]
async fn expired_access_token_reports_token_expired_and_refresh_recovers() {
    let (config, pool) = setup().await;
    let user = create_user(&pool, "expired-access").await;
    let issued = issue(&pool, user).await;
    sqlx::query(
        "UPDATE sessions SET access_expires_at = now() - interval '1 second' WHERE id = $1",
    )
    .bind(issued.session_id)
    .execute(&pool)
    .await
    .expect("access expiry is moved into the past");
    let app = router(&config, &pool);

    let (status, headers, body) =
        common::send(app.clone(), get("/api/v1/me", Some(&issued.access_token))).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "TOKEN_EXPIRED");
    assert_eq!(headers.get(header::WWW_AUTHENTICATE).unwrap(), "Bearer");
    assert_eq!(
        body["error"]["request_id"].as_str(),
        headers
            .get("x-request-id")
            .and_then(|value| value.to_str().ok())
    );

    let (status, _, body) = common::send(
        app.clone(),
        post_json(
            "/api/v1/auth/refresh",
            None,
            refresh_body(&issued.refresh_token),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let access = body["data"]["access_token"].as_str().unwrap();

    let (status, _, body) = common::send(app, get("/api/v1/me", Some(access))).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["id"], user.to_string());
}

#[tokio::test]
async fn refresh_rotates_both_tokens_and_rejects_reuse() {
    let (config, pool) = setup().await;
    let user = create_user(&pool, "rotation").await;
    let issued = issue(&pool, user).await;
    let app = router(&config, &pool);

    let (status, _, body) = common::send(
        app.clone(),
        post_json(
            "/api/v1/auth/refresh",
            None,
            refresh_body(&issued.refresh_token),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["token_type"], "Bearer");
    assert_eq!(body["data"]["expires_in"], 900);
    let next_access = body["data"]["access_token"].as_str().unwrap().to_owned();
    let next_refresh = body["data"]["refresh_token"].as_str().unwrap().to_owned();
    assert_ne!(next_access, issued.access_token);
    assert_ne!(next_refresh, issued.refresh_token);

    let (status, _, body) =
        common::send(app.clone(), get("/api/v1/me", Some(&issued.access_token))).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "INVALID_TOKEN");

    let (status, _, body) = common::send(
        app.clone(),
        post_json(
            "/api/v1/auth/refresh",
            None,
            refresh_body(&issued.refresh_token),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "INVALID_TOKEN");

    let (status, _, body) = common::send(app, get("/api/v1/me", Some(&next_access))).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["id"], user.to_string());
}

#[tokio::test]
async fn logout_revokes_the_session_for_both_token_types() {
    let (config, pool) = setup().await;
    let user = create_user(&pool, "logout").await;
    let issued = issue(&pool, user).await;
    let app = router(&config, &pool);

    let (status, _, _) = common::send(
        app.clone(),
        post_json(
            "/api/v1/auth/logout",
            Some(&issued.access_token),
            refresh_body(&issued.refresh_token),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::NO_CONTENT);

    let (status, _, body) =
        common::send(app.clone(), get("/api/v1/me", Some(&issued.access_token))).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "SESSION_REVOKED");

    let (status, _, body) = common::send(
        app,
        post_json(
            "/api/v1/auth/refresh",
            None,
            refresh_body(&issued.refresh_token),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "INVALID_TOKEN");
}

#[tokio::test]
async fn logout_requires_the_refresh_token_of_the_current_session() {
    let (config, pool) = setup().await;
    let user = create_user(&pool, "logout-match").await;
    let current = issue(&pool, user).await;
    let other = issue(&pool, user).await;
    let app = router(&config, &pool);

    let (status, _, body) = common::send(
        app.clone(),
        post_json(
            "/api/v1/auth/logout",
            Some(&current.access_token),
            refresh_body(&other.refresh_token),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "INVALID_TOKEN");

    let (status, _, _) = common::send(app, get("/api/v1/me", Some(&current.access_token))).await;
    assert_eq!(status, StatusCode::OK);
}

#[tokio::test]
async fn missing_malformed_and_unknown_tokens_are_rejected() {
    let (config, pool) = setup().await;
    let app = router(&config, &pool);

    let (status, _, body) = common::send(app.clone(), get("/api/v1/me", None)).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "AUTH_REQUIRED");

    let (status, _, body) = common::send(app.clone(), get("/api/v1/me", Some("not-a-token"))).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "INVALID_TOKEN");

    let (status, _, body) = common::send(
        app,
        post_json("/api/v1/auth/refresh", None, refresh_body("rt_unknown")),
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "INVALID_TOKEN");
}

#[tokio::test]
async fn refresh_rejects_unknown_fields_empty_tokens_and_wrong_content_type() {
    let (config, pool) = setup().await;
    let app = router(&config, &pool);

    let (status, _, body) = common::send(
        app.clone(),
        post_json(
            "/api/v1/auth/refresh",
            None,
            json!({ "refresh_token": "rt_x", "extra": true }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(body["error"]["code"], "INVALID_REQUEST_BODY");

    let (status, _, body) = common::send(
        app.clone(),
        post_json("/api/v1/auth/refresh", None, refresh_body("")),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(body["error"]["code"], "VALIDATION_FAILED");
    assert_eq!(body["error"]["fields"][0]["path"], "refresh_token");
    assert_eq!(body["error"]["fields"][0]["code"], "required");

    let request = Request::builder()
        .method(Method::POST)
        .uri("/api/v1/auth/refresh")
        .body(Body::from(r#"{"refresh_token":"rt_x"}"#))
        .unwrap();
    let (status, _, body) = common::send(app, request).await;
    assert_eq!(status, StatusCode::UNSUPPORTED_MEDIA_TYPE);
    assert_eq!(body["error"]["code"], "UNSUPPORTED_MEDIA_TYPE");
}

#[tokio::test]
async fn expired_refresh_token_is_rejected_and_revokes_the_session() {
    let (config, pool) = setup().await;
    let user = create_user(&pool, "expired-refresh").await;
    let issued = issue(&pool, user).await;
    sqlx::query(
        "UPDATE sessions SET refresh_expires_at = now() - interval '1 second' WHERE id = $1",
    )
    .bind(issued.session_id)
    .execute(&pool)
    .await
    .expect("refresh expiry is moved into the past");
    let app = router(&config, &pool);

    let (status, _, body) = common::send(
        app,
        post_json(
            "/api/v1/auth/refresh",
            None,
            refresh_body(&issued.refresh_token),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "TOKEN_EXPIRED");

    let revoked: Option<String> =
        sqlx::query_scalar("SELECT revoked_reason FROM sessions WHERE id = $1")
            .bind(issued.session_id)
            .fetch_one(&pool)
            .await
            .expect("session row is readable");
    assert_eq!(revoked.as_deref(), Some("refresh_expired"));
}
