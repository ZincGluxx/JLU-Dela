#![cfg(feature = "integration")]

use std::{
    fs,
    path::{Path, PathBuf},
};

use sqlx::{PgPool, migrate::Migrator, postgres::PgPoolOptions};
use url::Url;
use uuid::Uuid;

struct TempDatabase {
    name: String,
    url: Url,
    admin: PgPool,
}

impl TempDatabase {
    async fn create() -> Self {
        let base = Url::parse(
            &std::env::var("DATABASE_URL")
                .expect("DATABASE_URL is required when running with --features integration"),
        )
        .expect("DATABASE_URL is a URL");
        let mut admin_url = base.clone();
        admin_url.set_path("/postgres");
        let admin = PgPoolOptions::new()
            .max_connections(1)
            .connect(admin_url.as_str())
            .await
            .expect("administrator connection is available");

        let name = format!("jlu_dela_test_{}", Uuid::new_v4().simple());
        sqlx::raw_sql(sqlx::AssertSqlSafe(format!("CREATE DATABASE \"{name}\"")))
            .execute(&admin)
            .await
            .expect("temporary database is created");

        let mut url = base;
        url.set_path(&format!("/{name}"));
        Self { name, url, admin }
    }

    async fn pool(&self) -> PgPool {
        PgPoolOptions::new()
            .max_connections(2)
            .connect(self.url.as_str())
            .await
            .expect("temporary database is reachable")
    }

    async fn cleanup(self, pool: PgPool) {
        pool.close().await;
        sqlx::raw_sql(sqlx::AssertSqlSafe(format!(
            "DROP DATABASE IF EXISTS \"{}\"",
            self.name
        )))
        .execute(&self.admin)
        .await
        .expect("temporary database is dropped");
        self.admin.close().await;
    }
}

fn published_migrations() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("migrations")
}

fn copy_version_four_migrations() -> PathBuf {
    let target =
        std::env::temp_dir().join(format!("jlu-dela-migrations-{}", Uuid::new_v4().simple()));
    fs::create_dir_all(&target).expect("migration subset directory is created");
    for entry in fs::read_dir(published_migrations()).expect("migrations directory is readable") {
        let path = entry.expect("migration entry is readable").path();
        let name = path
            .file_name()
            .and_then(|name| name.to_str())
            .expect("migration file name is valid UTF-8");
        if name.ends_with(".sql") && name < "20261112000000" {
            fs::copy(&path, target.join(name)).expect("migration is copied");
        }
    }
    target
}

async fn schema_version(pool: &PgPool) -> String {
    sqlx::query_scalar("SELECT value FROM service_meta WHERE key = 'schema_version'")
        .fetch_one(pool)
        .await
        .expect("schema version is readable")
}

#[tokio::test]
async fn complete_migration_of_an_empty_database_reaches_version_nine() {
    let database = TempDatabase::create().await;
    let pool = database.pool().await;

    jlu_dela_api::db::run_migrations(&pool)
        .await
        .expect("migrations apply to an empty database");
    assert_eq!(schema_version(&pool).await, "9");

    let tables: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM information_schema.tables
         WHERE table_schema = 'public' AND table_name IN ('users', 'sessions', 'invites', 'login_attempts')",
    )
    .fetch_one(&pool)
    .await
    .expect("tables are readable");
    assert_eq!(tables, 4);

    let password_hash_column: bool = sqlx::query_scalar(
        "SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'password_hash'
        )",
    )
    .fetch_one(&pool)
    .await
    .expect("columns are readable");
    assert!(password_hash_column);

    database.cleanup(pool).await;
}

#[tokio::test]
async fn upgrading_from_version_four_keeps_existing_rows_and_adds_new_schema() {
    let database = TempDatabase::create().await;
    let pool = database.pool().await;

    let subset = copy_version_four_migrations();
    let migrator = Migrator::new(subset.as_path())
        .await
        .expect("version four migrations load");
    migrator
        .run(&pool)
        .await
        .expect("version four migrations apply");
    assert_eq!(schema_version(&pool).await, "4");

    let user_id = Uuid::new_v4();
    let session_id = Uuid::new_v4();
    let job_id = Uuid::new_v4();
    sqlx::query(
        "INSERT INTO users (id, login, display_name, timezone, created_at)
         VALUES ($1, 'legacy.user', 'Legacy User', 'Asia/Shanghai', now())",
    )
    .bind(user_id)
    .execute(&pool)
    .await
    .expect("existing user is inserted");
    sqlx::query(
        "INSERT INTO sessions (
            id, user_id, access_token_hash, refresh_token_hash,
            access_expires_at, refresh_expires_at, created_at, last_used_at
         ) VALUES ($1, $2, 'legacy-access', 'legacy-refresh', now() + interval '1 hour',
                   now() + interval '30 days', now(), now())",
    )
    .bind(session_id)
    .bind(user_id)
    .execute(&pool)
    .await
    .expect("existing session is inserted");
    sqlx::query("INSERT INTO todos (user_id, title) VALUES ($1, 'legacy todo')")
        .bind(user_id)
        .execute(&pool)
        .await
        .expect("existing todo is inserted");
    sqlx::query(
        "INSERT INTO sync_jobs (
            id, user_id, source, resource, scope, scope_key, status, created_at, updated_at
         ) VALUES ($1, $2, 'jlu_iedu', 'schedule', '{}'::jsonb, 'legacy', 'queued', now(), now())",
    )
    .bind(job_id)
    .bind(user_id)
    .execute(&pool)
    .await
    .expect("existing sync job is inserted");

    jlu_dela_api::db::run_migrations(&pool)
        .await
        .expect("full migration chain upgrades version four");
    assert_eq!(schema_version(&pool).await, "9");

    let stored_login: String = sqlx::query_scalar("SELECT login FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .expect("existing user survives the upgrade");
    assert_eq!(stored_login, "legacy.user");
    let stored_password_hash: Option<String> =
        sqlx::query_scalar("SELECT password_hash FROM users WHERE id = $1")
            .bind(user_id)
            .fetch_one(&pool)
            .await
            .expect("new password column is readable");
    assert_eq!(stored_password_hash, None);

    for (table, statement, expected) in [
        ("sessions", "SELECT count(*) FROM sessions", 1_i64),
        ("todos", "SELECT count(*) FROM todos", 1_i64),
        ("sync_jobs", "SELECT count(*) FROM sync_jobs", 1_i64),
        ("invites", "SELECT count(*) FROM invites", 0_i64),
        (
            "login_attempts",
            "SELECT count(*) FROM login_attempts",
            0_i64,
        ),
    ] {
        let count: i64 = sqlx::query_scalar(statement)
            .fetch_one(&pool)
            .await
            .expect("table is readable");
        assert_eq!(count, expected, "unexpected rows in {table}");
    }

    let new_tables: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM information_schema.tables
         WHERE table_schema = 'public' AND table_name IN ('invites', 'login_attempts')",
    )
    .fetch_one(&pool)
    .await
    .expect("tables are readable");
    assert_eq!(new_tables, 2);

    fs::remove_dir_all(subset).ok();
    database.cleanup(pool).await;
}
