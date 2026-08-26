#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"
test_selection="${1:-prismBarUITests}"

installed_executable='/Applications/prismBar.app/Contents/MacOS/prismBar'
installed_was_running=false
if pgrep -f "^$installed_executable$" >/dev/null 2>&1; then
  installed_was_running=true
fi

restore_installed_application() {
  if [ "$installed_was_running" = true ] &&
      ! pgrep -f "^$installed_executable$" >/dev/null 2>&1 &&
      [ -x "$installed_executable" ]; then
    /usr/bin/open /Applications/prismBar.app
  fi
}
trap restore_installed_application EXIT INT TERM

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}" \
  xcodebuild \
    -project prismBar.xcodeproj \
    -scheme prismBar \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "${UI_DERIVED_DATA_DIR:-$repository_root/build/UI-DerivedData}" \
    test \
    "-only-testing:$test_selection"
