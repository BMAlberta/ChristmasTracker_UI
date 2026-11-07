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

Run `policy:set` on the API server with the exact values printed by `install-info`. The
script never calls `policy:set` itself. The runbook explains what `--min-build` means.

### Deadline

**2026-11-25** — the 4.4 ad hoc provisioning profile expires. Every 4.4 install stops
launching after that date. Build 500 must be on-device before then.

---

## Unverified assumptions (agents did not run signing or upload)

The following work was validated only by test stubs. You will find out if anything is
wrong during the first real preflight/archive/upload:

1. **Signing identity name** — `preflight` checks `security find-identity -v -p codesigning`
   for an "Apple Distribution" identity. If your certificate uses a different prefix
   (e.g., "iPhone Distribution"), the check will fail. The pattern is easy to adjust in
   `cmd_preflight` around line 358 of `release.sh`.

2. **Profile decode** — `preflight` decodes the provisioning profile with `security cms -D`.
   The structure assumed (ProvisionedDevices array, Entitlements dict with get-task-allow)
   matches the standard Apple ad hoc profile format. If Apple changes the structure, the
   grep/PlistBuddy path in `cmd_preflight` may need updating.

3. **xcodebuild archive signing** — Signing settings are read from the Xcode project by
   default (preflight checks them). If signing fails during archive, check the target's
   Signing and Capabilities settings in Xcode, or set `RELEASE_ARCHIVE_SIGNING=cli` in
   `scripts/release.env` as a fallback.

4. **IPA layout** — `verify-ipa` reads `PRODUCT_NAME` from xcodebuild build settings to
   find the `.app` bundle. If build settings are unavailable, it falls back to scanning
   for a single `Payload/*.app` entry. This was fixed in the fix pass; the hardcoded
   `ChristmasTracker.app` assumption no longer applies.

5. **S3 bucket policy** — The upload subcommand assumes `aws s3 cp` with the configured
   credentials can write to `s3://<bucket>/<prefix>/<build>/`. Confirm the IAM policy
   is in place before the first upload.

6. **itms-services on devices** — The install link works only in Safari on iOS. The device
   must trust your enterprise/ad hoc distribution certificate under Settings → General →
   VPN & Device Management if it has not done so before.

---

## Section 9 of PROGRAM.md (one line)

> I6b-1 (release script + fix pass): `scripts/release.sh` with preflight (project signing check), archive/export/verify-ipa/manifest/upload/install-info, test harness (62 tests), and runbook — agents stop here; Brian runs the first release before 2026-11-25.
