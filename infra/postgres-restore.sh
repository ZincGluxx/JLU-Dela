#!/usr/bin/env bash
set -euo pipefail

[ "$#" -ge 2 ] || {
  echo 'usage: postgres-restore.sh <dump-file> <new-db-name> [--native | env-file compose-file compose-override]' >&2
  exit 2
}
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/backup-common.sh"
dump_file="$1"
restore_db="$2"
shift 2
[ -f "$dump_file" ] || backup_die 'dump file not found'
[[ "$restore_db" =~ ^[a-z][a-z0-9_]{0,62}$ ]] || backup_die 'invalid new database name'
backup_database "$@"
pg_exec pg_restore --list < "$dump_file" > /dev/null
exists="$(pg_exec psql --no-psqlrc --dbname=postgres --tuples-only --no-align --set=ON_ERROR_STOP=1 \
  --command="SELECT 1 FROM pg_database WHERE datname = '$restore_db'")"
[ "$exists" != 1 ] || backup_die 'restore target database already exists'
pg_exec createdb --maintenance-db=postgres "$restore_db"
echo "created restore database: $restore_db"
trap 'echo "restore failed; new database retained for inspection, do not reuse it as a successful restore" >&2' ERR
pg_exec pg_restore --dbname="$restore_db" --no-owner --no-privileges --single-transaction < "$dump_file"
row="$(pg_exec psql --no-psqlrc --dbname="$restore_db" --tuples-only --no-align --set=ON_ERROR_STOP=1 --command="
  SELECT (SELECT value FROM service_meta WHERE key = 'schema_version'),
         (SELECT count(*) FROM users), (SELECT count(*) FROM sessions)")"
IFS='|' read -r schema_version user_count session_count <<< "$row"
[[ "$schema_version" =~ ^[0-9]+$ ]] || backup_die 'restored schema metadata missing'
printf 'database restore verified: schema_version=%s users=%s sessions=%s\n' "$schema_version" "$user_count" "$session_count"
trap - ERR
