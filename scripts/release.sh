#!/bin/bash
# scripts/release.sh — Christmas Tracker ad hoc release tool.
# Brian runs this; agents write and test it but never execute signing, archiving, or uploads.
# Usage: scripts/release.sh <subcommand> [options]
# Subcommands: preflight, archive, export, verify-ipa, manifest, upload, install-info, all
# Options: --build N, --dry-run, --yes, --allow-branch NAME, --allow-unpushed, --skip-verify,
#          --ipa PATH (for standalone verify-ipa), --verbose
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# Allow test overrides via environment variables
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/release.env}"
LEDGER_FILE="${LEDGER_FILE:-${SCRIPT_DIR}/.release-ledger}"
# Allow tests to override the build output root (defaults to repo root/build/release)
RELEASE_BUILD_ROOT="${RELEASE_BUILD_ROOT:-${REPO_ROOT}/build/release}"

# Tool overrides (tests substitute stubs via these variables)
RELEASE_XCODEBUILD="${RELEASE_XCODEBUILD:-xcodebuild}"
RELEASE_AWS="${RELEASE_AWS:-aws}"
RELEASE_SECURITY="${RELEASE_SECURITY:-security}"
RELEASE_CODESIGN="${RELEASE_CODESIGN:-codesign}"
RELEASE_PLUTIL="${RELEASE_PLUTIL:-plutil}"
RELEASE_UNZIP="${RELEASE_UNZIP:-unzip}"
RELEASE_SHASUM="${RELEASE_SHASUM:-shasum}"
RELEASE_GIT="${RELEASE_GIT:-git}"

RELEASE_ARCHIVE_SIGNING="${RELEASE_ARCHIVE_SIGNING:-project}"

# ---------------------------------------------------------------------------
# Defaults for optional env vars (overridden by release.env or environment)
# ---------------------------------------------------------------------------
RELEASE_BUNDLE_ID="${RELEASE_BUNDLE_ID:-com.alberta.ChristmasTracker}"
RELEASE_S3_PREFIX="${RELEASE_S3_PREFIX:-distribution/tracker}"
RELEASE_PUBLIC_BASE_URL="${RELEASE_PUBLIC_BASE_URL:-https://content.bmalberta.com}"
RELEASE_EXPORT_METHOD="${RELEASE_EXPORT_METHOD:-release-testing}"
RELEASE_MIN_PROFILE_DAYS="${RELEASE_MIN_PROFILE_DAYS:-14}"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
SUBCOMMAND=""
BUILD_NUMBER=""
DRY_RUN=0
YES=0
ALLOW_BRANCH=""
ALLOW_UNPUSHED=0
SKIP_VERIFY=0
IPA_PATH=""
VERBOSE=0

usage() {
    cat >&2 <<'EOF'
Usage: scripts/release.sh <subcommand> [options]

Subcommands:
  preflight      Validate environment, tools, profile, identity, repo state
  archive        xcodebuild archive (needs signing identity)
  export         xcodebuild -exportArchive to produce IPA
  verify-ipa     Assert IPA content correctness (also: --ipa PATH for standalone use)
  manifest       Generate manifest.plist for itms-services install
  upload         Upload IPA and manifest to S3 (requires --yes or --dry-run)
  install-info   Print install link, URLs, and policy:set values
  all            Run: preflight, archive, export, verify-ipa, manifest, upload, install-info

Options:
  --build N           Build number (integer >= 500, strictly > ledger)
  --dry-run           Print commands without executing side-effectful steps
  --yes               Confirm destructive operations (required for upload)
  --allow-branch NAME Allow running on branch NAME instead of master
  --allow-unpushed    Allow HEAD not matching origin/master
  --skip-verify       Skip scripts/verify.sh in preflight (UNSAFE)
  --ipa PATH          IPA file path for standalone verify-ipa
  --verbose           Extra output
EOF
    exit 1
}

if [ "$#" -eq 0 ]; then usage; fi

SUBCOMMAND="$1"; shift

while [ "$#" -gt 0 ]; do
    case "$1" in
        --build)
            [ "$#" -ge 2 ] || { echo "error: --build requires a value" >&2; exit 1; }
            BUILD_NUMBER="$2"; shift 2;;
        --dry-run) DRY_RUN=1; shift;;
        --yes) YES=1; shift;;
        --allow-branch)
            [ "$#" -ge 2 ] || { echo "error: --allow-branch requires a value" >&2; exit 1; }
            ALLOW_BRANCH="$2"; shift 2;;
        --allow-unpushed) ALLOW_UNPUSHED=1; shift;;
        --skip-verify) SKIP_VERIFY=1; shift;;
        --ipa)
            [ "$#" -ge 2 ] || { echo "error: --ipa requires a value" >&2; exit 1; }
            IPA_PATH="$2"; shift 2;;
        --verbose) VERBOSE=1; shift;;
        *) echo "error: unknown option: $1" >&2; usage;;
    esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[release] $*"; }
info() { echo "[release] $*"; }
warn() { echo "[release] WARNING: $*" >&2; }
die()  { echo "[release] ERROR: $*" >&2; exit 1; }

dry_run_cmd() {
    # Print the command. When DRY_RUN=1 do not execute; return 0.
    local label="$1"; shift
    echo "[dry-run] ${label}: $*"
    if [ "$DRY_RUN" -eq 0 ]; then
        "$@"
    fi
}

require_build_number() {
    [ -n "$BUILD_NUMBER" ] || die "--build N is required for this subcommand"
}

# ---------------------------------------------------------------------------
# Load env file
# ---------------------------------------------------------------------------
load_env() {
    if [ -f "$ENV_FILE" ]; then
        # shellcheck source=/dev/null
        source "$ENV_FILE"
    fi
    # Re-apply defaults that may have been overridden by env file or caller environment
    RELEASE_BUNDLE_ID="${RELEASE_BUNDLE_ID:-com.alberta.ChristmasTracker}"
    RELEASE_S3_PREFIX="${RELEASE_S3_PREFIX:-distribution/tracker}"
    RELEASE_PUBLIC_BASE_URL="${RELEASE_PUBLIC_BASE_URL:-https://content.bmalberta.com}"
    RELEASE_EXPORT_METHOD="${RELEASE_EXPORT_METHOD:-release-testing}"
    RELEASE_MIN_PROFILE_DAYS="${RELEASE_MIN_PROFILE_DAYS:-14}"
}

# ---------------------------------------------------------------------------
# Env validation
# ---------------------------------------------------------------------------
validate_env() {
    local fail=0

    for var in RELEASE_TEAM_ID RELEASE_PROFILE_NAME RELEASE_BUNDLE_ID RELEASE_S3_BUCKET; do
        if [ -z "${!var:-}" ]; then
            echo "[release] ERROR: $var is not set (check ${ENV_FILE})" >&2
            fail=1
        fi
    done

    # Public base URL must be https
    local base_url="${RELEASE_PUBLIC_BASE_URL:-}"
    if [ -n "$base_url" ] && [[ "$base_url" != https://* ]]; then
        echo "[release] ERROR: RELEASE_PUBLIC_BASE_URL must use https, got: $base_url" >&2
        fail=1
    fi

    [ "$fail" -eq 0 ] || exit 1

    if [ "$VERBOSE" -eq 1 ]; then
        log "RELEASE_TEAM_ID: [set]"
        log "RELEASE_PROFILE_NAME: [set]"
        log "RELEASE_BUNDLE_ID: ${RELEASE_BUNDLE_ID}"
        log "RELEASE_S3_BUCKET: [set]"
        log "RELEASE_S3_PREFIX: ${RELEASE_S3_PREFIX}"
        log "RELEASE_PUBLIC_BASE_URL: ${RELEASE_PUBLIC_BASE_URL}"
        log "RELEASE_AWS_PROFILE: ${RELEASE_AWS_PROFILE:-(using default profile)}"
        log "RELEASE_EXPORT_METHOD: ${RELEASE_EXPORT_METHOD}"
        log "RELEASE_MIN_PROFILE_DAYS: ${RELEASE_MIN_PROFILE_DAYS}"
    fi
}

# ---------------------------------------------------------------------------
# Build number validation
# ---------------------------------------------------------------------------
validate_build_number() {
    local build="$1"
    # Must be a non-empty integer
    if ! [[ "$build" =~ ^[0-9]+$ ]]; then
        die "Build number must be a positive integer, got: '$build'"
    fi
    if [ "$build" -lt 500 ]; then
        die "Build number must be >= 500, got: $build"
    fi

    # Must be strictly greater than the highest ledger entry
    if [ -f "$LEDGER_FILE" ]; then
        local highest=0
        while IFS= read -r line; do
            # Each line: build version commit date sha256
            local ledger_build
            ledger_build="$(echo "$line" | awk '{print $1}')"
            if [[ "$ledger_build" =~ ^[0-9]+$ ]] && [ "$ledger_build" -gt "$highest" ]; then
                highest="$ledger_build"
            fi
        done < "$LEDGER_FILE"
        if [ "$build" -le "$highest" ]; then
            die "Build number $build must be strictly greater than the highest ledger entry ($highest). Build numbers can never be reused."
        fi
    fi
}

# ---------------------------------------------------------------------------
# Build paths
# ---------------------------------------------------------------------------
build_dir() {
    local build="$1"
    echo "${RELEASE_BUILD_ROOT}/${build}"
}

archive_path() {
    local build="$1"
    echo "$(build_dir "$build")/ChristmasTracker.xcarchive"
}

ipa_name() {
    local version="$1"
    local build="$2"
    echo "ChristmasTracker-${version}-${build}.ipa"
}

ipa_path() {
    local version="$1"
    local build="$2"
    echo "$(build_dir "$build")/$(ipa_name "$version" "$build")"
}

export_options_path() {
    local build="$1"
    echo "$(build_dir "$build")/ExportOptions.plist"
}

manifest_path() {
    local build="$1"
    echo "$(build_dir "$build")/manifest.plist"
}

# ---------------------------------------------------------------------------
# Read build settings from the app target (read-only xcodebuild)
# ---------------------------------------------------------------------------
get_app_build_settings() {
    local raw
    raw="$("${RELEASE_XCODEBUILD}" -showBuildSettings \
        -project "${REPO_ROOT}/ChristmasTracker/ChristmasTracker.xcodeproj" \
        -scheme "ChristmasTracker" \
        -configuration "Release" 2>/dev/null)"
    local target_block
    target_block="$(printf '%s\n' "$raw" | awk '/Build settings for action .* target ChristmasTracker:$/{in_block=1;next} /Build settings for action /{in_block=0} in_block{print}')"
    if [ -n "$target_block" ]; then
        printf '%s\n' "$target_block"
    else
        printf '%s\n' "$raw"
    fi
}

get_product_name() {
    get_app_build_settings | grep "PRODUCT_NAME" | head -1 | sed 's/.*= *//' | tr -d '[:space:]'
}

get_marketing_version() {
    get_app_build_settings | grep "MARKETING_VERSION" | head -1 | sed 's/.*= *//' | tr -d '[:space:]'
}

# ---------------------------------------------------------------------------
# Check project signing settings match release configuration
# ---------------------------------------------------------------------------
check_project_signing() {
    info "Checking project signing settings..."
    local settings
    settings="$(get_app_build_settings)"
    if [ -z "$settings" ]; then
        die "Cannot read build settings from Xcode project. Ensure xcodebuild is installed."
    fi

    local fail=0
    local xcode_path="ChristmasTracker/ChristmasTracker.xcodeproj — ChristmasTracker target, Signing and Capabilities, Release"
    local code_sign_style dev_team prov_profile code_sign_id bundle_id

    code_sign_style="$(printf '%s\n' "$settings" | grep "CODE_SIGN_STYLE" | head -1 | sed 's/.*= *//' | tr -d '[:space:]')"
    dev_team="$(printf '%s\n' "$settings" | grep "DEVELOPMENT_TEAM" | head -1 | sed 's/.*= *//' | tr -d '[:space:]')"
    prov_profile="$(printf '%s\n' "$settings" | grep "PROVISIONING_PROFILE_SPECIFIER" | head -1 | sed 's/.*= *//' | tr -d '[:space:]')"
    code_sign_id="$(printf '%s\n' "$settings" | grep "CODE_SIGN_IDENTITY" | head -1 | sed 's/.*= *//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
    bundle_id="$(printf '%s\n' "$settings" | grep "PRODUCT_BUNDLE_IDENTIFIER" | head -1 | sed 's/.*= *//' | tr -d '[:space:]')"

    if [ "$code_sign_style" != "Manual" ]; then
        echo "[release] ERROR: CODE_SIGN_STYLE is wrong (got: '${code_sign_style}'). Fix in Xcode: ${xcode_path}: turn off Automatically manage signing." >&2; fail=1
    fi
    if [ "$dev_team" != "${RELEASE_TEAM_ID}" ]; then
        echo "[release] ERROR: DEVELOPMENT_TEAM does not match RELEASE_TEAM_ID [set]. Fix in Xcode: ${xcode_path}: choose the correct team." >&2; fail=1
    fi
    if [ "$prov_profile" != "${RELEASE_PROFILE_NAME}" ]; then
        echo "[release] ERROR: PROVISIONING_PROFILE_SPECIFIER does not match RELEASE_PROFILE_NAME [set]. Fix in Xcode: ${xcode_path}: select the ad hoc profile." >&2; fail=1
    fi
    if [[ "$code_sign_id" != Apple\ Distribution* ]] && [[ "$code_sign_id" != iPhone\ Distribution* ]]; then
        echo "[release] ERROR: CODE_SIGN_IDENTITY is wrong (got: '${code_sign_id}'). Fix in Xcode: ${xcode_path}: set identity to 'Apple Distribution' or 'iPhone Distribution'." >&2; fail=1
    fi
    if [ "$bundle_id" != "${RELEASE_BUNDLE_ID}" ]; then
        echo "[release] ERROR: PRODUCT_BUNDLE_IDENTIFIER is wrong (got: '${bundle_id}'). Fix in Xcode: ${xcode_path}: set bundle ID to match RELEASE_BUNDLE_ID." >&2; fail=1
    fi

    [ "$fail" -eq 1 ] && die "Project signing settings do not match release configuration. Fix the above settings in Xcode and re-run preflight."
    info "Project signing settings OK."
}

# ---------------------------------------------------------------------------
# S3 object URLs
# ---------------------------------------------------------------------------
s3_key() {
    local build="$1"
    local filename="$2"
    echo "${RELEASE_S3_PREFIX}/${build}/${filename}"
}

public_url() {
    local build="$1"
    local filename="$2"
    local base="${RELEASE_PUBLIC_BASE_URL%/}"
    echo "${base}/${RELEASE_S3_PREFIX}/${build}/${filename}"
}

# ---------------------------------------------------------------------------
# SUBCOMMAND: preflight
# ---------------------------------------------------------------------------
cmd_preflight() {
    load_env
    validate_env

    local fail=0

    # 1. Required tools
    info "Checking required tools..."
    for tool in xcodebuild plutil codesign security aws unzip shasum git; do
        local override_var
        override_var="RELEASE_$(echo "$tool" | tr '[:lower:]' '[:upper:]')"
        local tool_path="${!override_var:-$tool}"
        if ! command -v "$tool_path" > /dev/null 2>&1; then
            echo "[release] ERROR: required tool not found: $tool (resolved: $tool_path)" >&2
            fail=1
        fi
    done
    [ "$fail" -eq 0 ] || die "Required tools missing; install them and retry."
    info "All required tools found."

    # 2. Git: clean working tree
    info "Checking git state..."
    local git_status
    git_status="$("${RELEASE_GIT}" -C "${REPO_ROOT}" status --porcelain 2>&1)"
    if [ -n "$git_status" ]; then
        die "Working tree is not clean. Commit or stash changes before releasing."
    fi

    # 3. Git: branch check
    local current_branch
    current_branch="$("${RELEASE_GIT}" -C "${REPO_ROOT}" branch --show-current)"
    local required_branch="${ALLOW_BRANCH:-master}"
    if [ "$current_branch" != "$required_branch" ]; then
        die "Must be on branch '$required_branch' to release (current: '$current_branch'). Use --allow-branch NAME to override."
    fi
    info "Branch: $current_branch"

    # 4. Git: HEAD matches origin unless --allow-unpushed
    if [ "$ALLOW_UNPUSHED" -eq 0 ]; then
        if "${RELEASE_GIT}" -C "${REPO_ROOT}" rev-parse --verify "origin/${required_branch}" > /dev/null 2>&1; then
            local local_sha remote_sha
            local_sha="$("${RELEASE_GIT}" -C "${REPO_ROOT}" rev-parse HEAD)"
            remote_sha="$("${RELEASE_GIT}" -C "${REPO_ROOT}" rev-parse "origin/${required_branch}")"
            if [ "$local_sha" != "$remote_sha" ]; then
                die "HEAD ($local_sha) does not match origin/${required_branch} ($remote_sha). Push first, or use --allow-unpushed."
            fi
        else
            warn "Cannot verify origin/${required_branch}; remote not found."
        fi
    fi

    # 5. Project signing settings check
    check_project_signing

    # 6. Provisioning profile check
    info "Checking provisioning profile: ${RELEASE_PROFILE_NAME}..."
    local profile_path=""
    local profile_dir="${HOME}/Library/MobileDevice/Provisioning Profiles"
    if [ -d "$profile_dir" ]; then
        while IFS= read -r -d '' f; do
            local decoded
            decoded="$("${RELEASE_SECURITY}" cms -D -i "$f" 2>/dev/null)" || continue
            local name
            name="$(echo "$decoded" | "${RELEASE_PLUTIL}" -extract Name raw - 2>/dev/null)" || continue
            if [ "$name" = "${RELEASE_PROFILE_NAME}" ]; then
                profile_path="$f"
                break
            fi
        done < <(find "$profile_dir" -name "*.mobileprovision" -print0 2>/dev/null)
    fi
    if [ -z "$profile_path" ]; then
        die "Provisioning profile '${RELEASE_PROFILE_NAME}' not found in ~/Library/MobileDevice/Provisioning Profiles"
    fi
    info "Profile found: $profile_path"

    # Decode and validate profile
    local decoded
    decoded="$("${RELEASE_SECURITY}" cms -D -i "$profile_path" 2>/dev/null)"

    # Must have ProvisionedDevices (ad hoc indicator)
    if ! echo "$decoded" | "${RELEASE_PLUTIL}" -extract ProvisionedDevices raw - > /dev/null 2>&1; then
        die "Profile '${RELEASE_PROFILE_NAME}' is not an ad hoc profile (no ProvisionedDevices key)"
    fi

    # get-task-allow must be false
    local get_task_allow
    get_task_allow="$(echo "$decoded" | "${RELEASE_PLUTIL}" -extract Entitlements.get-task-allow raw - 2>/dev/null)" || get_task_allow="false"
    if [ "$get_task_allow" = "true" ] || [ "$get_task_allow" = "1" ]; then
        die "Profile has get-task-allow=true; this is a development profile, not an ad hoc distribution profile."
    fi

    # Bundle ID check
    local profile_app_id
    profile_app_id="$(echo "$decoded" | "${RELEASE_PLUTIL}" -extract Entitlements.application-identifier raw - 2>/dev/null)" || profile_app_id=""
    if ! echo "$profile_app_id" | grep -q "${RELEASE_BUNDLE_ID}$"; then
        die "Profile bundle ID mismatch: profile has '$profile_app_id', expected '${RELEASE_BUNDLE_ID}'"
    fi

    # Team ID check
    local profile_team
    profile_team="$(echo "$decoded" | "${RELEASE_PLUTIL}" -extract TeamIdentifier.0 raw - 2>/dev/null)" || profile_team=""
    if [ "$profile_team" != "${RELEASE_TEAM_ID}" ]; then
        die "Profile team mismatch: profile has '$profile_team', expected RELEASE_TEAM_ID [set]"
    fi

    # Expiry check
    local expiry_str
    expiry_str="$(echo "$decoded" | "${RELEASE_PLUTIL}" -extract ExpirationDate raw - 2>/dev/null)" || expiry_str=""
    if [ -n "$expiry_str" ]; then
        # Convert ISO 8601 date to epoch; macOS date vs GNU date
        local expiry_epoch
        expiry_epoch="$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${expiry_str}" "+%s" 2>/dev/null || date -d "${expiry_str}" "+%s" 2>/dev/null || echo 0)"
        local now_epoch
        now_epoch="$(date +%s)"
        local days_remaining
        days_remaining=$(( (expiry_epoch - now_epoch) / 86400 ))
        if [ "$days_remaining" -lt 0 ]; then
            die "Provisioning profile has EXPIRED (${expiry_str})."
        fi
        if [ "$days_remaining" -lt "${RELEASE_MIN_PROFILE_DAYS}" ]; then
            die "Provisioning profile expires in ${days_remaining} day(s), which is below the minimum of ${RELEASE_MIN_PROFILE_DAYS}. Renew the profile."
        fi
        info "Profile expires: ${expiry_str} (${days_remaining} days remaining)"
    fi

    # Device count
    local device_count
    device_count="$(printf '%s\n' "$decoded" | "${RELEASE_PLUTIL}" -extract ProvisionedDevices raw - 2>/dev/null)" || device_count=""
    if [ -z "$device_count" ] || ! [[ "$device_count" =~ ^[0-9]+$ ]]; then
        device_count="unknown"
    fi
    info "Profile registered devices: ${device_count}"
    if [ "$device_count" = "0" ]; then
        die "Profile has no registered devices. Add devices to the profile before releasing."
    fi

    # 7. Signing identity check (read-only: security find-identity)
    info "Checking signing identity..."
    local identity_line
    identity_line="$("${RELEASE_SECURITY}" find-identity -v -p codesigning 2>/dev/null | grep "Apple Distribution" | grep "${RELEASE_TEAM_ID}" | head -1)" || identity_line=""
    if [ -z "$identity_line" ]; then
        die "No Apple Distribution identity for team [set] found in keychain. Install the certificate and private key."
    fi
    # Print identity description without the hash (which could be sensitive metadata)
    local identity_name
    # Strip leading hash/number and trailing newline; extract quoted name
    identity_name="${identity_line#*\"}"
    identity_name="${identity_name%\"*}"
    info "Signing identity: $identity_name"

    # 8. scripts/verify.sh (skippable with --skip-verify)
    if [ "$SKIP_VERIFY" -eq 1 ]; then
        warn "--skip-verify was passed; skipping scripts/verify.sh. This is UNSAFE for a production release."
    else
        info "Running scripts/verify.sh..."
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[dry-run] preflight: would run: scripts/verify.sh"
        else
            "${SCRIPT_DIR}/verify.sh" || die "scripts/verify.sh failed. Fix all issues before releasing."
        fi
    fi

    info "preflight: all checks passed."
}

# ---------------------------------------------------------------------------
# SUBCOMMAND: archive
# ---------------------------------------------------------------------------
cmd_archive() {
    require_build_number "$BUILD_NUMBER"
    load_env
    validate_env
    validate_build_number "$BUILD_NUMBER"

    local marketing_version
    marketing_version="$(get_marketing_version)"
    local bdir
    bdir="$(build_dir "$BUILD_NUMBER")"
    local arch
    arch="$(archive_path "$BUILD_NUMBER")"

    info "archive: build=${BUILD_NUMBER} version=${marketing_version}"
    info "archive: output: ${arch}"

    local signing_args=()
    if [ "${RELEASE_ARCHIVE_SIGNING}" = "cli" ]; then
        signing_args=(
            "CODE_SIGN_STYLE=Manual"
            "DEVELOPMENT_TEAM=${RELEASE_TEAM_ID}"
            "PROVISIONING_PROFILE_SPECIFIER=${RELEASE_PROFILE_NAME}"
        )
    fi

    dry_run_cmd "archive" \
        "${RELEASE_XCODEBUILD}" archive \
        -project "${REPO_ROOT}/ChristmasTracker/ChristmasTracker.xcodeproj" \
        -scheme "ChristmasTracker" \
        -configuration "Release" \
        -destination "generic/platform=iOS" \
        -archivePath "${arch}" \
        -derivedDataPath "${bdir}/derived" \
        ${signing_args[@]+"${signing_args[@]}"} \
        CURRENT_PROJECT_VERSION="${BUILD_NUMBER}"

    if [ "$DRY_RUN" -eq 0 ]; then
        [ -d "$arch" ] || die "archive step did not produce an xcarchive at: $arch"
        info "archive: succeeded — ${arch}"
    fi
}

# ---------------------------------------------------------------------------
# SUBCOMMAND: export
# ---------------------------------------------------------------------------
cmd_export() {
    require_build_number "$BUILD_NUMBER"
    load_env
    validate_env
    validate_build_number "$BUILD_NUMBER"

    local marketing_version
    marketing_version="$(get_marketing_version)"
    local bdir
    bdir="$(build_dir "$BUILD_NUMBER")"
    local arch
    arch="$(archive_path "$BUILD_NUMBER")"
    local export_opts
    export_opts="$(export_options_path "$BUILD_NUMBER")"
    local iname
    iname="$(ipa_name "$marketing_version" "$BUILD_NUMBER")"
    local ipath
    ipath="$(ipa_path "$marketing_version" "$BUILD_NUMBER")"

    if [ "$DRY_RUN" -eq 0 ] && [ ! -d "$arch" ]; then
        die "xcarchive not found at $arch — run archive first"
    fi

    info "export: generating ExportOptions.plist at ${export_opts}"
    if [ "$DRY_RUN" -eq 1 ]; then
        cat <<EOF
[dry-run] export: would write ExportOptions.plist:
  method: ${RELEASE_EXPORT_METHOD}
  signingStyle: manual
  teamID: [set]
  provisioningProfiles: { ${RELEASE_BUNDLE_ID}: [profile name set] }
  stripSwiftSymbols: true
  uploadSymbols: false
  compileBitcode: false
EOF
    else
        mkdir -p "$bdir"
        # Write the plist as XML directly — plutil -insert uses dots as keypath separators,
        # which would break the bundle ID key (com.alberta.ChristmasTracker) if used for the
        # nested provisioningProfiles entry.
        cat > "${export_opts}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>${RELEASE_EXPORT_METHOD}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>teamID</key>
    <string>${RELEASE_TEAM_ID}</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>${RELEASE_BUNDLE_ID}</key>
        <string>${RELEASE_PROFILE_NAME}</string>
    </dict>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadSymbols</key>
    <false/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
PLIST
        "${RELEASE_PLUTIL}" -lint "${export_opts}" || die "ExportOptions.plist failed plutil -lint"
    fi

    info "export: running xcodebuild -exportArchive to produce ${iname}"
    dry_run_cmd "export" \
        "${RELEASE_XCODEBUILD}" -exportArchive \
        -archivePath "${arch}" \
        -exportPath "${bdir}" \
        -exportOptionsPlist "${export_opts}"

    if [ "$DRY_RUN" -eq 0 ]; then
        # xcodebuild places the IPA directly in the export path
        local product_name
        product_name="$(get_product_name)" || product_name=""
        local xc_ipa
        if [ -n "$product_name" ]; then
            xc_ipa="${bdir}/${product_name}.ipa"
        else
            xc_ipa="${bdir}/ChristmasTracker.ipa"
        fi
        if [ -f "$xc_ipa" ]; then
            mv "$xc_ipa" "$ipath"
        fi
        [ -f "$ipath" ] || die "export did not produce an IPA at $ipath"
        info "export: succeeded — ${ipath}"
    fi
}

# ---------------------------------------------------------------------------
# SUBCOMMAND: verify-ipa
# ---------------------------------------------------------------------------
cmd_verify_ipa() {
    load_env
    validate_env

    local ipath="$IPA_PATH"
    if [ -z "$ipath" ]; then
        require_build_number "$BUILD_NUMBER"
        validate_build_number "$BUILD_NUMBER"
        local marketing_version
        marketing_version="$(get_marketing_version)"
        ipath="$(ipa_path "$marketing_version" "$BUILD_NUMBER")"
    fi

    if [ "$DRY_RUN" -eq 0 ] && [ ! -f "$ipath" ]; then
        die "IPA not found at: $ipath"
    fi

    if [ "$DRY_RUN" -eq 1 ] && [ ! -f "$ipath" ]; then
        echo "[dry-run] verify-ipa: would verify IPA at: $ipath"
        echo "[dry-run] verify-ipa: assertions: bundle-id, build, version, API_BASE_URL, API_MODE,"
        echo "[dry-run] verify-ipa:   APP_ENVIRONMENT, ATS, FaceID usage, embedded profile ad hoc,"
        echo "[dry-run] verify-ipa:   expiry, get-task-allow false, codesign, team, debug entitlement, xcconfig leak"
        return 0
    fi

    info "verify-ipa: ${ipath}"

    local tmpdir
    tmpdir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '${tmpdir}'" EXIT

    local fail=0

    # Extract Info.plist and embedded.mobileprovision from IPA
    local product_name
    product_name="$(get_product_name)" || product_name=""
    local app_bundle_name
    if [ -n "$product_name" ]; then
        app_bundle_name="${product_name}.app"
    else
        local app_count
        app_count="$("${RELEASE_UNZIP}" -Z -1 "$ipath" 2>/dev/null | grep -cE "^Payload/[^/]+\.app/$")" || app_count="0"
        if [ "$app_count" -eq 1 ]; then
            local app_entry
            app_entry="$("${RELEASE_UNZIP}" -Z -1 "$ipath" 2>/dev/null | grep -E "^Payload/[^/]+\.app/$" | head -1)"
            app_bundle_name="${app_entry#Payload/}"
            app_bundle_name="${app_bundle_name%/}"
        else
            die "verify-ipa: cannot determine app bundle name (PRODUCT_NAME unreadable, found ${app_count} .app bundles in Payload/)"
        fi
    fi
    local payload_prefix="Payload/${app_bundle_name}"
    "${RELEASE_UNZIP}" -p "$ipath" "${payload_prefix}/Info.plist" > "${tmpdir}/Info.plist" 2>/dev/null \
        || die "Could not extract Info.plist from IPA — is this a valid IPA?"

    # CFBundleIdentifier
    local actual_bundle_id
    actual_bundle_id="$("${RELEASE_PLUTIL}" -extract CFBundleIdentifier raw "${tmpdir}/Info.plist" 2>/dev/null)" || actual_bundle_id=""
    if [ "$actual_bundle_id" != "${RELEASE_BUNDLE_ID}" ]; then
        echo "[verify-ipa] FAIL CFBundleIdentifier: expected '${RELEASE_BUNDLE_ID}', got '${actual_bundle_id}'" >&2
        fail=1
    else
        info "verify-ipa: CFBundleIdentifier OK: ${actual_bundle_id}"
    fi

    # CFBundleVersion (build number)
    if [ -n "$BUILD_NUMBER" ]; then
        local actual_build
        actual_build="$("${RELEASE_PLUTIL}" -extract CFBundleVersion raw "${tmpdir}/Info.plist" 2>/dev/null)" || actual_build=""
        if [ "$actual_build" != "${BUILD_NUMBER}" ]; then
            echo "[verify-ipa] FAIL CFBundleVersion: expected '${BUILD_NUMBER}', got '${actual_build}'" >&2
            fail=1
        else
            info "verify-ipa: CFBundleVersion OK: ${actual_build}"
        fi
    fi

    # CFBundleShortVersionString (marketing version)
    local expected_version
    expected_version="$(get_marketing_version)"
    local actual_version
    actual_version="$("${RELEASE_PLUTIL}" -extract CFBundleShortVersionString raw "${tmpdir}/Info.plist" 2>/dev/null)" || actual_version=""
    if [ "$actual_version" != "$expected_version" ]; then
        echo "[verify-ipa] FAIL CFBundleShortVersionString: expected '${expected_version}', got '${actual_version}'" >&2
        fail=1
    else
        info "verify-ipa: CFBundleShortVersionString OK: ${actual_version}"
    fi

    # API_BASE_URL
    local actual_api_base_url
    actual_api_base_url="$("${RELEASE_PLUTIL}" -extract API_BASE_URL raw "${tmpdir}/Info.plist" 2>/dev/null)" || actual_api_base_url=""
    if [ "$actual_api_base_url" != "https://api.bmalberta.com" ]; then
        echo "[verify-ipa] FAIL API_BASE_URL: expected 'https://api.bmalberta.com', got '${actual_api_base_url}'" >&2
        fail=1
    else
        info "verify-ipa: API_BASE_URL OK"
    fi

    # API_MODE
    local actual_api_mode
    actual_api_mode="$("${RELEASE_PLUTIL}" -extract API_MODE raw "${tmpdir}/Info.plist" 2>/dev/null)" || actual_api_mode=""
    if [ "$actual_api_mode" != "real" ]; then
        echo "[verify-ipa] FAIL API_MODE: expected 'real', got '${actual_api_mode}'" >&2
        fail=1
    else
        info "verify-ipa: API_MODE OK"
    fi

    # APP_ENVIRONMENT
    local actual_app_env
    actual_app_env="$("${RELEASE_PLUTIL}" -extract APP_ENVIRONMENT raw "${tmpdir}/Info.plist" 2>/dev/null)" || actual_app_env=""
    if [ "$actual_app_env" != "production" ]; then
        echo "[verify-ipa] FAIL APP_ENVIRONMENT: expected 'production', got '${actual_app_env}'" >&2
        fail=1
    else
        info "verify-ipa: APP_ENVIRONMENT OK"
    fi

    # NSAppTransportSecurity: NSAllowsArbitraryLoads and variants must NOT be true
    local ats_check_failed=0
    for ats_key in NSAllowsArbitraryLoads NSAllowsArbitraryLoadsInWebContent NSAllowsArbitraryLoadsForMedia; do
        local ats_val
        ats_val="$("${RELEASE_PLUTIL}" -extract "NSAppTransportSecurity.${ats_key}" raw "${tmpdir}/Info.plist" 2>/dev/null)" || ats_val="false"
        if [ "$ats_val" = "true" ] || [ "$ats_val" = "1" ]; then
            echo "[verify-ipa] FAIL ATS: NSAppTransportSecurity.${ats_key} is true — arbitrary loads must not be allowed" >&2
            ats_check_failed=1
        fi
    done
    if [ "$ats_check_failed" -eq 0 ]; then
        info "verify-ipa: NSAppTransportSecurity OK (no arbitrary loads)"
    else
        fail=1
    fi

    # NSFaceIDUsageDescription must be present
    local faceid_desc
    faceid_desc="$("${RELEASE_PLUTIL}" -extract NSFaceIDUsageDescription raw "${tmpdir}/Info.plist" 2>/dev/null)" || faceid_desc=""
    if [ -z "$faceid_desc" ]; then
        echo "[verify-ipa] FAIL NSFaceIDUsageDescription: key is missing from Info.plist" >&2
        fail=1
    else
        info "verify-ipa: NSFaceIDUsageDescription present"
    fi

    # SENTRY_DSN: must be present and non-empty
    local sentry_dsn_val
    sentry_dsn_val="$("${RELEASE_PLUTIL}" -extract SENTRY_DSN raw "${tmpdir}/Info.plist" 2>/dev/null)" || sentry_dsn_val=""
    if [ -z "$sentry_dsn_val" ]; then
        echo "[verify-ipa] FAIL SENTRY_DSN: key is missing or value is empty — production builds must include the DSN; ensure Config-Secrets.xcconfig is present on the release machine" >&2
        fail=1
    else
        info "verify-ipa: SENTRY_DSN present (value not printed)"
    fi

    # embedded.mobileprovision
    "${RELEASE_UNZIP}" -p "$ipath" "${payload_prefix}/embedded.mobileprovision" > "${tmpdir}/embedded.mobileprovision" 2>/dev/null \
        || die "Could not extract embedded.mobileprovision from IPA"

    local emb_decoded
    emb_decoded="$("${RELEASE_SECURITY}" cms -D -i "${tmpdir}/embedded.mobileprovision" 2>/dev/null)"

    # Ad hoc: must have ProvisionedDevices
    if ! echo "$emb_decoded" | "${RELEASE_PLUTIL}" -extract ProvisionedDevices raw - > /dev/null 2>&1; then
        echo "[verify-ipa] FAIL embedded profile: not an ad hoc profile (no ProvisionedDevices key)" >&2
        fail=1
    else
        info "verify-ipa: embedded profile is ad hoc (ProvisionedDevices present)"
    fi

    # get-task-allow must be false
    local emb_gta
    emb_gta="$(echo "$emb_decoded" | "${RELEASE_PLUTIL}" -extract Entitlements.get-task-allow raw - 2>/dev/null)" || emb_gta="false"
    if [ "$emb_gta" = "true" ] || [ "$emb_gta" = "1" ]; then
        echo "[verify-ipa] FAIL embedded profile get-task-allow is true — this is not a distribution build" >&2
        fail=1
    else
        info "verify-ipa: embedded profile get-task-allow false OK"
    fi

    # Expiry
    local emb_expiry
    emb_expiry="$(echo "$emb_decoded" | "${RELEASE_PLUTIL}" -extract ExpirationDate raw - 2>/dev/null)" || emb_expiry=""
    if [ -n "$emb_expiry" ]; then
        local emb_epoch
        emb_epoch="$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${emb_expiry}" "+%s" 2>/dev/null || date -d "${emb_expiry}" "+%s" 2>/dev/null || echo 0)"
        local now_epoch
        now_epoch="$(date +%s)"
        if [ "$emb_epoch" -lt "$now_epoch" ]; then
            echo "[verify-ipa] FAIL embedded profile is EXPIRED (${emb_expiry})" >&2
            fail=1
        else
            info "verify-ipa: embedded profile not expired (${emb_expiry})"
        fi
    fi

    # codesign --verify --strict
    "${RELEASE_UNZIP}" -q "$ipath" -d "${tmpdir}/ipa_contents" 2>/dev/null
    local app_path="${tmpdir}/ipa_contents/${payload_prefix}"
    if [ -d "$app_path" ]; then
        if ! "${RELEASE_CODESIGN}" --verify --strict "$app_path" 2>/dev/null; then
            echo "[verify-ipa] FAIL codesign --verify --strict failed" >&2
            fail=1
        else
            info "verify-ipa: codesign --verify OK"
        fi

        # Signing team matches
        local sign_info
        sign_info="$("${RELEASE_CODESIGN}" -dvvv "$app_path" 2>&1)" || sign_info=""
        if ! echo "$sign_info" | grep -q "TeamIdentifier=${RELEASE_TEAM_ID}"; then
            echo "[verify-ipa] FAIL codesign TeamIdentifier does not match RELEASE_TEAM_ID [set]" >&2
            fail=1
        else
            info "verify-ipa: codesign TeamIdentifier OK"
        fi

        # Debug entitlement must not be present
        local ent_output
        ent_output="$("${RELEASE_CODESIGN}" -d --entitlements - "$app_path" 2>/dev/null)" || ent_output=""
        if echo "$ent_output" | grep -q "get-task-allow"; then
            if echo "$ent_output" | grep -A1 "get-task-allow" | grep -q "true"; then
                echo "[verify-ipa] FAIL app binary contains get-task-allow=true entitlement" >&2
                fail=1
            else
                info "verify-ipa: app binary get-task-allow entitlement absent or false OK"
            fi
        else
            info "verify-ipa: no get-task-allow entitlement in app binary OK"
        fi

        # xcconfig leak check
        local xcconfig_found=0
        while IFS= read -r -d '' xcf; do
            warn "xcconfig file found in bundle: $xcf"
            xcconfig_found=1
        done < <(find "${tmpdir}/ipa_contents" -name "*.xcconfig" -print0 2>/dev/null)
        if [ "$xcconfig_found" -eq 0 ]; then
            info "verify-ipa: no .xcconfig files found in bundle OK"
        else
            info "verify-ipa: .xcconfig files found (warning only, not a failure)"
        fi
    else
        warn "Could not find app bundle for codesign verification at $app_path"
    fi

    if [ "$fail" -eq 0 ]; then
        info "verify-ipa: all assertions passed."
    else
        die "verify-ipa: one or more assertions FAILED. See errors above."
    fi
}

# ---------------------------------------------------------------------------
# SUBCOMMAND: manifest
# ---------------------------------------------------------------------------
cmd_manifest() {
    require_build_number "$BUILD_NUMBER"
    load_env
    validate_env
    validate_build_number "$BUILD_NUMBER"

    local marketing_version
    marketing_version="$(get_marketing_version)"
    local iname
    iname="$(ipa_name "$marketing_version" "$BUILD_NUMBER")"
    local ipa_public_url
    ipa_public_url="$(public_url "$BUILD_NUMBER" "$iname")"
    local manifest
    manifest="$(manifest_path "$BUILD_NUMBER")"
    local bdir
    bdir="$(build_dir "$BUILD_NUMBER")"

    # https enforcement
    if [[ "$ipa_public_url" != https://* ]]; then
        die "Manifest IPA URL must be https. Got: $ipa_public_url — check RELEASE_PUBLIC_BASE_URL."
    fi

    info "manifest: IPA URL = ${ipa_public_url}"
    info "manifest: writing ${manifest}"

    if [ "$DRY_RUN" -eq 1 ]; then
        cat <<EOF
[dry-run] manifest: would generate ${manifest}
  software-package url: ${ipa_public_url}
  bundle-identifier: ${RELEASE_BUNDLE_ID}
  bundle-version: ${marketing_version}
  title: Christmas Tracker
EOF
        return 0
    fi

    mkdir -p "$bdir"
    cat > "$manifest" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>items</key>
    <array>
        <dict>
            <key>assets</key>
            <array>
                <dict>
                    <key>kind</key>
                    <string>software-package</string>
                    <key>url</key>
                    <string>${ipa_public_url}</string>
                </dict>
            </array>
            <key>metadata</key>
            <dict>
                <key>bundle-identifier</key>
                <string>${RELEASE_BUNDLE_ID}</string>
                <key>bundle-version</key>
                <string>${marketing_version}</string>
                <key>kind</key>
                <string>software</string>
                <key>title</key>
                <string>Christmas Tracker</string>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOF

    # plutil -lint
    if ! "${RELEASE_PLUTIL}" -lint "$manifest" 2>&1; then
        die "manifest: plutil -lint FAILED on $manifest"
    fi
    info "manifest: plutil -lint OK"
    info "manifest: written to ${manifest}"
}

# ---------------------------------------------------------------------------
# SUBCOMMAND: upload
# ---------------------------------------------------------------------------
cmd_upload() {
    require_build_number "$BUILD_NUMBER"
    load_env
    validate_env
    validate_build_number "$BUILD_NUMBER"

    if [ "$DRY_RUN" -eq 0 ] && [ "$YES" -eq 0 ]; then
        die "upload requires --yes to confirm, or --dry-run to preview. This uploads to S3 and cannot be undone."
    fi

    local marketing_version
    marketing_version="$(get_marketing_version)"
    local iname
    iname="$(ipa_name "$marketing_version" "$BUILD_NUMBER")"
    local ipath
    ipath="$(ipa_path "$marketing_version" "$BUILD_NUMBER")"
    local manifest
    manifest="$(manifest_path "$BUILD_NUMBER")"
    local manifest_name="manifest.plist"

    local ipa_s3_key manifest_s3_key
    ipa_s3_key="$(s3_key "$BUILD_NUMBER" "$iname")"
    manifest_s3_key="$(s3_key "$BUILD_NUMBER" "$manifest_name")"

    local aws_profile_args=()
    if [ -n "${RELEASE_AWS_PROFILE:-}" ]; then
        aws_profile_args=("--profile" "${RELEASE_AWS_PROFILE}")
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        cat <<EOF
[dry-run] upload: would check s3://${RELEASE_S3_BUCKET}/${ipa_s3_key} does not exist
[dry-run] upload: would check s3://${RELEASE_S3_BUCKET}/${manifest_s3_key} does not exist
[dry-run] upload: would upload IPA:
  ${RELEASE_AWS} s3 cp [ipa_path] s3://[bucket]/${ipa_s3_key}
  --content-type application/octet-stream
  --cache-control "public, max-age=31536000, immutable"
[dry-run] upload: would upload manifest:
  ${RELEASE_AWS} s3 cp [manifest_path] s3://[bucket]/${manifest_s3_key}
  --content-type text/xml
  --cache-control "public, max-age=60"
[dry-run] upload: would re-verify both objects exist and print sizes
[dry-run] upload: would write ledger entry
EOF
        return 0
    fi

    if [ ! -f "$ipath" ]; then
        die "IPA not found at $ipath — run verify-ipa first"
    fi
    if [ ! -f "$manifest" ]; then
        die "manifest.plist not found at $manifest — run manifest first"
    fi

    # Refuse to overwrite existing objects
    info "upload: checking IPA does not already exist on S3..."
    if "${RELEASE_AWS}" s3 ls "s3://${RELEASE_S3_BUCKET}/${ipa_s3_key}" ${aws_profile_args[@]+"${aws_profile_args[@]}"} > /dev/null 2>&1; then
        die "Object already exists: s3://${RELEASE_S3_BUCKET}/${ipa_s3_key} — build numbers can never be reused."
    fi
    info "upload: checking manifest does not already exist on S3..."
    if "${RELEASE_AWS}" s3 ls "s3://${RELEASE_S3_BUCKET}/${manifest_s3_key}" ${aws_profile_args[@]+"${aws_profile_args[@]}"} > /dev/null 2>&1; then
        die "Object already exists: s3://${RELEASE_S3_BUCKET}/${manifest_s3_key} — build numbers can never be reused."
    fi

    # Upload IPA
    info "upload: uploading IPA..."
    "${RELEASE_AWS}" s3 cp "$ipath" "s3://${RELEASE_S3_BUCKET}/${ipa_s3_key}" \
        --content-type "application/octet-stream" \
        --cache-control "public, max-age=31536000, immutable" \
        ${aws_profile_args[@]+"${aws_profile_args[@]}"}

    # Upload manifest
    info "upload: uploading manifest..."
    "${RELEASE_AWS}" s3 cp "$manifest" "s3://${RELEASE_S3_BUCKET}/${manifest_s3_key}" \
        --content-type "text/xml" \
        --cache-control "public, max-age=60" \
        ${aws_profile_args[@]+"${aws_profile_args[@]}"}

    # Re-verify both exist
    info "upload: verifying objects exist on S3..."
    local ipa_ls manifest_ls
    ipa_ls="$("${RELEASE_AWS}" s3 ls "s3://${RELEASE_S3_BUCKET}/${ipa_s3_key}" ${aws_profile_args[@]+"${aws_profile_args[@]}"} 2>/dev/null)" || ipa_ls=""
    manifest_ls="$("${RELEASE_AWS}" s3 ls "s3://${RELEASE_S3_BUCKET}/${manifest_s3_key}" ${aws_profile_args[@]+"${aws_profile_args[@]}"} 2>/dev/null)" || manifest_ls=""
    if [ -z "$ipa_ls" ]; then
        die "Post-upload check: IPA not found on S3 at s3://${RELEASE_S3_BUCKET}/${ipa_s3_key}"
    fi
    if [ -z "$manifest_ls" ]; then
        die "Post-upload check: manifest not found on S3 at s3://${RELEASE_S3_BUCKET}/${manifest_s3_key}"
    fi
    info "upload: IPA on S3: $ipa_ls"
    info "upload: manifest on S3: $manifest_ls"

    # Write ledger entry (only after full success)
    local commit_sha
    commit_sha="$("${RELEASE_GIT}" -C "${REPO_ROOT}" rev-parse HEAD)"
    local ipa_sha256
    ipa_sha256="$("${RELEASE_SHASUM}" -a 256 "$ipath" | awk '{print $1}')"
    local today
    today="$(date -u +"%Y-%m-%d")"
    echo "${BUILD_NUMBER} ${marketing_version} ${commit_sha} ${today} ${ipa_sha256}" >> "$LEDGER_FILE"
    info "upload: ledger updated — ${LEDGER_FILE}"
    info "upload: complete."
}

# ---------------------------------------------------------------------------
# SUBCOMMAND: install-info
# ---------------------------------------------------------------------------
cmd_install_info() {
    load_env
    validate_env

    local build="${BUILD_NUMBER:-}"
    local marketing_version
    marketing_version="$(get_marketing_version)"

    local iname manifest_name="manifest.plist"
    if [ -n "$build" ]; then
        iname="$(ipa_name "$marketing_version" "$build")"
    else
        iname="ChristmasTracker-${marketing_version}-<build>.ipa"
        build="<build>"
    fi

    local manifest_public_url ipa_public_url
    manifest_public_url="$(public_url "$build" "$manifest_name")"
    ipa_public_url="$(public_url "$build" "$iname")"

    # https enforcement
    if [[ "$manifest_public_url" != https://* ]]; then
        die "install-info: manifest URL must be https. Got: $manifest_public_url — check RELEASE_PUBLIC_BASE_URL."
    fi

    local install_link="itms-services://?action=download-manifest&url=${manifest_public_url}"

    cat <<EOF

=== Christmas Tracker — Install Info (build: ${build}) ===

1. Install link (itms-services):
   ${install_link}

2. URLs:
   Manifest: ${manifest_public_url}
   IPA:      ${ipa_public_url}

3. Values for policy:set (run on the API server after upload):
   platform:          ios
   --latest-build:    ${build}
   --latest-version:  ${marketing_version}
   --recommended-version: ${marketing_version}
   --manifest-url:    ${manifest_public_url}
   --ipa-url:         ${ipa_public_url}
   --min-build:       (choose: raising this forces an update on older builds; see runbook)

   Pass these to policy:set; the exact flag names are in the API chat's local quickstart (unconfirmed here).

4. Device verification steps:
   a. Tap the install link on a registered device (must be in the provisioning profile).
   b. In Settings → General → VPN & Device Management, verify the app shows version ${marketing_version} (${build}).
   c. Launch the app and confirm it logs in against production (https://api.bmalberta.com).
   d. Check Sentry for a session event with the correct build number.

EOF
}

# ---------------------------------------------------------------------------
# SUBCOMMAND: all
# ---------------------------------------------------------------------------
cmd_all() {
    require_build_number "$BUILD_NUMBER"
    info "all: running preflight, archive, export, verify-ipa, manifest, upload, install-info"
    info "all: build=${BUILD_NUMBER}"

    cmd_preflight
    cmd_archive
    cmd_export

    # For verify-ipa, derive IPA path
    load_env
    local marketing_version
    marketing_version="$(get_marketing_version)"
    IPA_PATH="$(ipa_path "$marketing_version" "$BUILD_NUMBER")"
    cmd_verify_ipa

    cmd_manifest
    cmd_upload
    cmd_install_info

    info "all: complete."
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
case "$SUBCOMMAND" in
    preflight)    cmd_preflight;;
    archive)      cmd_archive;;
    export)       cmd_export;;
    verify-ipa)   cmd_verify_ipa;;
    manifest)     cmd_manifest;;
    upload)       cmd_upload;;
    install-info) cmd_install_info;;
    all)          cmd_all;;
    help|--help|-h) usage;;
    *) echo "error: unknown subcommand: $SUBCOMMAND" >&2; usage;;
esac
