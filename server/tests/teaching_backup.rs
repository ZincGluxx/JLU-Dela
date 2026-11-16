#![cfg(feature = "integration")]

mod common;

use axum::{
    Router,
    body::Body,
    http::{Method, Request, StatusCode, header},
};
use jlu_dela_api::{auth::session, db, http, state::AppState};
use serde_json::{Value, json};
use sqlx::PgPool;
use uuid::Uuid;

const ENDPOINT: &str = "/api/v1/personal-backup/teaching";
const NOTES: &str = "/api/v1/personal-backup/notes";
const SEMESTER: &str = "2026-2027-1";

async fn setup() -> (Router, PgPool, Uuid, String) {
    let database_url =
        std::env::var("DATABASE_URL").expect("DATABASE_URL is required with integration");
    let config = common::config(&[
        ("DATABASE_URL", &database_url),
        ("MAX_BODY_BYTES", "8388608"),
    ]);
    let pool = db::connect(&config).await.expect("PostgreSQL is reachable");
    db::run_migrations(&pool).await.expect("migrations apply");
    let (id, token) = user(&pool).await;
    (
        http::router(
            AppState::new(pool.clone(), config.build_id.clone()),
            &config,
        ),
        pool,
        id,
        token,
    )
}

async fn user(pool: &PgPool) -> (Uuid, String) {
    let id = Uuid::new_v4();
    sqlx::query("INSERT INTO users (id, login, display_name, timezone, created_at) VALUES ($1, $2, 'teaching backup test', 'Asia/Shanghai', now())")
        .bind(id).bind(format!("teaching-backup-{id}")).execute(pool).await.unwrap();
    let session = session::issue_for_user(pool, id).await.unwrap();
    (id, session.access_token)
}

fn request(
    endpoint: &str,
    method: Method,
    token: Option<&str>,
    key: Option<&str>,
    body: Value,
) -> Request<Body> {
    let mut request = Request::builder().method(method).uri(endpoint);
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
    request(ENDPOINT, method, Some(token), Some(&key.to_string()), body)
}

fn get(token: &str) -> Request<Body> {
    request(ENDPOINT, Method::GET, Some(token), None, Value::Null)
}
fn empty() -> Value {
    json!({"revision": 0, "deleted": true, "payload": null, "updated_at": null})
}
fn put(payload: Value, revision: i32) -> Value {
    json!({"expected_revision": revision, "payload": payload})
}
fn source(id: &str) -> Value {
    json!({"source": "jlu_iedu", "source_scope": SEMESTER, "source_id": id})
}

fn payload() -> Value {
    json!({
        "format": "jlu_dela_teaching_backup", "format_version": 1, "exported_at_utc": "2026-11-16T07:00:00Z",
        "timetables": [{
            "semester_code": SEMESTER, "name": "2026–2027 第一学期", "is_current": true,
            "starts_on": "2026-09-07", "total_weeks": 20, "observed_at_utc": "2026-11-15T07:00:00Z",
            "courses": [{"course_ref": source("course-a"), "name": "合成课程", "teacher": null}],
            "lessons": [{
                "course_ref": source("course-a"), "title": "合成课次", "starts_at_utc": "2026-09-16T01:10:00Z",
                "ends_at_utc": "2026-09-16T02:00:00Z", "location": null,
                "period_start": null, "period_end": null, "weekday": 3, "week_number": 2, "note": null
            }]
        }],
        "period_times": [{"campus": "", "period": 1, "start_minute": 550, "end_minute": 600, "observed_at_utc": "2026-11-15T07:00:00Z"}],
        "course_preferences": [{"course_ref": source("course-a"), "remark": null, "retained": false}],
        "academic_completion": {
            "selection_semester": "2026-2027-1", "current_semester": "2026-2027-1", "observed_at_utc": "2026-11-15T07:00:00Z",
            "plans": [{
                "id": "school-plan-1", "name": "学校方案", "study_type": null,
                "calculated_at_school": "2026-11-01 09:30:00", "required_credits": "学校要求 160.0", "earned_credits": null, "selected_credits": "12.50",
                "groups": [{
                    "id": "school-group-1", "parent_id": null, "name": "学校课组", "kind": "任选", "required_credits": "6/8", "earned_credits": "3.0", "selected_credits": "尚未统计",
                    "course_nature": null, "required_courses": null, "earned_courses": 1, "required_groups": null, "earned_groups": 0, "choice_groups": 2
                }]
            }]
        }
    })
}

#[tokio::test]
async fn default_reads_are_private_and_do_not_insert_and_all_methods_require_auth() {
    let (app, pool, id, token) = setup().await;
    let (status, headers, body) = common::send(app.clone(), get(&token)).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(body["data"], empty());
    assert_eq!(headers[header::CACHE_CONTROL], "private, no-store");
    for method in [Method::GET, Method::PUT, Method::DELETE] {
        for (token, code) in [(None, "AUTH_REQUIRED"), (Some("invalid"), "INVALID_TOKEN")] {
            let (status, headers, body) = common::send(
                app.clone(),
                request(
                    ENDPOINT,
                    method.clone(),
                    token,
                    Some(&Uuid::new_v4().to_string()),
                    put(payload(), 0),
                ),
            )
            .await;
            assert_eq!(status, StatusCode::UNAUTHORIZED, "{body}");
            assert_eq!(body["error"]["code"], code);
            assert_eq!(headers[header::CACHE_CONTROL], "private, no-store");
        }
    }
    for query in [
        "SELECT count(*) FROM teaching_backups WHERE user_id = $1",
        "SELECT count(*) FROM idempotency_keys WHERE user_id = $1",
    ] {
        let count: i64 = sqlx::query_scalar(query)
            .bind(id)
            .fetch_one(&pool)
            .await
            .unwrap();
        assert_eq!(count, 0);
    }
}

#[tokio::test]
async fn full_b_payload_round_trips_nulls_and_school_statistics_without_recomputing() {
    let (app, _, _, token) = setup().await;
    let mut saved = payload();
    saved["timetables"][0]["total_weeks"] = Value::Null;
    saved["exported_at_utc"] = json!("2026-11-16T15:00:00+08:00");
    let (status, _, receipt) = common::send(
        app.clone(),
        write(Method::PUT, &token, Uuid::new_v4(), put(saved.clone(), 0)),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{receipt}");
    assert_eq!(receipt["data"].as_object().unwrap().len(), 3);
    assert!(receipt["data"].get("payload").is_none());
    saved["exported_at_utc"] = json!("2026-11-16T07:00:00Z");
    let (_, _, snapshot) = common::send(app, get(&token)).await;
    assert_eq!(snapshot["data"]["payload"], saved);
    assert_eq!(snapshot["data"]["deleted"], false);
}

#[tokio::test]
async fn account_headers_cannot_change_ownership_and_notes_are_a_separate_partition() {
    let (app, pool, alice_id, alice) = setup().await;
    let (bob_id, bob) = user(&pool).await;
    let key = Uuid::new_v4();
    let mut save = write(Method::PUT, &alice, key, put(payload(), 0));
    save.headers_mut()
        .insert("x-user-id", bob_id.to_string().parse().unwrap());
    let (status, _, receipt) = common::send(app.clone(), save).await;
    assert_eq!(status, StatusCode::OK, "{receipt}");
    let (_, _, current) = common::send(app.clone(), get(&alice)).await;
    assert_eq!(current["data"]["payload"], payload());
    let (_, _, absent) = common::send(app.clone(), get(&bob)).await;
    assert_eq!(absent["data"], empty());
    let (status, _, _) = common::send(
        app.clone(),
        write(Method::DELETE, &bob, key, json!({"expected_revision": 0})),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let note = json!({"id": Uuid::new_v4(), "title": "private note", "body": "not teaching", "course_offering_id": null, "lesson_id": null, "replay_source": null, "replay_id": null, "replay_title": null, "position_ms": null, "created_at": "2026-11-16T00:00:00Z", "updated_at": "2026-11-16T00:00:00Z"});
    let (status, _, receipt) = common::send(
        app.clone(),
        request(
            NOTES,
            Method::PUT,
            Some(&alice),
            Some(&key.to_string()),
            json!({"expected_revision": 0, "notes": [note.clone()]}),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{receipt}");
    let (status, _, _) = common::send(
        app.clone(),
        write(Method::DELETE, &alice, key, json!({"expected_revision": 1})),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let (_, _, notes) = common::send(
        app.clone(),
        request(NOTES, Method::GET, Some(&alice), None, Value::Null),
    )
    .await;
    assert_eq!(notes["data"]["notes"], json!([note]));
    assert_eq!(notes["data"]["revision"], 1);
    let (_, _, deleted) = common::send(app, get(&alice)).await;
    assert_eq!(deleted["data"]["revision"], 2);
    assert!(deleted["data"]["payload"].is_null());
    let endpoints: Vec<String> = sqlx::query_scalar(
        "SELECT endpoint FROM idempotency_keys WHERE user_id = $1 ORDER BY endpoint",
    )
    .bind(alice_id)
    .fetch_all(&pool)
    .await
    .unwrap();
    assert_eq!(endpoints.len(), 3);
}

#[tokio::test]
async fn partition_omission_is_preserved_and_successful_empty_or_canceled_snapshots_are_allowed() {
    let (app, _, _, token) = setup().await;
    let full = payload();
    let header = json!({"format": "jlu_dela_teaching_backup", "format_version": 1, "exported_at_utc": "2026-11-16T07:00:00Z"});
    let mut preference_only = header.clone();
    preference_only["course_preferences"] = full["course_preferences"].clone();
    let mut academic_only = header.clone();
    academic_only["academic_completion"] = full["academic_completion"].clone();
    academic_only["academic_completion"]["plans"] = json!([]);
    let mut canceled = header;
    canceled["timetables"] = full["timetables"].clone();
    canceled["period_times"] = json!([]);
    canceled["timetables"][0]["lessons"] = json!([]);
    let mut empty_courses = canceled.clone();
    empty_courses["timetables"][0]["courses"] = json!([]);
    for (revision, saved) in [preference_only, academic_only, canceled, empty_courses]
        .into_iter()
        .enumerate()
    {
        let (status, _, body) = common::send(
            app.clone(),
            write(
                Method::PUT,
                &token,
                Uuid::new_v4(),
                put(saved.clone(), revision as i32),
            ),
        )
        .await;
        assert_eq!(status, StatusCode::OK, "{body}");
        let (_, _, current) = common::send(app.clone(), get(&token)).await;
        assert_eq!(current["data"]["payload"], saved);
    }
}

#[tokio::test]
async fn cas_conflicts_keep_both_client_bodies_and_current_cloud_snapshot() {
    let (app, pool, id, token) = setup().await;
    let key = Uuid::new_v4();
    let (status, _, conflict) = common::send(
        app.clone(),
        write(Method::PUT, &token, key, put(payload(), 3)),
    )
    .await;
    assert_eq!(status, StatusCode::CONFLICT, "{conflict}");
    assert_eq!(
        conflict["error"]["code"],
        "TEACHING_BACKUP_REVISION_CONFLICT"
    );
    assert_eq!(conflict["error"]["current"], empty());
    let count: i64 = sqlx::query_scalar("SELECT count(*) FROM idempotency_keys WHERE user_id = $1")
        .bind(id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count, 0);
    let (status, _, first) = common::send(
        app.clone(),
        write(Method::PUT, &token, key, put(payload(), 0)),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{first}");
    let (_, _, current) = common::send(app.clone(), get(&token)).await;
    let mut local = payload();
    local["course_preferences"][0]["remark"] = json!("unsent local conflict");
    let original_local = local.clone();
    for (method, body) in [
        (Method::PUT, put(local.clone(), 0)),
        (Method::DELETE, json!({"expected_revision": 0})),
    ] {
        let (status, _, conflict) =
            common::send(app.clone(), write(method, &token, Uuid::new_v4(), body)).await;
        assert_eq!(status, StatusCode::CONFLICT, "{conflict}");
        assert_eq!(conflict["error"]["current"], current["data"]);
    }
    assert_eq!(local, original_local);
    let (_, _, after) = common::send(app, get(&token)).await;
    assert_eq!(after["data"], current["data"]);
}

#[tokio::test]
async fn uncertain_write_retries_keep_original_receipts_after_delete_without_resurrecting_payload()
{
    let (app, pool, id, token) = setup().await;
    let key = Uuid::new_v4();
    let body = put(payload(), 0);
    let (first, duplicate) = tokio::join!(
        common::send(app.clone(), write(Method::PUT, &token, key, body.clone())),
        common::send(app.clone(), write(Method::PUT, &token, key, body.clone())),
    );
    assert_eq!(first.0, StatusCode::OK, "{}", first.2);
    assert_eq!(duplicate.0, StatusCode::OK, "{}", duplicate.2);
    assert_eq!(first.2["data"], duplicate.2["data"]);
    sqlx::query(
        "UPDATE idempotency_keys SET created_at = now() - interval '48 hours' WHERE user_id = $1",
    )
    .bind(id)
    .execute(&pool)
    .await
    .unwrap();
    let delete_key = Uuid::new_v4();
    let delete_body = json!({"expected_revision": 1});
    let (status, _, deleted) = common::send(
        app.clone(),
        write(Method::DELETE, &token, delete_key, delete_body.clone()),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{deleted}");
    let (status, _, retry) =
        common::send(app.clone(), write(Method::PUT, &token, key, body.clone())).await;
    assert_eq!(status, StatusCode::OK, "{retry}");
    assert_eq!(retry["data"], first.2["data"]);
    let (_, _, retry) = common::send(
        app.clone(),
        write(Method::DELETE, &token, delete_key, delete_body),
    )
    .await;
    assert_eq!(retry["data"], deleted["data"]);
    let (status, _, stale) = common::send(
        app.clone(),
        write(Method::PUT, &token, Uuid::new_v4(), body.clone()),
    )
    .await;
    assert_eq!(status, StatusCode::CONFLICT, "{stale}");
    assert_eq!(stale["error"]["current"]["revision"], 2);
    let mut changed = body;
    changed["payload"]["course_preferences"][0]["retained"] = json!(true);
    let (status, _, conflict) =
        common::send(app.clone(), write(Method::PUT, &token, key, changed)).await;
    assert_eq!(status, StatusCode::CONFLICT, "{conflict}");
    assert_eq!(conflict["error"]["code"], "IDEMPOTENCY_CONFLICT");
    assert!(conflict["error"].get("current").is_none());
    let (_, _, snapshot) = common::send(app, get(&token)).await;
    assert_eq!(snapshot["data"]["revision"], 2);
    assert_eq!(snapshot["data"]["deleted"], true);
    assert!(snapshot["data"]["payload"].is_null());
    let stored: Option<Value> =
        sqlx::query_scalar("SELECT payload FROM teaching_backups WHERE user_id = $1")
            .bind(id)
            .fetch_one(&pool)
            .await
            .unwrap();
    assert!(stored.is_none(), "SQL NULL, not JSON null");
    let receipts: Vec<Value> =
        sqlx::query_scalar("SELECT response FROM idempotency_keys WHERE user_id = $1")
            .bind(id)
            .fetch_all(&pool)
            .await
            .unwrap();
    assert_eq!(receipts.len(), 2);
    for receipt in receipts {
        assert_eq!(receipt.as_object().unwrap().len(), 3);
        assert!(receipt.get("revision").is_some());
        assert!(receipt.get("deleted").is_some());
        assert!(receipt.get("updated_at").is_some());
        assert!(receipt.get("payload").is_none());
        assert!(!receipt.to_string().contains("school-plan"));
    }
}

#[tokio::test]
async fn deleting_an_absent_backup_retains_a_tombstone_and_competing_keys_cannot_overwrite() {
    let (app, _, _, token) = setup().await;
    let (status, _, receipt) = common::send(
        app.clone(),
        write(
            Method::DELETE,
            &token,
            Uuid::new_v4(),
            json!({"expected_revision": 0}),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{receipt}");
    let (status, _, stale) = common::send(
        app.clone(),
        write(Method::PUT, &token, Uuid::new_v4(), put(payload(), 0)),
    )
    .await;
    assert_eq!(status, StatusCode::CONFLICT, "{stale}");
    assert_eq!(stale["error"]["current"]["revision"], 1);
    assert!(stale["error"]["current"]["payload"].is_null());
    let mut other = payload();
    other["course_preferences"][0]["remark"] = json!("second device");
    let (first, second) = tokio::join!(
        common::send(
            app.clone(),
            write(Method::PUT, &token, Uuid::new_v4(), put(payload(), 1))
        ),
        common::send(
            app.clone(),
            write(Method::PUT, &token, Uuid::new_v4(), put(other.clone(), 1))
        ),
    );
    assert!(
        (first.0 == StatusCode::OK && second.0 == StatusCode::CONFLICT)
            || (second.0 == StatusCode::OK && first.0 == StatusCode::CONFLICT)
    );
    let (_, _, current) = common::send(app, get(&token)).await;
    assert_eq!(current["data"]["revision"], 2);
    let losing = if first.0 == StatusCode::CONFLICT {
        first.2
    } else {
        second.2
    };
    assert_eq!(losing["error"]["current"], current["data"]);
    assert!(current["data"]["payload"] == payload() || current["data"]["payload"] == other);
}

#[tokio::test]
async fn unknown_fields_are_rejected_at_every_nested_boundary_and_never_persist() {
    let (app, _, _, token) = setup().await;
    let pointers = [
        "",
        "/payload",
        "/payload/timetables/0",
        "/payload/timetables/0/courses/0",
        "/payload/timetables/0/courses/0/course_ref",
        "/payload/timetables/0/lessons/0",
        "/payload/timetables/0/lessons/0/course_ref",
        "/payload/period_times/0",
        "/payload/course_preferences/0",
        "/payload/course_preferences/0/course_ref",
        "/payload/academic_completion",
        "/payload/academic_completion/plans/0",
        "/payload/academic_completion/plans/0/groups/0",
    ];
    for field in [
        "user_id",
        "device_uuid",
        "credentials",
        "cookie",
        "raw_response",
    ] {
        for pointer in pointers {
            let mut body = put(payload(), 0);
            body.pointer_mut(pointer)
                .unwrap()
                .as_object_mut()
                .unwrap()
                .insert(field.into(), json!("must not persist"));
            let (status, _, error) = common::send(
                app.clone(),
                write(Method::PUT, &token, Uuid::new_v4(), body),
            )
            .await;
            assert_eq!(
                status,
                StatusCode::UNPROCESSABLE_ENTITY,
                "{pointer}/{field}: {error}"
            );
            assert_eq!(error["error"]["code"], "INVALID_REQUEST_BODY");
        }
        let (status, _, error) = common::send(
            app.clone(),
            write(
                Method::DELETE,
                &token,
                Uuid::new_v4(),
                json!({"expected_revision": 0, field: "must not persist"}),
            ),
        )
        .await;
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{error}");
    }
    let (_, _, current) = common::send(app, get(&token)).await;
    assert_eq!(current["data"], empty());
}

#[tokio::test]
async fn time_date_source_reference_selection_and_string_limits_are_validated() {
    let (app, _, _, token) = setup().await;
    let mut cases = vec![
        put(
            json!({"format": "jlu_dela_teaching_backup", "format_version": 1, "exported_at_utc": "2026-11-16T00:00:00Z"}),
            0,
        ),
        put(payload(), -1),
        put(payload(), i32::MAX),
    ];
    for (pointer, value) in [
        ("/format", json!("notes")),
        ("/format_version", json!(2)),
        ("/exported_at_utc", json!("2026-11-16")),
        ("/timetables", Value::Null),
        ("/timetables", json!([])),
        ("/course_preferences", json!([])),
        ("/timetables/0/semester_code", json!("invalid")),
        ("/timetables/0/starts_on", json!("2026-02-30")),
        ("/timetables/0/starts_on", json!("2026-9-07")),
        ("/timetables/0/starts_on", json!("-0001-09-07")),
        ("/timetables/0/observed_at_utc", json!("invalid")),
        ("/timetables/0/total_weeks", json!(0)),
        ("/timetables/0/total_weeks", json!(105)),
        (
            "/timetables/0/courses/0/course_ref/source",
            json!("chaoxing"),
        ),
        ("/timetables/0/courses/0/course_ref/source_id", json!(" ")),
        (
            "/timetables/0/courses/0/course_ref/source_id",
            json!("x".repeat(301)),
        ),
        (
            "/timetables/0/courses/0/course_ref/source_scope",
            json!("2026-2027-2"),
        ),
        ("/timetables/0/courses/0/name", json!("文".repeat(301))),
        ("/timetables/0/courses/0/teacher", json!("文".repeat(301))),
        (
            "/timetables/0/lessons/0/course_ref/source_id",
            json!("missing"),
        ),
        ("/timetables/0/lessons/0/starts_at_utc", json!("invalid")),
        (
            "/timetables/0/lessons/0/ends_at_utc",
            json!("2026-09-16T01:10:00Z"),
        ),
        ("/timetables/0/lessons/0/period_start", json!(1)),
        ("/timetables/0/lessons/0/weekday", json!(8)),
        ("/timetables/0/lessons/0/week_number", json!(21)),
        ("/timetables/0/lessons/0/note", json!("文".repeat(2001))),
        ("/period_times/0/end_minute", json!(550)),
        ("/period_times/0/start_minute", json!(-1)),
        ("/period_times/0/end_minute", json!(1441)),
        ("/period_times/0/period", json!(501)),
        ("/period_times/0/campus", json!("文".repeat(101))),
        ("/course_preferences/0/remark", json!("文".repeat(101))),
        (
            "/course_preferences/0/course_ref/source_scope",
            json!("iedu"),
        ),
        ("/academic_completion", Value::Null),
        ("/academic_completion/observed_at_utc", json!("invalid")),
        ("/academic_completion/plans/0/required_credits", json!(160)),
        (
            "/academic_completion/plans/0/calculated_at_school",
            json!("x".repeat(101)),
        ),
        (
            "/academic_completion/plans/0/groups/0/earned_courses",
            json!(-1),
        ),
        (
            "/academic_completion/plans/0/groups/0/choice_groups",
            json!(1_000_001),
        ),
    ] {
        let mut changed = payload();
        *changed.pointer_mut(pointer).unwrap() = value;
        cases.push(put(changed, 0));
    }
    for missing in ["timetables", "period_times"] {
        let mut changed = payload();
        changed.as_object_mut().unwrap().remove(missing);
        cases.push(put(changed, 0));
    }
    for pointer in [
        "/timetables/0/courses/0",
        "/timetables/0/lessons/0",
        "/course_preferences/0",
        "/academic_completion/plans/0",
        "/academic_completion/plans/0/groups/0",
    ] {
        let mut changed = payload();
        let object = changed
            .pointer_mut(pointer)
            .unwrap()
            .as_object_mut()
            .unwrap();
        let nullable = match pointer {
            "/timetables/0/courses/0" => "teacher",
            "/timetables/0/lessons/0" => "location",
            "/course_preferences/0" => "remark",
            "/academic_completion/plans/0" => "study_type",
            _ => "parent_id",
        };
        object.remove(nullable);
        cases.push(put(changed, 0));
    }
    for body in cases {
        let (status, _, error) = common::send(
            app.clone(),
            write(Method::PUT, &token, Uuid::new_v4(), body.clone()),
        )
        .await;
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{body}: {error}");
    }
    let (_, _, current) = common::send(app, get(&token)).await;
    assert_eq!(current["data"], empty());
}

#[tokio::test]
async fn collection_caps_and_duplicate_keys_are_rejected_before_writes() {
    let (app, _, _, token) = setup().await;
    for (pointer, max) in [
        ("/timetables", 12),
        ("/course_preferences", 2000),
        ("/period_times", 500),
        ("/timetables/0/courses", 1000),
        ("/timetables/0/lessons", 10000),
        ("/academic_completion/plans", 20),
        ("/academic_completion/plans/0/groups", 500),
    ] {
        let mut changed = payload();
        let example = changed.pointer(pointer).unwrap()[0].clone();
        *changed.pointer_mut(pointer).unwrap() = json!(vec![example; max + 1]);
        let (status, _, error) = common::send(
            app.clone(),
            write(Method::PUT, &token, Uuid::new_v4(), put(changed, 0)),
        )
        .await;
        assert_eq!(
            status,
            StatusCode::UNPROCESSABLE_ENTITY,
            "{pointer}: {error}"
        );
        assert_eq!(error["error"]["fields"][0]["code"], "TOO_MANY_ITEMS");
    }
    for pointer in [
        "/timetables",
        "/course_preferences",
        "/period_times",
        "/timetables/0/courses",
    ] {
        let mut changed = payload();
        let example = changed.pointer(pointer).unwrap()[0].clone();
        changed
            .pointer_mut(pointer)
            .unwrap()
            .as_array_mut()
            .unwrap()
            .push(example);
        let (status, _, error) = common::send(
            app.clone(),
            write(Method::PUT, &token, Uuid::new_v4(), put(changed, 0)),
        )
        .await;
        assert_eq!(
            status,
            StatusCode::UNPROCESSABLE_ENTITY,
            "{pointer}: {error}"
        );
        assert_eq!(error["error"]["fields"][0]["code"], "DUPLICATE");
    }
    let (_, _, current) = common::send(app, get(&token)).await;
    assert_eq!(current["data"], empty());
}

#[tokio::test]
async fn serialized_payload_has_a_512_kib_utf8_cap_and_unicode_field_limits() {
    let (app, _, _, token) = setup().await;
    let mut saved = payload();
    saved["course_preferences"][0]["remark"] = json!("文".repeat(100));
    saved["timetables"][0]["courses"][0]["teacher"] = json!("文".repeat(300));
    let mut lesson = saved["timetables"][0]["lessons"][0].clone();
    lesson["note"] = json!("文".repeat(2000));
    saved["timetables"][0]["lessons"] = json!(vec![lesson; 87]);
    assert!(serde_json::to_vec(&saved).unwrap().len() > 512 * 1024);
    let (status, _, error) = common::send(
        app.clone(),
        write(Method::PUT, &token, Uuid::new_v4(), put(saved.clone(), 0)),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{error}");
    assert_eq!(error["error"]["fields"][0]["code"], "TOO_LARGE");
    saved["timetables"][0]["lessons"]
        .as_array_mut()
        .unwrap()
        .truncate(80);
    assert!(serde_json::to_vec(&saved).unwrap().len() < 512 * 1024);
    let (status, _, body) = common::send(
        app,
        write(Method::PUT, &token, Uuid::new_v4(), put(saved, 0)),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "{body}");
}

#[tokio::test]
async fn writes_require_json_and_uuid_keys_without_changing_backup_state() {
    let (app, _, _, token) = setup().await;
    for method in [Method::PUT, Method::DELETE] {
        let body = if method == Method::PUT {
            put(payload(), 0)
        } else {
            json!({"expected_revision": 0})
        };
        for key in [None, Some("not-a-uuid")] {
            let (status, _, error) = common::send(
                app.clone(),
                request(ENDPOINT, method.clone(), Some(&token), key, body.clone()),
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
    let (_, _, current) = common::send(app, get(&token)).await;
    assert_eq!(current["data"], empty());
}
