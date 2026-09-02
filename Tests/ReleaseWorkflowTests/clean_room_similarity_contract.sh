#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

audit_script="$repository_root/scripts/audit-clean-room-similarity.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/prismbar-similarity-contract.XXXXXX")"

cleanup() {
  local status="$?"
  chmod -R u+w "$test_root" 2>/dev/null || true
  find "$test_root" -depth -delete 2>/dev/null || true
  return "$status"
}
trap cleanup EXIT INT TERM

new_tree="$test_root/new"
reference_tree="$test_root/reference"
mkdir -p "$new_tree/Sources" "$reference_tree/Sources"

write_distinct_fixtures() {
  cat > "$new_tree/Sources/Independent.swift" <<'SWIFT'
struct IndependentLayout {
    let columns: Int
    func width(for total: Int) -> Int {
        total / max(columns, 1)
    }
}
SWIFT

  cat > "$reference_tree/Sources/Legacy.swift" <<'SWIFT'
final class LegacyController {
    private var isExpanded = false
    func toggle() {
        isExpanded.toggle()
    }
}
SWIFT
}

write_similar_fixtures() {
  local destination="$1"
  local changed_value="$2"
  cat > "$destination" <<SWIFT
struct SyntheticArrangement {
    let first = 1
    let second = 2
    let third = 3
    let fourth = 4
    let fifth = 5
    let sixth = 6
    let seventh = 7
    let eighth = 8
    let ninth = 9
    let tenth = 10
    let eleventh = 11
    let twelfth = 12
    let thirteenth = 13
    let fourteenth = 14
    let fifteenth = 15
    let sixteenth = 16
    let seventeenth = 17
    let eighteenth = 18
    let changed = $changed_value
}
SWIFT
}

run_audit() {
  PRISMBAR_SIMILARITY_TESTING=1 \
  PRISMBAR_SIMILARITY_NEW_ROOT="$new_tree" \
  PRISMBAR_SIMILARITY_REFERENCE_ROOT="$reference_tree" \
    "$audit_script" 2>&1
}

write_distinct_fixtures
pass_output="$(run_audit)"
printf '%s\n' "$pass_output" | rg -Fq \
  'Clean-room similarity audit passed: no copied or suspiciously similar implementation files detected.'
if printf '%s\n' "$pass_output" | rg -Fq "$test_root"; then
  printf 'Similarity audit exposed an audited path.\n' >&2
  exit 1
fi

cp "$new_tree/Sources/Independent.swift" "$reference_tree/Sources/ExactCopy.swift"
if exact_output="$(run_audit)"; then
  printf 'Similarity audit accepted an exact copied implementation file.\n' >&2
  exit 1
fi
printf '%s\n' "$exact_output" | rg -Fq \
  'Clean-room similarity audit failed: exact implementation content was detected.'
if printf '%s\n' "$exact_output" | rg -Fq 'Independent.swift\|ExactCopy.swift\|struct IndependentLayout'; then
  printf 'Similarity audit exposed reference identifiers or content.\n' >&2
  exit 1
fi

find "$reference_tree/Sources/ExactCopy.swift" -delete
find "$new_tree/Sources/Independent.swift" -delete
find "$reference_tree/Sources/Legacy.swift" -delete
write_similar_fixtures "$new_tree/Sources/Independent.swift" 19
write_similar_fixtures "$reference_tree/Sources/Legacy.swift" 99

if similar_output="$(run_audit)"; then
  printf 'Similarity audit accepted suspiciously similar implementation files.\n' >&2
  exit 1
fi
printf '%s\n' "$similar_output" | rg -Fq \
  'Clean-room similarity audit failed: suspicious normalized similarity was detected.'
if printf '%s\n' "$similar_output" | rg -Fq 'SyntheticArrangement\|Independent.swift\|Legacy.swift'; then
  printf 'Similarity audit exposed reference identifiers or content.\n' >&2
  exit 1
fi

printf 'Clean-room similarity contract passed.\n'
