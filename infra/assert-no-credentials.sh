#!/usr/bin/env bash
set -euo pipefail

log_file="${1:?usage: assert-no-credentials.sh <log-file> [secret-pattern]}"
secret="${2:-ci-secret}"

if grep -Fiq -- "$secret" "$log_file"; then
  echo "credential material found in $log_file" >&2
  exit 1
fi

echo "no credential material found in $log_file"
