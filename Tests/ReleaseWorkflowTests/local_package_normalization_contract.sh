#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
normalizer="$repository_root/scripts/normalize-local-package-reference.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/prismbar-package-reference.XXXXXX")"

cleanup() {
  find "$fixture_root" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM

quoted_input="$fixture_root/quoted.pbxproj"
unquoted_input="$fixture_root/unquoted.pbxproj"
quoted_output="$fixture_root/quoted.normalized"
unquoted_output="$fixture_root/unquoted.normalized"

cat > "$quoted_input" <<'FIXTURE'
ROOT_PACKAGE /* verified-deck-rebuild */ = {isa = PBXFileReference; lastKnownFileType = folder; name = "verified-deck-rebuild"; path = .; sourceTree = SOURCE_ROOT; };
children = (
	ROOT_PACKAGE /* verified-deck-rebuild */,
);
FIXTURE

cat > "$unquoted_input" <<'FIXTURE'
ROOT_PACKAGE /* prismBar */ = {isa = PBXFileReference; lastKnownFileType = folder; name = prismBar; path = .; sourceTree = SOURCE_ROOT; };
children = (
	ROOT_PACKAGE /* prismBar */,
);
FIXTURE

"$normalizer" "$quoted_input" "$quoted_output"
"$normalizer" "$unquoted_input" "$unquoted_output"

if ! cmp -s "$quoted_output" "$unquoted_output"; then
  printf 'Local-package normalization contract failed: quoted and unquoted XcodeGen names differ.\n' >&2
  diff -u "$quoted_output" "$unquoted_output" || true
  exit 1
fi

printf 'Local-package normalization contract passed.\n'
