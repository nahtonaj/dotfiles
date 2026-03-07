#!/bin/bash
[ -z "$TMUX" ] && exit 0

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

# Find active task subject from team's task list
TASK_SUBJECT=""
if [ -n "$TEAM" ]; then
  TASK_DIR="$HOME/.claude/tasks/$TEAM"
  if [ -d "$TASK_DIR" ]; then
    # Find first in_progress task, fall back to first pending task
    TASK_SUBJECT=$(
      for f in "$TASK_DIR"/*.json; do
        [ -f "$f" ] && cat "$f"
      done 2>/dev/null | jq -rs '
        (map(select(.status == "in_progress")) | first // null) //
        (map(select(.status == "pending")) | first // null) |
        .subject // empty
      ' 2>/dev/null
    )
  fi
fi

# Build window name: active task subject > team name > directory
if [ -n "$TASK_SUBJECT" ]; then
  WIN_NAME=$(echo "$TASK_SUBJECT" | cut -c1-40)
elif [ -n "$TEAM" ]; then
  WIN_NAME="$TEAM"
else
  WIN_NAME="$DIR"
fi

# Set pane title
SUMMARY=$(echo "$PROMPT" | head -1 | cut -c1-60)
tmux select-pane -T "claude[${DIR}]: ${SUMMARY}"

# Set window name to task/team context
tmux rename-window "$WIN_NAME" 2>/dev/null
tmux set-option -w automatic-rename off 2>/dev/null

# Set session name based on team (only if current session name is generic)
if [ -n "$TEAM" ]; then
  CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null)
  # Only rename if session has a numeric name (default tmux naming)
  if [[ "$CURRENT_SESSION" =~ ^[0-9]+$ ]]; then
    tmux rename-session "$TEAM" 2>/dev/null
  fi
fi

exit 0
