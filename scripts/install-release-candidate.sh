#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

fail() {
  printf 'Release installation failed: %s\n' "$1" >&2
  exit 1
}

[ "$#" -eq 4 ] && [ "$1" = '--disk-image' ] && [ "$3" = '--evidence' ] || {
  printf 'Usage: %s --disk-image PATH --evidence PATH\n' "$0" >&2
  exit 64
}

disk_image_path="$2"
evidence_path="$4"
[[ "$disk_image_path" == /* ]] || fail 'the disk image path must be absolute'
[[ "$evidence_path" == /* ]] || fail 'the evidence path must be absolute'
[ -f "$disk_image_path" ] && [ ! -L "$disk_image_path" ] || fail 'the disk image is unavailable or unsafe'
[ -f "$evidence_path" ] && [ ! -L "$evidence_path" ] || fail 'the evidence is unavailable or unsafe'

distribution_directory="$repository_root/build/Distribution"
case "$disk_image_path" in "$distribution_directory"/*) ;; *) fail 'the disk image is outside the release directory' ;; esac
case "$evidence_path" in "$distribution_directory"/*) ;; *) fail 'the evidence is outside the release directory' ;; esac
[ "$disk_image_path" = "${evidence_path%-evidence.json}.dmg" ] || \
  fail 'the disk image and evidence names do not form one release artifact'

for dependency in codesign diskutil ditto jq killall mv rg shasum spctl xcrun; do
  command -v "$dependency" >/dev/null 2>&1 || fail 'a required installation tool is unavailable'
done

[ -z "$(git status --porcelain=v1)" ] || fail 'the repository must be clean'
[ "$(git branch --show-current)" = 'main' ] || fail 'shipping installation must run from main'
source_revision="$(git rev-parse HEAD)"

jq -e --arg revision "$source_revision" '
  .schemaVersion == 1 and .product == "prismBar" and
  .sourceRevision == $revision and .sourceState == "clean local commit" and
  .notarized == true and
  .notarization.applicationStapled == true and
  .notarization.diskImageStapled == true and
  (.host.executableSHA256 | test("^[0-9a-f]{64}$")) and
  (.distribution.sha256 | test("^[0-9a-f]{64}$"))
' "$evidence_path" >/dev/null || fail 'the distribution evidence is invalid'

expected_disk_image_hash="$(jq -r '.distribution.sha256' "$evidence_path")"
actual_disk_image_hash="$(shasum -a 256 "$disk_image_path" | awk '{print $1}')"
[ "$actual_disk_image_hash" = "$expected_disk_image_hash" ] || fail 'the disk image hash differs from evidence'
codesign --verify --strict --verbose=4 "$disk_image_path" >/dev/null 2>&1 || fail 'the disk image signature is invalid'
xcrun stapler validate "$disk_image_path" >/dev/null 2>&1 || fail 'the disk image staple is invalid'
spctl --assess --type open --context context:primary-signature --verbose=4 "$disk_image_path" >/dev/null 2>&1 || \
  fail 'Gatekeeper rejected the disk image'

mount_point="$(mktemp -d "${TMPDIR:-/tmp}/prismbar-release-mount.XXXXXX")"
mounted=false
staging_root=''
cleanup() {
  if [ "$mounted" = true ]; then
    diskutil eject "$mount_point" >/dev/null 2>&1 || true
  fi
  rmdir "$mount_point" 2>/dev/null || true
  if [ -n "$staging_root" ]; then
    rmdir "$staging_root" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

diskutil image attach "$disk_image_path" -readonly -nobrowse -mountpoint "$mount_point" >/dev/null 2>&1 || \
  fail 'the disk image could not be mounted read-only'
mounted=true
candidate_bundle="$mount_point/prismBar.app"
[ -d "$candidate_bundle" ] && [ ! -L "$candidate_bundle" ] || fail 'the disk image does not contain prismBar'

expected_host_hash="$(jq -r '.host.executableSHA256' "$evidence_path")"
validate_release_bundle() {
  local application_path="$1"
  local signing_details
  local embedded_revision
  local executable_hash

  codesign --verify --deep --strict --verbose=4 "$application_path" >/dev/null 2>&1 || return 1
  xcrun stapler validate "$application_path" >/dev/null 2>&1 || return 1
  spctl --assess --type execute --verbose=4 "$application_path" >/dev/null 2>&1 || return 1
  ./scripts/audit-release-bundle.sh "$application_path" >/dev/null 2>&1 || return 1

  signing_details="$(codesign -d --verbose=4 "$application_path" 2>&1)" || return 1
  printf '%s\n' "$signing_details" | rg -Fq 'Authority=Developer ID Application: Patrick LaClair (N8A5T2PZY9)' || return 1
  printf '%s\n' "$signing_details" | rg -Fq 'TeamIdentifier=N8A5T2PZY9' || return 1
  printf '%s\n' "$signing_details" | rg -Fq 'Identifier=com.laclairtech.prismbar' || return 1

  embedded_revision="$(/usr/libexec/PlistBuddy -c 'Print :PrismSourceRevision' \
    "$application_path/Contents/Info.plist" 2>/dev/null)" || return 1
  [ "$embedded_revision" = "$source_revision" ] || return 1
  executable_hash="$(shasum -a 256 "$application_path/Contents/MacOS/prismBar" | awk '{print $1}')" || return 1
  [ "$executable_hash" = "$expected_host_hash" ]
}

validate_release_bundle "$candidate_bundle" || fail 'the mounted application failed release validation'

staging_root="$(mktemp -d '/Applications/.prismBar-install.XXXXXX')" || \
  fail 'the Applications folder is not writable without privilege escalation'
staged_bundle="$staging_root/prismBar.app"
ditto "$candidate_bundle" "$staged_bundle" >/dev/null 2>&1 || fail 'the application could not be staged'
validate_release_bundle "$staged_bundle" || fail 'the staged application failed release validation'

rollback_directory="$repository_root/build/InstallRollback"
[ ! -L "$rollback_directory" ] || fail 'the rollback directory is unsafe'
mkdir -p "$rollback_directory" 2>/dev/null || fail 'the rollback directory could not be created'
rollback_bundle="$rollback_directory/prismBar-$(date -u '+%Y%m%dT%H%M%SZ')-$source_revision.app"
[ ! -e "$rollback_bundle" ] && [ ! -L "$rollback_bundle" ] || fail 'the rollback destination already exists'

killall prismBar >/dev/null 2>&1 || true

# shellcheck source=scripts/release-installation.sh
source scripts/release-installation.sh
if ! promote_release_bundle \
  "$staged_bundle" '/Applications/prismBar.app' "$rollback_bundle" validate_release_bundle; then
  fail 'promotion failed; the prior application was restored when available'
fi

diskutil eject "$mount_point" >/dev/null
mounted=false
printf 'Release installation passed: notarized prismBar is installed and the prior bundle is preserved for rollback.\n'
