#!/bin/bash
# Gate: build, unit tests, and no prohibited frameworks in changed lines.
cd "$(dirname "$0")/.." || exit 1
FAIL=0

echo "=== verify: derived spec ==="
scripts/make-client-spec.sh --check || { echo "=== verify: DERIVED SPEC OUT OF DATE — run scripts/make-client-spec.sh ==="; exit 1; }

echo "=== verify: build ==="
scripts/build.sh || { echo "=== verify: BUILD FAILED ==="; exit 1; }

echo "=== verify: configuration check ==="
scripts/check-config.sh || { echo "=== verify: CONFIG CHECK FAILED ==="; FAIL=1; }

echo "=== verify: unit tests ==="
scripts/test.sh || { echo "=== verify: TESTS FAILED ==="; FAIL=1; }

echo "=== verify: TrackerAPI package tests ==="
swift test --package-path "LocalPackages/TrackerAPI" || { echo "=== verify: PACKAGE TESTS FAILED ==="; FAIL=1; }

echo "=== verify: TrackerAPI Xcode scheme ==="
TRACKER_API_LOG="/tmp/ct-trackerapi-build.log"
xcodebuild build \
  -scheme "TrackerAPI" \
  -project "ChristmasTracker/ChristmasTracker.xcodeproj" \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "/tmp/ct-derived" \
  -skipPackagePluginValidation > "$TRACKER_API_LOG" 2>&1
if [ $? -ne 0 ]; then
  echo "--- errors (first 20) ---"
  grep -E "error:|BUILD FAILED" "$TRACKER_API_LOG" | head -20
  echo "=== verify: TRACKERAPI XCODE BUILD FAILED ==="
  FAIL=1
else
  tail -2 "$TRACKER_API_LOG"
fi

echo "=== verify: prohibited frameworks in changed lines ==="
if git rev-parse --verify master > /dev/null 2>&1; then
  if git diff master...HEAD -U0 -- '*.swift' | grep -E '^\+[^+].*(import Combine|DispatchQueue)'; then
    echo "=== verify: PROHIBITED FRAMEWORK in changed lines ==="
    FAIL=1
  fi
else
  echo "WARNING: no local master branch; skipped this check"
fi

if [ "$FAIL" -eq 0 ]; then echo "=== verify: OK ==="; else echo "=== verify: FAILED ==="; fi
exit "$FAIL"