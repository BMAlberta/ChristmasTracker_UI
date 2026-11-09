Corrected in the I6b-1 fix passes.

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

## Corrected in fix pass (commit 0e46c4a)

The following items from the original R1 delivery were found incorrect or incomplete during Brian's review and corrected in story G1:

| Item | Original issue | Fix |
|------|----------------|-----|
| Archive signing | Passed `CODE_SIGN_STYLE=Manual`, `DEVELOPMENT_TEAM`, `PROVISIONING_PROFILE_SPECIFIER` as CLI overrides — breaks SPM dependencies | Signing now read from Xcode project by default; CLI opt-in via `RELEASE_ARCHIVE_SIGNING=cli` |
| Device count | Piped plutil output through `wc -l`; plutil returns count directly, so count was always 1 | Removed `wc -l` pipe; validates numeric result; fails on 0 |
| SENTRY_DSN | Treated key existence as sufficient; empty value passed | Now fails if key missing or value empty |
| Bundle name | Hardcoded `ChristmasTracker.app` in verify-ipa and export | Now reads `PRODUCT_NAME` from build settings with `Payload` scan fallback |
| install-info output | Included `npm run policy:set` example with unconfirmed flag names | Removed example; replaced with "(unconfirmed here)" note |

Gate 2 verdicts (R1 — retroactive, applied during fix pass):
- convention-reviewer: PASS (reviewed on G1 diff; no issues found in R1 scope)
- acceptance-reviewer: PASS with the above corrections applied

## Gate 2

The verdicts of the original R1 review could not be shown from the earlier runs (the section above says "retroactive"). Both reviewers were therefore run again on 2026-11-09, one after the other, on the FINAL `scripts/release.sh` and `scripts/test-release.sh` (branch `fix/i6b1b-release-lookups`, HEAD `dc13ca8`), as part of I6b-1b story K2.

**convention-reviewer — PASS** (script review and K2 docs diff). Evidence:
- `set -euo pipefail`: `release.sh:8`, `test-release.sh:6`. No `eval`, no `sudo` in either file.
- `rm -rf` only on a `mktemp -d` directory under an EXIT trap: `release.sh:702`, `:704`; `test-release.sh:565-566`. The only other `rm` is `rm -f` at `release.sh:355`.
- Quoting: shellcheck clean on both files, `bash -n` clean; the unquoted `${arr[@]+"${arr[@]}"}` idiom (550-552, 1069-1095) is the intended bash 3.2-safe empty-array form.
- Tool overrides `RELEASE_XCODEBUILD`, `_AWS`, `_SECURITY`, `_CODESIGN`, `_PLUTIL`, `_UNZIP`, `_SHASUM`, `_GIT` defined at `release.sh:19-26` and used for archive (550), export (639), aws (1069-1095), security (417, 433, 495, 835), codesign (875-894), git (379-398, 1107).
- Secrets not printed: team id, profile name, bucket logged as `[set]` (163-166, 321, 324, 458, 497, 599, 886); SENTRY_DSN "value not printed" (827). Informational: the raw `CODE_SIGN_IDENTITY` is echoed on a mismatch (`release.sh:327`); see the handoff's open risks.
- Dry-run: `dry_run_cmd` (112-118); archive (560), export (593, 644), manifest (956), upload (1042) and preflight `verify.sh` (511) are guarded; test at `test-release.sh:1287-1300` asserts `all --dry-run` creates no build directory.
- Bash 3.2: no `declare -A`, `mapfile`, `${var,,}`, `|&`, `coproc`.
- Test harness never runs real archive, export, aws or signing: every such invocation sets the stub overrides (examples `test-release.sh:1657-1688`, 723, 2291-2351, 1112-1209, 1290-1294).
- Informational, since fixed: the fixture still held a DerivedData folder name derived from this Mac's project path (see "Process finding" in `I6b1-6-docs-corrections.md`).

**acceptance-reviewer — PASS** (K2 diff; one required correction, the stale K1 commit hash in the handoff, applied). Focus-list answers on the final script:
- Preflight tools: loop at `release.sh:364-373`, each honoring its override. Git: clean tree 379-382, branch 386-390, origin match unless `--allow-unpushed` 394-405. Profile: found by name 411-429; ad hoc (`ProvisionedDevices`) 436; get-task-allow 442-445; bundle id 449-452; team 456-459; expiry and minimum days 463-479; device count 483-490. Identity: "Apple Distribution" plus team at 495-498, output masked 502-504.
- ExportOptions.plist: written as XML 609-633 (reason for not using `plutil -insert` in the comment at 606-608), linted at 634.
- manifest.plist: https enforced 949-951, written 968-1000, `plutil -lint` 1003-1005.
- verify-ipa: bundle id 733, build 744, version 757, `API_BASE_URL` 767, `API_MODE` 777, `APP_ENVIRONMENT` 787, ATS keys 796-808, FaceID 813, SENTRY_DSN 823-828 (value not printed), embedded profile ad hoc / get-task-allow / expiry 838-869, codesign, team and entitlement 875-904.
- Upload: needs `--yes` unless `--dry-run` (1019-1021); refuses overwrite via `s3 ls` pre-checks (1069-1075); re-verifies after upload (1094-1101); ledger written at 1112, only after success.
- install-info: link and URLs 1145-1156, https guard 1141, device steps 1184-1188 (the recipe is now the confirmed one, 1169-1182).
- Dry-run: archive and export go through `dry_run_cmd`; export plist only printed (593-603); manifest returns before writing (956-965); upload returns before any aws call or ledger write (1042-1058); verify-ipa returns when the IPA is absent (691-697); preflight skips `verify.sh` (511-512).
- Not true of the original R1 text but true of the final script: see "Corrected in fix pass" above and the I6b-1b report.

## Not done or partial

NOT RUN by the agents (the tests use stubs and fixtures only): `xcodebuild archive`, `xcodebuild -exportArchive`, the upload and any `aws` command, the real certificate lookup in a keychain (`security find-identity`), the real profile lookup in `~/Library/MobileDevice/Provisioning Profiles`, signing (`codesign` against a real identity), and any on-device install. `policy:set` is never run by the script and was not run by the agents.

Also: the five items in "Corrected in fix pass" were delivered with bugs in R1; they were corrected in commit 0e46c4a (story G1). Later problems found in the final script (unanchored build-setting greps, an assumed IPA file name, an unconfirmed `policy:set` recipe) were corrected in the second fix pass, I6b-1b (see `Docs/reports/I6b1-5-anchored-lookups-fixture-and-recipe.md`). The test count in this report (45) is the R1 count; the current count is 92.
