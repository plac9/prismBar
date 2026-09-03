#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'Runtime budget contract failed: %s\n' "$1" >&2
  exit 1
}

script='scripts/audit-runtime-budget.sh'
test -x "$script" || fail 'the runtime audit must exist and be executable'

rg -Fq "maximum_idle_cpu_percent='1.0'" "$script" || \
  fail 'the settled idle CPU budget must be explicit'
rg -Fq "maximum_footprint_mib='100.0'" "$script" || \
  fail 'the physical footprint budget must be explicit'
rg -Fq "maximum_sample_count='60'" "$script" || \
  fail 'sample collection must be bounded'
rg -Fq "expected_executable='/Applications/prismBar.app/Contents/MacOS/prismBar'" "$script" || \
  fail 'the audit must bind to the canonical installed executable'

for forbidden in 'printenv' 'env |' 'ps ax' 'ps aux' 'command=' 'args='; do
  if rg -Fq "$forbidden" "$script"; then
    fail "the audit contains forbidden broad process or environment output: $forbidden"
  fi
done

rg -Fq '"averageIdleCPUPercent"' "$script" || fail 'aggregate CPU evidence is missing'
rg -Fq '"maximumPhysicalFootprintMiB"' "$script" || fail 'aggregate footprint evidence is missing'
rg -Fq '"maximumThreadCount"' "$script" || fail 'aggregate thread evidence is missing'
rg -Fq "fail 'settled idle CPU exceeds the runtime budget'" "$script" || \
  fail 'CPU threshold failures must return nonzero'
rg -Fq "fail 'physical footprint exceeds the runtime budget'" "$script" || \
  fail 'footprint threshold failures must return nonzero'

printf 'Runtime budget contract passed.\n'
