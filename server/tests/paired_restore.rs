#![cfg(feature = "integration")]

mod common;

use std::{
    collections::BTreeMap,
    ffi::OsString,
    path::Path,
    process::Command,
    sync::atomic::{AtomicBool, Ordering},
};

use axum::{
    Router,
    body::{Body, to_bytes},
    extract::FromRequestParts,
    http::{Request, StatusCode},
};
use jlu_dela_api::{
    auth::{AuthenticatedUser, password, session, student},
    error::AppError,
    files::{self, FileUse},
    http,
    state::AppState,
};
use serde_json::{Value, json};
use sqlx::{
    PgPool,
    postgres::{PgConnectOptions, PgPoolOptions, PgSslMode},
};
use tempfile::TempDir;
use tower::ServiceExt;
use uuid::Uuid;

const PASSWORD: &str = "RestoreTest123";
const BUILD_ID: &str = "paired-restore-integration";

struct Account {
    id: Uuid,
    login: String,
    token: String,
    identity: Value,
}

struct FileFixture {
    id: Uuid,
    metadata: Value,
    bytes: Vec<u8>,
    attachment: Option<(FileUse, Uuid)>,
}

fn request(method: &str, uri: &str, token: &str) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(uri)
        .header("authorization", format!("Bearer {token}"))
        .body(Body::empty())
        .unwrap()
}

async fn assert_behavior(
    state: &AppState,
    app: Router,
    accounts: &[Account],
    files: &[FileFixture],
) {
    for account in accounts {
        let (status, _, body) =
            common::send(app.clone(), request("GET", "/api/v1/me", &account.token)).await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body["data"], account.identity);
    }
    for file in files {
        let uri = format!("/api/v1/files/{}", file.id);
        let linkage: (Option<String>, Option<Uuid>, bool) =
            sqlx::query_as("SELECT use_kind,business_id,deleting FROM files WHERE id=$1")
                .bind(file.id)
                .fetch_one(&state.pool)
                .await
                .unwrap();
        let expected_linkage = match file.attachment {
            Some((FileUse::Material, id)) => (Some("material".to_owned()), Some(id), false),
            Some((FileUse::CommunityImage, id)) => {
                (Some("community_image".to_owned()), Some(id), false)
            }
            None => (None, None, false),
        };
        assert_eq!(linkage, expected_linkage);
        for (index, account) in accounts.iter().enumerate() {
            for content in [false, true] {
                let path = format!("{uri}{}", if content { "/content" } else { "" });
                let response = app
                    .clone()
                    .oneshot(request("GET", &path, &account.token))
                    .await
                    .unwrap();
                let allowed = index == 0 && file.attachment.is_none();
                assert_eq!(
                    response.status(),
                    if allowed {
                        StatusCode::OK
                    } else {
                        StatusCode::NOT_FOUND
                    }
                );
                if allowed && content {
                    assert_eq!(
                        response.headers()["content-type"],
                        "application/octet-stream"
                    );
                    assert_eq!(response.headers()["cache-control"], "private, no-store");
                    assert_eq!(response.headers()["x-content-type-options"], "nosniff");
                }
                let bytes = to_bytes(response.into_body(), 64 * 1024).await.unwrap();
                if allowed && content {
                    assert_eq!(bytes.as_ref(), file.bytes);
                } else {
                    let body: Value = serde_json::from_slice(&bytes).unwrap();
                    if allowed {
                        assert_eq!(body["data"], file.metadata);
                    } else {
                        assert_eq!(body["error"]["code"], "FILE_NOT_FOUND");
                    }
                }
            }
        }
        if let Some((use_kind, business_id)) = file.attachment {
            let college: String =
                sqlx::query_scalar("SELECT college_id FROM paired_restore_businesses WHERE id=$1")
                    .bind(business_id)
                    .fetch_one(&state.pool)
                    .await
                    .unwrap();
            for (index, account) in accounts.iter().enumerate() {
                let (mut parts, _) = request("GET", &uri, &account.token).into_parts();
                let user = AuthenticatedUser::from_request_parts(&mut parts, state)
                    .await
                    .unwrap_or_else(|_| panic!("fixture account authenticates"));
                let result =
                    files::read_for_business(state, file.id, use_kind, business_id, || async {
                        user.require_college(&college)
                    })
                    .await;
                if index == 2 {
                    assert!(matches!(result, Err(AppError::CollegeRequired)));
                } else {
                    let content = result.unwrap();
                    assert_eq!(content.bytes, file.bytes);
                    assert_eq!(
                        serde_json::to_value(content.metadata).unwrap(),
                        file.metadata
                    );
                }
            }
            let wrong_use = match use_kind {
                FileUse::Material => FileUse::CommunityImage,
                FileUse::CommunityImage => FileUse::Material,
            };
            for (kind, business) in [(wrong_use, business_id), (use_kind, Uuid::new_v4())] {
                let called = AtomicBool::new(false);
                let result = files::read_for_business(state, file.id, kind, business, || async {
                    called.store(true, Ordering::SeqCst);
                    Ok(())
                })
                .await;
                assert!(matches!(result, Err(AppError::FileNotFound)));
                assert!(!called.load(Ordering::SeqCst));
            }
            let (status, _, body) =
                common::send(app.clone(), request("DELETE", &uri, &accounts[0].token)).await;
            assert_eq!(status, StatusCode::CONFLICT);
            assert_eq!(body["error"]["code"], "FILE_IN_USE");
        }
    }
}

async fn database_snapshot(pool: &PgPool) -> Value {
    sqlx::query_scalar(
        "SELECT jsonb_build_object(
            'users', (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM users t),
            'sessions', (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM sessions t),
            'student_reports', (SELECT jsonb_agg(to_jsonb(t) ORDER BY user_id) FROM student_reports t),
            'files', (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM files t),
            'businesses', (SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM paired_restore_businesses t),
            'schema', (SELECT jsonb_agg(to_jsonb(t) ORDER BY key) FROM service_meta t),
            'migrations', (SELECT jsonb_agg(to_jsonb(t) ORDER BY version) FROM _sqlx_migrations t)
        )",
    )
    .fetch_one(pool)
    .await
    .unwrap()
}

fn directory_snapshot(dir: &Path) -> BTreeMap<OsString, Vec<u8>> {
    std::fs::read_dir(dir)
        .unwrap()
        .map(|entry| {
            let entry = entry.unwrap();
            assert!(entry.file_type().unwrap().is_file());
            (entry.file_name(), std::fs::read(entry.path()).unwrap())
        })
        .collect()
}

fn shell_path(path: &Path) -> String {
    path.to_str().unwrap().replace('\\', "/")
}

fn run_bash(args: &[String], options: &PgConnectOptions) {
    let output = Command::new(std::env::var("BASH").unwrap_or_else(|_| "bash".to_owned()))
        .args(args)
        .env_remove("DATABASE_URL")
        .env("PGHOST", options.get_host())
        .env("PGPORT", options.get_port().to_string())
        .env("PGUSER", options.get_username())
        .env("PGDATABASE", options.get_database().unwrap())
        .env(
            "PGSSLMODE",
            match options.get_ssl_mode() {
                PgSslMode::Disable => "disable",
                PgSslMode::Allow => "allow",
                PgSslMode::Prefer => "prefer",
                PgSslMode::Require => "require",
                PgSslMode::VerifyCa => "verify-ca",
                PgSslMode::VerifyFull => "verify-full",
            },
        )
        .output()
        .expect("bash and PostgreSQL executables must be available on PATH");
    assert!(
        output.status.success(),
        "paired restore command failed ({}):\n{}\n{}",
        output.status,
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
}

#[sqlx::test(migrations = "./migrations")]
#[ignore = "requires native PostgreSQL client tools and Bash; run explicitly in an isolated cluster"]
async fn paired_backup_restores_accounts_files_and_business_authorization(pool: PgPool) {
    let dir = TempDir::new().unwrap();
    let source_files = dir.path().join("source-files");
    let restored_files = dir.path().join("restored-files");
    let bundle = dir.path().join("bundle");
    let config = common::config(&[
        ("FILE_STORAGE_DIR", source_files.to_str().unwrap()),
        ("FILE_MAX_BYTES", "65536"),
        ("APP_BUILD_ID", BUILD_ID),
    ]);
    let state = AppState::from_config(pool.clone(), &config);
    let app = http::router(state.clone(), &config);
    let hash = password::hash(PASSWORD).unwrap();
    let mut accounts = Vec::new();
    for (name, college_name) in [
        ("恢复测试上传者", "恢复测试学院"),
        ("恢复测试同院读者", "恢复测试学院"),
        ("恢复测试异院读者", "恢复测试其他学院"),
    ] {
        let id = Uuid::new_v4();
        let login = format!("restore-{}", id.simple());
        sqlx::query("INSERT INTO users(id,login,display_name,timezone,password_hash,created_at) VALUES($1,$2,$3,'Asia/Shanghai',$4,now())")
            .bind(id).bind(&login).bind(name).bind(&hash).execute(&pool).await.unwrap();
        sqlx::query("INSERT INTO student_reports(user_id,school,source,verified_at,college_name,college_source_field) VALUES($1,'吉林大学','chsi',now(),$2,'测试分院')")
            .bind(id).bind(college_name).execute(&pool).await.unwrap();
        let token = session::issue_for_user(&pool, id)
            .await
            .unwrap()
            .access_token;
        let college = student::load_identity(&pool, id)
            .await
            .unwrap()
            .college
            .unwrap();
        accounts.push(Account {
            id,
            login: login.clone(),
            token,
            identity: json!({
                "id": id,
                "display_name": name,
                "timezone": "Asia/Shanghai",
                "username": login,
                "password_set": true,
                "student_verified": true,
                "college": college,
            }),
        });
    }
    sqlx::query("CREATE TABLE paired_restore_businesses (id UUID PRIMARY KEY, college_id TEXT NOT NULL, title TEXT NOT NULL)")
        .execute(&pool).await.unwrap();
    let mut fixtures = Vec::new();
    for (name, media_type, bytes, use_kind) in [
        (
            "private-notes.txt",
            "text/plain",
            b"synthetic private notes\n".as_slice(),
            None,
        ),
        (
            "material.pdf",
            "application/pdf",
            b"%PDF-1.7\nsynthetic material\n".as_slice(),
            Some(FileUse::Material),
        ),
        (
            "community.png",
            "image/png",
            b"\x89PNG\r\n\x1a\nsynthetic community image".as_slice(),
            Some(FileUse::CommunityImage),
        ),
    ] {
        let mut body = format!("--paired-restore\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{name}\"\r\nContent-Type: {media_type}\r\n\r\n").into_bytes();
        body.extend_from_slice(bytes);
        body.extend_from_slice(b"\r\n--paired-restore--\r\n");
        let upload = Request::builder()
            .method("POST")
            .uri("/api/v1/files")
            .header("authorization", format!("Bearer {}", accounts[0].token))
            .header(
                "content-type",
                "multipart/form-data; boundary=paired-restore",
            )
            .body(Body::from(body))
            .unwrap();
        let (status, _, body) = common::send(app.clone(), upload).await;
        assert_eq!(status, StatusCode::CREATED);
        let metadata = body["data"].clone();
        let id = Uuid::parse_str(metadata["id"].as_str().unwrap()).unwrap();
        assert_eq!(metadata["uploader_id"], accounts[0].id.to_string());
        assert_eq!(metadata["original_name"], name);
        assert_eq!(metadata["media_type"], media_type);
        assert_eq!(metadata["size_bytes"], bytes.len());
        let attachment = if let Some(kind) = use_kind {
            let business = Uuid::new_v4();
            let mut tx = pool.begin().await.unwrap();
            sqlx::query(
                "INSERT INTO paired_restore_businesses(id,college_id,title) VALUES($1,$2,$3)",
            )
            .bind(business)
            .bind(accounts[0].identity["college"]["id"].as_str().unwrap())
            .bind(name)
            .execute(&mut *tx)
            .await
            .unwrap();
            files::attach(&mut tx, id, accounts[0].id, kind, business)
                .await
                .unwrap();
            tx.commit().await.unwrap();
            Some((kind, business))
        } else {
            None
        };
        fixtures.push(FileFixture {
            id,
            metadata,
            bytes: bytes.to_vec(),
            attachment,
        });
    }
    assert_behavior(&state, app.clone(), &accounts, &fixtures).await;
    let before_database = database_snapshot(&pool).await;
    let before_files = directory_snapshot(&source_files);
    assert_eq!(before_files.len(), 3);
    drop(app);
    drop(state);

    let stop_hook = dir.path().join("stop.sh");
    let start_hook = dir.path().join("start.sh");
    for (path, mark) in [(&stop_hook, "stop"), (&start_hook, "start")] {
        std::fs::write(path, format!("#!/usr/bin/env bash\nset -euo pipefail\nprintf '{mark}\\n' >> \"$(dirname \"$0\")/hooks.log\"\n")).unwrap();
    }
    let options = pool.connect_options();
    run_bash(
        &[
            "-c".to_owned(),
            "chmod u+x \"$1\" \"$2\"".to_owned(),
            "paired-restore-test".to_owned(),
            shell_path(&stop_hook),
            shell_path(&start_hook),
        ],
        &options,
    );
    let infra = Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .join("infra");
    run_bash(
        &[
            shell_path(&infra.join("paired-backup.sh")),
            shell_path(&bundle),
            "--native".to_owned(),
            shell_path(&source_files),
            "--app-build".to_owned(),
            BUILD_ID.to_owned(),
            "--stop-hook".to_owned(),
            shell_path(&stop_hook),
            "--start-hook".to_owned(),
            shell_path(&start_hook),
        ],
        &options,
    );
    assert_eq!(
        std::fs::read(dir.path().join("hooks.log")).unwrap(),
        b"stop\nstart\n"
    );
    assert!(!restored_files.exists());
    let restored_database = format!("paired_restore_{}", Uuid::new_v4().simple());
    run_bash(
        &[
            shell_path(&infra.join("paired-restore.sh")),
            shell_path(&bundle),
            restored_database.clone(),
            shell_path(&restored_files),
            "--app-build".to_owned(),
            BUILD_ID.to_owned(),
            "--native".to_owned(),
        ],
        &options,
    );
    assert!(
        before_database == database_snapshot(&pool).await,
        "source database is unchanged"
    );
    assert_eq!(before_files, directory_snapshot(&source_files));
    assert_eq!(before_files, directory_snapshot(&restored_files));
    assert_eq!(
        std::fs::read(dir.path().join("hooks.log")).unwrap(),
        b"stop\nstart\n"
    );

    let restored = PgPoolOptions::new()
        .max_connections(5)
        .connect_with((*options).clone().database(&restored_database))
        .await
        .expect("restored database is reachable");
    assert!(
        before_database == database_snapshot(&restored).await,
        "database rows and metadata are restored exactly"
    );
    let restored_config = common::config(&[
        ("FILE_STORAGE_DIR", restored_files.to_str().unwrap()),
        ("FILE_MAX_BYTES", "65536"),
        ("APP_BUILD_ID", BUILD_ID),
    ]);
    let restored_state = AppState::from_config(restored.clone(), &restored_config);
    let restored_app = http::router(restored_state.clone(), &restored_config);
    assert_behavior(&restored_state, restored_app.clone(), &accounts, &fixtures).await;
    let source_state = AppState::from_config(pool.clone(), &config);
    assert_behavior(
        &source_state,
        http::router(source_state.clone(), &config),
        &accounts,
        &fixtures,
    )
    .await;
    for account in &accounts {
        let login = Request::builder()
            .method("POST")
            .uri("/api/v1/auth/login")
            .header("content-type", "application/json")
            .body(Body::from(
                json!({"login": account.login, "password": PASSWORD}).to_string(),
            ))
            .unwrap();
        let (status, _, body) = common::send(restored_app.clone(), login).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "restored account password authenticates"
        );
        let token = body["data"]["access_token"].as_str().unwrap();
        let (status, _, body) =
            common::send(restored_app.clone(), request("GET", "/api/v1/me", token)).await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body["data"], account.identity);
    }
    assert!(
        before_database == database_snapshot(&pool).await,
        "restored account activity does not modify the source database"
    );
    assert_eq!(before_files, directory_snapshot(&source_files));
    restored.close().await;
    let artifacts = dir.keep();
    println!(
        "paired restore passed; retained database={restored_database}; synthetic artifacts={}",
        artifacts.display()
    );
}
