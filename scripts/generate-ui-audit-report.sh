#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s /path/to/build/ui-audit-run\n' "$0" >&2
  exit 64
fi

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"
if [ -n "$(git status --porcelain=v1)" ]; then
  printf 'UI audit evidence requires a clean committed revision.\n' >&2
  exit 1
fi

revision="$(git rev-parse HEAD)"
audit_root="$(cd "$1" && pwd -P)"
expected_prefix="$repository_root/build/ui-audit-"

case "$audit_root" in
  "$expected_prefix"*) ;;
  *)
    printf 'UI audit report output must be an isolated build/ui-audit directory.\n' >&2
    exit 64
    ;;
esac

manifest="$audit_root/screenshots/manifest.json"
report="$audit_root/index.html"

if [ ! -f "$manifest" ]; then
  printf 'UI audit attachment manifest is missing: %s\n' "$manifest" >&2
  exit 1
fi

expected_screenshot_keys=(
  '01-home'
  '02-menu-bar'
  '03-automation'
  '04-privacy'
  '05-about'
  '06-settings-general'
  '07-settings-privacy'
  '08-prismDeck'
  '09-status-item'
  '10-home-accessibility-size'
  '11-prismDeck-accessibility-size'
)
attachment_count="$(jq '[.[].attachments[] | select(.exportedFileName | endswith(".png"))] | length' "$manifest")"
expected_screenshot_key_set="$(printf '%s\n' "${expected_screenshot_keys[@]}" | LC_ALL=C sort)"
actual_screenshot_key_set="$(
  jq -r '
    .[].attachments[]
    | select(.exportedFileName | endswith(".png"))
    | .suggestedHumanReadableName
    | sub("_0_.*$"; "")
  ' "$manifest" | LC_ALL=C sort
)"

if [ "$attachment_count" -ne "${#expected_screenshot_keys[@]}" ] ||
    [ "$actual_screenshot_key_set" != "$expected_screenshot_key_set" ]; then
  printf 'UI audit report is incomplete: expected the exact %s shipping surfaces, found %s PNG attachments.\n' \
    "${#expected_screenshot_keys[@]}" "$attachment_count" >&2
  exit 1
fi

jq -r '
  def title:
    .suggestedHumanReadableName
    | sub("_0_.*$"; "")
    | {
        "01-home": "Home",
        "02-menu-bar": "Menu Bar",
        "03-automation": "Automation",
        "04-privacy": "Privacy",
        "05-about": "About",
        "06-settings-general": "Settings - General",
        "07-settings-privacy": "Settings - Privacy",
        "08-prismDeck": "prismDeck",
        "09-status-item": "Status Item",
        "10-home-accessibility-size": "Home at 200%",
        "11-prismDeck-accessibility-size": "prismDeck at 200%"
      }[.] // .;
  [.[].attachments[] | select(.exportedFileName | endswith(".png"))]
  | sort_by(.suggestedHumanReadableName)
  | "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">" +
    "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">" +
    "<title>prismBar UI Audit</title><style>" +
    "body{margin:0;padding:32px;background:#10141a;color:#f5f7fb;font:16px -apple-system,BlinkMacSystemFont,sans-serif}" +
    "main{max-width:1180px;margin:auto}h1{margin-bottom:8px}p{color:#aab4c3;margin-top:0}" +
    "figure{margin:28px 0;padding:18px;border:1px solid #334155;border-radius:20px;background:#171d26}" +
    "h2{font-size:18px}img{display:block;max-width:100%;height:auto;margin:auto;border-radius:14px}" +
    "</style></head><body><main><h1>prismBar macOS 27 UI audit</h1>" +
    "<p>Privacy-safe XCTest captures of prismBar-owned surfaces only.</p>" +
    (map("<figure><h2>" + (title | @html) + "</h2><img alt=\"" +
      (title | @html) + "\" src=\"screenshots/" + (.exportedFileName | @html) +
      "\"></figure>") | join("")) +
    "</main></body></html>"
' "$manifest" > "$report"

if [ ! -s "$report" ]; then
  printf 'UI audit report was not generated.\n' >&2
  exit 1
fi

evidence_directory="$repository_root/build/ui-audit"
evidence_report="$evidence_directory/prismBar-ui-audit-$revision.html"
evidence_path="$evidence_directory/prismBar-ui-audit-$revision.json"
mkdir -p "$evidence_directory"
sed "s|src=\"screenshots/|src=\"../$(basename "$audit_root")/screenshots/|g" \
  "$report" > "$evidence_report"
jq -n \
  --arg revision "$revision" \
  --arg generatedAt "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  --argjson screenshotCount "$attachment_count" \
  '{
    schemaVersion: 1,
    product: "prismBar",
    sourceRevision: $revision,
    sourceState: "clean local commit",
    generatedAt: $generatedAt,
    screenshotCount: $screenshotCount,
    privacyBoundary: "prismBar-owned surfaces with synthetic content only",
    result: "passed"
  }' > "$evidence_path"

printf 'UI audit report generated with %s privacy-safe screenshots: %s\n' \
  "$attachment_count" "$report"
printf 'Revision-bound report: %s\n' "$evidence_report"
printf 'Evidence: %s\n' "$evidence_path"
