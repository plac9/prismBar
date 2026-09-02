#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
verifier="$repository_root/scripts/verify-app-tests.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/prismbar-app-test-boundary.XXXXXX")"

cleanup() {
  chmod -R u+w "$test_root" 2>/dev/null || true
  find "$test_root" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM

run_fixture() {
  local host_version="$1"
  local expected_mode="$2"
  local expected_action="$3"
  local fixture_root="$test_root/$expected_mode"

  mkdir -p "$fixture_root/bin"
  cat > "$fixture_root/bin/sw_vers" <<SCRIPT
#!/usr/bin/env bash
printf '%s\n' '$host_version'
SCRIPT
  cat > "$fixture_root/bin/xcodebuild" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$PRISMBAR_TEST_COMMAND_LOG"
SCRIPT
  chmod +x "$fixture_root/bin/sw_vers" "$fixture_root/bin/xcodebuild"

  PATH="$fixture_root/bin:$PATH" \
    PRISMBAR_TEST_COMMAND_LOG="$fixture_root/command.log" \
    "$verifier" "$fixture_root/DerivedData" '0123456789012345678901234567890123456789' "$fixture_root/result"

  if [ "$(cat "$fixture_root/result")" != "$expected_mode" ]; then
    printf 'Hosted app-test boundary reported the wrong verification mode.\n' >&2
    exit 1
  fi

  if ! rg -q -- "$expected_action" "$fixture_root/command.log"; then
    printf 'Hosted app-test boundary invoked the wrong Xcode action.\n' >&2
    exit 1
  fi
}

run_fixture '26.5.2' 'compiled' 'build-for-testing'
run_fixture '27.0' 'executed' '-only-testing:prismBarAppTests'

printf 'Hosted app-test execution boundary contract passed.\n'
