#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

fail() {
  printf 'Public-safety audit failed: %s\n' "$1" >&2
  exit 1
}

sensitive_artifact_pattern='(^|/)(\.env($|\.)|secrets?(/|$)|.*\.(p8|p12|mobileprovision|provisionprofile|cer|key|pem|token|secret|log|logarchive|tracev3|xcactivitylog|xcresult|xcarchive|dSYM)(/|$))'
if git ls-files -z | rg -z -q "$sensitive_artifact_pattern"; then
  fail 'a credential, diagnostic, archive, or symbol artifact is tracked'
fi

if find . \
  -path './.git' -prune -o \
  -path './build' -prune -o \
  -type f -print0 | rg -z -q "$sensitive_artifact_pattern"; then
  fail 'a credential, diagnostic, archive, or symbol artifact exists outside ignored build output'
fi

if git ls-files -s | awk '$1 == 120000 { found = 1 } END { exit !found }'; then
  fail 'tracked symbolic links are not permitted in the public source tree'
fi

if [ -f .gitmodules ] || [ -n "$(git submodule status 2>/dev/null)" ]; then
  fail 'Git submodules are not permitted'
fi

personal_data_pattern='/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/|/var/folders/|Documents/Codex|@[A-Za-z0-9.-]*(gmail|icloud|outlook|protonmail)\.[A-Za-z]{2,}|(^|[^0-9])(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]{1,3}\.[0-9]{1,3})([^0-9]|$)'
scan_exclusions=(
  -g '!build/**'
  -g '!.git/**'
  -g '!scripts/audit-public-safety.sh'
  -g '!scripts/audit-release-bundle.sh'
)

if rg -I -q --hidden "${scan_exclusions[@]}" "$personal_data_pattern" .; then
  fail 'the working source tree contains a personal path, personal email domain, or private network address'
fi

while IFS= read -r revision; do
  if git grep -I -q -E "$personal_data_pattern" "$revision" -- . \
    ':(exclude)scripts/audit-public-safety.sh' \
    ':(exclude)scripts/audit-release-bundle.sh'; then
    fail 'Git history contains a personal path, personal email domain, or private network address'
  fi
done < <(git rev-list --all)

if git log --all --format='%ae%n%ce' | LC_ALL=C sort -u | \
  rg -v -q '^[0-9]+\+plac9@users\.noreply\.github\.com$'; then
  fail 'Git history contains an author or committer email outside the approved public address'
fi

if git grep -I -q '^version https://git-lfs.github.com/spec/' -- .; then
  fail 'Git LFS pointers are not permitted in the self-contained source release'
fi

if ! rg -q 'on activation, when you refresh' App ||
   ! rg -q 'during requested movement' App; then
  fail 'privacy copy does not disclose every local observation trigger'
fi
if rg -q 'Accessibility is used only when you request' App; then
  fail 'privacy copy incorrectly describes Accessibility as request-only'
fi
if ! rg -q 'does not capture the screen or upload menu titles' App; then
  fail 'privacy copy does not state the capture and upload boundary'
fi

actual_product_urls="$(
  rg -o --no-filename 'https://[^[:space:]\")"]+' App Sources |
    sed 's/[.,;:]$//' |
    LC_ALL=C sort -u
)"
expected_product_urls="$(printf '%s\n%s\n' \
  'https://github.com/plac9/prismBar' \
  'https://mozilla.org/MPL/2.0/' | LC_ALL=C sort)"
if [ "$actual_product_urls" != "$expected_product_urls" ]; then
  fail 'application source contains a URL outside the source and license allowlist'
fi

remote_urls="$(git remote -v | awk '{print $2}' | LC_ALL=C sort -u)"
if [ -n "$remote_urls" ] && printf '%s\n' "$remote_urls" | \
  rg -v -q '^(https://github\.com/plac9/prismBar(\.git)?|git@github\.com:plac9/prismBar\.git)$'; then
  fail 'a Git remote points outside the approved public repository'
fi

printf 'Public-safety audit passed: no sensitive artifacts, personal paths, private addresses, unsafe links, or unapproved remotes.\n'
