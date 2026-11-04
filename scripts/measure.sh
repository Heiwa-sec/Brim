#!/bin/bash
# Idle cost of a running Brim: average CPU over N seconds, memory footprint, leaks. Usage: scripts/measure.sh [seconds]
set -euo pipefail
PID=$(pgrep -x Brim) || { echo "Brim is not running"; exit 1; }
SECONDS_TO_SAMPLE=${1:-60}
echo "Sampling CPU for ${SECONDS_TO_SAMPLE}s (leave the pointer away from the notch)..."
for _ in $(seq "$SECONDS_TO_SAMPLE"); do ps -o %cpu= -p "$PID"; sleep 1; done |
  awk '{ s += $1; if ($1 > m) m = $1 } END { printf "CPU avg %.2f%%  peak %.2f%%\n", s / NR, m }'
footprint "$PID" 2>/dev/null | grep -E "Footprint|phys_footprint" | head -2 || true
leaks "$PID" 2>&1 | grep "leaks for"
