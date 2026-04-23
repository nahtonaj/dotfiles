#!/usr/bin/env bash
# team-cleanup.sh -- Clean up stale Claude Code team/task directories
# Runs on SessionEnd. Removes teams whose tmux panes (lead + members) are ALL dead.
# Safety: skips recently modified configs and requires ALL panes dead before removal.

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

TEAMS_DIR="$HOME/.claude/teams"
TASKS_DIR="$HOME/.claude/tasks"
STALE_THRESHOLD=60  # seconds -- skip configs modified within this window

# Exit early if no teams directory
if [ ! -d "$TEAMS_DIR" ]; then
  exit 0
fi

# Collect live pane IDs (empty if not in tmux)
live_panes=""
if command -v tmux &>/dev/null && tmux info &>/dev/null 2>&1; then
  live_panes=$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null || true)
fi

# If we can't check tmux at all, bail out -- never remove what we can't verify
if [ -z "$live_panes" ]; then
  echo >&2 "[team-cleanup] Cannot reach tmux -- skipping all teams"
  exit 0
fi

now=$(date +%s)

for team_dir in "$TEAMS_DIR"/*/; do
  [ -d "$team_dir" ] || continue
  team_name=$(basename "$team_dir")

  config="$team_dir/config.json"

  # Condition 1: config.json must exist and be readable
  if [ ! -f "$config" ] || [ ! -r "$config" ]; then
    echo >&2 "[team-cleanup] Skipping $team_name (no readable config.json)"
    continue
  fi

  # Condition 5: skip configs modified within the last STALE_THRESHOLD seconds
  config_mtime=$(stat -c %Y "$config" 2>/dev/null || stat -f %m "$config" 2>/dev/null || echo 0)
  age=$(( now - config_mtime ))
  if [ "$age" -lt "$STALE_THRESHOLD" ]; then
    echo >&2 "[team-cleanup] Skipping $team_name (config modified ${age}s ago, threshold ${STALE_THRESHOLD}s)"
    continue
  fi

  # Condition 2 & 3: extract ALL pane IDs (lead + members) from config
  all_panes=$(grep -oE '%[0-9]+' "$config" 2>/dev/null || true)

  # No pane references at all -- can't verify, skip
  if [ -z "$all_panes" ]; then
    echo >&2 "[team-cleanup] Skipping $team_name (no pane references in config)"
    continue
  fi

  # Condition 3 & 4: check that ALL referenced panes are dead
  any_alive=false
  for pane in $all_panes; do
    if echo "$live_panes" | grep -qxF "$pane"; then
      any_alive=true
      echo >&2 "[team-cleanup] Skipping $team_name (pane $pane still alive)"
      break
    fi
  done

  if [ "$any_alive" = true ]; then
    continue
  fi

  # All panes confirmed dead -- safe to remove
  if [ "$DRY_RUN" = true ]; then
    echo >&2 "[team-cleanup] DRY-RUN: would remove $team_name (all panes dead)"
  else
    echo >&2 "[team-cleanup] Removing $team_name (all panes dead)"
    rm -rf "$team_dir"
    rm -rf "$TASKS_DIR/$team_name"
  fi
done
