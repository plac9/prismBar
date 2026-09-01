#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"
test_selection="${1:-prismBarUITests}"

if [ "$test_selection" = "--source-audit" ]; then
  ./scripts/audit-liquid-glass.sh
  if rg -n 'resultSymbol\(for: message\)|isSuccessfulResult|message\.hasPrefix' App; then
    echo "Menu action feedback is still classified from display text." >&2
    exit 1
  fi
  if rg -n \
      'showSettings\(|settingsWindow|settingsFrameName|CommandGroup\(replacing: \.appSettings\)|openSettings:' \
      App; then
    echo "Legacy Settings ownership or routing remains." >&2
    exit 1
  fi
  settings_scene_count="$(
    rg -l '^[[:space:]]*Settings[[:space:]]*\{' App --glob '*.swift' | wc -l | tr -d ' '
  )"
  if [ "$settings_scene_count" != '1' ]; then
    echo "Exactly one SwiftUI Settings scene is required." >&2
    exit 1
  fi
  if ! rg -q '@Environment\(\\\.openSettings\)' App/Features/Overview/PrismDeckView.swift ||
      ! rg -q 'openSettings\(\)' App/Features/Overview/PrismDeckView.swift; then
    echo "prismDeck must route Settings through SwiftUI OpenSettingsAction." >&2
    exit 1
  fi
  if ! rg -q 'WindowGroup\("prismBar", id: PrismSceneID\.workspace\)' App/prismBarApp.swift; then
    echo "The workspace must be owned by a SwiftUI WindowGroup scene." >&2
    exit 1
  fi
  if ! rg -q '\.defaultLaunchBehavior\(\.suppressed\)' App/prismBarApp.swift; then
    echo "The workspace scene must not appear until the user requests it." >&2
    exit 1
  fi
  if rg -n 'UtilityWindow\("prismCalc"|Open prismCalc|Prism Cards' \
      App/prismBarApp.swift App/Features/Overview/PrismDeckView.swift; then
    echo "Core prismDeck must not expose prismCalc or Prism Cards before physical acceptance." >&2
    exit 1
  fi
  if rg -n 'AppWindowController|NSWindow\(|NSHostingController' App/AppLifecycle.swift App/Features; then
    echo "Manual AppKit ownership remains for a SwiftUI application window." >&2
    exit 1
  fi
  echo "UI source audit passed: native navigation, open content sections, and interactive glass are separated."
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

if [ "$installed_was_running" = true ]; then
  while IFS= read -r installed_pid; do
    kill -TERM "$installed_pid"
  done < <(pgrep -f "^$installed_executable$")

  for _ in {1..50}; do
    if ! pgrep -f "^$installed_executable$" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done

  if pgrep -f "^$installed_executable$" >/dev/null 2>&1; then
    echo "Installed prismBar did not terminate before UI testing." >&2
    exit 1
  fi
fi

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}" \
  xcodebuild \
    -project prismBar.xcodeproj \
    -scheme prismBar \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$ui_derived_data_directory" \
    "PRISM_SOURCE_REVISION=${PRISM_SOURCE_REVISION:-local-development}" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    DEVELOPMENT_TEAM= \
    test \
    "-only-testing:$test_selection"
