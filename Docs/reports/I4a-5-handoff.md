# I4a-5: Handoff and the real-mode check (docs only)

Branch: feat/i4a-record-purchase. Pipeline: solo, docs only (no new interface); Gate 2 convention-reviewer. Gate 1 spec: Docs/epics/I4a-record-purchase.md, section "Story D".

## What changed
- Added `Docs/handoffs/2026-11-12-ios-to-brian-i4a.md` with the sections of the earlier handoffs: contract issues found, what changed, commits, what the API team must do, log hygiene carried to I4b, legacy that remains, open risks, the line for section 9 of PROGRAM.md, and "Brian's real-mode check" (fifteen steps) with a "Which checks were run" list.
- Added this report. Nothing else changed; no production code, test, contract, .claude, .pbxproj, synced Docs or LocalPackages file was touched.

## Deviations and decisions
1. THE FIFTEEN STEPS ARE A DRAFT. The epic says the check has "the fifteen steps exactly as specified" in the package prompt. That prompt was not on disk and the session had been cleared, so the specified list was not available. The steps in the handoff were written by the iOS run from the brief, the budget flow and the seeded users of the I3c check, and the handoff says so at the top of the section. Brian should replace them with the original list if it differs.
2. Step 5 depends on how to configure a budget on the backend, which the iOS run did not verify; the step points at the backend's Docs/local-development.md.
3. The spec has no delete-purchase operation: noted as an I4b risk, as the epic required.
4. All checks are marked NOT PERFORMED; none was run against a real server.

## Tests and raw output
No code changed in this story: the app suite stays at 2523 passed, the TrackerAPI package at 212. After-commit `scripts/verify.sh` for the Story C commit (d8854ec, after the amend described in Docs/reports/I4a-4-record-purchase-screen.md, item 9b), summary lines, taken before this docs commit:
```
=== verify: derived spec ===
=== verify: build ===
=== verify: configuration check ===
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 2523 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 212 tests in 16 suites passed after 0.020 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
The verify run for this docs commit itself is reported in the final message of the package (a report cannot contain the result of the commit that adds it).

## Gate 2
- convention-reviewer: APPROVE, no hard blocks, no required changes. Checked: only the two Docs files changed; the handoff has the required sections and the layout of the I3c handoff; the commit list and the shortstat match `git log --oneline master..HEAD` and `git diff master...HEAD --shortstat`; the test counts (2089, 2209, 2402, 2523, 212, 92, 17) and deltas agree with reports I4a-1 to I4a-4; the delete-purchase gap is noted as an I4b risk; "Not done or partial" is honest; the real-mode steps are labelled as a draft; no secrets (only the seeded-user addresses of earlier handoffs). Nits: the revision 31 versus 32 wording (addressed in the handoff header) and recording this verdict durably (done here).
- Rejections: none. Stuck-detector log: no triggers.

## Not done or partial
- The fifteen real-mode steps were not run and are a draft (Deviations 1).
- No simulator screenshot of the new screen exists anywhere in the package.
