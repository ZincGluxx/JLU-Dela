use axum::{
    Router,
    body::{Body, to_bytes},
    http::{HeaderMap, Request, Response, StatusCode},
};
use jlu_dela_api::{config::Config, db, http, state::AppState};
use serde_json::Value;
use tower::ServiceExt;

pub fn config(overrides: &[(&str, &str)]) -> Config {
    let mut variables: Vec<(String, String)> = vec![
        ("HTTP_HOST".into(), "127.0.0.1".into()),
        ("HTTP_PORT".into(), "8080".into()),
        (
            "DATABASE_URL".into(),
            "postgres://jlu_dela:test-secret@127.0.0.1:1/jlu_dela".into(),
        ),
        (
            "CORS_ALLOWED_ORIGINS".into(),
            "http://localhost:8080".into(),
        ),
        ("REQUEST_TIMEOUT_SECONDS".into(), "2".into()),
        ("DATABASE_ACQUIRE_TIMEOUT_SECONDS".into(), "1".into()),
        ("MAX_BODY_BYTES".into(), "4096".into()),
        ("APP_BUILD_ID".into(), "test-build".into()),
        ("LOG_FORMAT".into(), "pretty".into()),
    ]
    .into_iter()
    .collect();

    for (key, value) in overrides {
        variables.retain(|(existing, _)| existing != key);
        variables.push(((*key).to_owned(), (*value).to_owned()));
    }

    Config::from_variables(variables).expect("test configuration is valid")
}

#[allow(dead_code)]
pub fn router(config: &Config) -> Router {
    let state = AppState::new(db::connect_lazy(config), config.build_id.clone());
    http::router(state, config)
}

pub async fn send(app: Router, request: Request<Body>) -> (StatusCode, HeaderMap, Value) {
    let response: Response<Body> = app.oneshot(request).await.expect("router responds");
    let status = response.status();
    let headers = response.headers().clone();
    let body = to_bytes(response.into_body(), 64 * 1024)
        .await
        .expect("response body is readable");
    let json = serde_json::from_slice(&body).unwrap_or(Value::Null);
    (status, headers, json)
}
