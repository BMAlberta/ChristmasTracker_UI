#!/bin/bash
set -o pipefail

DEST="${DEST:-platform=iOS Simulator,name=iPhone 16 Pro}"
LOG=$(mktemp /tmp/ct-test.XXXXXX)

xcodebuild \
    -project "ChristmasTracker/ChristmasTracker.xcodeproj" \
    -scheme ChristmasTracker \
    -destination "$DEST" \
    -derivedDataPath /tmp/ct-build \
    -only-testing:ChristmasTrackerTests \
    test \
    "$@" > "$LOG" 2>&1
STATUS=$?
tail -60 "$LOG"
exit $STATUS
