#!/bin/bash
# Run the unit tests only, serially. Optional arguments: test classes or tests,
# for example: scripts/test.sh ChristmasTrackerTests/ListServiceTests
# Override the destination with DEST="...".
cd "$(dirname "$0")/.." || exit 1
DEST="${DEST:-platform=iOS Simulator,name=iPhone 17 Pro,OS=latest}"
LOG="/tmp/ct-test.log"
RESULT="/tmp/ct-results-$(date +%s).xcresult"
ONLY=()
if [ "$#" -eq 0 ]; then
  ONLY=("-only-testing:ChristmasTrackerTests")
else
  for t in "$@"; do ONLY+=("-only-testing:$t"); done
fi
xcodebuild test \
  -project "ChristmasTracker/ChristmasTracker.xcodeproj" \
  -scheme "ChristmasTracker" \
  -destination "$DEST" \
  -derivedDataPath "/tmp/ct-derived" \
  -resultBundlePath "$RESULT" \
  -parallel-testing-enabled NO \
  "${ONLY[@]}" > "$LOG" 2>&1
STATUS=$?

echo "--- xcodebuild exit status: $STATUS ---"
if [ ! -d "$RESULT" ]; then
  echo "NO RESULT BUNDLE WAS WRITTEN (tests did not start). Last lines of the log:"
  tail -20 "$LOG" | cut -c1-200
  exit 1
fi

SUMMARY=$(xcrun xcresulttool get test-results summary --path "$RESULT" 2>/dev/null)
PASSED=$(echo "$SUMMARY" | jq -r '.passedTests // 0')
FAILED=$(echo "$SUMMARY" | jq -r '.failedTests // 0')
SKIPPED=$(echo "$SUMMARY" | jq -r '.skippedTests // 0')
echo "--- tests: $PASSED passed, $FAILED failed, $SKIPPED skipped ---"
echo "$SUMMARY" | jq -r '.testFailures[]? | "FAIL \(.testIdentifierString): \(.failureText)"' | head -30
if [ $((PASSED + FAILED)) -eq 0 ]; then
  echo "WARNING: no tests ran"
  [ "$STATUS" -eq 0 ] && STATUS=1
fi
echo "--- result bundle: $RESULT ---"
exit "$STATUS"