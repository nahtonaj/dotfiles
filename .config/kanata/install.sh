#!/bin/bash
# Kanata installation script
# This script sets up kanata as a LaunchDaemon with symlinked plist files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VHID_PLIST_SOURCE="$SCRIPT_DIR/com.kanata.virtualhid-daemon.plist"
VHID_DAEMON_DEST="/Library/LaunchDaemons/com.kanata.virtualhid-daemon.plist"

PLIST_SOURCE="$SCRIPT_DIR/com.kanata.plist"
DAEMON_DEST="/Library/LaunchDaemons/com.kanata.plist"
AGENT_DEST="$HOME/Library/LaunchAgents/com.kanata.plist"

echo "Installing Kanata LaunchDaemons..."

# Check if plist sources exist
if [ ! -f "$VHID_PLIST_SOURCE" ]; then
    echo "Error: $VHID_PLIST_SOURCE not found!"
    exit 1
fi

if [ ! -f "$PLIST_SOURCE" ]; then
    echo "Error: $PLIST_SOURCE not found!"
    exit 1
fi

# --- Install VirtualHID Daemon (must start before kanata) ---

echo "Installing Karabiner-VirtualHIDDevice-Daemon..."

# Unload existing VirtualHID daemon if loaded
if [ -e "$VHID_DAEMON_DEST" ]; then
    echo "Unloading existing VirtualHID LaunchDaemon..."
    sudo launchctl unload "$VHID_DAEMON_DEST" 2>/dev/null || true

    echo "Removing old plist..."
    sudo rm -f "$VHID_DAEMON_DEST"
fi

# Create symlink
echo "Creating symlink: $VHID_DAEMON_DEST -> $VHID_PLIST_SOURCE"
sudo ln -s "$VHID_PLIST_SOURCE" "$VHID_DAEMON_DEST"

# Set correct permissions
echo "Setting permissions..."
sudo chown root:wheel "$VHID_DAEMON_DEST"

# Load the daemon
echo "Loading VirtualHID LaunchDaemon..."
sudo launchctl load "$VHID_DAEMON_DEST"

# Wait for VirtualHID daemon socket to come up before starting kanata
sleep 2

# --- Install Kanata ---

echo "Installing Kanata LaunchDaemon..."

# Clean up old LaunchAgent if it exists
if [ -e "$AGENT_DEST" ]; then
    echo "Removing old LaunchAgent..."
    launchctl unload "$AGENT_DEST" 2>/dev/null || true
    rm -f "$AGENT_DEST"
fi

# Unload existing LaunchDaemon if loaded
if [ -e "$DAEMON_DEST" ]; then
    echo "Unloading existing Kanata LaunchDaemon..."
    sudo launchctl unload "$DAEMON_DEST" 2>/dev/null || true

    # Remove old file (whether symlink or regular file)
    echo "Removing old plist..."
    sudo rm -f "$DAEMON_DEST"
fi

# Create symlink
echo "Creating symlink: $DAEMON_DEST -> $PLIST_SOURCE"
sudo ln -s "$PLIST_SOURCE" "$DAEMON_DEST"

# Set correct permissions
echo "Setting permissions..."
sudo chown root:wheel "$DAEMON_DEST"

# Load the daemon
echo "Loading Kanata LaunchDaemon..."
sudo launchctl load "$DAEMON_DEST"

# Wait a moment for it to start
sleep 2

# Check if it's running
if ps aux | grep -v grep | grep -q "[k]anata"; then
    echo "Kanata is running!"
    ps aux | grep -v grep | grep "[k]anata" | head -1
else
    echo "Warning: Kanata may not be running. Check logs:"
    echo "   tail /tmp/kanata.log"
    echo "   tail /tmp/kanata.error.log"
fi

echo ""
echo "To reload config: sudo pkill -USR1 kanata"
echo "To uninstall: $SCRIPT_DIR/uninstall.sh"
