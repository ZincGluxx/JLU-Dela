#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo 'usage: paired-restore.sh <bundle-dir> <new-db-name> <new-files-dir> --app-build <matching-build> [--native | --compose <env-file> <compose-file> [override]]' >&2
  exit 2
}
[ "$#" -ge 6 ] || usage
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/backup-common.sh"
backup_load_bundle "$1"
restore_db="$2"
backup_new_path "$3"
target="$new_path"
shift 3
[ "${1:-}" = --app-build ] || usage
[ "${2:-}" = "$backup_build" ] || backup_die 'application build does not match backup; use the matching service'
shift 2
mode="${1:---native}"
if [ "$mode" = --compose ]; then shift; fi
backup_database "$@"
[[ "$restore_db" =~ ^[a-z][a-z0-9_]{0,62}$ ]] || backup_die 'invalid new database name'
[ "$restore_db" != "$source_database" ] || backup_die 'refusing source database name'
case "$target/" in "$bundle/"* | "$source_files/"*) backup_die 'restore target overlaps backup or source files' ;; esac
exists="$(pg_exec psql --no-psqlrc --dbname=postgres --tuples-only --no-align --set=ON_ERROR_STOP=1 --command="SELECT 1 FROM pg_database WHERE datname='$restore_db'")"
[ "$exists" != 1 ] || backup_die 'restore target database already exists'
pg_exec pg_restore --list < "$bundle/database.dump" > /dev/null
while IFS= read -r entry; do
  [[ "$entry" = ./ || "$entry" =~ ^\./[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] || backup_die 'unsafe file archive entry'
done < <(tar --force-local -tf "$bundle/files.tar")
while IFS= read -r entry; do
  case "$entry" in -* | d*) ;; *) backup_die 'archive links and special files are not allowed' ;; esac
done < <(tar --force-local -tvf "$bundle/files.tar")
tar --force-local -tf "$bundle/files.tar" > /dev/null
if ! "$native"; then
  [ -z "$(compose ps -q api)" ] || backup_die 'restore only into an isolated project with no running API'
fi
umask 077
preflight="$(mktemp -d "$(dirname -- "$target")/.restore-preflight.XXXXXX")"
trap 'rm -rf -- "$preflight"' EXIT
mkdir -- "$preflight/files"
tar --force-local --extract --file="$bundle/files.tar" --directory="$preflight/files" --no-same-owner --no-same-permissions
backup_inventory "$preflight/files" "$preflight/files.sha256"
cmp -s -- "$preflight/files.sha256" "$bundle/files.sha256" || backup_die 'file archive and inventory do not match; no restore targets created'
trap 'echo "paired restore failed; new targets retained for inspection, no success receipt written" >&2' ERR
if "$native"; then
  bash "$script_dir/postgres-restore.sh" "$bundle/database.dump" "$restore_db" --native
else
  bash "$script_dir/postgres-restore.sh" "$bundle/database.dump" "$restore_db" "$env_file" "$compose_file" "${compose_override:-}"
fi
mkdir -- "$target"
inventory="$preflight/restored.sha256"
rows="$preflight/rows"
tar --force-local --extract --file="$bundle/files.tar" --directory="$target" --no-same-owner --no-same-permissions
backup_inventory "$target" "$inventory"
cmp -s -- "$inventory" "$bundle/files.sha256" || backup_die 'restored content checksum mismatch'
chmod 700 -- "$target"
find "$target" -maxdepth 1 -type f -exec chmod 600 -- {} +
schema="$(pg_exec psql --no-psqlrc --dbname="$restore_db" --tuples-only --no-align --set=ON_ERROR_STOP=1 --command="SELECT value FROM service_meta WHERE key='schema_version'")"
[ "$schema" = "$backup_schema" ] || backup_die 'restored schema does not match backup manifest'
pg_exec psql --no-psqlrc --dbname="$restore_db" --tuples-only --no-align --set=ON_ERROR_STOP=1 --command='SELECT id, size_bytes FROM files WHERE NOT deleting ORDER BY id' > "$rows"
while IFS='|' read -r id size; do
  [ -f "$target/$id" ] && [ "$(wc -c < "$target/$id" | tr -d '[:space:]')" = "$size" ] || backup_die 'restored file metadata/content mismatch'
done < "$rows"
if ! "$native"; then
  image="$(compose images -q postgres)"
  [ -n "$image" ] || backup_die 'PostgreSQL helper image missing'
  docker run --rm --network none --mount "type=bind,source=$target,target=/restore" --entrypoint sh "$image" -ec 'chown -R 10001:10001 /restore; chmod 700 /restore; find /restore -type f -exec chmod 600 {} +'
fi
trap - ERR
echo "paired restore complete: database=$restore_db files=$target schema=$schema build=$backup_build"
echo 'Start the matching API on an isolated loopback endpoint with this database and FILE_STORAGE_DIR; verify accounts, private files and business permissions before admitting traffic.'
