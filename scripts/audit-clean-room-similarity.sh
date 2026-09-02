#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'Clean-room similarity audit failed: %s\n' "$1" >&2
  exit 1
}

for dependency in awk comm find git mktemp rg sed shasum sort tar tr wc; do
  command -v "$dependency" >/dev/null 2>&1 || fail 'a required local audit tool is unavailable.'
done

testing="${PRISMBAR_SIMILARITY_TESTING:-0}"
repository_root="$(git rev-parse --show-toplevel)"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/prismbar-clean-room-audit.XXXXXX")"

cleanup() {
  local status="$?"
  chmod -R u+w "$temporary_root" 2>/dev/null || true
  find "$temporary_root" -depth -delete 2>/dev/null || true
  return "$status"
}
trap cleanup EXIT INT TERM

if [ "$testing" = 1 ]; then
  new_root="${PRISMBAR_SIMILARITY_NEW_ROOT:-}"
  reference_root="${PRISMBAR_SIMILARITY_REFERENCE_ROOT:-}"
  [ -d "$new_root" ] && [ -d "$reference_root" ] || \
    fail 'synthetic audit roots are unavailable.'
else
  [ -z "${PRISMBAR_SIMILARITY_NEW_ROOT:-}" ] || \
    fail 'the clean source root cannot be overridden.'
  [ -z "${PRISMBAR_SIMILARITY_REFERENCE_ROOT:-}" ] || \
    fail 'the reference root cannot be overridden.'
  [ -z "$(git status --porcelain=v1)" ] || \
    fail 'the clean source repository must be committed before the audit.'

  new_root="$repository_root"
  frozen_reference="$(dirname "$repository_root")/prismBar-gpl-reference"
  [ -d "$frozen_reference/.git" ] || fail 'the frozen GPL reference repository is unavailable.'
  [ "$(git -C "$frozen_reference" remote get-url --push origin)" = DISABLED ] || \
    fail 'the frozen GPL reference push URL is enabled.'
  [ "$(git -C "$frozen_reference" remote get-url --push upstream)" = DISABLED ] || \
    fail 'the frozen GPL upstream push URL is enabled.'

  reference_root="$temporary_root/reference"
  mkdir -p "$reference_root"
  git -C "$frozen_reference" archive HEAD | tar -xf - -C "$reference_root"
fi

[ "$(cd "$new_root" && pwd -P)" != "$(cd "$reference_root" && pwd -P)" ] || \
  fail 'the clean and reference roots must be different.'

collect_files() {
  local root="$1"
  find "$root" \
    -type d \( -name .git -o -name .build -o -name build -o -name DerivedData \
      -o -name xcuserdata -o -name node_modules \) -prune -o \
    -type f \( \
      -name '*.swift' -o -name '*.sh' -o -name '*.py' -o -name '*.js' \
      -o -name '*.ts' -o -name '*.json' -o -name '*.yml' -o -name '*.yaml' \
      -o -name '*.plist' -o -name '*.xcprivacy' -o -name '*.md' \
      -o -name '*.png' -o -name '*.icns' -o -name '*.pdf' \
    \) ! -name LICENSE -size +79c -print0
}

new_files=()
reference_files=()
while IFS= read -r -d '' file; do new_files+=("$file"); done < <(collect_files "$new_root")
while IFS= read -r -d '' file; do reference_files+=("$file"); done < <(collect_files "$reference_root")

new_hashes=()
reference_hashes=()
for file in "${new_files[@]}"; do
  new_hashes+=("$(shasum -a 256 "$file" | awk '{print $1}')")
done
for file in "${reference_files[@]}"; do
  reference_hashes+=("$(shasum -a 256 "$file" | awk '{print $1}')")
done

for new_hash in "${new_hashes[@]}"; do
  for reference_hash in "${reference_hashes[@]}"; do
    [ "$new_hash" != "$reference_hash" ] || \
      fail 'exact implementation content was detected.'
  done
done

similarity_threshold=85
minimum_combined_lines=30
normalized_root="$temporary_root/normalized"
mkdir -p "$normalized_root/new" "$normalized_root/reference"

normalize_source() {
  local input="$1"
  local output="$2"
  sed -E 's#//.*$##; s/[[:space:]]+//g; /^$/d' "$input" | LC_ALL=C sort -u > "$output"
}

new_source_extensions=()
new_normalized_files=()
new_normalized_counts=()
new_index=0
for new_file in "${new_files[@]}"; do
  case "$new_file" in
    *.swift|*.sh|*.py|*.js|*.ts) ;;
    *) continue ;;
  esac
  normalized_file="$normalized_root/new/$new_index"
  normalize_source "$new_file" "$normalized_file"
  normalized_count="$(wc -l < "$normalized_file" | tr -d '[:space:]')"
  new_source_extensions+=("${new_file##*.}")
  new_normalized_files+=("$normalized_file")
  new_normalized_counts+=("$normalized_count")
  new_index=$((new_index + 1))
done

reference_source_extensions=()
reference_normalized_files=()
reference_normalized_counts=()
reference_index=0
for reference_file in "${reference_files[@]}"; do
  case "$reference_file" in
    *.swift|*.sh|*.py|*.js|*.ts) ;;
    *) continue ;;
  esac
  normalized_file="$normalized_root/reference/$reference_index"
  normalize_source "$reference_file" "$normalized_file"
  normalized_count="$(wc -l < "$normalized_file" | tr -d '[:space:]')"
  reference_source_extensions+=("${reference_file##*.}")
  reference_normalized_files+=("$normalized_file")
  reference_normalized_counts+=("$normalized_count")
  reference_index=$((reference_index + 1))
done

for new_index in "${!new_normalized_files[@]}"; do
  new_lines="${new_normalized_counts[$new_index]}"
  for reference_index in "${!reference_normalized_files[@]}"; do
    [ "${new_source_extensions[$new_index]}" = \
      "${reference_source_extensions[$reference_index]}" ] || continue
    reference_lines="${reference_normalized_counts[$reference_index]}"
    combined_lines=$((new_lines + reference_lines))
    [ "$combined_lines" -ge "$minimum_combined_lines" ] || continue
    if [ "$new_lines" -le "$reference_lines" ]; then
      smaller_line_count="$new_lines"
    else
      smaller_line_count="$reference_lines"
    fi
    maximum_similarity=$((smaller_line_count * 200 / combined_lines))
    [ "$maximum_similarity" -ge "$similarity_threshold" ] || continue

    shared_lines="$(comm -12 \
      "${new_normalized_files[$new_index]}" \
      "${reference_normalized_files[$reference_index]}" | wc -l | tr -d '[:space:]')"
    similarity=$((shared_lines * 200 / combined_lines))
    [ "$similarity" -lt "$similarity_threshold" ] || \
      fail 'suspicious normalized similarity was detected.'
  done
done

printf 'Clean-room similarity audit passed: no copied or suspiciously similar implementation files detected.\n'
if [ "$testing" != 1 ]; then
  printf 'Clean revision: %s\n' "$(git -C "$repository_root" rev-parse HEAD)"
  printf 'Frozen reference revision: %s\n' "$(git -C "$frozen_reference" rev-parse HEAD)"
fi
