#[cfg(feature = "integration")]
mod common;

use jlu_dela_api::{
    auth::{account, password, phone},
    error::AppError,
};

#[test]
fn mainland_phone_normalization_is_explicit() {
    assert_eq!(phone::normalize("13800138000").unwrap(), "+8613800138000");
    assert_eq!(
        phone::normalize(" +8613800138000 ").unwrap(),
        "+8613800138000"
    );
    for invalid in [
        "8613800138000",
        "+1 13800138000",
        "138-0013-8000",
        "12800138000",
        "1380013800",
        "１３８００１３８０００",
        "",
    ] {
        assert!(phone::normalize(invalid).is_err(), "{invalid}");
    }
}

#[test]
fn username_is_lowercase_ascii_without_implicit_normalization() {
    for valid in ["abcdef", "abc123", "0123456789"] {
        assert!(account::validate_username(valid).is_ok());
    }
    for invalid in [
        "abcde",
        "abcdefghijk",
        "Abc123",
        "abc_123",
        " abc123",
        "用户123456",
        "abc123\n",
        "abc123 ",
    ] {
        assert!(account::validate_username(invalid).is_err());
    }
}

#[test]
fn new_password_counts_unicode_scalars_and_requires_ascii_categories() {
    for valid in [
        "Abcdefg1",
        "Abcdefghijklmno1",
        "Aa1😀😀😀😀😀",
        "Aa1ééééé",
        "Abc123!@",
        " Abc1234 ",
    ] {
        assert!(password::validate_new(valid).is_ok(), "{valid}");
    }
    for invalid in [
        "Aa12345",
        "Aa123456789012345",
        "abcdefgh",
        "ABCDEFG1",
        "abcdefg1",
        "Abcdefgh",
        "Ａａ１２３４５６",
        "Aa1😀😀😀😀",
    ] {
        assert!(password::validate_new(invalid).is_err(), "{invalid}");
    }
    assert!(password::validate_attempt(&"x".repeat(128)).is_ok());
    assert!(password::validate_attempt(&"😀".repeat(128)).is_ok());
    assert!(password::validate_attempt(&"x".repeat(129)).is_err());
    assert!(password::validate_attempt("legacy long password without uppercase or digit").is_ok());
}

#[tokio::test]
async fn password_hashing_preserves_whitespace_case_and_unicode() {
    let password = " Abc123😀 ";
    password::validate_new(password).unwrap();
    let encoded = password::hash_async(password).await.unwrap();
    assert!(password::verify_async(password, &encoded).await);
    for changed in [
        password.trim().to_owned(),
        password.to_lowercase(),
        " Abc123 ".to_owned(),
    ] {
        assert!(!password::verify_async(&changed, &encoded).await);
    }
}

#[cfg(debug_assertions)]
#[tokio::test]
async fn development_sender_is_explicitly_not_real_sms_delivery() {
    use phone::SmsSender;
    let config = jlu_dela_api::config::Config::from_variables([
        ("DATABASE_URL", "postgres://test@127.0.0.1/test"),
        ("DEV_SMS_FIXED_CODE_ENABLED", "true"),
    ])
    .unwrap();
    let sender = phone::configured_sender(&config);
    assert!(sender.dev_mode());
    sender
        .send("not-a-network-destination", "not-transmitted")
        .await
        .unwrap();
    assert!(!phone::UnavailableSmsSender.dev_mode());
}

#[tokio::test]
async fn unavailable_sender_does_not_claim_delivery() {
    use phone::SmsSender;
    assert!(matches!(
        phone::UnavailableSmsSender
            .send("+8613800138000", "123456")
            .await,
        Err(AppError::SmsUnavailable)
    ));
}

#[cfg(feature = "integration")]
mod postgres {
    use super::*;
    use axum::{
        body::Body,
        http::{Request, StatusCode},
    };
    use jlu_dela_api::{http, state::AppState};
    use serde_json::{Value, json};
    use sqlx::PgPool;
    use std::sync::{Arc, Mutex};
    use uuid::Uuid;

    #[derive(Default)]
    struct TestSender(Mutex<Vec<(String, String)>>);

    impl phone::SmsSender for TestSender {
        fn send<'a>(&'a self, phone: &'a str, code: &'a str) -> phone::SendFuture<'a> {
            Box::pin(async move {
                self.0
                    .lock()
                    .unwrap()
                    .push((phone.to_owned(), code.to_owned()));
                Ok(())
            })
        }
    }

    #[cfg(debug_assertions)]
    #[tokio::test]
    async fn fixed_development_code_uses_real_expiry_consumption_and_limits_without_delivery() {
        let pool = pool().await;
        let config = super::common::config(&[("DEV_SMS_FIXED_CODE_ENABLED", "true")]);
        let state = AppState::from_config(pool.clone(), &config);
        assert!(state.sms_sender.dev_mode());
        let phone = unique_phone();
        phone::request_code(&pool, state.sms_sender.as_ref(), &phone)
            .await
            .unwrap();
        let hash: String =
            sqlx::query_scalar("SELECT code_hash FROM phone_verification_codes WHERE phone = $1")
                .bind(&phone)
                .fetch_one(&pool)
                .await
                .unwrap();
        assert!(password::verify_async("114514", &hash).await);
        assert_ne!(hash, "114514");
        assert!(matches!(
            phone::request_code(&pool, state.sms_sender.as_ref(), &phone).await,
            Err(AppError::RateLimited { .. })
        ));
        phone::authenticate(&pool, &phone, "114514").await.unwrap();
        assert!(matches!(
            phone::authenticate(&pool, &phone, "114514").await,
            Err(AppError::InvalidSmsCode)
        ));
        resend(&pool, &phone).await;
        phone::request_code(&pool, state.sms_sender.as_ref(), &phone)
            .await
            .unwrap();
        sqlx::query("UPDATE phone_verification_codes SET expires_at = now() - interval '1 second' WHERE phone = $1").bind(&phone).execute(&pool).await.unwrap();
        assert!(matches!(
            phone::authenticate(&pool, &phone, "114514").await,
            Err(AppError::SmsCodeExpired)
        ));
        resend(&pool, &phone).await;
        phone::request_code(&pool, state.sms_sender.as_ref(), &phone)
            .await
            .unwrap();
        for _ in 0..5 {
            assert!(matches!(
                phone::authenticate(&pool, &phone, "000000").await,
                Err(AppError::InvalidSmsCode)
            ));
        }
        assert!(matches!(
            phone::authenticate(&pool, &phone, "114514").await,
            Err(AppError::InvalidSmsCode)
        ));
        sqlx::query("UPDATE phone_verification_codes SET sent_at = now() - interval '61 seconds', send_attempts = 10 WHERE phone = $1").bind(&phone).execute(&pool).await.unwrap();
        assert!(matches!(
            phone::request_code(&pool, state.sms_sender.as_ref(), &phone).await,
            Err(AppError::RateLimited { .. })
        ));
    }

    struct FailedSender;
    impl phone::SmsSender for FailedSender {
        fn send<'a>(&'a self, _phone: &'a str, _code: &'a str) -> phone::SendFuture<'a> {
            Box::pin(async { Err(AppError::SmsSendFailed) })
        }
    }

    fn request(method: &str, path: &str, body: Value, access: Option<&str>) -> Request<Body> {
        let mut request = Request::builder()
            .method(method)
            .uri(path)
            .header("content-type", "application/json");
        if let Some(access) = access {
            request = request.header("authorization", format!("Bearer {access}"));
        }
        request.body(Body::from(body.to_string())).unwrap()
    }

    #[cfg(debug_assertions)]
    #[tokio::test]
    async fn local_development_phone_route_identifies_no_delivery_mode() {
        let pool = pool().await;
        let config = super::common::config(&[
            ("DEV_SMS_FIXED_CODE_ENABLED", "true"),
            ("REQUEST_TIMEOUT_SECONDS", "15"),
        ]);
        let app = http::router(AppState::from_config(pool, &config), &config);
        let phone = unique_phone();
        let (status, _, sent) = super::common::send(
            app.clone(),
            request(
                "POST",
                "/api/v1/auth/phone/code",
                json!({"phone":phone}),
                None,
            ),
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(
            sent["data"],
            json!({"expires_in":300,"retry_after":60,"dev_mode":true})
        );
        let (status, _, login) = super::common::send(
            app,
            request(
                "POST",
                "/api/v1/auth/phone/login",
                json!({"phone":phone,"sms_code":"114514"}),
                None,
            ),
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        assert!(
            login["data"]["access_token"]
                .as_str()
                .unwrap()
                .starts_with("at_")
        );
    }

    #[tokio::test]
    async fn phone_routes_and_account_settings_preserve_identity_boundaries() {
        let pool = pool().await;
        let sender = Arc::new(TestSender::default());
        let config = super::common::config(&[("REQUEST_TIMEOUT_SECONDS", "15")]);
        let mut state = AppState::new(pool.clone(), config.build_id.clone());
        state.sms_sender = sender.clone();
        let app = http::router(state, &config);
        let phone = unique_phone();
        let (status, _, sent) = super::common::send(
            app.clone(),
            request(
                "POST",
                "/api/v1/auth/phone/code",
                json!({"phone":phone}),
                None,
            ),
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(
            sent["data"],
            json!({"expires_in":300,"retry_after":60,"dev_mode":false})
        );
        let code = sender.0.lock().unwrap()[0].1.clone();
        let (status, _, login) = super::common::send(
            app.clone(),
            request(
                "POST",
                "/api/v1/auth/phone/login",
                json!({"phone":phone,"sms_code":code}),
                None,
            ),
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(login["data"]["token_type"], "Bearer");
        assert_eq!(login["data"]["expires_in"], 900);
        assert!(
            login["data"]["refresh_token"]
                .as_str()
                .unwrap()
                .starts_with("rt_")
        );
        let access = login["data"]["access_token"].as_str().unwrap();
        let (status, _, me) = super::common::send(
            app.clone(),
            request("GET", "/api/v1/me", Value::Null, Some(access)),
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        assert!(me["data"]["username"].is_null());
        assert_eq!(me["data"]["password_set"], false);
        assert_eq!(me["data"]["student_verified"], false);
        assert!(me["data"]["college"].is_null());
        assert!(me["data"].get("phone").is_none());
        for forbidden in [
            json!({"student_verified":true}),
            json!({"college":{"id":"fake","name":"伪造"}}),
            json!({"phone":unique_phone()}),
            json!({"username":null}),
            json!({"display_name":null}),
            json!({"password":null}),
        ] {
            let (status, _, body) = super::common::send(
                app.clone(),
                request("PATCH", "/api/v1/me/account", forbidden, Some(access)),
            )
            .await;
            assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
            assert_eq!(body["error"]["code"], "INVALID_REQUEST_BODY");
        }
        let username = format!("u{}", &Uuid::new_v4().simple().to_string()[..8]);
        let (status, _, updated) = super::common::send(
            app.clone(),
            request(
                "PATCH",
                "/api/v1/me/account",
                json!({"username":username,"display_name":"独立展示名","password":"Password123"}),
                Some(access),
            ),
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(updated["data"]["username"], username);
        assert_eq!(updated["data"]["display_name"], "独立展示名");
        assert_eq!(updated["data"]["password_set"], true);
        assert_eq!(updated["data"]["student_verified"], false);
        assert!(updated["data"].get("phone").is_none());
        let (status, _, refreshed) = super::common::send(
            app.clone(),
            request("GET", "/api/v1/me", Value::Null, Some(access)),
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(refreshed["data"], updated["data"]);
        let (status, _, _) = super::common::send(
            app.clone(),
            request(
                "POST",
                "/api/v1/auth/login",
                json!({"login":username,"password":"Password123"}),
                None,
            ),
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        let taken = format!("u{}", &Uuid::new_v4().simple().to_string()[..8]);
        sqlx::query("INSERT INTO users (id, login, display_name, timezone, created_at) VALUES ($1,$2,'其他','Asia/Shanghai',now())").bind(Uuid::new_v4()).bind(&taken).execute(&pool).await.unwrap();
        let (status, _, conflict) = super::common::send(
            app,
            request(
                "PATCH",
                "/api/v1/me/account",
                json!({"username":taken}),
                Some(access),
            ),
        )
        .await;
        assert_eq!(status, StatusCode::CONFLICT);
        assert_eq!(conflict["error"]["code"], "USERNAME_TAKEN");
        assert_eq!(conflict["error"]["message"], "用户名已被使用，请更换");
        assert_eq!(
            conflict["error"]["fields"],
            json!([{"path":"username","code":"already_used"}])
        );
        assert!(
            conflict["error"]["message"]
                .as_str()
                .is_some_and(|message| !message.is_empty())
        );
    }

    #[tokio::test]
    async fn production_default_phone_route_reports_sms_unavailable() {
        let pool = pool().await;
        let config = super::common::config(&[("REQUEST_TIMEOUT_SECONDS", "15")]);
        let app = http::router(AppState::new(pool, config.build_id.clone()), &config);
        let (status, _, body) = super::common::send(
            app,
            request(
                "POST",
                "/api/v1/auth/phone/code",
                json!({"phone":unique_phone()}),
                None,
            ),
        )
        .await;
        assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
        assert_eq!(body["error"]["code"], "SMS_UNAVAILABLE");
        assert!(body.get("data").is_none());
    }

    struct HangingSender;
    impl phone::SmsSender for HangingSender {
        fn send<'a>(&'a self, _phone: &'a str, _code: &'a str) -> phone::SendFuture<'a> {
            Box::pin(std::future::pending())
        }
    }

    #[tokio::test]
    async fn sender_timeout_persists_failed_delivery_and_cooldown() {
        let pool = pool().await;
        let phone = unique_phone();
        assert!(matches!(
            phone::request_code(&pool, &HangingSender, &phone).await,
            Err(AppError::SmsSendFailed)
        ));
        let state: (i32, bool) = sqlx::query_as(
            "SELECT send_attempts, consumed_at IS NOT NULL FROM phone_verification_codes WHERE phone = $1",
        )
        .bind(&phone)
        .fetch_one(&pool)
        .await
        .unwrap();
        assert_eq!(state, (1, true));
        assert!(matches!(
            phone::request_code(&pool, &TestSender::default(), &phone).await,
            Err(AppError::RateLimited { .. })
        ));
        assert!(matches!(
            phone::authenticate(&pool, &phone, "123456").await,
            Err(AppError::InvalidSmsCode)
        ));
    }

    async fn pool() -> PgPool {
        let pool = PgPool::connect(
            &std::env::var("DATABASE_URL").expect("isolated DATABASE_URL required"),
        )
        .await
        .unwrap();
        jlu_dela_api::db::run_migrations(&pool).await.unwrap();
        pool
    }

    fn unique_phone() -> String {
        let bytes = Uuid::new_v4().as_u128();
        format!("+86139{:08}", bytes % 100_000_000)
    }

    async fn resend(pool: &PgPool, phone: &str) {
        sqlx::query("UPDATE phone_verification_codes SET sent_at = now() - interval '61 seconds' WHERE phone = $1").bind(phone).execute(pool).await.unwrap();
    }

    #[tokio::test]
    async fn sms_login_creates_no_fake_login_and_reuses_the_same_account() {
        let pool = pool().await;
        let sender = TestSender::default();
        let phone = unique_phone();
        phone::request_code(&pool, &sender, &phone).await.unwrap();
        let code = sender.0.lock().unwrap()[0].1.clone();
        assert_eq!(code.len(), 6);
        let hash: String =
            sqlx::query_scalar("SELECT code_hash FROM phone_verification_codes WHERE phone = $1")
                .bind(&phone)
                .fetch_one(&pool)
                .await
                .unwrap();
        assert!(hash.starts_with("$argon2id$"));
        assert_ne!(hash, code);
        let issued = phone::authenticate(&pool, &phone, &code).await.unwrap();
        let user = jlu_dela_api::auth::session::authenticate(&pool, &issued.access_token)
            .await
            .unwrap();
        let account = account::get(&pool, user.user_id).await.unwrap();
        assert!(account.username.is_none());
        assert!(!account.password_set);
        assert!(!user.student_verified);
        assert!(user.college.is_none());
        assert!(matches!(
            phone::authenticate(&pool, &phone, &code).await,
            Err(AppError::InvalidSmsCode)
        ));
        resend(&pool, &phone).await;
        phone::request_code(&pool, &sender, &phone).await.unwrap();
        let code = sender.0.lock().unwrap()[1].1.clone();
        let issued = phone::authenticate(&pool, &phone, &code).await.unwrap();
        let repeated = jlu_dela_api::auth::session::authenticate(&pool, &issued.access_token)
            .await
            .unwrap();
        assert_eq!(user.user_id, repeated.user_id);
        let username = format!("u{}", &Uuid::new_v4().simple().to_string()[..8]);
        let updated = account::update(
            &pool,
            user.user_id,
            Some(&username),
            Some("独立昵称"),
            Some("Password123"),
        )
        .await
        .unwrap();
        assert_eq!(updated.username.as_deref(), Some(username.as_str()));
        assert_eq!(updated.display_name, "独立昵称");
        assert!(updated.password_set);
        assert!(
            jlu_dela_api::auth::login::authenticate(&pool, &username, "Password123")
                .await
                .is_ok()
        );
        let other_id = Uuid::new_v4();
        sqlx::query("INSERT INTO users (id, display_name, timezone, created_at) VALUES ($1, '其他', 'Asia/Shanghai', now())").bind(other_id).execute(&pool).await.unwrap();
        assert!(matches!(
            account::update(&pool, other_id, Some(&username), None, None).await,
            Err(AppError::UsernameTaken)
        ));
        assert!(
            account::get(&pool, other_id)
                .await
                .unwrap()
                .username
                .is_none()
        );
    }

    #[tokio::test]
    async fn cooldown_expiry_attempt_limit_and_send_failures_are_persistent() {
        let pool = pool().await;
        let sender = TestSender::default();
        let phone = unique_phone();
        phone::request_code(&pool, &sender, &phone).await.unwrap();
        assert!(matches!(
            phone::request_code(&pool, &sender, &phone).await,
            Err(AppError::RateLimited { .. })
        ));
        let code = sender.0.lock().unwrap()[0].1.clone();
        let wrong = if code == "000000" { "111111" } else { "000000" };
        for _ in 0..5 {
            assert!(matches!(
                phone::authenticate(&pool, &phone, wrong).await,
                Err(AppError::InvalidSmsCode)
            ));
        }
        assert!(matches!(
            phone::authenticate(&pool, &phone, &code).await,
            Err(AppError::InvalidSmsCode)
        ));
        resend(&pool, &phone).await;
        phone::request_code(&pool, &sender, &phone).await.unwrap();
        let code = sender.0.lock().unwrap()[1].1.clone();
        sqlx::query("UPDATE phone_verification_codes SET expires_at = now() - interval '1 second' WHERE phone = $1").bind(&phone).execute(&pool).await.unwrap();
        assert!(matches!(
            phone::authenticate(&pool, &phone, &code).await,
            Err(AppError::SmsCodeExpired)
        ));
        resend(&pool, &phone).await;
        assert!(matches!(
            phone::request_code(&pool, &FailedSender, &phone).await,
            Err(AppError::SmsSendFailed)
        ));
        assert!(matches!(
            phone::request_code(&pool, &sender, &phone).await,
            Err(AppError::RateLimited { .. })
        ));
        assert!(matches!(
            phone::authenticate(&pool, &phone, &code).await,
            Err(AppError::InvalidSmsCode)
        ));
        sqlx::query("UPDATE phone_verification_codes SET sent_at = now() - interval '61 seconds', send_attempts = 10 WHERE phone = $1").bind(&phone).execute(&pool).await.unwrap();
        assert!(matches!(
            phone::request_code(&pool, &sender, &phone).await,
            Err(AppError::RateLimited { .. })
        ));
    }

    #[tokio::test]
    async fn concurrent_code_consumption_issues_only_one_session() {
        let pool = pool().await;
        let sender = TestSender::default();
        let phone = unique_phone();
        phone::request_code(&pool, &sender, &phone).await.unwrap();
        let code = sender.0.lock().unwrap()[0].1.clone();
        let (first, second) = tokio::join!(
            phone::authenticate(&pool, &phone, &code),
            phone::authenticate(&pool, &phone, &code)
        );
        assert_ne!(first.is_ok(), second.is_ok());
        assert!(matches!(
            first.err().or(second.err()),
            Some(AppError::InvalidSmsCode)
        ));
    }

    #[tokio::test]
    async fn legacy_passwords_still_authenticate() {
        let pool = pool().await;
        let username = format!("legacy{}", &Uuid::new_v4().simple().to_string()[..10]);
        let old_password = "correct horse battery staple";
        sqlx::query("INSERT INTO users (id, login, display_name, timezone, password_hash, created_at) VALUES ($1, $2, '旧账号', 'Asia/Shanghai', $3, now())")
            .bind(Uuid::new_v4()).bind(&username).bind(password::hash_async(old_password).await.unwrap()).execute(&pool).await.unwrap();
        assert!(
            jlu_dela_api::auth::login::authenticate(&pool, &username, old_password)
                .await
                .is_ok()
        );
    }
}
