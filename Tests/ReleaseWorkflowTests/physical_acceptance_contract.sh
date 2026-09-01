#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

acceptance_script='scripts/record-physical-acceptance.sh'
test -x "$acceptance_script" || {
  printf 'Physical acceptance contract failed: recorder is missing or not executable.\n' >&2
  exit 1
}

bash -n "$acceptance_script"

# The contract intentionally checks literal shell fragments rather than expansion.
# shellcheck disable=SC2016
for required in \
  '/Applications/prismBar.app' \
  'git status --porcelain=v1' \
  'PrismSourceRevision' \
  'Developer ID Application: Patrick LaClair (N8A5T2PZY9)' \
  'TeamIdentifier=N8A5T2PZY9' \
  'codesign --verify --deep --strict' \
  'spctl --assess' \
  'stapler validate' \
  'physical macOS 27' \
  'build/acceptance' \
  'prismBar-physical-$revision.json'; do
  rg -Fq -- "$required" "$acceptance_script" || {
    printf 'Physical acceptance contract failed: recorder is missing %s.\n' "$required" >&2
    exit 1
  }
done

if rg -n -- '--confirm-all|--all|all=true' "$acceptance_script"; then
  printf 'Physical acceptance contract failed: blanket confirmation is forbidden.\n' >&2
  exit 1
fi

fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/prismbar-physical-contract.XXXXXX")"
cleanup() {
  chmod -R u+w "$fixture_root" 2>/dev/null || true
  find "$fixture_root" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM

application="$fixture_root/prismBar.app"
executable="$application/Contents/MacOS/prismBar"
fake_bin="$fixture_root/bin"
evidence_directory="$fixture_root/acceptance"
distribution_evidence="$fixture_root/distribution-evidence.json"
mkdir -p "$(dirname "$executable")" "$fake_bin" "$evidence_directory"
printf 'physical acceptance fixture\n' > "$executable"
chmod 755 "$executable"

revision="$(git rev-parse HEAD)"
plutil -create xml1 "$application/Contents/Info.plist"
plutil -insert CFBundleIdentifier -string com.laclairtech.prismbar "$application/Contents/Info.plist"
plutil -insert PrismSourceRevision -string "$revision" "$application/Contents/Info.plist"
executable_hash="$(shasum -a 256 "$executable" | awk '{print $1}')"

jq -n \
  --arg revision "$revision" \
  --arg executableHash "$executable_hash" \
  '{
    schemaVersion: 1,
    product: "prismBar",
    sourceRevision: $revision,
    sourceState: "clean local commit",
    notarized: true,
    host: {
      identifier: "com.laclairtech.prismbar",
      teamIdentifier: "N8A5T2PZY9",
      executableSHA256: $executableHash
    },
    notarization: {
      applicationStapled: true,
      diskImageStapled: true
    },
    distribution: {
      sha256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  }' > "$distribution_evidence"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ " $* " == *" -dv "* ]]; then' \
  "  printf '%s\\n' 'Authority=Developer ID Application: Patrick LaClair (N8A5T2PZY9)' >&2" \
  "  printf '%s\\n' 'Identifier=com.laclairtech.prismbar' >&2" \
  "  printf '%s\\n' 'TeamIdentifier=N8A5T2PZY9' >&2" \
  'fi' \
  'exit 0' > "$fake_bin/codesign"

printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$fake_bin/spctl"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$fake_bin/xcrun"

chmod 755 "$fake_bin/codesign" "$fake_bin/spctl" "$fake_bin/xcrun"

run_acceptance_with_evidence() {
  local selected_evidence="$1"
  shift
  PATH="$fake_bin:$PATH" \
  PRISMBAR_ACCEPTANCE_TESTING=1 \
  PRISMBAR_ACCEPTANCE_APPLICATION="$application" \
  PRISMBAR_ACCEPTANCE_DISTRIBUTION_EVIDENCE="$selected_evidence" \
  PRISMBAR_ACCEPTANCE_OUTPUT_DIRECTORY="$evidence_directory" \
    "$acceptance_script" "$@"
}

run_acceptance() {
  run_acceptance_with_evidence "$distribution_evidence" "$@"
}

run_acceptance --initialize >/dev/null
physical_evidence="$evidence_directory/prismBar-physical-$revision.json"
jq -e '.result == "incomplete" and (.gates | all(. == false))' "$physical_evidence" >/dev/null

if run_acceptance --confirm light >/dev/null 2>&1; then
  printf 'Physical acceptance contract failed: confirmation omitted the physical-observation acknowledgement.\n' >&2
  exit 1
fi

if run_acceptance --confirm all --observed-on-physical-macos-27 >/dev/null 2>&1; then
  printf 'Physical acceptance contract failed: blanket confirmation was accepted.\n' >&2
  exit 1
fi

run_acceptance --confirm light --observed-on-physical-macos-27 >/dev/null
jq -e '.result == "incomplete" and .gates.light == true and
  ([.gates[] | select(. == true)] | length) == 1' "$physical_evidence" >/dev/null

gates=(
  accessibilityGrant cleanAccountGatekeeper dark fullScreen increasedContrast
  largerText logout menuMovement multipleDisplays permissionRelaunch reboot
  reducedMotion reducedTransparency signedUpgrade sleepWake spaces statusItem voiceOver
)
for gate in "${gates[@]}"; do
  run_acceptance --confirm "$gate" --observed-on-physical-macos-27 >/dev/null
done
jq -e '.result == "passed" and (.gates | all(. == true))' "$physical_evidence" >/dev/null

run_acceptance --invalidate light >/dev/null
jq -e '.result == "incomplete" and .gates.light == false' "$physical_evidence" >/dev/null

printf 'tampered\n' >> "$executable"
if run_acceptance --confirm light --observed-on-physical-macos-27 >/dev/null 2>&1; then
  printf 'Physical acceptance contract failed: changed installed executable was accepted.\n' >&2
  exit 1
fi

printf 'physical acceptance fixture\n' > "$executable"
wrong_revision_evidence="$fixture_root/wrong-revision.json"
jq '.sourceRevision = "0000000000000000000000000000000000000000"' \
  "$distribution_evidence" > "$wrong_revision_evidence"
if run_acceptance_with_evidence "$wrong_revision_evidence" --status >/dev/null 2>&1; then
  printf 'Physical acceptance contract failed: wrong-revision distribution evidence was accepted.\n' >&2
  exit 1
fi

unstapled_evidence="$fixture_root/unstapled.json"
jq '.notarization.applicationStapled = false' \
  "$distribution_evidence" > "$unstapled_evidence"
if run_acceptance_with_evidence "$unstapled_evidence" --status >/dev/null 2>&1; then
  printf 'Physical acceptance contract failed: unstapled distribution evidence was accepted.\n' >&2
  exit 1
fi

printf 'Physical acceptance contract passed: exact installed provenance and individual physical observations fail closed.\n'
