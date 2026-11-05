#!/bin/bash
# Build the app for the simulator. Override the destination with DEST="...".
cd "$(dirname "$0")/.." || exit 1
DEST="${DEST:-platform=iOS Simulator,name=iPhone 17 Pro,OS=latest}"
CONFIGURATION="${CONFIGURATION:-Debug}"
LOG="/tmp/ct-build.log"
xcodebuild build \
  -project "ChristmasTracker/ChristmasTracker.xcodeproj" \
  -scheme "ChristmasTracker" \
  -configuration "$CONFIGURATION" \
  -destination "$DEST" \
  -derivedDataPath "/tmp/ct-derived" \
  -skipPackagePluginValidation > "$LOG" 2>&1
STATUS=$?
echo "--- errors (first 20) ---"
grep -E "error:|Unable to find a destination|BUILD FAILED" "$LOG" | head -20
echo "--- last 8 lines of $LOG ---"
tail -8 "$LOG"
exit "$STATUS"