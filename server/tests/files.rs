#![cfg(feature = "integration")]

mod common;

use axum::{
    Router,
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use jlu_dela_api::{
    auth::session,
    config::Config,
    error::AppError,
    files::{self, FileUse},
    http,
    state::AppState,
};
use serde_json::Value;
use sqlx::{PgPool, postgres::PgPoolOptions};
use tempfile::TempDir;
use tower::ServiceExt;
use uuid::Uuid;

async fn user(pool: &PgPool) -> (Uuid, String) {
    let id = Uuid::new_v4();
    sqlx::query("INSERT INTO users(id,login,display_name,timezone,created_at) VALUES($1,$2,'files test','Asia/Shanghai',now())")
        .bind(id).bind(id.to_string()).execute(pool).await.unwrap();
    let session = session::issue_for_user(pool, id).await.unwrap();
    (id, session.access_token)
}

fn setup(pool: &PgPool, dir: &TempDir, max: usize) -> (Config, AppState, Router) {
    let config = common::config(&[
        (
            "FILE_STORAGE_DIR",
            dir.path().join("files").to_str().unwrap(),
        ),
        ("FILE_MAX_BYTES", &max.to_string()),
    ]);
    let state = AppState::from_config(pool.clone(), &config);
    let app = http::router(state.clone(), &config);
    (config, state, app)
}

fn upload(token: &str, name: &str, bytes: &[u8], extra: &str) -> Request<Body> {
    let mut body = format!("--files-test\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{name}\"\r\nContent-Type: text/html; charset=utf-8\r\n\r\n").into_bytes();
    body.extend_from_slice(bytes);
    body.extend_from_slice(format!("\r\n{extra}--files-test--\r\n").as_bytes());
    Request::builder()
        .method("POST")
        .uri("/api/v1/files")
        .header("authorization", format!("Bearer {token}"))
        .header("content-type", "multipart/form-data; boundary=files-test")
        .body(Body::from(body))
        .unwrap()
}

fn request(method: &str, id: Uuid, token: &str, content: bool) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(format!(
            "/api/v1/files/{id}{}",
            if content { "/content" } else { "" }
        ))
        .header("authorization", format!("Bearer {token}"))
        .body(Body::empty())
        .unwrap()
}

async fn saved(app: Router, token: &str, name: &str, bytes: &[u8]) -> (Uuid, Value) {
    let (status, _, body) = common::send(app, upload(token, name, bytes, "")).await;
    assert_eq!(status, StatusCode::CREATED, "{body}");
    (
        Uuid::parse_str(body["data"]["id"].as_str().unwrap()).unwrap(),
        body,
    )
}

#[sqlx::test(migrations = "./migrations")]
async fn authenticated_upload_privacy_download_and_reconnection(pool: PgPool) {
    let dir = TempDir::new().unwrap();
    let (config, state, app) = setup(&pool, &dir, 10000);
    assert!(!state.files.dir.exists());
    let (owner, token) = user(&pool).await;
    let (_, other) = user(&pool).await;
    let (status, _, body) = common::send(app.clone(), upload("", "x", b"x", "")).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "AUTH_REQUIRED");
    let bytes = vec![b'x'; 5000];
    let (id, body) = saved(app.clone(), &token, "../../outside.html", &bytes).await;
    assert_eq!(body["data"]["uploader_id"], owner.to_string());
    assert_eq!(body["data"]["original_name"], "../../outside.html");
    assert_eq!(body["data"]["size_bytes"], 5000);
    assert_eq!(body["data"].as_object().unwrap().len(), 6);
    assert!(body["data"]["created_at"].as_str().unwrap().ends_with('Z'));
    assert_eq!(std::fs::read_dir(&state.files.dir).unwrap().count(), 1);
    assert!(state.files.dir.join(id.to_string()).is_file());
    for content in [false, true] {
        let (status, _, body) =
            common::send(app.clone(), request("GET", id, &other, content)).await;
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert_eq!(body["error"]["code"], "FILE_NOT_FOUND");
        let (status, _, _) = common::send(app.clone(), request("GET", id, "", content)).await;
        assert_eq!(status, StatusCode::UNAUTHORIZED);
    }
    let (status, _, _) = common::send(app.clone(), request("DELETE", id, &other, false)).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    let (status, _, body) = common::send(app.clone(), request("GET", id, &token, false)).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["id"], id.to_string());
    let options = pool.connect_options();
    drop(app);
    drop(state);
    pool.close().await;
    let reconnected = PgPoolOptions::new()
        .connect_with((*options).clone())
        .await
        .unwrap();
    let state = AppState::from_config(reconnected.clone(), &config);
    let app = http::router(state, &config);
    let response = app
        .clone()
        .oneshot(request("GET", id, &token, true))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
    assert_eq!(
        response.headers()["content-type"],
        "application/octet-stream"
    );
    assert_eq!(response.headers()["x-content-type-options"], "nosniff");
    assert_eq!(response.headers()["cache-control"], "private, no-store");
    assert!(
        response.headers()["content-disposition"]
            .to_str()
            .unwrap()
            .starts_with("attachment;")
    );
    assert_eq!(to_bytes(response.into_body(), 10000).await.unwrap(), bytes);
    let (status, _, _) = common::send(app.clone(), request("DELETE", id, &token, false)).await;
    assert_eq!(status, StatusCode::NO_CONTENT);
    let (status, _, _) = common::send(app, request("GET", id, &token, true)).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    reconnected.close().await;
}

#[sqlx::test(migrations = "./migrations")]
async fn business_attachment_authorization_and_transaction_rollback(pool: PgPool) {
    let dir = TempDir::new().unwrap();
    let (_, state, app) = setup(&pool, &dir, 1000);
    let (owner, token) = user(&pool).await;
    let (other, other_token) = user(&pool).await;
    let (id, _) = saved(app.clone(), &token, "image.png", b"image").await;
    let business = Uuid::new_v4();
    let mut tx = pool.begin().await.unwrap();
    assert!(matches!(
        files::attach(&mut tx, id, other, FileUse::Material, business).await,
        Err(AppError::FileNotFound)
    ));
    files::attach(&mut tx, id, owner, FileUse::Material, business)
        .await
        .unwrap();
    tx.rollback().await.unwrap();
    let (status, _, _) = common::send(app.clone(), request("GET", id, &token, true)).await;
    assert_eq!(status, StatusCode::OK);
    let mut tx = pool.begin().await.unwrap();
    files::attach(&mut tx, id, owner, FileUse::CommunityImage, business)
        .await
        .unwrap();
    tx.commit().await.unwrap();
    for token in [&token, &other_token] {
        for content in [false, true] {
            let (status, _, _) =
                common::send(app.clone(), request("GET", id, token, content)).await;
            assert_eq!(status, StatusCode::NOT_FOUND);
        }
    }
    let (status, _, body) = common::send(app.clone(), request("DELETE", id, &token, false)).await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert_eq!(body["error"]["code"], "FILE_IN_USE");
    let (status, _, _) =
        common::send(app.clone(), request("DELETE", id, &other_token, false)).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    sqlx::query("INSERT INTO student_reports(user_id,school,source,verified_at,college_name,college_source_field) VALUES($1,'吉林大学','chsi',now(),'文件测试学院','测试字段')")
        .bind(owner).execute(&pool).await.unwrap();
    let college = jlu_dela_api::auth::student::load_identity(&pool, owner)
        .await
        .unwrap()
        .college
        .unwrap()
        .id;
    use axum::extract::FromRequestParts;
    use jlu_dela_api::auth::AuthenticatedUser;
    let (mut parts, _) = request("GET", id, &token, true).into_parts();
    let authorized = AuthenticatedUser::from_request_parts(&mut parts, &state)
        .await
        .unwrap_or_else(|_| panic!("owner authenticates"));
    let (mut parts, _) = request("GET", id, &other_token, true).into_parts();
    let denied = AuthenticatedUser::from_request_parts(&mut parts, &state)
        .await
        .unwrap_or_else(|_| panic!("other authenticates"));
    assert!(matches!(
        files::read_for_business(&state, id, FileUse::CommunityImage, business, || async {
            denied.require_college(&college)
        })
        .await,
        Err(AppError::StudentRequired)
    ));
    let read = files::read_for_business(&state, id, FileUse::CommunityImage, business, || async {
        authorized.require_college(&college)
    })
    .await
    .unwrap();
    assert_eq!(read.bytes, b"image");
    let called = std::sync::atomic::AtomicBool::new(false);
    let result = files::read_for_business(&state, id, FileUse::Material, business, || async {
        called.store(true, std::sync::atomic::Ordering::SeqCst);
        Ok(())
    })
    .await;
    assert!(matches!(result, Err(AppError::FileNotFound)));
    assert!(!called.load(std::sync::atomic::Ordering::SeqCst));
    let mut tx = pool.begin().await.unwrap();
    assert!(matches!(
        files::attach(&mut tx, id, owner, FileUse::Material, business).await,
        Err(AppError::FileInUse)
    ));
    assert!(matches!(
        files::detach(&mut tx, id, FileUse::CommunityImage, Uuid::new_v4()).await,
        Err(AppError::FileNotFound)
    ));
    files::detach(&mut tx, id, FileUse::CommunityImage, business)
        .await
        .unwrap();
    tx.commit().await.unwrap();
    let (status, _, _) = common::send(app.clone(), request("GET", id, &token, true)).await;
    assert_eq!(status, StatusCode::OK);
    let (status, _, _) = common::send(app, request("DELETE", id, &token, false)).await;
    assert_eq!(status, StatusCode::NO_CONTENT);
}

#[sqlx::test(migrations = "./migrations")]
async fn limits_validation_and_storage_failures_leave_no_success(pool: PgPool) {
    let dir = TempDir::new().unwrap();
    let (_, state, app) = setup(&pool, &dir, 10);
    let (_, token) = user(&pool).await;
    for (name, bytes, extra, status) in [
        ("x", vec![], "", StatusCode::UNPROCESSABLE_ENTITY),
        ("x", vec![b'x'; 11], "", StatusCode::PAYLOAD_TOO_LARGE),
        ("x", vec![b'x'; 70000], "", StatusCode::PAYLOAD_TOO_LARGE),
        (
            "x",
            vec![b'x'],
            "--files-test\r\nContent-Disposition: form-data; name=\"other\"\r\n\r\ny\r\n",
            StatusCode::UNPROCESSABLE_ENTITY,
        ),
    ] {
        let (actual, _, _) = common::send(app.clone(), upload(&token, name, &bytes, extra)).await;
        assert_eq!(actual, status);
    }
    let long = "a".repeat(256);
    let (status, _, body) = common::send(app.clone(), upload(&token, &long, b"x", "")).await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(body["error"]["code"], "VALIDATION_FAILED");
    let json_request = Request::builder()
        .method("POST")
        .uri("/api/v1/auth/login")
        .header("content-type", "application/json")
        .body(Body::from("x".repeat(5000)))
        .unwrap();
    let (status, _, body) = common::send(app.clone(), json_request).await;
    assert_eq!(status, StatusCode::PAYLOAD_TOO_LARGE);
    assert_eq!(body["error"]["code"], "PAYLOAD_TOO_LARGE");
    let (status, _, _) =
        common::send(app.clone(), upload(&token, "bad\u{0001}name", b"x", "")).await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert!(!state.files.dir.exists());
    std::fs::write(&state.files.dir, b"blocking directory creation").unwrap();
    let (status, _, body) = common::send(app.clone(), upload(&token, "x", b"x", "")).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(body["error"]["code"], "FILE_STORAGE_UNAVAILABLE");
    std::fs::remove_file(&state.files.dir).unwrap();
    sqlx::query("ALTER TABLE files ADD CONSTRAINT reject_upload CHECK (size_bytes < 0)")
        .execute(&pool)
        .await
        .unwrap();
    let (status, _, body) = common::send(app.clone(), upload(&token, "x", b"x", "")).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(body["error"]["code"], "DATABASE_UNAVAILABLE");
    assert_eq!(std::fs::read_dir(&state.files.dir).unwrap().count(), 0);
    sqlx::query("ALTER TABLE files DROP CONSTRAINT reject_upload")
        .execute(&pool)
        .await
        .unwrap();
    let (id, _) = saved(app.clone(), &token, "x", b"x").await;
    std::fs::remove_file(state.files.dir.join(id.to_string())).unwrap();
    let (status, _, body) = common::send(app.clone(), request("GET", id, &token, true)).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(body["error"]["code"], "FILE_NOT_FOUND");
    std::fs::create_dir(state.files.dir.join(id.to_string())).unwrap();
    let (status, _, _) = common::send(app.clone(), request("DELETE", id, &token, false)).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    let (status, _, _) = common::send(app.clone(), request("GET", id, &token, true)).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    std::fs::remove_dir(state.files.dir.join(id.to_string())).unwrap();
    let (status, _, _) = common::send(app, request("DELETE", id, &token, false)).await;
    assert_eq!(status, StatusCode::NO_CONTENT);
}
