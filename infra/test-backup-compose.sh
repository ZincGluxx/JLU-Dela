#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root="$(mktemp -d)"
trap 'rm -rf -- "$root"' EXIT
mkdir "$root/bin"
: > "$root/synthetic.env"
: > "$root/compose.yaml"
cat > "$root/bin/docker" << 'DOCKER'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = inspect ]; then
  [ "$#" -eq 4 ] && [ "$2" = --format ] && [ "$3" = '{{range .Config.Env}}{{println .}}{{end}}' ] && [ "$4" = synthetic-api ] || exit 90
  printf 'inspect synthetic-api\n' >> "$FAKE_DOCKER_TRACE"
  printf 'APP_BUILD_ID=synthetic\nDATABASE_URL=%s\n' "$FAKE_DATABASE_URL"
  exit 0
fi
[ "${1:-}" = compose ] || exit 91
shift
[ "$#" -ge 5 ] && [ "$1" = --env-file ] && [ "$2" = "$FAKE_ENV_FILE" ] && [ "$3" = -f ] && [ "$4" = "$FAKE_COMPOSE_FILE" ] || exit 92
shift 4
case "$*" in
  'ps -q api')
    printf 'compose ps -q api\n' >> "$FAKE_DOCKER_TRACE"
    printf 'synthetic-api\n'
    ;;
  'images -q postgres')
    printf 'compose images -q postgres\n' >> "$FAKE_DOCKER_TRACE"
    ;;
  *)
    case "$1" in
      exec)
        [ "$#" -eq 13 ] && [ "$2" = -T ] && [ "$3" = postgres ] && [ "$4" = sh ] && [ "$5" = -c ] && [ "$7" = sh ] && [ "$8" = psql ] || exit 93
        [ "$9" = --no-psqlrc ] && [ "${10}" = --tuples-only ] && [ "${11}" = --no-align ] && [ "${12}" = --set=ON_ERROR_STOP=1 ] && [ "${13}" = '--command=SELECT current_database()' ] || exit 94
        printf 'compose exec current_database\n' >> "$FAKE_DOCKER_TRACE"
        printf '%s\n' "$FAKE_CURRENT_DATABASE"
        ;;
      stop|start)
        printf 'compose %s\n' "$1" >> "$FAKE_DOCKER_TRACE"
        exit 95
        ;;
      *)
        printf 'unexpected compose call\n' >> "$FAKE_DOCKER_TRACE"
        exit 96
        ;;
    esac
    ;;
esac
DOCKER
chmod +x "$root/bin/docker"

fail() {
  echo "$1" >&2
  exit 1
}

expect_preflight_failure() {
  local name="$1" database_url="$2" current_database="$3" message="$4" calls="$5"
  local bundle="$root/$name" log="$root/$name.log" trace="$root/$name.trace" status=0
  : > "$trace"
  PATH="$root/bin:$PATH" FAKE_DOCKER_TRACE="$trace" FAKE_DATABASE_URL="$database_url" \
    FAKE_CURRENT_DATABASE="$current_database" FAKE_ENV_FILE="$root/synthetic.env" FAKE_COMPOSE_FILE="$root/compose.yaml" \
    bash "$script_dir/paired-backup.sh" "$bundle" --app-build synthetic --compose "$root/synthetic.env" "$root/compose.yaml" > "$log" 2>&1 || status=$?
  [ "$status" -ne 0 ] || fail "$name: backup unexpectedly succeeded"
  grep -Fxq -- "$message" "$log" || fail "$name: expected preflight diagnostic missing"
  [ ! -e "$bundle" ] && [ ! -L "$bundle" ] || fail "$name: bundle created before maintenance"
  if grep -Eq '^compose (stop|start)( |$)' "$trace"; then
    fail "$name: API stop/start called before preflight rejection"
  fi
  if grep -Fq -- "$database_url" "$log" || grep -Fq -- "$synthetic_password" "$log" || grep -Eq 'postgres(ql)?://' "$log"; then
    fail "$name: database URL or password leaked into logs"
  fi
  printf 'compose ps -q api\ninspect synthetic-api\ninspect synthetic-api\n%s' "$calls" > "$root/expected.trace"
  cmp -s "$root/expected.trace" "$trace" || fail "$name: unexpected Docker call sequence"
  printf 'ok %s: exit=%s, expected trace, no stop/start, no bundle, no URL/password in log\n' "$name" "$status"
}

synthetic_password='synthetic-compose-stub-password'
url="postgresql://synthetic:$synthetic_password@synthetic.invalid/app_db"
exec_trace=$'compose exec current_database\n'
invalid_message='cannot identify a plain API database name'
expect_preflight_failure mismatch "$url" other_db \
  'API and PostgreSQL backup database differ; align the isolated stack configuration before backup' "$exec_trace"
expect_preflight_failure invalid-url "postgresql://synthetic:$synthetic_password@synthetic.invalid/" app_db "$invalid_message" ''
expect_preflight_failure invalid-db-name "postgresql://synthetic:$synthetic_password@synthetic.invalid/app-db" app_db "$invalid_message" ''
expect_preflight_failure plain-db app_db app_db "$invalid_message" ''
expect_preflight_failure matching "$url" app_db 'PostgreSQL helper image missing' "${exec_trace}"$'compose images -q postgres\n'
expect_preflight_failure matching-query "$url?sslmode=require" app_db 'PostgreSQL helper image missing' "${exec_trace}"$'compose images -q postgres\n'
echo 'Compose backup preflight stub tests passed: mismatch, invalid URL/plain database, matching database with and without query'
