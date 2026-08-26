#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s /path/to/prismBar.app\n' "$0" >&2
  exit 64
fi

application_path="$1"
repository_root="$(git rev-parse --show-toplevel)"

fail() {
  printf 'Release audit failed: %s\n' "$1" >&2
  exit 1
}

if [ ! -d "$application_path/Contents" ]; then
  fail "application bundle is unavailable at $application_path"
fi

host_executable="$application_path/Contents/MacOS/prismBar"
plugin_bundle="$application_path/Contents/XPCServices/prismCalcPluginService.xpc"
plugin_executable="$plugin_bundle/Contents/MacOS/prismCalcPluginService"
privacy_manifest="$application_path/Contents/Resources/PrivacyInfo.xcprivacy"

for required_path in \
  "$host_executable" \
  "$plugin_executable" \
  "$privacy_manifest"; do
  if [ ! -f "$required_path" ]; then
    fail "required bundle file is missing: $required_path"
  fi
done

actual_executables="$(find "$application_path/Contents" -type f -perm -111 -print | LC_ALL=C sort)"
expected_executables="$(printf '%s\n%s\n' "$host_executable" "$plugin_executable" | LC_ALL=C sort)"
if [ "$actual_executables" != "$expected_executables" ]; then
  printf 'Expected executables:\n%s\nActual executables:\n%s\n' \
    "$expected_executables" "$actual_executables" >&2
  fail 'bundle executable allowlist does not match'
fi

if [ -d "$application_path/Contents/Frameworks" ] && \
  find "$application_path/Contents/Frameworks" -type f -print -quit | rg -q .; then
  fail 'embedded frameworks or dynamic libraries are not allowed'
fi

for executable_path in "$host_executable" "$plugin_executable"; do
  if [ "$(lipo -archs "$executable_path")" != 'arm64' ]; then
    fail "release executable is not arm64-only: $executable_path"
  fi

  while IFS= read -r linked_library; do
    case "$linked_library" in
      /System/Library/*|/usr/lib/*) ;;
      *) fail "non-system linked library in ${executable_path}: ${linked_library}" ;;
    esac
  done < <(otool -L "$executable_path" | tail -n +2 | awk '{print $1}')

  if strings -a "$executable_path" | rg -q \
    '/Users/[^/[:space:]]+|/home/[^/[:space:]]+|Documents/Codex|-----BEGIN ([A-Z0-9 ]+ )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}'; then
    fail "local path or credential-shaped content found in ${executable_path}"
  fi
done

host_bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$application_path/Contents/Info.plist")"
plugin_bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plugin_bundle/Contents/Info.plist")"
minimum_system_version="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$application_path/Contents/Info.plist")"
if [ "$host_bundle_identifier" != 'com.laclairtech.prismbar' ]; then
  fail "unexpected host bundle identifier: $host_bundle_identifier"
fi
if [ "$plugin_bundle_identifier" != 'com.laclairtech.prismbar.plugin.prismcalc' ]; then
  fail "unexpected plugin bundle identifier: $plugin_bundle_identifier"
fi
if [ "$minimum_system_version" != '27.0' ]; then
  fail "unexpected minimum macOS version: $minimum_system_version"
fi

expected_privacy_manifest='{"NSPrivacyCollectedDataTypes":[],"NSPrivacyTrackingDomains":[],"NSPrivacyTracking":false,"NSPrivacyAccessedAPITypes":[{"NSPrivacyAccessedAPIType":"NSPrivacyAccessedAPICategoryUserDefaults","NSPrivacyAccessedAPITypeReasons":["CA92.1"]}]}'
actual_privacy_manifest="$(plutil -convert json -o - "$privacy_manifest")"
if [ "$actual_privacy_manifest" != "$expected_privacy_manifest" ]; then
  fail 'privacy manifest differs from the local-only allowlist'
fi

if [ "$(plutil -convert json -o - "$repository_root/Config/prismBar.entitlements")" != '{}' ]; then
  fail 'host entitlement allowlist is not empty'
fi
expected_plugin_entitlements='{"com.apple.security.app-sandbox":true}'
actual_plugin_entitlements="$(plutil -convert json -o - \
  "$repository_root/Config/prismCalcPluginService.entitlements")"
if [ "$actual_plugin_entitlements" != "$expected_plugin_entitlements" ]; then
  fail 'plugin entitlement allowlist is not exactly App Sandbox'
fi

printf 'Release bundle audit passed: two expected executables, Apple libraries only, exact entitlements, and no credential-shaped strings.\n'
