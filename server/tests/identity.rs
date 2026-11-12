#![cfg(feature = "integration")]

mod common;

use axum::{
    Router,
    body::Body,
    http::{Method, Request, StatusCode, header},
};
use jlu_dela_api::{
    auth::{
        invite::{self, CreateError},
        login, password, token,
    },
    config::Config,
    db, http,
    state::AppState,
};
use serde_json::{Value, json};
use sqlx::PgPool;
use time::Duration;
use uuid::Uuid;

const PASSWORD: &str = "correct horse battery staple";

async fn setup() -> (Config, PgPool) {
    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL is required when running with --features integration");
    let config = common::config(&[("DATABASE_URL", &database_url)]);
    let pool = db::connect(&config).await.expect("PostgreSQL is reachable");
    db::run_migrations(&pool).await.expect("migrations apply");
    (config, pool)
}

fn router(config: &Config, pool: &PgPool) -> Router {
    http::router(AppState::new(pool.clone(), config.build_id.clone()), config)
}

fn unique_login(prefix: &str) -> String {
    format!("{prefix}.{}", &Uuid::new_v4().simple().to_string()[..12])
}

async fn create_invitation(pool: &PgPool, login: &str, display_name: &str) -> String {
    invite::create(pool, login, display_name, Duration::hours(1))
        .await
        .expect("invitation is created")
        .token
}

async fn create_user(pool: &PgPool, login: &str, password_hash: Option<String>, disabled: bool) {
    sqlx::query(
        "INSERT INTO users (id, login, display_name, timezone, password_hash, created_at, disabled_at)
         VALUES ($1, $2, $3, 'Asia/Shanghai', $4, now(), CASE WHEN $5 THEN now() ELSE NULL END)",
    )
    .bind(Uuid::new_v4())
    .bind(login)
    .bind(login)
    .bind(password_hash)
    .bind(disabled)
    .execute(pool)
    .await
    .expect("user is created");
}

fn post_json(uri: &str, body: Value) -> Request<Body> {
    Request::builder()
        .method(Method::POST)
        .uri(uri)
        .header(header::CONTENT_TYPE, "application/json")
        .body(Body::from(body.to_string()))
        .unwrap()
}

fn post_json_with_request_id(uri: &str, body: Value, request_id: &str) -> Request<Body> {
    let mut request = post_json(uri, body);
    request
        .headers_mut()
        .insert("x-request-id", request_id.parse().unwrap());
    request
}

fn get(uri: &str, token: &str) -> Request<Body> {
    Request::builder()
        .method(Method::GET)
        .uri(uri)
        .header(header::AUTHORIZATION, format!("Bearer {token}"))
        .body(Body::empty())
        .unwrap()
}

fn login_body(login: &str, password_value: &str) -> Value {
    json!({ "login": login, "password": password_value })
}

#[tokio::test]
async fn activation_issues_a_usable_session_and_stores_only_hashes() {
    let (config, pool) = setup().await;
    let login = unique_login("activate");
    let token_value = create_invitation(&pool, &login, "激活用户").await;
    let app = router(&config, &pool);

    let (status, headers, body) = common::send(
        app.clone(),
        post_json(
            "/api/v1/auth/activate",
            json!({ "invite_token": token_value, "password": PASSWORD }),
        ),
    )
    .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["token_type"], "Bearer");
    assert_eq!(body["data"]["expires_in"], 900);
    let access = body["data"]["access_token"].as_str().unwrap().to_owned();
    let refresh = body["data"]["refresh_token"].as_str().unwrap().to_owned();
    assert!(access.starts_with("at_"));
    assert!(refresh.starts_with("rt_"));
    assert_eq!(
        body["meta"]["request_id"].as_str(),
        headers
            .get("x-request-id")
            .and_then(|value| value.to_str().ok())
    );

    let (status, _, me) = common::send(app, get("/api/v1/me", &access)).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(me["data"]["display_name"], "激活用户");
    assert_eq!(me["data"]["timezone"], "Asia/Shanghai");

    let stored: String = sqlx::query_scalar("SELECT password_hash FROM users WHERE login = $1")
        .bind(&login)
        .fetch_one(&pool)
        .await
        .expect("password hash is stored");
    assert!(stored.starts_with("$argon2id$"));
    assert_ne!(stored, PASSWORD);
    assert!(!stored.contains(PASSWORD));
    assert!(password::verify(PASSWORD, &stored));
    assert!(!password::verify("wrong password value", &stored));

    let stored_token_hash: String =
        sqlx::query_scalar("SELECT token_hash FROM invites WHERE login = $1")
            .bind(&login)
            .fetch_one(&pool)
            .await
            .expect("invitation digest is stored");
    assert_eq!(stored_token_hash, token::digest(&token_value));
    assert_ne!(stored_token_hash, token_value);
    assert_eq!(
        sqlx::query_scalar::<_, i64>("SELECT count(*) FROM invites WHERE token_hash = $1")
            .bind(&token_value)
            .fetch_one(&pool)
            .await
            .expect("invitation rows are readable"),
        0
    );
}

#[tokio::test]
async fn repeated_activation_is_rejected_without_creating_a_second_user() {
    let (config, pool) = setup().await;
    let login = unique_login("repeat");
    let token_value = create_invitation(&pool, &login, "重复激活").await;
    let app = router(&config, &pool);
    let request = || {
        post_json(
            "/api/v1/auth/activate",
            json!({ "invite_token": token_value, "password": PASSWORD }),
        )
    };

    let (status, _, _) = common::send(app.clone(), request()).await;
    assert_eq!(status, StatusCode::OK);

    let (status, _, body) = common::send(app, request()).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(body["error"]["code"], "INVALID_INVITE");

    let users: i64 = sqlx::query_scalar("SELECT count(*) FROM users WHERE login = $1")
        .bind(&login)
        .fetch_one(&pool)
        .await
        .expect("users are readable");
    assert_eq!(users, 1);
}

#[tokio::test]
async fn concurrent_activation_of_one_invitation_succeeds_once() {
    let (config, pool) = setup().await;
    let login = unique_login("concurrent");
    let token_value = create_invitation(&pool, &login, "并发激活").await;
    let app = router(&config, &pool);
    let first_app = app.clone();
    let second_app = app.clone();
    let first_token = token_value.clone();
    let second_token = token_value.clone();
    let (first, second) = tokio::join!(
        tokio::spawn(async move {
            common::send(
                first_app,
                post_json(
                    "/api/v1/auth/activate",
                    json!({ "invite_token": first_token, "password": PASSWORD }),
                ),
            )
            .await
        }),
        tokio::spawn(async move {
            common::send(
                second_app,
                post_json(
                    "/api/v1/auth/activate",
                    json!({ "invite_token": second_token, "password": PASSWORD }),
                ),
            )
            .await
        })
    );
    let first = first.expect("first activation task completed");
    let second = second.expect("second activation task completed");

    let mut statuses = [first.0, second.0];
    statuses.sort();
    assert_eq!(statuses, [StatusCode::OK, StatusCode::UNAUTHORIZED]);
    for (status, _, body) in [first, second] {
        if status == StatusCode::UNAUTHORIZED {
            assert_eq!(body["error"]["code"], "INVALID_INVITE");
        }
    }

    let users: i64 = sqlx::query_scalar("SELECT count(*) FROM users WHERE login = $1")
        .bind(&login)
        .fetch_one(&pool)
        .await
        .expect("users are readable");
    assert_eq!(users, 1);
}

#[tokio::test]
async fn expired_and_unknown_invitations_are_rejected() {
    let (config, pool) = setup().await;
    let login = unique_login("expired");
    let token_value = create_invitation(&pool, &login, "过期邀请").await;
    sqlx::query("UPDATE invites SET expires_at = now() - interval '1 second' WHERE login = $1")
        .bind(&login)
        .execute(&pool)
        .await
        .expect("invitation expiry is moved into the past");
    let app = router(&config, &pool);

    for invite_token in [token_value, "inv_unknown_invitation".to_owned()] {
        let (status, _, body) = common::send(
            app.clone(),
            post_json(
                "/api/v1/auth/activate",
                json!({ "invite_token": invite_token, "password": PASSWORD }),
            ),
        )
        .await;
        assert_eq!(status, StatusCode::UNAUTHORIZED);
        assert_eq!(body["error"]["code"], "INVALID_INVITE");
        assert_eq!(
            body["error"]["message"],
            "The invitation is invalid, expired or already used."
        );
    }

    let users: i64 = sqlx::query_scalar("SELECT count(*) FROM users WHERE login = $1")
        .bind(&login)
        .fetch_one(&pool)
        .await
        .expect("users are readable");
    assert_eq!(users, 0);
}

#[tokio::test]
async fn logout_then_login_again_and_refresh_restore_the_session() {
    let (config, pool) = setup().await;
    let login = unique_login("login");
    let token_value = create_invitation(&pool, &login, "登录用户").await;
    let app = router(&config, &pool);

    let (status, _, body) = common::send(
        app.clone(),
        post_json(
            "/api/v1/auth/activate",
            json!({ "invite_token": token_value, "password": PASSWORD }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let activation_access = body["data"]["access_token"].as_str().unwrap().to_owned();
    let activation_refresh = body["data"]["refresh_token"].as_str().unwrap().to_owned();

    let logout = Request::builder()
        .method(Method::POST)
        .uri("/api/v1/auth/logout")
        .header(header::CONTENT_TYPE, "application/json")
        .header(header::AUTHORIZATION, format!("Bearer {activation_access}"))
        .body(Body::from(
            json!({ "refresh_token": activation_refresh }).to_string(),
        ))
        .unwrap();
    let (status, _, _) = common::send(app.clone(), logout).await;
    assert_eq!(status, StatusCode::NO_CONTENT);

    let (status, _, body) = common::send(
        app.clone(),
        post_json(
            "/api/v1/auth/login",
            login_body(&format!("  {}  ", login.to_uppercase()), PASSWORD),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let access = body["data"]["access_token"].as_str().unwrap().to_owned();
    let refresh = body["data"]["refresh_token"].as_str().unwrap().to_owned();

    let (status, _, me) = common::send(app.clone(), get("/api/v1/me", &access)).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(me["data"]["display_name"], "登录用户");

    let (status, _, body) = common::send(
        app.clone(),
        post_json("/api/v1/auth/refresh", json!({ "refresh_token": refresh })),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let next_access = body["data"]["access_token"].as_str().unwrap().to_owned();

    let (status, _, me) = common::send(app, get("/api/v1/me", &next_access)).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(me["data"]["display_name"], "登录用户");
}

#[tokio::test]
async fn invalid_credentials_share_one_response_for_every_failure_reason() {
    let (config, pool) = setup().await;
    let activated_login = unique_login("activated");
    let token_value = create_invitation(&pool, &activated_login, "已激活").await;
    let app = router(&config, &pool);

    let (status, _, _) = common::send(
        app.clone(),
        post_json(
            "/api/v1/auth/activate",
            json!({ "invite_token": token_value, "password": PASSWORD }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    let legacy_login = unique_login("legacy");
    create_user(&pool, &legacy_login, None, false).await;
    let disabled_login = unique_login("disabled");
    create_user(
        &pool,
        &disabled_login,
        Some(password::hash(PASSWORD).expect("password is hashed")),
        true,
    )
    .await;
    let unknown_login = unique_login("unknown");

    let probes = [
        (activated_login.as_str(), "definitely wrong password"),
        (legacy_login.as_str(), PASSWORD),
        (disabled_login.as_str(), PASSWORD),
        (unknown_login.as_str(), PASSWORD),
    ];
    let mut reference: Option<Value> = None;
    for (index, (login, password_value)) in probes.iter().enumerate() {
        let (status, headers, body) = common::send(
            app.clone(),
            post_json_with_request_id(
                "/api/v1/auth/login",
                login_body(login, password_value),
                "enumeration-probe",
            ),
        )
        .await;
        assert_eq!(status, StatusCode::UNAUTHORIZED, "probe {index}");
        assert_eq!(body["error"]["code"], "INVALID_CREDENTIALS");
        assert_eq!(
            body["error"]["message"],
            "The login or password is invalid."
        );
        assert_eq!(body["error"]["retryable"], false);
        assert_eq!(body["error"]["fields"], json!([]));
        assert_eq!(headers.get(header::WWW_AUTHENTICATE).unwrap(), "Bearer");
        match &reference {
            Some(reference) => assert_eq!(&body, reference, "probe {index} body differs"),
            None => reference = Some(body),
        }
    }
}

#[tokio::test]
async fn five_failed_attempts_lock_the_account_even_for_the_correct_password() {
    let (config, pool) = setup().await;
    let login = unique_login("locked");
    create_user(
        &pool,
        &login,
        Some(password::hash(PASSWORD).expect("password is hashed")),
        false,
    )
    .await;
    let app = router(&config, &pool);

    for attempt in 1..=login::MAX_FAILURES {
        let (status, _, body) = common::send(
            app.clone(),
            post_json(
                "/api/v1/auth/login",
                login_body(&login, "definitely wrong password"),
            ),
        )
        .await;
        assert_eq!(status, StatusCode::UNAUTHORIZED, "attempt {attempt}");
        assert_eq!(body["error"]["code"], "INVALID_CREDENTIALS");
    }

    let (status, headers, body) = common::send(
        app.clone(),
        post_json("/api/v1/auth/login", login_body(&login, PASSWORD)),
    )
    .await;
    assert_eq!(status, StatusCode::TOO_MANY_REQUESTS);
    assert_eq!(body["error"]["code"], "RATE_LIMITED");
    assert_eq!(body["error"]["retryable"], true);
    let retry_after = headers
        .get(header::RETRY_AFTER)
        .and_then(|value| value.to_str().ok())
        .expect("Retry-After is present")
        .parse::<u64>()
        .expect("Retry-After is a number");
    assert!((1..=900).contains(&retry_after));

    let locked: Option<time::OffsetDateTime> =
        sqlx::query_scalar("SELECT locked_until FROM login_attempts WHERE login_hash = $1")
            .bind(token::digest(&login))
            .fetch_one(&pool)
            .await
            .expect("login bucket is readable");
    assert!(locked.is_some());
}

#[tokio::test]
async fn a_successful_login_clears_the_failure_counter() {
    let (config, pool) = setup().await;
    let login = unique_login("recovered");
    create_user(
        &pool,
        &login,
        Some(password::hash(PASSWORD).expect("password is hashed")),
        false,
    )
    .await;
    let app = router(&config, &pool);

    for _ in 0..4 {
        let (status, _, _) = common::send(
            app.clone(),
            post_json(
                "/api/v1/auth/login",
                login_body(&login, "definitely wrong password"),
            ),
        )
        .await;
        assert_eq!(status, StatusCode::UNAUTHORIZED);
    }

    let (status, _, _) = common::send(
        app.clone(),
        post_json("/api/v1/auth/login", login_body(&login, PASSWORD)),
    )
    .await;
    assert_eq!(status, StatusCode::OK);

    let buckets: i64 =
        sqlx::query_scalar("SELECT count(*) FROM login_attempts WHERE login_hash = $1")
            .bind(token::digest(&login))
            .fetch_one(&pool)
            .await
            .expect("login buckets are readable");
    assert_eq!(buckets, 0);

    let (status, _, _) = common::send(
        app,
        post_json("/api/v1/auth/login", login_body(&login, PASSWORD)),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
}

#[tokio::test]
async fn stale_failure_buckets_are_cleaned_by_a_login_attempt() {
    let (config, pool) = setup().await;
    let stale_hash = token::digest("stale.login.bucket");
    sqlx::query(
        "INSERT INTO login_attempts (login_hash, failures, window_started_at, locked_until)
         VALUES ($1, 5, now() - interval '2 days', now() - interval '2 days')",
    )
    .bind(&stale_hash)
    .execute(&pool)
    .await
    .expect("stale bucket is inserted");
    let app = router(&config, &pool);

    let (status, _, _) = common::send(
        app,
        post_json(
            "/api/v1/auth/login",
            login_body(&unique_login("cleanup"), PASSWORD),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);

    let stale: i64 =
        sqlx::query_scalar("SELECT count(*) FROM login_attempts WHERE login_hash = $1")
            .bind(&stale_hash)
            .fetch_one(&pool)
            .await
            .expect("login buckets are readable");
    assert_eq!(stale, 0);
}

#[tokio::test]
async fn activation_login_validation_and_content_type_are_enforced() {
    let (config, pool) = setup().await;
    let short_password_login = unique_login("shortpw");
    let short_password_token = create_invitation(&pool, &short_password_login, "短密码").await;
    let matching_login = unique_login("matching");
    let matching_token = create_invitation(&pool, &matching_login, "密码同名").await;
    let app = router(&config, &pool);

    let (status, _, body) = common::send(
        app.clone(),
        post_json(
            "/api/v1/auth/activate",
            json!({ "invite_token": short_password_token, "password": "too-short" }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(body["error"]["code"], "VALIDATION_FAILED");
    assert_eq!(body["error"]["fields"][0]["path"], "password");
    assert_eq!(body["error"]["fields"][0]["code"], "too_short");

    let (status, _, body) = common::send(
        app.clone(),
        post_json(
            "/api/v1/auth/activate",
            json!({ "invite_token": matching_token, "password": matching_login }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(body["error"]["fields"][0]["path"], "password");
    assert_eq!(body["error"]["fields"][0]["code"], "matches_login");

    let (status, _, body) = common::send(
        app.clone(),
        post_json(
            "/api/v1/auth/activate",
            json!({ "invite_token": "inv_unknown", "password": PASSWORD, "extra": true }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(body["error"]["code"], "INVALID_REQUEST_BODY");

    let (status, _, body) = common::send(
        app.clone(),
        post_json(
            "/api/v1/auth/activate",
            json!({ "invite_token": "   ", "password": PASSWORD }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(body["error"]["fields"][0]["path"], "invite_token");
    assert_eq!(body["error"]["fields"][0]["code"], "required");

    let (status, _, body) = common::send(
        app.clone(),
        post_json("/api/v1/auth/login", login_body("bad login", PASSWORD)),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(body["error"]["code"], "VALIDATION_FAILED");
    assert_eq!(body["error"]["fields"][0]["path"], "login");
    assert_eq!(body["error"]["fields"][0]["code"], "invalid_format");

    let (status, _, body) = common::send(
        app.clone(),
        post_json(
            "/api/v1/auth/login",
            json!({ "login": "short", "password": PASSWORD, "extra": true }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(body["error"]["code"], "INVALID_REQUEST_BODY");

    let request = Request::builder()
        .method(Method::POST)
        .uri("/api/v1/auth/activate")
        .body(Body::from(
            json!({ "invite_token": "inv_x", "password": PASSWORD }).to_string(),
        ))
        .unwrap();
    let (status, _, body) = common::send(app, request).await;
    assert_eq!(status, StatusCode::UNSUPPORTED_MEDIA_TYPE);
    assert_eq!(body["error"]["code"], "UNSUPPORTED_MEDIA_TYPE");
}

#[tokio::test]
async fn invitation_creation_rejects_taken_logins_and_active_invitations() {
    let (_config, pool) = setup().await;
    let taken = unique_login("taken");
    create_user(&pool, &taken, None, false).await;
    assert!(matches!(
        invite::create(&pool, &taken, "已存在", Duration::hours(1)).await,
        Err(CreateError::LoginExists)
    ));

    let active = unique_login("active");
    invite::create(&pool, &active, "活跃邀请", Duration::hours(1))
        .await
        .expect("first invitation is created");
    assert!(matches!(
        invite::create(&pool, &active, "活跃邀请", Duration::hours(1)).await,
        Err(CreateError::ActiveInvitation)
    ));

    let expired = unique_login("reissue");
    invite::create(&pool, &expired, "过期重发", Duration::hours(1))
        .await
        .expect("invitation is created");
    sqlx::query("UPDATE invites SET expires_at = now() - interval '1 second' WHERE login = $1")
        .bind(&expired)
        .execute(&pool)
        .await
        .expect("invitation expiry is moved into the past");
    invite::create(&pool, &expired, "过期重发", Duration::hours(1))
        .await
        .expect("an expired invitation does not block a new one");
}
