# I5b-3: Items read the server's per-item flags

Package I5b, Story C. Full pipeline: isolated test-writer, implementer, convention-reviewer (one rejection, fixed and re-reviewed), acceptance-reviewer.

## What changed
- `ListItem.canEdit` and `canDelete` (non-optional Bool) were added and mapped in Story A (`ItemMapping.swift:62-63`; getItem passes `data.value1` to the shared builder at `:33-35`, `value2` supplies only purchases and totalQuantityPurchased). Story C makes them the only source of the rights.
- `ItemPermissions`: `canEdit(_:)` and `canDelete(_:)` are removed. Every other rule is unchanged (`canAddItem`, `showsOffListNotice`, `visibleItems`, `canSeeGiftActivity`, `canSeeOffListItems`, `canPurchase`). The stale header is rewritten. `currentUserId` stays in the init (call sites and tests pass it) and is now an unused stored property, labelled as such. See deviations.
- `ItemDetailState`: `showsEdit = item.canEdit`, `showsDelete = item.canDelete` (`ItemViewState.swift:244-245`). `ItemDetailView` reads only these: Edit toolbar (`:66`), Delete section (`:182`), Delete button (`:281`).
- Audit of every Edit and Delete control (whole app, by grep and by reading): item rows and `ItemsSectionView` have no Edit or Delete controls, swipe actions or menus. The swipe actions and menus in `DashboardView`, `ListDetailView` and `ChildrenView` are for lists and children and read their own flags. `AddItemView` builds `ItemPermissions` only for `canAddItem` and `showsOffListNotice`. The only remaining use of `createdBy` for rights is the mock's `mockFlags`.
- `MockItemRepository`: `mayChange` is replaced by one mock-only function, `mockFlags(item, caps)`, computed at call time from the mock list's capabilities and the stored item (which keeps its purchases): canEdit is the owner or co-owner on a regular item and the creator on their own off-list item; canDelete is the same and additionally false for a caller who can see gift activity when the item has purchases; a blind caller's canDelete never depends on purchases. `hidden()` (list, get, create, update) takes its flags from it, and update and delete throw `forbidden` exactly when the flag is false.
- The defensive 422 CANNOT_DELETE_ITEM_WITH_PURCHASES mapping (`GeneratedClientItemRepository.swift:183-185`) is untouched.

## Files
Added (tests): `ItemFlagMappingTests.swift`, `GeneratedClientItemRepositoryFlagTests.swift`, and this report.
Changed (production): `ItemMapping.swift` (header comment only), `MockItemRepository.swift`, `ItemPermissions.swift`, `ItemViewState.swift`.
Changed (tests): `ItemDetailStateTests.swift`, `ItemPermissionsTests.swift`, `ItemWireSupport.swift` (new `omitting:` parameter on `itemJSON`), `MockItemRepositoryTests.swift`.
Deleted: none (tests only, listed below).

## Tests
New:
- `ItemFlagMappingTests`: `listPayloadMapsFlags` (4 combinations), `listPayloadFlagsIgnoreOtherFields`, `detailPayloadMapsFlagsFromValue1` (4 combinations), `detailFlagsIgnoreValue2`, `listAndDetailAgree`.
- `GeneratedClientItemRepositoryFlagTests`: `flagsReachTheDomain(op:flags:)` (list, detail, create, update by 4 combinations), `flagsIgnoreOffListAndCreator`, `missingFlagIsInvalid(op:flag:)` (each flag omitted separately on list, detail, create and update gives `ItemError.invalidResponse`), `bothFlagsMissingIsInvalid(op:)`, `oneBadItemFailsTheList`, `nonBooleanFlagIsInvalid` (string, number, null).
- `ItemDetailStateTests`: `editDeleteFollowTheItemFlags(canEdit:canDelete:)` (4 combinations across 7 personas), `handoffCases(_:)` (owner, co-owner, creator of an off-list item, member on a normal item, non-blind caller on an item with purchases (true, false), blind caller on an item with purchases (true, true)), `hiddenAndShown`, `listCapabilitiesAndUserDoNotChangeTheFlags(canEdit:canDelete:)`, `flagsIgnoreOffListCreatorPurchasesAndListStatus`.
- `MockItemRepositoryTests`: `createdItemFlags(persona:)`, `seededFlagsFollowTheMatrix(persona:)` (corrected, see below), `seededFlagsForTheCreator`, `detailFlagsEqualListFlags(persona:)`, `forbiddenExactlyWhenFlagIsFalse(persona:)`, `updateAndDeleteSucceedWhenFlagIsTrue(persona:)`, `nonBlindOwnersCannotDeleteItemsWithPurchases`, `blindOwnersDeleteItemsWithPurchases`; helper `purchasedSeededItemIds()`.
Rewritten: `ItemPermissionsTests.personasOnActiveAndArchivedLists` (display outputs only); `MockItemRepositoryTests.memberCannotTouchRegularItem` and `readOnlyViewersCannotEditOrDelete(persona:)` (act on a seeded regular item under the persona's flags and assert the fetched flag); `ownersEditAndDeleteRegularItems(persona:)` and `memberOwnOffListItem` gained flag assertions.
Deleted because they exclusively asserted the removed derivation (equivalent coverage: the flag-driven tests above):
- `ItemPermissionsTests`: `fullTruthTable(bits:)` (with its `Creator` enum and `oracle()` helper), `nilCurrentUserIdNeverMatches`, `nilCurrentUserIdRegularItem`, `memberRights`, `ownersCannotTouchMemberOffListItems` (named in the test file header; the edit and delete fields of its `Expectation` struct went with them).
- `ItemDetailStateTests`: `editDeleteRegularItem`, `editDeleteMemberOffListItem`, `ownerNoEditOnMemberOffListItem`, `nilUserOffListItem`.
The existing strictness test `itemMissingRequiredField` is generic and kept; the 422 test `GeneratedClientItemRepositoryErrorTests.deleteWithPurchases` is unchanged and still pins the defensive mapping.

Test arithmetic:
- App suite: 4215 (after Story B, measured) to 4230 (measured, final) = +15 net. Not itemized against the test listing: parameterized tests count per argument in the runner total while the lists above count each as one entry, and the removed truth-table test was parameterized over many rows.
- Package suite: 212 + 0 new - 0 deleted = 212 (measured).

## Verification (all from running commands)
Before the commit (`scripts/verify.sh`, summary lines):
```
=== verify: derived spec ===
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 4230 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 212 tests in 16 suites passed after 0.020 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"`: 212 tests in 16 suites passed (inside verify). Story B after-commit run (7014d86): `** BUILD SUCCEEDED **`, `--- tests: 4215 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed`, `=== verify: OK ===`. After the Story C commit: see the Story D report.

## Gate 2
- Implementer, first run: 4227 passed, 1 failed (`seededFlagsFollowTheMatrix`). The implementer stopped, correctly, because the test expected `canDelete == true` for a gift-activity-seeing owner on seeded items that have purchases, which contradicts P25. The spec was right and the test was wrong; the Orchestrator routed the correction to the test-writer (derive the expected flag per item from the matrix and the item's purchase state; add the two purchase tests). Then green at 4230.
- convention-reviewer, first pass: REJECT (small): a `default:` in a test helper switch (`GeneratedClientItemRepositoryFlagTests.swift:32`), a stale "flag-free" comment (`ItemMapping.swift:6`), a stale `ItemPermissions` header and the dead `currentUserId` state, a stray blank line in the mock seed. Fixed by the implementer.
- convention-reviewer, second pass: APPROVE. Optional nits: `ItemMapping.swift:7` is a long comment line; `ItemMappingTests.swift:13` still says "The mapper itself is flag-free" (file not in the diff, left as is).
- acceptance-reviewer: APPROVE. Evidence: (5) `ItemMapping.swift:33-35, 62-63`; (6) `ItemViewState.swift:244-245`, `ItemDetailView.swift:66, 182, 281`, no other derivation; (7) `GeneratedClientItemRepository.swift:183-185` plus `deleteWithPurchases`; (8) `missingFlagIsInvalid`, `bothFlagsMissingIsInvalid`, `oneBadItemFailsTheList`, `nonBooleanFlagIsInvalid`; (11) the lists above; (13) no logging added; mock rule matches P25 and the privacy matrix (`MockItemRepository.swift:151-158`).
- Stuck detector: not triggered.

## Deviations, risks and outside scope
- `ItemPermissions.currentUserId` is now dead state (kept for the init signature, the `Equatable` conformance and existing call sites and tests). Removing it touches every call site and was left out of Story C; both reviewers accepted it. Candidate for a later cleanup.
- Item decoding of the new fields is strict: an older server without them fails the items load as an invalid response (also noted in the handoff).

## Not done or partial
- The +15 app-suite change is not itemized against the test listing.
- The two optional comment nits above were not applied (one is in a file outside the diff).
- No simulator run was possible. Brian's real-mode check is the only proof of the on-screen behavior (Edit and Delete visibility per persona, steps 3 to 6 of the handoff).
