#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'Runtime budget audit failed: %s\n' "$1" >&2
  exit 1
}

expected_executable='/Applications/prismBar.app/Contents/MacOS/prismBar'
maximum_idle_cpu_percent='1.0'
maximum_footprint_mib='100.0'
maximum_footprint_growth_mib='15.0'
maximum_thread_growth='2'
maximum_sample_count='60'
sample_count='10'
sample_interval_seconds='5'
settle_seconds='5'
output_path=''

while [ "$#" -gt 0 ]; do
  case "$1" in
    --samples)
      [ "$#" -ge 2 ] || fail 'missing value for --samples'
      sample_count="$2"
      shift 2
      ;;
    --interval)
      [ "$#" -ge 2 ] || fail 'missing value for --interval'
      sample_interval_seconds="$2"
      shift 2
      ;;
    --settle)
      [ "$#" -ge 2 ] || fail 'missing value for --settle'
      settle_seconds="$2"
      shift 2
      ;;
    --output)
      [ "$#" -ge 2 ] || fail 'missing value for --output'
      output_path="$2"
      shift 2
      ;;
    *)
      fail 'unsupported argument'
      ;;
  esac
done

for value in "$sample_count" "$sample_interval_seconds" "$settle_seconds"; do
  case "$value" in
    '' | *[!0-9]*) fail 'sample controls must be nonnegative integers' ;;
  esac
done
[ "$sample_count" -ge 1 ] || fail 'at least one sample is required'
[ "$sample_count" -le "$maximum_sample_count" ] || fail 'sample count exceeds the bound'
[ "$sample_interval_seconds" -le 10 ] || fail 'sample interval exceeds the bound'
[ "$settle_seconds" -le 60 ] || fail 'settle period exceeds the bound'

for dependency in awk jq perl pgrep ps vmmap; do
  command -v "$dependency" >/dev/null 2>&1 || fail 'a required runtime metric tool is unavailable'
done

matching_pids=()
while IFS= read -r matching_pid; do
  matching_pids+=("$matching_pid")
done < <(pgrep -f "^$expected_executable$")
[ "${#matching_pids[@]}" -eq 1 ] || fail 'exactly one canonical installed prismBar process is required'
pid="${matching_pids[0]}"
actual_executable="$(ps -p "$pid" -o comm= | awk '{$1=$1; print}')"
[ "$actual_executable" = "$expected_executable" ] || fail 'the selected process is not the canonical app'

if [ "$settle_seconds" -gt 0 ]; then
  sleep "$settle_seconds"
fi

cpu_total='0'
maximum_interval_cpu='0'
maximum_footprint='0'
maximum_threads='0'
initial_footprint=''
ending_footprint=''
initial_threads=''
ending_threads=''

sample_footprint_mib() {
  local raw_value magnitude suffix
  raw_value="$(vmmap -summary "$pid" 2>/dev/null | awk '/^Physical footprint:/ {print $3; exit}')"
  [ -n "$raw_value" ] || fail 'physical footprint is unavailable'
  suffix="${raw_value: -1}"
  magnitude="${raw_value%?}"
  case "$suffix" in
    K) awk -v value="$magnitude" 'BEGIN {printf "%.3f", value / 1024}' ;;
    M) awk -v value="$magnitude" 'BEGIN {printf "%.3f", value}' ;;
    G) awk -v value="$magnitude" 'BEGIN {printf "%.3f", value * 1024}' ;;
    *) fail 'physical footprint unit is unsupported' ;;
  esac
}

sample_cpu_seconds() {
  local raw_value
  raw_value="$(ps -p "$pid" -o cputime=)" || fail 'process CPU time is unavailable'
  awk -v value="$raw_value" '
    BEGIN {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      count = split(value, fields, ":")
      if (count == 2) {
        seconds = (fields[1] * 60) + fields[2]
      } else if (count == 3) {
        seconds = (fields[1] * 3600) + (fields[2] * 60) + fields[3]
      } else {
        exit 1
      }
      printf "%.3f", seconds
    }
  ' || fail 'process CPU time has an unsupported format'
}

monotonic_seconds() {
  perl -MTime::HiRes=clock_gettime,CLOCK_MONOTONIC \
    -e 'printf "%.6f", clock_gettime(CLOCK_MONOTONIC)'
}

previous_cpu_seconds="$(sample_cpu_seconds)"
previous_wall_seconds="$(monotonic_seconds)"

for ((sample_index = 1; sample_index <= sample_count; sample_index += 1)); do
  kill -0 "$pid" 2>/dev/null || fail 'prismBar exited during the audit'
  if [ "$sample_interval_seconds" -gt 0 ]; then
    sleep "$sample_interval_seconds"
  fi
  current_cpu_seconds="$(sample_cpu_seconds)"
  current_wall_seconds="$(monotonic_seconds)"
  cpu_value="$(awk \
    -v current_cpu="$current_cpu_seconds" \
    -v previous_cpu="$previous_cpu_seconds" \
    -v current_wall="$current_wall_seconds" \
    -v previous_wall="$previous_wall_seconds" '
      BEGIN {
        cpu_delta = current_cpu - previous_cpu
        wall_delta = current_wall - previous_wall
        if (cpu_delta < 0 || wall_delta <= 0) exit 1
        printf "%.3f", (cpu_delta / wall_delta) * 100
      }
    ')" || fail 'interval CPU usage is unavailable'
  previous_cpu_seconds="$current_cpu_seconds"
  previous_wall_seconds="$current_wall_seconds"
  footprint_value="$(sample_footprint_mib)"
  thread_listing="$(ps -M -p "$pid")" || fail 'thread count is unavailable'
  thread_value="$(awk 'NR > 1 && NF {count += 1} END {print count + 0}' <<< "$thread_listing")"
  [ "$thread_value" -gt 0 ] || fail 'thread count is unavailable'

  cpu_total="$(awk -v total="$cpu_total" -v value="$cpu_value" 'BEGIN {printf "%.3f", total + value}')"
  maximum_interval_cpu="$(awk -v current="$maximum_interval_cpu" -v value="$cpu_value" \
    'BEGIN {printf "%.3f", (value > current ? value : current)}')"
  maximum_footprint="$(awk -v current="$maximum_footprint" -v value="$footprint_value" \
    'BEGIN {printf "%.3f", (value > current ? value : current)}')"
  maximum_threads="$(awk -v current="$maximum_threads" -v value="$thread_value" \
    'BEGIN {print (value > current ? value : current)}')"
  if [ "$sample_index" -eq 1 ]; then
    initial_footprint="$footprint_value"
    initial_threads="$thread_value"
  fi
  ending_footprint="$footprint_value"
  ending_threads="$thread_value"
done

average_cpu="$(awk -v total="$cpu_total" -v count="$sample_count" \
  'BEGIN {printf "%.3f", total / count}')"
footprint_growth="$(awk -v ending="$ending_footprint" -v initial="$initial_footprint" \
  'BEGIN {printf "%.3f", ending - initial}')"
thread_growth="$((ending_threads - initial_threads))"
awk -v value="$maximum_interval_cpu" -v limit="$maximum_idle_cpu_percent" \
  'BEGIN {exit !(value < limit)}' || fail 'settled idle CPU exceeds the runtime budget'
awk -v value="$maximum_footprint" -v limit="$maximum_footprint_mib" \
  'BEGIN {exit !(value < limit)}' || fail 'physical footprint exceeds the runtime budget'
awk -v value="$footprint_growth" -v limit="$maximum_footprint_growth_mib" \
  'BEGIN {exit !(value <= limit)}' || fail 'physical footprint growth exceeds the runtime budget'
[ "$thread_growth" -le "$maximum_thread_growth" ] || fail 'thread growth exceeds the runtime budget'

repository_root="$(git rev-parse --show-toplevel)"
source_revision="$(/usr/libexec/PlistBuddy -c 'Print :PrismSourceRevision' \
  /Applications/prismBar.app/Contents/Info.plist 2>/dev/null)" || \
  fail 'the installed source revision is unavailable'
if [ -z "$output_path" ]; then
  output_path="$repository_root/build/runtime/prismBar-runtime-$source_revision.json"
fi
mkdir -p "$(dirname "$output_path")"

jq -n \
  --arg sourceRevision "$source_revision" \
  --arg measuredAt "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  --argjson sampleCount "$sample_count" \
  --argjson averageCPU "$average_cpu" \
  --argjson maximumIntervalCPU "$maximum_interval_cpu" \
  --argjson initialFootprint "$initial_footprint" \
  --argjson endingFootprint "$ending_footprint" \
  --argjson footprintGrowth "$footprint_growth" \
  --argjson maximumFootprint "$maximum_footprint" \
  --argjson initialThreads "$initial_threads" \
  --argjson endingThreads "$ending_threads" \
  --argjson threadGrowth "$thread_growth" \
  --argjson maximumThreads "$maximum_threads" \
  --argjson cpuBudget "$maximum_idle_cpu_percent" \
  --argjson footprintBudget "$maximum_footprint_mib" \
  --argjson footprintGrowthBudget "$maximum_footprint_growth_mib" \
  --argjson threadGrowthBudget "$maximum_thread_growth" \
  '{
    "schemaVersion": 1,
    "product": "prismBar",
    "sourceRevision": $sourceRevision,
    "measuredAt": $measuredAt,
    "sampleCount": $sampleCount,
    "averageIdleCPUPercent": $averageCPU,
    "maximumIntervalCPUPercent": $maximumIntervalCPU,
    "initialPhysicalFootprintMiB": $initialFootprint,
    "endingPhysicalFootprintMiB": $endingFootprint,
    "physicalFootprintGrowthMiB": $footprintGrowth,
    "maximumPhysicalFootprintMiB": $maximumFootprint,
    "initialThreadCount": $initialThreads,
    "endingThreadCount": $endingThreads,
    "threadGrowth": $threadGrowth,
    "maximumThreadCount": $maximumThreads,
    "budgets": {
      "maximumIdleCPUPercentExclusive": $cpuBudget,
      "maximumPhysicalFootprintMiBExclusive": $footprintBudget,
      "maximumPhysicalFootprintGrowthMiBInclusive": $footprintGrowthBudget,
      "maximumThreadGrowthInclusive": $threadGrowthBudget
    },
    "contentCaptured": false,
    "result": "passed"
  }' > "$output_path"

printf 'Runtime budget audit passed: CPU %s%%, footprint %s MiB, threads %s.\n' \
  "$average_cpu" "$maximum_footprint" "$maximum_threads"
printf 'Evidence written.\n'
