#!/bin/bash
set -o pipefail

echo "=== verify.sh: build ==="
bash "scripts/build.sh"
BUILD_STATUS=$?

if [ $BUILD_STATUS -ne 0 ]; then
    echo "=== verify.sh: BUILD FAILED ==="
    exit $BUILD_STATUS
fi

echo "=== verify.sh: test ==="
bash "scripts/test.sh"
TEST_STATUS=$?

if [ $TEST_STATUS -ne 0 ]; then
    echo "=== verify.sh: TESTS FAILED ==="
    exit $TEST_STATUS
fi

echo "=== verify.sh: prohibited pattern check ==="
VIOLATIONS=$(git diff master...HEAD -- "*.swift" \
    | grep "^+" \
    | grep -v "^+++" \
    | grep -E "import Combine|DispatchQueue")

if [ -n "$VIOLATIONS" ]; then
    echo "FAIL: prohibited patterns found in diff:"
    echo "$VIOLATIONS"
    exit 1
fi

echo "=== verify.sh: PASSED ==="
exit 0
