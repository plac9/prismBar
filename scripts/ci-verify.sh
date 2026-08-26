#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

for dependency in actionlint xcodebuild xcodegen swift swiftlint gitleaks rg; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf 'CI dependency is unavailable: %s\n' "$dependency" >&2
    exit 1
  fi
done

if [ "$(uname -m)" != "arm64" ] || [[ "$(xcrun --sdk macosx --show-sdk-version)" != 27.* ]]; then
  printf 'CI requires the Apple silicon Xcode 27 runner.\n' >&2
  exit 1
fi

if git ls-files -z | rg -z -q \
  '(^|/)(\.env($|\.)|secrets?/|.*\.(p8|p12|mobileprovision|provisionprofile|cer|key|pem|token|secret|logarchive|tracev3)$)'; then
  printf 'A forbidden credential or diagnostic artifact is tracked.\n' >&2
  exit 1
fi

gitleaks git . --no-banner --redact
actionlint .github/workflows/ci.yml

xcodegen generate
if ! git diff --quiet -- prismBar.xcodeproj; then
  printf 'The generated Xcode project does not match project.yml.\n' >&2
  git diff --stat -- prismBar.xcodeproj
  exit 1
fi

swiftlint lint --strict
swift test
swift test -c release

derived_data_directory="${CI_DERIVED_DATA_DIR:-$repository_root/build/CI-DerivedData}"
common_build_arguments=(
  -project prismBar.xcodeproj
  -scheme prismBar
  -destination 'platform=macOS,arch=arm64'
  -derivedDataPath "$derived_data_directory"
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
)

xcodebuild "${common_build_arguments[@]}" -configuration Debug build
xcodebuild "${common_build_arguments[@]}" -configuration Debug analyze
xcodebuild "${common_build_arguments[@]}" -configuration Release build
./scripts/audit-release-bundle.sh \
  "$derived_data_directory/Build/Products/Release/prismBar.app"

printf 'CI verification passed without signing or publishing artifacts.\n'
