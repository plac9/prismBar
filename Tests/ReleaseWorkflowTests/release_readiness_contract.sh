#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

readiness_script='scripts/release-readiness.sh'
test -x "$readiness_script" || {
  printf 'Release readiness contract failed: readiness workflow is missing.\n' >&2
  exit 1
}

bash -n "$readiness_script" scripts/release-signing-keychain.sh

# These fragments are intentionally source-level release invariants.
# shellcheck disable=SC2016
for required in \
  '--keychain-profile' \
  '--signing-keychain' \
  '--signing-identity' \
  'validate_release_signing_keychain' \
  'git status --porcelain=v1' \
  'git branch --show-current' \
  'prismBar-ci-$source_revision.json' \
  'prismBar-ui-audit-$source_revision.json' \
  'sourceRevision == $revision' \
  'sourceState == "clean local commit"' \
  'result == "passed"' \
  'screenshotCount == 11' \
  'notarytool history' \
  '--keychain-profile "$keychain_profile"' \
  '--keychain "$release_signing_keychain"' \
  'Release readiness passed.'; do
  rg -Fq -- "$required" "$readiness_script" || {
    printf 'Release readiness contract failed: missing required invariant.\n' >&2
    exit 1
  }
done

if rg -n -- '--apple-id|--password|--issuer|--key-id|--key |op read|printenv|\$\{?[A-Z][A-Z0-9_]*(?:\}|\b)' \
  "$readiness_script"; then
  printf 'Release readiness contract failed: credential or environment access is forbidden.\n' >&2
  exit 1
fi

if ./scripts/release-readiness.sh \
  --keychain-profile 'unsafe/profile' \
  --signing-keychain '/tmp/prismBar-release.keychain-db' \
  --signing-identity '0000000000000000000000000000000000000000' >/dev/null 2>&1; then
  printf 'Release readiness contract failed: unsafe Keychain profile was accepted.\n' >&2
  exit 1
fi

if ./scripts/release-readiness.sh \
  --keychain-profile 'prismBar-notary' \
  --signing-keychain 'relative.keychain-db' \
  --signing-identity '0000000000000000000000000000000000000000' >/dev/null 2>&1; then
  printf 'Release readiness contract failed: relative Keychain path was accepted.\n' >&2
  exit 1
fi

printf 'Release readiness contract passed: readiness is exact, non-interactive, and privacy-safe.\n'
