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

# Use claude in print mode with haiku for a fast, cheap summary
SUMMARY=$(claude -p --model claude-haiku-4-5-20251001 --max-turns 1 \
  "Summarize this task in 3-6 words for a tmux pane title. No quotes, no punctuation. Just the short title.

$TRUNCATED" 2>/dev/null)

if [ -n "$SUMMARY" ]; then
  tmux select-pane -T "claude[$DIR]: $SUMMARY"
fi

exit 0
