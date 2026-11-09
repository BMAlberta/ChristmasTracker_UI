#!/bin/bash
# scripts/test-destination.sh — Self-contained tests for scripts/lib/destination.sh.
# Uses a stub simctl and JSON fixtures only. Never calls the real simctl, a simulator,
# xcodebuild, or the network. Prints "=== test-destination.sh: N passed, M failed ===".
# Exit: 0 when all tests pass, 1 on any failure.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${SCRIPT_DIR}/lib/destination.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
CURRENT_TEST=""

test_start() { CURRENT_TEST="$1"; }
test_pass() { PASS=$(( PASS + 1 )); echo "  PASS: ${CURRENT_TEST}"; }
test_fail() { FAIL=$(( FAIL + 1 )); echo "  FAIL: ${CURRENT_TEST} — $*" >&2; }

# ---------------------------------------------------------------------------
# Stub simctl: prints $STUB_FIXTURE, or fails when STUB_FAIL=1. Logs every call.
# ---------------------------------------------------------------------------
STUB="${WORK}/simctl-stub"
CALLS="${WORK}/calls.log"
cat > "$STUB" <<'EOF'
#!/bin/bash
echo "called: $*" >> "$STUB_CALLS"
if [ "${STUB_FAIL:-0}" = "1" ]; then exit 1; fi
cat "$STUB_FIXTURE"
EOF
chmod +x "$STUB"

# A device entry: dev NAME UDID AVAILABLE(true|false)
dev() {
  printf '{"name":"%s","udid":"%s","isAvailable":%s,"state":"Shutdown"}' "$1" "$2" "$3"
}

# A fixture file: fixture FILE RUNTIME_KEY DEVICE_JSON [RUNTIME_KEY DEVICE_JSON ...]
fixture() {
  local file="$1"; shift
  local body="" sep=""
  while [ "$#" -ge 2 ]; do
    body="${body}${sep}\"com.apple.CoreSimulator.SimRuntime.$1\":[$2]"
    sep=","
    shift 2
  done
  printf '{"devices":{%s}}' "$body" > "$file"
}

OUT="" ERR="" RC=0
# run_resolve FIXTURE_FILE [DEST_VALUE]
run_resolve() {
  : > "$CALLS"
  OUT="$(DEST="${2:-}" SIMCTL="$STUB" STUB_CALLS="$CALLS" STUB_FIXTURE="$1" STUB_FAIL="${STUB_FAIL:-0}" \
    bash -c 'source "$1"; resolve_destination' _ "$LIB" 2> "${WORK}/err")"
  RC=$?
  ERR="$(cat "${WORK}/err")"
}

expect_out() {
  if [ "$RC" -eq 0 ] && [ "$OUT" = "$1" ]; then test_pass
  else test_fail "expected rc 0 and '$1', got rc $RC and '$OUT' (stderr: $ERR)"; fi
}

expect_failure_with() {
  if [ "$RC" -ne 0 ] && [ -z "$OUT" ] && printf '%s' "$ERR" | grep -q "$1"; then test_pass
  else test_fail "expected non-zero, empty stdout, stderr containing '$1'; got rc $RC out '$OUT' err '$ERR'"; fi
}

F="${WORK}/fixture.json"

# ---------------------------------------------------------------------------
test_start "DEST override wins, is printed unchanged, and simctl is not called"
fixture "$F" "iOS-27-2" "$(dev 'iPhone 18 Pro' AAAA true)"
run_resolve "$F" "platform=iOS Simulator,name=Custom,OS=1.0"
if [ "$RC" -eq 0 ] && [ "$OUT" = "platform=iOS Simulator,name=Custom,OS=1.0" ] && [ ! -s "$CALLS" ]; then test_pass
else test_fail "rc $RC out '$OUT' calls '$(cat "$CALLS")'"; fi

test_start "newest iOS runtime is chosen among several"
fixture "$F" \
  "iOS-26-5" "$(dev 'iPhone 17 Pro' OLD-1 true)" \
  "iOS-27-2" "$(dev 'iPhone 18 Pro' NEW-1 true)" \
  "iOS-18-0" "$(dev 'iPhone 16 Pro' OLDER-1 true)"
run_resolve "$F"
expect_out "platform=iOS Simulator,id=NEW-1"

test_start "version ordering is numeric, not lexical (iOS 26.10 beats 26.5)"
fixture "$F" \
  "iOS-26-5" "$(dev 'iPhone 17 Pro' V5 true)" \
  "iOS-26-10" "$(dev 'iPhone 17 Pro' V10 true)"
run_resolve "$F"
expect_out "platform=iOS Simulator,id=V10"

test_start "a runtime with no iPhone is skipped in favor of an older one"
fixture "$F" \
  "iOS-27-2" "$(dev 'iPad Pro 13-inch' PAD-1 true)" \
  "iOS-26-5" "$(dev 'iPhone 17 Pro' PHONE-1 true)"
run_resolve "$F"
expect_out "platform=iOS Simulator,id=PHONE-1"

test_start "non-iOS runtimes are ignored"
fixture "$F" \
  "tvOS-28-0" "$(dev 'iPhone Lookalike' TV-1 true)" \
  "watchOS-12-0" "$(dev 'iPhone Lookalike' WATCH-1 true)" \
  "iOS-26-5" "$(dev 'iPhone 17 Pro' IOS-1 true)"
run_resolve "$F"
expect_out "platform=iOS Simulator,id=IOS-1"

test_start "iPhone 17 Pro is preferred when present on the newest runtime"
fixture "$F" "iOS-27-2" \
  "$(dev 'iPhone 16e' E-1 true),$(dev 'iPhone 17 Pro' PRO-1 true),$(dev 'iPhone 11' ELEVEN-1 true)"
run_resolve "$F"
expect_out "platform=iOS Simulator,id=PRO-1"

test_start "without iPhone 17 Pro the first iPhone by name is chosen"
fixture "$F" "iOS-27-2" \
  "$(dev 'iPhone 18 Pro' P18 true),$(dev 'iPad mini' PAD true),$(dev 'iPhone 16e' E16 true)"
run_resolve "$F"
expect_out "platform=iOS Simulator,id=E16"

test_start "runtimes with the same version are pooled (device-specific variant)"
fixture "$F" \
  "iOS-27-2" "$(dev 'iPhone 18 Pro' MAIN-1 true)" \
  "iOS-27-2-iPhone19-4" "$(dev 'iPhone 17 Pro' VARIANT-1 true)"
run_resolve "$F"
expect_out "platform=iOS Simulator,id=VARIANT-1"

test_start "a device marked unavailable is ignored"
fixture "$F" "iOS-27-2" \
  "$(dev 'iPhone 17 Pro' GONE-1 false),$(dev 'iPhone 18 Pro' HERE-1 true)"
run_resolve "$F"
expect_out "platform=iOS Simulator,id=HERE-1"

test_start "only unavailable iPhones on the newest runtime falls back to an older runtime"
fixture "$F" \
  "iOS-27-2" "$(dev 'iPhone 18 Pro' GONE-2 false)" \
  "iOS-26-5" "$(dev 'iPhone 17 Pro' OLD-2 true)"
run_resolve "$F"
expect_out "platform=iOS Simulator,id=OLD-2"

test_start "no available runtime gives a non-zero exit and the install message"
printf '{"devices":{}}' > "$F"
run_resolve "$F"
expect_failure_with "Xcode Settings, Components"

test_start "only unavailable devices gives a non-zero exit and the install message"
fixture "$F" "iOS-27-2" "$(dev 'iPhone 18 Pro' GONE-3 false)"
run_resolve "$F"
expect_failure_with "Xcode Settings, Components"

test_start "malformed JSON gives a clean error and a non-zero exit"
printf '{"devices": {not json' > "$F"
run_resolve "$F"
expect_failure_with "malformed JSON"

test_start "valid JSON of the wrong shape gives a clean error and a non-zero exit"
printf '[1,2,3]' > "$F"
run_resolve "$F"
expect_failure_with "malformed JSON"

test_start "a failing simctl gives a clean error and a non-zero exit"
fixture "$F" "iOS-27-2" "$(dev 'iPhone 18 Pro' X-1 true)"
STUB_FAIL=1 run_resolve "$F"
expect_failure_with "could not list simulators"

test_start "the chosen destination is reported once on stderr; stdout holds only the destination"
fixture "$F" "iOS-27-2" "$(dev 'iPhone 18 Pro' ONCE-1 true)"
run_resolve "$F"
LINES="$(printf '%s\n' "$ERR" | grep -c '^destination: ')"
if [ "$RC" -eq 0 ] && [ "$LINES" -eq 1 ] && [ "$OUT" = "platform=iOS Simulator,id=ONCE-1" ]; then test_pass
else test_fail "rc $RC info lines $LINES out '$OUT'"; fi

test_start "the stub (never the real simctl) was the only simulator source used"
if grep -q '^called: list devices available -j$' "$CALLS"; then test_pass
else test_fail "stub call log: '$(cat "$CALLS")'"; fi

echo "=== test-destination.sh: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ]
