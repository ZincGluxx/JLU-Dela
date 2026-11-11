#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: postgres-restore.sh <dump-file> <new-db-name> [env-file] [compose-file] [compose-override]" >&2
  exit 2
}

[ "$#" -ge 2 ] || usage

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
dump_file="$1"
restore_db="$2"
env_file="${3:-$script_dir/.env}"
compose_file="${4:-$script_dir/compose.yaml}"
compose_override="${5:-}"

[ -f "$dump_file" ] || {
  echo "dump file not found: $dump_file" >&2
  exit 1
}
if [[ ! "$restore_db" =~ ^[a-z][a-z0-9_]*$ ]] || [ "${#restore_db}" -gt 63 ]; then
  echo "restore database name must match [a-z][a-z0-9_]* and be at most 63 characters: $restore_db" >&2
  exit 2
fi
command -v docker > /dev/null 2>&1 || {
  echo "docker is required: pg_restore runs inside the postgres service container" >&2
  exit 1
}
[ -f "$env_file" ] || {
  echo "env file not found: $env_file" >&2
  exit 1
}
[ -f "$compose_file" ] || {
  echo "compose file not found: $compose_file" >&2
  exit 1
}
compose_args=(-f "$compose_file")
if [ -n "$compose_override" ]; then
  [ -f "$compose_override" ] || {
    echo "compose override not found: $compose_override" >&2
    exit 1
  }
  compose_args+=(-f "$compose_override")
fi

compose() {
  docker compose --env-file "$env_file" "${compose_args[@]}" "$@"
}

compose exec -T postgres bash -s "$restore_db" <<'INNER'
set -euo pipefail
export PGPASSWORD="$POSTGRES_PASSWORD"
db="$1"
exists="$(psql --host=127.0.0.1 --username="$POSTGRES_USER" --dbname=postgres --tuples-only --no-align \
  --command="SELECT 1 FROM pg_database WHERE datname = '$db'")"
if [ "$exists" = "1" ]; then
  echo "restore target already exists: $db" >&2
  exit 1
fi
createdb --host=127.0.0.1 --username="$POSTGRES_USER" "$db"
echo "created restore database: $db"
INNER

compose exec -T postgres sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" exec pg_restore --host=127.0.0.1 --username="$POSTGRES_USER" --dbname="$1" --no-owner --no-privileges --single-transaction' \
  sh "$restore_db" < "$dump_file"

compose exec -T postgres bash -s "$restore_db" <<'INNER'
set -euo pipefail
export PGPASSWORD="$POSTGRES_PASSWORD"
db="$1"
row="$(psql --host=127.0.0.1 --username="$POSTGRES_USER" --dbname="$db" --tuples-only --no-align --command="
  SELECT (SELECT value FROM service_meta WHERE key = 'schema_version'),
         (SELECT count(*) FROM users),
         (SELECT count(*) FROM sessions)")"
IFS='|' read -r schema_version user_count session_count <<< "$row"
printf 'restore verified: schema_version=%s users=%s sessions=%s\n' \
  "$schema_version" "$user_count" "$session_count"
INNER

echo "restore complete: $restore_db"
