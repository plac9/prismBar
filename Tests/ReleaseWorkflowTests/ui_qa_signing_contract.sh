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

printf 'UI QA signing contract passed: routine UI automation cannot consult the login Keychain.\n'
