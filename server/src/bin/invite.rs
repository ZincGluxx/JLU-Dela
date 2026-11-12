use std::iter::Iterator;

use anyhow::{Context, Result, bail};
use jlu_dela_api::{
    auth::{invite, login},
    config::Config,
    db,
    error::AppError,
};
use time::{Duration, format_description::well_known::Rfc3339};

const USAGE: &str =
    "Usage: invite --login <login> --display-name <display name> [--ttl-hours <hours>]

Issues a one-time workbench invitation. The default lifetime is 24 hours; the
maximum is 168 hours (7 days).";

const DEFAULT_TTL_HOURS: u64 = 24;
const MAX_TTL_HOURS: u64 = 168;
const MAX_DISPLAY_NAME_CHARS: usize = 128;

struct Arguments {
    login: String,
    display_name: String,
    ttl_hours: u64,
}

#[tokio::main]
async fn main() -> Result<()> {
    let Some(arguments) = parse_arguments()? else {
        println!("{USAGE}");
        return Ok(());
    };

    let login = normalize_login(&arguments.login)?;
    let display_name = normalize_display_name(&arguments.display_name)?;

    let config = Config::from_env().context("load configuration")?;
    let pool = db::connect(&config)
        .await
        .map_err(|error| anyhow::anyhow!("database connection failed ({})", db::error_kind(&error)))
        .with_context(|| format!("connect to PostgreSQL at {}", config.database.target()))?;

    let issued = invite::create(
        &pool,
        &login,
        &display_name,
        Duration::hours(arguments.ttl_hours as i64),
    )
    .await
    .context("create invitation")?;

    println!("invite_token: {}", issued.token);
    println!("login: {login}");
    println!(
        "expires_at: {}",
        issued
            .expires_at
            .format(&Rfc3339)
            .context("format invitation expiry")?
    );

    pool.close().await;
    Ok(())
}

fn parse_arguments() -> Result<Option<Arguments>> {
    let mut arguments = std::env::args().skip(1);
    let mut login = None;
    let mut display_name = None;
    let mut ttl_hours = None;

    while let Some(argument) = arguments.next() {
        match argument.as_str() {
            "--login" => login = Some(next_value(&mut arguments, "--login")?),
            "--display-name" => display_name = Some(next_value(&mut arguments, "--display-name")?),
            "--ttl-hours" => {
                let value = next_value(&mut arguments, "--ttl-hours")?;
                ttl_hours = Some(
                    value
                        .parse::<u64>()
                        .with_context(|| format!("--ttl-hours is not a whole number: {value}"))?,
                );
            }
            "--help" | "-h" => return Ok(None),
            other => bail!("unexpected argument: {other}\n\n{USAGE}"),
        }
    }

    let ttl_hours = ttl_hours.unwrap_or(DEFAULT_TTL_HOURS);
    if !(1..=MAX_TTL_HOURS).contains(&ttl_hours) {
        bail!("--ttl-hours must be between 1 and {MAX_TTL_HOURS}");
    }

    Ok(Some(Arguments {
        login: login.context("--login is required")?,
        display_name: display_name.context("--display-name is required")?,
        ttl_hours,
    }))
}

fn next_value(arguments: &mut impl Iterator<Item = String>, flag: &str) -> Result<String> {
    arguments
        .next()
        .with_context(|| format!("{flag} requires a value"))
}

fn normalize_login(raw: &str) -> Result<String> {
    let login = login::normalize(raw);
    match login::validate(&login) {
        Ok(()) => Ok(login),
        Err(AppError::Validation(fields)) => {
            let code = fields
                .first()
                .map_or("is invalid", |field| field.code.as_str());
            match code {
                "too_short" => bail!("--login must be 4-64 characters"),
                "too_long" => bail!("--login must be 4-64 characters"),
                "invalid_format" => {
                    bail!("--login may only contain lowercase letters, digits, '.', '_' and '-'")
                }
                _ => bail!("--login is invalid"),
            }
        }
        Err(_) => bail!("--login is invalid"),
    }
}

fn normalize_display_name(raw: &str) -> Result<String> {
    let display_name = raw.trim();
    if display_name.is_empty() {
        bail!("--display-name must not be blank");
    }
    if display_name.chars().count() > MAX_DISPLAY_NAME_CHARS {
        bail!("--display-name must be at most {MAX_DISPLAY_NAME_CHARS} characters");
    }
    Ok(display_name.to_owned())
}
