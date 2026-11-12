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
- The fifteen real-mode steps were not run and are a draft (Deviations 1). SUPERSEDED by the addendum below: the steps now follow Story D word for word; they are still NOT PERFORMED.
- No simulator screenshot of the new screen exists anywhere in the package.

## Addendum: use the specified real-mode steps (commit "I4a: use the specified real-mode steps in the handoff")
Docs only. Files changed: `Docs/handoffs/2026-11-12-ios-to-brian-i4a.md` and this report. Nothing else.

What changed in the handoff:
- "Brian's real-mode check": the draft NOTE and the draft list were replaced by the fifteen steps of Story D of the package prompt (prompts/mobile-ui/I4a-record-purchase.md), word for word, numbered 1 to 15 (the "(n)" markers became "n."; the step text, including its trailing semicolons, is unchanged). The intro sentence about the local backend and the seeded users and the scope reminder are kept.
- "Which checks were run": step references updated to the new list; all fifteen NOT PERFORMED.
- "Open risks" and "What the API team must do": the delete-purchase statements now say that the API chat has since decided S14 (DELETE /purchases/{id}, operationId deletePurchase, purchaser only, a hard delete that returns the deleted purchase with its item reference; PATCH /purchases/{id} accepts only notes and trackingNumber, a notes clear is an empty string; shipping through PATCH /purchases/{id}/shipping), the contract commit is not named yet and I4b will sync at it.
- "What changed": one line noting that the section was corrected after the session was cleared.
- Two consequential fixes outside the listed places, because they would otherwise contradict the new text: the L16 bullet in "Contract issues found" pointed at real-mode step 13 and now says step 11 (archived lists in the new list); the PROGRAM.md section 9 line said "no delete-purchase operation in the spec" and now says S14 decided, commit not named, I4b syncs at it.

Verify before the change (working tree clean, HEAD 0817892), run from the repo root, summary lines:
```
=== verify: derived spec ===
=== verify: build ===
=== verify: configuration check ===
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 2523 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 212 tests in 16 suites passed after 0.019 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"` before the change:
```
􁁛  Test run with 212 tests in 16 suites passed after 0.018 seconds.
```
Test arithmetic: no test added, changed or deleted: app 2523, package 212, release-script 92, destination-script 17.

Verify after the commit: a report cannot contain the result of the commit that adds it; the after-commit run is in the final message of this session.
