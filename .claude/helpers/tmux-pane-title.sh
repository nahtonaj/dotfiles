#!/bin/bash
[ -z "$TMUX" ] && exit 0

# Disable automatic rename immediately — must happen before any early exit
# so that tmux never overrides the Claude-set window name mid-session.
tmux set-option -w automatic-rename off 2>/dev/null

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0
[ ${#PROMPT} -lt 10 ] && exit 0

DIR=$(basename "$PWD")

# Read most recent active team name
TEAM=""
TEAM_DIR="$HOME/.claude/teams"
if [ -d "$TEAM_DIR" ]; then
  TEAM=$(ls -t "$TEAM_DIR" 2>/dev/null | head -1)
fi

# Build prompt summary for pane title
SUMMARY=$(echo "$PROMPT" | head -1 | cut -c1-60)

# Try routing task summary for window name (written by hook-handler.cjs route)
TASK_FILE="/tmp/claude-tmux-task-summary"
WIN_SUMMARY=""
if [ -f "$TASK_FILE" ]; then
  FILE_AGE=$(( $(date +%s) - $(stat -c %Y "$TASK_FILE" 2>/dev/null || echo 0) ))
  if [ "$FILE_AGE" -lt 5 ]; then
    WIN_SUMMARY=$(head -1 "$TASK_FILE" | sed 's/[^a-zA-Z0-9 _.,!?:-]//g' | sed 's/^[[:space:]]*//' | cut -c1-40 | sed 's/[[:space:]]*$//')
  fi
fi

# Fall back to prompt-based summary
if [ -z "$WIN_SUMMARY" ]; then
  WIN_SUMMARY=$(echo "$SUMMARY" | sed 's/[^a-zA-Z0-9 _.,!?-]//g' | sed 's/^[[:space:]]*//' | cut -c1-40 | sed 's/[[:space:]]*$//')
fi

# Window name: routing summary > prompt summary > directory fallback
if [ -n "$WIN_SUMMARY" ]; then
  WIN_NAME="$WIN_SUMMARY"
else
  WIN_NAME="$DIR"
fi

# Set pane title
tmux select-pane -T "claude[${DIR}]: ${SUMMARY}"

# Set window name (automatic-rename already disabled at script entry)
tmux rename-window "$WIN_NAME" 2>/dev/null

# Set session name based on team (only if current session name is generic)
if [ -n "$TEAM" ]; then
  CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null)
  # Only rename if session has a numeric name (default tmux naming)
  if [[ "$CURRENT_SESSION" =~ ^[0-9]+$ ]]; then
    tmux rename-session "$TEAM" 2>/dev/null
  fi
fi

exit 0
