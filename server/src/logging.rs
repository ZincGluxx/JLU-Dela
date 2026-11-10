use tracing_subscriber::{EnvFilter, fmt};

use crate::config::LogFormat;

pub fn init(format: LogFormat) {
    let filter =
        EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info,sqlx=warn"));

    match format {
        LogFormat::Pretty => {
            fmt()
                .with_env_filter(filter)
                .with_target(false)
                .compact()
                .init();
        }
        LogFormat::Json => {
            fmt()
                .json()
                .with_env_filter(filter)
                .with_current_span(false)
                .with_span_list(false)
                .init();
        }
    }
}
