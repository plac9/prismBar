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

rg -Fq '.backgroundExtensionEffect()' App/Features/Overview/MainWindowView.swift || {
  fail 'the content canvas no longer extends beneath the native sidebar'
}

rg -Fq 'struct PrismContentSurface' App/Design/PrismVisuals.swift || {
  fail 'the standard-material content surface is missing'
}

printf 'Liquid Glass audit passed: native navigation, standard-material content, and interactive custom glass remain separated.\n'
