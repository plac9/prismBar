#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

assurance_sources=(
  DESIGN.md
  docs/IMPLEMENTATION-PLAN.md
  docs/assurance-report.template.html
)

audit_assurance_sources() {
  if rg -n 'PrismBackdrop|PrismLightField|GlassCard|PrismMark' "${assurance_sources[@]}"; then
    printf 'Assurance source audit failed: deleted interface evidence remains.\n' >&2
    exit 1
  fi
  rg -q 'ContentCard' docs/assurance-report.template.html || {
    printf 'Assurance source audit failed: ContentCard evidence is missing.\n' >&2
    exit 1
  }
  rg -q 'contextual SF Symbols' docs/assurance-report.template.html || {
    printf 'Assurance source audit failed: contextual symbol evidence is missing.\n' >&2
    exit 1
  }
}

if [ "${1:-}" = "--source-audit" ]; then
  audit_assurance_sources
  printf 'Assurance source audit passed: evidence names the shipping native interface.\n'
  exit 0
fi

audit_assurance_sources

if [ -n "$(git status --porcelain)" ]; then
  printf 'Assurance reports require a clean committed revision.\n' >&2
  exit 1
fi

./scripts/audit-tool-versions.sh
./scripts/audit-licensing.sh
./scripts/audit-public-safety.sh
swiftlint lint --strict >/dev/null

revision="$(git rev-parse HEAD)"
generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
output_directory="$repository_root/build/assurance"
output_file="$output_directory/prismBar-assurance-$revision.html"
mkdir -p "$output_directory"

automated_class='hold'
automated_status='Exact-revision CI and endurance evidence required'
ci_evidence="$repository_root/build/ci/prismBar-ci-$revision.json"
stress_evidence="$repository_root/build/stress/prismBar-stress-$revision.json"
if [ -f "$ci_evidence" ] && [ -f "$stress_evidence" ]; then
  if jq -e --arg revision "$revision" '
      .schemaVersion == 1 and .product == "prismBar" and
      .sourceRevision == $revision and .sourceState == "clean local commit" and
      .result == "passed"
    ' "$ci_evidence" >/dev/null &&
      jq -e --arg revision "$revision" '
        .schemaVersion == 1 and .product == "prismBar" and
        .sourceRevision == $revision and .sourceState == "clean local commit" and
        .result == "passed" and .completedCycles > 0 and
        .elapsedDurationSeconds >= .requestedDurationSeconds
      ' "$stress_evidence" >/dev/null; then
    automated_class='pass'
    automated_status='Exact-revision CI and endurance evidence passed'
  else
    automated_class='fail'
    automated_status='Exact-revision automated evidence is invalid'
  fi
fi

ui_audit_class='hold'
ui_audit_status='Exact-revision visual audit required'
ui_audit_link=''
ui_audit_evidence="$repository_root/build/ui-audit/prismBar-ui-audit-$revision.json"
ui_audit_report="$repository_root/build/ui-audit/prismBar-ui-audit-$revision.html"
if [ -f "$ui_audit_evidence" ]; then
  if jq -e --arg revision "$revision" '
      .schemaVersion == 1 and .product == "prismBar" and
      .sourceRevision == $revision and .sourceState == "clean local commit" and
      .result == "passed" and .screenshotCount == 9
    ' "$ui_audit_evidence" >/dev/null && [ -s "$ui_audit_report" ]; then
    ui_audit_class='pass'
    ui_audit_status='Eight exact-revision shipping surfaces reviewed'
    ui_audit_link="<a href=\"../ui-audit/prismBar-ui-audit-$revision.html\">Open visual audit</a>"
  else
    ui_audit_class='fail'
    ui_audit_status='Exact-revision visual evidence is invalid'
  fi
fi

physical_class='hold'
physical_status='Physical signed-app matrix required'
physical_evidence="$repository_root/build/acceptance/prismBar-physical-$revision.json"
if [ -f "$physical_evidence" ]; then
  if jq -e --arg revision "$revision" '
      .schemaVersion == 1 and .product == "prismBar" and
      .sourceRevision == $revision and .sourceState == "clean local commit" and
      .result == "passed" and
      (.gates | keys | sort) == ([
        "accessibilityGrant", "cleanAccountGatekeeper", "dark", "fullScreen",
        "increasedContrast", "largerText", "light", "logout", "menuMovement",
        "multipleDisplays", "permissionRelaunch", "plugin", "reboot",
        "reducedMotion", "reducedTransparency", "signedUpgrade", "sleepWake",
        "spaces", "statusItem", "voiceOver"
      ] | sort) and (.gates | all(. == true))
    ' "$physical_evidence" >/dev/null; then
    physical_class='pass'
    physical_status='Physical signed-app matrix passed'
  else
    physical_class='fail'
    physical_status='Physical signed-app evidence is invalid'
  fi
fi

distribution_class='hold'
distribution_status='Exact-revision signed distribution evidence required'
public_class='hold'
public_status='Exact public source revision and owner publication approval required'
distribution_evidence=''
while IFS= read -r candidate; do
  if jq -e --arg revision "$revision" '.sourceRevision == $revision' "$candidate" >/dev/null 2>&1; then
    if [ -n "$distribution_evidence" ]; then
      distribution_class='fail'
      distribution_status='Multiple exact-revision distribution records found'
      distribution_evidence=''
      break
    fi
    distribution_evidence="$candidate"
  fi
done < <(find "$repository_root/build/Distribution" -maxdepth 1 -type f \
  -name 'prismBar-*-evidence.json' -print 2>/dev/null | LC_ALL=C sort)

if [ -n "$distribution_evidence" ]; then
  if jq -e --arg revision "$revision" '
      .schemaVersion == 1 and .product == "prismBar" and
      .sourceRevision == $revision and .sourceState == "clean local commit" and
      .notarized == true and .notarization.applicationStapled == true and
      .notarization.diskImageStapled == true and
      (.host.executableSHA256 | test("^[0-9a-f]{64}$")) and
      (.distribution.sha256 | test("^[0-9a-f]{64}$"))
    ' "$distribution_evidence" >/dev/null; then
    installed_executable='/Applications/prismBar.app/Contents/MacOS/prismBar'
    disk_image="${distribution_evidence%-evidence.json}.dmg"
    if [ ! -f "$disk_image" ] || [ ! -x "$installed_executable" ]; then
      distribution_status='Notarized record passed; local artifact or installed-app proof is unavailable'
    else
      expected_host_hash="$(jq -r '.host.executableSHA256' "$distribution_evidence")"
      expected_disk_image_hash="$(jq -r '.distribution.sha256' "$distribution_evidence")"
      actual_host_hash="$(shasum -a 256 "$installed_executable" | awk '{print $1}')"
      actual_disk_image_hash="$(shasum -a 256 "$disk_image" | awk '{print $1}')"
      if [ "$actual_host_hash" = "$expected_host_hash" ] &&
          [ "$actual_disk_image_hash" = "$expected_disk_image_hash" ]; then
        distribution_class='pass'
        distribution_status='Notarized, stapled, installed, and hash-matched'
      else
        distribution_class='fail'
        distribution_status='Installed app or disk image differs from release evidence'
      fi
    fi

    if [ "$(jq -r '.publicSourceVerified' "$distribution_evidence")" = true ]; then
      public_class='pass'
      public_status='Exact public source revision verified'
    fi
  else
    distribution_class='fail'
    distribution_status='Exact-revision distribution evidence is invalid'
  fi
fi

sed \
  -e "s/{{REVISION}}/$revision/g" \
  -e "s/{{GENERATED_AT}}/$generated_at/g" \
  -e "s|{{AUTOMATED_CLASS}}|$automated_class|g" \
  -e "s|{{AUTOMATED_STATUS}}|$automated_status|g" \
  -e "s|{{UI_AUDIT_CLASS}}|$ui_audit_class|g" \
  -e "s|{{UI_AUDIT_STATUS}}|$ui_audit_status|g" \
  -e "s|{{UI_AUDIT_LINK}}|$ui_audit_link|g" \
  -e "s|{{PHYSICAL_CLASS}}|$physical_class|g" \
  -e "s|{{PHYSICAL_STATUS}}|$physical_status|g" \
  -e "s|{{DISTRIBUTION_CLASS}}|$distribution_class|g" \
  -e "s|{{DISTRIBUTION_STATUS}}|$distribution_status|g" \
  -e "s|{{PUBLIC_CLASS}}|$public_class|g" \
  -e "s|{{PUBLIC_STATUS}}|$public_status|g" \
  docs/assurance-report.template.html > "$output_file"

if rg -n -e '\{\{[A-Z_]+\}\}' "$output_file"; then
  printf 'Assurance report contains unresolved evidence placeholders.\n' >&2
  exit 1
fi

printf 'Assurance report: %s\n' "$output_file"
