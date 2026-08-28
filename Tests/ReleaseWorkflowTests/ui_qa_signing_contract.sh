#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

for script in scripts/test-ui.sh scripts/capture-ui-audit.sh; do
  for required in \
    'CODE_SIGN_STYLE=Manual' \
    'CODE_SIGN_IDENTITY=-' \
    'DEVELOPMENT_TEAM='; do
    rg -Fq "$required" "$script" || {
      printf '%s must force local ad-hoc signing with %s.\n' "$script" "$required" >&2
      exit 1
    }
  done
done

for required in \
  '#if DEBUG' \
  '--prismbar-ui-testing' \
  'permitsAdHocUITesting'; do
  rg -Fq -- "$required" \
    App/AppModel.swift App/PluginClient.swift App/UIAuditWindowConfiguration.swift \
    XPC/prismCalcPluginService/ServiceMain.swift || {
    printf 'UI QA signing contract is missing the DEBUG-only plugin trust gate: %s.\n' \
      "$required" >&2
    exit 1
  }
done

rg -Fq -- '#if !DEBUG' XPC/prismCalcPluginService/ServiceMain.swift || {
  printf 'UI QA signing contract requires a DEBUG-only reciprocal trust seam.\n' >&2
  exit 1
}

printf 'UI QA signing contract passed: routine UI automation cannot consult the login Keychain.\n'
