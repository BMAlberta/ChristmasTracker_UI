# I6b-1 R1 — The Release Script Core

## What Changed

| File | Change |
|------|--------|
| `scripts/release.sh` | New — full release automation (preflight, archive, export, verify-ipa, manifest, upload, install-info, all) |
| `scripts/test-release.sh` | New — self-contained stub/fixture test harness, 45 tests |
| `scripts/release.env.example` | New — env template with placeholder values and documentation |
| `scripts/verify.sh` | Modified — added release script test step before the prohibited-frameworks check |
| `.gitignore` | Modified — added `scripts/release.env`, `scripts/.release-ledger`, `build/` |

## verify.sh output (pre-commit)

```
=== verify: derived spec ===
Derived spec is up to date.
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- tests: 612 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Build complete! (0.18s)
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 45 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## git check-ignore proof

```
$ git check-ignore -q scripts/release.env && echo "ignored"
ignored
$ git check-ignore -q scripts/.release-ledger && echo "ignored"
ignored
$ git check-ignore -q build/ && echo "ignored"
ignored
```

## Dry-run transcripts

### `install-info --build 500`

```
=== Christmas Tracker — Install Info (build: 500) ===

1. Install link (itms-services):
   itms-services://?action=download-manifest&url=https://content.bmalberta.com/distribution/tracker/500/manifest.plist

2. URLs:
   Manifest: https://content.bmalberta.com/distribution/tracker/500/manifest.plist
   IPA:      https://content.bmalberta.com/distribution/tracker/500/ChristmasTracker-5.0-500.ipa

3. Values for policy:set (run on the API server after upload):
   platform:          ios
   --latest-build:    500
   --latest-version:  5.0
   --recommended-version: 5.0
   --manifest-url:    https://content.bmalberta.com/distribution/tracker/500/manifest.plist
   --ipa-url:         https://content.bmalberta.com/distribution/tracker/500/ChristmasTracker-5.0-500.ipa
   --min-build:       (choose: raising this forces an update on older builds; see runbook)

   Example command:
     npm run policy:set -- --platform ios \
       --latest-build 500 --latest-version 5.0 \
       --manifest-url 'https://content.bmalberta.com/distribution/tracker/500/manifest.plist' \
       --ipa-url 'https://content.bmalberta.com/distribution/tracker/500/ChristmasTracker-5.0-500.ipa'

4. Device verification steps:
   a. Tap the install link on a registered device (must be in the provisioning profile).
   b. In Settings → General → VPN & Device Management, verify the app shows version 5.0 (500).
   c. Launch the app and confirm it logs in against production (https://api.bmalberta.com).
   d. Check Sentry for a session event with the correct build number.
```

### `preflight --dry-run --skip-verify --allow-unpushed` (placeholder env)

```
[release] Checking required tools...
[release] All required tools found.
[release] Checking git state...
[release] Branch: master
[release] Checking provisioning profile: YourAdHocProfileName...
[release] ERROR: Provisioning profile 'YourAdHocProfileName' not found in ~/Library/MobileDevice/Provisioning Profiles
```

Expected: preflight stops at the profile check with placeholder values. With a real
profile installed, it proceeds to verify expiry, identity, and optionally `scripts/verify.sh`.

## Test harness coverage

45 tests across 9 sections:

- env validation (5 tests): required vars, http URL rejection, missing vars
- build number (5 tests): non-integer, too small, ledger reject, ledger accept
- ExportOptions.plist (2 tests): correct fields, plutil -lint passes
- manifest.plist (6 tests): https URL, plutil-lint, bundle-identifier, bundle-version, IPA filename, http URL rejection
- verify-ipa (11 tests): good IPA, 7 bad-field cases, expired profile, get-task-allow=true, SENTRY_DSN never printed
- upload (5 tests): no --yes, overwrite rejection, dry-run side effects, ledger after success, AWS_PROFILE honored
- install-info (4 tests): itms-services link, https manifest URL, policy:set block, no secrets in output
- dry-run (3 tests): no build dir files, aws not called, no ledger entry
- profile checks (2 tests): non-ad-hoc profile fails, expiring within min days fails
- gitignore (3 tests): release.env, .release-ledger, build/ all ignored

## Deviations from Gate 1 spec

1. **ExportOptions.plist written as heredoc** — Gate 1 spec implied `plutil -insert` commands.
   Changed to a heredoc (`cat > file <<PLIST`) because `plutil` treats `.` as a keypath
   separator, making `provisioningProfiles.com.alberta.ChristmasTracker` fail (it navigates
   into `com`→`alberta`→`ChristmasTracker` rather than setting a dotted key). The heredoc
   produces identical output and passes `plutil -lint`.

2. **`capture_failing` uses `env "$@"`** — Needed to support `VAR=val cmd` prefix syntax.
   Shell function `"$@"` doesn't handle env-var-prefix arguments; `env "$@"` does.

3. **`aws_profile_args` expanded with `${arr[@]+"${arr[@]}"}`** — Bash 3.2 (bundled on macOS)
   treats empty arrays as unbound under `set -u`. The portable expansion avoids the error.

4. **`tmpbase` promoted from `local` to global** — EXIT trap fires at global scope after
   `run_tests()` returns; `local` variables are out of scope at that point, causing
   "unbound variable" on cleanup.

## Not done or partial

None. All Gate 1 acceptance criteria met; 45/45 tests pass; verify.sh passes.
