#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

if [ -n "$(git status --porcelain=v1)" ]; then
  printf 'CI verification requires a clean committed revision.\n' >&2
  exit 1
fi

revision="$(git rev-parse HEAD)"
started_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

for dependency in actionlint gitleaks jq perl rg swift swiftlint xcodebuild xcodegen; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf 'CI dependency is unavailable: %s\n' "$dependency" >&2
    exit 1
  fi
done

./scripts/audit-tool-versions.sh
./scripts/audit-licensing.sh
./scripts/audit-public-safety.sh
./scripts/audit-liquid-glass.sh
./scripts/audit-macos-27-compatibility.sh
Tests/ReleaseWorkflowTests/archive_contract.sh
Tests/ReleaseWorkflowTests/notarization_contract.sh
Tests/ReleaseWorkflowTests/assurance_contract.sh
Tests/ReleaseWorkflowTests/ui_qa_signing_contract.sh
Tests/ReleaseWorkflowTests/physical_acceptance_contract.sh
Tests/ReleaseWorkflowTests/release_signing_keychain_contract.sh
Tests/ReleaseWorkflowTests/core_shipping_contract.sh
Tests/ReleaseWorkflowTests/local_package_normalization_contract.sh

if [ "$(uname -m)" != "arm64" ] || [[ "$(xcrun --sdk macosx --show-sdk-version)" != 27.* ]]; then
  printf 'CI requires the Apple silicon Xcode 27 runner.\n' >&2
  exit 1
fi

gitleaks git . --no-banner --redact
actionlint .github/workflows/ci.yml

generated_project='prismBar.xcodeproj/project.pbxproj'
expected_project="$(mktemp "${TMPDIR:-/tmp}/prismbar-project-expected.XXXXXX")"
expected_normalized="$(mktemp "${TMPDIR:-/tmp}/prismbar-project-expected-normalized.XXXXXX")"
generated_normalized="$(mktemp "${TMPDIR:-/tmp}/prismbar-project-generated-normalized.XXXXXX")"

restore_checked_in_project() {
  if [ -s "$expected_project" ]; then
    cp "$expected_project" "$generated_project"
  fi
  rm -f "$expected_project" "$expected_normalized" "$generated_normalized"
}

trap restore_checked_in_project EXIT INT TERM
git show "HEAD:$generated_project" > "$expected_project"
xcodegen generate
generated_project_changes="$(git diff --name-only -- prismBar.xcodeproj)"
if [ -n "$generated_project_changes" ] && [ "$generated_project_changes" != "$generated_project" ]; then
  printf 'XcodeGen changed unexpected project files:\n%s\n' "$generated_project_changes" >&2
  exit 1
fi
./scripts/normalize-local-package-reference.sh "$expected_project" "$expected_normalized"
./scripts/normalize-local-package-reference.sh "$generated_project" "$generated_normalized"
if ! cmp -s "$expected_normalized" "$generated_normalized"; then
  printf 'The generated Xcode project does not match project.yml.\n' >&2
  diff -u "$expected_normalized" "$generated_normalized" || true
  exit 1
fi
restore_checked_in_project
trap - EXIT INT TERM

verification_root="${CI_VERIFICATION_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/prismbar-ci.XXXXXX")}"
if [ -z "${CI_VERIFICATION_ROOT:-}" ]; then
  cleanup() {
    chmod -R u+w "$verification_root" 2>/dev/null || true
    find "$verification_root" -depth -delete 2>/dev/null || true
  }
  trap cleanup EXIT INT TERM
fi

swiftlint lint --strict
swift test
swift test -c release

xcodebuild \
  -project prismBar.xcodeproj \
  -scheme prismBar \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$verification_root/AppTests" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  "PRISM_SOURCE_REVISION=$revision" \
  test \
  '-only-testing:prismBarAppTests'

swift test --sanitize=address --scratch-path \
  "${CI_ADDRESS_SANITIZER_DIR:-$verification_root/SwiftPM-ASan}"
swift test --sanitize=thread --scratch-path \
  "${CI_THREAD_SANITIZER_DIR:-$verification_root/SwiftPM-TSan}"

derived_data_directory="${CI_DERIVED_DATA_DIR:-$verification_root/DerivedData}"
common_build_arguments=(
  -project prismBar.xcodeproj
  -scheme prismBar
  -destination 'platform=macOS,arch=arm64'
  -derivedDataPath "$derived_data_directory"
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  "PRISM_SOURCE_REVISION=$(git rev-parse HEAD)"
)

xcodebuild "${common_build_arguments[@]}" -configuration Debug build
xcodebuild "${common_build_arguments[@]}" -configuration Debug analyze
xcodebuild "${common_build_arguments[@]}" -configuration Release build
./scripts/audit-release-bundle.sh \
  "$derived_data_directory/Build/Products/Release/prismBar.app"

evidence_directory="$repository_root/build/ci"
evidence_path="$evidence_directory/prismBar-ci-$revision.json"
mkdir -p "$evidence_directory"
jq -n \
  --arg revision "$revision" \
  --arg startedAt "$started_at" \
  --arg completedAt "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  '{
    schemaVersion: 1,
    product: "prismBar",
    sourceRevision: $revision,
    sourceState: "clean local commit",
    startedAt: $startedAt,
    completedAt: $completedAt,
    scopes: [
      "toolchain contract",
      "licensing, public safety, and Liquid Glass structure",
      "Git history secret scan",
      "Swift lint",
      "debug and release tests",
      "hosted application state tests",
      "Address Sanitizer",
      "Thread Sanitizer",
      "Xcode static analysis",
      "unsigned release bundle audit"
    ],
    result: "passed"
  }' > "$evidence_path"

printf 'CI verification passed without signing or publishing artifacts.\n'
printf 'Evidence: %s\n' "$evidence_path"
