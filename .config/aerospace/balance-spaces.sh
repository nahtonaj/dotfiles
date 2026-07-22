#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
set -euo pipefail

# balance-spaces.sh -- Evenly distribute AeroSpace workspaces 1-10 across monitors.
#
# Formula (integer/floor arithmetic):
#   target_monitor = (ws - 1) * count / 10 + 1      (1-based)
#
# Resulting splits by monitor count:
#   1 monitor:  all 10 on monitor 1
#   2 monitors: 1-5 on mon1, 6-10 on mon2
#   3 monitors: 1-3 on mon1, 4-6 on mon2, 7-10 on mon3   (4/3/3)
#   4 monitors: 1-2 on mon1, 3-5 on mon2, 6-7 on mon3, 8-10 on mon4  (2/3/2/3)
#   5 monitors: 1-2 on mon1, 3-4 on mon2, 5-6 on mon3, 7-8 on mon4, 9-10 on mon5
#
# Invoked by:
#   - aerospace service-mode esc reload binding (alt-shift-; then esc)
#   - after-startup-command (cold boot / login)

count=$(aerospace list-monitors --count 2>/dev/null || echo "")

# Default to 1 if empty, non-numeric, or less than 1
if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -lt 1 ]; then
  count=1
fi

for ws in $(seq 1 10); do
  mon=$(( (ws - 1) * count / 10 + 1 ))
  aerospace move-workspace-to-monitor --workspace "$ws" "$mon" >/dev/null 2>&1 || true
done

# Refresh sketchybar's per-monitor space filtering after redistribution.
sketchybar --trigger spaces_refresh 2>/dev/null || true
