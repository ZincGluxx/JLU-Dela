use anyhow::{Context, Result, anyhow};
use jlu_dela_api::{config::Config, db, http, logging, state::AppState};
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> Result<()> {
    let config = Config::from_env().context("load configuration")?;
    logging::init(config.log_format);

    let pool = db::connect(&config)
        .await
        .map_err(|error| anyhow!("database connection failed ({})", db::error_kind(&error)))
        .with_context(|| format!("connect to PostgreSQL at {}", config.database.target()))?;

    let state = AppState::new(pool.clone(), config.build_id.clone());
    let _sync_worker = jlu_dela_api::sync::worker::spawn(state.clone());
    let app = http::router(state, &config);
    let listener = TcpListener::bind((config.host, config.port))
        .await
        .with_context(|| format!("bind HTTP listener on {}:{}", config.host, config.port))?;
    let address = listener.local_addr()?;

    tracing::info!(
        address = %address,
        version = env!("CARGO_PKG_VERSION"),
        build_id = %config.build_id,
        database = %config.database.target(),
        "server listening"
    );

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .context("serve HTTP")?;

    tracing::info!("server stopped");
    pool.close().await;
    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        if let Err(error) = tokio::signal::ctrl_c().await {
            tracing::error!(%error, "failed to listen for Ctrl+C");
        }
    };

    #[cfg(unix)]
    let terminate = async {
        match tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate()) {
            Ok(mut signal) => {
                signal.recv().await;
            }
            Err(error) => tracing::error!(%error, "failed to listen for SIGTERM"),
        }
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {}
        _ = terminate => {}
    }
    tracing::info!("shutdown signal received");
}
