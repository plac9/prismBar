#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
fixture_root="$repository_root/.worktrees/.swiftlint-scope-contract"
fixture_path="$fixture_root/GeneratedArtifact.swift"

cleanup() {
  find "$fixture_root" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM

mkdir -p "$fixture_root"
cat > "$fixture_path" <<'FIXTURE'
let generatedArtifact = "This deliberately overlong generated line proves that managed worktree output cannot enter the shipping source lint boundary or make root-checkout verification path-dependent."
FIXTURE

cd "$repository_root"
if ! swiftlint lint --strict --quiet; then
  printf 'SwiftLint scope contract failed: ignored managed worktree output entered lint scope.\n' >&2
  exit 1
fi

printf 'SwiftLint scope contract passed.\n'
