use std::{collections::HashMap, fmt, net::IpAddr, str::FromStr, time::Duration};

use axum::http::HeaderValue;
use sqlx::postgres::PgConnectOptions;
use url::Url;

const DEFAULT_HTTP_HOST: &str = "127.0.0.1";
const DEFAULT_HTTP_PORT: &str = "8080";
const DEFAULT_MAX_CONNECTIONS: &str = "10";
const DEFAULT_ACQUIRE_TIMEOUT_SECONDS: &str = "5";
const DEFAULT_REQUEST_TIMEOUT_SECONDS: &str = "15";
const DEFAULT_MAX_BODY_BYTES: &str = "1048576";
const DEFAULT_BUILD_ID: &str = "dev";
const MIN_BODY_BYTES: usize = 1024;
const MAX_BODY_BYTES: usize = 16 * 1024 * 1024;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum LogFormat {
    Pretty,
    Json,
}

impl FromStr for LogFormat {
    type Err = ();

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "pretty" => Ok(Self::Pretty),
            "json" => Ok(Self::Json),
            _ => Err(()),
        }
    }
}

#[derive(Clone)]
pub struct Config {
    pub host: IpAddr,
    pub port: u16,
    pub database: DatabaseConfig,
    pub cors_allowed_origins: Vec<HeaderValue>,
    pub request_timeout: Duration,
    pub max_body_bytes: usize,
    pub files: crate::files::FileStorageConfig,
    pub build_id: String,
    pub log_format: LogFormat,
    pub dev_sms_fixed_code_enabled: bool,
}

#[derive(Clone)]
pub struct DatabaseConfig {
    pub connect_options: PgConnectOptions,
    pub max_connections: u32,
    pub acquire_timeout: Duration,
    target: String,
}

impl fmt::Debug for Config {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("Config")
            .field("host", &self.host)
            .field("port", &self.port)
            .field("database", &self.database)
            .field("cors_allowed_origins", &self.cors_allowed_origins)
            .field("request_timeout", &self.request_timeout)
            .field("max_body_bytes", &self.max_body_bytes)
            .field("files", &self.files)
            .field("build_id", &self.build_id)
            .field("log_format", &self.log_format)
            .field(
                "dev_sms_fixed_code_enabled",
                &self.dev_sms_fixed_code_enabled,
            )
            .finish()
    }
}

impl DatabaseConfig {
    pub fn target(&self) -> &str {
        &self.target
    }
}

impl fmt::Debug for DatabaseConfig {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("DatabaseConfig")
            .field("target", &self.target)
            .field("max_connections", &self.max_connections)
            .field("acquire_timeout", &self.acquire_timeout)
            .finish()
    }
}

#[derive(Debug, Eq, PartialEq)]
pub struct ConfigError {
    messages: Vec<String>,
}

impl ConfigError {
    fn new(messages: Vec<String>) -> Self {
        Self { messages }
    }
}

impl fmt::Display for ConfigError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        writeln!(formatter, "invalid configuration:")?;
        for message in &self.messages {
            writeln!(formatter, "  - {message}")?;
        }
        Ok(())
    }
}

impl std::error::Error for ConfigError {}

impl Config {
    pub fn from_env() -> Result<Self, ConfigError> {
        Self::from_variables(std::env::vars())
    }

    pub fn from_variables<I, K, V>(variables: I) -> Result<Self, ConfigError>
    where
        I: IntoIterator<Item = (K, V)>,
        K: Into<String>,
        V: Into<String>,
    {
        let variables: HashMap<String, String> = variables
            .into_iter()
            .map(|(key, value)| (key.into(), value.into()))
            .collect();
        let mut errors = Vec::new();

        let host = parse_value(
            variables
                .get("HTTP_HOST")
                .map_or(DEFAULT_HTTP_HOST, String::as_str),
            "HTTP_HOST",
            |value| {
                value
                    .parse::<IpAddr>()
                    .map_err(|_| "must be a valid IP address".to_owned())
            },
            &mut errors,
        );
        let port = parse_value(
            variables
                .get("HTTP_PORT")
                .map_or(DEFAULT_HTTP_PORT, String::as_str),
            "HTTP_PORT",
            |value| {
                let port = value
                    .parse::<u16>()
                    .map_err(|_| "must be a valid port".to_owned())?;
                if port == 0 {
                    return Err("must be between 1 and 65535".to_owned());
                }
                Ok(port)
            },
            &mut errors,
        );

        let database_url = match variables
            .get("DATABASE_URL")
            .filter(|value| !value.is_empty())
        {
            Some(value) => Some(value),
            None => {
                errors.push("DATABASE_URL is required".to_owned());
                None
            }
        };

        let database =
            database_url.and_then(|value| Self::database(value, &variables, &mut errors));

        let cors_allowed_origins =
            match parse_allowed_origins(variables.get("CORS_ALLOWED_ORIGINS")) {
                Ok(origins) => origins,
                Err(message) => {
                    errors.push(message);
                    Vec::new()
                }
            };

        let request_timeout = parse_bounded_duration(
            variables
                .get("REQUEST_TIMEOUT_SECONDS")
                .map_or(DEFAULT_REQUEST_TIMEOUT_SECONDS, String::as_str),
            "REQUEST_TIMEOUT_SECONDS",
            1,
            120,
            &mut errors,
        );
        let max_body_bytes = parse_value(
            variables
                .get("MAX_BODY_BYTES")
                .map_or(DEFAULT_MAX_BODY_BYTES, String::as_str),
            "MAX_BODY_BYTES",
            |value| {
                let bytes = value
                    .parse::<usize>()
                    .map_err(|_| "must be a byte count".to_owned())?;
                if !(MIN_BODY_BYTES..=MAX_BODY_BYTES).contains(&bytes) {
                    return Err(format!(
                        "must be between {MIN_BODY_BYTES} and {MAX_BODY_BYTES} bytes"
                    ));
                }
                Ok(bytes)
            },
            &mut errors,
        );
        let file_max_bytes = parse_value(
            variables
                .get("FILE_MAX_BYTES")
                .map_or("10485760", String::as_str),
            "FILE_MAX_BYTES",
            |value| {
                let bytes = value
                    .parse::<usize>()
                    .map_err(|_| "must be a byte count".to_owned())?;
                if !(1..=64 * 1024 * 1024).contains(&bytes) {
                    return Err("must be between 1 and 67108864 bytes".to_owned());
                }
                Ok(bytes)
            },
            &mut errors,
        );
        let file_storage_dir = variables
            .get("FILE_STORAGE_DIR")
            .map_or("./data/files", String::as_str);
        if file_storage_dir.is_empty() {
            errors.push("FILE_STORAGE_DIR must not be empty".to_owned());
        }
        let build_id = parse_value(
            variables
                .get("APP_BUILD_ID")
                .map_or(DEFAULT_BUILD_ID, String::as_str),
            "APP_BUILD_ID",
            |value| {
                if value.is_empty()
                    || value.len() > 64
                    || !value.chars().all(|character| {
                        character.is_ascii_alphanumeric() || "._-".contains(character)
                    })
                {
                    return Err("must be 1-64 ASCII letters, digits, '.', '_' or '-'".to_owned());
                }
                Ok(value.to_owned())
            },
            &mut errors,
        );
        let log_format = parse_value(
            variables.get("LOG_FORMAT").map_or("pretty", String::as_str),
            "LOG_FORMAT",
            |value| match value {
                "pretty" => Ok(LogFormat::Pretty),
                "json" => Ok(LogFormat::Json),
                _ => Err("must be 'pretty' or 'json'".to_owned()),
            },
            &mut errors,
        );

        let dev_sms_fixed_code_enabled = match variables
            .get("DEV_SMS_FIXED_CODE_ENABLED")
            .map_or("false", String::as_str)
        {
            "false" => false,
            "true" => {
                if !cfg!(debug_assertions) {
                    errors.push("DEV_SMS_FIXED_CODE_ENABLED requires a debug build".to_owned());
                }
                if !host.as_ref().is_ok_and(|host| host.is_loopback()) {
                    errors
                        .push("DEV_SMS_FIXED_CODE_ENABLED requires loopback HTTP_HOST".to_owned());
                }
                true
            }
            _ => {
                errors.push("DEV_SMS_FIXED_CODE_ENABLED must be 'true' or 'false'".to_owned());
                false
            }
        };

        match (
            host,
            port,
            database,
            request_timeout,
            max_body_bytes,
            file_max_bytes,
            build_id,
            log_format,
        ) {
            (
                Ok(host),
                Ok(port),
                Some(database),
                Ok(request_timeout),
                Ok(max_body_bytes),
                Ok(file_max_bytes),
                Ok(build_id),
                Ok(log_format),
            ) if errors.is_empty() => Ok(Self {
                host,
                port,
                database,
                cors_allowed_origins,
                request_timeout,
                max_body_bytes,
                files: crate::files::FileStorageConfig {
                    dir: file_storage_dir.into(),
                    max_bytes: file_max_bytes,
                },
                build_id,
                log_format,
                dev_sms_fixed_code_enabled,
            }),
            _ => Err(ConfigError::new(errors)),
        }
    }

    fn database(
        url: &str,
        variables: &HashMap<String, String>,
        errors: &mut Vec<String>,
    ) -> Option<DatabaseConfig> {
        let parsed = match Url::parse(url) {
            Ok(parsed) if matches!(parsed.scheme(), "postgres" | "postgresql") => parsed,
            Ok(_) => {
                errors.push(
                    "DATABASE_URL must use the postgres:// or postgresql:// scheme".to_owned(),
                );
                return None;
            }
            Err(_) => {
                errors.push("DATABASE_URL is not a valid URL".to_owned());
                return None;
            }
        };

        let host = parsed.host_str().unwrap_or("unknown");
        let port = parsed.port().unwrap_or(5432);
        let database_name = parsed.path().trim_start_matches('/');
        let target = format!("{host}:{port}/{database_name}");
        let connect_options = match PgConnectOptions::from_str(url) {
            Ok(options) => options,
            Err(_) => {
                errors.push("DATABASE_URL is not a valid PostgreSQL connection string".to_owned());
                return None;
            }
        };
        let max_connections = parse_value(
            variables
                .get("DATABASE_MAX_CONNECTIONS")
                .map_or(DEFAULT_MAX_CONNECTIONS, String::as_str),
            "DATABASE_MAX_CONNECTIONS",
            |value| {
                let connections = value
                    .parse::<u32>()
                    .map_err(|_| "must be a connection count".to_owned())?;
                if !(1..=100).contains(&connections) {
                    return Err("must be between 1 and 100".to_owned());
                }
                Ok(connections)
            },
            errors,
        );
        let acquire_timeout = parse_bounded_duration(
            variables
                .get("DATABASE_ACQUIRE_TIMEOUT_SECONDS")
                .map_or(DEFAULT_ACQUIRE_TIMEOUT_SECONDS, String::as_str),
            "DATABASE_ACQUIRE_TIMEOUT_SECONDS",
            1,
            60,
            errors,
        );

        match (max_connections, acquire_timeout) {
            (Ok(max_connections), Ok(acquire_timeout)) => Some(DatabaseConfig {
                connect_options,
                max_connections,
                acquire_timeout,
                target,
            }),
            _ => None,
        }
    }
}

fn parse_value<T>(
    value: &str,
    name: &str,
    parser: impl FnOnce(&str) -> Result<T, String>,
    errors: &mut Vec<String>,
) -> Result<T, ()> {
    match parser(value) {
        Ok(parsed) => Ok(parsed),
        Err(error) => {
            errors.push(format!("{name} {error}"));
            Err(())
        }
    }
}

fn parse_bounded_duration(
    value: &str,
    name: &str,
    minimum: u64,
    maximum: u64,
    errors: &mut Vec<String>,
) -> Result<Duration, ()> {
    parse_value(
        value,
        name,
        |value| {
            let seconds = value
                .parse::<u64>()
                .map_err(|_| "must be a whole number of seconds".to_owned())?;
            if !(minimum..=maximum).contains(&seconds) {
                return Err(format!("must be between {minimum} and {maximum} seconds"));
            }
            Ok(Duration::from_secs(seconds))
        },
        errors,
    )
}

fn parse_allowed_origins(value: Option<&String>) -> Result<Vec<HeaderValue>, String> {
    let Some(value) = value else {
        return Ok(Vec::new());
    };

    let mut origins = Vec::new();
    for raw_origin in value
        .split(',')
        .map(str::trim)
        .filter(|origin| !origin.is_empty())
    {
        if raw_origin == "*" {
            return Err("CORS_ALLOWED_ORIGINS must list explicit origins, not '*'".to_owned());
        }
        let parsed = Url::parse(raw_origin).map_err(|_| {
            format!("CORS_ALLOWED_ORIGINS contains an invalid origin: {raw_origin}")
        })?;
        let valid = matches!(parsed.scheme(), "http" | "https")
            && parsed.host_str().is_some()
            && parsed.username().is_empty()
            && parsed.password().is_none()
            && parsed.query().is_none()
            && parsed.fragment().is_none()
            && matches!(parsed.path(), "" | "/");
        if !valid {
            return Err(format!(
                "CORS_ALLOWED_ORIGINS must contain scheme://host[:port] origins: {raw_origin}"
            ));
        }
        let header = HeaderValue::from_str(raw_origin.trim_end_matches('/')).map_err(|_| {
            format!("CORS_ALLOWED_ORIGINS contains an invalid origin: {raw_origin}")
        })?;
        origins.push(header);
    }
    Ok(origins)
}
