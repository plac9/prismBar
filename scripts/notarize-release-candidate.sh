#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

fail() {
  printf 'Notarization failed: %s\n' "$1" >&2
  exit 1
}

if [ "${1:-}" = '--source-audit' ]; then
  [ "$#" -eq 1 ] || fail 'source audit accepts no additional arguments'
  printf 'Notarization source audit passed: dedicated-Keychain authentication and signed disk-image validation are required.\n'
  exit 0
fi

[ "$#" -eq 6 ] && \
  [ "$1" = '--keychain-profile' ] && \
  [ "$3" = '--signing-keychain' ] && \
  [ "$5" = '--signing-identity' ] || {
  printf 'Usage: %s --keychain-profile PROFILE --signing-keychain PATH --signing-identity CERTIFICATE_SHA1\n' "$0" >&2
  exit 64
}

keychain_profile="$2"
[[ "$keychain_profile" =~ ^[A-Za-z0-9._-]+$ ]] || fail 'the Keychain profile name contains unsupported characters'

for dependency in codesign diskutil ditto find jq rg security shasum spctl xcodebuild xcrun; do
  command -v "$dependency" >/dev/null 2>&1 || fail "$dependency is unavailable"
done

# shellcheck source=scripts/release-signing-keychain.sh
source scripts/release-signing-keychain.sh
validate_release_signing_keychain "$4" "$6"

[ -z "$(git status --porcelain=v1)" ] || fail 'the repository must be clean'
[ "$(git branch --show-current)" = 'main' ] || fail 'release candidates must come from main'

./scripts/audit-tool-versions.sh
./scripts/audit-licensing.sh
./scripts/audit-public-safety.sh

source_revision="$(git rev-parse HEAD)"
short_revision="$(git rev-parse --short=12 HEAD)"
candidate_directory="$repository_root/build/ReleaseCandidate"
[ ! -L "$candidate_directory" ] || fail 'candidate directory must not be a symbolic link'
archive_matches=()
while IFS= read -r candidate_path; do
  archive_matches+=("$candidate_path")
done < <(find "$candidate_directory" -maxdepth 1 -type d \
  -name "prismBar-*-$short_revision.xcarchive" -print)
evidence_matches=()
while IFS= read -r candidate_path; do
  evidence_matches+=("$candidate_path")
done < <(find "$candidate_directory" -maxdepth 1 -type f \
  -name "prismBar-*-$short_revision-evidence.json" -print)

[ "${#archive_matches[@]}" -eq 1 ] && [ -d "${archive_matches[0]}" ] || \
  fail 'exactly one current-revision archive is required'
[ "${#evidence_matches[@]}" -eq 1 ] && [ -f "${evidence_matches[0]}" ] || \
  fail 'exactly one current-revision evidence file is required'

archive_path="${archive_matches[0]}"
evidence_path="${evidence_matches[0]}"
application_path="$archive_path/Products/Applications/prismBar.app"
plugin_path="$application_path/Contents/XPCServices/prismCalcPluginService.xpc"

[ "$(jq -r '.sourceRevision' "$evidence_path")" = "$source_revision" ] || \
  fail 'candidate evidence does not match the current source revision'
[ "$(jq -r '.sourceState' "$evidence_path")" = 'clean local commit' ] || \
  fail 'candidate evidence does not describe a clean source state'
[ -d "$application_path" ] && [ -d "$plugin_path" ] || fail 'candidate application is incomplete'
bundle_source_revision="$(/usr/libexec/PlistBuddy -c 'Print :PrismSourceRevision' \
  "$application_path/Contents/Info.plist")"
[ "$bundle_source_revision" = "$source_revision" ] || \
  fail 'candidate application does not embed the current source revision'

codesign --verify --deep --strict --verbose=4 "$application_path"
./scripts/audit-release-bundle.sh "$application_path"
./scripts/audit-live-signing-boundaries.sh "$application_path"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$application_path/Contents/Info.plist")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$application_path/Contents/Info.plist")"
artifact_stem="prismBar-$version-$build_number-$short_revision"
distribution_directory="$repository_root/build/Distribution"
notarization_directory="$repository_root/build/Notarization"
disk_image_path="$distribution_directory/$artifact_stem.dmg"
disk_image_evidence_path="$distribution_directory/$artifact_stem-evidence.json"
application_submission_path="$notarization_directory/$artifact_stem-app.zip"
application_result_path="$notarization_directory/$artifact_stem-app-result.json"
disk_image_result_path="$notarization_directory/$artifact_stem-dmg-result.json"

for output_directory in "$distribution_directory" "$notarization_directory"; do
  [ ! -L "$output_directory" ] || fail 'release output directories must not be symbolic links'
done

for output in \
  "$disk_image_path" \
  "$disk_image_evidence_path" \
  "$application_submission_path" \
  "$application_result_path" \
  "$disk_image_result_path"; do
  [ ! -e "$output" ] && [ ! -L "$output" ] || \
    fail 'revision-specific notarization output already exists'
done

mkdir -p "$distribution_directory" "$notarization_directory"
staging_root="$(mktemp -d "${TMPDIR:-/tmp}/prismbar-notarize.XXXXXX")"
cleanup() {
  chmod -R u+w "$staging_root" 2>/dev/null || true
  find "$staging_root" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM

ditto -c -k --keepParent "$application_path" "$application_submission_path"
xcrun notarytool submit \
  "$application_submission_path" \
  --keychain-profile "$keychain_profile" \
  --keychain "$release_signing_keychain" \
  --wait \
  --output-format json > "$application_result_path"

[ "$(jq -r '.status' "$application_result_path")" = 'Accepted' ] || \
  fail 'Apple did not accept the application submission'
jq -e '.id | type == "string" and length > 0' "$application_result_path" >/dev/null || \
  fail 'Apple application result did not contain a submission identifier'

xcrun stapler staple "$application_path"
xcrun stapler validate "$application_path"
codesign --verify --deep --strict --verbose=4 "$application_path"
spctl --assess --type execute --verbose=4 "$application_path"
./scripts/audit-release-bundle.sh "$application_path"
./scripts/audit-live-signing-boundaries.sh "$application_path"

disk_image_root="$staging_root/disk-image"
mkdir -p "$disk_image_root"
ditto "$application_path" "$disk_image_root/prismBar.app"
ln -s /Applications "$disk_image_root/Applications"
diskutil image create from \
  --format UDZO \
  --volumeName prismBar \
  "$disk_image_root" \
  "$disk_image_path"

codesign --force \
  --keychain "$release_signing_keychain" \
  --sign "$release_signing_identity" \
  --timestamp \
  "$disk_image_path"
codesign --verify --strict --verbose=4 "$disk_image_path"

xcrun notarytool submit \
  "$disk_image_path" \
  --keychain-profile "$keychain_profile" \
  --keychain "$release_signing_keychain" \
  --wait \
  --output-format json > "$disk_image_result_path"

[ "$(jq -r '.status' "$disk_image_result_path")" = 'Accepted' ] || \
  fail 'Apple did not accept the disk image submission'
jq -e '.id | type == "string" and length > 0' "$disk_image_result_path" >/dev/null || \
  fail 'Apple disk-image result did not contain a submission identifier'

xcrun stapler staple "$disk_image_path"
xcrun stapler validate "$disk_image_path"
codesign --verify --strict --verbose=4 "$disk_image_path"
spctl --assess --type open --context context:primary-signature --verbose=4 "$disk_image_path"

host_hash="$(shasum -a 256 "$application_path/Contents/MacOS/prismBar" | awk '{print $1}')"
plugin_hash="$(shasum -a 256 "$plugin_path/Contents/MacOS/prismCalcPluginService" | awk '{print $1}')"
disk_image_hash="$(shasum -a 256 "$disk_image_path" | awk '{print $1}')"
application_submission_id="$(jq -r '.id' "$application_result_path")"
disk_image_submission_id="$(jq -r '.id' "$disk_image_result_path")"

jq \
  --arg generatedAt "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  --arg hostSHA256 "$host_hash" \
  --arg pluginSHA256 "$plugin_hash" \
  --arg applicationSubmissionID "$application_submission_id" \
  --arg diskImageSubmissionID "$disk_image_submission_id" \
  --arg diskImageSHA256 "$disk_image_hash" \
  '.generatedAt = $generatedAt
   | .notarized = true
   | .host.executableSHA256 = $hostSHA256
   | .plugin.executableSHA256 = $pluginSHA256
   | .notarization = {
       applicationSubmissionID: $applicationSubmissionID,
       diskImageSubmissionID: $diskImageSubmissionID,
       applicationStapled: true,
       diskImageStapled: true
     }
   | .distribution = {
       format: "signed notarized APFS disk image",
       sha256: $diskImageSHA256
     }' \
  "$evidence_path" > "$disk_image_evidence_path"

./scripts/audit-public-safety.sh

printf 'Notarized release candidate created.\n'
printf 'Disk image: %s\n' "$disk_image_path"
printf 'Evidence: %s\n' "$disk_image_evidence_path"
printf 'Publication and distribution remain owner-gated.\n'
