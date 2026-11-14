#!/usr/bin/env bash
set -euo pipefail

[ "$#" -ge 1 ] || {
  echo 'usage: postgres-backup.sh <output-dir> [--native | env-file compose-file compose-override]' >&2
  exit 2
}
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/backup-common.sh"
backup_dir="$1"
shift
backup_database "$@"
umask 077
mkdir -p -- "$backup_dir"
backup_dir="$(realpath -e -- "$backup_dir")"
final_file="$backup_dir/jlu-dela-postgres-$(date -u +%Y%m%dT%H%M%SZ)-$$.dump"
[ ! -e "$final_file" ] || backup_die 'backup file already exists'
tmp_file="$(mktemp "$backup_dir/.postgres-backup.XXXXXX")"
trap 'rm -f -- "$tmp_file"' EXIT
pg_exec pg_dump --format=custom --no-owner --no-privileges > "$tmp_file"
pg_exec pg_restore --list < "$tmp_file" > /dev/null
mv -- "$tmp_file" "$final_file"
trap - EXIT
echo "database-only backup written: $final_file ($(wc -c < "$final_file") bytes)"
