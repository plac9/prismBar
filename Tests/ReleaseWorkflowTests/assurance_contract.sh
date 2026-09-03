#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

test -x scripts/generate-assurance-report.sh || {
  printf 'Assurance contract failed: report generator is missing or not executable.\n' >&2
  exit 1
}

test -x scripts/capture-ui-audit.sh || {
  printf 'Assurance contract failed: UI audit capture workflow is missing or not executable.\n' >&2
  exit 1
}

bash -n scripts/generate-assurance-report.sh

for required in \
  'build/ci/prismBar-ci-$revision.json' \
  'build/stress/prismBar-stress-$revision.json' \
  'build/ui-audit/prismBar-ui-audit-$revision.json' \
  'build/acceptance/prismBar-physical-$revision.json' \
  'sourceRevision' \
  'publicSourceVerified' \
  '{{AUTOMATED_CLASS}}' \
  '{{AUTOMATED_STATUS}}' \
  '{{UI_AUDIT_CLASS}}' \
  '{{UI_AUDIT_STATUS}}' \
  '{{PHYSICAL_CLASS}}' \
  '{{PHYSICAL_STATUS}}' \
  '{{DISTRIBUTION_CLASS}}' \
  '{{DISTRIBUTION_STATUS}}' \
  '{{PUBLIC_CLASS}}' \
  '{{PUBLIC_STATUS}}'; do
  rg -Fq -- "$required" scripts/generate-assurance-report.sh docs/assurance-report.template.html || {
    printf 'Assurance contract failed: missing %s.\n' "$required" >&2
    exit 1
  }
done

for required in \
  'git status --porcelain=v1' \
  'PRISM_SOURCE_REVISION=$revision' \
  'VisualAuditTests' \
  'xcresulttool export attachments' \
  'generate-ui-audit-report.sh'; do
  rg -Fq -- "$required" scripts/capture-ui-audit.sh || {
    printf 'Assurance contract failed: UI capture workflow is missing %s.\n' "$required" >&2
    exit 1
  }
done

for required in \
  'addUIInterruptionMonitor' \
  'systemUIOcclusionDetected' \
  'attachOpaquePopoverInterior' \
  'System UI is obscuring the shipping surface'; do
  rg -Fq -- "$required" Tests/prismBarUITests/VisualAuditTests.swift || {
    printf 'Assurance contract failed: visual capture does not reject %s.\n' "$required" >&2
    exit 1
  }
done

for required in \
  'git status --porcelain=v1' \
  'build/ci' \
  'sourceState' \
  'result' \
  'passed'; do
  rg -Fq -- "$required" scripts/ci-verify.sh || {
    printf 'Assurance contract failed: CI evidence is missing %s.\n' "$required" >&2
    exit 1
  }
done

for required in \
  'git status --porcelain=v1' \
  'build/ui-audit' \
  'sourceRevision' \
  'screenshotCount' \
  'expected_screenshot_keys' \
  'actual_screenshot_key_set'; do
  rg -Fq -- "$required" scripts/generate-ui-audit-report.sh || {
    printf 'Assurance contract failed: UI audit evidence is missing %s.\n' "$required" >&2
    exit 1
  }
done

rg -Fq -- 'Eleven exact-revision shipping surfaces reviewed' \
  scripts/generate-assurance-report.sh || {
  printf 'Assurance contract failed: visual audit count copy is stale.\n' >&2
  exit 1
}

if rg -n '"plugin"|Reciprocal plugin trust|plugin readiness' \
  scripts/generate-assurance-report.sh docs/assurance-report.template.html; then
  printf 'Assurance contract failed: core-only release evidence still requires the dormant plugin.\n' >&2
  exit 1
fi

for required in \
  'git status --porcelain=v1' \
  'PRISM_SOURCE_REVISION="$revision"' \
  'build/stress'; do
  rg -Fq -- "$required" scripts/stress-verify.sh || {
    printf 'Assurance contract failed: stress evidence is missing %s.\n' "$required" >&2
    exit 1
  }
done

if rg -n 'Final clean-revision gate pending|Owner-gated release work' \
    docs/assurance-report.template.html; then
  printf 'Assurance contract failed: static release claims remain in the report template.\n' >&2
  exit 1
fi

./scripts/generate-assurance-report.sh --source-audit
