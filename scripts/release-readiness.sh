#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

fail() {
  printf 'Release readiness failed: %s\n' "$1" >&2
  exit 1
}

[ "$#" -eq 6 ] && \
  [ "$1" = '--keychain-profile' ] && \
  [ "$3" = '--signing-keychain' ] && \
  [ "$5" = '--signing-identity' ] || {
  printf 'Usage: %s --keychain-profile PROFILE --signing-keychain PATH --signing-identity CERTIFICATE_SHA1\n' \
    "$0" >&2
  exit 64
}

keychain_profile="$2"
[[ "$keychain_profile" =~ ^[A-Za-z0-9._-]+$ ]] || \
  fail 'the Keychain profile name contains unsupported characters'

for dependency in git jq rg security xcrun; do
  command -v "$dependency" >/dev/null 2>&1 || fail 'a required release tool is unavailable'
done

# shellcheck source=scripts/release-signing-keychain.sh
release_signing_keychain=''
release_signing_identity=''
source scripts/release-signing-keychain.sh
validate_release_signing_keychain "$4" "$6"
printf 'Release readiness: signing identity passed.\n'

[ -z "$(git status --porcelain=v1)" ] || fail 'the repository is not clean'
[ "$(git branch --show-current)" = 'main' ] || fail 'the release revision is not on main'
source_revision="$(git rev-parse HEAD)"

ci_evidence="build/ci/prismBar-ci-$source_revision.json"
ui_evidence="build/ui-audit/prismBar-ui-audit-$source_revision.json"
[ -f "$ci_evidence" ] && [ ! -L "$ci_evidence" ] || \
  fail 'exact-revision CI evidence is unavailable'
[ -f "$ui_evidence" ] && [ ! -L "$ui_evidence" ] || \
  fail 'exact-revision UI evidence is unavailable'

jq -e --arg revision "$source_revision" '
  .schemaVersion == 1 and .product == "prismBar" and
  .sourceRevision == $revision and .sourceState == "clean local commit" and
  .result == "passed"
' "$ci_evidence" >/dev/null || fail 'exact-revision CI evidence is invalid'

jq -e --arg revision "$source_revision" '
  .schemaVersion == 1 and .product == "prismBar" and
  .sourceRevision == $revision and .sourceState == "clean local commit" and
  .result == "passed" and .screenshotCount == 9
' "$ui_evidence" >/dev/null || fail 'exact-revision UI evidence is invalid'
printf 'Release readiness: revision evidence passed.\n'

./scripts/audit-tool-versions.sh >/dev/null 2>&1 || fail 'the toolchain audit failed'
./scripts/audit-licensing.sh >/dev/null 2>&1 || fail 'the licensing audit failed'
./scripts/audit-public-safety.sh >/dev/null 2>&1 || fail 'the public-safety audit failed'
printf 'Release readiness: source audits passed.\n'

if ! xcrun notarytool history \
  --keychain-profile "$keychain_profile" \
  --keychain "$release_signing_keychain" \
  --output-format json >/dev/null 2>&1; then
  fail 'the dedicated notarization profile is unavailable or invalid'
fi
printf 'Release readiness: notarization authentication passed.\n'
printf 'Release readiness passed.\n'
