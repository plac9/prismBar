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
