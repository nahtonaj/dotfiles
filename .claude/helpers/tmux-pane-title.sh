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

CONTEXT="${TEAM:-$DIR}"

# Set pane title
SUMMARY=$(echo "$PROMPT" | head -1 | cut -c1-60)
tmux select-pane -T "claude[${DIR}]: ${SUMMARY}"

# Set window name to team/task context
tmux rename-window "${CONTEXT}" 2>/dev/null
tmux set-option -w automatic-rename off 2>/dev/null

exit 0
