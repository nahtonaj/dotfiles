#!/usr/bin/env bash
# team-cleanup.sh — Clean up stale Claude Code team/task directories
# Runs on SessionEnd. Removes teams whose member tmux panes are all dead.

set -euo pipefail

TEAMS_DIR="$HOME/.claude/teams"
TASKS_DIR="$HOME/.claude/tasks"

# Exit early if no teams directory
if [ ! -d "$TEAMS_DIR" ]; then
  exit 0
fi

# Collect live pane IDs (empty if not in tmux)
live_panes=""
if command -v tmux &>/dev/null && tmux info &>/dev/null 2>&1; then
  live_panes=$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null || true)
fi

for team_dir in "$TEAMS_DIR"/*/; do
  [ -d "$team_dir" ] || continue
  team_name=$(basename "$team_dir")

  config="$team_dir/config.json"

  # No config.json → stale, remove
  if [ ! -f "$config" ]; then
    echo >&2 "[team-cleanup] Removing $team_name (no config.json)"
    rm -rf "$team_dir"
    rm -rf "$TASKS_DIR/$team_name"
    continue
  fi

  # Extract pane IDs from members array (looks for %NNN patterns)
  member_panes=$(grep -oE '%[0-9]+' "$config" 2>/dev/null || true)

  # No member panes referenced → stale, remove
  if [ -z "$member_panes" ]; then
    echo >&2 "[team-cleanup] Removing $team_name (no member panes)"
    rm -rf "$team_dir"
    rm -rf "$TASKS_DIR/$team_name"
    continue
  fi

  # If we can't check tmux, skip (don't remove teams we can't verify)
  if [ -z "$live_panes" ]; then
    continue
  fi

  # Check if ANY member pane is still alive
  any_alive=false
  for pane in $member_panes; do
    if echo "$live_panes" | grep -qF "$pane"; then
      any_alive=true
      break
    fi
  done

  if [ "$any_alive" = false ]; then
    echo >&2 "[team-cleanup] Removing $team_name (all member panes dead)"
    rm -rf "$team_dir"
    rm -rf "$TASKS_DIR/$team_name"
  fi
done
