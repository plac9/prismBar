#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

fail() {
  printf 'Release candidate archive failed: %s\n' "$1" >&2
  exit 1
}

for dependency in codesign jq shasum xcodebuild xcodegen; do
  command -v "$dependency" >/dev/null 2>&1 || fail "$dependency is unavailable"
done

if [ -n "$(git status --porcelain=v1)" ]; then
  fail 'the repository must be clean so the artifact maps to one source revision'
fi

if [ "$(git branch --show-current)" != 'main' ]; then
  fail 'release candidates must be built from main'
fi

./scripts/audit-tool-versions.sh
./scripts/audit-licensing.sh
./scripts/audit-public-safety.sh

xcodegen generate >/dev/null
git diff --quiet -- prismBar.xcodeproj || fail 'the generated Xcode project changed'

source_revision="$(git rev-parse HEAD)"
source_tree="$(git rev-parse 'HEAD^{tree}')"
short_revision="$(git rev-parse --short=12 HEAD)"
candidate_directory="build/ReleaseCandidate"
archive_path="$candidate_directory/prismBar-0.1.0-$short_revision.xcarchive"
application_path="$archive_path/Products/Applications/prismBar.app"
plugin_path="$application_path/Contents/XPCServices/prismCalcPluginService.xpc"
evidence_path="$candidate_directory/prismBar-0.1.0-$short_revision-evidence.json"

mkdir -p "$candidate_directory"
if [ -e "$archive_path" ] || [ -e "$evidence_path" ]; then
  fail 'the revision-specific candidate already exists; preserve it or remove it deliberately'
fi

xcodebuild archive \
  -quiet \
  -project prismBar.xcodeproj \
  -scheme prismBar \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$archive_path" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM=N8A5T2PZY9 \
  CODE_SIGN_IDENTITY='Developer ID Application: Patrick LaClair (N8A5T2PZY9)'

codesign --verify --deep --strict --verbose=4 "$application_path"
./scripts/audit-release-bundle.sh "$application_path"
./scripts/audit-live-signing-boundaries.sh "$application_path"

host_identifier="$(codesign -d --verbose=4 "$application_path" 2>&1 | awk -F= '$1 == "Identifier" {print $2}')"
host_team="$(codesign -d --verbose=4 "$application_path" 2>&1 | awk -F= '$1 == "TeamIdentifier" {print $2}')"
plugin_identifier="$(codesign -d --verbose=4 "$plugin_path" 2>&1 | awk -F= '$1 == "Identifier" {print $2}')"
plugin_team="$(codesign -d --verbose=4 "$plugin_path" 2>&1 | awk -F= '$1 == "TeamIdentifier" {print $2}')"

[ "$host_identifier" = 'com.laclairtech.prismbar' ] || fail 'host identifier differs from the release contract'
[ "$plugin_identifier" = 'com.laclairtech.prismbar.plugin.prismcalc' ] || fail 'plugin identifier differs from the release contract'
[ "$host_team" = 'N8A5T2PZY9' ] || fail 'host team differs from the release contract'
[ "$plugin_team" = 'N8A5T2PZY9' ] || fail 'plugin team differs from the release contract'

host_hash="$(shasum -a 256 "$application_path/Contents/MacOS/prismBar" | awk '{print $1}')"
plugin_hash="$(shasum -a 256 "$plugin_path/Contents/MacOS/prismCalcPluginService" | awk '{print $1}')"
privacy_hash="$(shasum -a 256 "$application_path/Contents/Resources/PrivacyInfo.xcprivacy" | awk '{print $1}')"

jq -n \
  --arg generatedAt "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  --arg sourceRevision "$source_revision" \
  --arg sourceTree "$source_tree" \
  --arg hostIdentifier "$host_identifier" \
  --arg hostTeam "$host_team" \
  --arg hostSHA256 "$host_hash" \
  --arg pluginIdentifier "$plugin_identifier" \
  --arg pluginTeam "$plugin_team" \
  --arg pluginSHA256 "$plugin_hash" \
  --arg privacyManifestSHA256 "$privacy_hash" \
  '{
    schemaVersion: 1,
    generatedAt: $generatedAt,
    product: "prismBar",
    version: "0.1.0",
    build: "1",
    sourceRevision: $sourceRevision,
    sourceTree: $sourceTree,
    sourceState: "clean local commit",
    publicSourceVerified: false,
    notarized: false,
    host: {
      identifier: $hostIdentifier,
      teamIdentifier: $hostTeam,
      executableSHA256: $hostSHA256,
      entitlements: []
    },
    plugin: {
      identifier: $pluginIdentifier,
      teamIdentifier: $pluginTeam,
      executableSHA256: $pluginSHA256,
      entitlements: ["com.apple.security.app-sandbox"]
    },
    privacyManifestSHA256: $privacyManifestSHA256
  }' > "$evidence_path"

printf 'Signed local release candidate archived.\n'
printf 'Archive: %s\n' "$archive_path"
printf 'Evidence: %s\n' "$evidence_path"
printf 'Notarization, stapling, public-source verification, packaging, installation, and distribution remain blocked.\n'
