#!/bin/bash
# Kanata uninstallation script

set -e

DAEMON_DEST="/Library/LaunchDaemons/com.kanata.plist"
VHID_DAEMON_DEST="/Library/LaunchDaemons/com.kanata.virtualhid-daemon.plist"

echo "Uninstalling Kanata LaunchDaemons..."

# Unload and remove Kanata LaunchDaemon first (it depends on VirtualHID)
if [ -e "$DAEMON_DEST" ]; then
    echo "Unloading Kanata LaunchDaemon..."
    sudo launchctl unload "$DAEMON_DEST" 2>/dev/null || true

    echo "Removing symlink..."
    sudo rm -f "$DAEMON_DEST"

    echo "Kanata LaunchDaemon uninstalled!"
else
    echo "No Kanata LaunchDaemon found at $DAEMON_DEST"
fi

# Unload and remove VirtualHID daemon
if [ -e "$VHID_DAEMON_DEST" ]; then
    echo "Unloading VirtualHID LaunchDaemon..."
    sudo launchctl unload "$VHID_DAEMON_DEST" 2>/dev/null || true

    echo "Removing symlink..."
    sudo rm -f "$VHID_DAEMON_DEST"

    echo "VirtualHID LaunchDaemon uninstalled!"
else
    echo "No VirtualHID LaunchDaemon found at $VHID_DAEMON_DEST"
fi

# Check if still running
if ps aux | grep -v grep | grep -q "[k]anata"; then
    echo "Warning: Kanata process still running!"
    echo "   Run: sudo pkill kanata"
else
    echo "Kanata is not running"
fi
