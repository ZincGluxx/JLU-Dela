#[cfg(feature = "integration")]
mod common;

use jlu_dela_api::auth::student::{StudentReportError, StudentReportRequest, StudentVerifier};
use serde_json::json;
use sqlx::postgres::PgPoolOptions;
use uuid::Uuid;

#[test]
fn clients_can_supply_only_a_report_code() {
    assert!(
        serde_json::from_value::<StudentReportRequest>(json!({
            "report_code": "A1234567890ABCDE"
        }))
        .is_ok()
    );
    for field in [
        "url",
        "school",
        "student_number",
        "college",
        "student_verified",
    ] {
        let mut request = json!({ "report_code": "A1234567890ABCDE" });
        request[field] = json!("untrusted");
        assert!(
            serde_json::from_value::<StudentReportRequest>(request).is_err(),
            "{field}"
        );
    }
}

#[tokio::test]
async fn invalid_codes_do_not_use_the_network_or_database() {
    let pool = PgPoolOptions::new()
        .connect_lazy("postgres://unused:unused@127.0.0.1:1/unused")
        .unwrap();
    let verifier = StudentVerifier::new().unwrap();
    for code in [
        "",
        "https://127.0.0.1/report",
        "X1234567890ABC&x",
        "A1234567890abcde",
    ] {
        let result = verifier.verify_and_bind(&pool, Uuid::new_v4(), code).await;
        assert!(matches!(result, Err(StudentReportError::Invalid)));
    }
}

#[cfg(feature = "integration")]
mod postgres {
    use super::*;
    use jlu_dela_api::auth::student::load_identity;
    use sqlx::PgPool;
    async fn user(pool: &PgPool) -> Uuid {
        let id = Uuid::new_v4();
        sqlx::query("INSERT INTO users (id,login,display_name,timezone,created_at) VALUES ($1,$2,'test','Asia/Shanghai',now())")
            .bind(id).bind(id.to_string()).execute(pool).await.unwrap();
        id
    }

    async fn report(
        pool: &PgPool,
        id: Uuid,
        college: Option<(&str, &str)>,
    ) -> Result<(), sqlx::Error> {
        sqlx::query("INSERT INTO student_reports (user_id,school,source,verified_at,college_name,college_source_field) VALUES ($1,'吉林大学','chsi',now(),$2,$3)")
            .bind(id).bind(college.map(|(name, _)| name)).bind(college.map(|(_, field)| field))
            .execute(pool).await.map(|_| ())
    }
    #[sqlx::test(migrations = "./migrations")]
    async fn authenticated_identity_and_permissions_follow_current_account_and_report(
        pool: PgPool,
    ) {
        use axum::{
            extract::FromRequestParts,
            http::{Request, StatusCode, header},
        };
        use jlu_dela_api::{
            auth::{AuthenticatedUser, session},
            error::AppError,
            http,
            state::AppState,
        };

        let no_college = user(&pool).await;
        let college_a = user(&pool).await;
        let college_b = user(&pool).await;
        let unverified = user(&pool).await;
        report(&pool, no_college, None).await.unwrap();
        report(&pool, college_a, Some(("测试学院甲", "测试学院字段")))
            .await
            .unwrap();
        report(&pool, college_b, Some(("测试学院乙", "测试学院字段")))
            .await
            .unwrap();
        let college_a_id = load_identity(&pool, college_a)
            .await
            .unwrap()
            .college
            .unwrap()
            .id;
        let college_b_id = load_identity(&pool, college_b)
            .await
            .unwrap()
            .college
            .unwrap()
            .id;
        assert_ne!(college_a_id, college_b_id);

        let config = common::config(&[]);
        let state = AppState::new(pool.clone(), config.build_id.clone());
        let app = http::router(state.clone(), &config);
        let mut college_a_token = String::new();
        for (id, verified, own_college) in [
            (no_college, true, None),
            (college_a, true, Some(college_a_id.as_str())),
            (college_b, true, Some(college_b_id.as_str())),
            (unverified, false, None),
        ] {
            let issued = session::issue_for_user(&pool, id).await.unwrap();
            if id == college_a {
                college_a_token = issued.access_token.clone();
            }
            let session = session::authenticate(&pool, &issued.access_token)
                .await
                .unwrap();
            assert_eq!(session.user_id, id);
            assert_eq!(session.student_verified, verified);
            assert_eq!(
                session.college.as_ref().map(|college| college.id.as_str()),
                own_college
            );

            let request = Request::builder()
                .uri("/api/v1/me")
                .header(
                    header::AUTHORIZATION,
                    format!("Bearer {}", issued.access_token),
                )
                .body(())
                .unwrap();
            let (mut parts, ()) = request.into_parts();
            let user = AuthenticatedUser::from_request_parts(&mut parts, &state)
                .await
                .unwrap_or_else(|_| panic!("valid session authenticates"));
            assert_eq!(user.user_id, id);
            if verified {
                user.require_student().unwrap();
                if let Some(own_college) = own_college {
                    user.require_college(own_college).unwrap();
                }
                let other_college = if id == college_a {
                    &college_b_id
                } else {
                    &college_a_id
                };
                assert!(matches!(
                    user.require_college(other_college),
                    Err(AppError::CollegeRequired)
                ));
            } else {
                assert!(matches!(
                    user.require_student(),
                    Err(AppError::StudentRequired)
                ));
                assert!(matches!(
                    user.require_college(&college_a_id),
                    Err(AppError::StudentRequired)
                ));
            }

            let request = Request::builder()
                .uri("/api/v1/me")
                .header(
                    header::AUTHORIZATION,
                    format!("Bearer {}", issued.access_token),
                )
                .body(axum::body::Body::empty())
                .unwrap();
            let (status, _, body) = common::send(app.clone(), request).await;
            assert_eq!(status, StatusCode::OK);
            assert_eq!(body["data"]["id"], id.to_string());
            assert_eq!(body["data"]["student_verified"], verified);
            match own_college {
                Some(college) => assert_eq!(body["data"]["college"]["id"], college),
                None => assert!(body["data"]["college"].is_null()),
            }
        }

        sqlx::query("UPDATE student_reports SET verified_at = now() - interval '10 years' WHERE user_id = $1")
            .bind(college_a).execute(&pool).await.unwrap();
        let retained = session::authenticate(&pool, &college_a_token)
            .await
            .unwrap();
        assert!(retained.student_verified);
        assert_eq!(retained.college.unwrap().id, college_a_id);
        let request = Request::builder()
            .uri("/api/v1/me")
            .header(header::AUTHORIZATION, format!("Bearer {college_a_token}"))
            .body(axum::body::Body::empty())
            .unwrap();
        let (status, _, body) = common::send(app, request).await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body["data"]["student_verified"], true);
        assert_eq!(body["data"]["college"]["id"], college_a_id);
    }

    #[sqlx::test(migrations = "./migrations")]
    async fn storage_is_minimal_and_has_no_student_or_expiry_columns(pool: PgPool) {
        let first = user(&pool).await;
        let second = user(&pool).await;
        report(&pool, first, Some(("测试学院", "分院")))
            .await
            .unwrap();
        report(&pool, second, Some(("测试学院", "分院")))
            .await
            .unwrap();
        assert_eq!(
            load_identity(&pool, first)
                .await
                .unwrap()
                .college
                .unwrap()
                .id,
            load_identity(&pool, second)
                .await
                .unwrap()
                .college
                .unwrap()
                .id
        );
        let columns: Vec<String> = sqlx::query_scalar("SELECT column_name FROM information_schema.columns WHERE table_name = 'student_reports' ORDER BY ordinal_position")
            .fetch_all(&pool).await.unwrap();
        assert_eq!(
            columns,
            [
                "user_id",
                "school",
                "source",
                "verified_at",
                "college_name",
                "college_source_field"
            ]
        );
    }

    #[ignore = "requires explicitly supplied real official report"]
    #[sqlx::test(migrations = "./migrations")]
    async fn real_official_report_verifies_persisted_identity_session_and_me(pool: PgPool) {
        use axum::http::{Request, StatusCode, header};
        use jlu_dela_api::{auth::session, http, state::AppState};
        let code = std::env::var("CHSI_REPORT_CODE")
            .expect("CHSI_REPORT_CODE must be supplied explicitly");
        let id = user(&pool).await;
        let issued = session::issue_for_user(&pool, id).await.unwrap();
        let config = common::config(&[]);
        let app = http::router(
            AppState::new(pool.clone(), config.build_id.clone()),
            &config,
        );
        let request = Request::builder()
            .method("POST")
            .uri("/api/v1/me/student-verification")
            .header(
                header::AUTHORIZATION,
                format!("Bearer {}", issued.access_token),
            )
            .header(header::CONTENT_TYPE, "application/json")
            .body(axum::body::Body::from(
                json!({"report_code": code}).to_string(),
            ))
            .unwrap();
        let (status, _, result) = common::send(app.clone(), request).await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(result["data"]["student_verified"], true);
        assert_eq!(result["data"]["id"], id.to_string());
        let stored = load_identity(&pool, id).await.unwrap();
        assert!(stored.student_verified);
        assert!(
            stored
                .college
                .as_ref()
                .map(|college| !college.id.is_empty() && !college.name.is_empty())
                .unwrap_or(true)
        );
        assert!(
            session::authenticate(&pool, &issued.access_token)
                .await
                .unwrap()
                .student_verified
        );
        let request = Request::builder()
            .uri("/api/v1/me")
            .header(
                header::AUTHORIZATION,
                format!("Bearer {}", issued.access_token),
            )
            .body(axum::body::Body::empty())
            .unwrap();
        let (status, _, body) = common::send(app, request).await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body["data"]["student_verified"], true);
        assert_eq!(body["data"]["college"].is_null(), stored.college.is_none());
        assert_eq!(body["data"], result["data"]);
        let columns: Vec<String> = sqlx::query_scalar("SELECT column_name FROM information_schema.columns WHERE table_name = 'student_reports' ORDER BY ordinal_position")
            .fetch_all(&pool).await.unwrap();
        assert!(
            !columns
                .iter()
                .any(|name| matches!(name.as_str(), "report_code" | "name" | "birthday" | "photo"))
        );
    }
}
