use anyhow::{Context, Result, anyhow};
use jlu_dela_api::{config::Config, db, logging};

#[tokio::main]
async fn main() -> Result<()> {
    let config = Config::from_env().context("load configuration")?;
    logging::init(config.log_format);

    let pool = db::connect(&config)
        .await
        .map_err(|error| anyhow!("database connection failed ({})", db::error_kind(&error)))
        .with_context(|| format!("connect to PostgreSQL at {}", config.database.target()))?;

    db::run_migrations(&pool)
        .await
        .context("run database migrations")?;
    tracing::info!(
        database = %config.database.target(),
        "database migrations complete"
    );
    pool.close().await;
    Ok(())
}
