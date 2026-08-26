#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'Tool version audit failed: %s\n' "$1" >&2
  exit 1
}

assert_exact_version() {
  local tool="$1"
  local actual="$2"
  local expected="$3"
  if [ "$actual" != "$expected" ]; then
    fail "$tool is $actual, expected $expected"
  fi
}

assert_exact_version 'XcodeGen' "$(xcodegen --version)" 'Version: 2.46.0'
assert_exact_version 'SwiftLint' "$(swiftlint version)" '0.65.1'
assert_exact_version 'Gitleaks' "$(gitleaks version)" '8.30.1'
assert_exact_version 'actionlint' "$(actionlint --version | head -n 1)" '1.7.12'
assert_exact_version 'ripgrep' "$(rg --version | head -n 1)" 'ripgrep 15.2.0'
assert_exact_version 'jq' "$(jq --version)" 'jq-1.8.2'

swift_version="$(swift --version 2>&1 | rg -m 1 'Apple Swift version')"
if [[ "$swift_version" != *'Apple Swift version 6.4 '* ]]; then
  fail "Swift compiler is outside the approved 6.4 toolchain: $swift_version"
fi

printf 'Build tool version audit passed.\n'
