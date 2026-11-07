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

## Not done or partial

None.
