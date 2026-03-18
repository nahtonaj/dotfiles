# Automatic Display Reload Configuration

This document describes the automatic reload setup for Sketchybar when display configurations change.

## Overview

Sketchybar is configured to automatically reload when displays are connected, disconnected, or reconfigured. This ensures the bar adapts to different display setups without manual intervention.

## Components

### 1. Reload Script
**Location:** `~/.config/sketchybar/helpers/reload_on_display_change.sh`

Simple script that reloads Sketchybar with a 1-second delay to ensure display changes are complete.

### 2. Launch Agent
**Location:** `~/Library/LaunchAgents/com.sketchybar.display-reload.plist`

A macOS Launch Agent that monitors the system display preferences file for changes and triggers the reload script automatically.

**Monitored file:** `/Library/Preferences/com.apple.windowserver.displays.plist`

## How It Works

The Launch Agent uses macOS's `WatchPaths` feature to monitor the window server display preferences file. When you:
- Connect or disconnect an external display
- Change display resolution or arrangement
- Enable/disable mirroring

The system updates the preferences file, triggering the Launch Agent to run the reload script.

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
