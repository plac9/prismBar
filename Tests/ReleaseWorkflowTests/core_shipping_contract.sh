#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'Core shipping contract failed: %s\n' "$1" >&2
  exit 1
}

rg -Fq 'product: prismBarAccessibility' project.yml || \
  fail 'the application must ship the Accessibility engine'
rg -Fq 'product: prismBarEngine' project.yml || \
  fail 'the application must ship the verified menu bar engine'

if rg -Fq 'target: prismCalcPluginService' project.yml; then
  fail 'prismCalc must not be embedded while core recovery is active'
fi
if rg -Fq 'product: prismPluginKit' project.yml; then
  fail 'the core application must not link the dormant plugin framework'
fi
if rg -Fq 'import prismPluginKit' App/AppModel.swift; then
  fail 'the core application model must not initialize dormant plugin state'
fi
if rg -Fq 'prismCalc' Sources/prismBarCore/PresentationCatalog.swift; then
  fail 'the shipping core catalog must not retain a dormant calculator scene'
fi
if rg -Fq 'Tools run in sandboxed services' App/Features/Privacy/PrivacyView.swift; then
  fail 'privacy copy must describe the shipping core rather than dormant tools'
fi
if rg -Fq 'UtilityWindow("prismCalc"' App/prismBarApp.swift; then
  fail 'the core application must not expose a prismCalc utility window'
fi
if rg -Fq 'case tools' Sources/prismBarCore/PresentationCatalog.swift; then
  fail 'the core workspace must not advertise dormant tools'
fi
if rg -Fq 'Text("Prism Deck")' App/Features/Overview/PrismDeckView.swift; then
  fail 'the visible control surface name must use exact prismDeck casing'
fi
for view in App/Features/MenuBar/MenuBarView.swift App/Features/Overview/PrismDeckView.swift; do
  rg -Fq 'sourceAvailabilityNotice(' "$view" || \
    fail 'limited-scan notices must use the collapse-aware presentation'
  rg -Fq 'hiddenSectionCollapsed: model.isHiddenSectionCollapsed' "$view" || \
    fail 'limited-scan notices must respect folded hidden-section state'
done

printf 'Core shipping contract passed.\n'
