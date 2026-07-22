# Automatic Display Reload Configuration

This document describes the automatic display-change handler for Sketchybar and AeroSpace.

## Overview

When displays are connected, disconnected, or reconfigured, the handler script:

1. **Sets PATH explicitly** -- launchd runs with a minimal PATH (`/usr/bin:/bin:/usr/sbin:/sbin`), so `/opt/homebrew/bin` must be prepended for Homebrew-installed binaries (sketchybar, aerospace) to be found. This fixes the original exit-127 "command not found" failure.
2. **Debounces** -- a single display reconfiguration fires multiple fsevents in quick succession. The script uses a PID-based lock file so only the last invocation does work.
3. **Restarts the sketchybar service** via `launchctl kickstart -k` instead of `sketchybar --reload`, which is more reliable for rebuilding the bar against a new display topology.
4. **Re-runs AeroSpace's balance-spaces.sh** for deterministic workspace redistribution across present monitors (AeroSpace 0.20.x has no native monitor connect/disconnect callback).

## Components

### 1. Handler Script
**Location:** `~/.config/sketchybar/helpers/reload_on_display_change.sh`

Handles PATH setup, debounce, sketchybar service restart, and aerospace workspace rebalancing.

### 2. Launch Agent
**Location:** `~/Library/LaunchAgents/com.sketchybar.display-reload.plist`

A macOS Launch Agent that monitors the system display preferences file for changes and triggers the handler script automatically.

**Monitored file:** `/Library/Preferences/com.apple.windowserver.displays.plist`

## How It Works

The Launch Agent uses macOS's `WatchPaths` feature to monitor the window server display preferences file. When you:
- Connect or disconnect an external display
- Change display resolution or arrangement
- Enable/disable mirroring

The system updates the preferences file, triggering the Launch Agent to run the handler script.

**Important:** This is event-driven, not a background process. The script only runs when actual display changes occur.

## Management Commands

### Enable/Disable
```bash
# Disable the automatic reload
launchctl unload ~/Library/LaunchAgents/com.sketchybar.display-reload.plist

# Enable the automatic reload
launchctl load -w ~/Library/LaunchAgents/com.sketchybar.display-reload.plist
```

### Status and Logs
```bash
# Check if the agent is loaded
launchctl list | grep sketchybar

# View logs
tail -f /tmp/sketchybar-display-reload.log

# View error logs
tail -f /tmp/sketchybar-display-reload.error.log
```

### Manual Reload
```bash
# Manually reload Sketchybar
sketchybar --reload

# Or run the helper script directly
~/.config/sketchybar/helpers/reload_on_display_change.sh
```

## Troubleshooting

If automatic reload isn't working:

1. Verify the Launch Agent is loaded:
   ```bash
   launchctl list | grep com.sketchybar.display-reload
   ```

2. Check the logs for errors:
   ```bash
   cat /tmp/sketchybar-display-reload.error.log
   ```

3. Ensure the script is executable:
   ```bash
   chmod +x ~/.config/sketchybar/helpers/reload_on_display_change.sh
   ```

4. Reload the Launch Agent:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.sketchybar.display-reload.plist
   launchctl load -w ~/Library/LaunchAgents/com.sketchybar.display-reload.plist
   ```

## Configuration Date
Configured: 2026-01-30
