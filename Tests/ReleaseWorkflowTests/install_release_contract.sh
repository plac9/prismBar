#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

installer='scripts/install-release-candidate.sh'
installation_library='scripts/release-installation.sh'
test -x "$installer" && test -f "$installation_library" || {
  printf 'Release installation contract failed: shipping installer is missing.\n' >&2
  exit 1
}

bash -n "$installer" "$installation_library"

# These fragments are intentionally source-level release invariants.
# shellcheck disable=SC2016
for required in \
  '--disk-image' \
  '--evidence' \
  '/Applications/prismBar.app' \
  'build/InstallRollback' \
  '[ ! -L "$disk_image_path" ]' \
  '[ ! -L "$evidence_path" ]' \
  '.notarized == true' \
  '.notarization.applicationStapled == true' \
  '.notarization.diskImageStapled == true' \
  'stapler validate' \
  'codesign --verify' \
  'spctl --assess' \
  'audit-release-bundle.sh' \
  'diskutil image attach' \
  'diskutil eject' \
  'promote_release_bundle'; do
  rg -Fq -- "$required" "$installer" || {
    printf 'Release installation contract failed: a shipping invariant is missing.\n' >&2
    exit 1
  }
done

if rg -n 'sudo|rm -|find .*delete|^[[:space:]]*open[[:space:]]|launch|--password|--apple-id|op read' \
  "$installer" "$installation_library"; then
  printf 'Release installation contract failed: destructive, privileged, launching, or credential behavior is forbidden.\n' >&2
  exit 1
fi

fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/prismbar-install-contract.XXXXXX")"
cleanup() {
  chmod -R u+w "$fixture_root" 2>/dev/null || true
  find "$fixture_root" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# shellcheck source=scripts/release-installation.sh
source "$installation_library"

successful_verification() { return 0; }
failed_verification() { return 1; }

target="$fixture_root/prismBar.app"
staged="$fixture_root/staged.app"
rollback="$fixture_root/rollback.app"
mkdir -p "$target" "$staged"
printf 'old\n' > "$target/payload"
printf 'new\n' > "$staged/payload"

promote_release_bundle "$staged" "$target" "$rollback" successful_verification
[ "$(tr -d '\n' < "$target/payload")" = new ]
[ "$(tr -d '\n' < "$rollback/payload")" = old ]

second_stage="$fixture_root/second-stage.app"
second_rollback="$fixture_root/second-rollback.app"
mkdir -p "$second_stage"
printf 'rejected\n' > "$second_stage/payload"

if promote_release_bundle \
  "$second_stage" "$target" "$second_rollback" failed_verification >/dev/null 2>&1; then
  printf 'Release installation contract failed: post-install verification failure was accepted.\n' >&2
  exit 1
fi

[ "$(tr -d '\n' < "$target/payload")" = new ] || {
  printf 'Release installation contract failed: prior app was not restored.\n' >&2
  exit 1
}
[ "$(tr -d '\n' < "$second_rollback.failed/payload")" = rejected ] || {
  printf 'Release installation contract failed: rejected app was not quarantined.\n' >&2
  exit 1
}

printf 'Release installation contract passed: promotion preserves rollback and restores on failure.\n'
