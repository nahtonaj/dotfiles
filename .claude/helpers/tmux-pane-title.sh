#!/bin/bash
# Updates tmux pane title with an LLM-generated summary of the user prompt.
# Triggered by UserPromptSubmit hook.

[ -z "$TMUX" ] && exit 0

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

# Skip very short prompts (confirmations like "yes", "ok") — keep existing title
[ ${#PROMPT} -lt 10 ] && exit 0

DIR=$(basename "$PWD")

# Truncate prompt to keep the LLM call fast
TRUNCATED=$(echo "$PROMPT" | head -5 | cut -c1-500)


if [ -n "$SUMMARY" ]; then
  tmux select-pane -T "claude[$DIR]: $TRUNCATED"
fi

exit 0
