#!/bin/bash
# Fired by launchd (com.sketchybar.display-reload) on changes to
# /Library/Preferences/com.apple.windowserver.displays.plist, i.e. whenever a
# display is connected, disconnected, or reconfigured.
#
# Fixes two things that break on display changes:
#   1. sketchybar's bar can vanish -> restart the service so the bar is rebuilt
#      against the new display topology (more reliable than --reload here).
#   2. aerospace does not redistribute workspaces on reconnect -> re-run the
#      balancer for a deterministic, consistent split across present monitors.
#
# launchd runs with a minimal PATH, so Homebrew binaries (sketchybar,
# aerospace) must be made resolvable explicitly. This was the original Bug 1:
# bare `sketchybar` -> "command not found" / exit 127 on every fire.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Debounce: a single display reconfiguration emits several fsevents in quick
# succession. Record our PID, let the topology settle, then bail if a newer
# invocation has superseded us, so only the last event does the work.
LOCK="/tmp/display-change.lock"
echo $$ > "$LOCK"
sleep 2
[ "$(cat "$LOCK" 2>/dev/null)" = "$$" ] || exit 0

# 1. Rebuild the sketchybar bar on the new topology.
launchctl kickstart -k "gui/$(id -u)/homebrew.mxcl.sketchybar"

# Give sketchybar a moment to come back up before aerospace fires
# wm_workspace_change triggers at it during rebalancing.
sleep 1

# 2. Redistribute aerospace workspaces deterministically across present monitors.
BALANCE="/Users/jon.gao/dotfiles/.config/aerospace/balance-spaces.sh"
[ -x "$BALANCE" ] && "$BALANCE"
