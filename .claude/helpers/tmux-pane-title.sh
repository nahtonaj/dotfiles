#!/bin/bash
# Set tmux pane title from user prompt. Window naming is handled by
# the permission-hook (scripts/permission-hook.cjs) which reads the
# session name from the daemon -- this keeps the tmux tab in sync
# with the dashboard. This hook only sets the pane title for context.
[ -z "$TMUX" ] && exit 0

# Disable automatic rename so the permission-hook's window name sticks
tmux set-option -w automatic-rename off 2>/dev/null

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0
[ ${#PROMPT} -lt 10 ] && exit 0

DIR=$(basename "$PWD")
SUMMARY=$(echo "$PROMPT" | head -1 | cut -c1-60)

# Set pane title only (window name is managed by permission-hook)
tmux select-pane -T "claude[${DIR}]: ${SUMMARY}" 2>/dev/null

exit 0
