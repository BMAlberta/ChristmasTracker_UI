# I3a-1: Regenerate from contract revision 26 and adopt C17

Branch feat/i3a-lists. Gate 1: Docs/epics/I3a-lists.md (H1). Path: full pipeline (generated-client layer).

## What changed
- scripts/make-client-spec.sh (write mode) regenerated LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json. Output: `Transformed 5 null-schema properties.` The guard (TRANSFORM_EXPECTED_COUNT=5, script line 11) held, so no guard or pin test changed. Verified by running the command.
- The regenerated spec adds: six required booleans on ListSummary (canSeeMembers, canEditList, canDeleteList, canManageMembers, canSetCoOwner, canLeaveList), a description on optional ListDetail.members, a 422 on updateList, and an optional `rememberMe` on the login request. `rememberMe` is regeneration output from contract/openapi.json (not hand-added); the auth repository was not changed to use it. (Source: spec diff, read by the convention and acceptance reviewers; I did not diff it against contract/openapi.json myself.)
- Flags live on `ListSummary.value1` (the allOf base), and for a detail as `detail.value1.value1.<flag>` (test-writer finding, from reading the generated sources).
- C17: `classifyErrorCode` (TrackerAPIError.swift): 1008 and 4002 -> .reLogin; 4011 -> .notFound; 4001, 4003 to 4007, 4010 unchanged .notFound. isCredentialFailure, the SessionEndingMiddleware and the login mapping are unchanged.
- The app needed NO compile fixes (scripts/build.sh succeeded). No code in ChristmasTracker/ or the package Sources calls getUser, listLists, getList, createList, updateList or deleteList today, so no existing switch over those Output types exists; the exhaustive switches for them are written in L2. classifyErrorCode has no caller outside the package.

## Files
Changed: LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json; Sources/TrackerAPI/TrackerAPIError.swift; Tests/TrackerAPITests/{DecodingTests,TrackerAPIErrorTests,SessionEndingMiddlewareTests}.swift.
Added: Tests/TrackerAPITests/OperationResponseTests.swift.
Deleted: none (one test deleted, see below).

## Test arithmetic
Package: 191 + 13 added - 1 deleted = 203 (final run `Test run with 203 tests in 14 suites passed`).
- Fixed fixtures (same meaning, six booleans added): decodeListSummaryNullCoOwner, decodeListSummaryNonNullCoOwner, decodeListSummaryAllOf (also asserts the new flags), decodeListDetailAllOf.
- Added: decodeListDetailWithoutMembers; classify1008ReLogin; classify4011NotFound; personNotFoundDoesNotCallHandler (parameterized, one entry); userNotFoundStillCallsHandlerOnListAndUserOperations; accountDisabledStillCallsHandlerOnListAndUserOperations; factoryGetUser404PersonNotFoundDoesNotCallHandler; factoryGetUser404UserNotFoundCallsHandler; factoryGetUser403AccountDisabledCallsHandler; factoryGetList404PersonNotFoundDoesNotCallHandler; factoryGetListSessionEndingCodesCallHandler; getUserPersonNotFound and updateListCannotEditArchivedList (OperationResponseTests). That is 13 added.
- Rewritten: classify4002NotFound -> classify4002ReLogin (the old test asserted the behavior C17 replaces).
- Deleted: classify1008ShowMessage (asserted 1008 -> showMessage, which contradicts the synced error-codes.md row 1008 re-login).
- 191 + 13 added - 1 deleted = 203 (the rewrite is neutral).
App: 677 before, 677 after (verify.sh: `--- tests: 677 passed, 0 failed, 0 skipped ---`). No app test changed.

## Raw outputs
Before (P3, command run): `ERROR: Derived spec is out of date. Run scripts/make-client-spec.sh to regenerate.` / `=== verify: DERIVED SPEC OUT OF DATE ===`. Package before changes: `Test run with 191 tests in 13 suites failed ... with 1 issue` (the derived-spec conformance test).
After (commands run by the Orchestrator):
```
Test run with 203 tests in 14 suites passed after 0.017 seconds.
=== verify: derived spec ===
=== verify: build ===
=== verify: configuration check ===
=== verify: unit tests ===
--- tests: 677 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
(The summary lines above are grep-filtered from the full verify output for the verify run; the test and verify runs happened before the commit. A second run after the commit is recorded below.)

## Gate 2
- Convention-reviewer: APPROVED. No findings. Warning: the login-403 administrator message is not covered by this diff; confirmed below by the acceptance review.
- Acceptance-reviewer: APPROVED. Evidence: guard at script line 11; classification diff; SessionEndingMiddleware unchanged and keyed on (403, ACCOUNT_DISABLED) and (404, USER_NOT_FOUND) by code string so 4011 is ignored for every operation including getUser; login 403 maps by status in GeneratedClientAuthenticationRepository.swift:56-57 to AuthErrorMessages.swift:14-15, covered by AuthenticationServiceTests.swift:376-377 and AuthErrorMappingTests.swift:32 (code read by the reviewer, not changed here).
- Rejections: none. Stuck-detector log: no retries.

## Focus-list answers (from the Gate 1 and brief)
1. Guard held (command). No switch over the new operations exists yet (grep by reviewer).
2. Classification, middleware and login: see Gate 2 (tests run; login by reading code and existing tests that pass in verify).
14. Only the package files listed above changed (git status).

## Deviations, bugs, scope
- The test-writer deleted classify1008ShowMessage in addition to rewriting 4002; named above.
- Backend commit in contract/VERSION is 8109ef3 (sync commit message says 4193c78); the checksum matches. Noted, not acted on.
- The H1 spec text said the inventory would paste generated signatures after regeneration; they are recorded in the L1 and L2 Gate 1 sections.

## Not done or partial
- The first-run login 403 behaviour was verified by existing tests and code reading only; no real-server check (Brian's handoff step).
- The post-commit verify.sh and package run are appended in the commit step below.
