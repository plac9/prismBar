#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

contract='scripts/release-signing-keychain.sh'
bash -n "$contract"

fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/prismbar-keychain-contract.XXXXXX")"
cleanup() {
  chmod -R u+w "$fixture_root" 2>/dev/null || true
  find "$fixture_root" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM

fake_bin="$fixture_root/bin"
keychain="$fixture_root/prismBar-release.keychain-db"
mkdir -p "$fake_bin"
touch "$keychain"

approved_identity='626EFB4E5115EEBE77068A224D49055F067FFDE8'
other_identity='AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'

write_fake_security() {
  local mode="$1"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    "printf '%s\\n' '  1) $approved_identity \"Developer ID Application: Patrick LaClair (N8A5T2PZY9)\"'" \
    > "$fake_bin/security"
  if [ "$mode" = multiple ]; then
    printf '%s\n' \
      "printf '%s\\n' '  2) $other_identity \"Apple Development: Unexpected (AAAAAAAAAA)\"'" \
      >> "$fake_bin/security"
  fi
  printf '%s\n' 'exit 0' >> "$fake_bin/security"
  chmod 755 "$fake_bin/security"
}

run_validation() {
  PATH="$fake_bin:$PATH" bash -c '
    set -euo pipefail
    fail() { printf "%s\n" "$1" >&2; exit 1; }
    source scripts/release-signing-keychain.sh
    validate_release_signing_keychain "$1" "$2"
  ' _ "$keychain" "$approved_identity"
}

write_fake_security multiple
if run_validation >/dev/null 2>&1; then
  printf 'Release signing keychain contract failed: a keychain with unrelated identities was accepted.\n' >&2
  exit 1
fi

write_fake_security single
run_validation

for required in \
  'exactly one valid code-signing identity' \
  'release_signing_identity' \
  'Developer ID Application: Patrick LaClair (N8A5T2PZY9)'; do
  rg -Fq -- "$required" "$contract" || {
    printf 'Release signing keychain contract failed: missing %s.\n' "$required" >&2
    exit 1
  }
done

printf 'Release signing keychain contract passed: only the approved isolated identity is accepted.\n'
