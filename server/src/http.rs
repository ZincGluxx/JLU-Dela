use std::time::{Duration, Instant};

use axum::{
    Router,
    extract::{DefaultBodyLimit, Extension, Request, State},
    http::{HeaderName, Method, StatusCode, header},
    middleware::{self, Next},
    response::Response,
    routing::{get, post},
};
use tower_http::{
    cors::CorsLayer,
    request_id::{MakeRequestUuid, PropagateRequestIdLayer, RequestId, SetRequestIdLayer},
};
use tracing::{debug, info};

use crate::{
    auth,
    config::Config,
    error::{AppError, request_id, request_id_from_extensions},
    health, meta,
    state::AppState,
    sync,
};

pub const REQUEST_ID_HEADER: HeaderName = HeaderName::from_static("x-request-id");

pub fn router(state: AppState, config: &Config) -> Router {
    let routes = Router::new()
        .route("/health/live", get(health::live))
        .route("/health/ready", get(health::ready))
        .route("/api/v1/meta", get(meta::get))
        .route("/api/v1/auth/activate", post(auth::activate))
        .route("/api/v1/auth/login", post(auth::login))
        .route("/api/v1/auth/refresh", post(auth::refresh))
        .route("/api/v1/auth/logout", post(auth::logout))
        .route("/api/v1/me", get(auth::me))
        .merge(crate::todos::router())
        .merge(crate::calendar::router())
        .route("/api/v1/sync-jobs", post(sync::create))
        .route("/api/v1/sync-jobs/{id}", get(sync::get))
        .fallback(not_found)
        .with_state(state);

    let cors = CorsLayer::new()
        .allow_origin(config.cors_allowed_origins.clone())
        .allow_methods([
            Method::GET,
            Method::POST,
            Method::PATCH,
            Method::DELETE,
            Method::OPTIONS,
        ])
        .allow_headers([
            header::CONTENT_TYPE,
            header::AUTHORIZATION,
            header::IF_MATCH,
            HeaderName::from_static("idempotency-key"),
            REQUEST_ID_HEADER,
        ])
        .expose_headers([REQUEST_ID_HEADER, header::RETRY_AFTER])
        .max_age(Duration::from_secs(600));

    let middleware = tower::ServiceBuilder::new()
        .layer(cors)
        .layer(SetRequestIdLayer::new(REQUEST_ID_HEADER, MakeRequestUuid))
        .layer(PropagateRequestIdLayer::new(REQUEST_ID_HEADER))
        .layer(middleware::from_fn(log_requests))
        .layer(middleware::from_fn(normalize_framework_errors))
        .layer(middleware::from_fn_with_state(
            config.request_timeout,
            timeout_requests,
        ))
        .layer(DefaultBodyLimit::max(config.max_body_bytes));

    routes.layer(middleware)
}

async fn not_found(Extension(request_id_value): Extension<RequestId>) -> Response {
    AppError::NotFound.response(&request_id(&request_id_value))
}

async fn log_requests(request: Request, next: Next) -> Response {
    let method = request.method().clone();
    let path = request.uri().path().to_owned();
    let request_id = request_id_from_extensions(request.extensions());
    let started = Instant::now();
    let response = next.run(request).await;
    let status = response.status();
    let latency_ms = started.elapsed().as_millis() as u64;

    if path.starts_with("/health/") {
        debug!(request_id, %method, path, status = status.as_u16(), latency_ms, "request completed");
    } else {
        info!(request_id, %method, path, status = status.as_u16(), latency_ms, "request completed");
    }
    response
}

async fn normalize_framework_errors(request: Request, next: Next) -> Response {
    let request_id = request_id_from_extensions(request.extensions());
    let response = next.run(request).await;

    if response
        .headers()
        .get(header::CONTENT_TYPE)
        .is_some_and(|value| {
            value
                .to_str()
                .is_ok_and(|value| value.starts_with("application/json"))
        })
    {
        return response;
    }

    match response.status() {
        StatusCode::METHOD_NOT_ALLOWED => AppError::MethodNotAllowed.response(&request_id),
        StatusCode::PAYLOAD_TOO_LARGE => AppError::PayloadTooLarge.response(&request_id),
        _ => response,
    }
}

async fn timeout_requests(
    State(timeout): State<Duration>,
    request: Request,
    next: Next,
) -> Response {
    let request_id = request_id_from_extensions(request.extensions());
    match tokio::time::timeout(timeout, next.run(request)).await {
        Ok(response) => response,
        Err(_) => AppError::RequestTimeout.response(&request_id),
    }
}
#[cfg(test)]
mod tests {
    use std::time::Duration;

    use axum::{
        Router,
        body::{Body, to_bytes},
        routing::get,
    };
    use tower::ServiceExt;

    use super::*;

    #[tokio::test]
    async fn request_timeout_returns_json_error_envelope() {
        let app = Router::new()
            .route(
                "/slow",
                get(|| async {
                    tokio::time::sleep(Duration::from_millis(200)).await;
                    "late"
                }),
            )
            .layer(middleware::from_fn_with_state(
                Duration::from_millis(10),
                timeout_requests,
            ));

        let request = Request::builder().uri("/slow").body(Body::empty()).unwrap();
        let response = app.oneshot(request).await.expect("router responds");

        assert_eq!(response.status(), StatusCode::REQUEST_TIMEOUT);
        let body = to_bytes(response.into_body(), 4096)
            .await
            .expect("body is readable");
        let body: serde_json::Value = serde_json::from_slice(&body).expect("body is JSON");
        assert_eq!(body["error"]["code"], "REQUEST_TIMEOUT");
        assert_eq!(body["error"]["retryable"], true);
    }
}
