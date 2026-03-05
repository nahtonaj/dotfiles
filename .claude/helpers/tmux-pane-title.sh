#!/bin/bash
# Updates tmux pane title with context from the Claude prompt.
# Triggered by UserPromptSubmit hook.

[ -z "$TMUX" ] && exit 0

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

# Skip very short prompts (confirmations like "yes", "ok")
[ ${#PROMPT} -lt 10 ] && exit 0

DIR=$(basename "$PWD")

# First line, truncated to 60 chars for clean pane border display
SUMMARY=$(echo "$PROMPT" | head -1 | cut -c1-60)
[ ${#SUMMARY} -gt 59 ] && SUMMARY="${SUMMARY}…"

tmux select-pane -T "claude[$DIR]: $SUMMARY"
exit 0
