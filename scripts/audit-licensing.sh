#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

fail() {
  printf 'Licensing audit failed: %s\n' "$1" >&2
  exit 1
}

expected_license_checksum='fab3dd6bdab226f1c08630b1dd917e11fcb4ec5e1e020e2c16f83a0a13863e85'
actual_license_checksum="$(shasum -a 256 LICENSE | awk '{print $1}')"
if [ "$actual_license_checksum" != "$expected_license_checksum" ]; then
  fail 'MPL-2.0 license text checksum changed'
fi

dependency_graph="$(swift package show-dependencies --format json)"
if ! jq -e '.name == "prismBar" and .dependencies == []' \
  <<< "$dependency_graph" >/dev/null; then
  fail 'SwiftPM contains an unreviewed external dependency'
fi

while IFS= read -r source_file; do
  if ! head -n 4 "$source_file" | rg -q \
    'This Source Code Form is subject to the terms of the Mozilla Public'; then
    fail "MPL source notice is missing: $source_file"
  fi
done < <(find App Sources Tests XPC -type f -name '*.swift' -print | LC_ALL=C sort)

if ! jq -e '
  .spdxVersion == "SPDX-2.3" and
  .dataLicense == "CC0-1.0" and
  .documentDescribes == ["SPDXRef-Package-prismBar"] and
  (.packages | length) == 1 and
  .packages[0].name == "prismBar" and
  .packages[0].versionInfo == "0.1.0" and
  .packages[0].licenseDeclared == "MPL-2.0" and
  .packages[0].licenseConcluded == "MPL-2.0" and
  .packages[0].filesAnalyzed == false
' sbom.spdx.json >/dev/null; then
  fail 'SPDX source SBOM differs from the approved dependency-free declaration'
fi

printf 'Licensing audit passed: MPL notices and checksum valid, SPDX 2.3 SBOM valid, and no external Swift packages.\n'
