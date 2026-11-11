#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: postgres-backup.sh <output-dir> [env-file] [compose-file] [compose-override]" >&2
  exit 2
}

[ "$#" -ge 1 ] || usage

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
backup_dir="$1"
env_file="${2:-$script_dir/.env}"
compose_file="${3:-$script_dir/compose.yaml}"
compose_override="${4:-}"

command -v docker > /dev/null 2>&1 || {
  echo "docker is required: pg_dump runs inside the postgres service container" >&2
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

umask 077
mkdir -p -- "$backup_dir"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
final_file="$backup_dir/jlu-dela-postgres-$timestamp.dump"
[ ! -e "$final_file" ] || {
  echo "backup file already exists: $final_file" >&2
  exit 1
}

tmp_file="$(mktemp "$backup_dir/.postgres-backup.XXXXXX")"
trap 'rm -f -- "$tmp_file"' EXIT

compose() {
  docker compose --env-file "$env_file" "${compose_args[@]}" "$@"
}

compose exec -T postgres \
  sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" exec pg_dump --host=127.0.0.1 --username="$POSTGRES_USER" --dbname="$POSTGRES_DB" --format=custom --no-owner --no-privileges' \
  > "$tmp_file"

compose exec -T postgres pg_restore --list < "$tmp_file" > /dev/null

mv -- "$tmp_file" "$final_file"
trap - EXIT

echo "backup written: $final_file ($(wc -c < "$final_file") bytes)"
echo "restore with: postgres-restore.sh $final_file <new-db-name>"
