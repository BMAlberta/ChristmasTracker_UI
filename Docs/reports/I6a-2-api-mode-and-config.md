# I6a Story 2 — API_MODE and observability configuration

## Files added and changed

**Added:**
- `ChristmasTracker/Config-Secrets.example.xcconfig` — tracked template with placeholder DSN and `$()` escape explanation
- `ChristmasTracker/ChristmasTrackerTests/Core/Configuration/APIModeTests.swift` — 15 new tests
- `scripts/check-config.sh` — configuration invariant checker

**Modified:**
- `ChristmasTracker/ChristmasTracker/Info.plist` — added `API_MODE`, `SENTRY_DSN`, `APP_ENVIRONMENT` keys
- `ChristmasTracker/ChristmasTracker/Config/Config.xcconfig` — removed stale `PRODUCT_BUNDLE_IDENTIFIER`; added `SENTRY_DSN_RELEASE =` fallback, optional `#include?` of secrets file (before fallback so secrets override), `API_MODE`, `APP_ENVIRONMENT`, `SENTRY_DSN`
- `ChristmasTracker/ChristmasTracker/Config/Config-Debug.xcconfig` — removed stale `PRODUCT_BUNDLE_IDENTIFIER`; added `API_MODE = mock`, `APP_ENVIRONMENT = development`, `SENTRY_DSN =` after include
- `ChristmasTracker/ChristmasTracker/Config/Config-QA.xcconfig` — removed stale `PRODUCT_BUNDLE_IDENTIFIER`; added `API_MODE = mock`, `APP_ENVIRONMENT = qa`, `SENTRY_DSN =` after include
- `ChristmasTracker/ChristmasTracker/Core/Configuration/AppConfiguration.swift` — added `APIMode` enum, `readConfiguration(from:)` pure function, `apiMode`/`sentryDSN`/`appEnvironment` properties; retained `environment`/`isDebug` compile-time helpers for existing tests
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` — replaced `#if DEBUG` block in `AppDependencies.make()` with `switch AppConfiguration.apiMode`
- `scripts/build.sh` — added `CONFIGURATION` env variable (default `Debug`) so `CONFIGURATION=Release scripts/build.sh` builds Release
- `scripts/verify.sh` — added `check-config.sh` call after build step
- `.gitignore` — added `ChristmasTracker/Config-Secrets.xcconfig`

## verify.sh raw output

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- tests: 80 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## Test arithmetic

Previous total: 65. New tests added: 15 (`APIModeTests` × 7 + `ReadConfigurationTests` × 8). New total: **80**. ✓

New test names:
- `APIModeTests/parse 'mock' returns mock`
- `APIModeTests/parse 'real' returns real`
- `APIModeTests/parse ' Mock ' (whitespace + mixed case) returns mock`
- `APIModeTests/parse 'REAL' (uppercase) returns real`
- `APIModeTests/parse nil returns real`
- `APIModeTests/parse empty string returns real`
- `APIModeTests/parse unknown value returns real`
- `ReadConfigurationTests/apiMode from info dictionary with 'mock'`
- `ReadConfigurationTests/apiMode from info dictionary with 'real'`
- `ReadConfigurationTests/apiMode from info dictionary missing API_MODE key defaults to real`
- `ReadConfigurationTests/sentryDSN is nil when SENTRY_DSN is empty`
- `ReadConfigurationTests/sentryDSN is nil when SENTRY_DSN is whitespace only`
- `ReadConfigurationTests/sentryDSN is non-nil and trimmed for a real value`
- `ReadConfigurationTests/appEnvironment falls back to 'production' when key is missing`
- `ReadConfigurationTests/readConfiguration reads all duration keys correctly`

## Verification claims

### (a) Before/after bundle IDs match P5 — verified by running -showBuildSettings

| Config | Before | After |
|---|---|---|
| App Debug | com.alberta.ChristmasTracker | com.alberta.ChristmasTracker ✓ |
| App QA | com.alberta.ChristmasTracker | com.alberta.ChristmasTracker ✓ |
| App Release | com.alberta.ChristmasTracker | com.alberta.ChristmasTracker ✓ |

MARKETING_VERSION and CURRENT_PROJECT_VERSION unchanged in all cases.

Stale xcconfig lines removed: `PRODUCT_BUNDLE_IDENTIFIER = com.christmastracker.ios` (Config.xcconfig), `com.christmastracker.ios.dev` (Config-Debug.xcconfig), `com.christmastracker.ios.qa` (Config-QA.xcconfig). All were overridden by target-level settings; after-state identical to before-state.

### (b) check-config.sh passes — verified by running scripts/check-config.sh

```
check-config: all configuration values OK
```

### (c) Fake-DSN Release build and Info.plist inspection — verified by running commands

Temporary `Config-Secrets.xcconfig` created at `ChristmasTracker/Config-Secrets.xcconfig` with:
```
SENTRY_DSN_RELEASE = https:/$()/examplekey@o0.ingest.sentry.io/0
```

`CONFIGURATION=Release scripts/build.sh` → BUILD SUCCEEDED (Release-iphonesimulator path confirmed in last 8 lines).

`/usr/libexec/PlistBuddy -c "Print"` on the built `Release-iphonesimulator` app's `Info.plist`:
```
SENTRY_DSN = https://examplekey@o0.ingest.sentry.io/0
API_MODE = real
APP_ENVIRONMENT = production
```

The `$()` trick correctly produces `//` in the expanded value. ✓

Temporary file deleted; `git status` confirmed it does not appear (gitignored).

### (d) xcconfig files in Debug app bundle — verified by find command

```
find "/tmp/ct-derived/Build/Products/Debug-iphonesimulator/ChristmasTracker.app" -name "*.xcconfig"
```
Output:
```
.../ChristmasTracker.app/Config-Debug.xcconfig
.../ChristmasTracker.app/Config-QA.xcconfig
.../ChristmasTracker.app/Config.xcconfig
```

**Finding:** The three tracked xcconfig files are copied into the Debug app bundle. They live inside the file-synchronized folder `ChristmasTracker/ChristmasTracker/Config/` which Xcode treats as a resource folder. These files contain no secrets (DSN is empty in Debug/QA; Release has no secrets in the tracked file). `Config-Secrets.xcconfig` is correctly absent. Not fixed per the brief.

## scripts/check-config.sh (verbatim)

```bash
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

    SETTINGS=$(xcodebuild -showBuildSettings \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CFG" 2>/dev/null)

    actual_api_mode=$(echo "$SETTINGS" | grep "^\s*API_MODE\s*=" | sed 's/.*= *//' | tr -d '[:space:]')
    actual_app_env=$(echo "$SETTINGS" | grep "^\s*APP_ENVIRONMENT\s*=" | sed 's/.*= *//' | tr -d '[:space:]')
    actual_dsn=$(echo "$SETTINGS" | grep "^\s*SENTRY_DSN\s*=" | sed 's/.*= *//' | tr -d '[:space:]')
    actual_bundle=$(echo "$SETTINGS" | grep "^\s*PRODUCT_BUNDLE_IDENTIFIER\s*=" | grep -v "DERIVE_MACCATALYST" | sed 's/.*= *//' | tr -d '[:space:]')

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
}

# CONFIGURATION  API_MODE  APP_ENVIRONMENT  DSN_MUST_BE_EMPTY
check_config "Debug"   "mock" "development" "1"
check_config "QA"      "mock" "qa"          "1"
check_config "Release" "real" "production"  "0"

if [ "$FAIL" -eq 0 ]; then
    echo "check-config: all configuration values OK"
fi
exit "$FAIL"
```

## scripts/verify.sh diff (relevant addition)

```bash
echo "=== verify: configuration check ==="
scripts/check-config.sh || { echo "=== verify: CONFIG CHECK FAILED ==="; FAIL=1; }
```

## Gate 2

**Convention reviewer:** No new async/throws functions at repo/service layer — @Instrumented not required. `APIMode` is `nonisolated` — correct. `readConfiguration` is `nonisolated` — correct. No design tokens (configuration layer). Naming: `APIMode` with `-ing`-suffix-irrelevant (it's an enum, not a protocol). Single commit per story. No violations.

**Acceptance reviewer:** All Gate 1 criteria met:
1. ✓ Info.plist has `API_MODE`, `SENTRY_DSN`, `APP_ENVIRONMENT` as `$(...)`.
2. ✓ Debug: `API_MODE = mock`, `APP_ENVIRONMENT = development`, `SENTRY_DSN =` (confirmed by check-config.sh).
3. ✓ QA: `API_MODE = mock`, `APP_ENVIRONMENT = qa`, `SENTRY_DSN =` (confirmed by check-config.sh).
4. ✓ Release: `API_MODE = real`, `APP_ENVIRONMENT = production`, `SENTRY_DSN = $(SENTRY_DSN_RELEASE)`.
5. ✓ `Config-Secrets.xcconfig` gitignored; `Config-Secrets.example.xcconfig` tracked with placeholder.
6. ✓ `AppConfiguration` has `apiMode`, `sentryDSN`, `appEnvironment`.
7. ✓ `APIMode.parse` is `nonisolated`, handles all cases.
8. ✓ `AppDependencies.make()` uses `switch AppConfiguration.apiMode` — no `#if DEBUG`.
9. ✓ Mock types confirmed not wrapped in `#if DEBUG` (P5 inventory).
10. ✓ `scripts/check-config.sh` passes for all three configurations.
11. ✓ `scripts/verify.sh` calls `check-config.sh`.
12. ✓ After-state bundle IDs match P5 before-state exactly.
13. ✓ `scripts/verify.sh` passes: 80 tests.

## Stuck-detector log

Build error round 1: `nonisolated` property accessing `@MainActor` `config` — fixed by marking `config` itself `nonisolated`. Test failure round 1: existing tests reference `AppConfiguration.environment`/`isDebug` — restored those compile-time helpers. Script failure round 1: `declare -A` not supported in macOS bash 3.2 — rewrote with a function + positional args. Config ordering issue: `SENTRY_DSN_RELEASE =` fallback after `#include?` overrode secrets file — moved fallback before include. 4 issues resolved; not repeated.

## Deviations

- `scripts/build.sh` modified to add `CONFIGURATION` env variable support — this was required by the story's Release build check and described in the brief ("if scripts/build.sh has no configuration override, add an optional CONFIGURATION environment variable").
- `AppConfiguration.environment` and `AppConfiguration.isDebug` retained (with `#if DEBUG` guards) to avoid breaking existing tests. These are compile-time helpers unrelated to the new xcconfig-driven `appEnvironment`.

## Not done or partial

None.
