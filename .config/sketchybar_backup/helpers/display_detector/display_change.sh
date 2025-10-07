#!/bin/bash

# This script monitors display changes and triggers a sketchybar reload
# when the active display changes

# Log file for debugging
LOG_FILE="/tmp/sketchybar_display.log"
echo "Display detector started at $(date)" > $LOG_FILE

# Function to get current display configuration
get_display_info() {
  system_profiler SPDisplaysDataType | grep -E 'Display Type|Resolution|Main Display|Mirror|Online|Active'
}

# Initial display info
CURRENT_DISPLAY=$(get_display_info)
echo "Initial display configuration:" >> $LOG_FILE
echo "$CURRENT_DISPLAY" >> $LOG_FILE

# Loop forever, checking for display changes
while true; do
  sleep 2
  NEW_DISPLAY=$(get_display_info)
  
  # If display info has changed, trigger a reload
  if [ "$CURRENT_DISPLAY" != "$NEW_DISPLAY" ]; then
    echo "Display change detected at $(date)" >> $LOG_FILE
    echo "New configuration:" >> $LOG_FILE
    echo "$NEW_DISPLAY" >> $LOG_FILE
    
    CURRENT_DISPLAY="$NEW_DISPLAY"
    
    # Directly reload sketchybar instead of just triggering an event
    echo "Reloading sketchybar..." >> $LOG_FILE
    sketchybar --reload
    
    # Also trigger the event as a backup
    sketchybar --trigger display_change
  fi
done
