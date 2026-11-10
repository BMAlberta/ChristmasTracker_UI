# I3b-3: Generated member and child repositories, session-safe services, mocks (story M2)
Date: 2026-11-09. Branch feat/i3b-members-children. Path: full pipeline (isolated test-writer, implementer, convention-reviewer, acceptance-reviewer).

## Previous commit (M1, 6614f25), after (source: command run, grep-filtered summary lines of the full stream)
```
** BUILD SUCCEEDED **
--- tests: 1167 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
The package suite was untouched since the last run (212 tests, re-run below).

## What changed
- **`MemberRepository` / `GeneratedClientMemberRepository`**: `addMember` (201 mapped through `mapMemberSummary`) and `removeMember` (leave is the same call with the caller's own user id). Every Output case is listed with no `default`: 400 validation message (plain fallback), 401, 403, 404 (MEMBER_EMAIL_NOT_FOUND 4009 on add and on the co-owner update, MEMBERSHIP_NOT_FOUND 4006 on remove, anything else `notFound`; the two codes are cross-gated per operation), 409 (5004) `alreadyMember`, 429 and a thrown `TrackerAPIError.rateLimited`, 500, undocumented (5xx `server`, otherwise `invalidResponse`), decoding `ClientError` `invalidResponse`, transport `network`, `CancellationError` rethrown. `@Instrumented` on the async throws functions.
- **`ChildRepository` / `GeneratedClientChildRepository`** (`Features/Children/Repositories`): `fetchChildren`, `createChild` (body: firstName, lastName, relationshipType always; displayName only when non-nil), `deleteChild` (422 with 6501 or CANNOT_DELETE_RESOURCE `childHasLists`, any other 422 `validation`). An unknown relationship string maps to `invalidResponse`.
- **Co-owner through `updateList`**: `.set(email)` sends `coOwnerEmail`; `.unchanged` sends none; **`.clear` is refused before any request** with `ListError.validation("Removing the co-owner is not available yet.")` (no request, no empty PATCH). createList still sends no `coOwnerEmail`. Clearing evidence and the contract question: Docs/contract-issues.md row 2 (filed in this story): the generated `coOwnerEmail` is a plain `String?` with synthesized `Codable` (no custom `encode(to:)`), so a nil is omitted and JSON null cannot be sent.
- **`ListService`**: `init(repository:memberRepository: any MemberRepository = InertMemberRepository(), dataStore:)`; `addMember`, `removeMember` (both refetch the detail via the repository, never splice the add response; mutation OK + refetch failure returns normally and sets `error`), `leaveList` (drops the list from `lists`, the cache, `currentListDetail`, the deleted-ids guard and sets `goneListId` so the detail screen leaves), `setCoOwner` (delegates to `updateList`, uses the returned detail). A `.membershipNotFound` on leave drops the list locally (the caller is no longer a member) and rethrows; on remove it best-effort refetches and rethrows. `.notFound`/`.archivedReadOnly` drops the list as in I3a. All methods use `isMutating` and the session generation guard.
- **`ChildService`** (`@MainActor @Observable`, `SessionClearable`): children, phase, `isMutating`, error; `loadChildren`, `addChild`, `deleteChild` (removes locally on success and on `childNotFound`; keeps the child on `childHasLists`), generation + cancellation, nothing written after teardown, `clearForSession` empties everything and returns to `.idle`.
- **Composition**: `AppDependencies` gains `memberRepository` and `childRepository` (makeMock shares ONE `MockListRepository` with the member and child mocks; makeReal uses the generated repositories; makeInert uses `InertMemberRepository`/`InertChildRepository`); `ChildService` is built in the App init, injected through `EnvironmentValues+ChildService` (default from `InertChildRepository`, never a Mock), and registered as the **7th** clearable (appended after the lock controller).
- **Mocks**: `MockMemberRepository`/`MockChildRepository` over shared state in `MockListRepository` (new helpers there): unknown email, already a member, add/remove visible in the detail only where `canSeeMembers` is true and `memberCount` follows, owner/co-owner removal forbidden, unknown member `membershipNotFound`, leave removes the list, co-owner `.set` with a small fake directory, `.clear` refused like the real repository, seed child "Tommy D." with a list (`childHasLists`), a child's list is not blind. The mock child and list were renamed from "Charlie" to "Tommy" (one leftover cosmetic id string `mock-child-charlie`).
- Pinned count: `makeProductionClearables` returns **7** (was 6), reason: a new session-scoped store (`ChildService`) holds the signed-in user's children and must be cleared at teardown. Updated in `InactivityLockIntegrationTests` (`productionClearablesReturnsSevenItems`) and `SessionTeardownTests`; all index assertions are unchanged.

## Files
Added (production, under ChristmasTracker/ChristmasTracker): `Features/Lists/Repositories/{MemberRepository,GeneratedClientMemberRepository,MockMemberRepository}.swift`, `Features/Children/Repositories/{ChildRepository,GeneratedClientChildRepository,MockChildRepository}.swift`, `Features/Children/Services/ChildService.swift`, `Core/Extensions/EnvironmentValues+ChildService.swift`.
Changed (production): `Features/Lists/Repositories/{GeneratedClientListRepository,MockListRepository}.swift`, `Features/Lists/Services/ListService.swift`, `App/InertRepositories.swift`, `Features/Authentication/Services/SessionClearable.swift`, `ChristmasTrackerApp.swift`.
Added (tests, under ChristmasTrackerTests): `Features/Lists/{GeneratedClientMemberRepositoryTests,GeneratedClientListRepositoryCoOwnerTests,ListServiceMemberTests,ListServiceMemberSessionSafetyTests,MockMemberRepositoryTests}.swift`, `Features/Children/{GeneratedClientChildRepositoryTests,ChildServiceTests,ChildServiceSessionSafetyTests,ChildServiceClearableTests,MockChildRepositoryTests,ChildServiceEnvironmentTests,MembersChildrenLogScanTests}.swift`; helpers `Features/Lists/{HeldCallGate,RepositoryCallLog,GatedMemberRepository,MemberServiceHarness,MemberServiceOp,MembersWire}.swift`, `Features/Children/GatedChildRepository.swift`.
Changed (tests): `AppDependenciesResolveTests` (7 added), `InactivityLockIntegrationTests` and `SessionTeardownTests` (count 6 to 7, new `childService:` argument), `GatedListRepository` (call log).
Changed (docs): `Docs/contract-issues.md` (row 2), `Docs/epics/I3b-members-children.md` (M2 Gate 1 addendum and the unknown-recipient ruling).
Deleted: none.

## Test arithmetic (from running the suite; per-file counts)
1167 + 185 new - 0 deleted = 1352 (runner reports 1352). New 185 = 178 in new files (GeneratedClientMemberRepository 30, GeneratedClientChildRepository 32, GeneratedClientListRepositoryCoOwner 10, ListServiceMember 27, ListServiceMemberSessionSafety 9, ChildService 16, ChildServiceSessionSafety 14, ChildServiceClearable 4, MockMemberRepository 18, MockChildRepository 12, ChildServiceEnvironment 3, MembersChildrenLogScan 3) + 7 in AppDependenciesResolveTests (mockModeBuildsMemberAndChildMocks, mockModeMemberRepositoryHasTheSameListRepository, mockModeChildRepositoryHasTheSameListRepository, realModeBuildsGeneratedMemberAndChildRepositories, failedBuildsInertMemberAndChildRepositories, failedMemberRepositoryThrows, failedChildRepositoryThrows). Parameterized tests count once. Changed in place (no count change): the two pinned count tests. Package suite 212 + 0 = 212.

## Gate 2
- Convention-reviewer: APPROVED. Warnings, non-blocking: repository protocols do not end in -ing (they follow the existing `ListRepository` pattern); `ListService.setCoOwner` has no span of its own (delegates to `updateList`, documented); mock id string `mock-child-charlie`.
- Acceptance-reviewer: APPROVED, no blocking findings. Advisories recorded below.
- Stuck detector: no rejection. One test-side compile defect (a missing `import Testing` in `MemberServiceOp.swift`) was found by the implementer, who did not edit the test; it was routed back to the test-writer and fixed there.

### Focus-list answers (M2-relevant; evidence from the acceptance reviewer, partly re-checked by me)
6. Roster refetched after add and remove, add response discarded (`ListService.swift` addMember/removeMember, `refetchDetailAfterMemberChange`); list dropped everywhere after leave (`dropList`, deleted-ids guard, `goneListId`).
8. Every documented response maps (see above); wire tests use the real factory-built client over `ListFakeTransport`, full `meta` envelopes, assert paths, methods, the four client headers, bearer token, add-member body key set exactly `email` and `role`, remove/leave bodyless, leave path with the caller's id, `.clear` sends zero requests. I confirmed that an empty 400 message falls back to a plain text in both `ListError.userMessage` and `ChildError.userMessage` (`ListRespository.swift:73-75`).
9. Stores registered (`SessionClearable.swift`, 7 clearables, teardown test on a populated `ChildService`); stale results after teardown, user switch and cancellation discarded (session-safety suites); the `ChildService` environment default is inert.
10. No Log call in the new repositories or `ChildService`; mocks log constant strings only; Sentry spans carry constant names and no data.
13. Nothing changed under `contract/`, `.claude/`, any `.pbxproj`, synced Docs, or `LocalPackages/TrackerAPI` (allowed docs changes: contract-issues.md, the epic).

### Advisories carried to M3 and the handoff
1. The service does not guard against double submission of add, remove, or leave; **M3 views must disable the controls while `isMutating` is true** (a double add gives `alreadyMember`, a double remove `membershipNotFound`; `ChildService.addChild` would create two children). `isMutating` is a Bool, as in the existing ListService pattern.
2. Leaving a PUBLIC list adds its id to the deleted-ids guard for the whole session; if the server still lists it, it stays hidden until the next sign-in.
3. Low-priority test gap: no wire test sends a 404 with an empty or non-JSON body to addMember or removeMember (the code falls back to `notFound` through `try?`).
4. A malformed 200 body on removeMember or deleteChild is reported as `invalidResponse` although the server already acted; removeMember then does not refetch, so the roster is stale until the next load (matches the addendum's decoding rule).
5. The mock never changes flags after add, remove or leave (deterministic mock; acceptable).

## Verification before the M2 commit (source: command run, grep-filtered summary lines)
```
** BUILD SUCCEEDED **
--- tests: 1352 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
Package (`swift test --package-path "LocalPackages/TrackerAPI"`): `Test run with 212 tests in 16 suites passed after 0.017 seconds.` After the commit: recorded at the top of Docs/reports/I3b-4-screens.md.

## Deviations, bugs, scope
- Deviation 1 (ruling): the mock does NOT reject unknown recipient ids, because two existing `ListServiceTests` create lists for arbitrary recipient ids on a plain `MockListRepository` and may not be weakened; `recipientNotFound` is covered through the real client only (brief M2 text said the mock should; recorded in the epic addendum).
- Deviation 2: the pinned clearables count moved 6 to 7 in two tests (stated reason above).
- Deviation 3: ordering of clearables: `ChildService` is appended last; `SessionManager.teardown` runs all clearables in order and a failure in one never stops the others, so the order carries no meaning (implementer's reading, accepted by the reviewers).
- Real bugs found: none beyond the test-side import defect.

## Not done or partial
- No screens (M3). Nothing was run in the simulator or against a real backend. The 404-with-empty-body wire cases for member calls are covered by code reading only (advisory 3).
