#!/usr/bin/env bash
set -euo pipefail

base_url="${1:-http://127.0.0.1:8080}"
request_id="compose-smoke-${RANDOM}"

for _ in $(seq 1 60); do
  if curl --fail --silent "$base_url/health/live" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

live_body=$(curl --fail --silent --show-error -H "X-Request-Id: $request_id" "$base_url/health/live")
grep -q '"status":"ok"' <<<"$live_body"
grep -q "\"request_id\":\"$request_id\"" <<<"$live_body"

ready_body=$(curl --fail --silent --show-error "$base_url/health/ready")
grep -q '"status":"ready"' <<<"$ready_body"
grep -Eq '"schema_version":"[0-9]+"' <<<"$ready_body"

meta_body=$(curl --fail --silent --show-error "$base_url/api/v1/meta")
grep -q '"api_version":"v1"' <<<"$meta_body"
grep -q '"service":"jlu-dela-api"' <<<"$meta_body"

not_found_status=$(curl --silent --output /tmp/jlu-dela-smoke-error.json --write-out '%{http_code}' "$base_url/api/v1/unknown")
test "$not_found_status" = "404"
grep -q '"code":"NOT_FOUND"' /tmp/jlu-dela-smoke-error.json

echo "compose smoke passed: $base_url"
