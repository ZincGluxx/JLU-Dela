mod common;

use axum::{
    body::Body,
    http::{Request, StatusCode},
};
use serde_json::Value;

fn seeded_documents() -> Vec<Value> {
    include_str!("../migrations/20261112010000_create_academic_calendars.sql")
        .split("$calendar$")
        .enumerate()
        .filter(|(index, _)| index % 2 == 1)
        .map(|(_, document)| serde_json::from_str(document).expect("seed document is valid JSON"))
        .collect()
}

#[test]
fn verified_seed_preserves_teaching_ranges_periods_and_holiday_boundaries() {
    let documents = seeded_documents();
    assert_eq!(documents.len(), 2);
    for document in &documents {
        assert_eq!(document["includes_makeup_day_rules"], false);
        assert_eq!(document["periods"].as_array().unwrap().len(), 12);
        assert_eq!(document["periods"][9]["start_time"], "19:05");
        assert_eq!(document["periods"][11]["end_time"], "21:30");
        assert_eq!(document["periods_source"]["published_at"], Value::Null);
        for term in document["terms"].as_array().unwrap() {
            let start =
                chrono::NaiveDate::parse_from_str(term["start_date"].as_str().unwrap(), "%Y-%m-%d")
                    .unwrap();
            let end =
                chrono::NaiveDate::parse_from_str(term["end_date"].as_str().unwrap(), "%Y-%m-%d")
                    .unwrap();
            assert_eq!(
                (end - start).num_days() + 1,
                term["teaching_weeks"].as_i64().unwrap() * 7
            );
        }
        let events = document["events"].as_array().unwrap();
        assert_eq!(
            events
                .iter()
                .filter(|event| event["type"] == "holiday")
                .count(),
            7
        );
        for event in events {
            assert!(event["start_date"].as_str().unwrap() <= event["end_date"].as_str().unwrap());
            if event["type"] == "holiday" {
                assert_eq!(event["start_date"], event["end_date"]);
            }
        }
    }
    let current = &documents[0];
    assert_eq!(current["source"]["published_at"], "2026-03-05");
    assert_eq!(current["terms"][0]["start_date"], "2026-09-07");
    let freshman = current["events"]
        .as_array()
        .unwrap()
        .iter()
        .find(|event| event["type"] == "freshman_teaching_start")
        .unwrap();
    assert_eq!(freshman["start_date"], "2026-09-21");
    assert_eq!(documents[1]["terms"][1]["start_date"], "2026-03-09");
}

#[tokio::test]
async fn public_endpoint_reports_database_failure_without_requiring_authentication() {
    let config = common::config(&[]);
    let request = Request::builder()
        .uri("/api/v1/academic-calendar")
        .body(Body::empty())
        .unwrap();
    let (status, headers, body) = common::send(common::router(&config), request).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(body["error"]["code"], "DATABASE_UNAVAILABLE");
    assert_eq!(
        body["error"]["request_id"],
        headers["x-request-id"].to_str().unwrap()
    );
}

#[cfg(feature = "integration")]
#[tokio::test]
async fn public_api_returns_only_stored_documents_and_unknown_year_is_not_found() {
    use jlu_dela_api::{db, http, state::AppState};
    use sqlx::postgres::PgPoolOptions;
    use url::Url;

    let mut url =
        Url::parse(&std::env::var("DATABASE_URL").expect("DATABASE_URL is required")).unwrap();
    url.set_path("/postgres");
    let admin = PgPoolOptions::new()
        .max_connections(1)
        .connect(url.as_str())
        .await
        .unwrap();
    let name = format!("jlu_calendar_test_{}", uuid::Uuid::new_v4().simple());
    sqlx::raw_sql(sqlx::AssertSqlSafe(format!("CREATE DATABASE \"{name}\"")))
        .execute(&admin)
        .await
        .unwrap();
    url.set_path(&format!("/{name}"));
    let config = common::config(&[("DATABASE_URL", url.as_str())]);
    let pool = db::connect(&config).await.unwrap();
    db::run_migrations(&pool).await.unwrap();
    db::run_migrations(&pool).await.unwrap();
    let app = http::router(AppState::new(pool.clone(), "calendar-test"), &config);

    for document in seeded_documents() {
        let year = document["academic_year"].as_str().unwrap();
        let request = Request::builder()
            .uri(format!("/api/v1/academic-calendar?academic_year={year}"))
            .header("x-request-id", "calendar-request")
            .body(Body::empty())
            .unwrap();
        let (status, _, body) = common::send(app.clone(), request).await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body["data"], document);
        assert_eq!(body["meta"]["request_id"], "calendar-request");
    }
    let request = Request::builder()
        .uri("/api/v1/academic-calendar")
        .body(Body::empty())
        .unwrap();
    let (status, _, body) = common::send(app.clone(), request).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["data"]["academic_year"], "2026-2027");

    for year in ["2099-2100", "", "invalid"] {
        let request = Request::builder()
            .uri(format!("/api/v1/academic-calendar?academic_year={year}"))
            .body(Body::empty())
            .unwrap();
        let (status, _, body) = common::send(app.clone(), request).await;
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert_eq!(body["error"]["code"], "ACADEMIC_CALENDAR_NOT_FOUND");
    }

    sqlx::query("UPDATE academic_calendars SET document = jsonb_set(document, '{version}', '\"stored-version\"') WHERE academic_year = '2026-2027'").execute(&pool).await.unwrap();
    let request = Request::builder()
        .uri("/api/v1/academic-calendar")
        .body(Body::empty())
        .unwrap();
    let (_, _, body) = common::send(app.clone(), request).await;
    assert_eq!(body["data"]["version"], "stored-version");
    let request = Request::builder()
        .method("POST")
        .uri("/api/v1/academic-calendar")
        .body(Body::empty())
        .unwrap();
    let (status, _, body) = common::send(app, request).await;
    assert_eq!(status, StatusCode::METHOD_NOT_ALLOWED);
    assert_eq!(body["error"]["code"], "METHOD_NOT_ALLOWED");

    pool.close().await;
    sqlx::raw_sql(sqlx::AssertSqlSafe(format!("DROP DATABASE \"{name}\"")))
        .execute(&admin)
        .await
        .unwrap();
    admin.close().await;
}
