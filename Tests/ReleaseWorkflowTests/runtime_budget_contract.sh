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
rg -Fq '"maximumIntervalCPUPercent"' "$script" || \
  fail 'interval CPU evidence is missing'
rg -Fq '"maximumPhysicalFootprintMiB"' "$script" || fail 'aggregate footprint evidence is missing'
rg -Fq '"maximumThreadCount"' "$script" || fail 'aggregate thread evidence is missing'
rg -Fq '"initialPhysicalFootprintMiB"' "$script" || \
  fail 'initial aggregate footprint evidence is missing'
rg -Fq '"endingPhysicalFootprintMiB"' "$script" || \
  fail 'ending aggregate footprint evidence is missing'
rg -Fq '"physicalFootprintGrowthMiB"' "$script" || \
  fail 'aggregate footprint-growth evidence is missing'
rg -Fq '"initialThreadCount"' "$script" || fail 'initial aggregate thread evidence is missing'
rg -Fq '"endingThreadCount"' "$script" || fail 'ending aggregate thread evidence is missing'
rg -Fq '"threadGrowth"' "$script" || fail 'aggregate thread-growth evidence is missing'
rg -Fq "maximum_footprint_growth_mib='15.0'" "$script" || \
  fail 'the footprint-growth tolerance must be explicit'
rg -Fq "maximum_thread_growth='2'" "$script" || \
  fail 'the thread-growth tolerance must be explicit'
rg -Fq "fail 'settled idle CPU exceeds the runtime budget'" "$script" || \
  fail 'CPU threshold failures must return nonzero'
rg -Fq "fail 'physical footprint exceeds the runtime budget'" "$script" || \
  fail 'footprint threshold failures must return nonzero'
rg -Fq "fail 'physical footprint growth exceeds the runtime budget'" "$script" || \
  fail 'footprint-growth failures must return nonzero'
rg -Fq "fail 'thread growth exceeds the runtime budget'" "$script" || \
  fail 'thread-growth failures must return nonzero'
rg -Fq "printf 'Evidence written.\\n'" "$script" || \
  fail 'the audit must confirm evidence without printing its filesystem path'
if rg -Fq "printf 'Evidence: %s\\n'" "$script"; then
  fail 'the audit must not print the runtime evidence path'
fi
rg -Fq "ps -p \"\$pid\" -o cputime=" "$script" || \
  fail 'CPU usage must derive from process CPU-time deltas'
rg -Fq 'CLOCK_MONOTONIC' "$script" || \
  fail 'CPU intervals must use a monotonic wall-time source'
if rg -Fq -- '-o %cpu=' "$script"; then
  fail 'the audit must not use the historical ps CPU average'
fi
rg -Fq 'thread_listing="$(ps -M -p "$pid")"' "$script" || \
  fail 'thread sampling failures must propagate'
if rg -Fq 'ps -M -p "$pid" -o tid=' "$script" || rg -Fq 'ps -M -p "$pid" -o tid= 2>/dev/null || true' "$script"; then
  fail 'thread sampling must not use an unsupported field or mask failures'
fi

printf 'Runtime budget contract passed.\n'
