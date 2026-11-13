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
    assert_eq!(config.files.max_bytes, 10_485_760);
    assert_eq!(config.files.dir, std::path::PathBuf::from("./data/files"));
    assert_eq!(config.build_id, "commit-abc123");
    assert_eq!(config.log_format, LogFormat::Pretty);
    assert_eq!(config.cors_allowed_origins.len(), 2);
    assert!(!config.dev_sms_fixed_code_enabled);
}

#[test]
fn file_configuration_validates_bounds_without_creating_storage() {
    for value in ["0", "67108865", "invalid"] {
        assert!(
            Config::from_variables(with("FILE_MAX_BYTES", value))
                .unwrap_err()
                .to_string()
                .contains("FILE_MAX_BYTES")
        );
    }
    for value in ["1", "67108864"] {
        assert_eq!(
            Config::from_variables(with("FILE_MAX_BYTES", value))
                .unwrap()
                .files
                .max_bytes,
            value.parse::<usize>().unwrap()
        );
    }
    assert!(Config::from_variables(with("FILE_STORAGE_DIR", "")).is_err());
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
fn fixed_development_sms_requires_explicit_boolean_and_loopback() {
    for host in ["0.0.0.0", "::", "192.168.1.2"] {
        let mut values = with("HTTP_HOST", host);
        values.push(("DEV_SMS_FIXED_CODE_ENABLED".into(), "true".into()));
        let error = Config::from_variables(values).unwrap_err();
        assert!(error.to_string().contains("requires loopback HTTP_HOST"));
    }
    assert!(Config::from_variables(with("DEV_SMS_FIXED_CODE_ENABLED", "1")).is_err());
    for host in ["127.0.0.1", "::1"] {
        let mut values = with("HTTP_HOST", host);
        values.push(("DEV_SMS_FIXED_CODE_ENABLED".into(), "true".into()));
        let config = Config::from_variables(values);
        if cfg!(debug_assertions) {
            assert!(config.unwrap().dev_sms_fixed_code_enabled);
        } else {
            assert!(
                config
                    .unwrap_err()
                    .to_string()
                    .contains("requires a debug build")
            );
        }
    }
}

#[test]
fn sender_selection_is_fail_closed_even_after_config_is_modified() {
    let mut config = Config::from_variables(base()).unwrap();
    assert!(!jlu_dela_api::auth::phone::configured_sender(&config).dev_mode());
    config.dev_sms_fixed_code_enabled = true;
    assert_eq!(
        jlu_dela_api::auth::phone::configured_sender(&config).dev_mode(),
        cfg!(debug_assertions)
    );
    config.host = "0.0.0.0".parse().unwrap();
    assert!(!jlu_dela_api::auth::phone::configured_sender(&config).dev_mode());
}

#[test]
fn invalid_build_id_is_rejected() {
    let error = Config::from_variables(with("APP_BUILD_ID", "not a build id"))
        .expect_err("configuration must fail");

    assert!(error.to_string().contains("APP_BUILD_ID"));
}
