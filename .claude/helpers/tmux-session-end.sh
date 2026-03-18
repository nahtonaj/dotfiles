#!/bin/bash
[ -z "$TMUX" ] && exit 0
tmux set-option -w automatic-rename on 2>/dev/null
exit 0
