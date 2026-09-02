#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'Pinned SwiftLint installation failed: %s\n' "$1" >&2
  exit 1
}

if [ "$#" -ne 3 ]; then
  fail 'expected archive path, SHA-256 digest, and destination path'
fi

archive_path="$1"
expected_digest="$2"
destination_path="$3"

if [ ! -f "$archive_path" ]; then
  fail 'archive is unavailable'
fi

if [[ ! "$expected_digest" =~ ^[0-9a-f]{64}$ ]]; then
  fail 'expected digest is not a lowercase SHA-256 value'
fi

actual_digest="$(shasum -a 256 "$archive_path" | awk '{print $1}')"
if [ "$actual_digest" != "$expected_digest" ]; then
  fail 'archive digest does not match the reviewed release'
fi

staging_directory="$(mktemp -d "${TMPDIR:-/tmp}/prismbar-swiftlint-install.XXXXXX")"
cleanup() {
  chmod -R u+w "$staging_directory" 2>/dev/null || true
  find "$staging_directory" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if ! unzip -q "$archive_path" swiftlint -d "$staging_directory"; then
  fail 'archive does not contain the expected executable'
fi

if [ ! -f "$staging_directory/swiftlint" ]; then
  fail 'archive does not contain the expected executable'
fi

destination_directory="$(dirname "$destination_path")"
mkdir -p "$destination_directory"
install -m 0755 "$staging_directory/swiftlint" "$destination_path"

printf 'Pinned SwiftLint installation passed digest verification.\n'
