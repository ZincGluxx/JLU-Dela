#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo 'usage: paired-backup.sh <new-bundle-dir> --app-build <build> [--native <files-dir> --stop-hook <executable> --start-hook <executable> | --compose <env-file> <compose-file> [override]]' >&2
  exit 2
}
[ "$#" -ge 3 ] || usage
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/backup-common.sh"
backup_new_path "$1"
bundle="$new_path"
shift
build='' mode='' files_dir='' stop_hook='' start_hook=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --app-build) build="${2:?}"; shift 2 ;;
    --native) mode=native; files_dir="${2:?}"; shift 2 ;;
    --stop-hook) stop_hook="${2:?}"; shift 2 ;;
    --start-hook) start_hook="${2:?}"; shift 2 ;;
    --compose) mode=compose; shift; backup_database "$@"; break ;;
    *) usage ;;
  esac
done
[[ "$build" =~ ^[a-zA-Z0-9._-]{1,128}$ ]] || backup_die 'application build must be a safe commit or build identifier'
if [ "$mode" = native ]; then
  backup_database --native
  files_dir="$(realpath -e -- "$files_dir")"
  [ -d "$files_dir" ] && [ "$files_dir" != / ] || backup_die 'invalid source files directory'
  for hook in "$stop_hook" "$start_hook"; do
    [ -f "$hook" ] && [ -x "$hook" ] || backup_die 'native mode requires executable stop and start hooks'
  done
  case "$bundle/" in "$files_dir/"*) backup_die 'backup target must be outside source files' ;; esac
elif [ "$mode" = compose ]; then
  api="$(compose ps -q api)"
  [ -n "$api" ] || backup_die 'API must be running before the maintenance window'
  actual_build="$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$api" | sed -n 's/^APP_BUILD_ID=//p')"
  [ "$actual_build" = "$build" ] || backup_die 'running API build does not match requested backup build'
  image="$(compose images -q postgres)"
  [ -n "$image" ] || backup_die 'PostgreSQL helper image missing'
  files_dir='compose:/var/lib/jlu-dela/files'
else
  usage
fi
umask 077
mkdir -- "$bundle"
resume_needed=false
finish() {
  local status=$?
  trap - EXIT
  if "$resume_needed"; then
    echo 'resuming API after maintenance window' >&2
    if { [ "$mode" = native ] && "$start_hook"; } || { [ "$mode" = compose ] && compose start api; }; then
      echo 'API restart command completed; check health/ready before admitting traffic' >&2
    else
      echo 'API RESTART FAILED: manually run the start hook or Compose start api and check health/ready' >&2
      status=1
    fi
  fi
  if [ "$status" -ne 0 ]; then
    echo "backup failed; directory is incomplete, not a valid recovery point: $bundle" >&2
  fi
  exit "$status"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
resume_needed=true
echo 'pausing API writes; no other writer or migration may run during this window' >&2
if [ "$mode" = native ]; then
  "$stop_hook"
else
  compose stop api
  [ "$(docker inspect --format '{{.State.Running}}' "$api")" = false ] || backup_die 'API did not stop'
fi
schema="$(pg_exec psql --no-psqlrc --tuples-only --no-align --set=ON_ERROR_STOP=1 --command="SELECT value FROM service_meta WHERE key='schema_version'")"
source_database="$(pg_exec psql --no-psqlrc --tuples-only --no-align --set=ON_ERROR_STOP=1 --command='SELECT current_database()')"
[[ "$schema" =~ ^[0-9]+$ ]] || backup_die 'schema version missing'
if [ "$mode" = native ]; then
  pg_exec psql --no-psqlrc --tuples-only --no-align --set=ON_ERROR_STOP=1 --command='SELECT id, size_bytes FROM files WHERE NOT deleting ORDER BY id' > "$bundle/file-rows.pending"
  while IFS='|' read -r id size; do
    [ -f "$files_dir/$id" ] && [ "$(wc -c < "$files_dir/$id" | tr -d '[:space:]')" = "$size" ] || backup_die 'source file metadata/content mismatch'
  done < "$bundle/file-rows.pending"
  rm -f -- "$bundle/file-rows.pending"
  bash "$script_dir/postgres-backup.sh" "$bundle" --native
  backup_inventory "$files_dir" "$bundle/files.sha256"
  tar --force-local --format=ustar -cf "$bundle/files.tar" -C "$files_dir" .
else
  pg_exec psql --no-psqlrc --tuples-only --no-align --set=ON_ERROR_STOP=1 --command='SELECT id, size_bytes FROM files WHERE NOT deleting ORDER BY id' | \
    docker run --rm -i --network none --volumes-from "$api:ro" --entrypoint bash "$image" -c '
      set -euo pipefail
      while IFS="|" read -r id size; do
        path="/var/lib/jlu-dela/files/$id"
        [ -f "$path" ] && [ "$(wc -c < "$path" | tr -d "[:space:]")" = "$size" ] || exit 1
      done
    '
  bash "$script_dir/postgres-backup.sh" "$bundle" "$env_file" "$compose_file" "${compose_override:-}"
  docker run --rm --network none --volumes-from "$api:ro" --entrypoint tar "$image" --format=ustar -cf - -C /var/lib/jlu-dela/files . > "$bundle/files.tar"
  docker run --rm -i --network none --volumes-from "$api:ro" --entrypoint bash "$image" -s <<INNER > "$bundle/files.sha256"
$(declare -f backup_die backup_inventory)
backup_inventory /var/lib/jlu-dela/files /dev/stdout
INNER
fi
shopt -s nullglob
dumps=("$bundle"/*.dump)
[ "${#dumps[@]}" -eq 1 ] || backup_die 'database dump missing'
mv -- "${dumps[0]}" "$bundle/database.dump"
{
  printf 'format=1\nbackup_id=%s-%s\nrecorded_at=%s\n' "$(date -u +%Y%m%dT%H%M%SZ)" "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'app_build=%s\nschema_version=%s\nsource_database=%s\nsource_files=%s\n' "$build" "$schema" "$source_database" "$files_dir"
  printf 'database_sha256=%s\n' "$(sha256sum "$bundle/database.dump" | cut -d ' ' -f1)"
  printf 'archive_sha256=%s\n' "$(sha256sum "$bundle/files.tar" | cut -d ' ' -f1)"
  printf 'inventory_sha256=%s\n' "$(sha256sum "$bundle/files.sha256" | cut -d ' ' -f1)"
} > "$bundle/manifest.pending"
# Restart must succeed before the success manifest is published.
if [ "$mode" = native ]; then "$start_hook"; else compose start api; fi
resume_needed=false
mv -- "$bundle/manifest.pending" "$bundle/manifest.env"
echo "paired backup complete: $bundle"
