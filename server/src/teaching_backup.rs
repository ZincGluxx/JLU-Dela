use std::collections::HashSet;

use axum::{
    Extension, Json, Router,
    extract::{Request, State},
    http::{HeaderMap, HeaderValue, StatusCode, header},
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::get,
};
use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;
use sha2::{Digest, Sha256};
use sqlx::{FromRow, PgPool};
use tower_http::request_id::RequestId;
use uuid::Uuid;

use crate::{
    auth::AuthenticatedUser,
    error::{AppError, FieldError, request_id},
    json::ApiJson,
    response::ApiResponse,
    state::AppState,
};

const PUT_ENDPOINT: &str = "PUT /personal-backup/teaching";
const DELETE_ENDPOINT: &str = "DELETE /personal-backup/teaching";
const MAX_PAYLOAD_BYTES: usize = 512 * 1024;

#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
struct TeachingBackupPayload {
    format: BackupFormat,
    format_version: u32,
    exported_at_utc: DateTime<Utc>,
    #[serde(
        default,
        deserialize_with = "selected",
        skip_serializing_if = "Option::is_none"
    )]
    timetables: Option<Vec<Timetable>>,
    #[serde(
        default,
        deserialize_with = "selected",
        skip_serializing_if = "Option::is_none"
    )]
    period_times: Option<Vec<PeriodTime>>,
    #[serde(
        default,
        deserialize_with = "selected",
        skip_serializing_if = "Option::is_none"
    )]
    course_preferences: Option<Vec<CoursePreference>>,
    #[serde(
        default,
        deserialize_with = "selected",
        skip_serializing_if = "Option::is_none"
    )]
    academic_completion: Option<AcademicCompletion>,
}

#[derive(Debug, Deserialize, Serialize)]
enum BackupFormat {
    #[serde(rename = "jlu_dela_teaching_backup")]
    Teaching,
}

#[derive(Debug, Deserialize, Serialize, PartialEq, Eq, Hash)]
#[serde(deny_unknown_fields)]
struct SourceRef {
    source: TeachingSource,
    source_scope: String,
    source_id: String,
}

#[derive(Debug, Deserialize, Serialize, PartialEq, Eq, Hash)]
enum TeachingSource {
    #[serde(rename = "jlu_iedu")]
    Iedu,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
struct Timetable {
    semester_code: String,
    name: String,
    is_current: bool,
    #[serde(deserialize_with = "calendar_date")]
    starts_on: NaiveDate,
    #[serde(deserialize_with = "required_nullable")]
    total_weeks: Option<i32>,
    observed_at_utc: DateTime<Utc>,
    courses: Vec<Course>,
    lessons: Vec<Lesson>,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
struct Course {
    course_ref: SourceRef,
    name: String,
    #[serde(deserialize_with = "required_nullable")]
    teacher: Option<String>,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
struct Lesson {
    course_ref: SourceRef,
    title: String,
    starts_at_utc: DateTime<Utc>,
    ends_at_utc: DateTime<Utc>,
    #[serde(deserialize_with = "required_nullable")]
    location: Option<String>,
    #[serde(deserialize_with = "required_nullable")]
    period_start: Option<i32>,
    #[serde(deserialize_with = "required_nullable")]
    period_end: Option<i32>,
    weekday: i32,
    week_number: i32,
    #[serde(deserialize_with = "required_nullable")]
    note: Option<String>,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
struct PeriodTime {
    campus: String,
    period: i32,
    start_minute: i32,
    end_minute: i32,
    observed_at_utc: DateTime<Utc>,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
struct CoursePreference {
    course_ref: SourceRef,
    #[serde(deserialize_with = "required_nullable")]
    remark: Option<String>,
    retained: bool,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
struct AcademicCompletion {
    selection_semester: String,
    current_semester: String,
    observed_at_utc: DateTime<Utc>,
    plans: Vec<AcademicPlan>,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
struct AcademicPlan {
    id: String,
    name: String,
    #[serde(deserialize_with = "required_nullable")]
    study_type: Option<String>,
    #[serde(deserialize_with = "required_nullable")]
    calculated_at_school: Option<String>,
    #[serde(deserialize_with = "required_nullable")]
    required_credits: Option<String>,
    #[serde(deserialize_with = "required_nullable")]
    earned_credits: Option<String>,
    #[serde(deserialize_with = "required_nullable")]
    selected_credits: Option<String>,
    groups: Vec<AcademicGroup>,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
struct AcademicGroup {
    id: String,
    #[serde(deserialize_with = "required_nullable")]
    parent_id: Option<String>,
    name: String,
    kind: String,
    required_credits: String,
    earned_credits: String,
    selected_credits: String,
    #[serde(deserialize_with = "required_nullable")]
    course_nature: Option<String>,
    #[serde(deserialize_with = "required_nullable")]
    required_courses: Option<i32>,
    #[serde(deserialize_with = "required_nullable")]
    earned_courses: Option<i32>,
    #[serde(deserialize_with = "required_nullable")]
    required_groups: Option<i32>,
    #[serde(deserialize_with = "required_nullable")]
    earned_groups: Option<i32>,
    #[serde(deserialize_with = "required_nullable")]
    choice_groups: Option<i32>,
}

fn calendar_date<'de, D>(deserializer: D) -> Result<NaiveDate, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let raw = String::deserialize(deserializer)?;
    let date = NaiveDate::parse_from_str(&raw, "%Y-%m-%d").map_err(serde::de::Error::custom)?;
    if raw.len() != 10 || date.format("%Y-%m-%d").to_string() != raw {
        return Err(serde::de::Error::custom("expected YYYY-MM-DD"));
    }
    Ok(date)
}

fn required_nullable<'de, D, T>(deserializer: D) -> Result<Option<T>, D::Error>
where
    D: serde::Deserializer<'de>,
    T: Deserialize<'de>,
{
    Option::<T>::deserialize(deserializer)
}

fn selected<'de, D, T>(deserializer: D) -> Result<Option<T>, D::Error>
where
    D: serde::Deserializer<'de>,
    T: Deserialize<'de>,
{
    T::deserialize(deserializer).map(Some)
}

#[derive(Debug, Serialize, FromRow)]
struct BackupSnapshot {
    revision: i32,
    deleted: bool,
    payload: Option<sqlx::types::Json<TeachingBackupPayload>>,
    updated_at: Option<DateTime<Utc>>,
}

impl Default for BackupSnapshot {
    fn default() -> Self {
        Self {
            revision: 0,
            deleted: true,
            payload: None,
            updated_at: None,
        }
    }
}

#[derive(Debug, Deserialize, Serialize, FromRow)]
#[serde(deny_unknown_fields)]
struct BackupReceipt {
    revision: i32,
    deleted: bool,
    updated_at: DateTime<Utc>,
}

#[derive(Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
struct PutBackup {
    expected_revision: i32,
    payload: TeachingBackupPayload,
}

#[derive(Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
struct DeleteBackup {
    expected_revision: i32,
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/personal-backup/teaching",
            get(read).put(put).delete(delete),
        )
        .layer(middleware::from_fn(private_response))
}

async fn private_response(request: Request, next: Next) -> Response {
    let mut response = next.run(request).await;
    response.headers_mut().insert(
        header::CACHE_CONTROL,
        HeaderValue::from_static("private, no-store"),
    );
    response
}

async fn read(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
) -> Response {
    let request_id = request_id(&request_id_value);
    match sqlx::query_as::<_, BackupSnapshot>(
        "SELECT revision, deleted, payload, updated_at FROM teaching_backups WHERE user_id = $1",
    )
    .bind(user.user_id)
    .fetch_optional(&state.pool)
    .await
    {
        Ok(snapshot) => {
            Json(ApiResponse::new(snapshot.unwrap_or_default(), request_id)).into_response()
        }
        Err(_) => AppError::DatabaseUnavailable.response(&request_id),
    }
}

async fn put(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
    headers: HeaderMap,
    ApiJson(body): ApiJson<PutBackup>,
) -> Response {
    let request_id = request_id(&request_id_value);
    let key = match idempotency_key(&headers) {
        Ok(key) => key,
        Err(error) => return error.response(&request_id),
    };
    if let Err(error) =
        validate_revision(body.expected_revision).and_then(|_| validate(&body.payload))
    {
        return error.response(&request_id);
    }
    let request_hash = hex::encode(Sha256::digest(
        serde_json::to_vec(&body).expect("teaching request serializes"),
    ));
    match write(
        &state.pool,
        user.user_id,
        PUT_ENDPOINT,
        key,
        &request_hash,
        body.expected_revision,
        Some(&body.payload),
    )
    .await
    {
        Ok(receipt) => Json(ApiResponse::new(receipt, request_id)).into_response(),
        Err(error) => error.response(&request_id),
    }
}

async fn delete(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Extension(request_id_value): Extension<RequestId>,
    headers: HeaderMap,
    ApiJson(body): ApiJson<DeleteBackup>,
) -> Response {
    let request_id = request_id(&request_id_value);
    let key = match idempotency_key(&headers) {
        Ok(key) => key,
        Err(error) => return error.response(&request_id),
    };
    if let Err(error) = validate_revision(body.expected_revision) {
        return error.response(&request_id);
    }
    let request_hash = hex::encode(Sha256::digest(
        serde_json::to_vec(&body).expect("teaching delete serializes"),
    ));
    match write(
        &state.pool,
        user.user_id,
        DELETE_ENDPOINT,
        key,
        &request_hash,
        body.expected_revision,
        None,
    )
    .await
    {
        Ok(receipt) => Json(ApiResponse::new(receipt, request_id)).into_response(),
        Err(error) => error.response(&request_id),
    }
}

fn invalid(path: impl Into<String>, code: &str) -> AppError {
    AppError::Validation(vec![FieldError::new(path, code)])
}

fn idempotency_key(headers: &HeaderMap) -> Result<Uuid, AppError> {
    headers
        .get("idempotency-key")
        .ok_or_else(|| invalid("Idempotency-Key", "REQUIRED"))?
        .to_str()
        .ok()
        .and_then(|raw| Uuid::parse_str(raw).ok())
        .ok_or_else(|| invalid("Idempotency-Key", "INVALID_FORMAT"))
}

fn validate_revision(revision: i32) -> Result<(), AppError> {
    if revision < 0 || revision == i32::MAX {
        return Err(invalid("expected_revision", "OUT_OF_RANGE"));
    }
    Ok(())
}

fn text(path: &str, value: Option<&str>, limit: usize) -> Result<(), AppError> {
    if value.is_some_and(|value| value.chars().count() > limit) {
        return Err(invalid(path, "TOO_LONG"));
    }
    Ok(())
}

fn count(path: &str, length: usize, limit: usize) -> Result<(), AppError> {
    if length > limit {
        return Err(invalid(path, "TOO_MANY_ITEMS"));
    }
    Ok(())
}

fn range(path: &str, value: i32, min: i32, max: i32) -> Result<(), AppError> {
    if !(min..=max).contains(&value) {
        return Err(invalid(path, "OUT_OF_RANGE"));
    }
    Ok(())
}

fn semester(path: &str, value: &str) -> Result<(), AppError> {
    let bytes = value.as_bytes();
    if bytes.len() != 11
        || bytes[4] != b'-'
        || bytes[9] != b'-'
        || !bytes[..4]
            .iter()
            .chain(&bytes[5..9])
            .all(u8::is_ascii_digit)
        || !matches!(bytes[10], b'1'..=b'3')
    {
        return Err(invalid(path, "INVALID_FORMAT"));
    }
    Ok(())
}

fn reference(path: &str, value: &SourceRef) -> Result<(), AppError> {
    semester(&format!("{path}.source_scope"), &value.source_scope)?;
    text(&format!("{path}.source_id"), Some(&value.source_id), 300)?;
    if value.source_id.trim().is_empty() {
        return Err(invalid(format!("{path}.source_id"), "REQUIRED"));
    }
    Ok(())
}

fn validate(payload: &TeachingBackupPayload) -> Result<(), AppError> {
    if payload.format_version != 1 {
        return Err(invalid("payload.format_version", "UNSUPPORTED_VERSION"));
    }
    if payload.timetables.is_some() != payload.period_times.is_some() {
        return Err(invalid("payload.period_times", "TIMETABLE_PAIR_REQUIRED"));
    }
    if payload.timetables.as_ref().is_some_and(Vec::is_empty)
        || payload
            .course_preferences
            .as_ref()
            .is_some_and(Vec::is_empty)
        || (payload.timetables.is_none()
            && payload.course_preferences.is_none()
            && payload.academic_completion.is_none())
    {
        return Err(invalid("payload", "EMPTY_SELECTION"));
    }
    if let Some(timetables) = &payload.timetables {
        count("payload.timetables", timetables.len(), 12)?;
        let mut semesters = HashSet::new();
        for (index, table) in timetables.iter().enumerate() {
            let path = format!("payload.timetables[{index}]");
            semester(&format!("{path}.semester_code"), &table.semester_code)?;
            if !semesters.insert(&table.semester_code) {
                return Err(invalid(format!("{path}.semester_code"), "DUPLICATE"));
            }
            text(&format!("{path}.name"), Some(&table.name), 300)?;
            if let Some(weeks) = table.total_weeks {
                range(&format!("{path}.total_weeks"), weeks, 1, 104)?;
            }
            count(&format!("{path}.courses"), table.courses.len(), 1000)?;
            count(&format!("{path}.lessons"), table.lessons.len(), 10000)?;
            let mut courses = HashSet::new();
            for (index, course) in table.courses.iter().enumerate() {
                let path = format!("{path}.courses[{index}]");
                reference(&format!("{path}.course_ref"), &course.course_ref)?;
                if course.course_ref.source_scope != table.semester_code {
                    return Err(invalid(format!("{path}.course_ref"), "SEMESTER_MISMATCH"));
                }
                if !courses.insert(&course.course_ref) {
                    return Err(invalid(format!("{path}.course_ref"), "DUPLICATE"));
                }
                text(&format!("{path}.name"), Some(&course.name), 300)?;
                text(&format!("{path}.teacher"), course.teacher.as_deref(), 300)?;
            }
            for (index, lesson) in table.lessons.iter().enumerate() {
                let path = format!("{path}.lessons[{index}]");
                reference(&format!("{path}.course_ref"), &lesson.course_ref)?;
                if !courses.contains(&lesson.course_ref) {
                    return Err(invalid(format!("{path}.course_ref"), "UNKNOWN_COURSE"));
                }
                text(&format!("{path}.title"), Some(&lesson.title), 300)?;
                text(&format!("{path}.location"), lesson.location.as_deref(), 300)?;
                text(&format!("{path}.note"), lesson.note.as_deref(), 2000)?;
                if lesson.starts_at_utc >= lesson.ends_at_utc {
                    return Err(invalid(format!("{path}.ends_at_utc"), "INVALID_INTERVAL"));
                }
                match (lesson.period_start, lesson.period_end) {
                    (None, None) => {}
                    (Some(start), Some(end)) if start <= end => {
                        range(&format!("{path}.period_start"), start, 1, 500)?;
                        range(&format!("{path}.period_end"), end, 1, 500)?;
                    }
                    _ => return Err(invalid(format!("{path}.period_end"), "INVALID_PERIOD_PAIR")),
                }
                range(&format!("{path}.weekday"), lesson.weekday, 1, 7)?;
                range(
                    &format!("{path}.week_number"),
                    lesson.week_number,
                    1,
                    table.total_weeks.unwrap_or(104),
                )?;
            }
        }
    }
    if let Some(periods) = &payload.period_times {
        count("payload.period_times", periods.len(), 500)?;
        let mut keys = HashSet::new();
        for (index, period) in periods.iter().enumerate() {
            let path = format!("payload.period_times[{index}]");
            text(&format!("{path}.campus"), Some(&period.campus), 100)?;
            range(&format!("{path}.period"), period.period, 1, 500)?;
            range(
                &format!("{path}.start_minute"),
                period.start_minute,
                0,
                1439,
            )?;
            range(&format!("{path}.end_minute"), period.end_minute, 1, 1440)?;
            if period.start_minute >= period.end_minute {
                return Err(invalid(format!("{path}.end_minute"), "INVALID_INTERVAL"));
            }
            if !keys.insert((&period.campus, period.period)) {
                return Err(invalid(path, "DUPLICATE"));
            }
        }
    }
    if let Some(preferences) = &payload.course_preferences {
        count("payload.course_preferences", preferences.len(), 2000)?;
        let mut keys = HashSet::new();
        for (index, preference) in preferences.iter().enumerate() {
            let path = format!("payload.course_preferences[{index}]");
            reference(&format!("{path}.course_ref"), &preference.course_ref)?;
            text(&format!("{path}.remark"), preference.remark.as_deref(), 100)?;
            if !keys.insert(&preference.course_ref) {
                return Err(invalid(format!("{path}.course_ref"), "DUPLICATE"));
            }
        }
    }
    if let Some(academic) = &payload.academic_completion {
        let path = "payload.academic_completion";
        text(
            &format!("{path}.selection_semester"),
            Some(&academic.selection_semester),
            100,
        )?;
        text(
            &format!("{path}.current_semester"),
            Some(&academic.current_semester),
            100,
        )?;
        count(&format!("{path}.plans"), academic.plans.len(), 20)?;
        for (index, plan) in academic.plans.iter().enumerate() {
            let path = format!("{path}.plans[{index}]");
            text(&format!("{path}.id"), Some(&plan.id), 300)?;
            text(&format!("{path}.name"), Some(&plan.name), 300)?;
            for (field, value) in [
                ("study_type", &plan.study_type),
                ("calculated_at_school", &plan.calculated_at_school),
                ("required_credits", &plan.required_credits),
                ("earned_credits", &plan.earned_credits),
                ("selected_credits", &plan.selected_credits),
            ] {
                text(&format!("{path}.{field}"), value.as_deref(), 100)?;
            }
            count(&format!("{path}.groups"), plan.groups.len(), 500)?;
            for (index, group) in plan.groups.iter().enumerate() {
                let path = format!("{path}.groups[{index}]");
                for (field, value) in [
                    ("id", Some(group.id.as_str())),
                    ("parent_id", group.parent_id.as_deref()),
                    ("name", Some(group.name.as_str())),
                ] {
                    text(&format!("{path}.{field}"), value, 300)?;
                }
                for (field, value) in [
                    ("kind", Some(group.kind.as_str())),
                    ("course_nature", group.course_nature.as_deref()),
                    ("required_credits", Some(group.required_credits.as_str())),
                    ("earned_credits", Some(group.earned_credits.as_str())),
                    ("selected_credits", Some(group.selected_credits.as_str())),
                ] {
                    text(&format!("{path}.{field}"), value, 100)?;
                }
                for (field, value) in [
                    ("required_courses", group.required_courses),
                    ("earned_courses", group.earned_courses),
                    ("required_groups", group.required_groups),
                    ("earned_groups", group.earned_groups),
                    ("choice_groups", group.choice_groups),
                ] {
                    if let Some(value) = value {
                        range(&format!("{path}.{field}"), value, 0, 1_000_000)?;
                    }
                }
            }
        }
    }
    if serde_json::to_vec(payload)
        .expect("teaching payload serializes")
        .len()
        > MAX_PAYLOAD_BYTES
    {
        return Err(invalid("payload", "TOO_LARGE"));
    }
    Ok(())
}

enum WriteError {
    IdempotencyConflict,
    RevisionConflict(Box<BackupSnapshot>),
    App(AppError),
}

impl From<sqlx::Error> for WriteError {
    fn from(_: sqlx::Error) -> Self {
        Self::App(AppError::DatabaseUnavailable)
    }
}

impl WriteError {
    fn response(self, request_id: &str) -> Response {
        let (code, message, current) = match self {
            Self::App(error) => return error.response(request_id),
            Self::IdempotencyConflict => (
                "IDEMPOTENCY_CONFLICT",
                "Idempotency key was used for a different request.",
                None,
            ),
            Self::RevisionConflict(snapshot) => (
                "TEACHING_BACKUP_REVISION_CONFLICT",
                "Teaching backup revision does not match.",
                Some(snapshot),
            ),
        };
        let mut error = json!({ "code": code, "message": message, "request_id": request_id, "retryable": false, "fields": [] });
        if let Some(current) = current {
            error["current"] = json!(current);
        }
        (StatusCode::CONFLICT, Json(json!({ "error": error }))).into_response()
    }
}

async fn write(
    pool: &PgPool,
    user_id: Uuid,
    endpoint: &str,
    key: Uuid,
    request_hash: &str,
    expected_revision: i32,
    payload: Option<&TeachingBackupPayload>,
) -> Result<BackupReceipt, WriteError> {
    let mut tx = pool.begin().await?;
    let claimed = sqlx::query(
        "INSERT INTO idempotency_keys (user_id, endpoint, key, request_hash)
         VALUES ($1, $2, $3, $4) ON CONFLICT (user_id, endpoint, key) DO NOTHING",
    )
    .bind(user_id)
    .bind(endpoint)
    .bind(key)
    .bind(request_hash)
    .execute(&mut *tx)
    .await?;
    if claimed.rows_affected() == 0 {
        let (existing_hash, status, response): (String, Option<i16>, Option<serde_json::Value>) =
            sqlx::query_as(
                "SELECT request_hash, status_code, response FROM idempotency_keys
             WHERE user_id = $1 AND endpoint = $2 AND key = $3",
            )
            .bind(user_id)
            .bind(endpoint)
            .bind(key)
            .fetch_one(&mut *tx)
            .await?;
        if existing_hash != request_hash || status != Some(200) {
            return Err(WriteError::IdempotencyConflict);
        }
        let receipt = serde_json::from_value(response.ok_or(sqlx::Error::RowNotFound)?)
            .map_err(|_| sqlx::Error::Decode("invalid teaching backup receipt".into()))?;
        tx.commit().await?;
        return Ok(receipt);
    }
    sqlx::query("INSERT INTO teaching_backups (user_id) VALUES ($1) ON CONFLICT DO NOTHING")
        .bind(user_id)
        .execute(&mut *tx)
        .await?;
    let current: BackupSnapshot = sqlx::query_as(
        "SELECT revision, deleted, payload, updated_at FROM teaching_backups WHERE user_id = $1 FOR UPDATE",
    ).bind(user_id).fetch_one(&mut *tx).await?;
    if current.revision != expected_revision {
        return Err(WriteError::RevisionConflict(Box::new(current)));
    }
    let receipt: BackupReceipt = sqlx::query_as(
        "UPDATE teaching_backups SET revision = $2, deleted = $3, payload = $4, updated_at = now()
         WHERE user_id = $1 RETURNING revision, deleted, updated_at",
    )
    .bind(user_id)
    .bind(expected_revision + 1)
    .bind(payload.is_none())
    .bind(payload.map(sqlx::types::Json))
    .fetch_one(&mut *tx)
    .await?;
    sqlx::query(
        "UPDATE idempotency_keys SET status_code = 200, response = $4 WHERE user_id = $1 AND endpoint = $2 AND key = $3",
    ).bind(user_id).bind(endpoint).bind(key).bind(sqlx::types::Json(&receipt)).execute(&mut *tx).await?;
    tx.commit().await?;
    Ok(receipt)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn selected_partition_omission_and_nullable_fields_round_trip() {
        let value = json!({
            "format": "jlu_dela_teaching_backup", "format_version": 1,
            "exported_at_utc": "2026-11-16T07:00:00Z",
            "course_preferences": [{
                "course_ref": {"source": "jlu_iedu", "source_scope": "2026-2027-1", "source_id": "course"},
                "remark": null, "retained": false,
            }],
        });
        let parsed: TeachingBackupPayload = serde_json::from_value(value.clone()).unwrap();
        assert!(validate(&parsed).is_ok());
        assert_eq!(serde_json::to_value(parsed).unwrap(), value);
        let mut null_partition = value.clone();
        null_partition["timetables"] = serde_json::Value::Null;
        assert!(serde_json::from_value::<TeachingBackupPayload>(null_partition).is_err());
        let mut unknown = value;
        unknown["course_preferences"][0]["course_ref"]["device_uuid"] = json!(Uuid::new_v4());
        assert!(serde_json::from_value::<TeachingBackupPayload>(unknown).is_err());
    }
}
