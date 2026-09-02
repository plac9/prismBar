#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'Application test verification failed: %s\n' "$1" >&2
  exit 1
}

if [ "$#" -ne 3 ]; then
  fail 'expected Derived Data path, source revision, and result path'
fi

derived_data_path="$1"
source_revision="$2"
result_path="$3"

if [[ ! "$source_revision" =~ ^[0-9a-f]{40}$ ]]; then
  fail 'source revision is not a complete Git commit identifier'
fi

host_version="$(sw_vers -productVersion)"
host_major="${host_version%%.*}"
if [[ ! "$host_major" =~ ^[0-9]+$ ]]; then
  fail 'host macOS version is unavailable'
fi

common_arguments=(
  -project prismBar.xcodeproj
  -scheme prismBar
  -derivedDataPath "$derived_data_path"
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  "PRISM_SOURCE_REVISION=$source_revision"
)

mkdir -p "$(dirname "$result_path")"

if [ "$host_major" -ge 27 ]; then
  xcodebuild \
    "${common_arguments[@]}" \
    -destination 'platform=macOS,arch=arm64' \
    test \
    '-only-testing:prismBarAppTests'
  printf 'executed\n' > "$result_path"
  printf 'Application state tests executed on macOS 27 or later.\n'
else
  xcodebuild \
    "${common_arguments[@]}" \
    -destination 'generic/platform=macOS' \
    build-for-testing \
    '-only-testing:prismBarAppTests'
  printf 'compiled\n' > "$result_path"
  printf 'Application state tests compiled for macOS 27; physical execution remains required.\n'
fi
