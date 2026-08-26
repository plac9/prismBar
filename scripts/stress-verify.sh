#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

fail() {
  printf 'Stress verification failed: %s\n' "$1" >&2
  exit 1
}

for dependency in date git jq swift xcodebuild; do
  command -v "$dependency" >/dev/null 2>&1 || fail "$dependency is unavailable"
done

if [ -n "$(git status --porcelain=v1)" ]; then
  fail 'the repository must be clean so evidence maps to one source revision'
fi

duration_seconds="${PRISMBAR_STRESS_SECONDS:-900}"
case "$duration_seconds" in
  '' | *[!0-9]*) fail 'PRISMBAR_STRESS_SECONDS must be an integer' ;;
esac
if [ "$duration_seconds" -lt 60 ] || [ "$duration_seconds" -gt 21600 ]; then
  fail 'PRISMBAR_STRESS_SECONDS must be between 60 and 21600 seconds'
fi

./scripts/audit-tool-versions.sh
./scripts/audit-licensing.sh
./scripts/audit-public-safety.sh

revision="$(git rev-parse HEAD)"
started_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
started_epoch="$(date '+%s')"
deadline_epoch="$((started_epoch + duration_seconds))"
cycles=0
stress_scratch="$(mktemp -d "${TMPDIR:-/tmp}/prismbar-stress.XXXXXX")"
cleanup() {
  chmod -R u+w "$stress_scratch" 2>/dev/null || true
  find "$stress_scratch" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM

while [ "$(date '+%s')" -lt "$deadline_epoch" ]; do
  swift test --scratch-path "$stress_scratch/SwiftPM"
  UI_DERIVED_DATA_DIR="$stress_scratch/UI-DerivedData" \
    ./scripts/test-ui.sh
  cycles="$((cycles + 1))"
done

completed_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
completed_epoch="$(date '+%s')"
elapsed_seconds="$((completed_epoch - started_epoch))"
evidence_directory="$repository_root/build/stress"
evidence_path="$evidence_directory/prismBar-stress-$revision.json"
mkdir -p "$evidence_directory"

jq -n \
  --arg revision "$revision" \
  --arg startedAt "$started_at" \
  --arg completedAt "$completed_at" \
  --argjson requestedSeconds "$duration_seconds" \
  --argjson elapsedSeconds "$elapsed_seconds" \
  --argjson cycles "$cycles" \
  '{
    schemaVersion: 1,
    product: "prismBar",
    sourceRevision: $revision,
    sourceState: "clean local commit",
    startedAt: $startedAt,
    completedAt: $completedAt,
    requestedDurationSeconds: $requestedSeconds,
    elapsedDurationSeconds: $elapsedSeconds,
    completedCycles: $cycles,
    scopes: [
      "host and window lifecycle",
      "permission state and refresh",
      "synthetic movement invariants",
      "plugin commands and isolation",
      "plugin crash, hang, timeout, and recovery",
      "appearance and accessibility launch variants"
    ],
    result: "passed",
    physicalMovementIncluded: false
  }' > "$evidence_path"

printf 'Stress verification passed: %s complete cycles across %s seconds.\n' \
  "$cycles" "$elapsed_seconds"
printf 'Evidence: %s\n' "$evidence_path"
printf 'Physical signed-app movement stress remains a separate release gate.\n'
