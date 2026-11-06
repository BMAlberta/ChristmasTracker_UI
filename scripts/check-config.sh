#!/bin/bash
# Verify effective xcconfig values for API_MODE, APP_ENVIRONMENT, SENTRY_DSN, and
# PRODUCT_BUNDLE_IDENTIFIER across Debug, QA, and Release configurations.
# Exits non-zero with a descriptive message on any mismatch.
# Never prints a SENTRY_DSN value.
cd "$(dirname "$0")/.." || exit 1

PROJECT="ChristmasTracker/ChristmasTracker.xcodeproj"
SCHEME="ChristmasTracker"
EXPECTED_BUNDLE_ID="com.alberta.ChristmasTracker"
FAIL=0

check_config() {
    local CFG=$1
    local EXPECTED_API_MODE=$2
    local EXPECTED_APP_ENV=$3
    local DSN_MUST_BE_EMPTY=$4
    local EXPECTED_API_BASE_URL=$5

    SETTINGS=$(xcodebuild -showBuildSettings \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CFG" 2>/dev/null)

    actual_api_mode=$(echo "$SETTINGS" | grep "^\s*API_MODE\s*=" | sed 's/.*= *//' | tr -d '[:space:]')
    actual_app_env=$(echo "$SETTINGS" | grep "^\s*APP_ENVIRONMENT\s*=" | sed 's/.*= *//' | tr -d '[:space:]')
    actual_dsn=$(echo "$SETTINGS" | grep "^\s*SENTRY_DSN\s*=" | sed 's/.*= *//' | tr -d '[:space:]')
    actual_bundle=$(echo "$SETTINGS" | grep "^\s*PRODUCT_BUNDLE_IDENTIFIER\s*=" | grep -v "DERIVE_MACCATALYST" | sed 's/.*= *//' | tr -d '[:space:]')
    actual_inactivity_lock=$(echo "$SETTINGS" | grep "^\s*INACTIVITY_LOCK_MINUTES\s*=" | sed 's/.*= *//' | tr -d '[:space:]')
    actual_api_base_url=$(echo "$SETTINGS" | grep "^\s*API_BASE_URL\s*=" | sed 's/.*= *//' | tr -d '[:space:]')

    if [ "$actual_api_mode" != "$EXPECTED_API_MODE" ]; then
        echo "FAIL [$CFG] API_MODE: expected '$EXPECTED_API_MODE', got '$actual_api_mode'"
        FAIL=1
    fi

    if [ "$actual_app_env" != "$EXPECTED_APP_ENV" ]; then
        echo "FAIL [$CFG] APP_ENVIRONMENT: expected '$EXPECTED_APP_ENV', got '$actual_app_env'"
        FAIL=1
    fi

    if [ "$DSN_MUST_BE_EMPTY" = "1" ] && [ -n "$actual_dsn" ]; then
        echo "FAIL [$CFG] SENTRY_DSN must be empty but is non-empty"
        FAIL=1
    fi

    if [ "$actual_bundle" != "$EXPECTED_BUNDLE_ID" ]; then
        echo "FAIL [$CFG] PRODUCT_BUNDLE_IDENTIFIER: expected '$EXPECTED_BUNDLE_ID', got '$actual_bundle'"
        FAIL=1
    fi

    if [ "$actual_inactivity_lock" != "10" ]; then
        echo "FAIL [$CFG] INACTIVITY_LOCK_MINUTES: expected '10', got '$actual_inactivity_lock'"
        FAIL=1
    fi

    if [ "$actual_api_base_url" != "$EXPECTED_API_BASE_URL" ]; then
        echo "FAIL [$CFG] API_BASE_URL: expected '$EXPECTED_API_BASE_URL', got '$actual_api_base_url'"
        FAIL=1
    fi
}

# CONFIGURATION  API_MODE  APP_ENVIRONMENT  DSN_MUST_BE_EMPTY  EXPECTED_API_BASE_URL
check_config "Debug"   "mock" "development" "1" "http://localhost:3010"
check_config "QA"      "mock" "qa"          "1" "http://localhost:3010"
check_config "Release" "real" "production"  "0" "https://api.bmalberta.com"

PLIST="ChristmasTracker/ChristmasTracker/Info.plist"
if ! grep -q "NSFaceIDUsageDescription" "$PLIST"; then
    echo "FAIL NSFaceIDUsageDescription missing from $PLIST"
    FAIL=1
fi

# ATS: NSAllowsLocalNetworking must be present; NSAllowsArbitraryLoads must NOT be present/true
if ! grep -q "NSAllowsLocalNetworking" "$PLIST"; then
    echo "FAIL NSAllowsLocalNetworking missing from $PLIST"
    FAIL=1
fi
if grep -q "NSAllowsArbitraryLoads" "$PLIST"; then
    echo "FAIL NSAllowsArbitraryLoads must not be present in $PLIST"
    FAIL=1
fi
if grep -q "NSAllowsArbitraryLoadsInWebContent" "$PLIST"; then
    echo "FAIL NSAllowsArbitraryLoadsInWebContent must not be present in $PLIST"
    FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
    echo "check-config: all configuration values OK"
fi
exit "$FAIL"
