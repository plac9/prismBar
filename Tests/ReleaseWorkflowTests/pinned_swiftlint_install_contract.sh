#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
installer="$repository_root/scripts/install-pinned-swiftlint.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/prismbar-swiftlint-contract.XXXXXX")"

cleanup() {
  chmod -R u+w "$test_root" 2>/dev/null || true
  find "$test_root" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM

mkdir -p "$test_root/archive"
cat > "$test_root/archive/swiftlint" <<'SCRIPT'
#!/usr/bin/env bash
printf '0.65.1\n'
SCRIPT
chmod +x "$test_root/archive/swiftlint"
(
  cd "$test_root/archive"
  zip -q "$test_root/portable_swiftlint.zip" swiftlint
)

archive_digest="$(shasum -a 256 "$test_root/portable_swiftlint.zip" | awk '{print $1}')"
installed_binary="$test_root/bin/swiftlint"

"$installer" "$test_root/portable_swiftlint.zip" "$archive_digest" "$installed_binary"

if [ ! -x "$installed_binary" ]; then
  printf 'Pinned SwiftLint installer did not produce an executable.\n' >&2
  exit 1
fi

if [ "$($installed_binary version)" != '0.65.1' ]; then
  printf 'Pinned SwiftLint installer produced the wrong executable.\n' >&2
  exit 1
fi

tampered_archive="$test_root/tampered.zip"
cp "$test_root/portable_swiftlint.zip" "$tampered_archive"
printf 'tampered' >> "$tampered_archive"

if "$installer" "$tampered_archive" "$archive_digest" "$test_root/rejected/swiftlint" >/dev/null 2>&1; then
  printf 'Pinned SwiftLint installer accepted a digest mismatch.\n' >&2
  exit 1
fi

if [ -e "$test_root/rejected/swiftlint" ]; then
  printf 'Pinned SwiftLint installer left an executable after digest rejection.\n' >&2
  exit 1
fi

printf 'Pinned SwiftLint installation contract passed.\n'
