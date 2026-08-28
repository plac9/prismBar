#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

document='docs/MACOS-27-COMPATIBILITY.md'

fail() {
  printf 'macOS 27 compatibility audit failed: %s\n' "$1" >&2
  exit 1
}

if [ ! -f "$document" ]; then
  fail 'the compatibility matrix is missing'
fi

required_terms=(
  'https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes'
  'https://github.com/jordanbaird/Ice/issues/954'
  'https://github.com/jordanbaird/Ice/issues/965'
  'https://github.com/jordanbaird/Ice/issues/957'
  'https://github.com/jordanbaird/Ice/issues/955'
  'https://github.com/jordanbaird/Ice/issues/201'
  'MenuBarInputSafetyValidator'
  'physical acceptance pending'
)

for term in "${required_terms[@]}"; do
  if ! rg -Fq "$term" "$document"; then
    fail "the compatibility matrix is missing required evidence: $term"
  fi
done

personal_data_pattern='[/]Users/|[/]var/folders/|Documents[/]Codex|@[A-Za-z0-9.-]*(gmail|icloud|outlook|protonmail)\.'
if rg -q "$personal_data_pattern" "$document"; then
  fail 'the compatibility matrix contains personal information'
fi

printf 'macOS 27 compatibility audit passed: sources, safeguards, and physical gates are recorded.\n'
