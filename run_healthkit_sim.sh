#!/bin/bash
set -e

SIMULATOR_UDID=$(xcrun simctl list devices | grep "(Booted)" | grep -E -o '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1)

if [ -z "$SIMULATOR_UDID" ]; then
    echo "Error: No booted simulator found. Boot one in Xcode or Simulator.app first."
    exit 1
fi

echo "Launching on simulator: $SIMULATOR_UDID"
exec /opt/homebrew/bin/flutter run -d "$SIMULATOR_UDID"
