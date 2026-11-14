# I5b: Contract sync (decisions S16 and P25)
Track: iOS. Depends on: UX1a (merged) and Brian's contract sync commit. Blocks: the theme pass.
Contract state: the synced contract is at backend 2ac98bb5db5cd8e3c38fccbf128c1c502e65e9ac, decisions revision 36, spec sha256 prefix f092125d6375. No operationId, path or parameter changed.

What changed in the contract (from the API handoff; the synced files are the authority):
1. Budget recipients (S16): POST /budgets and PATCH /budgets/{year} return the identical 404 RECIPIENT_NOT_FOUND (code 4010) for the caller's own id, an unknown id and a person the caller is not connected to (own child or shared list); nothing is written. A repeated recipientId is 400 VALIDATION_ERROR. On PATCH only recipients not already allocated in that budget are checked, so an existing allocation can always be kept, edited or removed.
2. 422 RECIPIENT_BUDGET_SUM_EXCEEDS_TOTAL (6003) is now typed on updateBudget only: it is returned when just one of totalBudget and recipients is sent; a body with both and an over-sum, and a create with an over-sum, are 400. A totalBudget of 0 is validated like any other value. This closes Docs/contract-issues.md row 3.
3. Item (and so ItemDetail) carries required canEdit and canDelete (P25): true for the owner and co-owner, blind or not, on a normal item, and for the creator on their own off-list item; canDelete is also false for a caller who can see gift activity when the item has purchases (the server would answer 422 CANNOT_DELETE_ITEM_WITH_PURCHASES); a blind caller's canDelete never depends on purchases; neither depends on the list status (L16). They replace the client's derived rules; decode them as NON-OPTIONAL.
4. POST /users/me/children 201 references the RelationshipType enum (PARENT, GUARDIAN, CARETAKER).
5. Description rewording only (canDeleteList, canManageMembers). The guide states the budget candidate rule: the recipients of the lists from GET /lists where canPurchase is true (the user's own blind lists excluded) plus the recipients already in the budget; there is no endpoint.

Decisions (Brian, 2026-11-13): no third item flag for manual status changes (iOS has no such control). The budget candidate rule matches the guide: DROP the "people the user has spent on" group.

Scope: Story A regenerate and compile-fix; Story B budgets (typed recipient 404, typed 422 on update, candidate rule); Story C items (flags from the server); Story D children enum and the docs; Story E handoff.

Non-goals: any new screen, any change to the purchase flows, services' session guards, authentication, the lock, the theme, and the polish items of UX1b. A third item flag. Any iOS handling of an endpoint that does not exist.

Acceptance
- The app and package build clean against the regenerated client; every `switch` over a generated enum that gained a case is exhaustive with no `default` added to hide it.
- Budget create and update: a 404 whose error code is RECIPIENT_NOT_FOUND maps to its own typed BudgetError case with its own fixed message and is NOT treated as "gone"; a 404 BUDGET_NOT_FOUND on update still means the budget is gone; the editor keeps the user's form, shows the banner INSIDE the editor, and refreshes its person options; LoadFailurePolicy and the presentation layers handle the new case exhaustively (tests); a 400 for a repeated recipient maps to the existing validation error; the typed 422 on updateBudget maps to the existing sum-rule error (and the client keeps its own pre-validation).
- The candidate rule is exactly: recipients of the lists where canPurchase is true (the user's own blind lists excluded) plus the recipients already in the budget; the spend-recipient group is gone (pure tests for each group and for no group).
- ListItem carries canEdit and canDelete read from the server; ItemPermissions no longer derives them (its other rules are unchanged); the Edit and Delete controls on the item list rows, the item detail and any swipe or menu action read ONLY the item's flags; the defensive 422 CANNOT_DELETE_ITEM_WITH_PURCHASES mapping stays.
- Item decoding stays strict: fixtures include the new required fields; a response without them is an invalid-response failure (a test pins it).
- The RelationshipType enum change compiles through the Children mapping with no behavior change.
- Docs/contract-issues.md row 3 is marked closed with the commit and the API handoff name; no other contract issue is invented.
- Session safety and every behavior outside these items unchanged; no change under contract/, .claude/, any .pbxproj or the synced Docs files; LocalPackages/ changes only through the regeneration in Story A.

## Inventory
Paths: APP = ChristmasTracker/ChristmasTracker, TESTS = ChristmasTracker/ChristmasTrackerTests, PKG = LocalPackages/TrackerAPI. Taken read-only at the start of the package.

Baseline (P3, before any change): `scripts/verify.sh` stops at the first gate ("Derived spec is out of date. Run scripts/make-client-spec.sh to regenerate."); `swift test --package-path "LocalPackages/TrackerAPI"` runs 212 tests in 16 suites with 1 failure (SpecConformance: the derived spec is 80736 bytes, the transformed contract 82614). Everything else in the package passes. The app build and tests are not reached until the derived spec is regenerated (Story A).

Regeneration procedure: PKG/Sources/TrackerAPI/openapi.json is the derived copy of contract/openapi.json, made by scripts/make-client-spec.sh (not the human-run sync script). The Swift client is generated from it by the build plugin at build time, so Story A runs make-client-spec.sh and then the build. The generated sources currently on disk are stale (pre-sync).

### Spec changes (generated surface)
- Item (spec "Item"): required gains canEdit and canDelete (booleans). There is no separate ItemDetail schema: getItem 200 data is allOf[Item, {purchases, totalQuantityPurchased}]; the flags are in the FIRST half (`DataPayload.value1`), value2 carries only purchases and totalQuantityPurchased. createItem 201, updateItem 200 and listItems 200 return Item.
- updateBudget gains 422 (UnprocessableEntityError): `Operations.UpdateBudget.Output.unprocessableContent` is new. createBudget and duplicateBudget gain no 422 (create's over-sum is 400).
- createChild 201 data.relationshipType: String becomes Components.Schemas.RelationshipType. listChildren and the request body already used the enum.
- List: description text only (canDeleteList, canManageMembers).
- Error envelope: NotFoundError and the others use Components.Schemas._Error with `error.code` (Int) and `error.errorCode` (String), both typed fields of the generated envelope. The spec has no enum for RECIPIENT_NOT_FOUND (4010) or BUDGET_NOT_FOUND (4007); the code is carried by `error.errorCode` and `error.code`. Reading those typed fields is not hand parsing; the lists repository already does it (APP/Features/Lists/Repositories/GeneratedClientListRepository.swift:105-114).

### Item edit and delete rights (item 1)
- APP/Features/Items/ViewState/ItemPermissions.swift:44-54 derives canEdit (off-list: creator is the current user; otherwise canCreateItem && !canAddOffList) and canDelete (= canEdit). Header comment 14-16 is stale after the sync.
- Only caller: APP/Features/Items/ViewState/ItemViewState.swift:243-244 (`showsEdit`, `showsDelete` in ItemDetailState.init). Views: ItemDetailView.swift:66 (Edit toolbar), :182 and :281 (Delete). Item rows have no swipe actions or menus.
- MockItemRepository.swift:139-144 `mayChange` repeats the derivation for update and delete (:103, :131); `hidden(...)` at :151-166 rebuilds items field by field.
- Source-scan tests that ban the word canEdit in scoped directories: ListSourceScanTests.swift (Features/Items scanned for .myRole only), MembersChildrenViewScanTests.swift (Children and Profile scope). Check that Lists, Children and Profile stay free of the word.
- Tests of the derivation: ItemPermissionsTests.swift, ItemDetailStateTests.swift:199-221,269, MockItemRepositoryTests.swift:48-70,185,215-273.

### ListItem construction sites (item 2)
ListItem: APP/Core/Models/ListItem.swift:26-86 (memberwise init 47-85). Production: ItemMapping.swift buildListItem 38-68 (mapListItem 29-36); MockItemRepository.swift createItem 76-90, updateItem 105-121, seed `item(...)` 183-203, `hidden(...)` 151-166; APP/Features/Purchases/Views/RecordPurchasePreviews.swift:16-29. Tests: the single shared fixture TESTS/Features/Items/ItemFixtures.swift:65-85.

### Wire fixtures (item 3)
- TESTS/Features/Items/ItemFixtures.swift `wireItem` 109-143 (memberwise Components.Schemas.Item, 127-142) and `wireDetail` 164-173.
- TESTS/Features/Items/ItemWireSupport.swift `ItemWire.itemJSON` 38-78 (detailEnvelope 108-117 inherits it).
- PKG/Tests/TrackerAPITests/DecodingTests.swift: two raw Item literals (about 203-218 and 233-250).

### Budget repository mapping (item 4)
APP/Features/Budgets/Repositories/GeneratedClientBudgetRepository.swift: create 82-115 (`.notFound` 101-102 maps to BudgetError.notFound, body not inspected; `.conflict` to alreadyExists; `.undocumented` via budgetUndocumentedFailure with isSumRuleWrite); update 118-151 (`.notFound` 139-140, no 422 case yet); budgetUndocumentedFailure 224-229 (isSumRuleWrite && 422: sumExceedsTotal); budgetUnreadableBodyFailures 233-240 (a 422 with an unreadable body maps to hasPurchases, correct for delete only); classifyBudgetAPIError 285-300; header comment 11-12 mentions contract issue 3. Tests: TESTS/Features/Budgets/GeneratedClientBudgetErrorTests.swift (header 14-30, 404 tests 168-186, 243-262, sweeps 431 and 444), BudgetWireSupport.swift (sumExceedsTotal fixture 187-188, isSumRuleWrite 278-284).

### BudgetError and exhaustive switches (item 5)
BudgetError.swift:10-22 (cases), userMessage 25-48, isGone 55-61, isRetryable 65-71. LoadFailure.swift:86-102 (`.validation, .alreadyExists, .sumExceedsTotal, .hasPurchases` map to .other, line 100). Non-exhaustive uses: BudgetEditorModel.swift:222-238, DuplicateBudgetModel.swift:58-65, StatsScreenModel.swift:230-234, StatsService.swift:221-224, BudgetService.swift:158 and :253, MockBudgetStore.swift, InertRepositories.swift:169-202. Tests: LoadFailureFixtures.swift:84-93 and 117-122, LoadFailureClassificationTests.swift:64-137, BudgetErrorTests.swift:12-124.

### Recipient options (item 6)
BudgetRecipientOptions.swift:20-49 `build(lists:existing:spend:)` merges three groups (lists where canPurchase, existing allocations, spend rows). Spend inputs: BudgetEditorModel.swift:42 (`spend`), :52-67 (init), :136-140, :160-164, :167-170; producer StatsScreenModel.swift:289-296; RecipientSpend type StatsYear.swift:10-17. Tests: BudgetRecipientOptionsTests.swift (spend group at 65, name precedence 73-120, ordering 137-148), BudgetEditorModelHarness.swift:61, BudgetEditorModelListsLoadTests.swift:106, BudgetEditorModelPickerTests.swift:57-70, and the `BudgetFixtures.spend(...)` helper used by Statistics tests (spendByRecipient itself stays: it is stats data).

### Children (item 8)
Child.swift:11-40 (ChildRelationship enum, Child). ChildMapping.swift:12-27 `mapChild(... relationshipRaw: String)`. GeneratedClientChildRepository.swift: fetchChildren 37 already uses `.rawValue`; createChild `.created` 77-86 uses `created.relationshipType` as a String (line 82) and will not compile after the sync. Tests and fixtures to touch: GeneratedClientChildRepositoryTests.swift (header 11-14, 141-190, 257-285), MembersWire.swift:56-91.

### Contract issues (item 9)
Docs/contract-issues.md row 3 (line 12) is Open: it asked for a documented 422 on create, update and duplicate. After the sync only updateBudget documents 422, and the spec says create's over-sum is 400, so the row is resolved by the contract as specified; Story D closes it.

## Gate 1: Story A, regenerate and compile-fix
- Contract slice: all operations touched by the sync (updateBudget 422, createChild 201, Item allOf).
- Acceptance: scripts/make-client-spec.sh brings the derived spec in line; app and package build; existing suites pass; new required item fields are added as stored properties on ListItem and mapped (tests come in Story C); fixtures gain the required fields.
- Scope: PKG/Sources/TrackerAPI/openapi.json (by script only), GeneratedClientBudgetRepository.swift, GeneratedClientChildRepository.swift, ListItem.swift, ItemMapping.swift, MockItemRepository.swift, RecordPurchasePreviews.swift, ItemFixtures.swift, ItemWireSupport.swift, DecodingTests.swift, and the budget error tests whose header text names "no 422" on update.
- New interface: none. Weight: solo implementer for A (compile fixes, no behavior), then both reviewers because it touches the generated-client and repository layer.
- Behavior notes: updateBudget `.unprocessableContent` maps to BudgetError.sumExceedsTotal (message from the envelope, like the 400 path). The existing "undocumented 422 on update" test now exercises a documented case and is rewritten to assert the typed case; create and duplicate keep the undocumented-422 mapping. The unreadable-body 422 mapping for update must become sumExceedsTotal, not hasPurchases.
- ListItem gets `canEdit` and `canDelete` (Bool); in A, ItemPermissions is unchanged and the flags are stored and mapped only.

## Gate 1: Story B, budgets
- Contract slice: createBudget and updateBudget 404 (RECIPIENT_NOT_FOUND 4010 vs BUDGET_NOT_FOUND 4007), 400, 409, updateBudget 422.
- Envelope finding: the generated envelope exposes the code through the typed `error.errorCode` (String) and `error.code` (Int). Nothing is parsed by hand; the repository reads those two typed fields exactly as the lists repository does. No question for Brian is needed.
- Acceptance: new `BudgetError.recipientNotFound` (a recipient that cannot be added); create and update 404 decide by code: RECIPIENT_NOT_FOUND (or 4010) gives recipientNotFound, BUDGET_NOT_FOUND (or 4007) gives notFound, any other 404 or an unreadable body keeps today's notFound. Duplicate keeps notFound (it takes no recipients). 400 stays validation. 422 on update is sumExceedsTotal.
- Message: fixed, names nobody ("One of the people you chose can't be added to your budget right now. Check the list and try again."). isGone false, isRetryable false.
- Policy category: .other, like the other mutation outcomes (validation, alreadyExists, sumExceedsTotal, hasPurchases). Pinned by LoadFailureFixtures and the classification tests. The presentation switches stay exhaustive with no default.
- Editor: on this error the banner shows inside the editor, the form is kept, the editor stays open, the budget is not treated as gone, and the person options are refreshed by a forced lists load through the existing session-safe path.
- Candidate rule: `BudgetRecipientOptions.build(lists:existing:)` returns the recipients of lists where canPurchase is true plus the existing allocations; the `spend` parameter, the editor's `spend` input and the StatsScreenModel producer argument are removed. Tests that only assert the spend group are deleted and named in the report.
- Scope: Features/Budgets (Domain, Repositories, ViewState), Features/Shared/ErrorPolicy/LoadFailure.swift, StatsScreenModel.swift (the editor construction), and their tests. New interface: none beyond the enum case and a removed parameter. Full pipeline.
- Scope amendment (Orchestrator, after the first acceptance review rejected): `ListService.refreshLists` gains `reportingFailure: Bool = true`, passed through to `performRefreshLists`, mirroring `loadLists(reportingFailure:)`. The editor calls it with `false` so a failed or successful refresh started from the editor never sets or clears `listsLoadFailure` (the Dashboard reads it), and rebuilds its options only when the refresh returned no error (a failed refresh must not turn a `.failed` or `.loading` picker into `.loaded`). The generation and archive-epoch guards of `performRefreshLists` are untouched. New file in scope: `Features/Lists/Services/ListService.swift` and its tests.

## Gate 1: Story C, items read the server's flags
- Contract slice: Item and getItem allOf (flags from value1).
- Acceptance: ListItem.canEdit and canDelete are non-optional Bools mapped from the generated Item (list, create, update) and from `value1` of getItem. ItemPermissions loses canEdit and canDelete (every other rule unchanged; the stale header comment is corrected). ItemDetailState.showsEdit and showsDelete read only the item's flags. The mock repository gets a small mock-only function that produces flags consistent with the mock's list permissions and replaces `mayChange` as the source of the flags; the mock's update and delete still throw forbidden when the flag is false. The defensive 422 CANNOT_DELETE_ITEM_WITH_PURCHASES mapping stays. A response missing either flag fails as an invalid response, pinned by a test.
- Scope: ListItem.swift, ItemMapping.swift, ItemPermissions.swift, ItemViewState.swift, MockItemRepository.swift, ItemDetailView.swift only if it still reads anything else, and tests/fixtures. Item rows have no Edit or Delete controls today; the audit confirms there are no swipe or menu actions.
- New interface: none (a property on ListItem). Full pipeline (capability-flag-driven UI and the repository layer).

## Gate 1: Story D, children enum and the docs
- Acceptance: createChild 201 uses the RelationshipType enum the same way the list mapping does (`created.relationshipType.rawValue`), no behavior change; the unknown-value test keeps its expectation (invalidResponse), now through decoding. Row 3 of Docs/contract-issues.md is closed with commit 2ac98bb and the API handoff Docs/handoffs/2026-11-13-api-to-ios-and-web-s16-p25.md. No other row or synced file is touched.
- Scope: GeneratedClientChildRepository.swift, ChildMapping.swift if needed, the Children tests and MembersWire fixture, Docs/contract-issues.md. New interface: none. Solo.

## Gate 1: Story E, handoff
- Docs only: Docs/handoffs/<run date>-ios-to-brian-i5b.md with "Brian's real-mode check" copied word for word from the package prompt, plus the report Docs/reports/I5b-5-handoff.md. No code.
