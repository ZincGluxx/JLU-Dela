#![cfg(feature = "integration")]

mod common;

use axum::{
    Router,
    body::Body,
    http::{Method, Request, StatusCode, header},
};
use jlu_dela_api::{auth::session, config::Config, db, http, state::AppState};
use serde_json::{Value, json};
use sqlx::PgPool;
use uuid::Uuid;

const ENDPOINT: &str = "/api/v1/personal-backup/notes";

async fn setup() -> (Router, PgPool, Uuid, String) {
    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL is required when running with --features integration");
    let config = common::config(&[
        ("DATABASE_URL", &database_url),
        ("MAX_BODY_BYTES", "1048576"),
    ]);
    let pool = db::connect(&config).await.expect("PostgreSQL is reachable");
    db::run_migrations(&pool).await.expect("migrations apply");
    let (user, token) = user(&pool).await;
    (router(&config, &pool), pool, user, token)
}

fn router(config: &Config, pool: &PgPool) -> Router {
    http::router(AppState::new(pool.clone(), config.build_id.clone()), config)
}

async fn user(pool: &PgPool) -> (Uuid, String) {
    let id = Uuid::new_v4();
    sqlx::query(
        "INSERT INTO users (id, login, display_name, timezone, created_at)
         VALUES ($1, $2, 'backup test', 'Asia/Shanghai', now())",
    )
    .bind(id)
    .bind(format!("backup-{id}"))
    .execute(pool)
    .await
    .expect("user is created");
    let session = session::issue_for_user(pool, id)
        .await
        .expect("session is issued");
    (id, session.access_token)
}

fn request(method: Method, token: Option<&str>, key: Option<&str>, body: Value) -> Request<Body> {
    let mut request = Request::builder().method(method).uri(ENDPOINT);
    if let Some(token) = token {
        request = request.header(header::AUTHORIZATION, format!("Bearer {token}"));
    }
    if let Some(key) = key {
        request = request.header("idempotency-key", key);
    }
    request
        .header(header::CONTENT_TYPE, "application/json")
        .body(Body::from(body.to_string()))
        .unwrap()
}

fn write(method: Method, token: &str, key: Uuid, body: Value) -> Request<Body> {
    request(method, Some(token), Some(&key.to_string()), body)
}

fn get(token: &str) -> Request<Body> {
    request(Method::GET, Some(token), None, Value::Null)
}

fn note() -> Value {
    json!({
        "id": Uuid::new_v4(),
        "title": "Private study note",
        "body": "Only my account may read this.",
        "course_offering_id": null,
        "lesson_id": null,
        "replay_source": null,
        "replay_id": null,
        "replay_title": null,
        "position_ms": null,
        "created_at": "2026-11-14T00:00:00Z",
        "updated_at": "2026-11-14T00:01:00Z",
    })
}

fn empty() -> Value {
    json!({"revision": 0, "deleted": true, "notes": [], "updated_at": null})
}

#[tokio::test]
async fn missing_backup_is_empty_and_private_without_creating_a_row() {
    let (app, pool, user, token) = setup().await;
    let (status, headers, body) = common::send(app, get(&token)).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(body["data"], empty());
    assert_eq!(headers[header::CACHE_CONTROL], "private, no-store");
    let count: i64 = sqlx::query_scalar("SELECT count(*) FROM personal_backups WHERE user_id = $1")
        .bind(user)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count, 0);
}

#[tokio::test]
async fn every_method_requires_the_authenticated_account() {
    let (app, _, _, _) = setup().await;
    for method in [Method::GET, Method::PUT, Method::DELETE] {
        let (status, headers, body) = common::send(
            app.clone(),
            request(
                method,
                None,
                Some(&Uuid::new_v4().to_string()),
                json!({"expected_revision": 0, "notes": []}),
            ),
        )
        .await;
        assert_eq!(status, StatusCode::UNAUTHORIZED, "{body}");
        assert_eq!(body["error"]["code"], "AUTH_REQUIRED");
        assert_eq!(headers[header::CACHE_CONTROL], "private, no-store");
    }
    let (status, _, body) = common::send(app, get("invalid-token")).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "INVALID_TOKEN");
}

#[tokio::test]
async fn owner_cannot_be_changed_by_headers_and_other_accounts_see_only_their_backup() {
    let (app, pool, _, alice) = setup().await;
    let (bob_id, bob) = user(&pool).await;
    let alice_note = note();
    let mut put = write(
        Method::PUT,
        &alice,
        Uuid::new_v4(),
        json!({"expected_revision": 0, "notes": [alice_note.clone()]}),
    );
    put.headers_mut()
        .insert("x-user-id", bob_id.to_string().parse().unwrap());
    let (status, _, body) = common::send(app.clone(), put).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    let (status, _, body) = common::send(app.clone(), get(&bob)).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"], empty());
    let (status, _, body) = common::send(
        app.clone(),
        write(
            Method::DELETE,
            &bob,
            Uuid::new_v4(),
            json!({"expected_revision": 0}),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{body}");
    let (status, _, body) = common::send(app, get(&alice)).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["revision"], 1);
    assert_eq!(body["data"]["notes"], json!([alice_note]));
}

#[tokio::test]
async fn cas_conflicts_include_the_complete_current_snapshot() {
    let (app, pool, user, token) = setup().await;
    let key = Uuid::new_v4();
    let (status, headers, body) = common::send(
        app.clone(),
        write(
            Method::PUT,
            &token,
            key,
            json!({"expected_revision": 4, "notes": []}),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::CONFLICT, "{body}");
    assert_eq!(body["error"]["code"], "BACKUP_REVISION_CONFLICT");
    assert_eq!(body["error"]["current"], empty());
    assert_eq!(headers[header::CACHE_CONTROL], "private, no-store");
    let count: i64 = sqlx::query_scalar("SELECT count(*) FROM idempotency_keys WHERE user_id = $1")
        .bind(user)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count, 0, "failed CAS rolls back the key reservation");
    let saved = note();
    let (status, _, receipt) = common::send(
        app.clone(),
        write(
            Method::PUT,
            &token,
            key,
            json!({"expected_revision": 0, "notes": [saved.clone()]}),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{receipt}");
    assert_eq!(receipt["data"]["revision"], 1);
    assert_eq!(receipt["data"]["deleted"], false);
    assert_eq!(receipt["data"].as_object().unwrap().len(), 3);
    assert!(receipt["data"].get("notes").is_none());
    let (_, _, current) = common::send(app.clone(), get(&token)).await;
    assert_eq!(current["data"]["notes"], json!([saved]));
    for method in [Method::PUT, Method::DELETE] {
        let body = if method == Method::PUT {
            json!({"expected_revision": 0, "notes": []})
        } else {
            json!({"expected_revision": 0})
        };
        let (status, _, conflict) =
            common::send(app.clone(), write(method, &token, Uuid::new_v4(), body)).await;
        assert_eq!(status, StatusCode::CONFLICT, "{conflict}");
        assert_eq!(conflict["error"]["code"], "BACKUP_REVISION_CONFLICT");
        assert_eq!(conflict["error"]["current"], current["data"]);
    }
}

#[tokio::test]
async fn exact_retries_never_reapply_even_after_expiry_or_a_later_delete() {
    let (app, pool, user, token) = setup().await;
    let key = Uuid::new_v4();
    let body = json!({"expected_revision": 0, "notes": [note()]});
    let (status, _, first) =
        common::send(app.clone(), write(Method::PUT, &token, key, body.clone())).await;
    assert_eq!(status, StatusCode::OK, "{first}");
    sqlx::query(
        "UPDATE idempotency_keys SET created_at = now() - interval '48 hours' WHERE user_id = $1",
    )
    .bind(user)
    .execute(&pool)
    .await
    .unwrap();
    let (status, _, retry) =
        common::send(app.clone(), write(Method::PUT, &token, key, body.clone())).await;
    assert_eq!(status, StatusCode::OK, "{retry}");
    assert_eq!(retry["data"], first["data"]);
    let delete_key = Uuid::new_v4();
    let delete_body = json!({"expected_revision": 1});
    let (status, _, deleted) = common::send(
        app.clone(),
        write(Method::DELETE, &token, delete_key, delete_body.clone()),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{deleted}");
    assert_eq!(deleted["data"]["revision"], 2);
    let (status, _, retry) = common::send(app.clone(), write(Method::PUT, &token, key, body)).await;
    assert_eq!(status, StatusCode::OK, "{retry}");
    assert_eq!(retry["data"], first["data"]);
    let (status, _, retry) = common::send(
        app.clone(),
        write(Method::DELETE, &token, delete_key, delete_body),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{retry}");
    assert_eq!(retry["data"], deleted["data"]);
    let (_, _, snapshot) = common::send(app, get(&token)).await;
    assert_eq!(snapshot["data"]["revision"], 2);
    assert_eq!(snapshot["data"]["deleted"], true);
    assert_eq!(snapshot["data"]["notes"], json!([]));
    let records: Vec<Value> =
        sqlx::query_scalar("SELECT response FROM idempotency_keys WHERE user_id = $1")
            .bind(user)
            .fetch_all(&pool)
            .await
            .unwrap();
    assert_eq!(records.len(), 2);
    for receipt in records {
        assert_eq!(receipt.as_object().unwrap().len(), 3);
        assert!(receipt.get("revision").is_some());
        assert!(receipt.get("deleted").is_some());
        assert!(receipt.get("updated_at").is_some());
    }
    let stored: Value = sqlx::query_scalar("SELECT notes FROM personal_backups WHERE user_id = $1")
        .bind(user)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(stored, json!([]));
}

#[tokio::test]
async fn same_key_rejects_changed_request_but_is_scoped_by_endpoint_and_user() {
    let (app, pool, _, token) = setup().await;
    let key = Uuid::new_v4();
    let original = json!({"expected_revision": 0, "notes": [note()]});
    let (status, _, first) = common::send(
        app.clone(),
        write(Method::PUT, &token, key, original.clone()),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{first}");
    let mut changed_revision = original.clone();
    changed_revision["expected_revision"] = json!(1);
    let mut changed_note = original.clone();
    changed_note["notes"][0]["body"] = json!("changed private content");
    for changed in [
        changed_revision,
        changed_note,
        json!({"expected_revision": 0, "notes": []}),
    ] {
        let (status, _, conflict) =
            common::send(app.clone(), write(Method::PUT, &token, key, changed)).await;
        assert_eq!(status, StatusCode::CONFLICT, "{conflict}");
        assert_eq!(conflict["error"]["code"], "IDEMPOTENCY_CONFLICT");
        assert!(conflict["error"].get("current").is_none());
    }
    let (status, _, deleted) = common::send(
        app.clone(),
        write(Method::DELETE, &token, key, json!({"expected_revision": 1})),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{deleted}");
    let (status, _, conflict) = common::send(
        app.clone(),
        write(Method::DELETE, &token, key, json!({"expected_revision": 2})),
    )
    .await;
    assert_eq!(status, StatusCode::CONFLICT, "{conflict}");
    assert_eq!(conflict["error"]["code"], "IDEMPOTENCY_CONFLICT");
    let (_, other) = user(&pool).await;
    let (status, _, body) = common::send(app, write(Method::PUT, &other, key, original)).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(body["data"]["revision"], 1);
}

#[tokio::test]
async fn deleting_an_empty_backup_creates_a_tombstone_that_rejects_old_puts() {
    let (app, _, _, token) = setup().await;
    for expected in [0, 1] {
        let (status, _, receipt) = common::send(
            app.clone(),
            write(
                Method::DELETE,
                &token,
                Uuid::new_v4(),
                json!({"expected_revision": expected}),
            ),
        )
        .await;
        assert_eq!(status, StatusCode::OK, "{receipt}");
        assert_eq!(receipt["data"]["revision"], expected + 1);
        assert_eq!(receipt["data"]["deleted"], true);
    }
    for expected in [0, 1] {
        let (status, _, conflict) = common::send(
            app.clone(),
            write(
                Method::PUT,
                &token,
                Uuid::new_v4(),
                json!({"expected_revision": expected, "notes": [note()]}),
            ),
        )
        .await;
        assert_eq!(status, StatusCode::CONFLICT, "{conflict}");
        assert_eq!(conflict["error"]["code"], "BACKUP_REVISION_CONFLICT");
        assert_eq!(conflict["error"]["current"]["revision"], 2);
        assert_eq!(conflict["error"]["current"]["deleted"], true);
        assert_eq!(conflict["error"]["current"]["notes"], json!([]));
    }
}

#[tokio::test]
async fn concurrent_same_key_retries_write_one_revision_and_different_keys_cas() {
    let (app, _, _, token) = setup().await;
    let body = json!({"expected_revision": 0, "notes": [note()]});
    let key = Uuid::new_v4();
    let (first, second) = tokio::join!(
        common::send(app.clone(), write(Method::PUT, &token, key, body.clone())),
        common::send(app.clone(), write(Method::PUT, &token, key, body)),
    );
    assert_eq!(first.0, StatusCode::OK, "{}", first.2);
    assert_eq!(second.0, StatusCode::OK, "{}", second.2);
    assert_eq!(first.2["data"], second.2["data"]);
    assert_eq!(first.2["data"]["revision"], 1);
    let body = json!({"expected_revision": 1, "notes": []});
    let (first, second) = tokio::join!(
        common::send(
            app.clone(),
            write(Method::PUT, &token, Uuid::new_v4(), body.clone())
        ),
        common::send(app, write(Method::PUT, &token, Uuid::new_v4(), body)),
    );
    assert!(
        (first.0 == StatusCode::OK && second.0 == StatusCode::CONFLICT)
            || (second.0 == StatusCode::OK && first.0 == StatusCode::CONFLICT)
    );
    let conflict = if first.0 == StatusCode::CONFLICT {
        first.2
    } else {
        second.2
    };
    assert_eq!(conflict["error"]["current"]["revision"], 2);
}

#[tokio::test]
async fn unknown_owner_local_revision_and_sensitive_fields_are_rejected_at_every_level() {
    let (app, _, _, token) = setup().await;
    for field in [
        "user_id",
        "owner",
        "revision",
        "local_revision",
        "password",
        "cookie",
        "access_token",
        "file_path",
        "school_credentials",
    ] {
        let mut top = json!({"expected_revision": 0, "notes": []});
        top[field] = json!("must not persist");
        let mut nested = json!({"expected_revision": 0, "notes": [note()]});
        nested["notes"][0][field] = json!("must not persist");
        for body in [top, nested] {
            let (status, _, error) = common::send(
                app.clone(),
                write(Method::PUT, &token, Uuid::new_v4(), body),
            )
            .await;
            assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{field}: {error}");
            assert_eq!(error["error"]["code"], "INVALID_REQUEST_BODY");
        }
        let mut delete = json!({"expected_revision": 0});
        delete[field] = json!("must not persist");
        let (status, _, body) = common::send(
            app.clone(),
            write(Method::DELETE, &token, Uuid::new_v4(), delete),
        )
        .await;
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{field}: {body}");
    }
    let (_, _, snapshot) = common::send(app, get(&token)).await;
    assert_eq!(snapshot["data"], empty());
}

#[tokio::test]
async fn shape_and_field_limits_are_validated_before_any_write() {
    let (app, _, _, token) = setup().await;
    let mut cases = vec![
        json!({"notes": []}),
        json!({"expected_revision": null, "notes": []}),
        json!({"expected_revision": -1, "notes": []}),
        json!({"expected_revision": 0.5, "notes": []}),
        json!({"expected_revision": 2147483648_i64, "notes": []}),
        json!({"expected_revision": 0}),
        json!({"expected_revision": 0, "notes": null}),
        json!({"expected_revision": 0, "notes": {}}),
        json!({"expected_revision": 0, "notes": [null]}),
        json!({"expected_revision": 0, "notes": vec![note(); 101]}),
    ];
    let duplicate = note();
    cases.push(json!({"expected_revision": 0, "notes": [duplicate.clone(), duplicate]}));
    for (field, value) in [
        ("id", json!("not-a-uuid")),
        ("title", Value::Null),
        ("title", json!("文".repeat(201))),
        ("body", json!("文".repeat(20001))),
        ("course_offering_id", json!({"cookie": "not a string"})),
        ("course_offering_id", json!("x".repeat(301))),
        ("lesson_id", json!("x".repeat(301))),
        ("replay_source", json!("x".repeat(301))),
        ("replay_id", json!("x".repeat(301))),
        ("replay_title", json!("x".repeat(301))),
        ("created_at", json!("2026-11-14")),
        ("created_at", json!("2026-11-14T01:00:00Z")),
        ("updated_at", json!("invalid")),
        ("replay_source", json!("ilearn")),
        ("replay_id", json!("replay")),
        ("position_ms", json!(0)),
        ("position_ms", json!(-1)),
        ("position_ms", json!(1.5)),
    ] {
        let mut invalid_note = note();
        invalid_note[field] = value;
        cases.push(json!({"expected_revision": 0, "notes": [invalid_note]}));
    }
    for missing in [
        "id",
        "title",
        "body",
        "course_offering_id",
        "lesson_id",
        "replay_source",
        "replay_id",
        "replay_title",
        "position_ms",
        "created_at",
        "updated_at",
    ] {
        let mut invalid_note = note();
        invalid_note.as_object_mut().unwrap().remove(missing);
        cases.push(json!({"expected_revision": 0, "notes": [invalid_note]}));
    }
    for (source, replay, position) in [
        ("", "", Value::Null),
        (" ", "replay", json!(0)),
        ("ilearn", " ", json!(0)),
        ("ilearn", "replay", json!(-1)),
    ] {
        let mut invalid_note = note();
        invalid_note["replay_source"] = json!(source);
        invalid_note["replay_id"] = json!(replay);
        invalid_note["position_ms"] = position;
        cases.push(json!({"expected_revision": 0, "notes": [invalid_note]}));
    }
    for body in cases {
        let (status, _, error) = common::send(
            app.clone(),
            write(Method::PUT, &token, Uuid::new_v4(), body),
        )
        .await;
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{error}");
    }
    let (_, _, snapshot) = common::send(app, get(&token)).await;
    assert_eq!(snapshot["data"], empty());
}

#[tokio::test]
async fn unicode_limits_nullable_fields_and_replay_metadata_round_trip() {
    let (app, _, _, token) = setup().await;
    let mut saved = note();
    saved["title"] = json!("文".repeat(200));
    saved["body"] = json!("文".repeat(20000));
    saved["course_offering_id"] = json!("c".repeat(300));
    saved["lesson_id"] = json!("l".repeat(300));
    saved["replay_source"] = json!("s".repeat(300));
    saved["replay_id"] = json!("r".repeat(300));
    saved["replay_title"] = json!("t".repeat(300));
    saved["position_ms"] = json!(0);
    saved["created_at"] = json!("2026-11-14T08:00:00+08:00");
    let (status, _, body) = common::send(
        app.clone(),
        write(
            Method::PUT,
            &token,
            Uuid::new_v4(),
            json!({"expected_revision": 0, "notes": [saved.clone()]}),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{body}");
    let (_, _, snapshot) = common::send(app.clone(), get(&token)).await;
    saved["created_at"] = json!("2026-11-14T00:00:00Z");
    assert_eq!(snapshot["data"]["notes"], json!([saved]));
    let mut minimal = note();
    minimal["title"] = json!("");
    minimal["body"] = json!("");
    let (status, _, body) = common::send(
        app.clone(),
        write(
            Method::PUT,
            &token,
            Uuid::new_v4(),
            json!({"expected_revision": 1, "notes": [minimal]}),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{body}");
    let (_, _, snapshot) = common::send(app, get(&token)).await;
    for field in [
        "course_offering_id",
        "lesson_id",
        "replay_source",
        "replay_id",
        "replay_title",
        "position_ms",
    ] {
        assert!(
            snapshot["data"]["notes"][0]
                .get(field)
                .is_some_and(Value::is_null)
        );
    }
}

#[tokio::test]
async fn serialized_notes_utf8_bytes_are_limited_to_512_kib() {
    let (app, _, _, token) = setup().await;
    let notes: Vec<Value> = (0..9)
        .map(|_| {
            let mut note = note();
            note["body"] = json!("文".repeat(20000));
            note
        })
        .collect();
    assert!(serde_json::to_vec(&notes[..8]).unwrap().len() < 512 * 1024);
    assert!(serde_json::to_vec(&notes).unwrap().len() > 512 * 1024);
    let (status, _, body) = common::send(
        app.clone(),
        write(
            Method::PUT,
            &token,
            Uuid::new_v4(),
            json!({"expected_revision": 0, "notes": notes}),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{body}");
    assert_eq!(body["error"]["fields"][0]["code"], "TOO_LARGE");
    let (status, _, body) = common::send(
        app,
        write(
            Method::PUT,
            &token,
            Uuid::new_v4(),
            json!({"expected_revision": 0, "notes": &notes[..8]}),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{body}");
}

#[tokio::test]
async fn exact_serialized_size_and_one_hundred_notes_are_accepted() {
    let (app, _, _, token) = setup().await;
    let mut notes: Vec<Value> = (0..27)
        .map(|_| {
            let mut note = note();
            note["body"] = json!("");
            note
        })
        .collect();
    let mut remaining = 512 * 1024 - serde_json::to_vec(&notes).unwrap().len();
    for note in &mut notes {
        let length = remaining.min(20_000);
        note["body"] = json!("x".repeat(length));
        remaining -= length;
    }
    assert_eq!(remaining, 0);
    assert_eq!(serde_json::to_vec(&notes).unwrap().len(), 512 * 1024);
    let (status, _, body) = common::send(
        app.clone(),
        write(
            Method::PUT,
            &token,
            Uuid::new_v4(),
            json!({"expected_revision": 0, "notes": notes}),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{body}");
    let last = notes.last_mut().unwrap();
    last["body"] = json!(format!("{}x", last["body"].as_str().unwrap()));
    assert_eq!(serde_json::to_vec(&notes).unwrap().len(), 512 * 1024 + 1);
    let (status, _, body) = common::send(
        app.clone(),
        write(
            Method::PUT,
            &token,
            Uuid::new_v4(),
            json!({"expected_revision": 1, "notes": notes}),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{body}");
    assert_eq!(body["error"]["fields"][0]["code"], "TOO_LARGE");
    let notes: Vec<Value> = (0..100).map(|_| note()).collect();
    let (status, _, body) = common::send(
        app.clone(),
        write(
            Method::PUT,
            &token,
            Uuid::new_v4(),
            json!({"expected_revision": 1, "notes": notes}),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{body}");
    let (status, _, snapshot) = common::send(app, get(&token)).await;
    assert_eq!(status, StatusCode::OK, "{snapshot}");
    assert_eq!(snapshot["data"]["notes"].as_array().unwrap().len(), 100);
    assert_eq!(snapshot["data"]["revision"], 2);
}

#[tokio::test]
async fn writes_require_json_uuid_keys_and_put_cors_is_allowed() {
    let (app, _, _, token) = setup().await;
    for method in [Method::PUT, Method::DELETE] {
        let body = if method == Method::PUT {
            json!({"expected_revision": 0, "notes": []})
        } else {
            json!({"expected_revision": 0})
        };
        for key in [None, Some("not-a-uuid")] {
            let (status, _, error) = common::send(
                app.clone(),
                request(method.clone(), Some(&token), key, body.clone()),
            )
            .await;
            assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{error}");
            assert_eq!(error["error"]["fields"][0]["path"], "Idempotency-Key");
        }
        let mut wrong_type = write(method, &token, Uuid::new_v4(), body);
        wrong_type
            .headers_mut()
            .insert(header::CONTENT_TYPE, "text/plain".parse().unwrap());
        let (status, _, error) = common::send(app.clone(), wrong_type).await;
        assert_eq!(status, StatusCode::UNSUPPORTED_MEDIA_TYPE, "{error}");
    }
    let preflight = Request::builder()
        .method(Method::OPTIONS)
        .uri(ENDPOINT)
        .header(header::ORIGIN, "http://localhost:8080")
        .header(header::ACCESS_CONTROL_REQUEST_METHOD, "PUT")
        .header(
            header::ACCESS_CONTROL_REQUEST_HEADERS,
            "content-type,authorization,idempotency-key",
        )
        .body(Body::empty())
        .unwrap();
    let (_, headers, _) = common::send(app, preflight).await;
    assert!(
        headers[header::ACCESS_CONTROL_ALLOW_METHODS]
            .to_str()
            .unwrap()
            .split(',')
            .any(|method| method.trim() == "PUT")
    );
}
