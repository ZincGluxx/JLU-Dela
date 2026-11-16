#![cfg(feature = "integration")]

mod common;

use std::process::Command;

use axum::{
    Router,
    body::Body,
    extract::State,
    http::{Method, Request, StatusCode, header},
    response::{IntoResponse, Response},
    routing::get as route_get,
};
use jlu_dela_api::{
    auth::{
        AuthenticatedUser,
        management::{self, ManagementScope},
        session::{self, IssuedSession},
    },
    config::Config,
    db, http,
    state::AppState,
};
use serde_json::{Value, json};
use sqlx::PgPool;
use uuid::Uuid;

async fn setup() -> (Config, PgPool, Router) {
    let database_url = std::env::var("DATABASE_URL").expect("integration DATABASE_URL is required");
    let config = common::config(&[("DATABASE_URL", &database_url)]);
    let pool = db::connect(&config).await.expect("test database connects");
    db::run_migrations(&pool).await.expect("migrations apply");
    let state = AppState::new(pool.clone(), config.build_id.clone());
    let probes = Router::new()
        .route("/management-test/campus", route_get(campus))
        .route("/management-test/college-a", route_get(college_a))
        .route("/management-test/college-b", route_get(college_b))
        .with_state(state.clone());
    let app = http::router(state, &config).merge(probes);
    (config, pool, app)
}

async fn check(pool: &PgPool, user: &AuthenticatedUser, scope: ManagementScope) -> Response {
    match management::require_scope(pool, user, &scope).await {
        Ok(()) => StatusCode::NO_CONTENT.into_response(),
        Err(error) => error.response("management-test"),
    }
}

async fn campus(State(state): State<AppState>, user: AuthenticatedUser) -> Response {
    check(&state.pool, &user, ManagementScope::Campus).await
}

async fn college_a(State(state): State<AppState>, user: AuthenticatedUser) -> Response {
    check(
        &state.pool,
        &user,
        ManagementScope::College("college-a".into()),
    )
    .await
}

async fn college_b(State(state): State<AppState>, user: AuthenticatedUser) -> Response {
    check(
        &state.pool,
        &user,
        ManagementScope::College("college-b".into()),
    )
    .await
}

async fn user(pool: &PgPool) -> (Uuid, IssuedSession) {
    let id = Uuid::new_v4();
    sqlx::query(
        "INSERT INTO users (id, login, display_name, timezone, created_at)
         VALUES ($1, $2, 'Synthetic management test', 'Asia/Shanghai', now())",
    )
    .bind(id)
    .bind(format!("management-{id}"))
    .execute(pool)
    .await
    .unwrap();
    (id, session::issue_for_user(pool, id).await.unwrap())
}

fn request(method: Method, uri: &str, token: Option<&str>, body: Option<Value>) -> Request<Body> {
    let mut builder = Request::builder().method(method).uri(uri);
    if let Some(token) = token {
        builder = builder.header(header::AUTHORIZATION, format!("Bearer {token}"));
    }
    let body = match body {
        Some(body) => {
            builder = builder.header(header::CONTENT_TYPE, "application/json");
            Body::from(body.to_string())
        }
        None => Body::empty(),
    };
    builder.body(body).unwrap()
}

async fn get(app: &Router, uri: &str, token: &str) -> (StatusCode, Value) {
    let (status, _, body) =
        common::send(app.clone(), request(Method::GET, uri, Some(token), None)).await;
    (status, body)
}

fn cli(arguments: &[&str]) -> (bool, String, String) {
    let output = Command::new(env!("CARGO_BIN_EXE_management"))
        .args(arguments)
        .env("HTTP_HOST", "127.0.0.1")
        .env("DEV_SMS_FIXED_CODE_ENABLED", "false")
        .output()
        .expect("management CLI runs");
    (
        output.status.success(),
        String::from_utf8(output.stdout).unwrap(),
        String::from_utf8(output.stderr).unwrap(),
    )
}

#[tokio::test]
async fn maintainer_cli_grant_and_revoke_apply_to_the_same_existing_token() {
    let (_, pool, app) = setup().await;
    let (id, issued) = user(&pool).await;
    let id = id.to_string();
    let token = &issued.access_token;
    let uri = "/management-test/campus";
    let (status, body) = get(&app, uri, token).await;
    assert_eq!(status, StatusCode::FORBIDDEN);
    assert_eq!(body["error"]["code"], "MANAGEMENT_REQUIRED");

    for result in ["result: granted", "result: already granted"] {
        let (ok, stdout, stderr) = cli(&["grant", "--user-id", &id, "--campus"]);
        assert!(ok, "{stderr}");
        assert!(stdout.contains(result));
        assert!(stdout.contains(&format!("user_id: {id}")));
        assert!(stdout.contains("scope: campus"));
    }
    assert_eq!(get(&app, uri, token).await.0, StatusCode::NO_CONTENT);
    for result in ["result: revoked", "result: already absent"] {
        let (ok, stdout, stderr) = cli(&["revoke", "--user-id", &id, "--campus"]);
        assert!(ok, "{stderr}");
        assert!(stdout.contains(result));
    }
    let (status, body) = get(&app, uri, token).await;
    assert_eq!(status, StatusCode::FORBIDDEN);
    assert_eq!(body["error"]["code"], "MANAGEMENT_REQUIRED");
}

#[tokio::test]
async fn scopes_and_users_are_isolated_without_assignee_student_affiliation() {
    let (_, pool, app) = setup().await;
    let (manager, issued) = user(&pool).await;
    let (_, other) = user(&pool).await;
    let scope = ManagementScope::College("college-a".into());
    assert!(management::grant(&pool, manager, &scope).await.unwrap());
    let (status, me) = get(&app, "/api/v1/me", &issued.access_token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(me["data"]["student_verified"], false);
    assert_eq!(me["data"]["college"], Value::Null);
    assert!(me["data"].get("management").is_none());
    assert_eq!(
        get(&app, "/management-test/college-a", &issued.access_token)
            .await
            .0,
        StatusCode::NO_CONTENT
    );
    for uri in ["/management-test/campus", "/management-test/college-b"] {
        assert_eq!(
            get(&app, uri, &issued.access_token).await.0,
            StatusCode::FORBIDDEN
        );
    }
    assert_eq!(
        get(&app, "/management-test/college-a", &other.access_token)
            .await
            .0,
        StatusCode::FORBIDDEN
    );
    management::grant(&pool, manager, &ManagementScope::Campus)
        .await
        .unwrap();
    for uri in [
        "/management-test/campus",
        "/management-test/college-a",
        "/management-test/college-b",
    ] {
        assert_eq!(
            get(&app, uri, &issued.access_token).await.0,
            StatusCode::NO_CONTENT
        );
    }
    management::revoke(&pool, manager, &ManagementScope::Campus)
        .await
        .unwrap();
    assert_eq!(
        get(&app, "/management-test/college-a", &issued.access_token)
            .await
            .0,
        StatusCode::NO_CONTENT
    );
    assert_eq!(
        get(&app, "/management-test/college-b", &issued.access_token)
            .await
            .0,
        StatusCode::FORBIDDEN
    );
}

#[tokio::test]
async fn management_endpoint_is_private_self_only_read_only_and_not_self_assignable() {
    let (_, pool, app) = setup().await;
    let (manager, issued) = user(&pool).await;
    let (_, other) = user(&pool).await;
    management::grant(&pool, manager, &ManagementScope::Campus)
        .await
        .unwrap();
    for id in ["college-b", "college-a"] {
        management::grant(&pool, manager, &ManagementScope::College(id.into()))
            .await
            .unwrap();
    }
    let (status, headers, body) = common::send(
        app.clone(),
        request(
            Method::GET,
            "/api/v1/me/management",
            Some(&issued.access_token),
            None,
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(headers[header::CACHE_CONTROL], "private, no-store");
    assert_eq!(
        body["data"],
        json!({"campus": true, "college_ids": ["college-a", "college-b"]})
    );
    let (_, body) = get(
        &app,
        &format!("/api/v1/me/management?user_id={manager}"),
        &other.access_token,
    )
    .await;
    assert_eq!(body["data"], json!({"campus": false, "college_ids": []}));
    for method in [Method::POST, Method::PATCH, Method::DELETE] {
        let (status, _, _) = common::send(
            app.clone(),
            request(
                method,
                "/api/v1/me/management",
                Some(&other.access_token),
                Some(json!({"campus": true})),
            ),
        )
        .await;
        assert_eq!(status, StatusCode::METHOD_NOT_ALLOWED);
    }
    for field in [
        "management",
        "management_grants",
        "campus",
        "college_ids",
        "is_admin",
        "role",
    ] {
        let (status, _, body) = common::send(
            app.clone(),
            request(
                Method::PATCH,
                "/api/v1/me/account",
                Some(&other.access_token),
                Some(json!({field: true})),
            ),
        )
        .await;
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "field {field}");
        assert_eq!(body["error"]["code"], "INVALID_REQUEST_BODY");
    }
    assert_eq!(
        get(&app, "/management-test/campus", &other.access_token)
            .await
            .0,
        StatusCode::FORBIDDEN
    );
    let (ok, stdout, stderr) = cli(&["list", "--user-id", &manager.to_string()]);
    assert!(ok, "{stderr}");
    assert!(stdout.contains("scope: campus"));
    assert!(stdout.contains("scope: college college-a"));
    assert!(stdout.contains("scope: college college-b"));
}

#[tokio::test]
async fn disabled_logout_and_missing_auth_cannot_use_management() {
    let (_, pool, app) = setup().await;
    let (manager, issued) = user(&pool).await;
    management::grant(&pool, manager, &ManagementScope::Campus)
        .await
        .unwrap();
    let snapshot = session::authenticate(&pool, &issued.access_token)
        .await
        .unwrap();
    let user = AuthenticatedUser {
        user_id: snapshot.user_id,
        session_id: snapshot.session_id,
        display_name: snapshot.display_name,
        timezone: snapshot.timezone,
        username: snapshot.username,
        password_set: snapshot.password_set,
        student_verified: snapshot.student_verified,
        college: snapshot.college,
    };
    sqlx::query("UPDATE users SET disabled_at = now() WHERE id = $1")
        .bind(manager)
        .execute(&pool)
        .await
        .unwrap();
    assert!(matches!(
        management::require_scope(&pool, &user, &ManagementScope::Campus).await,
        Err(jlu_dela_api::error::AppError::ManagementRequired)
    ));
    for uri in ["/api/v1/me/management", "/management-test/campus"] {
        let (status, body) = get(&app, uri, &issued.access_token).await;
        assert_eq!(status, StatusCode::UNAUTHORIZED);
        assert_eq!(body["error"]["code"], "INVALID_TOKEN");
    }
    let (ok, _, stderr) = cli(&[
        "grant",
        "--user-id",
        &manager.to_string(),
        "--college",
        "college-a",
    ]);
    assert!(!ok);
    assert!(stderr.contains("disabled user"));
    let (ok, _, stderr) = cli(&["revoke", "--user-id", &manager.to_string(), "--campus"]);
    assert!(ok, "{stderr}");
    sqlx::query("UPDATE users SET disabled_at = NULL WHERE id = $1")
        .bind(manager)
        .execute(&pool)
        .await
        .unwrap();
    management::grant(&pool, manager, &ManagementScope::Campus)
        .await
        .unwrap();
    let (status, _, _) = common::send(
        app.clone(),
        request(
            Method::POST,
            "/api/v1/auth/logout",
            Some(&issued.access_token),
            Some(json!({"refresh_token": issued.refresh_token})),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::NO_CONTENT);
    for uri in ["/api/v1/me/management", "/management-test/campus"] {
        let (status, body) = get(&app, uri, &issued.access_token).await;
        assert_eq!(status, StatusCode::UNAUTHORIZED);
        assert_eq!(body["error"]["code"], "SESSION_REVOKED");
    }
    let (status, headers, body) = common::send(
        app,
        request(Method::GET, "/api/v1/me/management", None, None),
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(headers[header::CACHE_CONTROL], "private, no-store");
    assert_eq!(body["error"]["code"], "AUTH_REQUIRED");
}

#[tokio::test]
async fn cli_requires_an_existing_target_and_lists_empty_grants() {
    let (_, pool, _) = setup().await;
    let absent = Uuid::new_v4().to_string();
    for command in ["grant", "revoke", "list"] {
        let mut arguments = vec![command, "--user-id", &absent];
        if command != "list" {
            arguments.push("--campus");
        }
        let (ok, _, stderr) = cli(&arguments);
        assert!(!ok);
        assert!(stderr.contains("target user does not exist"));
    }
    let (id, _) = user(&pool).await;
    let (ok, stdout, stderr) = cli(&["list", "--user-id", &id.to_string()]);
    assert!(ok, "{stderr}");
    assert!(stdout.contains("grants: none"));
    for expected in ["result: granted", "result: already granted"] {
        let (ok, stdout, stderr) = cli(&[
            "grant",
            "--user-id",
            &id.to_string(),
            "--college",
            "college-a",
        ]);
        assert!(ok, "{stderr}");
        assert!(stdout.contains(expected));
        assert!(stdout.contains("scope: college college-a"));
    }
    for expected in ["result: revoked", "result: already absent"] {
        let (ok, stdout, stderr) = cli(&[
            "revoke",
            "--user-id",
            &id.to_string(),
            "--college",
            "college-a",
        ]);
        assert!(ok, "{stderr}");
        assert!(stdout.contains(expected));
    }
}
