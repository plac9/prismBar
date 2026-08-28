#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'Physical acceptance failed: %s\n' "$1" >&2
  exit 1
}

usage() {
  printf 'Usage: %s --initialize | --status | --confirm GATE --observed-on-physical-macos-27 | --invalidate GATE\n' "$0" >&2
  exit 64
}

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

for dependency in codesign jq plutil rg shasum spctl xcrun; do
  command -v "$dependency" >/dev/null 2>&1 || fail "required tool is unavailable: $dependency"
done

testing="${PRISMBAR_ACCEPTANCE_TESTING:-0}"
if [ "$testing" != 1 ]; then
  [ -z "${PRISMBAR_ACCEPTANCE_APPLICATION:-}" ] || \
    fail 'the installed application path cannot be overridden outside contract tests'
  [ -z "${PRISMBAR_ACCEPTANCE_DISTRIBUTION_EVIDENCE:-}" ] || \
    fail 'distribution evidence cannot be overridden outside contract tests'
  [ -z "${PRISMBAR_ACCEPTANCE_OUTPUT_DIRECTORY:-}" ] || \
    fail 'the acceptance output directory cannot be overridden outside contract tests'
  [ -z "$(git status --porcelain=v1)" ] || \
    fail 'physical acceptance requires a clean committed revision'
fi

revision="$(git rev-parse HEAD)"
[[ "$revision" =~ ^[0-9a-f]{40}$ ]] || fail 'the source revision is not a complete Git commit'

application_path="${PRISMBAR_ACCEPTANCE_APPLICATION:-/Applications/prismBar.app}"
output_directory="${PRISMBAR_ACCEPTANCE_OUTPUT_DIRECTORY:-$repository_root/build/acceptance}"
output_file="$output_directory/prismBar-physical-$revision.json"

[ -d "$application_path/Contents" ] || fail "the installed application is unavailable at $application_path"
[ ! -L "$application_path" ] || fail 'the installed application must not be a symbolic link'
[ ! -e "$output_directory" ] || [ -d "$output_directory" ] || \
  fail 'the acceptance output path is not a directory'
[ ! -L "$output_directory" ] || fail 'the acceptance output directory must not be a symbolic link'
[ ! -e "$output_file" ] || [ ! -L "$output_file" ] || \
  fail 'the acceptance evidence must not be a symbolic link'

if [ "$testing" != 1 ]; then
  [ "$(uname -m)" = arm64 ] || fail 'physical acceptance requires Apple silicon'
  [[ "$(sw_vers -productVersion)" == 27.* ]] || fail 'physical acceptance requires physical macOS 27'
fi

distribution_evidence="${PRISMBAR_ACCEPTANCE_DISTRIBUTION_EVIDENCE:-}"
if [ -z "$distribution_evidence" ]; then
  while IFS= read -r candidate; do
    if jq -e --arg revision "$revision" '.sourceRevision == $revision' "$candidate" >/dev/null 2>&1; then
      [ -z "$distribution_evidence" ] || \
        fail 'multiple distribution records match the exact source revision'
      distribution_evidence="$candidate"
    fi
  done < <(find "$repository_root/build/Distribution" -maxdepth 1 -type f \
    -name 'prismBar-*-evidence.json' -print 2>/dev/null | LC_ALL=C sort)
fi

[ -n "$distribution_evidence" ] || fail 'exact-revision notarized distribution evidence is unavailable'
[ -f "$distribution_evidence" ] || fail 'distribution evidence is unavailable'
[ ! -L "$distribution_evidence" ] || fail 'distribution evidence must not be a symbolic link'

jq -e --arg revision "$revision" '
  .schemaVersion == 1 and
  .product == "prismBar" and
  .sourceRevision == $revision and
  .sourceState == "clean local commit" and
  .notarized == true and
  .host.identifier == "com.laclairtech.prismbar" and
  .host.teamIdentifier == "N8A5T2PZY9" and
  (.host.executableSHA256 | test("^[0-9a-f]{64}$")) and
  .notarization.applicationStapled == true and
  .notarization.diskImageStapled == true and
  (.distribution.sha256 | test("^[0-9a-f]{64}$"))
' "$distribution_evidence" >/dev/null || \
  fail 'distribution evidence is not a notarized exact-revision prismBar record'

info_plist="$application_path/Contents/Info.plist"
installed_executable="$application_path/Contents/MacOS/prismBar"
[ -f "$info_plist" ] || fail 'the installed application Info.plist is missing'
[ -x "$installed_executable" ] || fail 'the installed prismBar executable is missing'

installed_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_plist")"
installed_revision="$(/usr/libexec/PlistBuddy -c 'Print :PrismSourceRevision' "$info_plist")"
[ "$installed_identifier" = com.laclairtech.prismbar ] || \
  fail 'the installed application has the wrong bundle identifier'
[ "$installed_revision" = "$revision" ] || \
  fail 'the installed application does not match the exact source revision'

codesign --verify --deep --strict "$application_path" >/dev/null 2>&1 || \
  fail 'the installed application signature is invalid'
signature_description="$(codesign -dv --verbose=4 "$application_path" 2>&1)"
printf '%s\n' "$signature_description" | \
  rg -Fxq 'Authority=Developer ID Application: Patrick LaClair (N8A5T2PZY9)' || \
  fail 'the installed application does not use the approved Developer ID identity'
printf '%s\n' "$signature_description" | rg -Fxq 'Identifier=com.laclairtech.prismbar' || \
  fail 'the installed code signature has the wrong identifier'
printf '%s\n' "$signature_description" | rg -Fxq 'TeamIdentifier=N8A5T2PZY9' || \
  fail 'the installed code signature has the wrong Team ID'

spctl --assess --type execute --verbose=4 "$application_path" >/dev/null 2>&1 || \
  fail 'Gatekeeper rejected the installed application'
xcrun stapler validate "$application_path" >/dev/null 2>&1 || \
  fail 'the installed application does not contain a valid notarization ticket'

installed_hash="$(shasum -a 256 "$installed_executable" | awk '{print $1}')"
expected_hash="$(jq -r '.host.executableSHA256' "$distribution_evidence")"
[ "$installed_hash" = "$expected_hash" ] || \
  fail 'the installed executable differs from notarized distribution evidence'
distribution_evidence_hash="$(shasum -a 256 "$distribution_evidence" | awk '{print $1}')"

gates=(
  accessibilityGrant
  cleanAccountGatekeeper
  dark
  fullScreen
  increasedContrast
  largerText
  light
  logout
  menuMovement
  multipleDisplays
  permissionRelaunch
  plugin
  reboot
  reducedMotion
  reducedTransparency
  signedUpgrade
  sleepWake
  spaces
  statusItem
  voiceOver
)

is_known_gate() {
  local requested_gate="$1"
  local gate
  for gate in "${gates[@]}"; do
    [ "$gate" = "$requested_gate" ] && return 0
  done
  return 1
}

mkdir -p "$output_directory"
lock_directory="$output_file.lock"
if ! mkdir "$lock_directory" 2>/dev/null; then
  fail 'another physical acceptance update is in progress'
fi
cleanup_lock() {
  rmdir "$lock_directory" 2>/dev/null || true
}
trap cleanup_lock EXIT INT TERM

write_evidence() {
  local input_file="$1"
  local temporary_file
  temporary_file="$(mktemp "$output_directory/.prismBar-physical.XXXXXX")"
  chmod 600 "$temporary_file"
  jq . "$input_file" > "$temporary_file"
  mv -f "$temporary_file" "$output_file"
}

initialize_evidence() {
  local created_at
  local temporary_source
  created_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  temporary_source="$(mktemp "$output_directory/.prismBar-initialize.XXXXXX")"
  jq -n \
    --arg revision "$revision" \
    --arg createdAt "$created_at" \
    --arg installedHash "$installed_hash" \
    --arg distributionEvidenceHash "$distribution_evidence_hash" \
    '{
      schemaVersion: 1,
      product: "prismBar",
      sourceRevision: $revision,
      sourceState: "clean local commit",
      createdAt: $createdAt,
      updatedAt: $createdAt,
      installed: {
        path: "/Applications/prismBar.app",
        bundleIdentifier: "com.laclairtech.prismbar",
        teamIdentifier: "N8A5T2PZY9",
        executableSHA256: $installedHash,
        gatekeeperAccepted: true,
        notarizationStapled: true
      },
      distributionEvidenceSHA256: $distributionEvidenceHash,
      gates: {
        accessibilityGrant: false,
        cleanAccountGatekeeper: false,
        dark: false,
        fullScreen: false,
        increasedContrast: false,
        largerText: false,
        light: false,
        logout: false,
        menuMovement: false,
        multipleDisplays: false,
        permissionRelaunch: false,
        plugin: false,
        reboot: false,
        reducedMotion: false,
        reducedTransparency: false,
        signedUpgrade: false,
        sleepWake: false,
        spaces: false,
        statusItem: false,
        voiceOver: false
      },
      observations: {},
      result: "incomplete"
    }' > "$temporary_source"
  write_evidence "$temporary_source"
  find "$temporary_source" -delete
}

validate_existing_evidence() {
  [ -f "$output_file" ] || fail 'physical acceptance evidence is not initialized'
  jq -e \
    --arg revision "$revision" \
    --arg installedHash "$installed_hash" \
    --arg distributionEvidenceHash "$distribution_evidence_hash" '
      .schemaVersion == 1 and
      .product == "prismBar" and
      .sourceRevision == $revision and
      .sourceState == "clean local commit" and
      .installed.bundleIdentifier == "com.laclairtech.prismbar" and
      .installed.teamIdentifier == "N8A5T2PZY9" and
      .installed.executableSHA256 == $installedHash and
      .installed.gatekeeperAccepted == true and
      .installed.notarizationStapled == true and
      .distributionEvidenceSHA256 == $distributionEvidenceHash and
      (.gates | keys | sort) == ([
        "accessibilityGrant", "cleanAccountGatekeeper", "dark", "fullScreen",
        "increasedContrast", "largerText", "light", "logout", "menuMovement",
        "multipleDisplays", "permissionRelaunch", "plugin", "reboot",
        "reducedMotion", "reducedTransparency", "signedUpgrade", "sleepWake",
        "spaces", "statusItem", "voiceOver"
      ] | sort) and
      (.gates | all(type == "boolean"))
    ' "$output_file" >/dev/null || fail 'existing physical acceptance evidence is invalid'
}

update_gate() {
  local gate="$1"
  local state="$2"
  local observed_at
  local temporary_source
  observed_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  temporary_source="$(mktemp "$output_directory/.prismBar-update.XXXXXX")"
  if [ "$state" = true ]; then
    jq \
      --arg gate "$gate" \
      --arg observedAt "$observed_at" '
        .gates[$gate] = true |
        .observations[$gate] = {observedAt: $observedAt, environment: "physical macOS 27"} |
        .updatedAt = $observedAt |
        .result = (if (.gates | all(. == true)) then "passed" else "incomplete" end)
      ' "$output_file" > "$temporary_source"
  else
    jq \
      --arg gate "$gate" \
      --arg observedAt "$observed_at" '
        .gates[$gate] = false |
        del(.observations[$gate]) |
        .updatedAt = $observedAt |
        .result = "incomplete"
      ' "$output_file" > "$temporary_source"
  fi
  write_evidence "$temporary_source"
  find "$temporary_source" -delete
}

case "${1:-}" in
  --initialize)
    [ "$#" -eq 1 ] || usage
    if [ -f "$output_file" ]; then
      validate_existing_evidence
    else
      initialize_evidence
    fi
    printf 'Physical acceptance initialized for revision %s.\n' "$revision"
    ;;
  --status)
    [ "$#" -eq 1 ] || usage
    validate_existing_evidence
    jq '{sourceRevision, updatedAt, result, gates}' "$output_file"
    ;;
  --confirm)
    [ "$#" -eq 3 ] || usage
    [ "$3" = --observed-on-physical-macos-27 ] || usage
    is_known_gate "$2" || fail "unknown physical acceptance gate: $2"
    validate_existing_evidence
    update_gate "$2" true
    printf 'Confirmed %s on physical macOS 27.\n' "$2"
    ;;
  --invalidate)
    [ "$#" -eq 2 ] || usage
    is_known_gate "$2" || fail "unknown physical acceptance gate: $2"
    validate_existing_evidence
    update_gate "$2" false
    printf 'Invalidated %s.\n' "$2"
    ;;
  *)
    usage
    ;;
esac
