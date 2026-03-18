#!/bin/bash

# Reload sketchybar when called (triggered by display change events)
sleep 1  # Small delay to ensure display change is complete
sketchybar --reload
