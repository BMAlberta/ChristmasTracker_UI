# I6b-1 G1 — Signing from Project and Small Fixes

## What Changed

| File | Change |
|------|--------|
| `scripts/release.sh` | Added `get_app_build_settings()` / `get_product_name()`, `check_project_signing()` (5-setting preflight check); refactored `get_marketing_version()` to reuse settings call; `cmd_archive()` conditionalized on `RELEASE_ARCHIVE_SIGNING` (default: project, opt-in: cli); device count: removed `| wc -l`, added numeric validation and 0-device failure; `cmd_verify_ipa()`: SENTRY_DSN now fails if missing or empty, PRODUCT_NAME used for payload path with Payload scan fallback; `cmd_export()`: PRODUCT_NAME for IPA filename; `cmd_install_info()`: removed unconfirmed npm example |
| `scripts/test-release.sh` | `make_info_plist` gains optional `sentry_dsn` param (default non-empty); `make_ipa` gains optional `app_bundle_name` param; xcodebuild stub updated to multi-target format with correct signing settings; added 17 new tests (signing check x 7, archive mode x 2, device count x 3, SENTRY_DSN x 2, PRODUCT_NAME x 3, install-info x 1) for a total of 62 |
| `scripts/release.env.example` | Documents `RELEASE_ARCHIVE_SIGNING=project` |

## test-release.sh output (pre-commit)

```
=== test-release.sh: 62 passed, 0 failed ===
```

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
=== test-release.sh: 62 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## Gate 2 verdicts

- **convention-reviewer**: PASS — `set -euo pipefail` present; no eval; no rm -rf outside mktemp; all expansions quoted; tool overrides used throughout; DEVELOPMENT_TEAM and PROVISIONING_PROFILE_SPECIFIER error messages hide actual values; SENTRY_DSN value never printed; signing_args uses safe empty-array expansion.
- **acceptance-reviewer**: PASS (after one round-trip: missing 1-device test added, bringing total to 62).

## Deviations from Gate 1 spec

None. All five fix-pass acceptance criteria (N1–N5) met.

Gate 2 file and line evidence (both reviewers re-run on the final script on 2026-11-09, I6b-1b story K2; both PASS; full lists in `I6b1-1-script-core.md`, section "Gate 2"):
- Signing from the project by default: `RELEASE_ARCHIVE_SIGNING` defaults to `project` (`release.sh:28`); `check_project_signing` at 298-335; CLI signing only when the value is `cli` (541-547).
- Device count: the old `wc -l` pipe is gone; numeric validation at 484-486; zero devices fail at 488-490.
- SENTRY_DSN missing or empty fails: 823-825; value never printed (827).
- PRODUCT_NAME for the bundle path: anchored helper (287-289), used at 710-714, with the `Payload/*.app` scan fallback at 716-724 (exactly one `.app`, otherwise die).
- install-info: the unconfirmed example was removed in G1; the final script prints the confirmed `policy:set` recipe (1169-1182).
- Superseded since this report was written: the "What Changed" row says `cmd_export()` uses PRODUCT_NAME for the IPA filename and `cmd_install_info()` removed the npm example. In the final script `cmd_export` finds the single exported `.ipa` and renames it (644-668), and `cmd_install_info` prints the recipe again (I6b-1b).

## Not done or partial

NOT RUN by the agents (the tests use stubs and fixtures only): `xcodebuild archive`, `xcodebuild -exportArchive`, the upload and any `aws` command, the real certificate lookup in a keychain (`security find-identity`), the real profile lookup in `~/Library/MobileDevice/Provisioning Profiles`, signing (`codesign` against a real identity), and any on-device install. The project-signing check (`check_project_signing`) was exercised only against stubbed `xcodebuild -showBuildSettings` text; its grep-based lookups were later found unanchored and were replaced in I6b-1b (see `Docs/reports/I6b1-5-anchored-lookups-fixture-and-recipe.md`).
