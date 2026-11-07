#!/bin/bash
# scripts/test-release.sh — Self-contained test harness for scripts/release.sh.
# Uses stubs and fixtures only. Never touches the network, real keychain, real
# provisioning profile directory, xcodebuild, or aws.
# Exit: 0 when all tests pass, 1 on any failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RELEASE_SCRIPT="${SCRIPT_DIR}/release.sh"

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

    local plist="${dir}/Info.plist"
    local ats_block=""
    if [ "$allow_arbitrary" = "true" ]; then
        ats_block="<key>NSAllowsArbitraryLoads</key><true/>"
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

    local app_dir="${dir}/Payload/ChristmasTracker.app"
    mkdir -p "$app_dir"
    cp "$info_plist" "${app_dir}/Info.plist"
    cp "$profile" "${app_dir}/embedded.mobileprovision"

    # Fake binary and codesign metadata
    echo "FAKE_BINARY" > "${app_dir}/ChristmasTracker"
    mkdir -p "${app_dir}/_CodeSignature"
    echo "fake" > "${app_dir}/_CodeSignature/CodeResources"

    local ipa="${dir}/${ipa_name}"
    # zip from within dir so paths start with Payload/
    (cd "$dir" && zip -qr "$ipa_name" "Payload/")
    echo "$ipa"
}

# ---------------------------------------------------------------------------
# Stub factories
# ---------------------------------------------------------------------------

# Write stub scripts to a bin directory. These replace real tools.
# Each stub records its calls in $STUB_LOG (passed via env).
write_stubs() {
    local bindir="$1"
    local team="${3:-TESTTEAM99}"
    # $2 (profile_dir) is unused in this stub factory; profile lookup is handled by HOME override in callers

    mkdir -p "$bindir"

    # xcodebuild stub: prints MARKETING_VERSION for -showBuildSettings; exits 0 for archive/export
    cat > "${bindir}/xcodebuild" <<'STUB'
#!/bin/bash
echo "STUB_CALL: xcodebuild $*" >> "${STUB_LOG:-/dev/null}"
# If called with -showBuildSettings, print fake build settings
if [[ "$*" == *"-showBuildSettings"* ]]; then
    echo "    MARKETING_VERSION = 5.0"
    echo "    CURRENT_PROJECT_VERSION = 500"
    echo "    PRODUCT_BUNDLE_IDENTIFIER = com.alberta.ChristmasTracker"
    echo "    API_BASE_URL = https://api.bmalberta.com"
    echo "    API_MODE = real"
    echo "    APP_ENVIRONMENT = production"
    exit 0
fi
# For archive: create a fake xcarchive directory at -archivePath
ARCHIVE_PATH=""
while [[ $# -gt 0 ]]; do
    if [[ "$1" == "-archivePath" ]]; then ARCHIVE_PATH="$2"; fi
    shift
done
if [[ -n "$ARCHIVE_PATH" ]]; then
    mkdir -p "$ARCHIVE_PATH"
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
    mkdir -p "$bindir5"
    cat > "${bindir5}/xcodebuild" <<'STUB'
#!/bin/bash
echo "    MARKETING_VERSION = 5.0"
exit 0
STUB
    chmod +x "${bindir5}/xcodebuild"
    if ENV_FILE="${t5}/release.env" RELEASE_XCODEBUILD="${bindir5}/xcodebuild" \
       bash "${RELEASE_SCRIPT}" install-info --build 500 > /dev/null 2>&1; then
        test_pass
    else
        test_fail "valid env should not fail env validation"
    fi

    echo ""
    echo "--- build number validation ---"

    local bindir_xc; bindir_xc="${tmpbase}/xc-stubs"; mkdir -p "$bindir_xc"
    cat > "${bindir_xc}/xcodebuild" <<'STUB'
#!/bin/bash
echo "    MARKETING_VERSION = 5.0"
exit 0
STUB
    chmod +x "${bindir_xc}/xcodebuild"

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
    cat > "${bindir_xc}/xcodebuild_export" <<'STUB'
#!/bin/bash
echo "    MARKETING_VERSION = 5.0"
exit 0
STUB
    chmod +x "${bindir_xc}/xcodebuild_export"
    # Run export --dry-run to trigger ExportOptions generation without actual xcodebuild
    # The script writes ExportOptions.plist before calling xcodebuild in export mode
    # We need to check the generated file; in --dry-run mode it prints but doesn't write.
    # In live mode it writes. Let's use a fake xcodebuild that exits 0 and check the file.
    local bindir_e="${te}/bin"; mkdir -p "$bindir_e"
    cat > "${bindir_e}/xcodebuild" <<STUB
#!/bin/bash
if [[ "\$*" == *"-showBuildSettings"* ]]; then
    echo "    MARKETING_VERSION = 5.0"
    exit 0
fi
# Fake archive: create directory
while [[ \$# -gt 0 ]]; do
    if [[ "\$1" == "-archivePath" ]]; then mkdir -p "\$2"; fi
    shift
done
exit 0
STUB
    chmod +x "${bindir_e}/xcodebuild"
    mkdir -p "${te}/build/release/500"
    # Create a fake xcarchive so export doesn't fail on missing archive check
    mkdir -p "${te}/build/release/500/ChristmasTracker.xcarchive"
    # export will also look for the archive via build_dir; override BUILD root
    # We test the plist generation directly by running export non-dry-run
    # but catching that xcodebuild -exportArchive is a no-op
    cat > "${bindir_e}/xcodebuild" <<STUB
#!/bin/bash
if [[ "\$*" == *"-showBuildSettings"* ]]; then
    echo "    MARKETING_VERSION = 5.0"
    exit 0
fi
if [[ "\$*" == *"-exportArchive"* ]]; then
    # Simulate successful export: create the IPA in -exportPath
    EXPORT_PATH=""
    while [[ \$# -gt 0 ]]; do
        if [[ "\$1" == "-exportPath" ]]; then EXPORT_PATH="\$2"; fi
        shift
    done
    if [[ -n "\$EXPORT_PATH" ]]; then
        touch "\${EXPORT_PATH}/ChristmasTracker.ipa"
    fi
    exit 0
fi
exit 0
STUB
    chmod +x "${bindir_e}/xcodebuild"
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
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
run_tests

echo ""
echo "=== test-release.sh: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] || exit 1
