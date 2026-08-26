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

sed \
  -e "s/{{REVISION}}/$revision/g" \
  -e "s/{{GENERATED_AT}}/$generated_at/g" \
  docs/assurance-report.template.html > "$output_file"

printf 'Assurance report: %s\n' "$output_file"
