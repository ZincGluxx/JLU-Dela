#!/usr/bin/env bash
export LC_ALL=C

backup_die() {
  echo "$1" >&2
  exit 1
}

backup_database() {
  native=false
  if [ "${1:-}" = --native ]; then
    native=true
    [[ "${PGDATABASE:-}" =~ ^[a-zA-Z0-9_]{1,63}$ ]] || backup_die 'native mode requires a plain PGDATABASE name, never a connection URL'
    for tool in psql pg_dump pg_restore createdb; do
      command -v "$tool" > /dev/null || backup_die "$tool is required"
    done
  else
    command -v docker > /dev/null || backup_die 'docker is required'
    env_file="${1:-$script_dir/.env}"
    compose_file="${2:-$script_dir/compose.yaml}"
    [ -f "$env_file" ] && [ -f "$compose_file" ] || backup_die 'env or Compose file not found'
    compose_args=(--env-file "$env_file" -f "$compose_file")
    if [ -n "${3:-}" ]; then
      [ -f "$3" ] || backup_die 'Compose override not found'
      compose_override="$3"
      compose_args+=(-f "$compose_override")
    fi
  fi
}

compose() {
  docker compose "${compose_args[@]}" "$@"
}

pg_exec() {
  if "$native"; then
    if [ "$1" = psql ]; then
      PGCONNECT_TIMEOUT=5 "$@" | tr -d '\r'
    else
      PGCONNECT_TIMEOUT=5 "$@"
    fi
  else
    compose exec -T postgres sh -c '
      export PGPASSWORD="$POSTGRES_PASSWORD" PGDATABASE="$POSTGRES_DB" PGCONNECT_TIMEOUT=5
      tool="$1"; shift
      exec "$tool" --host=127.0.0.1 --username="$POSTGRES_USER" "$@"
    ' sh "$@"
  fi
}

backup_new_path() {
  local parent base
  parent="$(realpath -e -- "$(dirname -- "$1")")"
  base="$(basename -- "$1")"
  [ "$base" != . ] && [ "$base" != .. ] && [ -n "$base" ] || backup_die 'invalid target path'
  new_path="$parent/$base"
  [ ! -e "$new_path" ] && [ ! -L "$new_path" ] || backup_die "target already exists: $new_path"
}

backup_inventory() {
  local directory="$1" output="$2" path name
  (
    cd -- "$directory"
    shopt -s nullglob dotglob
    for path in *; do
      name="${path##*/}"
      [[ "$name" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] || backup_die 'unexpected file storage entry'
      [ -f "$path" ] && [ ! -L "$path" ] || backup_die 'file storage must contain regular files only'
      sha256sum -- "$name"
    done
  ) > "$output"
}

backup_load_bundle() {
  bundle="$(realpath -e -- "$1")"
  [ -f "$bundle/manifest.env" ] && [ ! -L "$bundle/manifest.env" ] || backup_die 'backup is incomplete: manifest missing'
  local key value
  declare -A record=()
  while IFS='=' read -r key value; do
    case "$key" in
    format | backup_id | recorded_at | app_build | schema_version | source_database | source_files | database_sha256 | archive_sha256 | inventory_sha256 | postgres_version_num | pg_dump_version) ;;
    *) backup_die 'invalid backup manifest field' ;;
    esac
    [ -z "${record[$key]+present}" ] || backup_die 'duplicate backup manifest field'
    record[$key]="$value"
  done < "$bundle/manifest.env"
  case "${record[format]:-}" in
  1) [ "${#record[@]}" -eq 10 ] || backup_die 'invalid backup manifest' ;;
  2)
    [ "${#record[@]}" -eq 12 ] || backup_die 'invalid backup manifest'
    [[ "${record[postgres_version_num]:-}" =~ ^[0-9]{6}$ && "${record[pg_dump_version]:-}" =~ ^[0-9]+\.[0-9]+$ ]] || backup_die 'invalid PostgreSQL version information'
    ;;
  *) backup_die 'unsupported backup manifest format' ;;
  esac
  [[ "${record[backup_id]}" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9]+$ ]] || backup_die 'invalid backup identifier'
  [[ "${record[recorded_at]}" =~ ^[0-9TZ:-]+$ ]] || backup_die 'invalid backup timestamp'
  [[ "${record[app_build]}" =~ ^[a-zA-Z0-9._-]{1,128}$ ]] || backup_die 'invalid application build'
  [[ "${record[schema_version]}" =~ ^[0-9]+$ ]] || backup_die 'invalid schema version'
  for key in database archive inventory; do
    value="${record[${key}_sha256]}"
    [[ "$value" =~ ^[0-9a-f]{64}$ ]] || backup_die 'invalid backup checksum'
  done
  for key in database.dump files.tar files.sha256; do
    [ -f "$bundle/$key" ] && [ ! -L "$bundle/$key" ] || backup_die "backup component missing: $key"
  done
  [ "$(sha256sum "$bundle/database.dump" | cut -d ' ' -f1)" = "${record[database_sha256]}" ] || backup_die 'database checksum mismatch'
  [ "$(sha256sum "$bundle/files.tar" | cut -d ' ' -f1)" = "${record[archive_sha256]}" ] || backup_die 'file archive checksum mismatch'
  [ "$(sha256sum "$bundle/files.sha256" | cut -d ' ' -f1)" = "${record[inventory_sha256]}" ] || backup_die 'file inventory checksum mismatch'
  backup_build="${record[app_build]}"
  backup_schema="${record[schema_version]}"
  source_files="${record[source_files]}"
  source_database="${record[source_database]}"
}
