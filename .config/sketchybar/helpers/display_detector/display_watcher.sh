#!/bin/bash

# This script uses a more reliable method to detect display changes
# by using the displayplacer tool if available, or falling back to system_profiler

LOG_FILE="/tmp/sketchybar_display_watcher.log"
echo "Display watcher started at $(date)" > $LOG_FILE

# Function to get current display configuration
get_display_config() {
  # Try to use displayplacer if available (more reliable)
  if command -v displayplacer &> /dev/null; then
    displayplacer list | grep -E 'ID|Resolution|Origin'
  else
    # Fall back to system_profiler
    system_profiler SPDisplaysDataType | grep -E 'Display Type|Resolution|Main Display|Mirror|Online|Active'
  fi
}

# Initial display configuration
CURRENT_CONFIG=$(get_display_config)
echo "Initial display configuration:" >> $LOG_FILE
echo "$CURRENT_CONFIG" >> $LOG_FILE

# Set up a trap to clean up on exit
trap "echo 'Display watcher exiting at $(date)' >> $LOG_FILE; exit" SIGINT SIGTERM

# Main loop to check for display changes
while true; do
  sleep 1
  NEW_CONFIG=$(get_display_config)
  
  if [ "$NEW_CONFIG" != "$CURRENT_CONFIG" ]; then
    echo "Display change detected at $(date)" >> $LOG_FILE
    echo "New configuration:" >> $LOG_FILE
    echo "$NEW_CONFIG" >> $LOG_FILE
    
    CURRENT_CONFIG="$NEW_CONFIG"
    
    # Force sketchybar to reload
    echo "Reloading sketchybar..." >> $LOG_FILE
    sketchybar --reload
    
    # Sleep a bit longer after a change to avoid rapid reloads
    sleep 3
  fi
done
