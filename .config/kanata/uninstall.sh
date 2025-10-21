#!/bin/bash
# Kanata uninstallation script

set -e

DAEMON_DEST="/Library/LaunchDaemons/com.kanata.plist"

echo "🗑️  Uninstalling Kanata LaunchDaemon..."

# Unload and remove LaunchDaemon
if [ -e "$DAEMON_DEST" ]; then
    echo "⏸️  Unloading LaunchDaemon..."
    sudo launchctl unload "$DAEMON_DEST" 2>/dev/null || true

    echo "🧹 Removing symlink..."
    sudo rm -f "$DAEMON_DEST"

    echo "✅ Kanata LaunchDaemon uninstalled!"
else
    echo "ℹ️  No LaunchDaemon found at $DAEMON_DEST"
fi

# Check if still running
if ps aux | grep -v grep | grep -q "[k]anata"; then
    echo "⚠️  Warning: Kanata process still running!"
    echo "   Run: sudo pkill kanata"
else
    echo "✅ Kanata is not running"
fi
