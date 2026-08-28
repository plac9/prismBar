#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

test -x scripts/archive-release-candidate.sh || {
  printf 'Archive contract failed: release archive workflow is missing or not executable.\n' >&2
  exit 1
}

bash -n scripts/archive-release-candidate.sh scripts/release-signing-keychain.sh

for required in \
  '--signing-keychain' \
  '--signing-identity' \
  'validate_release_signing_keychain' \
  'CODE_SIGN_IDENTITY="$release_signing_identity"' \
  'OTHER_CODE_SIGN_FLAGS="--keychain $release_signing_keychain"'; do
  rg -Fq -- "$required" scripts/archive-release-candidate.sh || {
    printf 'Archive contract failed: missing %s.\n' "$required" >&2
    exit 1
  }
done

if rg -Fq "CODE_SIGN_IDENTITY='Developer ID Application:" scripts/archive-release-candidate.sh; then
  printf 'Archive contract failed: archive still selects a default-Keychain identity by display name.\n' >&2
  exit 1
fi

if rejection="$('./scripts/archive-release-candidate.sh' \
  --signing-keychain '/tmp/login.keychain-db' \
  --signing-identity '0000000000000000000000000000000000000000' 2>&1)"; then
  printf 'Archive contract failed: a login Keychain path was accepted.\n' >&2
  exit 1
fi

printf '%s\n' "$rejection" | rg -Fq 'must not use a login or system keychain' || {
  printf 'Archive contract failed: login Keychain rejection was not explicit.\n' >&2
  exit 1
}
