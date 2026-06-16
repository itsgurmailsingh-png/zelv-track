#!/bin/bash
# Clean launch — kills stale instances and clears Hive locks before starting.

LOCK_DIR="$HOME/.local/share/com.example.routine_tracker/routine_tracker"

# Kill any running instance
pkill -f "routine_tracker" 2>/dev/null
sleep 0.5

# Clear stale lock files
rm -f "$LOCK_DIR"/*.lock 2>/dev/null

# Launch
cd "$(dirname "$0")"
flutter run -d linux
