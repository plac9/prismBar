#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 2 ]; then
  printf 'Usage: %s INPUT_PBXPROJ OUTPUT_PATH\n' "$0" >&2
  exit 64
fi

input_path="$1"
output_path="$2"
reference_pattern='PBXFileReference; lastKnownFileType = folder; name = ("[^"]+"|[A-Za-z_][A-Za-z0-9_]*); path = \.; sourceTree = SOURCE_ROOT;'
reference_count="$(rg -c "$reference_pattern" "$input_path" || true)"

if [ "$reference_count" != '1' ]; then
  printf 'Expected one root local-package reference in %s, found %s.\n' \
    "$input_path" "${reference_count:-0}" >&2
  exit 1
fi

reference_id="$(rg "$reference_pattern" "$input_path" | awk '{print $1}')"
LOCAL_PACKAGE_REFERENCE_ID="$reference_id" perl -pe '
  if (index($_, $ENV{"LOCAL_PACKAGE_REFERENCE_ID"}) >= 0) {
    if (/PBXFileReference/) {
      $_ = "";
    } else {
      s/\Q$ENV{"LOCAL_PACKAGE_REFERENCE_ID"}\E/LOCAL_PACKAGE_REFERENCE/g;
      s{/\*.*?\*/}{/* LOCAL_PACKAGE */}g;
    }
  }
  END { print "LOCAL_PACKAGE_REFERENCE_DECLARATION\n"; }
' "$input_path" > "$output_path"
