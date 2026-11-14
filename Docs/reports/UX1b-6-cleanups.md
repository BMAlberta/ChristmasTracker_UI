# UX1b Story B6: Cleanups

Branch: feat/ux1b-dialogs-colors-and-polish. Three commits: (a)+(b)+(c) comment-only; (d) dead error message properties; (e) unused ItemPermissions property. Pipeline: full per commit (implementer, convention-reviewer, acceptance-reviewer). Sections for (d) and (e) are appended below as they are done.

## Part (a)+(b): comment-only commit

### What changed
- (a) 50 test files: every stale "Fails today because ..." header sentence was rewritten to one accurate line ("Covers ..." for behavior tests, "Scans ..." for the four text-scan tests). Files in Core, DesignSystem, Features/Lists, Features/Items, Features/Purchases (the full list is the diff; 50 files matched the grep "fails today|currently fail"). No "Fails today" or "currently fail" remains in the test target (grep).
- (b) Stale comments corrected, found by the earlier reviews and by the Gate 2 follow-up (each checked against the code by the reviewer):
  - Features/Children/Repositories/GeneratedClientChildRepository.swift (deleteChild 422 case): now says a list of the child is still ACTIVE or DRAFT, that ChildDeletionFlow archives those first, and that archived lists do not block (was "the child still has lists").
  - Features/Children/Repositories/MockChildRepository.swift line 7: "a child with an ACTIVE or DRAFT list cannot be deleted".
  - ItemErrorTests.swift (legacy cases sentence dropped: no such cases exist), App/BootstrapResolutionTests.swift, Authentication/SessionTeardownTests.swift, InactivityLockPresenterTests.swift ("does not exist yet" blocks removed or rewritten; the types exist), Authentication/FirstLaunchWipeTests.swift and LogoutPathTests.swift ("Expected failure state BEFORE ... implementation" blocks and the "FAILS before ..." / "Requires R1 ..." doc comments removed or rewritten).
- (c) NOT changed, banked. The orphaned Keychain item left by the deleted DeviceFIngerprintService (deleted in f57fd28) is the UUID stored under the key `"com.christmastracker.deviceFingerprintUUID"` through `KeychainService.set(..., accessControl: .afterFirstUnlock)` (read from the last version of the deleted file; KeychainService's own service name was not inspected, so the exact service/account split is not recorded here). The existing first-launch wipe (Features/Authentication/Services/FirstLaunchWipe.swift) is a class-wide delete of all generic and internet passwords (once, on a clean install), not a plain list of items, so the story's precondition is not met; the separate LegacyTokenCleanup list names the biometric and session tokens and must not be touched. So an app that was upgraded from a build that stored this UUID keeps one harmless orphan item until the app is deleted and reinstalled. Nothing under Features/Authentication/Services or Core/Security changed (git diff stat is empty there; the biometric refresh-token item is untouched).

### Comment-only proof (raw, from running the command)
```
$ git diff -U0 -- "*.swift" | grep -E '^[+-][^+-]' | grep -v -E '^[+-][[:space:]]*//'
(no output)
$ git diff -U0 -- "*.swift" | grep -c DispatchQueue
0
$ git diff --stat | tail -2
 Docs/reports/UX1b-5-children-try-again.md          |  2 +-
 59 files changed, 72 insertions(+), 123 deletions(-)
```
(The non-Swift file in the diff is the B5 report's after-commit verify line; this report is untracked at that moment.)

### Files
Changed: 57 Swift files (2 Children repository files, 55 test files), all comment lines; Docs/reports/UX1b-5-children-try-again.md (after-commit verify line). Added: this report. Deleted: none. No test code changed; no test count change.

### Test arithmetic (app suite)
4398 + 0 new - 0 deleted = 4398. Measured by scripts/verify.sh: 4398. Package 212, release scripts 92, destination scripts 17.

### Raw output (from running commands)
Before commit:
```
--- tests: 4398 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
After commit: see the line added at the end of this section after the commit run.

### Gate 2 ((a)+(b)+(c))
- convention-reviewer: APPROVE (comment-only check empty; no .claude/.pbxproj/contract/LocalPackages/synced Docs; one 127-character comment line, wrapped afterwards).
- acceptance-reviewer: APPROVE with follow-ups: it sampled 12 files and found the four scan tests' "Covers" wording misleading (text scans, not behavior) and named four more stale comments; both were fixed by the implementer in a follow-up round (comment-only, re-checked empty by the Orchestrator). Both Children repository comments verified accurate against ChildDeletionFlow.swift and MockListRepository. Keychain decision confirmed.
- Stuck detector: none.

### Not done or partial (this part)
- The "Covers" lines were written from each file's old header; the acceptance-reviewer verified 12 files against test names and bodies, the other ~38 only against the type names. A line may be incomplete (for example ListMappingTests omits ListRole/ListStatus/ListVisibility) but none was found wrong.
- Other "does not exist yet" wording may remain in test files outside the files named by the reviews; the assertion message strings in MembersChildrenViewScanTests (lines ~286, 306, 329: "Features/Children/Views does not exist yet") are runtime failure messages, not comments, and were left.
- (c) banked as above.
