#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

test -x scripts/notarize-release-candidate.sh || {
  printf 'Notarization contract failed: release workflow is missing or not executable.\n' >&2
  exit 1
}

bash -n scripts/notarize-release-candidate.sh scripts/release-signing-keychain.sh

# The contract fragments are intentionally literal shell source.
# shellcheck disable=SC2016
for required in \
  'git status --porcelain=v1' \
  'sourceRevision' \
  '--signing-keychain' \
  '--signing-identity' \
  'validate_release_signing_keychain' \
  '--keychain "$release_signing_keychain"' \
  '[ ! -L "$output_directory" ]' \
  '[ ! -L "$output" ]' \
  'ditto -c -k --keepParent' \
  'notarytool submit' \
  'stapler staple' \
  'stapler validate' \
  'diskutil image create from' \
  'codesign --force' \
  '--sign "$release_signing_identity"' \
  'spctl --assess' \
  'audit-release-bundle.sh' \
  'audit-live-signing-boundaries.sh'; do
  rg -Fq -- "$required" scripts/notarize-release-candidate.sh || {
    printf 'Notarization contract failed: missing %s.\n' "$required" >&2
    exit 1
  }
done

if rg -n 'hdiutil create' scripts/notarize-release-candidate.sh; then
  printf 'Notarization contract failed: deprecated hdiutil creation remains.\n' >&2
  exit 1
fi

if rg -n -- '--apple-id|--password|--issuer|--key-id|--key ' scripts/notarize-release-candidate.sh; then
  printf 'Notarization contract failed: raw notarization credentials are forbidden.\n' >&2
  exit 1
fi

./scripts/notarize-release-candidate.sh --source-audit

if ./scripts/notarize-release-candidate.sh --source-audit unexpected >/dev/null 2>&1; then
  printf 'Notarization contract failed: source audit accepted an extra argument.\n' >&2
  exit 1
fi

if ./scripts/notarize-release-candidate.sh \
  --keychain-profile 'unsafe/profile' \
  --signing-keychain '/tmp/release.keychain-db' \
  --signing-identity '0000000000000000000000000000000000000000' >/dev/null 2>&1; then
  printf 'Notarization contract failed: unsafe Keychain profile name was accepted.\n' >&2
  exit 1
fi
