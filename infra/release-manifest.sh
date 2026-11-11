#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: release-manifest.sh record --image <ref@sha256:digest> --commit <sha> --schema-version <n> [--records-dir <dir>]
       release-manifest.sh check --manifest <file> --current-schema <n>
USAGE
  exit 2
}

die() {
  echo "$1" >&2
  exit 1
}

image_pattern='@sha256:[0-9a-f]{64}$'
commit_pattern='^[0-9a-f]{40}$|^[0-9a-f]{64}$'
schema_pattern='^[0-9]+$'

record() {
  local image=''
  local commit=''
  local schema_version=''
  local records_dir="${RELEASE_RECORDS_DIR:-$HOME/jlu-dela-release-records}"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --image)
        [ "$#" -ge 2 ] || usage
        image="$2"
        shift 2
        ;;
      --commit)
        [ "$#" -ge 2 ] || usage
        commit="$2"
        shift 2
        ;;
      --schema-version)
        [ "$#" -ge 2 ] || usage
        schema_version="$2"
        shift 2
        ;;
      --records-dir)
        [ "$#" -ge 2 ] || usage
        records_dir="$2"
        shift 2
        ;;
      *)
        usage
        ;;
    esac
  done

  [[ "$image" =~ $image_pattern ]] || die "image must be pinned by digest: <registry>/<image>@sha256:<64 hex>"
  [[ "$commit" =~ $commit_pattern ]] || die "commit must be a full 40 or 64 character git hash"
  [[ "$schema_version" =~ $schema_pattern ]] || die "schema version must be a non-negative integer"

  mkdir -p -- "$records_dir"

  local stamp
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  local manifest="$records_dir/release-$stamp.env"
  [ ! -e "$manifest" ] || die "release manifest already exists: $manifest"

  {
    printf 'recorded_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'image=%s\n' "$image"
    printf 'commit=%s\n' "$commit"
    printf 'schema_version=%s\n' "$schema_version"
  } > "$manifest"

  echo "release recorded: $manifest"
}

check() {
  local manifest=''
  local current_schema=''

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --manifest)
        [ "$#" -ge 2 ] || usage
        manifest="$2"
        shift 2
        ;;
      --current-schema)
        [ "$#" -ge 2 ] || usage
        current_schema="$2"
        shift 2
        ;;
      *)
        usage
        ;;
    esac
  done

  if [ -z "$manifest" ] || [ -z "$current_schema" ]; then
    usage
  fi
  [ -f "$manifest" ] || die "manifest not found: $manifest"
  [[ "$current_schema" =~ $schema_pattern ]] || die "current schema version must be a non-negative integer"

  local recorded_image recorded_commit recorded_schema
  recorded_image="$(sed -n 's/^image=//p' "$manifest")"
  recorded_commit="$(sed -n 's/^commit=//p' "$manifest")"
  recorded_schema="$(sed -n 's/^schema_version=//p' "$manifest")"

  [[ "$recorded_image" =~ $image_pattern ]] || die "manifest image is not pinned by digest: $manifest"
  [[ "$recorded_commit" =~ $commit_pattern ]] || die "manifest commit is not a full git hash: $manifest"
  [[ "$recorded_schema" =~ $schema_pattern ]] || die "manifest schema version is missing: $manifest"

  echo "rollback target: commit=$recorded_commit image=$recorded_image schema_version=$recorded_schema"

  if [ "$current_schema" -ne "$recorded_schema" ]; then
    echo "rollback blocked: database schema is $current_schema, target release recorded $recorded_schema" >&2
    echo "schema changed since the target release; confirm the old application is compatible before rolling back" >&2
    exit 1
  fi

  echo "rollback check passed: database schema matches the target release"
}

[ "$#" -ge 1 ] || usage
action="$1"
shift

case "$action" in
  record)
    record "$@"
    ;;
  check)
    check "$@"
    ;;
  *)
    usage
    ;;
esac
