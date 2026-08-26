#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s /path/to/prismBar.app\n' "$0" >&2
  exit 64
fi

application_path="$1"
plugin_path="$application_path/Contents/XPCServices/prismCalcPluginService.xpc"

fail() {
  printf 'Live signing-boundary audit failed: %s\n' "$1" >&2
  exit 1
}

for dependency in codesign ditto mktemp; do
  command -v "$dependency" >/dev/null 2>&1 || fail "$dependency is unavailable"
done

if [ ! -d "$application_path/Contents" ]; then
  fail 'the application bundle is unavailable'
fi
if [ ! -d "$plugin_path/Contents" ]; then
  fail 'the embedded plugin service is unavailable'
fi

host_requirement='identifier "com.laclairtech.prismbar" and anchor apple generic and certificate leaf[subject.OU] = "N8A5T2PZY9"'
plugin_requirement='identifier "com.laclairtech.prismbar.plugin.prismcalc" and anchor apple generic and certificate leaf[subject.OU] = "N8A5T2PZY9"'

codesign --verify --strict -R="$host_requirement" "$application_path" \
  || fail 'the authentic host does not satisfy its reciprocal requirement'
codesign --verify --strict -R="$plugin_requirement" "$plugin_path" \
  || fail 'the authentic plugin does not satisfy the host requirement'

audit_directory="$(mktemp -d "${TMPDIR:-/tmp}/prismbar-signing-audit.XXXXXX")"
cleanup() {
  chmod -R u+w "$audit_directory" 2>/dev/null || true
  find "$audit_directory" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM

host_impostor="$audit_directory/prismBar.app"
plugin_impostor="$audit_directory/prismCalcPluginService.xpc"
ditto "$application_path" "$host_impostor"
ditto "$plugin_path" "$plugin_impostor"

codesign --force --sign - "$host_impostor" >/dev/null \
  || fail 'could not create the isolated host impostor'
codesign --force --sign - "$plugin_impostor" >/dev/null \
  || fail 'could not create the isolated plugin impostor'

impostor_host_identifier="$(codesign -d --verbose=4 "$host_impostor" 2>&1 \
  | awk -F= '$1 == "Identifier" {print $2}')"
impostor_plugin_identifier="$(codesign -d --verbose=4 "$plugin_impostor" 2>&1 \
  | awk -F= '$1 == "Identifier" {print $2}')"

[ "$impostor_host_identifier" = 'com.laclairtech.prismbar' ] \
  || fail 'the isolated host impostor did not preserve the expected identifier'
[ "$impostor_plugin_identifier" = 'com.laclairtech.prismbar.plugin.prismcalc' ] \
  || fail 'the isolated plugin impostor did not preserve the expected identifier'

if codesign --verify --strict -R="$host_requirement" "$host_impostor" >/dev/null 2>&1; then
  fail 'an identically named ad-hoc host satisfied the reciprocal requirement'
fi
if codesign --verify --strict -R="$plugin_requirement" "$plugin_impostor" >/dev/null 2>&1; then
  fail 'an identically named ad-hoc plugin satisfied the host requirement'
fi

printf 'Live signing-boundary audit passed: authentic host and plugin accepted; identically named ad-hoc impostors rejected.\n'
