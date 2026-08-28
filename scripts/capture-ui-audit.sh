#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

fail() {
  printf 'UI audit capture failed: %s\n' "$1" >&2
  exit 1
}

if [ "$#" -ne 0 ]; then
  fail 'this workflow does not accept arguments'
fi

for dependency in git jq xcodebuild xcrun; do
  command -v "$dependency" >/dev/null 2>&1 || fail "$dependency is unavailable"
done

if [ -n "$(git status --porcelain=v1)" ]; then
  fail 'a clean committed revision is required'
fi

revision="$(git rev-parse HEAD)"
capture_root="$(mktemp -d "$repository_root/build/ui-audit-$(date '+%Y%m%d-%H%M')-XXXX")"
result_bundle="$capture_root/prismBar-ui.xcresult"
attachments_directory="$capture_root/screenshots"
installed_executable='/Applications/prismBar.app/Contents/MacOS/prismBar'
installed_was_running=false

if pgrep -f "^$installed_executable$" >/dev/null 2>&1; then
  installed_was_running=true
  while IFS= read -r installed_pid; do
    kill -TERM "$installed_pid"
  done < <(pgrep -f "^$installed_executable$")

  for _ in {1..50}; do
    if ! pgrep -f "^$installed_executable$" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done
  pgrep -f "^$installed_executable$" >/dev/null 2>&1 &&
    fail 'the installed app did not terminate before UI capture'
fi

restore_installed_application() {
  if [ "$installed_was_running" = true ] &&
      ! pgrep -f "^$installed_executable$" >/dev/null 2>&1 &&
      [ -x "$installed_executable" ]; then
    open /Applications/prismBar.app
  fi
}
trap restore_installed_application EXIT INT TERM

printf 'Capturing privacy-safe UI evidence for revision %s.\n' "$revision"
xcodebuild \
  -project prismBar.xcodeproj \
  -scheme prismBar \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$capture_root/DerivedData" \
  -resultBundlePath "$result_bundle" \
  "PRISM_SOURCE_REVISION=$revision" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  test '-only-testing:prismBarUITests/VisualAuditTests'

xcrun xcresulttool export attachments \
  --path "$result_bundle" \
  --output-path "$attachments_directory"

./scripts/generate-ui-audit-report.sh "$capture_root"

evidence_path="$repository_root/build/ui-audit/prismBar-ui-audit-$revision.json"
jq -e --arg revision "$revision" '
  .sourceRevision == $revision and .sourceState == "clean local commit" and
  .screenshotCount == 9 and .result == "passed"
' "$evidence_path" >/dev/null || fail 'revision-bound evidence validation failed'

printf 'UI audit capture passed: %s\n' "$capture_root"
