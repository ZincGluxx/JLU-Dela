mod common;

use axum::{
    Extension,
    body::Body,
    http::{Method, Request, StatusCode, header},
};
use jlu_dela_api::auth::{AuthenticatedUser, handlers};
use serde_json::{Value, json};
use tower_http::request_id::RequestId;
use uuid::Uuid;

#[tokio::test]
async fn me_serializes_unverified_identity_with_an_explicit_null_college() {
    let response = handlers::me(
        AuthenticatedUser {
            user_id: Uuid::new_v4(),
            session_id: Uuid::new_v4(),
            display_name: "未验证用户".to_owned(),
            timezone: "Asia/Shanghai".to_owned(),
            student_verified: false,
            college: None,
        },
        Extension(RequestId::new("student-identity-test".parse().unwrap())),
    )
    .await;
    let body = serde_json::to_value(response.0).unwrap();
    assert_eq!(body["data"]["student_verified"], false);
    assert_eq!(body["data"].get("college"), Some(&Value::Null));
}

#[tokio::test]
async fn auth_requests_reject_client_reported_student_status_and_college() {
    let app = common::router(&common::config(&[]));
    for (uri, valid_body) in [
        (
            "/api/v1/auth/activate",
            json!({ "invite_token": "inv_test", "password": "correct horse battery staple" }),
        ),
        (
            "/api/v1/auth/login",
            json!({ "login": "test.user", "password": "correct horse battery staple" }),
        ),
        (
            "/api/v1/auth/refresh",
            json!({ "refresh_token": "rt_test" }),
        ),
    ] {
        for (field, value) in [
            ("student_verified", json!(true)),
            (
                "college",
                json!({ "id": "claimed-college", "name": "自报学院" }),
            ),
        ] {
            let mut body = valid_body.clone();
            body[field] = value;
            let request = Request::builder()
                .method(Method::POST)
                .uri(uri)
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(body.to_string()))
                .unwrap();
            let (status, _, body) = common::send(app.clone(), request).await;
            assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY, "{uri}: {field}");
            assert_eq!(body["error"]["code"], "INVALID_REQUEST_BODY");
        }
    }
}

#[tokio::test]
async fn me_has_no_client_write_endpoint() {
    for method in [Method::POST, Method::PUT, Method::PATCH] {
        let request = Request::builder()
            .method(method)
            .uri("/api/v1/me")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(json!({ "student_verified": true }).to_string()))
            .unwrap();
        let (status, _, body) = common::send(common::router(&common::config(&[])), request).await;
        assert_eq!(status, StatusCode::METHOD_NOT_ALLOWED);
        assert_eq!(body["error"]["code"], "METHOD_NOT_ALLOWED");
    }
}
