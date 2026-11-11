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
    config::Config,
    db, http,
    state::AppState,
    sync::{
        SyncContext, SyncFailure, SyncFuture, SyncHandler, SyncOutcome, SyncRegistry, job, worker,
    },
};
use serde_json::{Value, json};
use sqlx::PgPool;
use uuid::Uuid;

struct SuccessHandler;

impl SyncHandler for SuccessHandler {
    fn execute<'a>(&'a self, _context: SyncContext<'a>) -> SyncFuture<'a> {
        Box::pin(async move {
            Ok(SyncOutcome {
                snapshot_version: Some(7),
                complete: true,
            })
        })
    }
}

struct FailureHandler;

impl SyncHandler for FailureHandler {
    fn execute<'a>(&'a self, _context: SyncContext<'a>) -> SyncFuture<'a> {
        Box::pin(async move { Err(SyncFailure::new("SOURCE_SCHEMA_CHANGED", false)) })
    }
}

static TEST_LOCK: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());

fn registry(handler: Arc<dyn SyncHandler>) -> SyncRegistry {
    SyncRegistry::empty().register("test_source", &["items"], handler)
}

async fn setup() -> (Config, PgPool) {
    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL is required when running with --features integration");
    let config = common::config(&[("DATABASE_URL", &database_url), ("MAX_BODY_BYTES", "65536")]);
    let pool = db::connect(&config).await.expect("PostgreSQL is reachable");
    db::run_migrations(&pool).await.expect("migrations apply");
    sqlx::query("DELETE FROM sync_jobs")
        .execute(&pool)
        .await
        .expect("sync jobs are cleared");
    (config, pool)
}

fn state(config: &Config, pool: &PgPool, registry: SyncRegistry) -> AppState {
    AppState::with_sync(pool.clone(), config.build_id.clone(), registry)
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

fn create_request(token: &str, source: &str, resource: &str, scope: Value) -> Request<Body> {
    Request::builder()
        .method(Method::POST)
        .uri("/api/v1/sync-jobs")
        .header(header::CONTENT_TYPE, "application/json")
        .header(header::AUTHORIZATION, format!("Bearer {token}"))
        .body(Body::from(
            json!({ "source": source, "resource": resource, "scope": scope }).to_string(),
        ))
        .unwrap()
}

fn get_request(token: &str, job_id: &str) -> Request<Body> {
    Request::builder()
        .method(Method::GET)
        .uri(format!("/api/v1/sync-jobs/{job_id}"))
        .header(header::AUTHORIZATION, format!("Bearer {token}"))
        .body(Body::empty())
        .unwrap()
}

async fn post_job(
    app: Router,
    token: &str,
    source: &str,
    resource: &str,
    scope: Value,
) -> (StatusCode, Value) {
    let (status, _, body) = common::send(app, create_request(token, source, resource, scope)).await;
    (status, body)
}

#[tokio::test]
async fn active_jobs_are_reused_and_scope_order_is_irrelevant() {
    let _guard = TEST_LOCK.lock().await;
    let (config, pool) = setup().await;
    let user = create_user(&pool, "sync-reuse").await;
    let issued = issue(&pool, user).await;
    let app = http::router(
        state(&config, &pool, registry(Arc::new(SuccessHandler))),
        &config,
    );

    let (status, first) = post_job(
        app.clone(),
        &issued.access_token,
        "test_source",
        "items",
        json!({ "b": 2, "a": 1 }),
    )
    .await;
    assert_eq!(status, StatusCode::ACCEPTED);
    assert_eq!(first["data"]["status"], "queued");
    assert_eq!(first["data"]["reused"], false);
    assert_eq!(first["data"]["attempts"], 0);
    assert_eq!(first["data"]["scope"], json!({ "a": 1, "b": 2 }));
    let job_id = first["data"]["id"].as_str().unwrap().to_owned();

    let (status, second) = post_job(
        app,
        &issued.access_token,
        "test_source",
        "items",
        json!({ "a": 1, "b": 2 }),
    )
    .await;
    assert_eq!(status, StatusCode::ACCEPTED);
    assert_eq!(second["data"]["id"], job_id);
    assert_eq!(second["data"]["reused"], true);

    let jobs: i64 = sqlx::query_scalar("SELECT count(*) FROM sync_jobs WHERE user_id = $1")
        .bind(user)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(jobs, 1);
}

#[tokio::test]
async fn concurrent_creates_produce_a_single_active_job() {
    let _guard = TEST_LOCK.lock().await;
    let (config, pool) = setup().await;
    let user = create_user(&pool, "sync-concurrent").await;
    let issued = issue(&pool, user).await;
    let app = http::router(
        state(&config, &pool, registry(Arc::new(SuccessHandler))),
        &config,
    );

    let (left, right) = tokio::join!(
        post_job(
            app.clone(),
            &issued.access_token,
            "test_source",
            "items",
            json!({ "semester_id": "2026-fall" }),
        ),
        post_job(
            app.clone(),
            &issued.access_token,
            "test_source",
            "items",
            json!({ "semester_id": "2026-fall" }),
        )
    );

    assert_eq!(left.0, StatusCode::ACCEPTED);
    assert_eq!(right.0, StatusCode::ACCEPTED);
    assert_eq!(left.1["data"]["id"], right.1["data"]["id"]);
    assert_ne!(left.1["data"]["reused"], right.1["data"]["reused"]);

    let jobs: i64 = sqlx::query_scalar("SELECT count(*) FROM sync_jobs WHERE user_id = $1")
        .bind(user)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(jobs, 1);
}

#[tokio::test]
async fn unknown_sources_resources_and_invalid_scopes_are_rejected_without_jobs() {
    let _guard = TEST_LOCK.lock().await;
    let (config, pool) = setup().await;
    let user = create_user(&pool, "sync-reject").await;
    let issued = issue(&pool, user).await;
    let state = state(&config, &pool, registry(Arc::new(SuccessHandler)));
    let app = http::router(state, &config);

    let (status, body) = post_job(
        app.clone(),
        &issued.access_token,
        "unknown_source",
        "items",
        json!({}),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(body["error"]["code"], "UNSUPPORTED_SOURCE");

    let (status, body) = post_job(
        app.clone(),
        &issued.access_token,
        "test_source",
        "todos",
        json!({}),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(body["error"]["code"], "UNSUPPORTED_RESOURCE");

    let (status, body) = post_job(
        app.clone(),
        &issued.access_token,
        "test_source",
        "items",
        json!([]),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(body["error"]["code"], "VALIDATION_FAILED");
    assert_eq!(body["error"]["fields"][0]["path"], "scope");

    let oversized = "x".repeat(5000);
    let (status, body) = post_job(
        app.clone(),
        &issued.access_token,
        "test_source",
        "items",
        json!({ "query": oversized }),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(body["error"]["fields"][0]["code"], "too_large");

    let (status, body) =
        post_job(app, &issued.access_token, "Test_Source", "items", json!({})).await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(body["error"]["fields"][0]["code"], "invalid_format");

    let jobs: i64 = sqlx::query_scalar("SELECT count(*) FROM sync_jobs WHERE user_id = $1")
        .bind(user)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(jobs, 0);
}

#[tokio::test]
async fn worker_completes_a_job_and_records_its_outcome() {
    let _guard = TEST_LOCK.lock().await;
    let (config, pool) = setup().await;
    let user = create_user(&pool, "sync-success").await;
    let issued = issue(&pool, user).await;
    let state = state(&config, &pool, registry(Arc::new(SuccessHandler)));
    let app = http::router(state.clone(), &config);

    let (_, created) = post_job(
        app.clone(),
        &issued.access_token,
        "test_source",
        "items",
        json!({ "semester_id": "2026-fall" }),
    )
    .await;
    let job_id = created["data"]["id"].as_str().unwrap().to_owned();

    let settled = worker::run_once(&state).await.expect("worker runs");
    assert_eq!(settled.map(|id| id.to_string()), Some(job_id.clone()));

    let (status, _, body) = common::send(app, get_request(&issued.access_token, &job_id)).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["status"], "succeeded");
    assert_eq!(body["data"]["attempts"], 1);
    assert_eq!(body["data"]["complete"], true);
    assert_eq!(body["data"]["snapshot_version"], 7);
    assert_eq!(body["data"]["error"], Value::Null);
    assert!(body["data"]["started_at"].is_string());
    assert!(body["data"]["finished_at"].is_string());
}

#[tokio::test]
async fn worker_failure_is_terminal_and_a_retry_creates_a_new_job() {
    let _guard = TEST_LOCK.lock().await;
    let (config, pool) = setup().await;
    let user = create_user(&pool, "sync-failure").await;
    let issued = issue(&pool, user).await;
    let state = state(&config, &pool, registry(Arc::new(FailureHandler)));
    let app = http::router(state.clone(), &config);

    let (_, created) = post_job(
        app.clone(),
        &issued.access_token,
        "test_source",
        "items",
        json!({ "semester_id": "2026-fall" }),
    )
    .await;
    let job_id = created["data"]["id"].as_str().unwrap().to_owned();
    worker::run_once(&state).await.expect("worker runs");

    let (_, _, body) = common::send(app.clone(), get_request(&issued.access_token, &job_id)).await;
    assert_eq!(body["data"]["status"], "failed");
    assert_eq!(body["data"]["error"]["code"], "SOURCE_SCHEMA_CHANGED");
    assert_eq!(body["data"]["error"]["retryable"], false);
    assert_eq!(body["data"]["complete"], Value::Null);
    assert_eq!(body["data"]["snapshot_version"], Value::Null);

    let (status, retried) = post_job(
        app,
        &issued.access_token,
        "test_source",
        "items",
        json!({ "semester_id": "2026-fall" }),
    )
    .await;
    assert_eq!(status, StatusCode::ACCEPTED);
    assert_eq!(retried["data"]["reused"], false);
    assert_ne!(retried["data"]["id"], job_id);
}

#[tokio::test]
async fn expired_leases_are_requeued_and_bounded_by_attempt_limit() {
    let _guard = TEST_LOCK.lock().await;
    let (config, pool) = setup().await;
    let user = create_user(&pool, "sync-lease").await;
    let issued = issue(&pool, user).await;
    let state = state(&config, &pool, registry(Arc::new(SuccessHandler)));
    let app = http::router(state, &config);

    let (_, created) = post_job(
        app,
        &issued.access_token,
        "test_source",
        "items",
        json!({ "semester_id": "2026-fall" }),
    )
    .await;
    let job_id = Uuid::parse_str(created["data"]["id"].as_str().unwrap()).unwrap();

    worker::claim(&pool).await.unwrap().expect("job is claimed");
    expire_lease(&pool, job_id).await;
    assert_eq!(worker::requeue_expired(&pool).await.unwrap(), 1);
    assert_eq!(
        job::get(&pool, user, job_id).await.unwrap().status,
        "queued"
    );

    worker::claim(&pool)
        .await
        .unwrap()
        .expect("job is claimed again");
    expire_lease(&pool, job_id).await;
    worker::requeue_expired(&pool).await.unwrap();
    assert_eq!(
        job::get(&pool, user, job_id).await.unwrap().status,
        "queued"
    );

    worker::claim(&pool)
        .await
        .unwrap()
        .expect("job is claimed a third time");
    expire_lease(&pool, job_id).await;
    worker::requeue_expired(&pool).await.unwrap();

    let job = job::get(&pool, user, job_id).await.unwrap();
    assert_eq!(job.status, "failed");
    assert_eq!(job.error_code.as_deref(), Some("SYNC_INTERRUPTED"));
    assert_eq!(job.error_retryable, Some(true));
    assert_eq!(job.attempts, worker::MAX_ATTEMPTS);
    assert!(job.finished_at.is_some());
}

async fn expire_lease(pool: &PgPool, job_id: Uuid) {
    sqlx::query(
        "UPDATE sync_jobs SET lease_expires_at = now() - interval '1 second' WHERE id = $1",
    )
    .bind(job_id)
    .execute(pool)
    .await
    .expect("lease is expired");
}

#[tokio::test]
async fn jobs_are_visible_only_to_their_owner_and_survive_router_rebuild() {
    let _guard = TEST_LOCK.lock().await;
    let (config, pool) = setup().await;
    let owner = create_user(&pool, "sync-owner").await;
    let other = create_user(&pool, "sync-other").await;
    let owner_session = issue(&pool, owner).await;
    let other_session = issue(&pool, other).await;
    let first_app = http::router(
        state(&config, &pool, registry(Arc::new(SuccessHandler))),
        &config,
    );

    let (_, created) = post_job(
        first_app,
        &owner_session.access_token,
        "test_source",
        "items",
        json!({ "semester_id": "2026-fall" }),
    )
    .await;
    let job_id = created["data"]["id"].as_str().unwrap().to_owned();

    let rebuilt_app = http::router(
        state(&config, &pool, registry(Arc::new(SuccessHandler))),
        &config,
    );

    let (status, _, body) = common::send(
        rebuilt_app.clone(),
        get_request(&owner_session.access_token, &job_id),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["status"], "queued");

    let (status, _, body) = common::send(
        rebuilt_app.clone(),
        get_request(&other_session.access_token, &job_id),
    )
    .await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(body["error"]["code"], "SYNC_JOB_NOT_FOUND");

    let (status, _, body) = common::send(
        rebuilt_app,
        get_request(&owner_session.access_token, "not-a-uuid"),
    )
    .await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(body["error"]["code"], "SYNC_JOB_NOT_FOUND");
}

#[tokio::test]
async fn sync_endpoints_require_a_session_and_ignore_user_headers() {
    let _guard = TEST_LOCK.lock().await;
    let (config, pool) = setup().await;
    let owner = create_user(&pool, "sync-header-owner").await;
    let other = create_user(&pool, "sync-header-other").await;
    let owner_session = issue(&pool, owner).await;
    let other_session = issue(&pool, other).await;
    let app = http::router(
        state(&config, &pool, registry(Arc::new(SuccessHandler))),
        &config,
    );

    let request = Request::builder()
        .method(Method::POST)
        .uri("/api/v1/sync-jobs")
        .header(header::CONTENT_TYPE, "application/json")
        .body(Body::from(
            json!({ "source": "test_source", "resource": "items", "scope": {} }).to_string(),
        ))
        .unwrap();
    let (status, _, body) = common::send(app.clone(), request).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "AUTH_REQUIRED");

    let request = Request::builder()
        .method(Method::POST)
        .uri("/api/v1/sync-jobs")
        .header(header::CONTENT_TYPE, "application/json")
        .header(
            header::AUTHORIZATION,
            format!("Bearer {}", owner_session.access_token),
        )
        .header("x-user-id", other.to_string())
        .body(Body::from(
            json!({
                "source": "test_source",
                "resource": "items",
                "scope": { "semester_id": "2026-fall" }
            })
            .to_string(),
        ))
        .unwrap();
    let (status, _, body) = common::send(app.clone(), request).await;
    assert_eq!(status, StatusCode::ACCEPTED);
    let job_id = body["data"]["id"].as_str().unwrap().to_owned();

    let (status, _, _) = common::send(
        app.clone(),
        get_request(&other_session.access_token, &job_id),
    )
    .await;
    assert_eq!(status, StatusCode::NOT_FOUND);

    let (status, _, body) =
        common::send(app, get_request(&owner_session.access_token, &job_id)).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["id"], job_id);
}

#[tokio::test]
async fn two_users_with_the_same_scope_get_separate_jobs() {
    let _guard = TEST_LOCK.lock().await;
    let (config, pool) = setup().await;
    let first = create_user(&pool, "sync-scope-first").await;
    let second = create_user(&pool, "sync-scope-second").await;
    let first_session = issue(&pool, first).await;
    let second_session = issue(&pool, second).await;
    let app = http::router(
        state(&config, &pool, registry(Arc::new(SuccessHandler))),
        &config,
    );

    let (first_status, first_body) = post_job(
        app.clone(),
        &first_session.access_token,
        "test_source",
        "items",
        json!({ "semester_id": "2026-fall" }),
    )
    .await;
    let (second_status, second_body) = post_job(
        app,
        &second_session.access_token,
        "test_source",
        "items",
        json!({ "semester_id": "2026-fall" }),
    )
    .await;

    assert_eq!(first_status, StatusCode::ACCEPTED);
    assert_eq!(second_status, StatusCode::ACCEPTED);
    assert_ne!(first_body["data"]["id"], second_body["data"]["id"]);
    assert_eq!(first_body["data"]["reused"], false);
    assert_eq!(second_body["data"]["reused"], false);

    for user in [first, second] {
        let jobs: i64 = sqlx::query_scalar("SELECT count(*) FROM sync_jobs WHERE user_id = $1")
            .bind(user)
            .fetch_one(&pool)
            .await
            .unwrap();
        assert_eq!(jobs, 1);
    }
}

#[tokio::test]
async fn restarted_worker_reclaims_an_expired_lease() {
    let _guard = TEST_LOCK.lock().await;
    let (config, pool) = setup().await;
    let user = create_user(&pool, "sync-restart").await;
    let issued = issue(&pool, user).await;
    let app = http::router(
        state(&config, &pool, registry(Arc::new(SuccessHandler))),
        &config,
    );

    let (_, created) = post_job(
        app,
        &issued.access_token,
        "test_source",
        "items",
        json!({ "semester_id": "2026-fall" }),
    )
    .await;
    let job_id = Uuid::parse_str(created["data"]["id"].as_str().unwrap()).unwrap();

    worker::claim(&pool)
        .await
        .unwrap()
        .expect("the interrupted process claimed the job");
    expire_lease(&pool, job_id).await;

    let restarted = state(&config, &pool, registry(Arc::new(SuccessHandler)));
    worker::drain(&restarted)
        .await
        .expect("the restarted worker drains the queue");

    let job = job::get(&pool, user, job_id).await.unwrap();
    assert_eq!(job.status, "succeeded");
    assert_eq!(job.attempts, 2);
    assert_eq!(job.complete, Some(true));
    assert_eq!(job.snapshot_version, Some(7));
}

#[tokio::test]
async fn stale_attempt_cannot_settle_a_reclaimed_job() {
    let _guard = TEST_LOCK.lock().await;
    let (config, pool) = setup().await;
    let user = create_user(&pool, "sync-fencing").await;
    let issued = issue(&pool, user).await;
    let app = http::router(
        state(&config, &pool, registry(Arc::new(SuccessHandler))),
        &config,
    );

    let (_, created) = post_job(
        app,
        &issued.access_token,
        "test_source",
        "items",
        json!({ "semester_id": "2026-fall" }),
    )
    .await;
    let job_id = Uuid::parse_str(created["data"]["id"].as_str().unwrap()).unwrap();

    worker::claim(&pool).await.unwrap().expect("first claim");
    expire_lease(&pool, job_id).await;
    worker::requeue_expired(&pool).await.unwrap();
    let second = worker::claim(&pool).await.unwrap().expect("second claim");
    assert_eq!(second.attempts, 2);

    job::finish_succeeded(
        &pool,
        job_id,
        1,
        SyncOutcome {
            snapshot_version: Some(1),
            complete: false,
        },
    )
    .await
    .unwrap();
    assert_eq!(
        job::get(&pool, user, job_id).await.unwrap().status,
        "running"
    );

    job::finish_failed(&pool, job_id, 1, &SyncFailure::new("STALE_ATTEMPT", false))
        .await
        .unwrap();
    assert_eq!(
        job::get(&pool, user, job_id).await.unwrap().status,
        "running"
    );

    job::finish_succeeded(
        &pool,
        job_id,
        2,
        SyncOutcome {
            snapshot_version: Some(7),
            complete: true,
        },
    )
    .await
    .unwrap();
    let job = job::get(&pool, user, job_id).await.unwrap();
    assert_eq!(job.status, "succeeded");
    assert_eq!(job.snapshot_version, Some(7));
}
