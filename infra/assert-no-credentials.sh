#!/usr/bin/env bash
set -euo pipefail

log_file="${1:?usage: assert-no-credentials.sh <log-file> [secret-pattern]}"
secret="${2:-ci-secret}"

status=0
grep -Fi -- "$secret" "$log_file" > /dev/null || status=$?
if [ "$status" -eq 0 ]; then
  echo "credential material found in $log_file" >&2
  exit 1
fi
if [ "$status" -ne 1 ]; then
  echo "could not check $log_file for credentials" >&2
  exit 2
fi

echo "no credential material found in $log_file"
