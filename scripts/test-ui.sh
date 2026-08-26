#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"
test_selection="${1:-prismBarUITests}"

if [ "$test_selection" = "--source-audit" ]; then
  if rg -n 'PrismBackdrop|PrismLightField|PrismRay|PrismMark|GlassCard|GlassEffectContainer|\.glassEffect\(' \
      App/Features App/Design/PrismVisuals.swift; then
    echo "Decorative content glass or obsolete page artwork remains." >&2
    exit 1
  fi
  if rg -n 'resultSymbol\(for: message\)|isSuccessfulResult|message\.hasPrefix' App; then
    echo "Menu action feedback is still classified from display text." >&2
    exit 1
  fi
  echo "UI source audit passed: content uses semantic surfaces and native interactive glass only."
  exit 0
fi

installed_executable='/Applications/prismBar.app/Contents/MacOS/prismBar'
installed_was_running=false
ui_scratch_is_temporary=false
ui_derived_data_directory="${UI_DERIVED_DATA_DIR:-}"
if [ -z "$ui_derived_data_directory" ]; then
  ui_derived_data_directory="$(mktemp -d "${TMPDIR:-/tmp}/prismbar-ui.XXXXXX")"
  ui_scratch_is_temporary=true
fi
if pgrep -f "^$installed_executable$" >/dev/null 2>&1; then
  installed_was_running=true
fi

cleanup() {
  if [ "$installed_was_running" = true ] &&
      ! pgrep -f "^$installed_executable$" >/dev/null 2>&1 &&
      [ -x "$installed_executable" ]; then
    /usr/bin/open /Applications/prismBar.app
  fi
  if [ "$ui_scratch_is_temporary" = true ]; then
    chmod -R u+w "$ui_derived_data_directory" 2>/dev/null || true
    find "$ui_derived_data_directory" -depth -delete 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}" \
  xcodebuild \
    -project prismBar.xcodeproj \
    -scheme prismBar \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$ui_derived_data_directory" \
    test \
    "-only-testing:$test_selection"
