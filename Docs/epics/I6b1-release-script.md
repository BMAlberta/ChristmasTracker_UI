# I6b-1: The release script

Track: iOS. Depends on: nothing in the contract. Blocks: the first on-device build (about Nov 20 target; hard date Nov 25: the 4.4 provisioning profile expires and every 4.4 install stops launching).
Why: v2 is distributed ad hoc (no TestFlight, no App Store): an IPA signed with an Apple Distribution certificate and an ad hoc provisioning profile, plus a manifest.plist, hosted over HTTPS on S3 at content.bmalberta.com/distribution/tracker/<build>/. Brian runs the release; agents write the script and never run it.

Facts: bundle id com.alberta.ChristmasTracker (v2 replaces 4.4 in place); marketing version 5.0; builds start at 500 and increase; manual signing; the export method is release-testing (Xcode's ad hoc export); the Release configuration points the app at https://api.bmalberta.com with API_MODE real and APP_ENVIRONMENT production; the version policy API (public GET /app/version-check) carries manifestUrl and ipaUrl, set with the backend's policy:set command by Brian; install links use itms-services://?action=download-manifest&url=<https manifest url>.

Scope: scripts/release.sh with subcommands preflight, archive, export, verify-ipa, manifest, upload, install-info, and all; --dry-run everywhere; scripts/release.env.example and an untracked scripts/release.env; scripts/test-release.sh (stubs and fixtures only) run from scripts/verify.sh; Docs/release-runbook.md.

Decisions
- Inputs come from scripts/release.env (untracked, in .gitignore): RELEASE_TEAM_ID, RELEASE_PROFILE_NAME (the ad hoc provisioning profile's name), RELEASE_BUNDLE_ID (default com.alberta.ChristmasTracker), RELEASE_S3_BUCKET, RELEASE_S3_PREFIX (default distribution/tracker), RELEASE_PUBLIC_BASE_URL (default https://content.bmalberta.com), RELEASE_AWS_PROFILE (optional), RELEASE_EXPORT_METHOD (default release-testing), RELEASE_MIN_PROFILE_DAYS (default 14). The script fails with a clear message for any missing required value and never prints secret values.
- The build number is an argument (--build N): an integer greater than or equal to 500 that is strictly greater than the highest build already recorded in a local ledger file (scripts/.release-ledger, untracked, one line per release: build, version, commit, date, ipa sha256); it is passed to xcodebuild as CURRENT_PROJECT_VERSION on the command line, not by editing the project.
- preflight checks: git status clean, current branch is master (or --allow-branch NAME), HEAD equals origin/master unless --allow-unpushed, required tools exist (xcodebuild, plutil, codesign, security, aws, unzip, shasum, git), the env values, the profile (found in ~/Library/MobileDevice/Provisioning Profiles by name, decoded with security cms -D: type is ad hoc (has ProvisionedDevices, get-task-allow false), the bundle id matches, the team id matches, it expires at least RELEASE_MIN_PROFILE_DAYS days from now, and print the registered device count), the signing identity (an Apple Distribution identity for the team exists in the keychain via security find-identity, name printed, no secrets), and scripts/verify.sh passes (skippable only with --skip-verify, which the report must flag as unsafe).
- archive: xcodebuild archive with the ChristmasTracker scheme, Release configuration, generic iOS destination, manual signing with the team and profile, CURRENT_PROJECT_VERSION=<build>, into a build directory outside the repo's tracked files (build/release/<build>/, gitignored).
- export: generate ExportOptions.plist (method from env, signingStyle manual, teamID, provisioningProfiles mapping the bundle id to the profile name, stripSwiftSymbols true, uploadSymbols false, compileBitcode false) into the build directory, run xcodebuild -exportArchive, and produce ChristmasTracker-<version>-<build>.ipa.
- verify-ipa (the most important check; it must work on any IPA path): unzip the Info.plist and embedded.mobileprovision from the IPA and assert: CFBundleIdentifier equals RELEASE_BUNDLE_ID; CFBundleVersion equals the requested build; CFBundleShortVersionString is the expected marketing version (read from the project with xcodebuild -showBuildSettings); API_BASE_URL equals exactly https://api.bmalberta.com; API_MODE equals real; APP_ENVIRONMENT equals production; NSAppTransportSecurity contains no NSAllowsArbitraryLoads and none of its arbitrary-load variants true; the NSFaceIDUsageDescription key is present; the embedded profile is ad hoc, not expired, and lists get-task-allow false; codesign --verify --strict passes and the signing team id matches; the app binary contains no debug entitlement; and the bundle does not contain Config-Secrets.xcconfig or any file whose name ends in .xcconfig with a secret-looking value (if the three Config*.xcconfig files ship, warn but do not fail, and list them). A SENTRY_DSN value is checked for presence only and NEVER printed.
- manifest: generate manifest.plist (Apple's items/assets/software-package structure; bundle-identifier, bundle-version equal to the marketing version, kind software, title Christmas Tracker) whose software-package URL is <public base>/<prefix>/<build>/ChristmasTracker-<version>-<build>.ipa; every URL must be https (an http URL is a hard error); plutil -lint must pass.
- upload: refuses without --yes unless --dry-run; checks with aws s3 ls that neither object exists (never overwrites an existing build; a mismatch is an error, not a prompt); uploads the IPA (content type application/octet-stream, cache-control public max-age=31536000 immutable) then the manifest (content type text/xml, cache-control public max-age=60), then re-checks both exist and prints their sizes; never deletes anything; uses RELEASE_AWS_PROFILE when set.
- install-info: prints (1) the itms-services install link, (2) the https manifest URL and ipa URL, (3) a block labelled "values for policy:set" listing platform ios, minimum build and latest build candidates (latest = this build; minimum is left for Brian to choose and the runbook explains why raising it forces an update), the latest and recommended version, the manifest URL, and the ipa URL, and (4) a reminder of the verification steps. It never runs policy:set.
- The ledger line is written only after a fully successful upload.
- Every subcommand supports --dry-run (prints exactly what it would run, with no side effects and no secret values) and exits non-zero with a clear message on any failure. Tool paths can be overridden with environment variables (for example RELEASE_XCODEBUILD, RELEASE_AWS, RELEASE_SECURITY, RELEASE_CODESIGN) so the tests can substitute stubs.
- Docs/release-runbook.md: prerequisites (Apple Distribution certificate and private key in the login keychain, the ad hoc profile installed with every family device registered, how to fill scripts/release.env, aws configure for the bucket's upload-only key, installing the itms-services link on a device), the step-by-step release procedure, what to check on a device (installs over 4.4, version in Profile, a login against production), how to roll back (point the version policy at the previous build's manifest and IPA URLs; never delete an uploaded build), the Nov 25 deadline and the 4.4 coexistence notes, and the exact commands.

Non-goals: running any signing, export, or upload; changing the app, project file, or xcconfig; the version manager screen; TestFlight or App Store; automating policy:set; updating the old 4.4 config.json.

Acceptance
- `bash -n` passes for every script; shellcheck output recorded (or "not installed").
- scripts/test-release.sh passes with stubs and fixtures and is run by scripts/verify.sh; it covers every Decision with positive and negative cases (below), and no test touches the network, the real keychain, the real profile directory, xcodebuild, or aws.
- `scripts/release.sh preflight --dry-run`, `... all --build 500 --dry-run`, and `... install-info --build 500 --dry-run` run without side effects in a clean checkout with only scripts/release.env.example copied to a temp env file with placeholder values, and their transcripts are in the report.
- No secret, team id, profile name, or bucket name appears in any tracked file; the env file and build directory are gitignored (prove with git check-ignore).
- No change under .claude/, contract/, LocalPackages/, the app sources, the project file, or the synced Docs files.

---

## Inventory (read from disk 2026-11-06)

### Release configuration signing and version settings (project.pbxproj)

Target-level Release build configuration (D3C3716E):

| Setting | Value |
|---|---|
| CODE_SIGN_STYLE | Automatic (script passes Manual on command line) |
| CURRENT_PROJECT_VERSION | 500 |
| DEVELOPMENT_TEAM | 2W5W9XTGL6 |
| PROVISIONING_PROFILE_SPECIFIER | (not set in Release; script passes on command line) |
| MARKETING_VERSION | 5.0 |
| PRODUCT_BUNDLE_IDENTIFIER | com.alberta.ChristmasTracker |

The Release configuration's base xcconfig is `Config/Config.xcconfig` (project-level D3C3716B). The app target Release config (D3C3716E) has no baseConfigurationReference (inherits project-level Release defaults).

### Effective Release build settings (xcodebuild -showBuildSettings, read 2026-11-06)

| Setting | Value |
|---|---|
| API_BASE_URL | https://api.bmalberta.com |
| API_MODE | real |
| APP_ENVIRONMENT | production |
| CODE_SIGN_STYLE | Automatic |
| CURRENT_PROJECT_VERSION | 500 |
| DEVELOPMENT_TEAM | 2W5W9XTGL6 |
| MARKETING_VERSION | 5.0 |
| PRODUCT_BUNDLE_IDENTIFIER | com.alberta.ChristmasTracker |

PROVISIONING_PROFILE_SPECIFIER is empty in Release; the script will pass it on the xcodebuild command line.

### Shared scheme

File: `ChristmasTracker/ChristmasTracker.xcodeproj/xcshareddata/xcschemes/ChristmasTracker.xcscheme` — shared scheme exists and is named `ChristmasTracker`.

### Info.plist keys read by verify-ipa

File: `ChristmasTracker/ChristmasTracker/Info.plist`

Keys present: `API_BASE_URL`, `API_MODE`, `APP_ENVIRONMENT`, `SENTRY_DSN`, `NSFaceIDUsageDescription`, `NSAppTransportSecurity` (with `NSAllowsLocalNetworking`, no `NSAllowsArbitraryLoads`).

### xcconfig files

- `ChristmasTracker/ChristmasTracker/Config/Config.xcconfig` — Release base; sets `API_BASE_URL = https://api.bmalberta.com`, `API_MODE = real`, `APP_ENVIRONMENT = production`
- `ChristmasTracker/ChristmasTracker/Config/Config-Debug.xcconfig` — Debug/QA override
- `ChristmasTracker/ChristmasTracker/Config/Config-QA.xcconfig` — QA override
- `ChristmasTracker/Config-Secrets.xcconfig` — untracked; listed in .gitignore

### .gitignore (existing entries relevant to release)

Already ignored: `Distribution/`, `ChristmasTracker_Dist/*`, `.DS_Store`.
Not yet ignored: `scripts/release.env`, `scripts/.release-ledger`, `build/`.

### scripts/ style and conventions

- All scripts: `cd "$(dirname "$0")/.."` at top, `set -euo pipefail` not yet present in existing scripts (they use `|| exit 1` and FAIL counters).
- verify.sh: adds steps with `echo "=== verify: <name> ==="` prefix, calls script, adds `|| { echo "=== verify: NAME FAILED ==="; FAIL=1; }`.
- build.sh / test.sh: environment variable overrides (`DEST=`, `CONFIGURATION=`), log to `/tmp/`, grep errors, tail log.
- check-config.sh: function-based, FAIL counter, local variables.

---

## Gate 1 — Story R1: The Script Core and the Pure Checks

**Contract slice:** No server contract involved. All work is local tooling.

**Interface introduced:** `scripts/release.sh` (new), `scripts/test-release.sh` (new), `scripts/release.env.example` (new). The verify.sh step addition is not a new interface.

**Acceptance criteria:**
1. `bash -n scripts/release.sh` exits 0.
2. `shellcheck scripts/release.sh` exits 0 (or output recorded if warnings exist).
3. `bash -n scripts/test-release.sh` exits 0.
4. `scripts/test-release.sh` exits 0 with all named tests passing and 0 failures.
5. `scripts/verify.sh` exits 0 with 612 app tests, 146 package tests, and the new release test step in its output.
6. `scripts/release.sh preflight --dry-run` with placeholder env exits 0 and prints only what it would do, no side effects.
7. `scripts/release.sh all --build 500 --dry-run` with placeholder env exits 0 and prints only what it would do.
8. `scripts/release.sh install-info --build 500 --dry-run` with placeholder env exits 0 and prints the install link.
9. `git check-ignore -v scripts/release.env scripts/.release-ledger build/` lists all three as ignored.
10. No tracked file contains a real team id (2W5W9XTGL6 is already in the project; the scripts must not add it), a bucket name, or a profile name.

**Weight:** Solo (non-auth, no capability-flag UI, no generated client). One implementer writes and loops.

**Scoped files:**
- `scripts/release.sh` (new)
- `scripts/lib/release-lib.sh` (new, optional helper)
- `scripts/test-release.sh` (new)
- `scripts/release.env.example` (new)
- `scripts/verify.sh` (add one step only)
- `.gitignore` (add three entries)

---

## Gate 1 — Story R2: The Runbook and the Handoff

**Contract slice:** No server contract. Documentation only.

**Interface introduced:** None.

**Acceptance criteria:**
1. `Docs/release-runbook.md` exists and covers all prerequisites, step-by-step procedure, device checks, and rollback.
2. The runbook includes the exact commands for a first release with build 500.
3. The handoff file exists in `Docs/handoffs/` and contains the first-release checklist.
4. The handoff lists unverified assumptions (signing, export, upload not run by agents).
5. No change to any file outside `Docs/release-runbook.md` and `Docs/handoffs/`.

**Weight:** Solo (docs only).

**Scoped files:**
- `Docs/release-runbook.md` (new)
- `Docs/handoffs/2026-11-06-ios-to-brian-i6b1.md` (new)

---

## Fix pass Gate 1 — Story G1: Signing from the project, and the small fixes

**Contract slice:** No server contract involved. All work is local tooling.

**Interface introduced:** `RELEASE_ARCHIVE_SIGNING` env var (new; default `project`; set to `cli` to restore the previous CLI-override behaviour as a fallback).

**Acceptance criteria:**
1. `bash -n scripts/release.sh` exits 0.
2. `shellcheck scripts/release.sh` exits 0 (or output recorded).
3. `bash -n scripts/test-release.sh` exits 0.
4. `scripts/test-release.sh` exits 0 with 0 failures; test arithmetic for every new test is documented in the report.
5. `scripts/verify.sh` exits 0; app tests 612, package tests 146, counts unchanged.
6. Default `archive` dry-run output contains `CURRENT_PROJECT_VERSION` and does NOT contain `CODE_SIGN_STYLE`, `DEVELOPMENT_TEAM`, or `PROVISIONING_PROFILE_SPECIFIER`.
7. `archive` with `RELEASE_ARCHIVE_SIGNING=cli` dry-run output contains all four settings.
8. `preflight` calls `check_project_signing`, which reads `CODE_SIGN_STYLE`, `DEVELOPMENT_TEAM`, `PROVISIONING_PROFILE_SPECIFIER`, `CODE_SIGN_IDENTITY`, and `PRODUCT_BUNDLE_IDENTIFIER` from the ChristmasTracker target block of `xcodebuild -showBuildSettings`; each wrong setting produces an error naming the setting and the Xcode fix path; no secret values (team ID, profile name) are printed in the error.
9. Device count is the integer returned directly by `plutil -extract ProvisionedDevices raw`; it is validated as numeric (non-numeric → "unknown"); 0 devices fails preflight.
10. `verify-ipa` fails when `SENTRY_DSN` is missing from Info.plist OR when present but empty; passes when non-empty; never prints the DSN value.
11. `verify-ipa` and `export` derive the app bundle name from `PRODUCT_NAME` in build settings; if build settings cannot be read, `verify-ipa` falls back to the single `Payload/*.app` entry in the IPA and fails if there is not exactly one; the IPA file name (`ChristmasTracker-<version>-<build>.ipa`) does not change.
12. `install-info` output contains no `npm run policy:set` command; it contains the values block and the note "Pass these to policy:set; the exact flag names are in the API chat's local quickstart (unconfirmed here)."
13. No change under `.claude/`, `contract/`, `LocalPackages/`, app sources, project file, or synced Docs files.

**Weight:** Solo (bash tooling, non-auth, no capability-flag UI, no generated client).

**Scoped files:**
- `scripts/release.sh` (modified)
- `scripts/test-release.sh` (modified — new tests added, existing tests unchanged or explained)
- `scripts/release.env.example` (modified — add RELEASE_ARCHIVE_SIGNING)

---

## Fix pass Gate 1 — Story G2: Runbook, handoff, and report accuracy

**Contract slice:** No server contract. Documentation only.

**Interface introduced:** None.

**Acceptance criteria:**
1. `Docs/release-runbook.md` updated: new prerequisite for configuring manual signing in Xcode; `RELEASE_ARCHIVE_SIGNING=cli` described as a fallback; Sentry DSN requirement noted; no text contradicts the new behaviour.
2. `Docs/handoffs/2026-11-06-ios-to-brian-i6b1.md` updated: false statements corrected (no "app_dir glob", no PlistBuddy reference); archive flags paragraph reflects project-signing default; project-signing step in "Before the first release"; what was not run clearly listed; commit list accurate.
3. `Docs/reports/I6b1-1-script-core.md` corrected: first line "Corrected in the I6b-1 fix pass."; Gate 2 verdicts present and real (both reviewers; if neither ran for R1, reviewers run now on the final script and verdicts recorded); "Not done or partial" lists what was not run.
4. `scripts/verify.sh` exits 0; counts unchanged.
5. No change outside the permitted Docs files.

**Weight:** Solo (docs only).

**Scoped files:**
- `Docs/release-runbook.md` (modified)
- `Docs/handoffs/2026-11-06-ios-to-brian-i6b1.md` (modified)
- `Docs/reports/I6b1-1-script-core.md` (modified)
