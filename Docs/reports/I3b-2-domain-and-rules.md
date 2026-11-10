# I3b-2: Domain models, errors, and pure rules (story M1)
Date: 2026-11-09. Branch feat/i3b-members-children. Path: full pipeline (isolated test-writer, implementer, convention-reviewer, acceptance-reviewer).

## Previous commit (K0, 2d4baec), after (source: command run)
```
** BUILD SUCCEEDED **
--- tests: 1010 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
(verify output filtered with grep to its summary lines; the full stream was run.) The package suite was untouched by K0 and is re-run below.

## What changed
Pure, `nonisolated`, Sendable types with no wire types, no SwiftUI import and no logging:
- **Domain** (`Core/Models/MemberInputs.swift`, `Child.swift`): `MemberRole` (typealias of the existing `ListMemberRole`, now `CaseIterable`, with `title`), `AddMemberInput`, `CoOwnerChange {unchanged, set(email:), clear}` and `UpdateListInput.coOwner` (defaulted `.unchanged`; existing call sites compile), `ChildRelationship {parent, guardian, caretaker}`, `Child` (+`shownName`), `CreateChildInput`.
- **Mapping**: `mapMemberSummary` (the former private mapper, now internal; `mapListDetail` uses it), `mapChild(id:firstName:lastName:displayName:relationshipRaw:)` in `Features/Children/ChildMapping.swift` (nil for an unknown relationship; the createChild response carries a plain String).
- **Errors**: `ListError` + `memberEmailNotFound`, `alreadyMember`, `membershipNotFound` (plain fixed messages; not retryable; no screen exit); `ChildError` (10 cases) + `ChildErrorPresentation` (`Features/Children/ChildError.swift`). Every switch over these is exhaustive with no `default`.
- **View-state**: `MembersSectionState`/`MemberRowState`/`MemberRowKind` (roster shown only when `canSeeMembers` and members present; ACTIVE rows only; Add = `canManageMembers`; Leave = `canLeaveList`; per-row Remove = `canManageMembers` and the row is not the owner or co-owner, identified by the detail's person ids; no email in rows or labels), `MemberRemoveConfirmation`, `LeaveListConfirmation`, `AddMemberFormValidation`; `CoOwnerSectionState` (`clearingSupported = false`, so `showsRemove` is always false; comment cites the generated `String?` payload that omits nil), `CoOwnerFormValidation`; `ChildrenState`, `ChildrenLoadPhase`, `ChildFormValidation` (first/last 1 to 100, display name blank or 1 to 200, trimmed), `CreateListRecipientOptions` ("For me" first and always present, soft failure); `ListFormValidation.makeUpdateInput(... coOwner:)`.
- The only reader of a roster row's membership `.role` is `Features/Lists/ViewState/MembersViewState.swift` (plus one temporary allowlisted line in `ListDetailView.swift`, guarded by a test that fails when M3 removes the need). No new file mentions `myRole`.

## Files
Added (production): `Core/Models/MemberInputs.swift`, `Core/Models/Child.swift`, `Features/Children/ChildMapping.swift`, `Features/Children/ChildError.swift`, `Features/Children/ViewState/ChildrenViewState.swift`, `Features/Lists/ViewState/MembersViewState.swift`, `Features/Lists/ViewState/CoOwnerViewState.swift`.
Changed (production): `Core/Models/ListDetail.swift`, `Features/Lists/Repositories/ListMapping.swift`, `Features/Lists/Repositories/ListRespository.swift`, `Features/Lists/ViewState/ListViewState.swift`, `Features/Lists/Services/ListService.swift` (one exhaustive-switch case list).
Added (tests, under ChristmasTrackerTests): `Features/Lists/MembersFixtures.swift` (helpers), `Core/MemberDomainTests.swift`, `Core/ChildModelTests.swift`, `Features/Lists/MemberMappingTests.swift`, `Features/Children/ChildErrorTests.swift`, `Features/Children/ChildErrorPresentationTests.swift`, `Features/Lists/MembersSectionStateTests.swift`, `Features/Lists/MembersTruthTableTests.swift`, `Features/Lists/MemberConfirmationTests.swift`, `Features/Lists/CoOwnerSectionStateTests.swift`, `Features/Lists/CoOwnerFormValidationTests.swift`, `Features/Lists/AddMemberFormValidationTests.swift`, `Features/Children/ChildFormValidationTests.swift`, `Features/Children/ChildrenStateTests.swift`, `Features/Children/CreateListRecipientOptionsTests.swift`, `Features/Lists/ListUpdateInputCoOwnerTests.swift`, `Features/Lists/MembersSourceScanTests.swift`.
Changed (tests, additive only): `ListErrorTests`, `ListErrorPresentationTests`, `ListScreenExitTests`, `ListSourceScanTests` (scope now includes `Features/Children` and `Features/Profile`).
Deleted: none.

## Truth table and how it was reduced
`MembersSectionState` and `CoOwnerSectionState` depend on four flags (canSeeMembers, canManageMembers, canLeaveList, canSetCoOwner), members present or absent, and co-owner present or absent. `MembersTruthTableTests` enumerates all 16 flag combinations x 2 x 2 = 64 cases against an independently written oracle, with `myRole` varied per case to prove it is ignored, plus seven named personas as concrete fixtures (blind owner/recipient of a self list T,T,T,F; co-owner T,T,F,F; blind co-owner T,T,F,F; MEMBER-role member T,F,F,T; VIEWER-role member F,F,F,T; PUBLIC non-member F,F,F,F; archived list), and a test that a members array in the model alone never grants the roster. No reduction beyond ignoring the gift flags, which these functions never read.

## Test arithmetic (from running the suite; per-file counts)
1010 + 157 new - 0 deleted = 1167 (runner reports 1167). New 157 = 155 in the new files (MemberDomain 8, ChildModel 8, MemberMapping 12, ChildError 11, ChildErrorPresentation 4, MembersSectionState 24, MembersTruthTable 3, MemberConfirmation 8, CoOwnerSectionState 8, CoOwnerFormValidation 6, AddMemberFormValidation 7, ChildFormValidation 13, ChildrenState 15, CreateListRecipientOptions 15, ListUpdateInputCoOwner 8, MembersSourceScan 5) + 2 in `ListErrorTests` (exact strings, errorDescription). Edited additively without count change: ListErrorPresentationTests (three rows), ListScreenExitTests (case list 12 to 15), ListSourceScanTests (wider scope). Parameterized tests count as one. Package suite 212 + 0 = 212.

## Gate 2
- Convention-reviewer: APPROVED, no warnings needing routing (nit: `AddMemberFormValidation.validate(email:role:)` does not use `role`; the tests call it that way).
- Acceptance-reviewer: APPROVED. Notes carried forward (below).
- Stuck detector: no rejection; the implementer's first build failed once on `nonisolated` applied to a typealias (a different error afterwards, not a repeat).

### Focus-list answers (M1-relevant)
5. Flags: `MembersViewState.swift:58-79` (roster = canSeeMembers via `ListPermissions.showsMembersSection` and members non-nil; Add = canManageMembers; Leave = canLeaveList; row Remove = canManageMembers and kind member or viewer), `CoOwnerViewState.swift:26-27`. No `myRole` in any new file (grep and `MembersSourceScanTests`). Roster hidden for viewers and PUBLIC non-members even with a members array present (`MembersTruthTableTests`).
10. Children's names and ids: no logging in any new file (grep for Log, print, os_log found nothing); the row accessibility label contains the display name and role only, no ids or emails.
13. `git diff --stat`: nothing under `contract/`, `.claude/`, any `.pbxproj`, synced Docs, or `LocalPackages/TrackerAPI`.

### Carried forward to M2 and M3 (from the acceptance review)
1. `makeUpdateInput` returns a non-nil input for `coOwner == .clear`; M2's repository MUST refuse `.clear` with a typed error (never send an empty PATCH) and have a test.
2. `ListDetail.applying` ignores `coOwner`; the mock repository handles `.set` itself (coOwner and flags on the result).
3. M2 must map 4006 and 4009 to their own cases before the generic 404; decide what a leave that returns 4006 does (drop the list or refetch) and record it.
4. `CreateListInput` has no `coOwnerEmail` (create-time co-owner is not in scope).
5. M3 must reset the visible recipient picker selection to "For me" if the selected child disappears (a reload failure), so a list is never created for a different recipient than the one shown.
6. The roster may or may not contain the owner row (the guide does not say); the state is safe either way, and M3 may show the owner separately if absent.
7. `GET /lists/{id}/members` is not used (the roster comes from the detail).

## Verification before the M1 commit (source: command run, grep-filtered summary lines)
```
** BUILD SUCCEEDED **
check-config: all configuration values OK
--- xcodebuild exit status: 0 ---
--- tests: 1167 passed, 0 failed, 0 skipped ---
check-package-imports: OK
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
Package: `Test run with 212 tests in 16 suites passed after 0.017 seconds.`
After the commit: recorded at the top of Docs/reports/I3b-3-repositories-and-services.md.

## Deviations, bugs, scope
- Deviation: a temporary allowlist entry for `ListDetailView.swift` (it reads `member.role.displayName`) in `MembersSourceScanTests`; the guard test `allowlistEntriesStillNeeded` fails once M3 rebuilds that view, forcing removal.
- `MemberRole` is a typealias, so `title` is an extension on `ListMemberRole` (a typealias cannot be `nonisolated`).
- The 254-character email cap is not in the spec (harmless).
- Real bugs found: none.

## Not done or partial
- No repository, service, screen or contract-issues row yet (M2, M3). Nothing was run in the simulator.
