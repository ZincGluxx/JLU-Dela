use anyhow::{Context, Result, bail};
use jlu_dela_api::{
    auth::management::{self, ManagementScope},
    config::Config,
    db,
};
use uuid::Uuid;

const USAGE: &str = "Usage: management grant --user-id <UUID> (--campus | --college <ID>)
       management revoke --user-id <UUID> (--campus | --college <ID>)
       management list --user-id <UUID>

Only trusted server maintainers may run this command. College IDs must match the
trusted business target's college ID, not a display name. No account is created.";

#[derive(Debug, PartialEq, Eq)]
enum Action {
    Grant(ManagementScope),
    Revoke(ManagementScope),
    List,
}

#[derive(Debug, PartialEq, Eq)]
struct Arguments {
    user_id: Uuid,
    action: Action,
}

#[tokio::main]
async fn main() -> Result<()> {
    let Some(arguments) = parse_arguments(std::env::args().skip(1))? else {
        println!("{USAGE}");
        return Ok(());
    };
    let config = Config::from_env().context("load configuration")?;
    let pool = db::connect(&config)
        .await
        .map_err(|error| anyhow::anyhow!("database connection failed ({})", db::error_kind(&error)))
        .with_context(|| format!("connect to PostgreSQL at {}", config.database.target()))?;

    let user_id = arguments.user_id;
    match arguments.action {
        Action::Grant(scope) => {
            let changed = management::grant(&pool, user_id, &scope).await?;
            println!("user_id: {user_id}");
            print_scope(&scope);
            println!(
                "result: {}",
                if changed {
                    "granted"
                } else {
                    "already granted"
                }
            );
        }
        Action::Revoke(scope) => {
            let changed = management::revoke(&pool, user_id, &scope).await?;
            println!("user_id: {user_id}");
            print_scope(&scope);
            println!(
                "result: {}",
                if changed { "revoked" } else { "already absent" }
            );
        }
        Action::List => {
            let exists: bool =
                sqlx::query_scalar("SELECT EXISTS (SELECT 1 FROM users WHERE id = $1)")
                    .bind(user_id)
                    .fetch_one(&pool)
                    .await?;
            if !exists {
                bail!("target user does not exist: {user_id}");
            }
            let grants = management::list(&pool, user_id)
                .await
                .map_err(|error| anyhow::anyhow!("cannot list management grants: {error:?}"))?;
            println!("user_id: {user_id}");
            if !grants.campus && grants.college_ids.is_empty() {
                println!("grants: none");
            }
            if grants.campus {
                print_scope(&ManagementScope::Campus);
            }
            for id in grants.college_ids {
                print_scope(&ManagementScope::College(id));
            }
        }
    }
    pool.close().await;
    Ok(())
}

fn print_scope(scope: &ManagementScope) {
    match scope {
        ManagementScope::Campus => println!("scope: campus"),
        ManagementScope::College(id) => println!("scope: college {id}"),
    }
}

fn parse_arguments(mut arguments: impl Iterator<Item = String>) -> Result<Option<Arguments>> {
    let Some(command) = arguments.next() else {
        bail!("a command is required\n\n{USAGE}");
    };
    if matches!(command.as_str(), "--help" | "-h") && arguments.next().is_none() {
        return Ok(None);
    }
    if !matches!(command.as_str(), "grant" | "revoke" | "list") {
        bail!("unknown command: {command}\n\n{USAGE}");
    }
    let mut user_id = None;
    let mut scope = None;
    while let Some(argument) = arguments.next() {
        match argument.as_str() {
            "--user-id" => {
                if user_id.is_some() {
                    bail!("duplicate --user-id");
                }
                let value = next_value(&mut arguments, "--user-id")?;
                user_id = Some(Uuid::parse_str(&value).context("--user-id must be a UUID")?);
            }
            "--campus" | "--college" => {
                if scope.is_some() {
                    bail!(
                        "choose exactly one --campus or --college; repeated scopes are not allowed"
                    );
                }
                scope = Some(if argument == "--campus" {
                    ManagementScope::Campus
                } else {
                    let id = next_value(&mut arguments, "--college")?;
                    if id.trim().is_empty() || id != id.trim() {
                        bail!("--college must be a nonblank ID without surrounding whitespace");
                    }
                    ManagementScope::College(id)
                });
            }
            other => bail!("unexpected argument: {other}\n\n{USAGE}"),
        }
    }
    let user_id = user_id.context("--user-id is required")?;
    let action = match command.as_str() {
        "grant" => Action::Grant(scope.context("choose exactly one --campus or --college")?),
        "revoke" => Action::Revoke(scope.context("choose exactly one --campus or --college")?),
        _ => {
            if scope.is_some() {
                bail!("list does not accept --campus or --college");
            }
            Action::List
        }
    };
    Ok(Some(Arguments { user_id, action }))
}

fn next_value(arguments: &mut impl Iterator<Item = String>, flag: &str) -> Result<String> {
    arguments
        .next()
        .filter(|value| !value.starts_with('-'))
        .with_context(|| format!("{flag} requires a value"))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse(arguments: &[&str]) -> Result<Option<Arguments>> {
        parse_arguments(arguments.iter().map(|value| (*value).to_owned()))
    }

    #[test]
    fn accepts_explicit_scopes_and_user_only_list() {
        let id = Uuid::new_v4();
        let id_string = id.to_string();
        for (command, flags, expected) in [
            (
                "grant",
                vec!["--campus"],
                Action::Grant(ManagementScope::Campus),
            ),
            (
                "revoke",
                vec!["--campus"],
                Action::Revoke(ManagementScope::Campus),
            ),
            (
                "grant",
                vec!["--college", "college-a"],
                Action::Grant(ManagementScope::College("college-a".into())),
            ),
            (
                "revoke",
                vec!["--college", "college-a"],
                Action::Revoke(ManagementScope::College("college-a".into())),
            ),
            ("list", vec![], Action::List),
        ] {
            let mut arguments = vec![command, "--user-id", &id_string];
            arguments.extend(flags);
            assert_eq!(
                parse(&arguments).unwrap(),
                Some(Arguments {
                    user_id: id,
                    action: expected
                })
            );
        }
        assert_eq!(parse(&["--help"]).unwrap(), None);
    }

    #[test]
    fn rejects_missing_duplicate_unknown_and_invalid_arguments() {
        let id = "4ec0408f-02b1-4c51-8f0b-b72649e9b5be";
        for arguments in [
            vec![],
            vec!["self-promote"],
            vec!["grant", "--campus"],
            vec!["grant", "--user-id", id],
            vec!["revoke", "--user-id", id],
            vec!["grant", "--user-id", "not-a-uuid", "--campus"],
            vec!["grant", "--user-id", "", "--campus"],
            vec!["grant", "--user-id", id, "--user-id", id, "--campus"],
            vec!["grant", "--user-id", id, "--campus", "--campus"],
            vec![
                "revoke",
                "--user-id",
                id,
                "--college",
                "a",
                "--college",
                "a",
            ],
            vec!["grant", "--user-id", id, "--campus", "--college", "a"],
            vec!["grant", "--user-id", id, "--college", ""],
            vec!["grant", "--user-id", id, "--college", "   "],
            vec!["grant", "--user-id", id, "--college", " a"],
            vec!["grant", "--user-id", id, "--college"],
            vec!["grant", "--user-id", "--campus"],
            vec!["grant", "--user-id", id, "--admin"],
            vec!["grant", "--user-id", id, "--college", "-h"],
            vec!["grant", "--user-id", id, "--college", "-x"],
            vec!["grant", "--user-id", id, "--campus", "extra"],
            vec!["grant", "--user-id", id, "--campus", "--help"],
            vec!["list", "--user-id", id, "--campus"],
            vec!["list", "--user-id", id, "--college", "a"],
            vec!["--help", "--unknown"],
        ] {
            assert!(parse(&arguments).is_err(), "accepted {arguments:?}");
        }
    }
}
