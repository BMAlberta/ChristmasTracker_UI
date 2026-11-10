# I3b-2 R2: the repository and the service
Date: 2026-11-10. Branch: feat/i3b-members-children. Weight: full pipeline (generated-client and repository layer): Gate 1 spec in the epic brief, isolated test-writer, isolated implementer, convention-reviewer, then acceptance-reviewer, strictly one after the other.

## What changed
Added (tests): `GeneratedClientListRepositoryRemoveCoOwnerTests.swift`, `ListServiceRemoveCoOwnerTests.swift`, `MockListRepositoryRemoveCoOwnerTests.swift` (all under `ChristmasTrackerTests/Features/Lists/`).

Changed (production):
- `Features/Lists/Repositories/ListRespository.swift`: protocol gains `removeCoOwner(listId:) async throws -> ListDetail`.
- `Features/Lists/Repositories/GeneratedClientListRepository.swift`: `removeCoOwner` (`@Instrumented`) through the generated `Operations.RemoveCoOwner`; `updateList` no longer has a `.clear` refusal (it maps `.unchanged` and `.set` only); `coOwnerClearUnavailableMessage` removed.
- `Features/Lists/Repositories/MockListRepository.swift`: `removeCoOwner` (detail with `coOwner` nil, idempotent, `forbidden` when `canSetCoOwner` is false, `notFound` for an unknown id, honors `shouldFail`); the `.clear` refusal removed; the private `replacing(coOwner:)` helper takes an optional.
- `Features/Lists/Services/ListService.swift`: `removeCoOwner(listId:)` modeled on `updateList` (manual Sentry span with the explaining comment because `@Instrumented` cannot be applied to a `@MainActor` method); `setCoOwner` doc comment updated.
- `App/InertRepositories.swift`: `InertListRepository.removeCoOwner` (`@Instrumented`).
- `Core/Models/MemberInputs.swift`: `CoOwnerChange.clear` removed (pointer comment to `removeCoOwner`).
- `Features/Lists/Views/EditListView.swift`: the single line that turned the toggle into `.clear` removed; nothing else (R3 owns the screen).

Changed (tests): `MemberDomainTests`, `ListUpdateInputCoOwnerTests`, `CoOwnerFormValidationTests`, `MockMemberRepositoryTests`, `GeneratedClientListRepositoryCoOwnerTests` (old "clearing is blocked" tests removed or rewritten), and the doubles `GatedListRepository`, `FixedListRepository` (in `ListServiceTests`), `FastMockListRepository` (in `SessionTeardownTests`) gained `removeCoOwner`. Brief: Gate 1 spec for R2 added. Files deleted: none.

## Commands and raw output (commands ran)
Before the commit, `scripts/verify.sh`, summary lines:
```
=== verify: unit tests ===
--- tests: 1464 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 212 tests in 16 suites passed after 0.020 seconds.
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
Before the commit, `swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.021 seconds.`

Red state (reported by the test-writer, which ran `scripts/test.sh`): the test target did not compile; the only errors were `has no member 'removeCoOwner'` on the repository, mock and service, and a non-exhaustive two-case switch until `.clear` was gone. Implementer: green on the first attempt.

The "after the commit" run of both commands is recorded in the R3 report's "before" section (the R3 baseline is this commit); the R2 commit changes no files after these runs except this report.

## Test arithmetic
`scripts/verify.sh` counts test functions (a parameterized `@Test` is one), not argument cases.
App suite, by function: 1415 + 52 new - 3 deleted = 1464, which matches the raw count. The 3 rewritten tests keep their count.
- New (52, my `grep -c "@Test"` per file and the acceptance-reviewer's count agree): 23 in `GeneratedClientListRepositoryRemoveCoOwnerTests` (the test-writer's own summary said 24 and 8 for the mock; the files hold 23 and 9, same total), 19 in `ListServiceRemoveCoOwnerTests`, 9 in `MockListRepositoryRemoveCoOwnerTests`, 1 in `MemberDomainTests` (`coOwnerChangeHasNoClearCase`).
- Rewritten (3): `MemberDomainTests.coOwnerChangeEquality` and `updateInputCarriesCoOwner` (the `.clear` parts removed), `CoOwnerFormValidationTests.makeChangeOnlySets` (`!= .clear` became `== .set(email:)` plus `!= .unchanged`).
- Deleted (3, each exclusively asserted the old "clearing is blocked" behavior, which no longer exists): `ListUpdateInputCoOwnerTests.clearOnly`, `GeneratedClientListRepositoryCoOwnerTests.clearIsRefusedWithoutARequest` (2 arguments), `MockMemberRepositoryTests.clearCoOwner`.
By argument case the same change is about +74 new, -4 removed (the acceptance-reviewer's count from reading); the raw figure above is by function.
Package suite: 212 + 0 - 0 = 212.

## Gate 2 (real verdicts, written after the reviews)
- convention-reviewer: APPROVE. `@Instrumented` on `GeneratedClientListRepository.removeCoOwner` (:182-183) and the inert repository (`InertRepositories.swift:63-64`); the mock is an actor with the usual "intentionally uninstrumented" comment; the service method has the manual span and comment (`ListService.swift:301-345`); no force unwraps, Combine, GCD, `Task.yield()` loops or real sleeps; test fakes are `@MainActor` final classes; no `@unchecked Sendable`/`nonisolated(unsafe)`; log calls carry only static strings; fixtures use example.com. One warning, below.
- acceptance-reviewer: APPROVE. (2) clearing goes only through the generated DELETE operation; the PATCH body is asserted to carry no `coOwnerEmail` key and no null (`patchNeverCarriesNullCoOwner`, `clearUsesDeleteNotPatch`). (3) real factory client (`TrackerClientFactory.make` in `WireHarness.make`, `MembersWire.swift:121`) with a fake transport and full-meta literal fixtures; request assertions cover DELETE, path, no body, the four client headers, the bearer token and no cookie; every response case is covered. (4) the service mirrors `updateList` line for line: generation, `isMutating`, `perform`/`ensureCurrent`, both removal-sequence guards, no refetch (asserted on the fetch counts), teardown, user-switch and cancellation tests with handshakes. (7) no list name, id, email or member name logged. (9) `updateList` in the service is untouched; the only other edits are the mock `.clear` removal and the one `EditListView` line. (10) nothing under `contract/`, `LocalPackages`, any `.pbxproj` or the synced Docs changed. Minor gap noted by the reviewer: no test drives a 429 to the `.tooManyRequests` output case directly (the rate-limit middleware throws first, as for the sibling operations).
- Both reviewers could not inspect `.claude/` because a guard hook blocks it; `git status` lists no `.claude/` path.
- Rejections: none. Stuck detector: not triggered (green on the first attempt).

## Deviations and findings
- Warning (convention-reviewer), carried to R3: `EditListView` still contains the `removesCoOwner` toggle (`EditListView.swift:23, 173, 180-181`). It is shown only when `showsRemove` is true, and `CoOwnerSectionState.clearingSupported` is still `false` (`CoOwnerViewState.swift:17`), so it is unreachable and no longer feeds `coOwnerChange`. R3 replaces it with the dedicated action and deletes the dead state.
- No real bugs found. No contract mismatch found.
- Verification source: test totals and the build come from running commands; the mapping and session-safety claims come from the reviewers reading the code and tests, not from my own running of them beyond the green suite.

## Not done or partial
- The edit screen has no working "Remove co-owner" yet (R3). Until R3, `showsRemove` stays false.
- `CoOwnerSectionStateTests` and `MembersTruthTableTests` still encode `clearingSupported == false`; R3 rewrites them.
- Contract-issues row 2 is still open until R4.
- The real-mode check against a running backend was not run (needs Brian).
