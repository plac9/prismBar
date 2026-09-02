#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
synthetic_ref='refs/prismbar-contract/github-merge'

cleanup() {
  git update-ref -d "$synthetic_ref" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

synthetic_commit="$(
  printf 'Synthetic GitHub pull request merge\n' | env \
    GIT_AUTHOR_NAME='GitHub' \
    GIT_AUTHOR_EMAIL='20830695+plac9@users.noreply.github.com' \
    GIT_COMMITTER_NAME='GitHub' \
    GIT_COMMITTER_EMAIL='noreply@github.com' \
    git commit-tree "$(git rev-parse HEAD^{tree})" -p HEAD
)"
git update-ref "$synthetic_ref" "$synthetic_commit"

"$repository_root/scripts/audit-public-safety.sh"

printf 'GitHub synthetic merge public-safety contract passed.\n'
