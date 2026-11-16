use sqlx::{
    PgPool,
    migrate::{MigrateError, Migrator},
    postgres::PgPoolOptions,
};

use crate::config::Config;

static MIGRATOR: Migrator = sqlx::migrate!("./migrations");

pub async fn connect(config: &Config) -> Result<PgPool, sqlx::Error> {
    PgPoolOptions::new()
        .max_connections(config.database.max_connections)
        .acquire_timeout(config.database.acquire_timeout)
        .connect_with(config.database.connect_options.clone())
        .await
}

pub fn connect_lazy(config: &Config) -> PgPool {
    PgPoolOptions::new()
        .max_connections(config.database.max_connections)
        .acquire_timeout(config.database.acquire_timeout)
        .connect_lazy_with(config.database.connect_options.clone())
}

pub async fn run_migrations(pool: &PgPool) -> Result<(), MigrateError> {
    let mut connection = pool.acquire().await?;
    let has_ledger: bool = sqlx::query_scalar("SELECT to_regclass('_sqlx_migrations') IS NOT NULL")
        .fetch_one(&mut *connection)
        .await?;
    if has_ledger {
        let applied: Vec<(i64, Vec<u8>, bool)> = sqlx::query_as(
            "SELECT version, checksum, success FROM _sqlx_migrations ORDER BY version",
        )
        .fetch_all(&mut *connection)
        .await?;
        for (version, checksum, success) in applied {
            if !success {
                return Err(MigrateError::Dirty(version));
            }
            let migration = MIGRATOR
                .iter()
                .find(|migration| migration.version == version)
                .ok_or(MigrateError::VersionMissing(version))?;
            if migration.checksum.as_ref() != checksum {
                return Err(MigrateError::VersionMismatch(version));
            }
        }
    }
    MIGRATOR.run(&mut *connection).await
}

pub fn error_kind(error: &sqlx::Error) -> &'static str {
    match error {
        sqlx::Error::Configuration(_) => "configuration",
        sqlx::Error::Database(_) => "database",
        sqlx::Error::Io(_) => "io",
        sqlx::Error::Tls(_) => "tls",
        sqlx::Error::Protocol(_) => "protocol",
        sqlx::Error::PoolTimedOut => "pool_timeout",
        sqlx::Error::PoolClosed => "pool_closed",
        sqlx::Error::WorkerCrashed => "worker_crashed",
        sqlx::Error::RowNotFound => "row_not_found",
        sqlx::Error::Migrate(_) => "migration",
        _ => "other",
    }
}
