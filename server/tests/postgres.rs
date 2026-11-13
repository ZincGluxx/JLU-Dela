#![cfg(feature = "integration")]

mod common;

use axum::{
    body::Body,
    http::{Method, Request, StatusCode},
};

#[tokio::test]
async fn migrations_and_readiness_work_against_postgres() {
    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL is required when running with --features integration");
    let config = common::config(&[("DATABASE_URL", &database_url)]);

    let pool = jlu_dela_api::db::connect(&config)
        .await
        .expect("PostgreSQL is reachable");
    jlu_dela_api::db::run_migrations(&pool)
        .await
        .expect("migrations apply");
    jlu_dela_api::db::run_migrations(&pool)
        .await
        .expect("migrations are idempotent");

    let schema_version: String =
        sqlx::query_scalar("SELECT value FROM service_meta WHERE key = 'schema_version'")
            .fetch_one(&pool)
            .await
            .expect("service metadata exists");
    assert_eq!(schema_version, "8");

    let app = common::router(&config);
    let request = Request::builder()
        .method(Method::GET)
        .uri("/health/ready")
        .body(Body::empty())
        .unwrap();
    let (status, _, body) = common::send(app, request).await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["status"], "ready");
    assert_eq!(body["data"]["schema_version"], "8");
    pool.close().await;
}
