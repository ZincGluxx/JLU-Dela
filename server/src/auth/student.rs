use std::time::Duration;

use reqwest::{Client, redirect::Policy};
use scraper::{Html, Selector};
use sha2::{Digest, Sha256};
use sqlx::PgPool;
use time::OffsetDateTime;
use uuid::Uuid;

use crate::auth::session::College;

const REPORT_URL: &str = "https://www.chsi.com.cn/xlcx/bg.do";
const SCHOOL: &str = "吉林大学";
const SOURCE: &str = "chsi";
const MAX_REPORT_BYTES: usize = 1024 * 1024;

#[derive(serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StudentReportRequest {
    pub report_code: String,
}

#[derive(Debug, PartialEq, Eq)]
pub enum StudentReportError {
    Invalid,
    Restricted,
    ParseFailed,
    NotEligible,
    Unavailable,
    Store,
}

#[derive(Debug)]
pub struct StudentIdentity {
    pub student_verified: bool,
    pub college: Option<College>,
}

pub struct StudentVerifier {
    client: Client,
}

struct ReportFields {
    college: Option<(String, String)>,
}

impl StudentVerifier {
    pub fn new() -> Result<Self, StudentReportError> {
        let client = Client::builder()
            .user_agent("JluDela/0.1 (+https://github.com/ZincGluxx/JLU-Dela)")
            .https_only(true)
            .redirect(Policy::none())
            .connect_timeout(Duration::from_secs(5))
            .timeout(Duration::from_secs(10))
            .referer(false)
            .build()
            .map_err(|_| StudentReportError::Unavailable)?;
        Ok(Self { client })
    }

    pub async fn verify_and_bind(
        &self,
        pool: &PgPool,
        user_id: Uuid,
        report_code: &str,
    ) -> Result<StudentIdentity, StudentReportError> {
        validate_code(report_code)?;
        let mut response = self
            .client
            .post(REPORT_URL)
            .query(&[("vcode", report_code), ("srcid", "bgcx")])
            .send()
            .await
            .map_err(|_| StudentReportError::Unavailable)?;
        if response.status().is_redirection()
            || matches!(response.status().as_u16(), 401 | 403 | 429)
        {
            return Err(StudentReportError::Restricted);
        }
        if !response.status().is_success() {
            return Err(StudentReportError::Unavailable);
        }
        if response
            .content_length()
            .is_some_and(|size| size > MAX_REPORT_BYTES as u64)
        {
            return Err(StudentReportError::ParseFailed);
        }
        let mut body = Vec::new();
        while let Some(chunk) = response
            .chunk()
            .await
            .map_err(|_| StudentReportError::Unavailable)?
        {
            if body.len() + chunk.len() > MAX_REPORT_BYTES {
                return Err(StudentReportError::ParseFailed);
            }
            body.extend_from_slice(&chunk);
        }
        let report = parse_official_report(&body)?;
        bind_report(pool, user_id, report).await?;
        load_identity(pool, user_id).await
    }
}

fn validate_code(code: &str) -> Result<(), StudentReportError> {
    let bytes = code.as_bytes();
    let legacy = bytes.len() == 12 && bytes.iter().all(u8::is_ascii_digit);
    let current = bytes.len() == 16
        && matches!(bytes[0], b'A' | b'X')
        && bytes
            .iter()
            .all(|byte| byte.is_ascii_uppercase() || byte.is_ascii_digit());
    if legacy || current {
        Ok(())
    } else {
        Err(StudentReportError::Invalid)
    }
}

fn parse_official_report(body: &[u8]) -> Result<ReportFields, StudentReportError> {
    let body = std::str::from_utf8(body).map_err(|_| StudentReportError::ParseFailed)?;
    let document = Html::parse_document(body);
    let selector = |value| Selector::parse(value).map_err(|_| StudentReportError::ParseFailed);
    let report_selector = selector("div.zxyz-res.xj-zxyz-res")?;
    let mut reports = document.select(&report_selector);
    let report = reports.next().ok_or(StudentReportError::ParseFailed)?;
    if reports.next().is_some() {
        return Err(StudentReportError::ParseFailed);
    }
    let title_selector = selector(":scope > h4")?;
    let mut titles = report.select(&title_selector);
    let title = titles.next().ok_or(StudentReportError::ParseFailed)?;
    let report_type = title.text().collect::<String>().trim().to_owned();
    if titles.next().is_some() {
        return Err(StudentReportError::ParseFailed);
    }
    if report_type != "教育部学籍在线验证报告" {
        return Err(StudentReportError::NotEligible);
    }
    let item_selector = selector(":scope > div.report-info > div.report-info-item")?;
    let label_selector = selector(":scope > div.label")?;
    let value_selector = selector(":scope > div.value")?;
    let mut school = None;
    let mut college = None;
    let mut college_seen = false;
    for item in report.select(&item_selector) {
        let mut labels = item.select(&label_selector);
        let label = labels.next().ok_or(StudentReportError::ParseFailed)?;
        let label = label.text().collect::<String>().trim().to_owned();
        if labels.next().is_some() {
            return Err(StudentReportError::ParseFailed);
        }
        if !matches!(label.as_str(), "学校名称" | "分院") {
            continue;
        }
        let mut values = item.select(&value_selector);
        let value = values.next().ok_or(StudentReportError::ParseFailed)?;
        let value = value.text().collect::<String>().trim().to_owned();
        if values.next().is_some() {
            return Err(StudentReportError::ParseFailed);
        }
        if label == "学校名称" {
            if value.is_empty() || school.replace(value).is_some() {
                return Err(StudentReportError::ParseFailed);
            }
        } else {
            if college_seen {
                return Err(StudentReportError::ParseFailed);
            }
            college_seen = true;
            college = (!value.is_empty()).then_some(value);
        }
    }
    let school = school.ok_or(StudentReportError::ParseFailed)?;
    if school != SCHOOL {
        return Err(StudentReportError::NotEligible);
    }
    Ok(ReportFields {
        college: college.map(|name| (name, "分院".to_owned())),
    })
}

async fn bind_report(
    pool: &PgPool,
    user_id: Uuid,
    report: ReportFields,
) -> Result<(), StudentReportError> {
    let (college_name, college_source_field) = match report.college {
        Some((name, field)) => (Some(name), Some(field)),
        None => (None, None),
    };
    sqlx::query(
        "INSERT INTO student_reports (
            user_id, school, source, verified_at, college_name, college_source_field
         ) VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (user_id) DO UPDATE SET
            school = EXCLUDED.school,
            source = EXCLUDED.source,
            verified_at = EXCLUDED.verified_at,
            college_name = EXCLUDED.college_name,
            college_source_field = EXCLUDED.college_source_field",
    )
    .bind(user_id)
    .bind(SCHOOL)
    .bind(SOURCE)
    .bind(OffsetDateTime::now_utc())
    .bind(college_name)
    .bind(college_source_field)
    .execute(pool)
    .await
    .map_err(store_error)?;
    Ok(())
}

pub async fn load_identity(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<StudentIdentity, StudentReportError> {
    let row: Option<(Option<String>, Option<String>)> = sqlx::query_as(
        "SELECT college_name, college_source_field FROM student_reports
         WHERE user_id = $1 AND school = $2 AND source = $3",
    )
    .bind(user_id)
    .bind(SCHOOL)
    .bind(SOURCE)
    .fetch_optional(pool)
    .await
    .map_err(store_error)?;
    let Some((name, field)) = row else {
        return Ok(StudentIdentity {
            student_verified: false,
            college: None,
        });
    };
    let college = name.zip(field).map(|(name, field)| {
        let mut digest = Sha256::new();
        for value in [SOURCE, SCHOOL, &field, &name] {
            digest.update(value.as_bytes());
            digest.update([0]);
        }
        College {
            id: format!("chsi:{}", hex::encode(digest.finalize())),
            name,
        }
    });
    Ok(StudentIdentity {
        student_verified: true,
        college,
    })
}

fn store_error(error: sqlx::Error) -> StudentReportError {
    tracing::error!(
        error_kind = crate::db::error_kind(&error),
        "student identity store operation failed"
    );
    StudentReportError::Store
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn code_matches_the_current_official_entry_format_without_accepting_urls() {
        for code in ["123456789012", "A1234567890ABCDE", "X1234567890ABCDE"] {
            assert_eq!(validate_code(code), Ok(()));
        }
        for code in [
            "",
            "https://www.chsi.com.cn/xlcx/bg.do",
            "a1234567890ABCDE",
            "W1234567890ABCDE",
            " A1234567890ABCDE",
            "A1234567890ABCD&",
            "１２３４５６７８９０１２",
        ] {
            assert_eq!(validate_code(code), Err(StudentReportError::Invalid));
        }
    }

    #[test]
    fn unsupported_html_never_becomes_a_verified_report() {
        for body in [
            "",
            "教育部学籍在线验证报告 吉林大学 在读 学号 123 学院 计算机学院",
            "<html>验证码</html>",
        ] {
            assert!(matches!(
                parse_official_report(body.as_bytes()),
                Err(StudentReportError::ParseFailed)
            ));
        }
    }

    const OBSERVED_REDACTED_REPORT: &str = r#"
        <div class="zxyz-res xj-zxyz-res">
            <h4>教育部学籍在线验证报告</h4>
            <div class="update-time">更新日期：2026年11月13日</div>
            <div class="report-info">
                <div class="report-info-item"><div class="label">学校名称</div><div class="value long">吉林大学</div></div>
                <div class="report-info-item"><div class="label">分院</div><div class="value long">测试学院</div></div>
                <div class="report-info-item"><div class="label">系所</div><div class="value">测试校区</div></div>
                <div class="report-info-item"><div class="label">学籍状态</div><div class="value long">在籍（注册学籍）</div></div>
                <div class="report-info-item"><div class="label">预计毕业日期</div><div class="value">2030年07月01日</div></div>
            </div>
        </div>"#;

    #[test]
    fn observed_redacted_structure_verifies_school_and_only_source_backed_college() {
        let parsed = parse_official_report(OBSERVED_REDACTED_REPORT.as_bytes()).unwrap();
        assert_eq!(parsed.college, Some(("测试学院".into(), "分院".into())));
        for status in ["毕业", "在籍（注册学籍）", "未知状态"] {
            let body = OBSERVED_REDACTED_REPORT.replace("在籍（注册学籍）", status);
            assert!(parse_official_report(body.as_bytes()).is_ok());
        }
        let empty_college = OBSERVED_REDACTED_REPORT.replace("测试学院", " ");
        assert!(
            parse_official_report(empty_college.as_bytes())
                .unwrap()
                .college
                .is_none()
        );
        let duplicate_empty_college = OBSERVED_REDACTED_REPORT.replace("<div class=\"report-info\">", "<div class=\"report-info\"><div class=\"report-info-item\"><div class=\"label\">分院</div><div class=\"value\"></div></div>");
        assert!(matches!(
            parse_official_report(duplicate_empty_college.as_bytes()),
            Err(StudentReportError::ParseFailed)
        ));
        let without_college = OBSERVED_REDACTED_REPORT.replace(
            r#"<div class="report-info-item"><div class="label">分院</div><div class="value long">测试学院</div></div>"#, "");
        assert!(
            parse_official_report(without_college.as_bytes())
                .unwrap()
                .college
                .is_none()
        );
        let other_school = OBSERVED_REDACTED_REPORT.replace("吉林大学", "吉林大学珠海学院");
        assert!(matches!(
            parse_official_report(other_school.as_bytes()),
            Err(StudentReportError::NotEligible)
        ));
        let other_type = OBSERVED_REDACTED_REPORT
            .replace("教育部学籍在线验证报告", "教育部学历证书电子注册备案表");
        assert!(matches!(
            parse_official_report(other_type.as_bytes()),
            Err(StudentReportError::NotEligible)
        ));
        let duplicate_school = OBSERVED_REDACTED_REPORT.replace(
            "<div class=\"report-info\">",
            "<div class=\"report-info\"><div class=\"report-info-item\"><div class=\"label\">学校名称</div><div class=\"value\">吉林大学</div></div>",
        );
        assert!(matches!(
            parse_official_report(duplicate_school.as_bytes()),
            Err(StudentReportError::ParseFailed)
        ));
        let duplicate = format!("{OBSERVED_REDACTED_REPORT}{OBSERVED_REDACTED_REPORT}");
        assert!(matches!(
            parse_official_report(duplicate.as_bytes()),
            Err(StudentReportError::ParseFailed)
        ));
    }

    #[cfg(feature = "integration")]
    #[sqlx::test(migrations = "./migrations")]
    async fn binding_allows_shared_reports_and_updates_only_the_current_account(pool: PgPool) {
        let columns: Vec<String> = sqlx::query_scalar("SELECT column_name FROM information_schema.columns WHERE table_name = 'student_reports' ORDER BY ordinal_position").fetch_all(&pool).await.unwrap();
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
        let first = Uuid::new_v4();
        let second = Uuid::new_v4();
        for id in [first, second] {
            sqlx::query("INSERT INTO users (id, login, display_name, timezone, created_at) VALUES ($1, $2, 'test', 'Asia/Shanghai', now())")
                .bind(id).bind(id.to_string()).execute(&pool).await.unwrap();
            bind_report(
                &pool,
                id,
                parse_official_report(OBSERVED_REDACTED_REPORT.as_bytes()).unwrap(),
            )
            .await
            .unwrap();
        }
        bind_report(&pool, first, ReportFields { college: None })
            .await
            .unwrap();
        assert!(load_identity(&pool, first).await.unwrap().college.is_none());
        assert!(
            load_identity(&pool, second)
                .await
                .unwrap()
                .college
                .is_some()
        );
        assert!(load_identity(&pool, first).await.unwrap().student_verified);
        let count: i64 = sqlx::query_scalar("SELECT count(*) FROM student_reports")
            .fetch_one(&pool)
            .await
            .unwrap();
        assert_eq!(count, 2);
    }
}
