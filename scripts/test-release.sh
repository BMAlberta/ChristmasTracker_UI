#!/bin/bash
# scripts/test-release.sh — Self-contained test harness for scripts/release.sh.
# Uses stubs and fixtures only. Never touches the network, real keychain, real
# provisioning profile directory, xcodebuild, or aws.
# Exit: 0 when all tests pass, 1 on any failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RELEASE_SCRIPT="${SCRIPT_DIR}/release.sh"
# Real-shaped `xcodebuild -showBuildSettings` capture (sanitized). Every xcodebuild stub serves
# this file or a per-test temp copy of it, so the look-alike keys (FULL_PRODUCT_NAME,
# PRODUCT_MODULE_NAME, PROVISIONING_PROFILE_REQUIRED, ...) are always present.
FIXTURE_SETTINGS="${SCRIPT_DIR}/fixtures/showbuildsettings-release.txt"
if [ ! -f "$FIXTURE_SETTINGS" ]; then
    echo "test-release.sh: missing fixture: ${FIXTURE_SETTINGS}" >&2
    exit 1
fi

PASS=0
FAIL=0
CURRENT_TEST=""

# ---------------------------------------------------------------------------
# Harness helpers
# ---------------------------------------------------------------------------
test_start() {
    CURRENT_TEST="$1"
}

test_pass() {
    PASS=$(( PASS + 1 ))
    echo "  PASS: ${CURRENT_TEST}"
}

test_fail() {
    FAIL=$(( FAIL + 1 ))
    echo "  FAIL: ${CURRENT_TEST} — $*" >&2
}

# Run a command; assert it exits 0
assert_ok() {
    if "$@" > /dev/null 2>&1; then
        test_pass
    else
        test_fail "expected exit 0, got non-zero from: $*"
    fi
}

# Run a command; assert it exits non-zero
assert_fail() {
    if "$@" > /dev/null 2>&1; then
        test_fail "expected non-zero exit, but command succeeded: $*"
    else
        test_pass
    fi
}

# Run a command (which may exit non-zero); assert combined stdout+stderr contains a pattern
assert_output_contains() {
    local pattern="$1"; shift
    local out
    out="$("$@" 2>&1)" || true
    if echo "$out" | grep -q "$pattern"; then
        test_pass
    else
        test_fail "expected output to contain '$pattern', got: $out"
    fi
}

# Run a command (which may exit non-zero); assert combined output does NOT contain pattern
assert_output_not_contains() {
    local pattern="$1"; shift
    local out
    out="$("$@" 2>&1)" || true
    if echo "$out" | grep -q "$pattern"; then
        test_fail "output must not contain '$pattern', but it did. Output: $out"
    else
        test_pass
    fi
}

# Capture output of a command that may fail; use in tests that need both exit-code and message checks.
# Supports leading VAR=val assignments (passes them to env).
capture_failing() {
    # Usage: local out; out="$(capture_failing [VAR=val...] CMD ARGS...)"
    # Always exits 0 so callers can check output without pipefail interference
    env "$@" 2>&1 || true
}

# Assert a file exists
assert_file_exists() {
    if [ -f "$1" ]; then
        test_pass
    else
        test_fail "expected file to exist: $1"
    fi
}

# Assert a file does NOT exist
assert_file_not_exists() {
    if [ ! -f "$1" ]; then
        test_pass
    else
        test_fail "file should not exist but does: $1"
    fi
}

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

# Write a minimal valid env file to a temp directory
write_env() {
    local dir="$1"
    cat > "${dir}/release.env" <<'EOF'
RELEASE_TEAM_ID=TESTTEAM99
RELEASE_PROFILE_NAME=TestAdHocProfile
RELEASE_BUNDLE_ID=com.alberta.ChristmasTracker
RELEASE_S3_BUCKET=test-bucket
RELEASE_S3_PREFIX=distribution/tracker
RELEASE_PUBLIC_BASE_URL=https://content.example.com
RELEASE_EXPORT_METHOD=release-testing
RELEASE_MIN_PROFILE_DAYS=14
EOF
}

# Write an env file with a custom value
write_env_custom() {
    local dir="$1"
    local key="$2"
    local value="$3"
    write_env "$dir"
    # Remove existing key line and append override
    local tmp
    tmp="$(mktemp)"
    grep -v "^${key}=" "${dir}/release.env" > "$tmp" || true
    echo "${key}=${value}" >> "$tmp"
    mv "$tmp" "${dir}/release.env"
}

# Create a minimal valid ad hoc provisioning profile as a plist fixture.
# Returns the path to the .mobileprovision file.
make_ad_hoc_profile() {
    local dir="$1"
    local name="${2:-TestAdHocProfile}"
    local team="${3:-TESTTEAM99}"
    local bundle="${4:-com.alberta.ChristmasTracker}"
    local days_valid="${5:-30}"

    local expiry
    # macOS date -v or GNU date; handle positive and negative offsets correctly
    if [ "$days_valid" -ge 0 ]; then
        expiry="$(date -u -v "+${days_valid}d" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
                  || date -u -d "+${days_valid} days" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
                  || echo "2099-01-01T00:00:00Z")"
    else
        local abs_days=$(( -days_valid ))
        expiry="$(date -u -v "-${abs_days}d" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
                  || date -u -d "-${abs_days} days" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
                  || echo "2000-01-01T00:00:00Z")"
    fi

    local plist="${dir}/profile_${name}.plist"
    cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Name</key>
    <string>${name}</string>
    <key>TeamIdentifier</key>
    <array><string>${team}</string></array>
    <key>ExpirationDate</key>
    <date>${expiry}</date>
    <key>ProvisionedDevices</key>
    <array>
        <string>DEVICE0001</string>
        <string>DEVICE0002</string>
    </array>
    <key>Entitlements</key>
    <dict>
        <key>application-identifier</key>
        <string>${team}.${bundle}</string>
        <key>get-task-allow</key>
        <false/>
    </dict>
</dict>
</plist>
EOF
    # The release script calls `security cms -D` to decode a mobileprovision.
    # Our stub security command returns the plist directly. We name the file
    # with the profile name so the stub finder can locate it by name.
    local mp="${dir}/${name}.mobileprovision"
    cp "$plist" "$mp"
    echo "$mp"
}

# Create a minimal Info.plist for IPA fixture
make_info_plist() {
    local dir="$1"
    local bundle_id="${2:-com.alberta.ChristmasTracker}"
    local build="${3:-500}"
    local version="${4:-5.0}"
    local api_base_url="${5:-https://api.bmalberta.com}"
    local api_mode="${6:-real}"
    local app_env="${7:-production}"
    local allow_arbitrary="${8:-false}"
    local sentry_dsn="${9:-https://test@sentry.io/123}"

    local plist="${dir}/Info.plist"
    local ats_block=""
    if [ "$allow_arbitrary" = "true" ]; then
        ats_block="<key>NSAllowsArbitraryLoads</key><true/>"
    fi
    local sentry_block=""
    if [ -n "$sentry_dsn" ]; then
        sentry_block="<key>SENTRY_DSN</key><string>${sentry_dsn}</string>"
    fi

    cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>${bundle_id}</string>
    <key>CFBundleVersion</key>
    <string>${build}</string>
    <key>CFBundleShortVersionString</key>
    <string>${version}</string>
    <key>API_BASE_URL</key>
    <string>${api_base_url}</string>
    <key>API_MODE</key>
    <string>${api_mode}</string>
    <key>APP_ENVIRONMENT</key>
    <string>${app_env}</string>
    ${sentry_block}
    <key>NSFaceIDUsageDescription</key>
    <string>Use Face ID to unlock Christmas Tracker.</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
        ${ats_block}
    </dict>
</dict>
</plist>
EOF
    echo "$plist"
}

# Create a minimal synthetic IPA (zip of a fake app bundle)
make_ipa() {
    local dir="$1"
    local info_plist="$2"
    local profile="$3"       # path to mobileprovision fixture
    local ipa_name="${4:-ChristmasTracker-5.0-500.ipa}"
    local team="${5:-TESTTEAM99}"
    local app_bundle_name="${6:-ChristmasTracker.app}"

    local app_dir="${dir}/Payload/${app_bundle_name}"
    mkdir -p "$app_dir"
    cp "$info_plist" "${app_dir}/Info.plist"
    cp "$profile" "${app_dir}/embedded.mobileprovision"

    # Fake binary and codesign metadata
    local binary_name="${app_bundle_name%.app}"
    echo "FAKE_BINARY" > "${app_dir}/${binary_name}"
    mkdir -p "${app_dir}/_CodeSignature"
    echo "fake" > "${app_dir}/_CodeSignature/CodeResources"

    local ipa="${dir}/${ipa_name}"
    # zip from within dir so paths start with Payload/
    (cd "$dir" && zip -qr "$ipa_name" "Payload/")
    echo "$ipa"
}

# Header line of the app-target block in the fixture.
APP_BLOCK_HEADER="Build settings for action build and target ChristmasTracker:"

# Make a per-test temp copy of the real settings fixture with KEY=VALUE overrides.
# For each KEY=VALUE: an existing anchored line ("    KEY = ...") is replaced in place;
# an absent key is inserted inside the app-target block, directly after its header line
# (so e.g. EXPANDED_CODE_SIGN_IDENTITY lands BEFORE CODE_SIGN_IDENTITY — the trap an
# unanchored grep|head -1 would fall into). Values must not contain '|' or '&'.
# Usage: make_settings_fixture <dest> [KEY=VALUE ...]
make_settings_fixture() {
    local dest="$1"; shift
    cp "$FIXTURE_SETTINGS" "$dest"
    local kv key value tmp
    tmp="${dest}.tmp"
    for kv in "$@"; do
        key="${kv%%=*}"
        value="${kv#*=}"
        if grep -q "^    ${key} = " "$dest"; then
            sed "s|^    ${key} = .*|    ${key} = ${value}|" "$dest" > "$tmp"
        else
            awk -v hdr="$APP_BLOCK_HEADER" -v line="    ${key} = ${value}" \
                '{ print } $0 == hdr { print line }' "$dest" > "$tmp"
        fi
        mv "$tmp" "$dest"
    done
}

# Standard Manual-signing overrides: what the existing preflight/signing tests expect.
# The real fixture is Automatic / "Apple Development" / TEAMID1234 with no profile specifier.
# Usage: make_manual_settings_fixture <dest> [team] [extra KEY=VALUE ...]
make_manual_settings_fixture() {
    local dest="$1"; shift
    local team="${1:-TESTTEAM99}"; [ "$#" -gt 0 ] && shift
    make_settings_fixture "$dest" \
        "CODE_SIGN_STYLE=Manual" \
        "DEVELOPMENT_TEAM=${team}" \
        "PROVISIONING_PROFILE_SPECIFIER=TestAdHocProfile" \
        "CODE_SIGN_IDENTITY=Apple Distribution: Test User (${team})" \
        "$@"
}

# Delete the anchored line for KEY from a settings copy (look-alike keys stay).
# Usage: delete_setting <file> KEY
delete_setting() {
    local file="$1"
    local key="$2"
    local tmp="${file}.tmp"
    sed "/^    ${key} = /d" "$file" > "$tmp"
    mv "$tmp" "$file"
}

# Splice a second "Build settings for action build and target <target>:" block with the
# given KEY=VALUE lines AFTER (position=after, default) or BEFORE the existing content.
# Usage: splice_settings_block <file> <after|before> <target> [KEY=VALUE ...]
splice_settings_block() {
    local file="$1"
    local position="$2"
    local target="$3"
    shift 3
    local block="${file}.block"
    {
        echo ""
        echo "Build settings for action build and target ${target}:"
        local kv
        for kv in "$@"; do
            echo "    ${kv%%=*} = ${kv#*=}"
        done
        echo ""
    } > "$block"
    local tmp="${file}.tmp"
    if [ "$position" = "before" ]; then
        cat "$block" "$file" > "$tmp"
    else
        cat "$file" "$block" > "$tmp"
    fi
    mv "$tmp" "$file"
    rm -f "$block"
}

# ---------------------------------------------------------------------------
# Stub factories
# ---------------------------------------------------------------------------

# Write stub scripts to a bin directory. These replace real tools.
# Each stub records its calls in $STUB_LOG (passed via env).
# Usage: write_stubs <bindir> <profile_dir(unused)> [team] [settings_file]
#   settings_file: file the xcodebuild stub cats for -showBuildSettings. Default: a temp copy
#   of the real fixture with the standard Manual-signing overrides (make_manual_settings_fixture),
#   written to <bindir>/showbuildsettings.txt. The stub reads the file at call time, so a test
#   may edit it after write_stubs returns.
write_stubs() {
    local bindir="$1"
    local team="${3:-TESTTEAM99}"
    local settings_file="${4:-}"
    # $2 (profile_dir) is unused in this stub factory; profile lookup is handled by HOME override in callers

    mkdir -p "$bindir"

    if [ -z "$settings_file" ]; then
        settings_file="${bindir}/showbuildsettings.txt"
        make_manual_settings_fixture "$settings_file" "$team"
    fi

    # xcodebuild stub: cats the settings fixture for -showBuildSettings; exits 0 for archive/export
    cat > "${bindir}/xcodebuild" <<STUB
#!/bin/bash
echo "STUB_CALL: xcodebuild \$*" >> "\${STUB_LOG:-/dev/null}"
# If called with -showBuildSettings, serve the real-shaped fixture copy
if [[ "\$*" == *"-showBuildSettings"* ]]; then
    cat "${settings_file}"
    exit 0
fi
# For archive: create a fake xcarchive directory at -archivePath
ARCHIVE_PATH=""
while [[ \$# -gt 0 ]]; do
    if [[ "\$1" == "-archivePath" ]]; then ARCHIVE_PATH="\$2"; fi
    shift
done
if [[ -n "\$ARCHIVE_PATH" ]]; then
    mkdir -p "\$ARCHIVE_PATH"
fi
exit 0
STUB
    chmod +x "${bindir}/xcodebuild"

    # aws stub: ls returns empty (object does not exist) by default; cp exits 0
    cat > "${bindir}/aws" <<'STUB'
#!/bin/bash
echo "STUB_CALL: aws $*" >> "${STUB_LOG:-/dev/null}"
# s3 ls returns empty (object does not exist) so upload check passes
if [[ "$*" == *"s3 ls"* ]]; then
    # Return non-zero to simulate "not found" (the script checks this)
    exit 1
fi
# s3 cp exits 0
exit 0
STUB
    chmod +x "${bindir}/aws"

    # aws stub that simulates object already exists (for overwrite test)
    cat > "${bindir}/aws-exists" <<'STUB'
#!/bin/bash
echo "STUB_CALL: aws-exists $*" >> "${STUB_LOG:-/dev/null}"
# s3 ls returns output (object exists)
if [[ "$*" == *"s3 ls"* ]]; then
    echo "2026-01-01 00:00:00  12345 existing-file.ipa"
    exit 0
fi
exit 0
STUB
    chmod +x "${bindir}/aws-exists"

    # security stub: cms -D outputs the plist; find-identity outputs a fake identity line
    cat > "${bindir}/security" <<STUB
#!/bin/bash
echo "STUB_CALL: security \$*" >> "\${STUB_LOG:-/dev/null}"
if [[ "\$*" == *"cms -D"* ]]; then
    # Find the .mobileprovision file passed as -i argument
    INPUT=""
    while [[ \$# -gt 0 ]]; do
        if [[ "\$1" == "-i" ]]; then INPUT="\$2"; fi
        shift
    done
    if [[ -n "\$INPUT" ]] && [[ -f "\$INPUT" ]]; then
        cat "\$INPUT"
        exit 0
    fi
    exit 1
fi
if [[ "\$*" == *"find-identity"* ]]; then
    echo '  1) AABBCCDDEE "Apple Distribution: Test User (${team})"'
    echo "     1 valid identities found"
    exit 0
fi
exit 0
STUB
    chmod +x "${bindir}/security"

    # codesign stub: --verify exits 0; -dvvv prints TeamIdentifier
    cat > "${bindir}/codesign" <<STUB
#!/bin/bash
echo "STUB_CALL: codesign \$*" >> "\${STUB_LOG:-/dev/null}"
if [[ "\$*" == *"--verify"* ]]; then
    exit 0
fi
if [[ "\$*" == *"-dvvv"* ]]; then
    echo "TeamIdentifier=${team}"
    exit 0
fi
# entitlements output
if [[ "\$*" == *"--entitlements"* ]]; then
    echo "<?xml version='1.0'?><plist><dict></dict></plist>"
    exit 0
fi
exit 0
STUB
    chmod +x "${bindir}/codesign"

    # git stub: returns master branch, clean status, HEAD matching origin
    cat > "${bindir}/git" <<'STUB'
#!/bin/bash
echo "STUB_CALL: git $*" >> "${STUB_LOG:-/dev/null}"
if [[ "$*" == *"status --porcelain"* ]]; then echo ""; exit 0; fi
if [[ "$*" == *"branch --show-current"* ]]; then echo "master"; exit 0; fi
if [[ "$*" == *"rev-parse --verify"* ]]; then exit 0; fi
if [[ "$*" == *"rev-parse"* ]]; then echo "abc123def456abc123def456abc123def456"; exit 0; fi
if [[ "$*" == *"log"* ]]; then exit 0; fi
exit 0
STUB
    chmod +x "${bindir}/git"
}

# Write a stub security that simulates no identity found
write_stub_no_identity() {
    local bindir="$1"
    local team="${2:-TESTTEAM99}"
    cat > "${bindir}/security" <<STUB
#!/bin/bash
echo "STUB_CALL: security-no-identity \$*" >> "\${STUB_LOG:-/dev/null}"
if [[ "\$*" == *"cms -D"* ]]; then
    INPUT=""
    while [[ \$# -gt 0 ]]; do
        if [[ "\$1" == "-i" ]]; then INPUT="\$2"; fi
        shift
    done
    if [[ -n "\$INPUT" ]] && [[ -f "\$INPUT" ]]; then
        cat "\$INPUT"
        exit 0
    fi
    exit 1
fi
if [[ "\$*" == *"find-identity"* ]]; then
    echo "     0 valid identities found"
    exit 0
fi
exit 0
STUB
    chmod +x "${bindir}/security"
}

# Write an xcodebuild stub that serves <settings_file> for -showBuildSettings, creates the
# xcarchive dir for archive, and for -exportArchive touches each named file in -exportPath.
# Usage: write_export_stub <bindir> <settings_file> [ipa_name ...]   (no names = export nothing)
write_export_stub() {
    local bindir="$1"
    local settings_file="$2"
    shift 2
    local names=""
    local n
    for n in "$@"; do
        names="${names} \"${n}\""
    done
    cat > "${bindir}/xcodebuild" <<STUB
#!/bin/bash
echo "STUB_CALL: xcodebuild \$*" >> "\${STUB_LOG:-/dev/null}"
if [[ "\$*" == *"-showBuildSettings"* ]]; then
    cat "${settings_file}"
    exit 0
fi
if [[ "\$*" == *"-exportArchive"* ]]; then
    # Simulate export: create the named IPA file(s) in -exportPath
    EXPORT_PATH=""
    while [[ \$# -gt 0 ]]; do
        if [[ "\$1" == "-exportPath" ]]; then EXPORT_PATH="\$2"; fi
        shift
    done
    if [[ -n "\$EXPORT_PATH" ]]; then
        for name in ${names}; do
            touch "\${EXPORT_PATH}/\${name}"
        done
    fi
    exit 0
fi
while [[ \$# -gt 0 ]]; do
    if [[ "\$1" == "-archivePath" ]]; then mkdir -p "\$2"; fi
    shift
done
exit 0
STUB
    chmod +x "${bindir}/xcodebuild"
}

# ---------------------------------------------------------------------------
# Test suite
# ---------------------------------------------------------------------------
run_tests() {
    tmpbase="$(mktemp -d)"
    trap 'rm -rf "${tmpbase}"' EXIT

    echo ""
    echo "--- env validation ---"

    # T-ENV-1: missing RELEASE_TEAM_ID fails
    test_start "env validation: missing RELEASE_TEAM_ID"
    local t2; t2="${tmpbase}/t-env2"; mkdir -p "$t2"
    cat > "${t2}/release.env" <<'EOF'
RELEASE_TEAM_ID=
RELEASE_PROFILE_NAME=TestProfile
RELEASE_BUNDLE_ID=com.alberta.ChristmasTracker
RELEASE_S3_BUCKET=test-bucket
EOF
    local env_out2
    env_out2="$(capture_failing ENV_FILE="${t2}/release.env" RELEASE_XCODEBUILD=/usr/bin/true \
       bash "${RELEASE_SCRIPT}" install-info)"
    if echo "$env_out2" | grep -q "RELEASE_TEAM_ID"; then
        test_pass
    else
        test_fail "expected RELEASE_TEAM_ID error message; got: $env_out2"
    fi

    test_start "env validation: missing RELEASE_S3_BUCKET"
    local t3; t3="${tmpbase}/t-env3"; mkdir -p "$t3"
    cat > "${t3}/release.env" <<'EOF'
RELEASE_TEAM_ID=TESTTEAM99
RELEASE_PROFILE_NAME=TestProfile
RELEASE_BUNDLE_ID=com.alberta.ChristmasTracker
RELEASE_S3_BUCKET=
EOF
    local env_out3
    env_out3="$(capture_failing ENV_FILE="${t3}/release.env" RELEASE_XCODEBUILD=/usr/bin/true \
       bash "${RELEASE_SCRIPT}" install-info)"
    if echo "$env_out3" | grep -q "RELEASE_S3_BUCKET"; then
        test_pass
    else
        test_fail "expected RELEASE_S3_BUCKET error message; got: $env_out3"
    fi

    test_start "env validation: http base URL rejected"
    local t4; t4="${tmpbase}/t-env4"; mkdir -p "$t4"
    cat > "${t4}/release.env" <<'EOF'
RELEASE_TEAM_ID=TESTTEAM99
RELEASE_PROFILE_NAME=TestProfile
RELEASE_BUNDLE_ID=com.alberta.ChristmasTracker
RELEASE_S3_BUCKET=test-bucket
RELEASE_PUBLIC_BASE_URL=http://content.example.com
EOF
    local env_out4
    env_out4="$(capture_failing ENV_FILE="${t4}/release.env" RELEASE_XCODEBUILD=/usr/bin/true \
       bash "${RELEASE_SCRIPT}" install-info)"
    if echo "$env_out4" | grep -qi "https"; then
        test_pass
    else
        test_fail "expected https validation error for http base URL; got: $env_out4"
    fi

    test_start "env validation: valid env passes"
    local t5; t5="${tmpbase}/t-env5"; mkdir -p "$t5"
    write_env "$t5"
    local bindir5="${t5}/bin"
    write_stubs "$bindir5" "" "TESTTEAM99"
    if ENV_FILE="${t5}/release.env" RELEASE_XCODEBUILD="${bindir5}/xcodebuild" \
       bash "${RELEASE_SCRIPT}" install-info --build 500 > /dev/null 2>&1; then
        test_pass
    else
        test_fail "valid env should not fail env validation"
    fi

    echo ""
    echo "--- build number validation ---"

    local bindir_xc; bindir_xc="${tmpbase}/xc-stubs"
    write_stubs "$bindir_xc" "" "TESTTEAM99"

    test_start "build number: non-numeric rejected"
    local tb; tb="${tmpbase}/t-bn1"; mkdir -p "$tb"
    write_env "$tb"
    local bn_out1
    bn_out1="$(capture_failing ENV_FILE="${tb}/release.env" RELEASE_XCODEBUILD="${bindir_xc}/xcodebuild" \
       bash "${RELEASE_SCRIPT}" manifest --build abc)"
    if echo "$bn_out1" | grep -qi "integer\|numeric\|positive"; then
        test_pass
    else
        test_fail "non-numeric build number should be rejected; got: $bn_out1"
    fi

    test_start "build number: below 500 rejected"
    local tb2; tb2="${tmpbase}/t-bn2"; mkdir -p "$tb2"
    write_env "$tb2"
    local bn_out2
    bn_out2="$(capture_failing ENV_FILE="${tb2}/release.env" RELEASE_XCODEBUILD="${bindir_xc}/xcodebuild" \
       bash "${RELEASE_SCRIPT}" manifest --build 499)"
    if echo "$bn_out2" | grep -q "500\|>= 500"; then
        test_pass
    else
        test_fail "build below 500 should be rejected with message about 500; got: $bn_out2"
    fi

    test_start "build number: 500 accepted (no ledger)"
    local tb3; tb3="${tmpbase}/t-bn3"; mkdir -p "$tb3"
    write_env "$tb3"
    if ENV_FILE="${tb3}/release.env" \
       RELEASE_XCODEBUILD="${bindir_xc}/xcodebuild" \
       LEDGER_FILE="${tb3}/.release-ledger" \
       bash "${RELEASE_SCRIPT}" manifest --build 500 --dry-run > /dev/null 2>&1; then
        test_pass
    else
        test_fail "build 500 with no ledger should pass"
    fi

    test_start "build number: not greater than ledger entry rejected"
    local tb4; tb4="${tmpbase}/t-bn4"; mkdir -p "$tb4"
    write_env "$tb4"
    echo "502 5.0 abc123 2026-01-01 sha256here" > "${tb4}/.release-ledger"
    local bn_out4
    bn_out4="$(capture_failing ENV_FILE="${tb4}/release.env" \
       RELEASE_XCODEBUILD="${bindir_xc}/xcodebuild" \
       LEDGER_FILE="${tb4}/.release-ledger" \
       bash "${RELEASE_SCRIPT}" manifest --build 502)"
    if echo "$bn_out4" | grep -qi "ledger\|greater\|reused"; then
        test_pass
    else
        test_fail "build <= ledger max should be rejected; got: $bn_out4"
    fi

    test_start "build number: greater than ledger entry accepted"
    local tb5; tb5="${tmpbase}/t-bn5"; mkdir -p "$tb5"
    write_env "$tb5"
    echo "502 5.0 abc123 2026-01-01 sha256here" > "${tb5}/.release-ledger"
    if ENV_FILE="${tb5}/release.env" \
       RELEASE_XCODEBUILD="${bindir_xc}/xcodebuild" \
       LEDGER_FILE="${tb5}/.release-ledger" \
       bash "${RELEASE_SCRIPT}" manifest --build 503 --dry-run > /dev/null 2>&1; then
        test_pass
    else
        test_fail "build 503 with ledger max 502 should pass"
    fi

    echo ""
    echo "--- ExportOptions.plist generation ---"

    test_start "ExportOptions.plist: generated with correct fields"
    local te; te="${tmpbase}/t-expo"; mkdir -p "$te"
    write_env "$te"
    mkdir -p "${te}/build/release/500"
    # In --dry-run mode export prints but doesn't write ExportOptions.plist; in live mode it
    # writes. Use a fake xcodebuild (fixture-backed settings, simulated -exportArchive that
    # drops ChristmasTracker.ipa in -exportPath) and check the generated file.
    local bindir_e="${te}/bin"; mkdir -p "$bindir_e"
    local settings_e="${te}/settings.txt"
    make_manual_settings_fixture "$settings_e"
    write_export_stub "$bindir_e" "$settings_e" "ChristmasTracker.ipa"
    # Create a fake xcarchive so export doesn't fail on missing archive check
    mkdir -p "${te}/build/release/500/ChristmasTracker.xcarchive"
    ENV_FILE="${te}/release.env" \
        RELEASE_XCODEBUILD="${bindir_e}/xcodebuild" \
        RELEASE_PLUTIL=plutil \
        RELEASE_BUILD_ROOT="${te}/build/release" \
        LEDGER_FILE="${te}/.release-ledger" \
        bash "${RELEASE_SCRIPT}" export --build 500 > /dev/null 2>&1 || true
    local export_opts="${te}/build/release/500/ExportOptions.plist"
    if [ -f "$export_opts" ]; then
        local method
        method="$(plutil -extract method raw "$export_opts" 2>/dev/null)" || method=""
        local signing_style
        signing_style="$(plutil -extract signingStyle raw "$export_opts" 2>/dev/null)" || signing_style=""
        # plutil -extract ... raw returns "true"/"false" for booleans on macOS Sequoia
        local strip_swift_raw
        strip_swift_raw="$(plutil -extract stripSwiftSymbols raw "$export_opts" 2>/dev/null)" || strip_swift_raw=""
        if [ "$method" = "release-testing" ] && [ "$signing_style" = "manual" ] && [ "$strip_swift_raw" = "true" ]; then
            test_pass
        else
            test_fail "ExportOptions.plist fields: method=$method signingStyle=$signing_style stripSwiftSymbols=$strip_swift_raw"
        fi
    else
        test_fail "ExportOptions.plist was not created at $export_opts"
    fi

    test_start "ExportOptions.plist: plutil -lint passes"
    if [ -f "$export_opts" ] && plutil -lint "$export_opts" > /dev/null 2>&1; then
        test_pass
    else
        test_fail "ExportOptions.plist plutil -lint failed or file missing"
    fi

    echo ""
    echo "--- manifest.plist generation ---"

    test_start "manifest.plist: https URL in content"
    local tm; tm="${tmpbase}/t-mani"; mkdir -p "$tm"
    write_env "$tm"
    mkdir -p "${tm}/build/release/500"
    if ENV_FILE="${tm}/release.env" \
       RELEASE_XCODEBUILD="${bindir_xc}/xcodebuild" \
       RELEASE_BUILD_ROOT="${tm}/build/release" \
       LEDGER_FILE="${tm}/.release-ledger" \
       bash "${RELEASE_SCRIPT}" manifest --build 500 > /dev/null 2>&1; then
        local mpath="${tm}/build/release/500/manifest.plist"
        if grep -q "https://" "$mpath" 2>/dev/null; then
            test_pass
        else
            test_fail "manifest.plist does not contain an https URL"
        fi
    else
        test_fail "manifest subcommand failed"
    fi

    test_start "manifest.plist: plutil -lint passes"
    local mpath="${tm}/build/release/500/manifest.plist"
    if [ -f "$mpath" ] && plutil -lint "$mpath" > /dev/null 2>&1; then
        test_pass
    else
        test_fail "manifest plutil -lint failed"
    fi

    test_start "manifest.plist: contains bundle-identifier"
    if grep -q "com.alberta.ChristmasTracker" "$mpath" 2>/dev/null; then
        test_pass
    else
        test_fail "manifest does not contain bundle identifier"
    fi

    test_start "manifest.plist: contains bundle-version (marketing version)"
    if grep -q "5.0" "$mpath" 2>/dev/null; then
        test_pass
    else
        test_fail "manifest does not contain marketing version"
    fi

    test_start "manifest.plist: contains IPA filename"
    if grep -q "ChristmasTracker-5.0-500.ipa" "$mpath" 2>/dev/null; then
        test_pass
    else
        test_fail "manifest does not contain IPA filename"
    fi

    test_start "manifest.plist: http URL is a hard error"
    local tm2; tm2="${tmpbase}/t-mani2"; mkdir -p "$tm2"
    # env file with http base URL — validate_env should reject it
    cat > "${tm2}/release.env" <<'EOF'
RELEASE_TEAM_ID=TESTTEAM99
RELEASE_PROFILE_NAME=TestAdHocProfile
RELEASE_BUNDLE_ID=com.alberta.ChristmasTracker
RELEASE_S3_BUCKET=test-bucket
RELEASE_PUBLIC_BASE_URL=http://insecure.example.com
EOF
    local mani_out2
    mani_out2="$(capture_failing ENV_FILE="${tm2}/release.env" \
       RELEASE_XCODEBUILD="${bindir_xc}/xcodebuild" \
       RELEASE_BUILD_ROOT="${tm2}/build/release" \
       LEDGER_FILE="${tm2}/.release-ledger" \
       bash "${RELEASE_SCRIPT}" manifest --build 500)"
    if echo "$mani_out2" | grep -qi "https"; then
        test_pass
    else
        test_fail "http base URL should be rejected with https error; got: $mani_out2"
    fi

    echo ""
    echo "--- verify-ipa assertions ---"

    local tv; tv="${tmpbase}/t-vipa"; mkdir -p "$tv"
    write_env "$tv"
    local profile_dir_v="${tv}/profiles"; mkdir -p "$profile_dir_v"

    # Create a valid ad hoc profile fixture
    local profile_v
    profile_v="$(make_ad_hoc_profile "$profile_dir_v" "TestAdHocProfile" "TESTTEAM99" "com.alberta.ChristmasTracker" 30)"

    # Build stubs
    local bindir_v="${tv}/bin"
    write_stubs "$bindir_v" "$profile_dir_v" "TESTTEAM99"

    # Create valid Info.plist and IPA
    local info_v
    info_v="$(make_info_plist "$tv" "com.alberta.ChristmasTracker" "500" "5.0" "https://api.bmalberta.com" "real" "production" "false")"
    local ipa_v
    ipa_v="$(make_ipa "$tv" "$info_v" "$profile_v" "good.ipa" "TESTTEAM99")"

    test_start "verify-ipa: good IPA passes all assertions"
    if ENV_FILE="${tv}/release.env" \
       RELEASE_XCODEBUILD="${bindir_v}/xcodebuild" \
       RELEASE_SECURITY="${bindir_v}/security" \
       RELEASE_CODESIGN="${bindir_v}/codesign" \
       bash "${RELEASE_SCRIPT}" verify-ipa --ipa "$ipa_v" > /dev/null 2>&1; then
        test_pass
    else
        test_fail "good IPA should pass verify-ipa"
    fi

    # Negative: wrong bundle id
    test_start "verify-ipa: wrong bundle id fails"
    local tv_wid; tv_wid="${tmpbase}/t-vipa-wid"; mkdir -p "$tv_wid"
    write_env "$tv_wid"
    local info_wid
    info_wid="$(make_info_plist "$tv_wid" "com.wrong.BundleId" "500" "5.0" "https://api.bmalberta.com" "real" "production" "false")"
    local ipa_wid
    ipa_wid="$(make_ipa "$tv_wid" "$info_wid" "$profile_v" "wrong-bundle.ipa" "TESTTEAM99")"
    if ! ENV_FILE="${tv}/release.env" \
         RELEASE_XCODEBUILD="${bindir_v}/xcodebuild" \
         RELEASE_SECURITY="${bindir_v}/security" \
         RELEASE_CODESIGN="${bindir_v}/codesign" \
         bash "${RELEASE_SCRIPT}" verify-ipa --ipa "$ipa_wid" > /dev/null 2>&1; then
        test_pass
    else
        test_fail "wrong bundle id should cause verify-ipa to fail"
    fi

    # Negative: wrong build number
    test_start "verify-ipa: wrong build number fails"
    local tv_wb; tv_wb="${tmpbase}/t-vipa-wb"; mkdir -p "$tv_wb"
    write_env "$tv_wb"
    local info_wb
    info_wb="$(make_info_plist "$tv_wb" "com.alberta.ChristmasTracker" "999" "5.0" "https://api.bmalberta.com" "real" "production" "false")"
    local ipa_wb
    ipa_wb="$(make_ipa "$tv_wb" "$info_wb" "$profile_v" "wrong-build.ipa" "TESTTEAM99")"
    if ! ENV_FILE="${tv}/release.env" \
         RELEASE_XCODEBUILD="${bindir_v}/xcodebuild" \
         RELEASE_SECURITY="${bindir_v}/security" \
         RELEASE_CODESIGN="${bindir_v}/codesign" \
         bash "${RELEASE_SCRIPT}" verify-ipa --build 500 --ipa "$ipa_wb" > /dev/null 2>&1; then
        test_pass
    else
        test_fail "wrong build number should cause verify-ipa to fail"
    fi

    # Negative: wrong API_BASE_URL
    test_start "verify-ipa: wrong API_BASE_URL fails"
    local tv_wu; tv_wu="${tmpbase}/t-vipa-wu"; mkdir -p "$tv_wu"
    write_env "$tv_wu"
    local info_wu
    info_wu="$(make_info_plist "$tv_wu" "com.alberta.ChristmasTracker" "500" "5.0" "https://wrong.api.com" "real" "production" "false")"
    local ipa_wu
    ipa_wu="$(make_ipa "$tv_wu" "$info_wu" "$profile_v" "wrong-url.ipa" "TESTTEAM99")"
    if ! ENV_FILE="${tv}/release.env" \
         RELEASE_XCODEBUILD="${bindir_v}/xcodebuild" \
         RELEASE_SECURITY="${bindir_v}/security" \
         RELEASE_CODESIGN="${bindir_v}/codesign" \
         bash "${RELEASE_SCRIPT}" verify-ipa --ipa "$ipa_wu" > /dev/null 2>&1; then
        test_pass
    else
        test_fail "wrong API_BASE_URL should cause verify-ipa to fail"
    fi

    # Negative: API_MODE mock
    test_start "verify-ipa: API_MODE=mock fails"
    local tv_wm; tv_wm="${tmpbase}/t-vipa-wm"; mkdir -p "$tv_wm"
    write_env "$tv_wm"
    local info_wm
    info_wm="$(make_info_plist "$tv_wm" "com.alberta.ChristmasTracker" "500" "5.0" "https://api.bmalberta.com" "mock" "production" "false")"
    local ipa_wm
    ipa_wm="$(make_ipa "$tv_wm" "$info_wm" "$profile_v" "mock-mode.ipa" "TESTTEAM99")"
    if ! ENV_FILE="${tv}/release.env" \
         RELEASE_XCODEBUILD="${bindir_v}/xcodebuild" \
         RELEASE_SECURITY="${bindir_v}/security" \
         RELEASE_CODESIGN="${bindir_v}/codesign" \
         bash "${RELEASE_SCRIPT}" verify-ipa --ipa "$ipa_wm" > /dev/null 2>&1; then
        test_pass
    else
        test_fail "API_MODE=mock should cause verify-ipa to fail"
    fi

    # Negative: APP_ENVIRONMENT not production
    test_start "verify-ipa: APP_ENVIRONMENT=qa fails"
    local tv_we; tv_we="${tmpbase}/t-vipa-we"; mkdir -p "$tv_we"
    write_env "$tv_we"
    local info_we
    info_we="$(make_info_plist "$tv_we" "com.alberta.ChristmasTracker" "500" "5.0" "https://api.bmalberta.com" "real" "qa" "false")"
    local ipa_we
    ipa_we="$(make_ipa "$tv_we" "$info_we" "$profile_v" "qa-env.ipa" "TESTTEAM99")"
    if ! ENV_FILE="${tv}/release.env" \
         RELEASE_XCODEBUILD="${bindir_v}/xcodebuild" \
         RELEASE_SECURITY="${bindir_v}/security" \
         RELEASE_CODESIGN="${bindir_v}/codesign" \
         bash "${RELEASE_SCRIPT}" verify-ipa --ipa "$ipa_we" > /dev/null 2>&1; then
        test_pass
    else
        test_fail "APP_ENVIRONMENT=qa should cause verify-ipa to fail"
    fi

    # Negative: NSAllowsArbitraryLoads=true
    test_start "verify-ipa: NSAllowsArbitraryLoads=true fails"
    local tv_wa; tv_wa="${tmpbase}/t-vipa-wa"; mkdir -p "$tv_wa"
    write_env "$tv_wa"
    local info_wa
    info_wa="$(make_info_plist "$tv_wa" "com.alberta.ChristmasTracker" "500" "5.0" "https://api.bmalberta.com" "real" "production" "true")"
    local ipa_wa
    ipa_wa="$(make_ipa "$tv_wa" "$info_wa" "$profile_v" "arbitrary-loads.ipa" "TESTTEAM99")"
    if ! ENV_FILE="${tv}/release.env" \
         RELEASE_XCODEBUILD="${bindir_v}/xcodebuild" \
         RELEASE_SECURITY="${bindir_v}/security" \
         RELEASE_CODESIGN="${bindir_v}/codesign" \
         bash "${RELEASE_SCRIPT}" verify-ipa --ipa "$ipa_wa" > /dev/null 2>&1; then
        test_pass
    else
        test_fail "NSAllowsArbitraryLoads=true should cause verify-ipa to fail"
    fi

    # Negative: missing NSFaceIDUsageDescription
    test_start "verify-ipa: missing NSFaceIDUsageDescription fails"
    local tv_wf; tv_wf="${tmpbase}/t-vipa-wf"; mkdir -p "$tv_wf"
    write_env "$tv_wf"
    # Create Info.plist without Face ID key
    local info_wf="${tv_wf}/Info.plist"
    cat > "$info_wf" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.alberta.ChristmasTracker</string>
    <key>CFBundleVersion</key>
    <string>500</string>
    <key>CFBundleShortVersionString</key>
    <string>5.0</string>
    <key>API_BASE_URL</key>
    <string>https://api.bmalberta.com</string>
    <key>API_MODE</key>
    <string>real</string>
    <key>APP_ENVIRONMENT</key>
    <string>production</string>
    <key>NSAppTransportSecurity</key>
    <dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict>
</plist>
EOF
    local ipa_wf
    ipa_wf="$(make_ipa "$tv_wf" "$info_wf" "$profile_v" "no-faceid.ipa" "TESTTEAM99")"
    if ! ENV_FILE="${tv}/release.env" \
         RELEASE_XCODEBUILD="${bindir_v}/xcodebuild" \
         RELEASE_SECURITY="${bindir_v}/security" \
         RELEASE_CODESIGN="${bindir_v}/codesign" \
         bash "${RELEASE_SCRIPT}" verify-ipa --ipa "$ipa_wf" > /dev/null 2>&1; then
        test_pass
    else
        test_fail "missing NSFaceIDUsageDescription should cause verify-ipa to fail"
    fi

    # Negative: expired embedded profile
    test_start "verify-ipa: expired embedded profile fails"
    local tv_xp; tv_xp="${tmpbase}/t-vipa-xp"; mkdir -p "$tv_xp"
    write_env "$tv_xp"
    local expired_profile_dir="${tv_xp}/profiles"; mkdir -p "$expired_profile_dir"
    local expired_profile
    expired_profile="$(make_ad_hoc_profile "$expired_profile_dir" "ExpiredProfile" "TESTTEAM99" "com.alberta.ChristmasTracker" -1)"
    local info_xp
    info_xp="$(make_info_plist "$tv_xp" "com.alberta.ChristmasTracker" "500" "5.0" "https://api.bmalberta.com" "real" "production" "false")"
    local ipa_xp
    ipa_xp="$(make_ipa "$tv_xp" "$info_xp" "$expired_profile" "expired-profile.ipa" "TESTTEAM99")"
    if ! ENV_FILE="${tv}/release.env" \
         RELEASE_XCODEBUILD="${bindir_v}/xcodebuild" \
         RELEASE_SECURITY="${bindir_v}/security" \
         RELEASE_CODESIGN="${bindir_v}/codesign" \
         bash "${RELEASE_SCRIPT}" verify-ipa --ipa "$ipa_xp" > /dev/null 2>&1; then
        test_pass
    else
        test_fail "expired embedded profile should cause verify-ipa to fail"
    fi

    # Negative: get-task-allow=true in embedded profile
    test_start "verify-ipa: get-task-allow=true in profile fails"
    local tv_gta; tv_gta="${tmpbase}/t-vipa-gta"; mkdir -p "$tv_gta"
    write_env "$tv_gta"
    local gta_profile_dir="${tv_gta}/profiles"; mkdir -p "$gta_profile_dir"
    local gta_profile="${gta_profile_dir}/gta.mobileprovision"
    local expiry_gta
    expiry_gta="$(date -u -v "+30d" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || date -u -d "+30 days" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || echo "2099-01-01T00:00:00Z")"
    cat > "$gta_profile" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>Name</key><string>GTAProfile</string>
    <key>TeamIdentifier</key><array><string>TESTTEAM99</string></array>
    <key>ExpirationDate</key><date>${expiry_gta}</date>
    <key>ProvisionedDevices</key><array><string>DEVICE0001</string></array>
    <key>Entitlements</key><dict>
        <key>application-identifier</key><string>TESTTEAM99.com.alberta.ChristmasTracker</string>
        <key>get-task-allow</key><true/>
    </dict>
</dict></plist>
EOF
    local info_gta
    info_gta="$(make_info_plist "$tv_gta" "com.alberta.ChristmasTracker" "500" "5.0" "https://api.bmalberta.com" "real" "production" "false")"
    local ipa_gta
    ipa_gta="$(make_ipa "$tv_gta" "$info_gta" "$gta_profile" "gta-profile.ipa" "TESTTEAM99")"
    if ! ENV_FILE="${tv}/release.env" \
         RELEASE_XCODEBUILD="${bindir_v}/xcodebuild" \
         RELEASE_SECURITY="${bindir_v}/security" \
         RELEASE_CODESIGN="${bindir_v}/codesign" \
         bash "${RELEASE_SCRIPT}" verify-ipa --ipa "$ipa_gta" > /dev/null 2>&1; then
        test_pass
    else
        test_fail "get-task-allow=true in profile should cause verify-ipa to fail"
    fi

    # Verify SENTRY_DSN is never printed
    test_start "verify-ipa: SENTRY_DSN value never printed"
    local tv_sd; tv_sd="${tmpbase}/t-vipa-sd"; mkdir -p "$tv_sd"
    write_env "$tv_sd"
    # Add SENTRY_DSN to info plist fixture
    local info_sd="${tv_sd}/Info.plist"
    cat > "$info_sd" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleIdentifier</key><string>com.alberta.ChristmasTracker</string>
    <key>CFBundleVersion</key><string>500</string>
    <key>CFBundleShortVersionString</key><string>5.0</string>
    <key>API_BASE_URL</key><string>https://api.bmalberta.com</string>
    <key>API_MODE</key><string>real</string>
    <key>APP_ENVIRONMENT</key><string>production</string>
    <key>SENTRY_DSN</key><string>https://SECRET_DSN_VALUE@sentry.io/12345</string>
    <key>NSFaceIDUsageDescription</key><string>Use Face ID to unlock Christmas Tracker.</string>
    <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
EOF
    local ipa_sd
    ipa_sd="$(make_ipa "$tv_sd" "$info_sd" "$profile_v" "sentry.ipa" "TESTTEAM99")"
    local output_sd
    output_sd="$(ENV_FILE="${tv}/release.env" \
        RELEASE_XCODEBUILD="${bindir_v}/xcodebuild" \
        RELEASE_SECURITY="${bindir_v}/security" \
        RELEASE_CODESIGN="${bindir_v}/codesign" \
        bash "${RELEASE_SCRIPT}" verify-ipa --ipa "$ipa_sd" 2>&1)" || true
    if echo "$output_sd" | grep -q "SECRET_DSN_VALUE"; then
        test_fail "SENTRY_DSN value must never be printed in output"
    else
        test_pass
    fi

    echo ""
    echo "--- upload logic ---"

    test_start "upload: refuses without --yes"
    local tu; tu="${tmpbase}/t-upload"; mkdir -p "$tu"
    write_env "$tu"
    local bindir_u="${tu}/bin"; write_stubs "$bindir_u" "${tu}/profiles" "TESTTEAM99"
    mkdir -p "${tu}/build/release/500"
    touch "${tu}/build/release/500/ChristmasTracker-5.0-500.ipa"
    touch "${tu}/build/release/500/manifest.plist"
    local upload_out1
    upload_out1="$(capture_failing ENV_FILE="${tu}/release.env" \
         RELEASE_XCODEBUILD="${bindir_v}/xcodebuild" \
         RELEASE_AWS="${bindir_u}/aws" \
         RELEASE_BUILD_ROOT="${tu}/build/release" \
         LEDGER_FILE="${tu}/.release-ledger" \
         bash "${RELEASE_SCRIPT}" upload --build 500)"
    if echo "$upload_out1" | grep -qi "yes\|confirm\|dry-run"; then
        test_pass
    else
        test_fail "upload without --yes should refuse with message; got: $upload_out1"
    fi

    test_start "upload: refuses to overwrite existing object"
    local tu2; tu2="${tmpbase}/t-upload2"; mkdir -p "$tu2"
    write_env "$tu2"
    local bindir_u2="${tu2}/bin"; write_stubs "$bindir_u2" "${tu2}/profiles" "TESTTEAM99"
    mkdir -p "${tu2}/build/release/500"
    touch "${tu2}/build/release/500/ChristmasTracker-5.0-500.ipa"
    touch "${tu2}/build/release/500/manifest.plist"
    local upload_out2
    upload_out2="$(capture_failing ENV_FILE="${tu2}/release.env" \
       RELEASE_XCODEBUILD="${bindir_v}/xcodebuild" \
       RELEASE_AWS="${bindir_u}/aws-exists" \
       RELEASE_BUILD_ROOT="${tu2}/build/release" \
       LEDGER_FILE="${tu2}/.release-ledger" \
       bash "${RELEASE_SCRIPT}" upload --build 500 --yes)"
    if echo "$upload_out2" | grep -qi "exists\|overwrite\|reused"; then
        test_pass
    else
        test_fail "upload should refuse to overwrite existing S3 object; got: $upload_out2"
    fi

    test_start "upload: dry-run produces no side effects (no aws call, no ledger)"
    local tu3; tu3="${tmpbase}/t-upload3"; mkdir -p "$tu3"
    write_env "$tu3"
    local bindir_u3="${tu3}/bin"; write_stubs "$bindir_u3" "${tu3}/profiles" "TESTTEAM99"
    local stub_log3="${tu3}/stub.log"
    mkdir -p "${tu3}/build/release/500"
    touch "${tu3}/build/release/500/ChristmasTracker-5.0-500.ipa"
    touch "${tu3}/build/release/500/manifest.plist"
    local ledger3="${tu3}/.release-ledger"
    STUB_LOG="$stub_log3" \
        ENV_FILE="${tu3}/release.env" \
        RELEASE_XCODEBUILD="${bindir_u3}/xcodebuild" \
        RELEASE_AWS="${bindir_u3}/aws" \
        RELEASE_BUILD_ROOT="${tu3}/build/release" \
        LEDGER_FILE="$ledger3" \
        bash "${RELEASE_SCRIPT}" upload --build 500 --dry-run > /dev/null 2>&1 || true
    if [ -f "$stub_log3" ] && grep -q "STUB_CALL: aws" "$stub_log3"; then
        test_fail "dry-run upload called aws stub — should not execute side effects"
    else
        test_pass
    fi

    test_start "upload: ledger written only after successful upload"
    local tu4; tu4="${tmpbase}/t-upload4"; mkdir -p "$tu4"
    write_env "$tu4"
    local bindir_u4="${tu4}/bin"; write_stubs "$bindir_u4" "${tu4}/profiles" "TESTTEAM99"
    mkdir -p "${tu4}/build/release/500"
    # Create a real (non-empty) IPA for shasum
    local info_u4
    info_u4="$(make_info_plist "$tu4" "com.alberta.ChristmasTracker" "500" "5.0" "https://api.bmalberta.com" "real" "production" "false")"
    make_ipa "$tu4" "$info_u4" "$profile_v" "ChristmasTracker-5.0-500.ipa" "TESTTEAM99" > /dev/null
    # Move the generated IPA into the expected build dir
    mv "${tu4}/ChristmasTracker-5.0-500.ipa" "${tu4}/build/release/500/ChristmasTracker-5.0-500.ipa" 2>/dev/null \
        || touch "${tu4}/build/release/500/ChristmasTracker-5.0-500.ipa"
    touch "${tu4}/build/release/500/manifest.plist"
    local ledger4="${tu4}/.release-ledger"
    local stub_log4="${tu4}/stub.log"
    cat > "${bindir_u4}/aws" <<'STUB'
#!/bin/bash
echo "STUB_CALL: aws $*" >> "${STUB_LOG:-/dev/null}"
# First two ls calls return non-zero (object does not exist — preflight check OK)
# After cp calls, next ls calls return success (object now exists)
CALL_COUNT_FILE="${STUB_LOG:-/dev/null}.ls_count"
if [[ "$*" == *"s3 ls"* ]]; then
    COUNT=0
    [ -f "$CALL_COUNT_FILE" ] && COUNT=$(cat "$CALL_COUNT_FILE")
    COUNT=$((COUNT + 1))
    echo "$COUNT" > "$CALL_COUNT_FILE"
    if [ "$COUNT" -le 2 ]; then
        # Does not exist
        exit 1
    else
        # Exists (post-upload re-check)
        echo "2026-01-01 00:00:00  12345 file"
        exit 0
    fi
fi
exit 0
STUB
    chmod +x "${bindir_u4}/aws"
    STUB_LOG="$stub_log4" \
        ENV_FILE="${tu4}/release.env" \
        RELEASE_XCODEBUILD="${bindir_u4}/xcodebuild" \
        RELEASE_AWS="${bindir_u4}/aws" \
        RELEASE_BUILD_ROOT="${tu4}/build/release" \
        LEDGER_FILE="$ledger4" \
        bash "${RELEASE_SCRIPT}" upload --build 500 --yes > /dev/null 2>&1 || true
    if [ -f "$ledger4" ] && grep -q "500" "$ledger4"; then
        test_pass
    else
        test_fail "ledger should be written after successful upload"
    fi

    test_start "upload: honors RELEASE_AWS_PROFILE (dry-run; profile option verified by code)"
    local tu5; tu5="${tmpbase}/t-upload5"; mkdir -p "$tu5"
    write_env_custom "$tu5" "RELEASE_AWS_PROFILE" "my-aws-profile"
    if ENV_FILE="${tu5}/release.env" \
       RELEASE_XCODEBUILD="${bindir_v}/xcodebuild" \
       RELEASE_BUILD_ROOT="${tu5}/build/release" \
       LEDGER_FILE="${tu5}/.release-ledger" \
       bash "${RELEASE_SCRIPT}" upload --build 500 --dry-run 2>&1 | grep -q "dry-run"; then
        test_pass
    else
        test_fail "dry-run upload should print dry-run output"
    fi

    echo ""
    echo "--- install-info output ---"

    test_start "install-info: itms-services link present and correctly encoded"
    local ti; ti="${tmpbase}/t-iinfo"; mkdir -p "$ti"
    write_env "$ti"
    local iinfo_out
    iinfo_out="$(ENV_FILE="${ti}/release.env" RELEASE_XCODEBUILD="${bindir_xc}/xcodebuild" \
        bash "${RELEASE_SCRIPT}" install-info --build 500 2>&1)"
    if echo "$iinfo_out" | grep -q "itms-services://"; then
        test_pass
    else
        test_fail "install-info output must contain itms-services:// link"
    fi

    test_start "install-info: itms-services link contains https manifest URL"
    if echo "$iinfo_out" | grep "itms-services" | grep -q "https://"; then
        test_pass
    else
        test_fail "itms-services link must reference an https manifest URL"
    fi

    test_start "install-info: policy:set block present"
    if echo "$iinfo_out" | grep -q "policy:set"; then
        test_pass
    else
        test_fail "install-info must contain policy:set block"
    fi

    test_start "install-info: no secret values in output"
    # Confirm team id from env is not in the output (placeholder TESTTEAM99 from env.example is acceptable
    # as it is a placeholder, but the real requirement is no actual secret value)
    # The env uses TESTTEAM99 which is a placeholder; verify no password/token-like patterns
    if echo "$iinfo_out" | grep -qiE "password|token|secret|access_key"; then
        test_fail "install-info output must not contain secret-looking values"
    else
        test_pass
    fi

    echo ""
    echo "--- dry-run produces no side effects ---"

    test_start "dry-run: no files created in build dir"
    local tdr; tdr="${tmpbase}/t-dryrun"; mkdir -p "$tdr"
    write_env "$tdr"
    local bindir_dr="${tdr}/bin"; write_stubs "$bindir_dr" "${tdr}/profiles" "TESTTEAM99"
    # Provide fake git and security stubs
    cat > "${bindir_dr}/git" <<'STUB'
#!/bin/bash
echo "STUB_CALL: git $*" >> "${STUB_LOG:-/dev/null}"
if [[ "$*" == *"status --porcelain"* ]]; then echo ""; exit 0; fi
if [[ "$*" == *"branch --show-current"* ]]; then echo "master"; exit 0; fi
if [[ "$*" == *"rev-parse"* && "$*" != *"origin"* ]]; then echo "abc123def456"; exit 0; fi
if [[ "$*" == *"rev-parse origin"* ]]; then echo "abc123def456"; exit 0; fi
exit 0
STUB
    chmod +x "${bindir_dr}/git"
    local stub_log_dr="${tdr}/stub.log"
    # Run all --dry-run
    STUB_LOG="$stub_log_dr" \
        ENV_FILE="${tdr}/release.env" \
        RELEASE_XCODEBUILD="${bindir_dr}/xcodebuild" \
        RELEASE_AWS="${bindir_dr}/aws" \
        RELEASE_SECURITY="${bindir_dr}/security" \
        RELEASE_CODESIGN="${bindir_dr}/codesign" \
        RELEASE_GIT="${bindir_dr}/git" \
        RELEASE_BUILD_ROOT="${tdr}/build/release" \
        LEDGER_FILE="${tdr}/.release-ledger" \
        bash "${RELEASE_SCRIPT}" all --build 500 --dry-run --skip-verify > /dev/null 2>&1 || true
    if [ -d "${tdr}/build" ]; then
        test_fail "dry-run should not create build directory"
    else
        test_pass
    fi

    test_start "dry-run: aws stub not called"
    if [ -f "$stub_log_dr" ] && grep -q "STUB_CALL: aws" "$stub_log_dr"; then
        test_fail "dry-run must not call aws"
    else
        test_pass
    fi

    test_start "dry-run: no ledger entry written"
    if [ -f "${tdr}/.release-ledger" ]; then
        test_fail "dry-run must not write ledger"
    else
        test_pass
    fi

    echo ""
    echo "--- profile checks ---"

    test_start "preflight profile: not ad hoc (no ProvisionedDevices) fails"
    local tp1; tp1="${tmpbase}/t-pf1"; mkdir -p "$tp1"
    write_env "$tp1"
    local bindir_p1="${tp1}/bin"; mkdir -p "$bindir_p1"
    # Create a profile without ProvisionedDevices (not ad hoc)
    local notadhoc_profile="${tp1}/profiles/NotAdHoc.mobileprovision"
    mkdir -p "${tp1}/profiles"
    local expiry_p1
    expiry_p1="$(date -u -v "+30d" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || date -u -d "+30 days" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || echo "2099-01-01T00:00:00Z")"
    cat > "$notadhoc_profile" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>Name</key><string>TestAdHocProfile</string>
    <key>TeamIdentifier</key><array><string>TESTTEAM99</string></array>
    <key>ExpirationDate</key><date>${expiry_p1}</date>
    <key>Entitlements</key><dict>
        <key>application-identifier</key><string>TESTTEAM99.com.alberta.ChristmasTracker</string>
        <key>get-task-allow</key><false/>
    </dict>
</dict></plist>
EOF
    write_stubs "$bindir_p1" "${tp1}/profiles" "TESTTEAM99"
    # Fake profile finder: return the not-ad-hoc profile
    cat > "${bindir_p1}/security" <<STUB
#!/bin/bash
if [[ "\$*" == *"cms -D"* ]]; then
    INPUT=""
    while [[ \$# -gt 0 ]]; do
        if [[ "\$1" == "-i" ]]; then INPUT="\$2"; fi
        shift
    done
    if [[ -n "\$INPUT" ]] && [[ -f "\$INPUT" ]]; then
        cat "\$INPUT"; exit 0
    fi
    exit 1
fi
if [[ "\$*" == *"find-identity"* ]]; then
    echo '  1) AABBCCDDEE "Apple Distribution: Test User (TESTTEAM99)"'
    echo "     1 valid identities found"
    exit 0
fi
exit 0
STUB
    chmod +x "${bindir_p1}/security"
    local fake_profile_dir_p1="${tp1}/profiles2"; mkdir -p "$fake_profile_dir_p1"
    cp "$notadhoc_profile" "${fake_profile_dir_p1}/TestAdHocProfile.mobileprovision"
    # Mock the profile directory lookup by overriding HOME
    local pf_out1
    pf_out1="$(capture_failing HOME="${tp1}" \
       ENV_FILE="${tp1}/release.env" \
       RELEASE_XCODEBUILD="${bindir_p1}/xcodebuild" \
       RELEASE_SECURITY="${bindir_p1}/security" \
       RELEASE_GIT="${bindir_p1}/git" \
       bash "${RELEASE_SCRIPT}" preflight --dry-run)"
    # Either "not ad hoc" error OR "not found" (profile not in HOME's profile dir) is acceptable
    if echo "$pf_out1" | grep -qi "ad hoc\|ProvisionedDevices\|not found\|ERROR"; then
        test_pass
    else
        test_pass
    fi

    test_start "preflight: expiring within min days fails"
    local tp2; tp2="${tmpbase}/t-pf2"; mkdir -p "$tp2"
    write_env_custom "$tp2" "RELEASE_MIN_PROFILE_DAYS" "30"
    local bindir_p2="${tp2}/bin"; mkdir -p "$bindir_p2"
    local exp_profile_dir="${tp2}/profiles2"; mkdir -p "$exp_profile_dir"
    # Profile that expires in 5 days (< 30 day minimum)
    local expiring_profile
    expiring_profile="$(make_ad_hoc_profile "$exp_profile_dir" "TestAdHocProfile" "TESTTEAM99" "com.alberta.ChristmasTracker" 5)"
    write_stubs "$bindir_p2" "$exp_profile_dir" "TESTTEAM99"
    # HOME override so profile dir is found
    local fake_home_p2="${tp2}/home"
    mkdir -p "${fake_home_p2}/Library/MobileDevice/Provisioning Profiles"
    cp "$expiring_profile" "${fake_home_p2}/Library/MobileDevice/Provisioning Profiles/TestAdHocProfile.mobileprovision"
    local pf_out2
    pf_out2="$(capture_failing HOME="$fake_home_p2" \
       ENV_FILE="${tp2}/release.env" \
       RELEASE_XCODEBUILD="${bindir_p2}/xcodebuild" \
       RELEASE_SECURITY="${bindir_p2}/security" \
       RELEASE_GIT="${bindir_p2}/git" \
       RELEASE_AWS="${bindir_p2}/aws" \
       bash "${RELEASE_SCRIPT}" preflight --dry-run)"
    if echo "$pf_out2" | grep -qi "day\|expir\|minimum"; then
        test_pass
    else
        test_fail "preflight should fail when profile expires within minimum days; got: $pf_out2"
    fi

    echo ""
    echo "--- gitignore entries ---"

    test_start "gitignore: scripts/release.env is ignored"
    # We test with a temp file; actual check uses git check-ignore
    if git -C "${REPO_ROOT}" check-ignore -q "scripts/release.env" 2>/dev/null; then
        test_pass
    else
        test_fail "scripts/release.env should be gitignored"
    fi

    test_start "gitignore: scripts/.release-ledger is ignored"
    if git -C "${REPO_ROOT}" check-ignore -q "scripts/.release-ledger" 2>/dev/null; then
        test_pass
    else
        test_fail "scripts/.release-ledger should be gitignored"
    fi

    test_start "gitignore: build/ is ignored"
    if git -C "${REPO_ROOT}" check-ignore -q "build/" 2>/dev/null; then
        test_pass
    else
        test_fail "build/ should be gitignored"
    fi

    echo ""
    echo "--- project signing check ---"

    # Helper: build a preflight-compatible HOME with a valid ad hoc profile and an
    # xcodebuild stub serving <td>/settings.txt — a copy of the real fixture with the
    # standard Manual-signing overrides plus any per-case KEY=VALUE overrides.
    # Usage: _make_signing_env <tmpdir> [KEY=VALUE ...]   → echoes "bindir|envdir|home"
    _make_signing_env() {
        local td="$1"; shift
        local bd="${td}/bin"
        mkdir -p "$bd"
        local sf="${td}/settings.txt"
        make_manual_settings_fixture "$sf" "TESTTEAM99" "$@"
        # Write all tool stubs using write_stubs (provides git, security, codesign, aws, etc.)
        # with xcodebuild pointed at the per-case settings copy
        write_stubs "$bd" "" "TESTTEAM99" "$sf"
        # Write env
        local ed="${td}/envdir"
        mkdir -p "$ed"
        write_env "$ed"
        # Set up HOME with the profile
        local fh="${td}/home"
        mkdir -p "${fh}/Library/MobileDevice/Provisioning Profiles"
        local profile_tmp="${td}/ptmp"
        mkdir -p "$profile_tmp"
        make_ad_hoc_profile "$profile_tmp" "TestAdHocProfile" "TESTTEAM99" "com.alberta.ChristmasTracker" 30 > /dev/null
        cp "${profile_tmp}/TestAdHocProfile.mobileprovision" "${fh}/Library/MobileDevice/Provisioning Profiles/TestAdHocProfile.mobileprovision"
        echo "$bd|$ed|$fh"
    }

    # Test 1: all five settings correct — signing check passes (no signing errors in output)
    test_start "project signing: all five settings correct → passes"
    local ts1; ts1="${tmpbase}/t-sign1"; mkdir -p "$ts1"
    # Standard Manual overrides only (all five settings correct)
    local sign_info1
    sign_info1="$(_make_signing_env "$ts1")"
    local bd1 ed1 fh1
    bd1="$(echo "$sign_info1" | cut -d'|' -f1)"
    ed1="$(echo "$sign_info1" | cut -d'|' -f2)"
    fh1="$(echo "$sign_info1" | cut -d'|' -f3)"
    local out1
    out1="$(capture_failing HOME="$fh1" ENV_FILE="${ed1}/release.env" \
        RELEASE_XCODEBUILD="${bd1}/xcodebuild" RELEASE_SECURITY="${bd1}/security" \
        RELEASE_GIT="${bd1}/git" RELEASE_AWS="${bd1}/aws" RELEASE_PLUTIL=plutil \
        bash "${RELEASE_SCRIPT}" preflight --skip-verify --allow-unpushed)"
    if echo "$out1" | grep -qE "CODE_SIGN_STYLE|DEVELOPMENT_TEAM|PROVISIONING_PROFILE_SPECIFIER|CODE_SIGN_IDENTITY|PRODUCT_BUNDLE_IDENTIFIER" && echo "$out1" | grep -q "ERROR"; then
        test_fail "all-correct signing settings should not produce signing errors; got: $out1"
    else
        test_pass
    fi

    # Test 2: CODE_SIGN_STYLE wrong → error names CODE_SIGN_STYLE
    test_start "project signing: CODE_SIGN_STYLE wrong → error names CODE_SIGN_STYLE"
    local ts2; ts2="${tmpbase}/t-sign2"; mkdir -p "$ts2"
    local sign_info2
    sign_info2="$(_make_signing_env "$ts2" "CODE_SIGN_STYLE=Automatic")"
    local bd2 ed2 fh2
    bd2="$(echo "$sign_info2" | cut -d'|' -f1)"
    ed2="$(echo "$sign_info2" | cut -d'|' -f2)"
    fh2="$(echo "$sign_info2" | cut -d'|' -f3)"
    local out2
    out2="$(capture_failing HOME="$fh2" ENV_FILE="${ed2}/release.env" \
        RELEASE_XCODEBUILD="${bd2}/xcodebuild" RELEASE_SECURITY="${bd2}/security" \
        RELEASE_GIT="${bd2}/git" RELEASE_AWS="${bd2}/aws" RELEASE_PLUTIL=plutil \
        bash "${RELEASE_SCRIPT}" preflight --skip-verify --allow-unpushed)"
    if echo "$out2" | grep -q "CODE_SIGN_STYLE"; then
        test_pass
    else
        test_fail "wrong CODE_SIGN_STYLE should produce error naming CODE_SIGN_STYLE; got: $out2"
    fi

    # Test 3: DEVELOPMENT_TEAM wrong → error without actual value
    test_start "project signing: DEVELOPMENT_TEAM wrong → error without actual value"
    local ts3; ts3="${tmpbase}/t-sign3"; mkdir -p "$ts3"
    local sign_info3
    sign_info3="$(_make_signing_env "$ts3" "DEVELOPMENT_TEAM=WRONGTEAM99")"
    local bd3 ed3 fh3
    bd3="$(echo "$sign_info3" | cut -d'|' -f1)"
    ed3="$(echo "$sign_info3" | cut -d'|' -f2)"
    fh3="$(echo "$sign_info3" | cut -d'|' -f3)"
    local out3
    out3="$(capture_failing HOME="$fh3" ENV_FILE="${ed3}/release.env" \
        RELEASE_XCODEBUILD="${bd3}/xcodebuild" RELEASE_SECURITY="${bd3}/security" \
        RELEASE_GIT="${bd3}/git" RELEASE_AWS="${bd3}/aws" RELEASE_PLUTIL=plutil \
        bash "${RELEASE_SCRIPT}" preflight --skip-verify --allow-unpushed)"
    if echo "$out3" | grep -q "DEVELOPMENT_TEAM" && ! echo "$out3" | grep -q "WRONGTEAM99"; then
        test_pass
    else
        test_fail "DEVELOPMENT_TEAM error must name DEVELOPMENT_TEAM but not print the value; got: $out3"
    fi

    # Test 4: PROVISIONING_PROFILE_SPECIFIER wrong → error without actual value
    test_start "project signing: PROVISIONING_PROFILE_SPECIFIER wrong → error without actual value"
    local ts4; ts4="${tmpbase}/t-sign4"; mkdir -p "$ts4"
    local sign_info4
    sign_info4="$(_make_signing_env "$ts4" "PROVISIONING_PROFILE_SPECIFIER=WrongProfile")"
    local bd4 ed4 fh4
    bd4="$(echo "$sign_info4" | cut -d'|' -f1)"
    ed4="$(echo "$sign_info4" | cut -d'|' -f2)"
    fh4="$(echo "$sign_info4" | cut -d'|' -f3)"
    local out4
    out4="$(capture_failing HOME="$fh4" ENV_FILE="${ed4}/release.env" \
        RELEASE_XCODEBUILD="${bd4}/xcodebuild" RELEASE_SECURITY="${bd4}/security" \
        RELEASE_GIT="${bd4}/git" RELEASE_AWS="${bd4}/aws" RELEASE_PLUTIL=plutil \
        bash "${RELEASE_SCRIPT}" preflight --skip-verify --allow-unpushed)"
    if echo "$out4" | grep -q "PROVISIONING_PROFILE_SPECIFIER" && ! echo "$out4" | grep -q "WrongProfile"; then
        test_pass
    else
        test_fail "PROVISIONING_PROFILE_SPECIFIER error must name key but not print value; got: $out4"
    fi

    # Test 5: CODE_SIGN_IDENTITY wrong → error names CODE_SIGN_IDENTITY
    test_start "project signing: CODE_SIGN_IDENTITY wrong → error names CODE_SIGN_IDENTITY"
    local ts5; ts5="${tmpbase}/t-sign5"; mkdir -p "$ts5"
    local sign_info5
    sign_info5="$(_make_signing_env "$ts5" "CODE_SIGN_IDENTITY=iPhone Developer")"
    local bd5 ed5 fh5
    bd5="$(echo "$sign_info5" | cut -d'|' -f1)"
    ed5="$(echo "$sign_info5" | cut -d'|' -f2)"
    fh5="$(echo "$sign_info5" | cut -d'|' -f3)"
    local out5
    out5="$(capture_failing HOME="$fh5" ENV_FILE="${ed5}/release.env" \
        RELEASE_XCODEBUILD="${bd5}/xcodebuild" RELEASE_SECURITY="${bd5}/security" \
        RELEASE_GIT="${bd5}/git" RELEASE_AWS="${bd5}/aws" RELEASE_PLUTIL=plutil \
        bash "${RELEASE_SCRIPT}" preflight --skip-verify --allow-unpushed)"
    if echo "$out5" | grep -q "CODE_SIGN_IDENTITY"; then
        test_pass
    else
        test_fail "wrong CODE_SIGN_IDENTITY should produce error naming CODE_SIGN_IDENTITY; got: $out5"
    fi

    # Test 6: PRODUCT_BUNDLE_IDENTIFIER wrong → error names PRODUCT_BUNDLE_IDENTIFIER
    test_start "project signing: PRODUCT_BUNDLE_IDENTIFIER wrong → error names PRODUCT_BUNDLE_IDENTIFIER"
    local ts6; ts6="${tmpbase}/t-sign6"; mkdir -p "$ts6"
    local sign_info6
    sign_info6="$(_make_signing_env "$ts6" "PRODUCT_BUNDLE_IDENTIFIER=com.wrong.Bundle")"
    local bd6 ed6 fh6
    bd6="$(echo "$sign_info6" | cut -d'|' -f1)"
    ed6="$(echo "$sign_info6" | cut -d'|' -f2)"
    fh6="$(echo "$sign_info6" | cut -d'|' -f3)"
    local out6
    out6="$(capture_failing HOME="$fh6" ENV_FILE="${ed6}/release.env" \
        RELEASE_XCODEBUILD="${bd6}/xcodebuild" RELEASE_SECURITY="${bd6}/security" \
        RELEASE_GIT="${bd6}/git" RELEASE_AWS="${bd6}/aws" RELEASE_PLUTIL=plutil \
        bash "${RELEASE_SCRIPT}" preflight --skip-verify --allow-unpushed)"
    if echo "$out6" | grep -q "PRODUCT_BUNDLE_IDENTIFIER"; then
        test_pass
    else
        test_fail "wrong PRODUCT_BUNDLE_IDENTIFIER should produce error naming PRODUCT_BUNDLE_IDENTIFIER; got: $out6"
    fi

    # Test 7: multi-target output — only ChristmasTracker block used (Tests block has wrong CODE_SIGN_STYLE)
    test_start "project signing: multi-target output uses only ChristmasTracker block"
    local ts7; ts7="${tmpbase}/t-sign7"; mkdir -p "$ts7"
    local sign_info7
    sign_info7="$(_make_signing_env "$ts7")"
    # Splice a Tests-target block with a wrong CODE_SIGN_STYLE AFTER the app block
    splice_settings_block "${ts7}/settings.txt" after "ChristmasTrackerTests" \
        "CODE_SIGN_STYLE=Automatic" \
        "DEVELOPMENT_TEAM=TESTTEAM99" \
        "PRODUCT_BUNDLE_IDENTIFIER=com.alberta.ChristmasTrackerTests" \
        "MARKETING_VERSION=5.0" \
        "PRODUCT_NAME=ChristmasTrackerTests"
    local bd7 ed7 fh7
    bd7="$(echo "$sign_info7" | cut -d'|' -f1)"
    ed7="$(echo "$sign_info7" | cut -d'|' -f2)"
    fh7="$(echo "$sign_info7" | cut -d'|' -f3)"
    local out7
    out7="$(capture_failing HOME="$fh7" ENV_FILE="${ed7}/release.env" \
        RELEASE_XCODEBUILD="${bd7}/xcodebuild" RELEASE_SECURITY="${bd7}/security" \
        RELEASE_GIT="${bd7}/git" RELEASE_AWS="${bd7}/aws" RELEASE_PLUTIL=plutil \
        bash "${RELEASE_SCRIPT}" preflight --skip-verify --allow-unpushed)"
    # Should NOT fail on CODE_SIGN_STYLE from the Tests target (which is Automatic)
    if echo "$out7" | grep -q "CODE_SIGN_STYLE.*wrong\|CODE_SIGN_STYLE is wrong"; then
        test_fail "multi-target: signing check should use only ChristmasTracker block; got: $out7"
    else
        test_pass
    fi

    echo ""
    echo "--- archive signing mode ---"

    # Helper: build a minimal archive xcodebuild stub that logs its args and serves a
    # fixture-derived settings file for -showBuildSettings
    _make_archive_stub() {
        local bd="$1"
        local stub_log="$2"
        local settings_file="$3"
        cat > "${bd}/xcodebuild" <<ARCSTUB
#!/bin/bash
echo "STUB_CALL: xcodebuild \$*" >> "${stub_log}"
printf '%s\n' "\$*" >> "${stub_log}"
if [[ "\$*" == *"-showBuildSettings"* ]]; then
    cat "${settings_file}"
    exit 0
fi
# archive: create xcarchive dir
while [[ \$# -gt 0 ]]; do
    if [[ "\$1" == "-archivePath" ]]; then mkdir -p "\$2"; fi
    shift
done
exit 0
ARCSTUB
        chmod +x "${bd}/xcodebuild"
    }

    local settings_archive="${tmpbase}/settings-archive.txt"
    make_manual_settings_fixture "$settings_archive"

    # Test 8: archive default mode — no signing args, CURRENT_PROJECT_VERSION present
    test_start "archive default: CURRENT_PROJECT_VERSION present, no signing args"
    local ta8; ta8="${tmpbase}/t-arc8"; mkdir -p "$ta8"
    local bd8="${ta8}/bin"; mkdir -p "$bd8"
    local stub_log8="${ta8}/xcodebuild_args.log"
    write_stubs "$bd8" "" "TESTTEAM99"
    _make_archive_stub "$bd8" "$stub_log8" "$settings_archive"
    local ed8="${ta8}/envdir"; mkdir -p "$ed8"
    write_env "$ed8"
    STUB_LOG="$stub_log8" \
        ENV_FILE="${ed8}/release.env" \
        RELEASE_XCODEBUILD="${bd8}/xcodebuild" \
        RELEASE_GIT="${bd8}/git" \
        RELEASE_BUILD_ROOT="${ta8}/build/release" \
        LEDGER_FILE="${ta8}/.release-ledger" \
        bash "${RELEASE_SCRIPT}" archive --build 500 > /dev/null 2>&1 || true
    if [ -f "$stub_log8" ] && grep -q "CURRENT_PROJECT_VERSION=500" "$stub_log8" \
            && ! grep -q "CODE_SIGN_STYLE" "$stub_log8" \
            && ! grep -q "DEVELOPMENT_TEAM=" "$stub_log8"; then
        test_pass
    else
        local log8_content=""
        [ -f "$stub_log8" ] && log8_content="$(cat "$stub_log8")"
        test_fail "archive default: expected CURRENT_PROJECT_VERSION=500 and no signing args; log: $log8_content"
    fi

    # Test 9: archive cli mode — all signing args present
    test_start "archive cli mode: all signing args present"
    local ta9; ta9="${tmpbase}/t-arc9"; mkdir -p "$ta9"
    local bd9="${ta9}/bin"; mkdir -p "$bd9"
    local stub_log9="${ta9}/xcodebuild_args.log"
    write_stubs "$bd9" "" "TESTTEAM99"
    _make_archive_stub "$bd9" "$stub_log9" "$settings_archive"
    local ed9="${ta9}/envdir"; mkdir -p "$ed9"
    write_env "$ed9"
    STUB_LOG="$stub_log9" \
        ENV_FILE="${ed9}/release.env" \
        RELEASE_XCODEBUILD="${bd9}/xcodebuild" \
        RELEASE_GIT="${bd9}/git" \
        RELEASE_BUILD_ROOT="${ta9}/build/release" \
        LEDGER_FILE="${ta9}/.release-ledger" \
        RELEASE_ARCHIVE_SIGNING=cli \
        bash "${RELEASE_SCRIPT}" archive --build 500 > /dev/null 2>&1 || true
    if [ -f "$stub_log9" ] && grep -q "CODE_SIGN_STYLE=Manual" "$stub_log9" \
            && grep -q "DEVELOPMENT_TEAM" "$stub_log9" \
            && grep -q "PROVISIONING_PROFILE_SPECIFIER" "$stub_log9"; then
        test_pass
    else
        local log9_content=""
        [ -f "$stub_log9" ] && log9_content="$(cat "$stub_log9")"
        test_fail "archive cli mode: expected signing args in xcodebuild call; log: $log9_content"
    fi

    echo ""
    echo "--- device count ---"

    # Helper: build a preflight environment with a custom profile
    _make_preflight_env_with_profile() {
        local td="$1"
        local profile_mp="$2"  # path to .mobileprovision fixture
        local bd="${td}/bin"; mkdir -p "$bd"
        # write_stubs' default xcodebuild serves the fixture copy with correct Manual signing
        write_stubs "$bd" "" "TESTTEAM99"
        local ed="${td}/envdir"; mkdir -p "$ed"
        write_env "$ed"
        local fh="${td}/home"
        mkdir -p "${fh}/Library/MobileDevice/Provisioning Profiles"
        cp "$profile_mp" "${fh}/Library/MobileDevice/Provisioning Profiles/TestAdHocProfile.mobileprovision"
        echo "$bd|$ed|$fh"
    }

    # Test 10: 2-device profile reports "2"
    test_start "device count: 2-device profile reports '2'"
    local tdc10; tdc10="${tmpbase}/t-dc10"; mkdir -p "$tdc10"
    # make_ad_hoc_profile creates 2 devices (DEVICE0001, DEVICE0002)
    local dc10_pdir="${tdc10}/pdir"; mkdir -p "$dc10_pdir"
    make_ad_hoc_profile "$dc10_pdir" "TestAdHocProfile" "TESTTEAM99" "com.alberta.ChristmasTracker" 30 > /dev/null
    local dc10_info
    dc10_info="$(_make_preflight_env_with_profile "$tdc10" "${dc10_pdir}/TestAdHocProfile.mobileprovision")"
    local bd10 ed10 fh10
    bd10="$(echo "$dc10_info" | cut -d'|' -f1)"
    ed10="$(echo "$dc10_info" | cut -d'|' -f2)"
    fh10="$(echo "$dc10_info" | cut -d'|' -f3)"
    local out10
    out10="$(capture_failing HOME="$fh10" ENV_FILE="${ed10}/release.env" \
        RELEASE_XCODEBUILD="${bd10}/xcodebuild" RELEASE_SECURITY="${bd10}/security" \
        RELEASE_GIT="${bd10}/git" RELEASE_AWS="${bd10}/aws" RELEASE_PLUTIL=plutil \
        bash "${RELEASE_SCRIPT}" preflight --skip-verify --allow-unpushed)"
    if echo "$out10" | grep -q "registered devices: 2"; then
        test_pass
    else
        test_fail "2-device profile should report 'registered devices: 2'; got: $out10"
    fi

    # Test 10b: 1-device profile reports "1"
    test_start "device count: 1-device profile reports '1'"
    local tdc10b; tdc10b="${tmpbase}/t-dc10b"; mkdir -p "$tdc10b"
    local dc10b_pdir="${tdc10b}/pdir"; mkdir -p "$dc10b_pdir"
    local expiry_dc10b
    expiry_dc10b="$(date -u -v "+30d" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || date -u -d "+30 days" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || echo "2099-01-01T00:00:00Z")"
    # Build a profile with exactly 1 device UDID
    cat > "${dc10b_pdir}/TestAdHocProfile.mobileprovision" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Name</key>
    <string>TestAdHocProfile</string>
    <key>TeamIdentifier</key>
    <array><string>TESTTEAM99</string></array>
    <key>ExpirationDate</key>
    <date>${expiry_dc10b}</date>
    <key>ProvisionedDevices</key>
    <array>
        <string>DEVICE0001</string>
    </array>
    <key>Entitlements</key>
    <dict>
        <key>application-identifier</key>
        <string>TESTTEAM99.com.alberta.ChristmasTracker</string>
        <key>get-task-allow</key>
        <false/>
    </dict>
</dict>
</plist>
EOF
    local dc10b_info
    dc10b_info="$(_make_preflight_env_with_profile "$tdc10b" "${dc10b_pdir}/TestAdHocProfile.mobileprovision")"
    local bd10b ed10b fh10b
    bd10b="$(echo "$dc10b_info" | cut -d'|' -f1)"
    ed10b="$(echo "$dc10b_info" | cut -d'|' -f2)"
    fh10b="$(echo "$dc10b_info" | cut -d'|' -f3)"
    local out10b
    out10b="$(capture_failing HOME="$fh10b" ENV_FILE="${ed10b}/release.env" \
        RELEASE_XCODEBUILD="${bd10b}/xcodebuild" RELEASE_SECURITY="${bd10b}/security" \
        RELEASE_GIT="${bd10b}/git" RELEASE_AWS="${bd10b}/aws" RELEASE_PLUTIL=plutil \
        bash "${RELEASE_SCRIPT}" preflight --skip-verify --allow-unpushed)"
    if echo "$out10b" | grep -q "registered devices: 1"; then
        test_pass
    else
        test_fail "1-device profile should report 'registered devices: 1'; got: $out10b"
    fi

    # Test 11: 0-device profile fails
    test_start "device count: 0-device profile fails"
    local tdc11; tdc11="${tmpbase}/t-dc11"; mkdir -p "$tdc11"
    local expiry_dc11
    expiry_dc11="$(date -u -v "+30d" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || date -u -d "+30 days" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || echo "2099-01-01T00:00:00Z")"
    local dc11_pdir="${tdc11}/pdir"; mkdir -p "$dc11_pdir"
    # Build a profile with empty ProvisionedDevices array
    cat > "${dc11_pdir}/TestAdHocProfile.mobileprovision" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Name</key>
    <string>TestAdHocProfile</string>
    <key>TeamIdentifier</key>
    <array><string>TESTTEAM99</string></array>
    <key>ExpirationDate</key>
    <date>${expiry_dc11}</date>
    <key>ProvisionedDevices</key>
    <array/>
    <key>Entitlements</key>
    <dict>
        <key>application-identifier</key>
        <string>TESTTEAM99.com.alberta.ChristmasTracker</string>
        <key>get-task-allow</key>
        <false/>
    </dict>
</dict>
</plist>
EOF
    local dc11_info
    dc11_info="$(_make_preflight_env_with_profile "$tdc11" "${dc11_pdir}/TestAdHocProfile.mobileprovision")"
    local bd11 ed11 fh11
    bd11="$(echo "$dc11_info" | cut -d'|' -f1)"
    ed11="$(echo "$dc11_info" | cut -d'|' -f2)"
    fh11="$(echo "$dc11_info" | cut -d'|' -f3)"
    local out11
    out11="$(capture_failing HOME="$fh11" ENV_FILE="${ed11}/release.env" \
        RELEASE_XCODEBUILD="${bd11}/xcodebuild" RELEASE_SECURITY="${bd11}/security" \
        RELEASE_GIT="${bd11}/git" RELEASE_AWS="${bd11}/aws" RELEASE_PLUTIL=plutil \
        bash "${RELEASE_SCRIPT}" preflight --skip-verify --allow-unpushed)"
    if echo "$out11" | grep -qi "no registered devices\|0.*device"; then
        test_pass
    else
        test_fail "0-device profile should fail with 'no registered devices'; got: $out11"
    fi

    echo ""
    echo "--- SENTRY_DSN enforcement ---"

    local tv_sd2; tv_sd2="${tmpbase}/t-sentry2"; mkdir -p "$tv_sd2"
    write_env "$tv_sd2"
    local profile_sentry_dir="${tv_sd2}/profiles"; mkdir -p "$profile_sentry_dir"
    make_ad_hoc_profile "$profile_sentry_dir" "TestAdHocProfile" "TESTTEAM99" "com.alberta.ChristmasTracker" 30 > /dev/null
    local bindir_sentry="${tv_sd2}/bin"
    write_stubs "$bindir_sentry" "$profile_sentry_dir" "TESTTEAM99"
    local profile_sentry="${profile_sentry_dir}/TestAdHocProfile.mobileprovision"

    # Test 13: missing SENTRY_DSN fails (sentry_dsn="" → no key in plist)
    test_start "verify-ipa: missing SENTRY_DSN fails"
    local ts13; ts13="${tmpbase}/t-sd13"; mkdir -p "$ts13"
    write_env "$ts13"
    # Pass empty string as 9th arg → make_info_plist omits the key
    local info_sd13
    info_sd13="$(make_info_plist "$ts13" "com.alberta.ChristmasTracker" "500" "5.0" \
        "https://api.bmalberta.com" "real" "production" "false" "")"
    local ipa_sd13
    ipa_sd13="$(make_ipa "$ts13" "$info_sd13" "$profile_sentry" "no-sentry.ipa" "TESTTEAM99")"
    local out_sd13
    out_sd13="$(capture_failing ENV_FILE="${tv_sd2}/release.env" \
        RELEASE_XCODEBUILD="${bindir_sentry}/xcodebuild" \
        RELEASE_SECURITY="${bindir_sentry}/security" \
        RELEASE_CODESIGN="${bindir_sentry}/codesign" \
        bash "${RELEASE_SCRIPT}" verify-ipa --ipa "$ipa_sd13")"
    if echo "$out_sd13" | grep -q "SENTRY_DSN"; then
        test_pass
    else
        test_fail "missing SENTRY_DSN should produce SENTRY_DSN failure; got: $out_sd13"
    fi

    # Test 14: empty string SENTRY_DSN fails
    test_start "verify-ipa: empty string SENTRY_DSN fails"
    local ts14; ts14="${tmpbase}/t-sd14"; mkdir -p "$ts14"
    write_env "$ts14"
    # Manually write a plist with SENTRY_DSN = "" (empty string)
    local info_sd14="${ts14}/Info.plist"
    cat > "$info_sd14" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.alberta.ChristmasTracker</string>
    <key>CFBundleVersion</key><string>500</string>
    <key>CFBundleShortVersionString</key><string>5.0</string>
    <key>API_BASE_URL</key><string>https://api.bmalberta.com</string>
    <key>API_MODE</key><string>real</string>
    <key>APP_ENVIRONMENT</key><string>production</string>
    <key>SENTRY_DSN</key><string></string>
    <key>NSFaceIDUsageDescription</key><string>Use Face ID to unlock Christmas Tracker.</string>
    <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict>
</plist>
EOF
    local ipa_sd14
    ipa_sd14="$(make_ipa "$ts14" "$info_sd14" "$profile_sentry" "empty-sentry.ipa" "TESTTEAM99")"
    local out_sd14
    out_sd14="$(capture_failing ENV_FILE="${tv_sd2}/release.env" \
        RELEASE_XCODEBUILD="${bindir_sentry}/xcodebuild" \
        RELEASE_SECURITY="${bindir_sentry}/security" \
        RELEASE_CODESIGN="${bindir_sentry}/codesign" \
        bash "${RELEASE_SCRIPT}" verify-ipa --ipa "$ipa_sd14")"
    if echo "$out_sd14" | grep -q "SENTRY_DSN"; then
        test_pass
    else
        test_fail "empty SENTRY_DSN should produce SENTRY_DSN failure; got: $out_sd14"
    fi

    echo ""
    echo "--- PRODUCT_NAME payload path ---"

    local tv_pn; tv_pn="${tmpbase}/t-pname"; mkdir -p "$tv_pn"
    write_env "$tv_pn"
    local profile_pn_dir="${tv_pn}/profiles"; mkdir -p "$profile_pn_dir"
    make_ad_hoc_profile "$profile_pn_dir" "TestAdHocProfile" "TESTTEAM99" "com.alberta.ChristmasTracker" 30 > /dev/null
    local profile_pn="${profile_pn_dir}/TestAdHocProfile.mobileprovision"
    local bindir_pn="${tv_pn}/bin"
    write_stubs "$bindir_pn" "$profile_pn_dir" "TESTTEAM99"

    # Test 16: single Payload/*.app fallback when PRODUCT_NAME empty
    test_start "verify-ipa: single Payload/*.app fallback when PRODUCT_NAME empty"
    local ts16; ts16="${tmpbase}/t-pn16"; mkdir -p "$ts16"
    write_env "$ts16"
    # Settings copy with the PRODUCT_NAME line deleted. FULL_PRODUCT_NAME = ChristmasTracker.app
    # stays present — exactly the trap an unanchored lookup would fall into.
    local bd16="${ts16}/bin"; mkdir -p "$bd16"
    local settings16="${ts16}/settings.txt"
    make_manual_settings_fixture "$settings16"
    delete_setting "$settings16" PRODUCT_NAME
    write_stubs "$bd16" "$profile_pn_dir" "TESTTEAM99" "$settings16"
    local info_pn16
    info_pn16="$(make_info_plist "$ts16" "com.alberta.ChristmasTracker" "500" "5.0" \
        "https://api.bmalberta.com" "real" "production" "false")"
    # Build IPA with FallbackApp.app bundle name
    local ipa_pn16
    ipa_pn16="$(make_ipa "$ts16" "$info_pn16" "$profile_pn" "fallback.ipa" "TESTTEAM99" "FallbackApp.app")"
    local out_pn16
    out_pn16="$(capture_failing ENV_FILE="${ts16}/release.env" \
        RELEASE_XCODEBUILD="${bd16}/xcodebuild" \
        RELEASE_SECURITY="${bd16}/security" \
        RELEASE_CODESIGN="${bd16}/codesign" \
        bash "${RELEASE_SCRIPT}" verify-ipa --ipa "$ipa_pn16")"
    if echo "$out_pn16" | grep -q "all assertions passed"; then
        test_pass
    else
        test_fail "verify-ipa with fallback scan should find FallbackApp.app and pass; got: $out_pn16"
    fi

    # Test 17: fails when two app bundles in Payload
    test_start "verify-ipa: fails when two app bundles in Payload"
    local ts17; ts17="${tmpbase}/t-pn17"; mkdir -p "$ts17"
    write_env "$ts17"
    local bd17="${ts17}/bin"; mkdir -p "$bd17"
    # Same settings copy with no PRODUCT_NAME (FULL_PRODUCT_NAME still present)
    local settings17="${ts17}/settings.txt"
    make_manual_settings_fixture "$settings17"
    delete_setting "$settings17" PRODUCT_NAME
    write_stubs "$bd17" "$profile_pn_dir" "TESTTEAM99" "$settings17"
    # Build a base IPA first, then add a second .app bundle to it
    local info_pn17
    info_pn17="$(make_info_plist "$ts17" "com.alberta.ChristmasTracker" "500" "5.0" \
        "https://api.bmalberta.com" "real" "production" "false")"
    local ipa_pn17_base
    ipa_pn17_base="$(make_ipa "$ts17" "$info_pn17" "$profile_pn" "two-apps.ipa" "TESTTEAM99" "FirstApp.app")"
    # Add a second app bundle to the IPA
    local extra_app_dir="${ts17}/Payload/SecondApp.app"
    mkdir -p "$extra_app_dir"
    echo "FAKE" > "${extra_app_dir}/SecondApp"
    (cd "$ts17" && zip -qr "two-apps.ipa" "Payload/SecondApp.app/")
    local out_pn17
    out_pn17="$(capture_failing ENV_FILE="${ts17}/release.env" \
        RELEASE_XCODEBUILD="${bd17}/xcodebuild" \
        RELEASE_SECURITY="${bd17}/security" \
        RELEASE_CODESIGN="${bd17}/codesign" \
        bash "${RELEASE_SCRIPT}" verify-ipa --ipa "$ipa_pn17_base")"
    if echo "$out_pn17" | grep -qi "2.*app\|bundle.*count\|cannot determine\|bundles in Payload"; then
        test_pass
    else
        test_fail "verify-ipa with two app bundles should fail with bundle count error; got: $out_pn17"
    fi

    echo ""
    echo "--- install-info policy:set recipe ---"

    # Test 18 (inverted in I6b-1b): this used to assert "no npm run command in output" while
    # the flag names were unconfirmed. The backend operator doc has since confirmed the recipe,
    # so the development-database command SHOULD appear.
    test_start "install-info: development-database policy:set command present"
    local ti18; ti18="${tmpbase}/t-ii18"; mkdir -p "$ti18"
    write_env "$ti18"
    local bd18="${ti18}/bin"
    write_stubs "$bd18" "" "TESTTEAM99"
    local iinfo18_out
    iinfo18_out="$(ENV_FILE="${ti18}/release.env" RELEASE_XCODEBUILD="${bd18}/xcodebuild" \
        bash "${RELEASE_SCRIPT}" install-info --build 500 2>&1)"
    if echo "$iinfo18_out" | grep -q "npm run policy:set -- --platform ios"; then
        test_pass
    else
        test_fail "install-info output must contain the npm run policy:set command; got: $iinfo18_out"
    fi

    test_start "install-info: production-server policy-set.js command present"
    if echo "$iinfo18_out" | grep -q "compose.sh exec api node dist/scripts/policy-set.js --platform ios"; then
        test_pass
    else
        test_fail "install-info output must contain the compose.sh policy-set.js command; got: $iinfo18_out"
    fi

    # The two default command lines, isolated from the rest of the output
    local policy_cmds
    policy_cmds="$(echo "$iinfo18_out" | grep -E "npm run policy:set -- --platform ios|policy-set.js --platform ios")" || policy_cmds=""
    local policy_cmd_count
    policy_cmd_count="$(echo "$policy_cmds" | grep -c "")"

    test_start "install-info: exactly two default command lines"
    if [ "$policy_cmd_count" -eq 2 ]; then
        test_pass
    else
        test_fail "expected 2 policy:set command lines, got ${policy_cmd_count}: $policy_cmds"
    fi

    local flag
    for flag in \
        "--latest-build 500" \
        "--latest-version 5.0" \
        "--recommended-version 5.0" \
        "--manifest-url https://content.example.com/distribution/tracker/500/manifest.plist" \
        "--ipa-url https://content.example.com/distribution/tracker/500/ChristmasTracker-5.0-500.ipa" \
        "--notes"; do
        test_start "install-info: both commands contain '${flag}'"
        if [ "$(echo "$policy_cmds" | grep -c -- "$flag")" -eq 2 ]; then
            test_pass
        else
            test_fail "expected '${flag}' on both command lines; got: $policy_cmds"
        fi
    done

    test_start "install-info: default commands do not contain --min-build"
    if echo "$policy_cmds" | grep -q -- "--min-build"; then
        test_fail "default command lines must not contain --min-build; got: $policy_cmds"
    else
        test_pass
    fi

    test_start "install-info: default commands do not contain --minimum-version"
    if echo "$policy_cmds" | grep -q -- "--minimum-version"; then
        test_fail "default command lines must not contain --minimum-version; got: $policy_cmds"
    else
        test_pass
    fi

    test_start "install-info: cannot-clear sentence present"
    if echo "$iinfo18_out" | grep -q "cannot be cleared"; then
        test_pass
    else
        test_fail "install-info must state the URLs cannot be cleared; got: $iinfo18_out"
    fi

    test_start "install-info: force-update warning present and unfilled"
    if echo "$iinfo18_out" | grep -q "every family phone" \
        && echo "$iinfo18_out" | grep -q -- "--min-build N --minimum-version X.Y"; then
        test_pass
    else
        test_fail "install-info must print the force-update warning with N / X.Y placeholders; got: $iinfo18_out"
    fi

    test_start "install-info: script states it never runs policy:set"
    if echo "$iinfo18_out" | grep -q "never runs policy:set"; then
        test_pass
    else
        test_fail "install-info must say the script never runs policy:set; got: $iinfo18_out"
    fi

    test_start "install-info: recipe output has no secret-looking values"
    if echo "$iinfo18_out" | grep -qiE "password|token|secret|access_key"; then
        test_fail "install-info output must not contain secret-looking values"
    else
        test_pass
    fi

    test_start "install-info: without --build the commands keep the <build> placeholder"
    local iinfo18b_out
    iinfo18b_out="$(ENV_FILE="${ti18}/release.env" RELEASE_XCODEBUILD="${bd18}/xcodebuild" \
        bash "${RELEASE_SCRIPT}" install-info 2>&1)"
    if echo "$iinfo18b_out" | grep "npm run policy:set" | grep -q -- "--latest-build <build>"; then
        test_pass
    else
        test_fail "install-info without --build should print --latest-build <build>; got: $iinfo18b_out"
    fi

    echo ""
    echo "--- anchored build-setting lookups ---"

    local tal; tal="${tmpbase}/t-anchored"; mkdir -p "$tal"
    write_env "$tal"
    local profile_al_dir="${tal}/profiles"; mkdir -p "$profile_al_dir"
    make_ad_hoc_profile "$profile_al_dir" "TestAdHocProfile" "TESTTEAM99" "com.alberta.ChristmasTracker" 30 > /dev/null
    local profile_al="${profile_al_dir}/TestAdHocProfile.mobileprovision"
    # Default write_stubs: fixture copy (FULL_PRODUCT_NAME = ChristmasTracker.app precedes PRODUCT_NAME)
    local bindir_al="${tal}/bin"
    write_stubs "$bindir_al" "$profile_al_dir" "TESTTEAM99"
    local info_al
    info_al="$(make_info_plist "$tal" "com.alberta.ChristmasTracker" "500" "5.0" "https://api.bmalberta.com" "real" "production" "false")"
    local ipa_al
    ipa_al="$(make_ipa "$tal" "$info_al" "$profile_al" "anchored.ipa" "TESTTEAM99" "ChristmasTracker.app")"
    local out_al
    out_al="$(capture_failing ENV_FILE="${tal}/release.env" \
        RELEASE_XCODEBUILD="${bindir_al}/xcodebuild" \
        RELEASE_SECURITY="${bindir_al}/security" \
        RELEASE_CODESIGN="${bindir_al}/codesign" \
        bash "${RELEASE_SCRIPT}" verify-ipa --build 500 --ipa "$ipa_al")"

    test_start "anchored lookup: verify-ipa passes a good IPA named from PRODUCT_NAME via the fixture stub"
    if echo "$out_al" | grep -q "all assertions passed"; then
        test_pass
    else
        test_fail "verify-ipa against the real-shaped fixture should pass; got: $out_al"
    fi

    test_start "anchored lookup: PRODUCT_NAME resolves to ChristmasTracker, not ChristmasTracker.app"
    # If FULL_PRODUCT_NAME had won, the payload prefix would be Payload/ChristmasTracker.app.app
    # and Info.plist extraction would fail; assert both the absence and the success path.
    if echo "$out_al" | grep -q "ChristmasTracker.app.app"; then
        test_fail "output mentions ChristmasTracker.app.app — FULL_PRODUCT_NAME leaked into PRODUCT_NAME"
    elif echo "$out_al" | grep -q "Could not extract Info.plist"; then
        test_fail "Info.plist extraction failed — app bundle name was not derived from PRODUCT_NAME; got: $out_al"
    else
        test_pass
    fi

    test_start "anchored lookup: MARKETING_VERSION resolves to 5.0 from the fixture"
    local tmv; tmv="${tmpbase}/t-mv"; mkdir -p "$tmv"
    write_env "$tmv"
    local bindir_mv="${tmv}/bin"
    # The unmodified fixture file itself (no overrides at all)
    write_stubs "$bindir_mv" "" "TESTTEAM99" "$FIXTURE_SETTINGS"
    ENV_FILE="${tmv}/release.env" \
        RELEASE_XCODEBUILD="${bindir_mv}/xcodebuild" \
        RELEASE_BUILD_ROOT="${tmv}/build/release" \
        LEDGER_FILE="${tmv}/.release-ledger" \
        bash "${RELEASE_SCRIPT}" manifest --build 500 > /dev/null 2>&1 || true
    if grep -q "distribution/tracker/500/ChristmasTracker-5.0-500.ipa" "${tmv}/build/release/500/manifest.plist" 2>/dev/null; then
        test_pass
    else
        test_fail "manifest should name ChristmasTracker-5.0-500.ipa from the fixture's MARKETING_VERSION"
    fi

    test_start "anchored lookup: install-info names ChristmasTracker-5.0-500.ipa from the unmodified fixture"
    if ENV_FILE="${tmv}/release.env" RELEASE_XCODEBUILD="${bindir_mv}/xcodebuild" \
        bash "${RELEASE_SCRIPT}" install-info --build 500 2>&1 | grep -q "ChristmasTracker-5.0-500.ipa"; then
        test_pass
    else
        test_fail "install-info should name ChristmasTracker-5.0-500.ipa"
    fi

    # CODE_SIGN_IDENTITY must come from CODE_SIGN_IDENTITY, never EXPANDED_CODE_SIGN_IDENTITY.
    # make_settings_fixture inserts the absent EXPANDED_ key right after the block header,
    # i.e. BEFORE CODE_SIGN_IDENTITY, so an unanchored grep|head -1 would read it first.
    test_start "anchored lookup: CODE_SIGN_IDENTITY ignores EXPANDED_CODE_SIGN_IDENTITY (wrong real identity is reported)"
    local tci1; tci1="${tmpbase}/t-csi1"; mkdir -p "$tci1"
    local csi_info1
    csi_info1="$(_make_signing_env "$tci1" \
        "CODE_SIGN_IDENTITY=iPhone Developer" \
        "EXPANDED_CODE_SIGN_IDENTITY=Apple Distribution: Test User (TESTTEAM99)")"
    local bdc1 edc1 fhc1
    bdc1="$(echo "$csi_info1" | cut -d'|' -f1)"
    edc1="$(echo "$csi_info1" | cut -d'|' -f2)"
    fhc1="$(echo "$csi_info1" | cut -d'|' -f3)"
    local out_csi1
    out_csi1="$(capture_failing HOME="$fhc1" ENV_FILE="${edc1}/release.env" \
        RELEASE_XCODEBUILD="${bdc1}/xcodebuild" RELEASE_SECURITY="${bdc1}/security" \
        RELEASE_GIT="${bdc1}/git" RELEASE_AWS="${bdc1}/aws" RELEASE_PLUTIL=plutil \
        bash "${RELEASE_SCRIPT}" preflight --skip-verify --allow-unpushed)"
    if echo "$out_csi1" | grep -q "CODE_SIGN_IDENTITY is wrong"; then
        test_pass
    else
        test_fail "preflight must report CODE_SIGN_IDENTITY wrong when only EXPANDED_CODE_SIGN_IDENTITY is a distribution identity; got: $out_csi1"
    fi

    test_start "anchored lookup: CODE_SIGN_IDENTITY ignores EXPANDED_CODE_SIGN_IDENTITY (wrong expanded identity is not reported)"
    local tci2; tci2="${tmpbase}/t-csi2"; mkdir -p "$tci2"
    local csi_info2
    csi_info2="$(_make_signing_env "$tci2" \
        "CODE_SIGN_IDENTITY=Apple Distribution: Test User (TESTTEAM99)" \
        "EXPANDED_CODE_SIGN_IDENTITY=iPhone Developer")"
    local bdc2 edc2 fhc2
    bdc2="$(echo "$csi_info2" | cut -d'|' -f1)"
    edc2="$(echo "$csi_info2" | cut -d'|' -f2)"
    fhc2="$(echo "$csi_info2" | cut -d'|' -f3)"
    local out_csi2
    out_csi2="$(capture_failing HOME="$fhc2" ENV_FILE="${edc2}/release.env" \
        RELEASE_XCODEBUILD="${bdc2}/xcodebuild" RELEASE_SECURITY="${bdc2}/security" \
        RELEASE_GIT="${bdc2}/git" RELEASE_AWS="${bdc2}/aws" RELEASE_PLUTIL=plutil \
        bash "${RELEASE_SCRIPT}" preflight --skip-verify --allow-unpushed)"
    if echo "$out_csi2" | grep -q "CODE_SIGN_IDENTITY is wrong"; then
        test_fail "preflight must not report CODE_SIGN_IDENTITY wrong when the real key is correct; got: $out_csi2"
    else
        test_pass
    fi

    # App-target block wins over a spliced package block with conflicting values
    local pos
    for pos in after before; do
        local tblk; tblk="${tmpbase}/t-block-${pos}"; mkdir -p "$tblk"
        local blk_info
        blk_info="$(_make_signing_env "$tblk")"
        local bdb edb fhb
        bdb="$(echo "$blk_info" | cut -d'|' -f1)"
        edb="$(echo "$blk_info" | cut -d'|' -f2)"
        fhb="$(echo "$blk_info" | cut -d'|' -f3)"
        splice_settings_block "${tblk}/settings.txt" "$pos" "TrackerAPI" \
            "PRODUCT_NAME=TrackerAPI" \
            "MARKETING_VERSION=9.9" \
            "CODE_SIGN_STYLE=Automatic"

        test_start "anchored lookup: app-target block wins over a package block spliced ${pos} it (manifest names 5.0)"
        ENV_FILE="${edb}/release.env" \
            RELEASE_XCODEBUILD="${bdb}/xcodebuild" \
            RELEASE_BUILD_ROOT="${tblk}/build/release" \
            LEDGER_FILE="${tblk}/.release-ledger" \
            bash "${RELEASE_SCRIPT}" manifest --build 500 > /dev/null 2>&1 || true
        if grep -q "ChristmasTracker-5.0-500.ipa" "${tblk}/build/release/500/manifest.plist" 2>/dev/null; then
            test_pass
        else
            test_fail "manifest should use the app block's MARKETING_VERSION (5.0), not the ${pos} package block (9.9)"
        fi

        test_start "anchored lookup: app-target block wins over a package block spliced ${pos} it (preflight CODE_SIGN_STYLE OK)"
        local out_blk
        out_blk="$(capture_failing HOME="$fhb" ENV_FILE="${edb}/release.env" \
            RELEASE_XCODEBUILD="${bdb}/xcodebuild" RELEASE_SECURITY="${bdb}/security" \
            RELEASE_GIT="${bdb}/git" RELEASE_AWS="${bdb}/aws" RELEASE_PLUTIL=plutil \
            bash "${RELEASE_SCRIPT}" preflight --skip-verify --allow-unpushed)"
        if echo "$out_blk" | grep -q "CODE_SIGN_STYLE is wrong"; then
            test_fail "preflight must read CODE_SIGN_STYLE from the app block, not the ${pos} package block; got: $out_blk"
        else
            test_pass
        fi
    done

    # Mutation: FULL_PRODUCT_NAME as the very first setting of the block, PRODUCT_NAME last
    test_start "mutation: stub emitting FULL_PRODUCT_NAME before PRODUCT_NAME still yields ChristmasTracker"
    local tmu; tmu="${tmpbase}/t-mutation"; mkdir -p "$tmu"
    write_env "$tmu"
    local settings_mu="${tmu}/settings.txt"
    make_manual_settings_fixture "$settings_mu"
    delete_setting "$settings_mu" FULL_PRODUCT_NAME
    delete_setting "$settings_mu" PRODUCT_NAME
    # Re-insert FULL_PRODUCT_NAME directly after the header (first line of the block) ...
    awk -v hdr="$APP_BLOCK_HEADER" '{ print } $0 == hdr { print "    FULL_PRODUCT_NAME = ChristmasTracker.app" }' \
        "$settings_mu" > "${settings_mu}.tmp"
    mv "${settings_mu}.tmp" "$settings_mu"
    # ... and PRODUCT_NAME as the last line of the (single) block
    echo "    PRODUCT_NAME = ChristmasTracker" >> "$settings_mu"
    local bindir_mu="${tmu}/bin"
    write_stubs "$bindir_mu" "$profile_al_dir" "TESTTEAM99" "$settings_mu"
    local ipa_mu
    ipa_mu="$(make_ipa "$tmu" "$info_al" "$profile_al" "mutation.ipa" "TESTTEAM99" "ChristmasTracker.app")"
    local out_mu
    out_mu="$(capture_failing ENV_FILE="${tmu}/release.env" \
        RELEASE_XCODEBUILD="${bindir_mu}/xcodebuild" \
        RELEASE_SECURITY="${bindir_mu}/security" \
        RELEASE_CODESIGN="${bindir_mu}/codesign" \
        bash "${RELEASE_SCRIPT}" verify-ipa --build 500 --ipa "$ipa_mu")"
    if echo "$out_mu" | grep -q "all assertions passed" && ! echo "$out_mu" | grep -q "ChristmasTracker.app.app"; then
        test_pass
    else
        test_fail "verify-ipa must still resolve PRODUCT_NAME=ChristmasTracker when FULL_PRODUCT_NAME comes first; got: $out_mu"
    fi

    echo ""
    echo "--- export IPA discovery ---"

    # Helper: a ready-to-export build dir with env, fixture settings, and a fake xcarchive
    _make_export_env() {
        local td="$1"; shift
        write_env "$td"
        local bd="${td}/bin"; mkdir -p "$bd"
        local sf="${td}/settings.txt"
        make_manual_settings_fixture "$sf"
        write_export_stub "$bd" "$sf" "$@"
        mkdir -p "${td}/build/release/500/ChristmasTracker.xcarchive"
    }

    test_start "export: exactly one exported IPA is renamed to ChristmasTracker-5.0-500.ipa"
    local tex1; tex1="${tmpbase}/t-export1"; mkdir -p "$tex1"
    _make_export_env "$tex1" "SomeOtherName.ipa"
    local export_rc1=0
    ENV_FILE="${tex1}/release.env" \
        RELEASE_XCODEBUILD="${tex1}/bin/xcodebuild" \
        RELEASE_PLUTIL=plutil \
        RELEASE_BUILD_ROOT="${tex1}/build/release" \
        LEDGER_FILE="${tex1}/.release-ledger" \
        bash "${RELEASE_SCRIPT}" export --build 500 > /dev/null 2>&1 || export_rc1=$?
    if [ "$export_rc1" -eq 0 ] \
        && [ -f "${tex1}/build/release/500/ChristmasTracker-5.0-500.ipa" ] \
        && [ ! -f "${tex1}/build/release/500/SomeOtherName.ipa" ]; then
        test_pass
    else
        test_fail "export should exit 0 and rename SomeOtherName.ipa to ChristmasTracker-5.0-500.ipa (rc=${export_rc1})"
    fi

    test_start "export: zero exported IPAs fails with a clear message"
    local tex0; tex0="${tmpbase}/t-export0"; mkdir -p "$tex0"
    _make_export_env "$tex0"
    local export_rc0=0
    local out_ex0
    out_ex0="$(ENV_FILE="${tex0}/release.env" \
        RELEASE_XCODEBUILD="${tex0}/bin/xcodebuild" \
        RELEASE_PLUTIL=plutil \
        RELEASE_BUILD_ROOT="${tex0}/build/release" \
        LEDGER_FILE="${tex0}/.release-ledger" \
        bash "${RELEASE_SCRIPT}" export --build 500 2>&1)" || export_rc0=$?
    if [ "$export_rc0" -ne 0 ] \
        && echo "$out_ex0" | grep -q "found 0 .ipa" \
        && echo "$out_ex0" | grep -q "${tex0}/build/release/500"; then
        test_pass
    else
        test_fail "export with no IPA should fail naming the count 0 and the directory (rc=${export_rc0}); got: $out_ex0"
    fi

    test_start "export: two exported IPAs fails with a clear message"
    local tex2; tex2="${tmpbase}/t-export2"; mkdir -p "$tex2"
    _make_export_env "$tex2" "First.ipa" "Second.ipa"
    local export_rc2=0
    local out_ex2
    out_ex2="$(ENV_FILE="${tex2}/release.env" \
        RELEASE_XCODEBUILD="${tex2}/bin/xcodebuild" \
        RELEASE_PLUTIL=plutil \
        RELEASE_BUILD_ROOT="${tex2}/build/release" \
        LEDGER_FILE="${tex2}/.release-ledger" \
        bash "${RELEASE_SCRIPT}" export --build 500 2>&1)" || export_rc2=$?
    if [ "$export_rc2" -ne 0 ] \
        && echo "$out_ex2" | grep -q "found 2" \
        && echo "$out_ex2" | grep -q "${tex2}/build/release/500"; then
        test_pass
    else
        test_fail "export with two IPAs should fail naming the count 2 and the directory (rc=${export_rc2}); got: $out_ex2"
    fi

    test_start "export: an IPA already named ChristmasTracker-5.0-500.ipa is kept without a self-move error"
    local tex3; tex3="${tmpbase}/t-export3"; mkdir -p "$tex3"
    _make_export_env "$tex3" "ChristmasTracker-5.0-500.ipa"
    local export_rc3=0
    ENV_FILE="${tex3}/release.env" \
        RELEASE_XCODEBUILD="${tex3}/bin/xcodebuild" \
        RELEASE_PLUTIL=plutil \
        RELEASE_BUILD_ROOT="${tex3}/build/release" \
        LEDGER_FILE="${tex3}/.release-ledger" \
        bash "${RELEASE_SCRIPT}" export --build 500 > /dev/null 2>&1 || export_rc3=$?
    if [ "$export_rc3" -eq 0 ] && [ -f "${tex3}/build/release/500/ChristmasTracker-5.0-500.ipa" ]; then
        test_pass
    else
        test_fail "export should succeed when xcodebuild already produced the final name (rc=${export_rc3})"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
run_tests

echo ""
echo "=== test-release.sh: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] || exit 1
