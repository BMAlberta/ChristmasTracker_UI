# iOS Handoff — I6b-1 release script — 2026-11-06

**Package:** I6b-1 (the ad hoc release script)
**From:** iOS agents
**To:** Brian
**Branch:** `feat/i6b1-release-script` — open a PR to `master`, merge when ready

---

## Contract issues found

None. This package has no server-contract dependency.

---

## What changed

| File | Description |
|------|-------------|
| `scripts/release.sh` | New ad hoc release script: preflight, archive, export, verify-ipa, manifest, upload, install-info, all subcommands; `--dry-run` on every subcommand; fix pass adds project signing check, `RELEASE_ARCHIVE_SIGNING` opt-in, correct device count (plutil returns count directly), SENTRY_DSN non-empty check, PRODUCT_NAME bundle path, install-info cleanup |
| `scripts/test-release.sh` | New self-contained stub/fixture test harness; 45 tests (R1), 62 tests after fix pass; run by `scripts/verify.sh` |
| `scripts/release.env.example` | Env template; copy to `scripts/release.env` and fill in real values |
| `scripts/verify.sh` | Added one step: runs `scripts/test-release.sh` |
| `.gitignore` | Added `scripts/release.env`, `scripts/.release-ledger`, `build/` |
| `Docs/release-runbook.md` | Step-by-step release runbook including prerequisites, procedure, 4.4 coexistence notes, rollback, and troubleshooting |
| `Docs/epics/I6b1-release-script.md` | Epic brief with inventory (committed in the Docs commit preceding R1) |
| `Docs/reports/I6b1-1-script-core.md` | R1 story report |

Second fix pass (I6b-1b, added 2026-11-09 on branch `fix/i6b1b-release-lookups`):

| File | Description |
|------|-------------|
| `scripts/release.sh` | Every build-setting read now goes through an anchored awk helper (`setting_value_from` / `setting_value`), so look-alike keys such as `FULL_PRODUCT_NAME`, `EXPANDED_CODE_SIGN_IDENTITY`, and `DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER` can no longer be picked up in place of `PRODUCT_NAME`, `CODE_SIGN_IDENTITY`, and `PRODUCT_BUNDLE_IDENTIFIER`. `export` finds the exported `.ipa` (exactly one required; zero or several fail with a clear message) instead of assuming `ChristmasTracker.ipa`. `install-info` prints the confirmed `policy:set` recipe (development-database and production-server commands, an unfilled force-update warning, and the note that manifest and IPA URLs cannot be cleared once set). |
| `scripts/fixtures/showbuildsettings-release.txt` | New. A real, sanitized `xcodebuild -showBuildSettings` capture (Release, scheme build) that the test stubs serve, so the lookups are tested against real-shaped output instead of hand-written text. |
| `scripts/test-release.sh` | The xcodebuild stub serves the fixture; 30 new tests (92 total); one assertion inverted with a stated reason (install-info now must contain the `policy:set` recipe). |
| `Docs/release-runbook.md` | Step 7 and Rollback rewritten around the confirmed `policy:set` recipe. |
| `Docs/reports/I6b1-5-anchored-lookups-fixture-and-recipe.md`, `Docs/reports/I6b1-6-docs-corrections.md` | Story reports for K1 and K2. |

Test counts: 45 tests after R1, 62 after the first fix pass, **92** after I6b-1b.

### Commits

Merged to `master` earlier (I6b-1 and its first fix pass):

```
d3e61cc I6b-1: add epic brief and inventory
7c6f387 I6b-1: add the release script with its stubbed test harness
d0a097e I6b-1: add the release runbook and the package handoff note
1a57ad1 I6b-1: add fix pass Gate 1 spec
0e46c4a I6b-1: verify signing in the project, make CLI signing opt-in, and fix the device count, DSN, and bundle name checks
4218ae3 I6b-1: correct the runbook, handoff, and reports
```

On branch `fix/i6b1b-release-lookups` (output of `git log --oneline master..HEAD` before the K2 commit):

```
dc13ca8 I6b-1b: anchor build-setting lookups, test against real-shaped build settings, find the exported IPA robustly, and print the real policy:set recipe
dc0ce64 Merge branch 'master' into fix/i6b1b-release-lookups
7f83990 I6b-1b: add second fix pass Gate 1 spec
```

The K2 docs commit ("I6b-1b: add the missing report corrections, Gate 2 verdicts, and not-run list") follows these; its hash is in `git log` (a commit cannot contain its own hash).

---

## What you must do next

### Before the first release (prerequisite setup)

1. **Provision the ad hoc profile.**
   Every family device must be registered (UDID added in Developer portal, device added to
   the ad hoc provisioning profile). Re-download the profile after adding devices, then
   open it on your Mac. See `Docs/release-runbook.md` §Prerequisites for the exact steps.

2. **Fill in `scripts/release.env`.**
   ```bash
   cp scripts/release.env.example scripts/release.env
   ```
   Set `RELEASE_TEAM_ID` (your 10-character Apple team ID), `RELEASE_PROFILE_NAME` (the
   exact name of the ad hoc profile as it appears in Xcode), `RELEASE_S3_BUCKET`, and
   optionally `RELEASE_AWS_PROFILE`. Also configure signing in Xcode (ChristmasTracker
   target → Signing and Capabilities → Release → Manual, your team, ad hoc profile) —
   preflight will verify.

3. **Configure AWS.**
   The upload subcommand uses the AWS CLI. Configure IAM credentials with
   `s3:PutObject` and `s3:ListBucket` permissions for the distribution bucket.

4. **Run preflight.**
   ```bash
   bash scripts/release.sh preflight --build 500
   ```
   This validates everything — tools, git state, profile, signing identity, and the full
   test suite — before you archive. Fix any reported issues before proceeding.

### The first release

```bash
bash scripts/release.sh preflight --build 500
bash scripts/release.sh archive  --build 500
bash scripts/release.sh export   --build 500
bash scripts/release.sh verify-ipa --build 500
bash scripts/release.sh manifest --build 500
bash scripts/release.sh upload   --build 500 --yes
bash scripts/release.sh install-info --build 500
# Then run policy:set on the API server with the values printed by install-info
```

Or in one command after a clean preflight:
```bash
bash scripts/release.sh all --build 500 --yes
```

### After upload

Run `policy:set` with the exact values printed by `install-info`. `install-info` now prints
two ready commands (development database: `npm run policy:set -- --platform ios ...`;
production server: `bash repo/deploy/scripts/compose.sh exec api node dist/scripts/policy-set.js --platform ios ...`).
The script never calls `policy:set` itself. Do not add `--min-build` until the new build is on
every family phone; the runbook explains why. The manifest and IPA URLs cannot be cleared
once set.

### Deadline

**2026-11-25** — the 4.4 ad hoc provisioning profile expires. Every 4.4 install stops
launching after that date. Build 500 must be on-device before then.

---

## Not run by the agents

The agents wrote and tested the script with stubs and fixtures only. They did NOT run:
`xcodebuild archive`, `xcodebuild -exportArchive`, the upload and any `aws` command, the real
certificate lookup in a keychain (`security find-identity`), the real profile lookup in
`~/Library/MobileDevice/Provisioning Profiles`, signing (`codesign` against a real identity),
and any on-device install. The only real `xcodebuild` call in the whole package was one
read-only `-showBuildSettings` capture, used to build the fixture. `policy:set` was not run
in either form.

---

## Unverified assumptions (agents did not run signing or upload)

The following work was validated only by test stubs. You will find out if anything is
wrong during the first real preflight/archive/upload:

1. **Signing identity name** — `preflight` checks `security find-identity -v -p codesigning`
   for an "Apple Distribution" identity (`scripts/release.sh` line 495). If your certificate
   uses a different prefix (e.g., "iPhone Distribution"), the check will fail. The pattern
   is easy to adjust there.

2. **Profile decode** — `preflight` decodes the provisioning profile with `security cms -D`
   and reads fields with `plutil -extract` (for example `ProvisionedDevices`,
   `Entitlements.get-task-allow`, `ExpirationDate`; `scripts/release.sh` lines 419–483).
   The structure assumed (ProvisionedDevices array, Entitlements dict with get-task-allow)
   matches the standard Apple ad hoc profile format. If Apple changes the structure, those
   `plutil -extract` calls may need updating.

3. **xcodebuild archive signing** — Signing settings are read from the Xcode project by
   default (preflight checks them). If signing fails during archive, check the target's
   Signing and Capabilities settings in Xcode, or set `RELEASE_ARCHIVE_SIGNING=cli` in
   `scripts/release.env` as a fallback.

4. **IPA layout** — `verify-ipa` reads `PRODUCT_NAME` from xcodebuild build settings to
   find the `.app` bundle. If build settings are unavailable, it falls back to scanning
   for a single `Payload/*.app` entry. This was fixed in the fix pass; the hardcoded
   `ChristmasTracker.app` assumption no longer applies. `export` no longer assumes the file
   name `xcodebuild -exportArchive` writes: it requires exactly one `.ipa` in the build
   directory and renames it to `ChristmasTracker-<version>-<build>.ipa`; this has only been
   exercised with a stub that writes one IPA.

5. **S3 bucket policy** — The upload subcommand assumes `aws s3 cp` with the configured
   credentials can write to `s3://<bucket>/<prefix>/<build>/`. Confirm the IAM policy
   is in place before the first upload.

6. **itms-services on devices** — The install link works only in Safari on iOS. The device
   must trust your enterprise/ad hoc distribution certificate under Settings → General →
   VPN & Device Management if it has not done so before.

---

## Open risks

- **Pre-existing, not fixed:** `check_project_signing` echoes the raw `CODE_SIGN_IDENTITY`
  value on a mismatch (`got: '...'`, `scripts/release.sh` line 327). With Xcode's generic
  values (for example `Apple Development`) this is harmless, but if the project ever names a
  specific certificate, that name would be printed. Found by the I6b-1b convention and
  acceptance reviewers; flagged for a later pass.
- The fixture is single-block `-scheme` output and contains neither
  `EXPANDED_CODE_SIGN_IDENTITY` nor `PROVISIONING_PROFILE_SPECIFIER` (the project signs
  Automatic today). The Manual-signing and look-alike cases are tested by splicing values into
  a temp copy, not by real output; the first real archive with Manual signing may expose a
  difference.
- The `policy:set` recipe and flag names come from the backend operator doc; the script only
  prints them.

---

## Section 9 of PROGRAM.md (one line)

> I6b-1 (release script + fix pass): `scripts/release.sh` with preflight (project signing check), archive/export/verify-ipa/manifest/upload/install-info, anchored build-setting lookups against a real-shaped fixture, export IPA discovery, the printed `policy:set` recipe, test harness (92 tests), and runbook — agents stop here; Brian runs the first release before 2026-11-25.
