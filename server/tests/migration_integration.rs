#![cfg(feature = "integration")]

use std::{collections::BTreeMap, path::Path};

use base64::Engine;
use serde_json::Value;
use sha2::{Digest, Sha256};
use sqlx::{
    AssertSqlSafe, PgPool, SqlSafeStr,
    migrate::{MigrateError, Migration, MigrationType, Migrator},
};
use uuid::Uuid;

const MAIN_TEN: i64 = 20261114010000;
const D_SEVENTEEN: i64 = 20261116040000;
const PERSONAL_TABLES: &[&str] = &[
    "users",
    "sessions",
    "student_reports",
    "todos",
    "sync_jobs",
    "files",
    "personal_backups",
];
const COMMUNITY_TABLES: &[&str] = &[
    "community_posts",
    "community_comments",
    "community_post_images",
    "campus_places",
    "community_post_likes",
    "community_post_favorites",
    "community_notifications",
    "community_reports",
];

async fn canonical() -> Migrator {
    Migrator::new(Path::new(env!("CARGO_MANIFEST_DIR")).join("migrations"))
        .await
        .expect("canonical migrations load")
}

async fn snapshot(pool: &PgPool, tables: &[&str]) -> BTreeMap<String, Value> {
    let mut result = BTreeMap::new();
    for table in tables {
        let sql = format!(
            "SELECT COALESCE(jsonb_agg(item ORDER BY item::text), '[]'::jsonb)
             FROM (SELECT to_jsonb(t) AS item FROM {table} t) rows"
        );
        let rows = sqlx::query_scalar(AssertSqlSafe(sql))
            .fetch_one(pool)
            .await
            .expect("fixture snapshot is readable");
        result.insert((*table).to_owned(), rows);
    }
    result
}

async fn seed_personal(pool: &PgPool) -> Uuid {
    let user = Uuid::new_v4();
    for statement in [
        "INSERT INTO users(id,login,display_name,timezone,created_at)
         VALUES($1,$1::text,'Synthetic migration user','Asia/Shanghai',now())",
        "INSERT INTO student_reports(user_id,school,source,verified_at,college_name,college_source_field)
         VALUES($1,'吉林大学','chsi',now(),'合成迁移学院','分院')",
        "INSERT INTO todos(user_id,title) VALUES($1,'synthetic retained todo')",
        "INSERT INTO sync_jobs(id,user_id,source,resource,scope,scope_key,status,created_at,updated_at)
         VALUES(gen_random_uuid(),$1,'jlu_iedu','schedule','{}'::jsonb,'synthetic','queued',now(),now())",
        "INSERT INTO files(id,uploader_id,original_name,size_bytes,media_type)
         VALUES(gen_random_uuid(),$1,'synthetic-private.txt',3,'text/plain')",
        "INSERT INTO personal_backups(user_id,revision,deleted,notes,updated_at)
         VALUES($1,7,false,'[{\"title\":\"synthetic retained note\"}]'::jsonb,now())",
    ] {
        sqlx::query(statement)
            .bind(user)
            .execute(pool)
            .await
            .expect("personal fixture is inserted");
    }
    jlu_dela_api::auth::session::issue_for_user(pool, user)
        .await
        .expect("fixture session is issued");
    user
}

async fn assert_complete_without_publication_or_grants(pool: &PgPool) {
    let schema: String =
        sqlx::query_scalar("SELECT value FROM service_meta WHERE key='schema_version'")
            .fetch_one(pool)
            .await
            .unwrap();
    assert_eq!(schema, "20");
    let ledger: (i64, i64, bool) = sqlx::query_as(
        "SELECT count(*),count(DISTINCT version),bool_and(success) FROM _sqlx_migrations",
    )
    .fetch_one(pool)
    .await
    .unwrap();
    assert_eq!(ledger, (20, 20, true));
    let published: i64 = sqlx::query_scalar("SELECT count(*) FROM shared_materials")
        .fetch_one(pool)
        .await
        .unwrap();
    let grants: i64 = sqlx::query_scalar("SELECT count(*) FROM management_grants")
        .fetch_one(pool)
        .await
        .unwrap();
    let backups: i64 = sqlx::query_scalar("SELECT count(*) FROM teaching_backups")
        .fetch_one(pool)
        .await
        .unwrap();
    assert_eq!(published, 0);
    assert_eq!(grants, 0);
    assert_eq!(backups, 0);
}

#[tokio::test]
async fn canonical_sqlx_versions_are_unique_and_ordered() {
    let migrator = canonical().await;
    let versions: Vec<_> = migrator.iter().map(|migration| migration.version).collect();
    assert_eq!(versions.len(), 20);
    assert!(versions.windows(2).all(|pair| pair[0] < pair[1]));
    assert_eq!(versions.last(), Some(&20261116070000));
}

#[sqlx::test(migrations = false)]
async fn empty_database_reaches_twenty_without_automatic_publication_or_grants(pool: PgPool) {
    jlu_dela_api::db::run_migrations(&pool).await.unwrap();
    jlu_dela_api::db::run_migrations(&pool).await.unwrap();
    assert_complete_without_publication_or_grants(&pool).await;
    let users: i64 = sqlx::query_scalar("SELECT count(*) FROM users")
        .fetch_one(&pool)
        .await
        .unwrap();
    let posts: i64 = sqlx::query_scalar("SELECT count(*) FROM community_posts")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!((users, posts), (0, 0));
}

#[sqlx::test(migrations = false)]
async fn main_ten_upgrade_preserves_personal_data_and_private_files(pool: PgPool) {
    let migrator = canonical().await;
    migrator.run_to(MAIN_TEN, &pool).await.unwrap();
    let user = seed_personal(&pool).await;
    let before = snapshot(&pool, PERSONAL_TABLES).await;

    jlu_dela_api::db::run_migrations(&pool).await.unwrap();
    jlu_dela_api::db::run_migrations(&pool).await.unwrap();

    assert_eq!(snapshot(&pool, PERSONAL_TABLES).await, before);
    let private_files: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM files WHERE uploader_id=$1 AND use_kind IS NULL AND business_id IS NULL",
    )
    .bind(user)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(private_files, 1);
    assert_complete_without_publication_or_grants(&pool).await;
}

#[sqlx::test(migrations = false)]
async fn d_seventeen_upgrade_preserves_interactions_images_and_maintained_places(pool: PgPool) {
    let migrator = canonical().await;
    migrator.run_to(D_SEVENTEEN, &pool).await.unwrap();
    let owner = seed_personal(&pool).await;
    let actor = seed_personal(&pool).await;
    let post = Uuid::new_v4();
    let parent = Uuid::new_v4();
    let reply = Uuid::new_v4();
    let image = Uuid::new_v4();
    let bytes = base64::engine::general_purpose::STANDARD
        .decode("iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEklEQVR4nGNUa3jNwMDAxAAGABIxAZXdg286AAAAAElFTkSuQmCC")
        .unwrap();
    let directory = tempfile::tempdir().unwrap();
    let image_path = directory.path().join(image.to_string());
    tokio::fs::write(&image_path, &bytes).await.unwrap();
    let college = jlu_dela_api::auth::student::load_identity(&pool, owner)
        .await
        .unwrap()
        .college
        .unwrap();

    sqlx::query(
        "INSERT INTO community_posts(id,college_id,author_id,title,body)
         VALUES($1,$2,$3,'synthetic retained post','synthetic retained body')",
    )
    .bind(post)
    .bind(college.id)
    .bind(owner)
    .execute(&pool)
    .await
    .unwrap();
    sqlx::query(
        "INSERT INTO community_comments(id,post_id,author_id,body)
         VALUES($1,$2,$3,'synthetic retained comment')",
    )
    .bind(parent)
    .bind(post)
    .bind(actor)
    .execute(&pool)
    .await
    .unwrap();
    sqlx::query(
        "INSERT INTO community_comments(id,post_id,author_id,body,reply_to_comment_id)
         VALUES($1,$2,$3,'synthetic retained reply',$4)",
    )
    .bind(reply)
    .bind(post)
    .bind(owner)
    .bind(parent)
    .execute(&pool)
    .await
    .unwrap();
    sqlx::query(
        "INSERT INTO files(id,uploader_id,original_name,size_bytes,media_type,use_kind,business_id)
         VALUES($1,$2,'synthetic.png',$3,'image/png','community_image',$4)",
    )
    .bind(image)
    .bind(owner)
    .bind(bytes.len() as i64)
    .bind(post)
    .execute(&pool)
    .await
    .unwrap();
    sqlx::query("INSERT INTO community_post_images(post_id,file_id,position) VALUES($1,$2,0)")
        .bind(post)
        .bind(image)
        .execute(&pool)
        .await
        .unwrap();
    for statement in [
        "INSERT INTO community_post_likes(post_id,user_id) VALUES($1,$2)",
        "INSERT INTO community_post_favorites(post_id,user_id) VALUES($1,$2)",
        "INSERT INTO community_reports(post_id,reporter_id,reason) VALUES($1,$2,'synthetic retained reason')",
    ] {
        sqlx::query(statement)
            .bind(post)
            .bind(actor)
            .execute(&pool)
            .await
            .unwrap();
    }
    sqlx::query(
        "INSERT INTO community_notifications(recipient_id,actor_id,post_id,comment_id,kind,read_at)
         VALUES($1,$2,$3,$4,'comment',now())",
    )
    .bind(owner)
    .bind(actor)
    .bind(post)
    .bind(parent)
    .execute(&pool)
    .await
    .unwrap();
    sqlx::query(
        "UPDATE campus_places SET room='synthetic maintained room',office_person=NULL,
         updated_at=updated_at+interval '1 second' WHERE id='jwc-nanling-teaching-office'",
    )
    .execute(&pool)
    .await
    .unwrap();
    let personal_before = snapshot(&pool, PERSONAL_TABLES).await;
    let community_before = snapshot(&pool, COMMUNITY_TABLES).await;

    jlu_dela_api::db::run_migrations(&pool).await.unwrap();
    jlu_dela_api::db::run_migrations(&pool).await.unwrap();

    assert_eq!(snapshot(&pool, PERSONAL_TABLES).await, personal_before);
    assert_eq!(snapshot(&pool, COMMUNITY_TABLES).await, community_before);
    assert_eq!(tokio::fs::read(&image_path).await.unwrap(), bytes);
    assert_complete_without_publication_or_grants(&pool).await;
}

#[sqlx::test(migrations = false)]
async fn old_b_twelve_ledger_requires_a_separate_data_migration(pool: PgPool) {
    let migrator = canonical().await;
    let canonical_sql = include_str!("../migrations/20261116050000_shared_materials.sql");
    let schema_statement =
        "UPDATE service_meta SET value = '18', updated_at = now() WHERE key = 'schema_version';";
    assert_eq!(canonical_sql.matches(schema_statement).count(), 1);
    let old_sql = canonical_sql.replace(
        schema_statement,
        "UPDATE service_meta SET value = '12', updated_at = now() WHERE key = 'schema_version';",
    );
    assert_eq!(
        hex::encode(Sha256::digest(old_sql.as_bytes())),
        "784f4535e07419eec7ea43f1af5a98c6883d28b3f5337ed7b85cabfdfabf82d2"
    );
    let mut old_migrations: Vec<_> = migrator
        .iter()
        .filter(|migration| migration.version <= MAIN_TEN)
        .cloned()
        .collect();
    old_migrations.push(Migration::new(
        20261115010000,
        "shared materials".into(),
        MigrationType::Simple,
        AssertSqlSafe(old_sql).into_sql_str(),
        false,
    ));
    Migrator::with_migrations(old_migrations)
        .run(&pool)
        .await
        .unwrap();
    let owner = seed_personal(&pool).await;
    let material = Uuid::new_v4();
    let file = Uuid::new_v4();
    sqlx::query(
        "INSERT INTO files(id,uploader_id,original_name,size_bytes,media_type,use_kind,business_id)
         VALUES($1,$2,'synthetic-material.txt',3,'text/plain','material',$3)",
    )
    .bind(file)
    .bind(owner)
    .bind(material)
    .execute(&pool)
    .await
    .unwrap();
    sqlx::query(
        "INSERT INTO shared_materials(id,author_id,title,kind,course_source,course_scope,
         course_source_id,course_name,visibility,file_id)
         VALUES($1,$2,'synthetic retained material','material','jlu_iedu','2026-2027-1',
         'synthetic-course','synthetic course','students',$3)",
    )
    .bind(material)
    .bind(owner)
    .bind(file)
    .execute(&pool)
    .await
    .unwrap();
    let personal_before = snapshot(&pool, PERSONAL_TABLES).await;
    let before = snapshot(
        &pool,
        &["service_meta", "_sqlx_migrations", "shared_materials"],
    )
    .await;

    let error = jlu_dela_api::db::run_migrations(&pool).await.unwrap_err();
    assert!(matches!(
        error,
        MigrateError::VersionMismatch(20261115010000)
    ));

    assert_eq!(snapshot(&pool, PERSONAL_TABLES).await, personal_before);
    assert_eq!(
        snapshot(
            &pool,
            &["service_meta", "_sqlx_migrations", "shared_materials"]
        )
        .await,
        before
    );
}
