#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
[ "${PGDATABASE:-}" = paired_backup_script_test ] || {
  echo 'set PGDATABASE=paired_backup_script_test on an isolated PostgreSQL cluster; this test creates it and never drops a database' >&2
  exit 2
}
source "$script_dir/backup-common.sh"
backup_database --native
root="$(mktemp -d)"
echo "synthetic script test artifacts: $root"
pg_exec createdb --maintenance-db=postgres "$PGDATABASE"
pg_exec psql -X --set=ON_ERROR_STOP=1 --command="
  CREATE TABLE service_meta(key text PRIMARY KEY, value text NOT NULL);
  INSERT INTO service_meta VALUES('schema_version','9');
  CREATE TABLE users(id integer);
  CREATE TABLE sessions(id integer);
  CREATE TABLE files(id uuid PRIMARY KEY, size_bytes bigint, deleting boolean DEFAULT false);
  INSERT INTO files VALUES('00000000-0000-4000-8000-000000000001',4,false);" > /dev/null
mkdir "$root/files"
printf 'test' > "$root/files/00000000-0000-4000-8000-000000000001"
printf '#!/usr/bin/env bash\nprintf "stop\\n" >> "%s/hooks.log"\n' "$root" > "$root/stop"
printf '#!/usr/bin/env bash\nprintf "start\\n" >> "%s/hooks.log"\n' "$root" > "$root/start"
printf '#!/usr/bin/env bash\nexit 1\n' > "$root/fail"
chmod +x "$root/stop" "$root/start" "$root/fail"

expect_failure() {
  if "$@" > "$root/last-failure.log" 2>&1; then
    backup_die 'command unexpectedly succeeded'
  fi
}

bash "$script_dir/paired-backup.sh" "$root/good" --app-build synthetic --native "$root/files" --stop-hook "$root/stop" --start-hook "$root/start"
[ -f "$root/good/manifest.env" ]
grep -qx 'format=2' "$root/good/manifest.env"
grep -Eq '^postgres_version_num=[0-9]{6}$' "$root/good/manifest.env"
grep -Eq '^pg_dump_version=[0-9]+\.[0-9]+$' "$root/good/manifest.env"
expect_failure bash "$script_dir/paired-backup.sh" "$root/good" --app-build synthetic --native "$root/files" --stop-hook "$root/stop" --start-hook "$root/start"
starts_before="$(grep -c '^start$' "$root/hooks.log")"
expect_failure bash "$script_dir/paired-backup.sh" "$root/failed-stop" --app-build synthetic --native "$root/files" --stop-hook "$root/fail" --start-hook "$root/start"
[ ! -e "$root/failed-stop/manifest.env" ]
[ "$(grep -c '^start$' "$root/hooks.log")" -eq "$((starts_before + 1))" ]
expect_failure bash "$script_dir/paired-backup.sh" "$root/failed-start" --app-build synthetic --native "$root/files" --stop-hook "$root/stop" --start-hook "$root/fail"
[ ! -e "$root/failed-start/manifest.env" ]
grep -q 'API RESTART FAILED' "$root/last-failure.log"
pg_exec psql -X --set=ON_ERROR_STOP=1 --command="UPDATE files SET size_bytes=5" > /dev/null
expect_failure bash "$script_dir/paired-backup.sh" "$root/missing-content" --app-build synthetic --native "$root/files" --stop-hook "$root/stop" --start-hook "$root/start"
[ ! -e "$root/missing-content/manifest.env" ]
[ "$(tail -1 "$root/hooks.log")" = start ]
pg_exec psql -X --set=ON_ERROR_STOP=1 --command="UPDATE files SET size_bytes=4" > /dev/null
for kind in missing-archive incomplete corrupt corrupt-database mismatched-inventory; do
  mkdir "$root/$kind"
  cp "$root/good/manifest.env" "$root/good/database.dump" "$root/good/files.sha256" "$root/$kind/"
  if [ "$kind" != missing-archive ]; then cp "$root/good/files.tar" "$root/$kind/"; fi
  if [ "$kind" = incomplete ]; then mv "$root/$kind/manifest.env" "$root/$kind/manifest.pending"; fi
  if [ "$kind" = corrupt ]; then printf corrupt >> "$root/$kind/files.tar"; fi
  if [ "$kind" = corrupt-database ]; then printf corrupt >> "$root/$kind/database.dump"; fi
  if [ "$kind" = mismatched-inventory ]; then
    printf '%064d  00000000-0000-4000-8000-000000000001\n' 0 > "$root/$kind/files.sha256"
    checksum="$(sha256sum "$root/$kind/files.sha256" | cut -d ' ' -f1)"
    sed -i "s/^inventory_sha256=.*/inventory_sha256=$checksum/" "$root/$kind/manifest.env"
  fi
  expect_failure bash "$script_dir/paired-restore.sh" "$root/$kind" "paired_${kind//-/_}" "$root/target-$kind" --app-build synthetic --native
  [ ! -e "$root/target-$kind" ]
  [ -z "$(pg_exec psql -X -At --dbname=postgres --command="SELECT 1 FROM pg_database WHERE datname='paired_${kind//-/_}'")" ]
done
[ -z "$(find "$root" -maxdepth 1 -name '.restore-preflight.*' -print -quit)" ]
mkdir "$root/legacy"
cp "$root/good/"* "$root/legacy/"
sed -i '/^postgres_version_num=/d; /^pg_dump_version=/d; s/^format=2$/format=1/' "$root/legacy/manifest.env"
bash "$script_dir/paired-restore.sh" "$root/legacy" paired_legacy_restored "$root/legacy-restored" --app-build synthetic --native
expect_failure bash "$script_dir/paired-restore.sh" "$root/good" paired_wrong_build "$root/wrong-build" --app-build wrong --native
expect_failure bash "$script_dir/paired-restore.sh" "$root/good" "$PGDATABASE" "$root/new-target" --app-build synthetic --native
expect_failure bash "$script_dir/paired-restore.sh" "$root/good" paired_existing_target "$root/files" --app-build synthetic --native
expect_failure bash "$script_dir/paired-restore.sh" "$root/good" paired_overlap "$root/files/child" --app-build synthetic --native
pg_exec createdb --maintenance-db=postgres paired_existing_database
expect_failure bash "$script_dir/paired-restore.sh" "$root/good" paired_existing_database "$root/existing-db-target" --app-build synthetic --native
[ ! -e "$root/existing-db-target" ]
bash "$script_dir/paired-restore.sh" "$root/good" paired_script_test_restored "$root/restored" --app-build synthetic --native
cmp "$root/files/00000000-0000-4000-8000-000000000001" "$root/restored/00000000-0000-4000-8000-000000000001"
[ "$(pg_exec psql -X -At --command='SELECT size_bytes FROM files')" = 4 ]
[ "$(pg_exec psql -X -At --dbname=paired_script_test_restored --command='SELECT size_bytes FROM files')" = 4 ]
echo 'paired script tests passed: success, failure/resume, incomplete/missing/corrupt bundle, build and existing/overlapping targets'
