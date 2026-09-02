#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

fail() {
  printf 'Liquid Glass audit failed: %s\n' "$1" >&2
  exit 1
}

if rg -q 'PrismGlassSurface' App; then
  fail 'persistent content still uses the retired glass-card abstraction'
fi

custom_glass_files="$(rg -l '\.glassEffect\(' App || true)"
if [ "$custom_glass_files" != 'App/Features/Overview/PrismRailView.swift' ]; then
  fail 'custom Liquid Glass exists outside the interactive Prism Rail chips'
fi

rg -Fq '.glassEffect(.regular.interactive(), in: .capsule)' \
  App/Features/Overview/PrismRailView.swift || {
  fail 'Prism Rail drag controls are not using interactive Liquid Glass'
}

if rg -Fq '.backgroundExtensionEffect()' App/Features/Overview/MainWindowView.swift; then
  fail 'persistent workspace content still uses a background extension effect'
fi

rg -Fq 'struct PrismContentSection' App/Design/PrismVisuals.swift || {
  fail 'the native content section is missing'
}

rg -Fq 'Color(nsColor: .controlBackgroundColor)' App/Design/PrismVisuals.swift || {
  fail 'informational content is not grouped with a native system surface'
}

rg -Fq '.accessibilityIdentifier("workspace.contentSection")' App/Design/PrismVisuals.swift || {
  fail 'native content groups are not exposed to accessibility verification'
}

if rg -q '\.regularMaterial' App/Design/PrismVisuals.swift; then
  fail 'persistent content sections still create repeated material cards'
fi

if rg -q 'Color\(red:|\.ultraThinMaterial' App/Design/PrismVisuals.swift; then
  fail 'the content canvas still uses hard-coded colors or content-layer material'
fi

rg -Fq '@Environment(\.colorSchemeContrast)' App/Design/PrismVisuals.swift || {
  fail 'the prismatic content canvas does not adapt to Increase Contrast'
}

if rg -q 'PrismCanvasBackground|scrollContentBackground\(\.hidden\)' \
  App/Features/Settings/SettingsRootView.swift; then
  fail 'Settings still replaces the native macOS settings background'
fi

if rg -q '\.largeTitle|design: \.rounded' App/Design/PrismVisuals.swift; then
  fail 'workspace page headers still use oversized custom typography'
fi

if ! rg -Uq 'Text\(message\)\n[[:space:]]+\.font\(\.body\)\n[[:space:]]+\.foregroundStyle\(\.primary\)' \
  App/Design/PrismVisuals.swift; then
  fail 'workspace page copy no longer uses primary semantic contrast'
fi

if rg -q 'foregroundStyle\(\.tertiary\)' App/Features/Overview/OverviewView.swift; then
  fail 'permission guidance still uses tertiary contrast'
fi

if rg -Fq '.background(.regularMaterial, in: .rect(cornerRadius: 16))' \
  App/Features/MenuBar/MenuBarView.swift App/Features/Overview/PrismRailView.swift; then
  fail 'the Menu Bar workspace still wraps native content in material cards'
fi

rg -Fq '.accessibilityActions' App/Features/Overview/PrismRailView.swift || {
  fail 'Rail items do not expose non-drag accessibility actions'
}

rg -Fq 'Move to First Position' App/Features/Overview/PrismRailView.swift || {
  fail 'Rail items do not provide direct positional accessibility actions'
}

printf 'Liquid Glass audit passed: native navigation, semantic content groups, and interactive custom glass remain separated.\n'
