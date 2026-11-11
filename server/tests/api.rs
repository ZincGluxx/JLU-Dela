mod common;

use axum::{
    body::Body,
    http::{Method, Request, StatusCode, header},
};
use serde_json::json;

#[tokio::test]
async fn live_reports_process_health_without_database() {
    let config = common::config(&[]);
    let request = Request::builder()
        .method(Method::GET)
        .uri("/health/live")
        .body(Body::empty())
        .unwrap();

    let (status, headers, body) = common::send(common::router(&config), request).await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["status"], "ok");
    assert!(
        body["meta"]["request_id"]
            .as_str()
            .is_some_and(|id| !id.is_empty())
    );
    assert_eq!(
        headers
            .get("x-request-id")
            .and_then(|value| value.to_str().ok()),
        body["meta"]["request_id"].as_str()
    );
}

#[tokio::test]
async fn ready_fails_when_database_is_unavailable_but_live_stays_available() {
    let config = common::config(&[]);
    let app = common::router(&config);

    let ready = Request::builder()
        .method(Method::GET)
        .uri("/health/ready")
        .body(Body::empty())
        .unwrap();
    let (status, headers, body) = common::send(app.clone(), ready).await;

    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(body["error"]["code"], "DATABASE_UNAVAILABLE");
    assert_eq!(body["error"]["retryable"], true);
    assert_eq!(
        body["error"]["request_id"].as_str(),
        headers
            .get("x-request-id")
            .and_then(|value| value.to_str().ok())
    );

    let live = Request::builder()
        .method(Method::GET)
        .uri("/health/live")
        .body(Body::empty())
        .unwrap();
    let (status, _, body) = common::send(app, live).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["status"], "ok");
}

#[tokio::test]
async fn unknown_route_uses_the_error_envelope() {
    let request = Request::builder()
        .method(Method::GET)
        .uri("/api/v1/missing")
        .body(Body::empty())
        .unwrap();

    let (status, _, body) = common::send(common::router(&common::config(&[])), request).await;

    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(body["error"]["code"], "NOT_FOUND");
    assert_eq!(body["error"]["retryable"], false);
    assert_eq!(body["error"]["fields"], json!([]));
    assert!(body["error"]["request_id"].as_str().is_some());
}

#[tokio::test]
async fn method_not_allowed_uses_the_error_envelope() {
    let request = Request::builder()
        .method(Method::POST)
        .uri("/health/live")
        .body(Body::empty())
        .unwrap();

    let (status, _, body) = common::send(common::router(&common::config(&[])), request).await;

    assert_eq!(status, StatusCode::METHOD_NOT_ALLOWED);
    assert_eq!(body["error"]["code"], "METHOD_NOT_ALLOWED");
}

#[tokio::test]
async fn client_request_id_is_propagated_to_header_and_body() {
    let request = Request::builder()
        .method(Method::GET)
        .uri("/api/v1/meta")
        .header("x-request-id", "client-request-42")
        .body(Body::empty())
        .unwrap();

    let (status, headers, body) = common::send(common::router(&common::config(&[])), request).await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        headers
            .get("x-request-id")
            .and_then(|value| value.to_str().ok()),
        Some("client-request-42")
    );
    assert_eq!(body["meta"]["request_id"], "client-request-42");
}

#[tokio::test]
async fn meta_exposes_only_public_build_identity() {
    let request = Request::builder()
        .method(Method::GET)
        .uri("/api/v1/meta")
        .body(Body::empty())
        .unwrap();

    let (status, _, body) = common::send(common::router(&common::config(&[])), request).await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["service"], "jlu-dela-api");
    assert_eq!(body["data"]["api_version"], "v1");
    assert_eq!(body["data"]["build_id"], "test-build");
    assert_eq!(body["data"]["version"], env!("CARGO_PKG_VERSION"));
    assert!(!body.to_string().contains("test-secret"));
}

#[tokio::test]
async fn cors_allows_only_configured_origins() {
    let config = common::config(&[]);
    let app = common::router(&config);

    let allowed = Request::builder()
        .method(Method::GET)
        .uri("/api/v1/meta")
        .header(header::ORIGIN, "http://localhost:8080")
        .body(Body::empty())
        .unwrap();
    let (status, headers, _) = common::send(app.clone(), allowed).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        headers
            .get(header::ACCESS_CONTROL_ALLOW_ORIGIN)
            .and_then(|value| value.to_str().ok()),
        Some("http://localhost:8080")
    );

    let denied = Request::builder()
        .method(Method::GET)
        .uri("/api/v1/meta")
        .header(header::ORIGIN, "http://evil.example")
        .body(Body::empty())
        .unwrap();
    let (status, headers, _) = common::send(app, denied).await;
    assert_eq!(status, StatusCode::OK);
    assert!(headers.get(header::ACCESS_CONTROL_ALLOW_ORIGIN).is_none());
}
#[tokio::test]
async fn cors_preflight_is_answered_for_configured_origins() {
    let request = Request::builder()
        .method(Method::OPTIONS)
        .uri("/api/v1/meta")
        .header(header::ORIGIN, "http://localhost:8080")
        .header(header::ACCESS_CONTROL_REQUEST_METHOD, "GET")
        .body(Body::empty())
        .unwrap();

    let (status, headers, _) = common::send(common::router(&common::config(&[])), request).await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        headers
            .get(header::ACCESS_CONTROL_ALLOW_ORIGIN)
            .and_then(|value| value.to_str().ok()),
        Some("http://localhost:8080")
    );
    assert!(
        headers
            .get(header::ACCESS_CONTROL_ALLOW_METHODS)
            .and_then(|value| value.to_str().ok())
            .is_some_and(|value| value.contains("GET"))
    );
}
