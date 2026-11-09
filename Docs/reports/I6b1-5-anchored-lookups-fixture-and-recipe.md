# I6b-1b K1 — Anchored lookups, a real-shaped fixture, a robust export, and the real policy:set recipe

Package I6b-1b (second fix pass of the release script). Branch `fix/i6b1b-release-lookups` from `master` (base `c609064`, the merged I2b-2d PR). Gate 1 spec: `Docs/epics/I6b1-release-script.md`, section "Second fix pass Gate 1".

## Files added and changed

| File | Change |
|------|--------|
| `scripts/fixtures/showbuildsettings-release.txt` | New. Real `xcodebuild -showBuildSettings -project ChristmasTracker/ChristmasTracker.xcodeproj -scheme ChristmasTracker -configuration Release` output (637 lines), captured read-only by the Orchestrator on 2026-11-07 and sanitized (see "Fixture sanitization"). |
| `scripts/release.sh` | `setting_value_from TEXT KEY` and `setting_value KEY` anchored helpers (lines 257–285); every build-setting read goes through them; `cmd_export` finds the exported `.ipa` instead of assuming `ChristmasTracker.ipa` (lines 641–666); `cmd_install_info` prints the confirmed policy:set recipe (lines 1165–1182). |
| `scripts/test-release.sh` | xcodebuild stub serves the fixture (or a per-test temp copy); fixture helpers `make_settings_fixture`, `make_manual_settings_fixture`, `delete_setting`, `splice_settings_block`, `write_export_stub`; 30 new tests; one existing test inverted with a stated reason. 62 → 92. |
| `Docs/release-runbook.md` | Step 7 and Rollback rewritten around the confirmed recipe, the force-update warning, and the cannot-clear note. |

Not changed: `scripts/release.env.example` (no new env var was needed), `scripts/verify.sh`, anything under `.claude/`, `contract/`, `LocalPackages/`, app sources, project file, synced Docs.

## Fixture sanitization (what was replaced, exactly)

Source: the raw capture in the Orchestrator's scratchpad (not committed). Replacements, all by `sed`, nothing else changed:

| Original | Replacement | Lines |
|---|---|---|
| `DEVELOPMENT_TEAM = <real team id>` | `DEVELOPMENT_TEAM = TEAMID1234` | 177 |
| every `/Users/<real username>` path prefix | `/Users/test` | 73 lines |
| bare username in `ALTERNATE_OWNER`, `INSTALL_OWNER`, `USER`, `VERSION_INFO_BUILDER` | `test` | 31, 316, 595, 606 |
| `TARGET_DEVICE_IDENTIFIER = <Mac hardware id>` | `00000000-FAKEDEVICE000000` | 571 (acceptance-reviewer advisory) |
| `/var/folders/<two characters>/<per-user hash>/` in `CACHE_ROOT`, `CCHROOT` | `/var/folders/xx/FAKEFOLDERHASH0000000000000000/` | 79, 80 (acceptance-reviewer advisory) |
| the per-user Xcode DerivedData folder name (`ChristmasTracker-<28-character hash derived from the project path>`) in the build, symbol, module-cache and derived-file paths | `ChristmasTracker-fakehashfakehashfakehashfake` (same length) | 54 lines (63, 66, 69, 93, 116, and others) — added after the K1 commit; see "Sanitization miss" |

The same pass also replaced two 32-character hex values that the pattern scan flagged and that are not present in the committed project file, so they could be machine- or path-derived: `PROJECT_GUID` (fixture line 447, now `0000000000000000fakeguid00000000`) and the hash inside `SDK_STAT_CACHE_PATH` (line 486, now `00000000fakesdkstatcache0000000`). Line structure unchanged.

Sanitization miss (found by the K2 convention reviewer, fixed in the working tree before the K1 commit was amended): the first pass replaced only a subset of per-user path values and left the DerivedData folder name, which is a hash derived from this Mac's project path. A pattern-based scan (DerivedData paths, `/var/folders` paths, `/Users/` paths, 32-character lowercase tokens, 36-character UUID-looking tokens, "Provisioning Profiles" followed by a file name) is now the permanent check. The line structure of the fixture is unchanged.

Kept as captured: `CODE_SIGN_IDENTITY = Apple Development` (a generic Xcode constant, not an identity name; signing is still Automatic in the project), `PRODUCT_BUNDLE_IDENTIFIER = com.alberta.ChristmasTracker`, `API_BASE_URL = https://api.bmalberta.com` (both already public in the repo). Checked by command: a case-insensitive search of the fixture for the real team id, the username, the per-user `/var/folders` hash, and the device identifier returned no matches (this value-based search did not cover the DerivedData folder name; see "Sanitization miss" above and the pattern-based scan results in the I6b1-6 report).

Scrub re-check after the interruption (Orchestrator, 2026-11-09): a case-insensitive search of the five changed and untracked paths (three modified files, this report, the fixture) for the real team id (read from the project file's DEVELOPMENT_TEAM setting), the per-user `/var/folders` hash (read from the shell's temp-directory variable), the local hardware UUID and serial number (read-only local query), and the username path form returned no matches. The only hits for the account's first name are prose mentions of the person ("Brian runs this" in a comment already committed on `HEAD`, and "Note for Brian" below); no path, `/Users/` prefix, or identifier. That value-based search missed the DerivedData folder name in the fixture; it was found later and replaced (see "Sanitization miss"). The values themselves are deliberately not recorded here.

What the real output looks like (facts, from the capture): a "Resolve Package Graph / Resolved source packages" preamble, then ONE block `Build settings for action build and target ChristmasTracker:` (line 23). With `-scheme`, xcodebuild prints no package-target or test-target blocks. Look-alike keys present: `FULL_PRODUCT_NAME = ChristmasTracker.app` (251), `PRODUCT_MODULE_NAME` (438), `EXECUTABLE_NAME` (242), `WRAPPER_NAME` (612), `TARGET_NAME` (575), `PROJECT_NAME` (448), `DWARF_DSYM_FILE_NAME = ChristmasTracker.app.dSYM` (187), `EMBEDDED_PROFILE_NAME` (196), `DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER = NO` (166, precedes `PRODUCT_BUNDLE_IDENTIFIER` at 436), `PROVISIONING_PROFILE_REQUIRED`/`_YES_YES`/`_SUPPORTED` (451–453). Absent: `EXPANDED_CODE_SIGN_IDENTITY`, `PROVISIONING_PROFILE_SPECIFIER`.

## What changed in detail

### The anchored helper (`scripts/release.sh:268-285`)

```bash
setting_value_from() {
    local settings="$1"
    local key="$2"
    printf '%s\n' "$settings" | awk -v k="$key" '
        !found && $0 ~ "^[[:space:]]*" k "[[:space:]]*=" {
            sub("^[[:space:]]*" k "[[:space:]]*=[[:space:]]*", "")
            sub("[[:space:]]*$", "")
            print
            found = 1
        }'
}
setting_value() { local key="$1"; setting_value_from "$(get_app_build_settings)" "$key"; }
```

Call sites: `get_product_name` → `setting_value PRODUCT_NAME` (288); `get_marketing_version` → `setting_value MARKETING_VERSION` (292); `check_project_signing` captures settings once and reads `CODE_SIGN_STYLE`, `DEVELOPMENT_TEAM`, `PROVISIONING_PROFILE_SPECIFIER`, `CODE_SIGN_IDENTITY`, `PRODUCT_BUNDLE_IDENTIFIER` via `setting_value_from "$settings" KEY` (311–315). `grep -n 'grep "' scripts/release.sh` → only line 495 (`security find-identity … | grep "Apple Distribution" | grep "${RELEASE_TEAM_ID}" | head -1`), which filters identity output, not a build setting. `get_app_build_settings` (target-block awk + whole-output fallback) is unchanged.

Deviation from the Gate 1 wording: the helper is awk, not sed. The first implementation used `sed -n '/…/{…;p;q;}'`; the acceptance reviewer found that the `q` early-quit closes the pipe while `printf` is still writing the ~40 KB settings text, which under `pipefail` becomes a silent exit 141 in `check_project_signing` (reproduced: 4 of 9 suite runs failed one or two preflight tests with output truncated after "Checking project signing settings..."; isolated 1 MB producer with the key on line 1: 30/30 died). The awk consumer reads to EOF and prints only the first match. After the fix: 6 consecutive runs by the implementer and 8 by the reviewer, all `92 passed, 0 failed`; stress 0/30 and 0/64. This closes the flake rather than leaving a "flaky test" trail.

### Export (`scripts/release.sh:641-666`)

Live mode only (dry-run path unchanged): `find "$bdir" -maxdepth 1 -name '*.ipa' -print0` loop; 0 files → `die "export: found 0 .ipa files in ${bdir} after -exportArchive …"` (657); more than one → `die "export: expected exactly 1 .ipa in ${bdir} after -exportArchive, found N: …"` (660); exactly one → `mv` to `ChristmasTracker-<version>-<build>.ipa`, with a self-move guard `[ "$found_ipa" != "$ipath" ]` (663).

### install-info (`scripts/release.sh:1165-1182`)

Values block kept; then "This script never runs policy:set…" (1167); "Development database (backend repo):" + `npm run policy:set -- --platform ios --latest-build <b> --latest-version <mv> --recommended-version <mv> --notes "<edit: what changed in this build>" --manifest-url <url> --ipa-url <url>` (1170); "Production server (run on the server):" + `bash repo/deploy/scripts/compose.sh exec api node dist/scripts/policy-set.js --platform ios …same flags…` (1173); a WARNING block for the force-update variant with `--min-build N --minimum-version X.Y` unfilled (1176–1178); `--enabled true|false` mention; "The --manifest-url and --ipa-url values cannot be cleared once set; a later policy:set can only point them at another valid pair." (1182). The function is a single heredoc; nothing is executed.

### Runbook (`Docs/release-runbook.md`)

Step 7 (213–247): both commands with placeholders (226, 232), the accepted flag list including `--enabled true|false` (237), the force-update warning "only after every family phone has the new build" (241), the cannot-clear sentence (246–247). Rollback (284–298): rollback = point the policy at the previous build's manifest and IPA URLs; since the URLs cannot be cleared, rollback only ever sets them to another valid pair (290); server command with `<prev-build>` placeholders (295); "Never delete an uploaded build" kept.

### Test harness

- `FIXTURE_SETTINGS` constant with fail-fast (`scripts/test-release.sh:14`).
- `make_settings_fixture <dest> [KEY=VALUE…]` (288): copies the fixture; an existing anchored line is replaced; an absent key is inserted directly after the app-block header — so a spliced `EXPANDED_CODE_SIGN_IDENTITY` lands BEFORE `CODE_SIGN_IDENTITY`, exactly where `grep | head -1` would have picked it. `make_manual_settings_fixture` (309) applies the Manual-signing overrides the existing tests expect (`CODE_SIGN_STYLE=Manual`, `DEVELOPMENT_TEAM=TESTTEAM99`, `PROVISIONING_PROFILE_SPECIFIER=TestAdHocProfile`, `CODE_SIGN_IDENTITY=Apple Distribution: Test User (TESTTEAM99)`). `delete_setting` (322), `splice_settings_block … after|before` (333).
- `write_stubs` takes an optional 4th argument (settings file; default = a Manual-signing temp copy); its xcodebuild stub's `-showBuildSettings` branch is `cat "${settings_file}"` (388). `write_export_stub` (522) and `_make_archive_stub` (1630) also cat fixture copies. No hand-written settings text remains in the harness.
- Existing assertion changed (the only one): "install-info: no npm run command in output" → "install-info: development-database policy:set command present", now asserts the `npm run policy:set -- --platform ios` line IS present. Reason (comment at 1987): P3 — the backend operator doc confirmed the flag names. All other 61 earlier tests pass with unchanged meaning on fixture-derived stubs.

## Test arithmetic

62 (previous, including the inverted T18 in its slot) + 30 new = **92**. New tests, by section:

install-info policy:set recipe (15 executions, 14 new; T18's slot is the inverted one):
1. install-info: production-server policy-set.js command present
2. install-info: exactly two default command lines
3–8. install-info: both commands contain '--latest-build 500' / '--latest-version 5.0' / '--recommended-version 5.0' / '--manifest-url https://content.example.com/distribution/tracker/500/manifest.plist' / '--ipa-url https://content.example.com/distribution/tracker/500/ChristmasTracker-5.0-500.ipa' / '--notes' (one loop, six executions, each asserting both command lines)
9. install-info: default commands do not contain --min-build
10. install-info: default commands do not contain --minimum-version
11. install-info: cannot-clear sentence present
12. install-info: force-update warning present and unfilled
13. install-info: script states it never runs policy:set
14. install-info: recipe output has no secret-looking values
15. install-info: without --build the commands keep the <build> placeholder

anchored build-setting lookups (11):
16. anchored lookup: verify-ipa passes a good IPA named from PRODUCT_NAME via the fixture stub
17. anchored lookup: PRODUCT_NAME resolves to ChristmasTracker, not ChristmasTracker.app
18. anchored lookup: MARKETING_VERSION resolves to 5.0 from the fixture
19. anchored lookup: install-info names ChristmasTracker-5.0-500.ipa from the unmodified fixture
20. anchored lookup: CODE_SIGN_IDENTITY ignores EXPANDED_CODE_SIGN_IDENTITY (wrong real identity is reported)
21. anchored lookup: CODE_SIGN_IDENTITY ignores EXPANDED_CODE_SIGN_IDENTITY (wrong expanded identity is not reported)
22. anchored lookup: app-target block wins over a package block spliced after it (manifest names 5.0)
23. anchored lookup: app-target block wins over a package block spliced after it (preflight CODE_SIGN_STYLE OK)
24. anchored lookup: app-target block wins over a package block spliced before it (manifest names 5.0)
25. anchored lookup: app-target block wins over a package block spliced before it (preflight CODE_SIGN_STYLE OK)
26. mutation: stub emitting FULL_PRODUCT_NAME before PRODUCT_NAME still yields ChristmasTracker

export IPA discovery (4):
27. export: exactly one exported IPA is renamed to ChristmasTracker-5.0-500.ipa
28. export: zero exported IPAs fails with a clear message
29. export: two exported IPAs fails with a clear message
30. export: an IPA already named ChristmasTracker-5.0-500.ipa is kept without a self-move error

Mutation evidence (reviewer's scratch run, repo untouched): the new test suite against the HEAD `release.sh` → `58 passed, 34 failed`, including both CODE_SIGN_IDENTITY tests, the FULL_PRODUCT_NAME mutation test, "PRODUCT_NAME resolves to ChristmasTracker, not ChristmasTracker.app", every project-signing/device-count preflight test (`DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER` wins on the old code), the export tests and the recipe tests. The implementer's scratch run with only the helper reverted → 32 real failures. The old code fails the new tests; the anchored helper passes them.

## Commands and raw output

### Baseline on `master` before branching (Orchestrator, run)

```
=== verify: derived spec ===
=== verify: build ===
=== verify: configuration check ===
=== verify: unit tests ===
--- tests: 677 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
  Test run with 191 tests in 13 suites passed after 0.019 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 62 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`scripts/test-release.sh` standalone: `=== test-release.sh: 62 passed, 0 failed ===`

### Before the K1 commit (final tree, after the SIGPIPE fix; Orchestrator, run)

`bash -n "scripts/release.sh"` → no output, exit 0. `bash -n "scripts/test-release.sh"` → no output, exit 0. `shellcheck "scripts/release.sh" "scripts/test-release.sh"` (0.11.0) → no output, exit 0.

```
=== verify: derived spec ===
=== verify: build ===
=== verify: configuration check ===
=== verify: unit tests ===
--- tests: 677 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
  Test run with 191 tests in 13 suites passed after 0.015 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`scripts/test-release.sh` standalone (Orchestrator): `=== test-release.sh: 92 passed, 0 failed ===`. Implementer, 6 consecutive runs after the fix: all `92 passed, 0 failed`. Acceptance reviewer, 8 consecutive runs after the fix: all `92 passed, 0 failed`.

(An intermediate verify run on the pre-fix tree, before the acceptance review, was also 677 / 191 / 92 OK; the SIGPIPE flake did not trigger in that single run.)

### After the K1 commit

See the "Post-commit verification" section appended in the K2 docs commit (the output cannot be inside the commit it measures).

### `install-info --build 500 --dry-run` transcript (placeholder env, fixture-serving xcodebuild stub; Orchestrator, run)

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

   This script never runs policy:set. Copy one of the commands below, edit --notes, and run it yourself.

   Development database (backend repo):
   npm run policy:set -- --platform ios --latest-build 500 --latest-version 5.0 --recommended-version 5.0 --notes "<edit: what changed in this build>" --manifest-url https://content.bmalberta.com/distribution/tracker/500/manifest.plist --ipa-url https://content.bmalberta.com/distribution/tracker/500/ChristmasTracker-5.0-500.ipa

   Production server (run on the server):
   bash repo/deploy/scripts/compose.sh exec api node dist/scripts/policy-set.js --platform ios --latest-build 500 --latest-version 5.0 --recommended-version 5.0 --notes "<edit: what changed in this build>" --manifest-url https://content.bmalberta.com/distribution/tracker/500/manifest.plist --ipa-url https://content.bmalberta.com/distribution/tracker/500/ChristmasTracker-5.0-500.ipa

   WARNING — force-update variant (NOT filled in on purpose):
   Adding --min-build N --minimum-version X.Y blocks every build older than N on every phone.
   Raise it only after the new build is installed on every family phone. When you do, append:
     --min-build N --minimum-version X.Y
   (replace N and X.Y yourself; never paste this build's values here without checking every phone first).
   Other flags the command accepts: --enabled true|false.

   The --manifest-url and --ipa-url values cannot be cleared once set; a later policy:set can only point them at another valid pair.

4. Device verification steps:
   a. Tap the install link on a registered device (must be in the provisioning profile).
   b. In Settings → General → VPN & Device Management, verify the app shows version 5.0 (500).
   c. Launch the app and confirm it logs in against production (https://api.bmalberta.com).
   d. Check Sentry for a session event with the correct build number.
```

## Verification claims: run vs read

| Claim | How |
|---|---|
| 677 app / 191 package / 92 release tests, verify OK | run (Orchestrator, `scripts/verify.sh`) |
| `bash -n`, shellcheck clean | run (Orchestrator, implementer, both reviewers) |
| No unanchored setting grep remains | run (`grep -n 'grep "' scripts/release.sh` → line 495 only) and read |
| Fixture sanitized, 637 lines | run (greps above) and read |
| Helper semantics (anchored, first match, trimmed, empty on absent) | read by the Orchestrator and both reviewers; exercised by the acceptance reviewer on a sourced copy |
| SIGPIPE flake fixed | run (6 + 8 clean consecutive suite runs; stress 0/30, 0/64 on scratch copies) |
| Old code fails the new tests | run (reviewer's scratch run 58/34; implementer's 32 real failures) |
| install-info output | run (transcript above) |
| Export zero/one/two behaviour | run (tests 27–30) and read (lines 641–666) |
| Runbook text | read |

## Gate 2

Pipeline: solo implementer, then convention-reviewer, then acceptance-reviewer, strictly sequential.

**convention-reviewer — PASS** (first and only run). Checked: `set -euo pipefail` in both scripts; no eval/sudo/`sed -i`; `rm -rf` only on mktemp dirs under EXIT traps (`release.sh` trap, `test-release.sh:566`); BSD-safe sed/awk/find in changed lines; real team id absent from all four files; `check_project_signing` still prints `[set]` for DEVELOPMENT_TEAM and PROVISIONING_PROFILE_SPECIFIER; SENTRY_DSN still "value not printed"; `cmd_` set identical to HEAD; `dry_run_cmd` untouched and the export discovery is inside `if [ "$DRY_RUN" -eq 0 ]`; 62 earlier test names retained except the one inverted with a reason; scope exactly the four files. Informational, not blocking: pre-existing `\|` alternation in test-release.sh grep calls; pre-existing `got: '${code_sign_id}'` echo of the raw CODE_SIGN_IDENTITY on mismatch (not one of the two masked messages the brief requires); loop variable `f` in `cmd_export` not declared `local` (same pattern as `cmd_preflight`).

**acceptance-reviewer — REJECT, then PASS on re-review.**

First run: REJECT, one real bug — `setting_value_from` used `sed … q`; the early quit SIGPIPEs the `printf` producer under `pipefail` and preflight exits 141 silently. Evidence: 9 suite runs → 92/0 ×5, 91/1 ×2, 90/2 ×2, all failures preflight tests truncated after "Checking project signing settings..."; isolated 1 MB producer + key on line 1 → 30/30 rc=141, without `q` → 0/30. Routed to the implementer (attempt 2 of 3). Also an advisory (applied by the Orchestrator): mask `TARGET_DEVICE_IDENTIFIER` and the `/var/folders/<xx>/<hash>/` cache paths in the fixture.

Re-review: PASS, no residual routing. Confirmed the awk helper's semantics on a sourced copy (anchored; duplicates → first only; internal spaces kept; trailing whitespace trimmed; empty value → empty, no fall-through; absent key → empty rc 0; `KEY=VALUE` at column 0 works); `grep -n "sed -n\|head -1"` → only lines 495 and 719, both pre-existing small grep-filtered producers; 8 consecutive clean suite runs; stress 0/30 and 0/64; fixture masking confirmed, 0 hits for the identifying values.

Focus-list answers (acceptance reviewer, with evidence):
1. Every read goes through the anchored helper: `release.sh:288, 292, 311–315`; only remaining `grep "` is line 495 (identity output). Pattern `^[[:space:]]*KEY[[:space:]]*=` is anchored; internal spaces kept; absent key → empty, rc 0; whole-output fallback still returns the first anchored match (verified with a header-stripped stub: install-info named `ChristmasTracker-5.0-777.ipa`).
2. Fixture keeps the look-alikes (`FULL_PRODUCT_NAME` 251, `PRODUCT_MODULE_NAME` 438, `EXECUTABLE_NAME` 242, `WRAPPER_NAME` 612, `DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER` 166, `PROVISIONING_PROFILE_REQUIRED*` 451–453, `TARGET_NAME` 575, `DWARF_DSYM_FILE_NAME` 187) and the real single-block structure (header at 23); sanitized as listed above; nothing invented.
3. `write_stubs` xcodebuild stub `cat "${settings_file}"` (`test-release.sh:388`), default via `make_manual_settings_fixture` (309); `write_export_stub` (535) and `_make_archive_stub` (1630) likewise. Exactly one earlier test name removed/replaced (the inverted T18, reason at 1987); 62 + 30 = 92.
4. `EXPANDED_CODE_SIGN_IDENTITY` is inserted after the block header (`test-release.sh:299–300`), i.e. before `CODE_SIGN_IDENTITY` at fixture line 123, the exact `grep|head -1` trap; `splice_settings_block … before` puts the conflicting block ahead of the file (349–351); both orders exercised for manifest version and preflight CODE_SIGN_STYLE; the mutation test puts `FULL_PRODUCT_NAME` first and `PRODUCT_NAME` last. New tests against the old script: 58/34.
5. Export: `release.sh:641–645` list, 657 zero, 660 more-than-one, 663 self-move guard; dry-run path unchanged; tests 27–30.
6. install-info: both commands (1170, 1173) with the computed build/version/URLs; force-update block unfilled (1176–1178); cannot-clear sentence (1182); never-runs line (1167); heredoc only, nothing executed; verified live with `--build 777`.
7. `dry_run_cmd` runs `"$@"` only when DRY_RUN=0; every test invocation sets `RELEASE_XCODEBUILD`, preflight/verify-ipa/all set `RELEASE_SECURITY`, upload sets `RELEASE_AWS` or `--dry-run`; real tools touched by the harness are read-only (`plutil`, `zip`, `git check-ignore`, `date`). No path runs archive, export, aws, signing, or policy:set under test or `--dry-run`.
8. Runbook step 7 and Rollback match the script output (lines 226, 232, 237, 241, 246–247, 290, 295).
9. `git status --porcelain`: ` M Docs/release-runbook.md`, ` M scripts/release.sh`, ` M scripts/test-release.sh`, `?? scripts/fixtures/` — nothing outside the permitted files.

Stuck-detector log: implementer attempt 1 (initial), attempt 2 (SIGPIPE fix) — accepted. No repeated error signature. Convention review 1 run; acceptance review 2 runs (REJECT → PASS).

## Deviations from the prompt and the brief

1. The committed fixture is single-block and lacks `EXPANDED_CODE_SIGN_IDENTITY` and `PROVISIONING_PROFILE_SPECIFIER`, because that is what real `-scheme` output contains today. The prompt asked for those in the fixture; its own fallback ("tests override per case in a temp copy; do not invent values in the committed file") was followed instead. Tests splice them.
2. The helper is awk, not the sed form sketched in the spec (reason: the SIGPIPE bug above).
3. Two extra sanitizing replacements beyond the prompt's list (`TARGET_DEVICE_IDENTIFIER`, `/var/folders` per-user hash), on the acceptance reviewer's advice.
4. `CODE_SIGN_IDENTITY = Apple Development` was kept rather than replaced with a fake Distribution identity: it is a generic Xcode constant, not an identity name, and replacing it would have made the committed fixture claim signing is configured when it is not.

## Real bugs found

- The sed early-quit SIGPIPE race in the first `setting_value_from` (fixed before commit). Note for Brian: the old `grep "KEY" | head -1` had the same shape but a tiny producer, so it never tripped.
- Pre-existing and out of scope (not fixed): `check_project_signing` echoes the raw `CODE_SIGN_IDENTITY` on mismatch (`got: '…'`); harmless with Xcode's generic values but could print a certificate name. Flagged for a later pass.

## Not done or partial

NOT RUN by the agents (stubs and fixtures only): `xcodebuild archive`, `xcodebuild -exportArchive`, any `aws` command, the real certificate lookup in a keychain (`security find-identity`), the real profile lookup in `~/Library/MobileDevice/Provisioning Profiles`, `codesign` against a real identity, any signing, any upload, `policy:set` in either form, and any on-device install. The only real xcodebuild invocation in this package was the read-only `-showBuildSettings` capture. The post-commit verify output for this commit is recorded in the K2 docs commit.

## Resume check (after interruption and the toolchain upgrade)

Date: 2026-11-09. The Mac rebooted and the toolchain moved to Xcode 27 (package T1 merged into this branch). Re-verification of the uncommitted K1 tree:

- `bash -n` on `scripts/release.sh` and `scripts/test-release.sh`: clean. `shellcheck` on both: clean.
- `scripts/test-release.sh` three runs in a row: `=== test-release.sh: 92 passed, 0 failed ===` each time.
- `scripts/verify.sh` (no DEST prefix), raw summary lines: `=== verify: derived spec ===`, `** BUILD SUCCEEDED **`, `=== verify: configuration check ===`, `--- tests: 677 passed, 0 failed, 0 skipped ---`, `Test run with 191 tests in 13 suites passed after 0.017 seconds.`, `=== verify: TrackerAPI import audit ===`, `=== test-release.sh: 92 passed, 0 failed ===`, `=== test-destination.sh: 17 passed, 0 failed ===`, `=== verify: prohibited frameworks in changed lines ===`, `=== verify: OK ===`.
- Identifier scrub: see "Fixture sanitization" (no matches in the five paths).

acceptance-reviewer (resume check, one run): **PASS**, no routing. Confirmed the tree matches this report: anchored awk helper at `release.sh:268-285` with every read going through it (288, 292, 311–315; remaining `grep` calls at 450 and 495 do not read build settings); export discovery at 644–668 inside the live-mode branch only (zero 656–657, more than one 659–660, self-move guard 663); install-info recipe 1167–1182; runbook step 7 (213–247) and Rollback (284–298) match the script output; fixture sanitized (637 lines, placeholders at 177, 571, 79–80, and only `/Users/test` paths); pattern searches of all five paths found no real team id, user path, folder hash, or UUID; 92 tests passed on the reviewer's own run; the only removed assertion against HEAD is the documented T18 inversion. Minor note: some cited line numbers are loose by 1–3 lines (helper cited as 257–285 in the file table; the function body is 268–285).
