use jlu_dela_api::config::{Config, LogFormat};

fn base() -> Vec<(String, String)> {
    vec![
        (
            "DATABASE_URL".into(),
            "postgres://jlu_dela:super-secret@db.internal:5432/jlu_dela?sslmode=require".into(),
        ),
        ("HTTP_HOST".into(), "127.0.0.1".into()),
        ("HTTP_PORT".into(), "8080".into()),
        (
            "CORS_ALLOWED_ORIGINS".into(),
            "http://localhost:8080,https://localhost:8443".into(),
        ),
        ("APP_BUILD_ID".into(), "commit-abc123".into()),
    ]
}

fn without(key: &str) -> Vec<(String, String)> {
    let mut values = base();
    values.retain(|(existing, _)| existing != key);
    values
}

fn with(key: &str, value: &str) -> Vec<(String, String)> {
    let mut values = base();
    values.retain(|(existing, _)| existing != key);
    values.push((key.to_owned(), value.to_owned()));
    values
}

#[test]
fn valid_configuration_applies_defaults() {
    let config = Config::from_variables(base()).expect("configuration is valid");

    assert_eq!(config.host.to_string(), "127.0.0.1");
    assert_eq!(config.port, 8080);
    assert_eq!(config.database.max_connections, 10);
    assert_eq!(config.request_timeout.as_secs(), 15);
    assert_eq!(config.max_body_bytes, 1_048_576);
    assert_eq!(config.build_id, "commit-abc123");
    assert_eq!(config.log_format, LogFormat::Pretty);
    assert_eq!(config.cors_allowed_origins.len(), 2);
}

#[test]
fn missing_database_url_is_reported_by_name() {
    let error =
        Config::from_variables(without("DATABASE_URL")).expect_err("configuration must fail");
    let message = error.to_string();

    assert!(message.contains("DATABASE_URL is required"));
    assert!(!message.contains("super-secret"));
}

#[test]
fn invalid_port_and_wildcard_cors_are_reported_together() {
    let mut values = with("HTTP_PORT", "70000");
    values.retain(|(key, _)| key != "CORS_ALLOWED_ORIGINS");
    values.push(("CORS_ALLOWED_ORIGINS".into(), "*".into()));

    let error = Config::from_variables(values).expect_err("configuration must fail");
    let message = error.to_string();

    assert!(message.contains("HTTP_PORT"));
    assert!(message.contains("CORS_ALLOWED_ORIGINS"));
}

#[test]
fn database_debug_output_redacts_credentials_and_query() {
    let config = Config::from_variables(base()).expect("configuration is valid");
    let debug = format!("{:?}", config.database);

    assert_eq!(config.database.target(), "db.internal:5432/jlu_dela");
    assert!(!debug.contains("super-secret"));
    assert!(!debug.contains("sslmode"));
    assert!(debug.contains("db.internal:5432/jlu_dela"));
}

#[test]
fn invalid_build_id_is_rejected() {
    let error = Config::from_variables(with("APP_BUILD_ID", "not a build id"))
        .expect_err("configuration must fail");

    assert!(error.to_string().contains("APP_BUILD_ID"));
}
