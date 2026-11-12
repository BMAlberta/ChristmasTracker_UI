# I4a: Recording a purchase, with the budget confirmation flow
Track: iOS. Depends on: I3c (merged) and the contract sync on this branch (decisions revision 31: L16, L17, P24, S12, docs pass 1). Blocks: I4b (managing your own purchase, deleting the legacy stack).
Contract state: CONFORMANT. API models come only from the generated client.

Why: the app cannot record a purchase at all. RecordPurchaseView never calls a repository (the call is commented out with a TODO), so "Record Purchase" only reloads the items and closes, and the old purchase types disagree with the server (Double money, a ShippingStatus without NOT_TRACKED, hand-written warning types). This package builds purchase recording from scratch on the generated client, including the two-step budget confirmation, in the product's privacy model: only people the flags allow can record a purchase, and nothing about a purchase leaks to a blind viewer.

Server facts (client guide 7.6 and 6.x, privacy matrix, error codes, decisions P24, S12, S13, L16; confirm each against the synced files): POST /tracker/v2/items/{itemId}/purchases takes quantity, totalCost, storeName and the other optional fields in the generated body, plus an optional confirmationToken. Within budget it returns 201 with data {status "created", purchase, requiresConfirmation false}. Over budget it returns 200 with data {status "confirmation_required", purchase null, requiresConfirmation true} and warnings[]: each warning has code 6002, warningCode BUDGET_OVERAGE_WARNING, level "recipient" or "total", severity, requiresConfirmation, a confirmationToken, and details (recipientId, recipientName, budgetLimit, currentSpent, purchaseAmount, overage); several warnings may be present and they share ONE token; NO purchase is created on the 200. The caller must resubmit the SAME request with the confirmationToken from any one warning. S12: the token binds user, item, recipient, quantity, the amount in cents, AND the buyer's spend (on that recipient and in total) at the time of the warning; it lasts 5 minutes and is IGNORED as soon as another purchase changes that spend. So a repeat over-budget purchase (even the same item, quantity and amount) returns 200 confirmation_required AGAIN with a NEW token: a token is never cached or reused, and the confirm flow runs for every overage purchase. The server is permissive (Brian's decision): any quantity of at least 1 is accepted, the item status is NOT checked (a PARTIAL or PURCHASED item still receives purchases, including from someone who already bought part of it), and the status is recomputed from the sum of all purchase quantities; a purchase on a WRAPPED or GIFTED item is recorded and counted but will not change that item's status (S13, merged at decisions revision 32 with no spec change: such a purchase is recorded and counted in quantityPurchased and quantityRemaining but never changes that item's status and writes no status history; only AVAILABLE, PARTIAL and PURCHASED items are recomputed. The client therefore NEVER assumes or computes an item's status after a purchase: the status always comes from the refetched item). P24: Item and ItemDetail carry two OPTIONAL integers, quantityPurchased (the sum of purchase quantities) and quantityRemaining (max(0, quantityRequested minus quantityPurchased)), present ONLY when the caller has canSeeGiftActivity and ABSENT otherwise (blind owners and co-owners, viewer-role members and PUBLIC non-members never get them); treat absent as unknown, never as zero. Who may purchase: the flag canPurchase (non-blind owner or co-owner, or an ACTIVE MEMBER-role member); blind owners and co-owners get 403 CANNOT_PURCHASE_OWN_LIST (6104); viewers and PUBLIC non-members get 403; strangers get 404; the flag does not depend on the list status, so purchases are accepted on an ARCHIVED list (decision L16). Money: request amounts have at most two decimals and at most 999999.99 (400 INVALID_PRICE, 3007, otherwise); responses are JSON numbers with at most two decimals (convert with the package helpers; never arithmetic on a raw Double). Item reads: purchase summaries and status appear only for callers with canSeeGiftActivity; blind viewers, viewer-role members and PUBLIC non-members see every item as available with no purchases. Confirm from the spec and the guide what the server does with an expired or invalid confirmationToken (a documented error code, or a fresh confirmation_required response); if the contract does not say, STOP that item, file a question row in Docs/contract-issues.md, and build the UI to handle BOTH outcomes (see Decisions).

Scope
1. Story P0: regenerate from the synced contract, and make the configuration tests hermetic.
2. Domain models and pure rules for recording a purchase, the budget confirmation state machine, the money handling, and the two new optional item quantities.
3. GeneratedClientPurchaseRepository (create only), a Mock that reproduces the budget flow including S12, a session-safe PurchaseService, composition for real and mock mode.
4. The Record Purchase screen (rebuilt), the budget confirmation panel, the item detail integration, and the refreshes after a purchase.
5. Removal of the "View Purchase History" button and of the legacy bridge from the new screens where nothing else needs them.

Decisions
- UI RULES FOR NEW CODE (banked polish backlog; they apply to everything new or rewritten in this package; older screens are not refactored): (1) every confirmationDialog is attached to the control that triggers it, never to a List, ScrollView, Form, NavigationStack, or screen container; (2) errors are scoped: a mutation error (recording a purchase) is thrown to the initiating view and held in its local state (shown as an InlineErrorBanner inside the form) and disappears on dismiss, retry success, closing the form, or leaving the screen; nothing is published in a shared service error that another screen reads; (3) destructive actions use role: .destructive with Color.destructiveColor; (4) errors use the existing InlineErrorBanner (no alerts for errors).
- Names: the new domain types do not reuse the legacy names. Use RecordedPurchase (the purchase returned by the server), PurchaseDraft (the form input), BudgetWarning (with a BudgetWarningLevel enum recipient and total), PurchaseOutcome (created(RecordedPurchase) or confirmationRequired(warnings, token)), and PurchaseError. Money is Decimal; the package helpers convert at the repository boundary. The legacy Purchase, ShippingStatus, and the other old purchase types stay untouched until package I4b.
- ListItem (from I3c) gains optional quantityPurchased and quantityRemaining mapped from the generated Item and ItemDetail (nil when absent). ItemDetailState's remaining-quantity text uses quantityRemaining when it is present and shows nothing when it is absent (never a computed value from a hidden field). Everything stays flag-driven: a blind or viewer caller has no purchase controls and no quantities.
- The Record Purchase entry on the item detail appears exactly when ItemDetailState says showsPurchaseEntry (the flag canPurchase) and nothing else; the new RecordPurchaseView takes a ListItem (not the legacy GiftItem) and the list's ItemListContext. The "View Purchase History" button is removed (the item detail's purchase status card already lists the purchases the caller may see; the history screens are build 2).
- The form: quantity (default max(1, quantityRemaining) when quantityRemaining is known and above zero, otherwise 1; at least 1; bounds from the generated schema), total cost (a Decimal parsed from the user's decimal input, greater than 0, at most 999999.99, at most two decimals), and only those optional fields that exist in the generated create body (store name, notes, confirmation number, tracking number: include a field only if the generated payload has it). The unit-cost line is computed with Decimal and shown only when valid. The server accepts any quantity, so the over-purchase prompt is a SOFT client confirmation only: when quantityRemaining is known and the quantity exceeds it, a confirmationDialog attached to the Record button asks "Record anyway?" with text that says how many remain (or, when zero remain, that the item has already been fully purchased and others may have bought it too); when quantityRemaining is absent no prompt is shown. Never block a purchase on quantity.
- Budget confirmation flow as a pure state machine (nonisolated, Sendable): states editing, submitting, awaitingConfirmation(warnings, token, issuedAt, notice), recorded(purchase), failed(error); events submit, serverCreated, serverConfirmationRequired(warnings, token), serverError, confirm, cancel, editDetails, clockTick. Rules: a confirmation_required outcome on a FIRST submit moves to awaitingConfirmation and creates nothing; while awaitingConfirmation the form fields are read-only (the token binds quantity and amount); "Edit Details" returns to editing and DISCARDS the token; "Cancel" closes without recording; "Record Anyway" resubmits the identical draft with the token from the pending confirmation (any one warning's token: they are the same); S12: if a CONFIRMED resubmit is answered by a NEW confirmation_required (the buyer's spend changed since the warning), REPLACE the pending confirmation with the new warnings, the new token and a new issuedAt, show the notice "The amounts changed since the last warning. Review them and confirm again.", and require a NEW explicit Record Anyway (never resubmit automatically, never loop silently); a token is NEVER cached, kept in the service, or reused for a later attempt (a new submit from editing always goes out WITHOUT a token); the pending confirmation is treated as EXPIRED at 4 minutes 30 seconds after issuedAt (an injected clock; one constant in one place, with a comment that the server's limit is 5 minutes) and then shows "This confirmation has expired. Review the details and record again." with a single button that returns to editing; the contract documents NO token error code (guide 7.6: an expired, tampered or mismatched token gets a fresh 200 confirmation_required with no 4xx), so a stale token surfaces through the replacement rule above and any other error follows the generic error handling. The warning panel is INLINE in the form (not an alert or a dialog): one row per warning with a plain label ("Over the budget for <recipient name>" for level recipient, "Over your total budget" for level total), the Decimal amounts formatted with the user's currency formatter (limit, already spent, this purchase, over by), the notice when present, then Cancel and "Record Anyway" (prominent) and "Edit Details". The recipient name comes from the warning's details; nothing else about the recipient is shown.
- After a successful purchase: the service returns the RecordedPurchase; the form closes; the item detail reloads (itemService.loadItemDetail), the item list refreshes (itemService.refreshItems) and the list detail refreshes (listService.refreshListDetail) so counts, status and the server's quantities update. A failed follow-up refresh never turns the successful purchase into an error (the purchase is already recorded): it shows the existing banners of those screens. Do not splice the response into the item by hand, and never infer the new status yourself (for example, do not assume that buying on a WRAPPED or GIFTED item makes it PURCHASED).
- PurchaseService is session-safe like ItemService and ListService (generation, cancellation, nothing written after the session ended, a mutating flag, cleared at teardown through the existing SessionClearable registration; the production-wiring test pins the new clearable count with a stated reason): recordPurchase(itemId:draft:confirmationToken:) throws a typed PurchaseError (no shared error property) and never keeps the token beyond the call. 401 is handled by the middleware; 403 ACCOUNT_DISABLED and 404 USER_NOT_FOUND by the existing session-ending seam; 403 CANNOT_PURCHASE_OWN_LIST and the other 403s map to plain messages; 404 (item or list gone) means gone: close the form and leave the item screen; 400 INVALID_PRICE and other validation errors show the server's plain message; 429 rateLimited; 422 per the documented responses.
- Archived lists: nothing special; the flags decide (purchases are accepted on archived lists).
- The hermetic configuration tests (P0): AppConfiguration.readConfiguration (or whatever reads the apiModeOverride) must not read the process UserDefaults when the unit tests run; inject the override as an explicit parameter whose production default reads UserDefaults, and make every configuration test pass the override explicitly (nil or a value) so that the tests give the same result with or without -apiModeOverride in the scheme.

Non-goals: editing, deleting, or viewing a purchase (I4b), shipping status updates (I4b), the purchase history, stats, and budgets screens (build 2), purchase of a "bought on creation" off-list item (needs an API decision), refactoring older screens, deleting the legacy stack (I4b), the tab bar and theme passes (banked).

Acceptance
- Through the REAL factory-built client with a fake transport, recording a purchase maps every documented response (201 created, 200 confirmation_required with one and with two warnings sharing one token, 400 INVALID_PRICE and the validation message, 401, 403 CANNOT_PURCHASE_OWN_LIST and the other 403s, 404, 422, 429, 500, undocumented, transport failure) with guide-accurate fixtures including the full meta object, the confirmation warnings with all details, and the confirmation token; the request carries exactly the draft fields and, on the resubmit, the token; money crosses the boundary as Decimal; the items fixtures include quantityPurchased and quantityRemaining present and absent.
- The state machine has a full transition table test, including the expiry at 4:30 with an injected clock, edit-details discarding the token, cancel creating nothing, a confirmed resubmit answered by a NEW confirmation_required (the pending confirmation replaced with the new warnings and token and the notice shown, no automatic resubmit), and a repeat purchase after success going out WITHOUT a token and returning confirmation_required again.
- The Record Purchase control and the form appear only when canPurchase is true; blind owners, blind co-owners, viewer-role members, and PUBLIC non-members never see a purchase control, purchase information, or the two quantities (view-state tests for every scenario, including archived lists).
- The soft over-purchase prompt appears only when quantityRemaining is known and exceeded, never blocks a purchase, and has its own wording when zero remain; an absent quantityRemaining never produces a prompt or a computed value.
- No Double arithmetic on money anywhere in the new code; a two-decimal and a three-decimal amount are tested; 999999.99 passes and 1000000.00 fails.
- The confirmation token never appears in a log, Sentry, an accessibility identifier, a service property, or any persisted store (scanning tests and review), and is dropped on every transition out of awaitingConfirmation.
- Stale data from a previous session or user is impossible after teardown, a user switch, or cancellation (deterministic tests); the service never sets an error after the session ended.
- The hermetic configuration tests pass with and without the override argument present.
- The "View Purchase History" button is gone; no new or rewritten screen references the legacy GiftItem or the legacy purchase types; the legacy files are untouched.
- No change under contract/, .claude/, any .pbxproj, the synced Docs files, or LocalPackages/TrackerAPI beyond P0.

---

# Inventory (read-only; paths are relative to the repo root; App = ChristmasTracker/ChristmasTracker, Tests = ChristmasTracker/ChristmasTrackerTests)

Taken at contract/VERSION: decisions_revision 32, spec sha256 7c5880219bd5, CONFORMANT. The generated sources under LocalPackages/TrackerAPI/.build were produced from the OLD derived spec (LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json differs from contract/openapi.json), so the generated signatures below are the pre-P0 state and are re-read after story P0.

## 1. Purchase operations in the synced spec
| operationId | method and path | request body | documented responses |
|---|---|---|---|
| createPurchase | POST /tracker/v2/items/{itemId}/purchases | quantity, totalCost, optional storeName, notes, confirmationNumber, trackingNumber, confirmationToken | 200, 201, 400, 401, 403, 404, 429, 500 |
| listPurchases | GET /tracker/v2/purchases | none (query: recipientId, listId, itemId, year, shippingStatus, limit, cursor) | 200, 400, 401, 403, 404, 429, 500 |
| getPurchase | GET /tracker/v2/purchases/{id} | none | 200, 401, 403, 404, 429, 500 |
| updatePurchase | PATCH /tracker/v2/purchases/{id} | optional notes (max 1000), trackingNumber (max 100) | 200, 400, 401, 403, 404, 429, 500 |
| updatePurchaseShipping | PATCH /tracker/v2/purchases/{id}/shipping | shippingStatus (required), optional trackingNumber | 200, 400, 401, 403, 404, 429, 500 |

- There is NO delete-purchase operation in the spec. The legacy deletePurchase in the app has no contract backing; I4b must raise this with the API team (or drop delete) before building it.
- I4a uses createPurchase only. I4b will need getPurchase, updatePurchase, updatePurchaseShipping and probably listPurchases.
- createPurchase body bounds: quantity integer minimum 1; totalCost number 0 to 999999.99 multipleOf 0.01; storeName max 200; notes max 1000; confirmationNumber max 100; trackingNumber max 100; confirmationToken string.
- 201 and 200 carry PurchaseResult, a oneOf discriminated by status: PurchaseCreatedData (status created, purchase, requiresConfirmation false) and PurchaseConfirmationRequiredData (status confirmation_required, purchase null, requiresConfirmation true). The 200 also carries warnings: [BudgetOverageWarning].
- BudgetOverageWarning required: code, warningCode, level (recipient or total), message, severity, requiresConfirmation, confirmationToken, details. details required: budgetLimit, currentSpent, purchaseAmount, overage (Money); optional recipientId and recipientName (level recipient only), year (level total only).
- Purchase required: id, itemId, quantity, totalCost, shippingStatus, purchaser, recipient, item {id, name, listId}, purchasedAt, createdAt, updatedAt; nullable storeName, notes, confirmationNumber, trackingNumber, shippedAt, deliveredAt.
- Item (also the base of the getItem data via allOf; there is no separate ItemDetail schema) gains optional quantityPurchased and quantityRemaining, integers, minimum 0, present only with gift activity visibility.

## 2. Expired or invalid confirmationToken
The contract is NOT silent and defines no error code. Docs/client-guide.md section 7.6 (line 665): "An expired, tampered or mismatched token is handled the same way (no 4xx)", meaning a fresh 200 confirmation_required with a new token. Docs/error-codes.md has no code for an expired or invalid confirmation token (6002 is a warning, not an error). So no row in Docs/contract-issues.md is needed. Per Brian's instruction after the inventory, there is therefore NO token-error branch in the UI or the state machine: a stale token surfaces as a new confirmation_required and uses the replacement rule (notice "The amounts changed since the last warning. Review them and confirm again."); any other error follows the generic error handling; the client-side expiry at 4 minutes 30 seconds still applies. (The brief text above was patched to match; the first committed copy carried the earlier wording, which this edit supersedes.)

## 3. Generated Swift (pre-P0, signatures only; Gen = LocalPackages/TrackerAPI/.build/plugins/outputs/trackerapi/TrackerAPI/destination/OpenAPIGenerator/GeneratedSources)
- Types+Operations.swift:3923 Operations.CreatePurchase: Input { path: Path { itemId: String }, headers, body: Body (.json(JsonPayload)) }. JsonPayload { quantity: Int, totalCost: Components.Schemas.MoneyAmount, storeName: String?, notes: String?, confirmationNumber: String?, trackingNumber: String?, confirmationToken: String? }. Output cases: ok (200), created (201), badRequest, unauthorized, forbidden, notFound, tooManyRequests, internalServerError, undocumented. Ok payload { success, data: PurchaseResult, warnings: [BudgetOverageWarning], meta }; Created payload { success, data: PurchaseResult, meta }.
- Types+Components+Schemas.swift: Money and MoneyAmount are typealiases of Swift.Double (:66, :70); PurchaseResult :1375 (enum: confirmationRequired(PurchaseConfirmationRequiredData), created(PurchaseCreatedData)); PurchaseCreatedData :1313 { status, purchase: Purchase, requiresConfirmation }; PurchaseConfirmationRequiredData :1346 { status, requiresConfirmation } (the pre-P0 type has no purchase member; re-check after P0); BudgetOverageWarning :1182 { code, warningCode, level, message, severity, requiresConfirmation, confirmationToken, details: DetailsPayload { recipientId?, recipientName?, year?, budgetLimit, currentSpent, purchaseAmount, overage } }; Purchase :993; Item :894 (no quantityPurchased or quantityRemaining before P0).
- Package helpers (LocalPackages/TrackerAPI/Sources/TrackerAPI): MoneyHelpers.swift `doubleToDecimal(_ value: Double) -> Decimal?` and `decimalToDouble(_ value: Decimal) -> Double`; TrackerAPIError.swift `enum TrackerAPIError { unauthorized, forbidden, invalidServerURL, notFound, conflict, validation(String), rateLimited(retryAfter:), versionOutdated, server(Int), network(Error), decoding(Error), undocumented(status:) }`.

## 4. Legacy usage (all untouched by I4a unless named in a story)
- App/Core/Models/Purchase.swift: the whole file is legacy (Purchase, PurchasePerson, ShippingStatus, CreatePurchaseRequest, UpdatePurchaseRequest, responses, PurchaseWarning, WarningDetails; Double money).
- App/Core/Models/GiftItem.swift:14 GiftItem; PurchaseSummary :47; the bridge `ListItem.legacyPurchaseItem` at :106-125.
- App/Features/Items/Repositories/MockItemData.swift (GiftItem and PurchasePerson, for purchase previews).
- App/Features/Items/Views/ItemDetailView.swift: DetailSheet cases :23-31; Record Purchase button :239-241; View Purchase History button :248-251; sheetContent :293-306 builds RecordPurchaseView(item: item.legacyPurchaseItem) and PurchaseHistoryView(item: item.legacyPurchaseItem).
- App/Features/Purchases/Views/RecordPurchaseView.swift (GiftItem at :12, commented-out createPurchase call :276, itemService.loadItems :289, preview :304), PurchaseHistoryView.swift, PurchaseDetailView.swift, PurchaseEditView.swift; Components/PurchaseRow.swift; Repositories/PurchaseRepository.swift (protocol), NetworkPurchaseRepository.swift, MockPurchaseRepository.swift (also declares the legacy PurchaseError at :159, which the new PurchaseError must not collide with).
- None of the legacy purchase repositories is wired into AppDependencies.
- Tests: Tests/Core/GiftItemLegacyBridgeTests.swift (only file naming legacyPurchaseItem); Tests/Features/Items/LegacyGiftItemScanTests.swift (allowlist :26-33, final allowlist :35-39); Tests/Features/Items/GiftItemTrimScanTests.swift; mentions in ListSourceScanTests.swift:15 and SessionTeardownTests.swift:41-44; ItemDetailStateTests.swift:97 and :225-250 (purchase rows and entry).

## 5. ItemDetailState and the item detail view
- App/Features/Items/ViewState/ItemViewState.swift:166 ItemDetailState; remainingQuantity :175 is computed at :215 as max(0, quantityRequested minus totalQuantityPurchased) (a client computation, to be replaced by quantityRemaining); showsPurchaseEntry :180 and :237 = permissions.canPurchase.
- ItemDetailView.swift: remaining text :213-217; entry condition :236; "Record Purchase" label :241; "View Purchase History" label :251 (inside the statusMarker condition); comment at :237 about the old stack.

## 6. Item mapping
- App/Features/Items/Repositories/ItemMapping.swift: mapListItem(Item) :31, mapListItem(GetItem data) :35 (value1 is the Item, value2 the purchases and totalQuantityPurchased), buildListItem :43, mapListItemPurchase :68.
- App/Core/Models/ListItem.swift:30 ListItem (no quantityPurchased or quantityRemaining yet; explicit init :45-66).

## 7. Composition and clearables
- App/ChristmasTrackerApp.swift:87 AppDependencies (no purchase repository field); makeMock :~100-117, makeReal :~120-135 (GeneratedClientItemRepository at :127), makeInert :~137 (InertItemRepository in App/InertRepositories.swift:104); services built at :~300-317; "production clearables (7 total ...)" comment :319; environment injection :419.
- App/Features/Authentication/Services/SessionClearable.swift:28-36 makeProductionClearables returns 7 clearables (listDataStore, itemDataStore, listService, itemService, networkCache, lockController, childService). A PurchaseService makes it 8.
- Tests pinning 7: SessionTeardownTests.swift:319, InactivityLockIntegrationTests.swift:81, ChildServiceClearableTests.swift:58-60 (its helper at :39 must gain the new parameter).
- Tests/App/BootstrapSourceScanTests.swift:98 requires mock types to be constructed in ChristmasTrackerApp.swift only inside makeMock (or a #Preview).
- App/Core/Extensions/EnvironemtValues+ItemService.swift:12 is the model for the new environment key.

## 8. Configuration
- App/Core/Configuration/AppConfiguration.swift: resolveAPIMode(infoValue:override:environment:) :71 (pure, already takes the override); readConfiguration(from:) :86 reads `UserDefaults.standard.string(forKey: "apiModeOverride")` at :110; the static config :127.
- Tests that call readConfiguration(from:) and therefore depend on process defaults: Tests/Core/Configuration/APIModeTests.swift:52-123 (suite "readConfiguration Tests") and Tests/Core/Configuration/AppConfigurationTests.swift:170-191. Tests/Core/API/APIModeResolverTests.swift calls the pure resolver and is already hermetic.

## 9. Log calls in the files the package will touch
- Features/Purchases (legacy, untouched): MockPurchaseRepository.swift :34, :49, :92, :135, :153; NetworkPurchaseRepository.swift :19-:121; PurchaseHistoryView.swift:175 (`LogError("Mock error: \(error)")`). Several interpolate ids or raw errors; they are removed in I4b, not here.
- Features/Items/Services/ItemService.swift :199, :232, :262, :325, :379, :388, :396 (state and operation names; :325 interpolates a count only). MockItemRepository.swift :58, :94, :124, :133. The repository, mapping, views and view-state files have none.
- Features/Lists/Services/ListService.swift :163, :195, :251, :293, :308, :344, :388, :434, :479, :507, :535, :566, :865 (counts and operation names only).

## 10. Tests that matter
ItemService: ItemServiceLoadTests, ItemServiceMutationTests, ItemServiceListSwitchTests, ItemServiceForcedRefreshTests, ItemServiceSessionSafetyTests, ItemServiceSeparateErrorsTests, with ItemServiceHarness and GatedItemRepository. Mapping and repository: ItemMappingTests, GeneratedClientItemRepositoryTests, GeneratedClientItemRepositoryErrorTests, ItemWireSupport (fixtures), ItemFixtures, ItemMockSupport, MockItemRepositoryTests. View state: ItemDetailStateTests, ItemDetailStateRemainingTests.

---

# Gate 1 specs

## Story P0: regenerate from the synced contract, and make the configuration tests hermetic
- Contract slice: Item (and the getItem data, which extends Item) gains optional integers quantityPurchased and quantityRemaining; descriptions change. No operation changes.
- Acceptance: scripts/make-client-spec.sh (write mode) regenerates the derived spec; the transformed-property count guard (5) holds, otherwise STOP and report; package and app build; scripts/verify.sh is green after the commit. readConfiguration takes the apiModeOverride as an explicit parameter whose production default reads UserDefaults (default expression evaluated nonisolated, no MainActor value in it); every readConfiguration test passes the override explicitly; tests give the same result with the key set, removed, and passed as nil or a value (set and remove the key inside the test and restore it).
- Scoped files: LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json (regenerated), any package pinning test only if the guard changes; App/Core/Configuration/AppConfiguration.swift; Tests/Core/Configuration/APIModeTests.swift and AppConfigurationTests.swift; the item mapping only if a compile error needs a minimal fix.
- New interface: none beyond a defaulted parameter. Weight: generated-client layer, full pipeline per CLAUDE.md.

## Story A: domain, money, and the pure rules
- Contract slice: createPurchase request and the 201 and 200 payloads, warnings and details, the Purchase payload, the two Item quantities.
- New interface: yes (RecordedPurchase, PurchaseDraft, BudgetWarning, BudgetWarningLevel, PurchaseOutcome, PurchaseError, RecordPurchaseFormState, BudgetWarningPanelState, RecordPurchaseFlow with a clock, pure mapping functions, ListItem quantityPurchased and quantityRemaining).
- Acceptance: the Acceptance bullets on money, the state machine transition table (including expiry at 4:30 with an injected clock and the S12 replacement), the soft over-purchase rule, the Decimal parser with an injected locale, the default quantity, privacy-neutral mapping of absent quantities to nil. PurchaseError does not collide with the legacy PurchaseError declared in MockPurchaseRepository.swift (the legacy type is not touched; resolve the clash by naming or module placement and state how in the report).
- Scoped files: new files under App/Features/Purchases/Domain, App/Features/Purchases/ViewState, App/Features/Purchases/Repositories (PurchaseMapping.swift, pure mapping functions only), App/Core/Models/ListItem.swift, App/Features/Items/Repositories/ItemMapping.swift, App/Features/Items/ViewState/ItemViewState.swift (remaining text), and their tests under Tests/Features/Purchases and Tests/Features/Items. Nothing else; legacy purchase files untouched.
- Name decision (conflict with the brief, recorded): the brief says PurchaseError, but a top-level `enum PurchaseError` already exists in the legacy Features/Purchases/Repositories/MockPurchaseRepository.swift:159 and is used by legacy views that must not be touched until I4b, so a second one is a redeclaration. The new type is `RecordPurchaseError`; I4b can rename it after deleting the legacy one. All other names are as in the brief.
- Money and sizes: all `nonisolated`, `Sendable`, `Equatable`; money is `Decimal`; no Double arithmetic.

Interface (the test-writer works from this; production code is written afterwards):

```swift
// Domain (Features/Purchases/Domain)
nonisolated enum RecordedShippingStatus: Equatable, Hashable, Sendable { case notTracked, notShipped, shipped, delivered }
nonisolated struct RecordedPurchase: Identifiable, Equatable, Hashable, Sendable {
    let id: String; let itemId: String; let quantity: Int; let totalCost: Decimal
    let storeName: String?; let notes: String?; let confirmationNumber: String?; let trackingNumber: String?
    let shippingStatus: RecordedShippingStatus; let shippedAt: Date?; let deliveredAt: Date?
    let purchaser: ListItemPerson; let recipient: ListItemPerson
    let purchasedAt: Date; let createdAt: Date; let updatedAt: Date
}
nonisolated struct PurchaseDraft: Equatable, Sendable {   // the optional strings are nil when blank
    let quantity: Int; let totalCost: Decimal
    let storeName: String?; let notes: String?; let confirmationNumber: String?; let trackingNumber: String?
}
nonisolated enum BudgetWarningLevel: Equatable, Sendable { case recipient, total }
nonisolated struct BudgetWarning: Equatable, Sendable {
    let level: BudgetWarningLevel; let recipientName: String?   // from details; nil for level total
    let budgetLimit: Decimal; let currentSpent: Decimal; let purchaseAmount: Decimal; let overage: Decimal
}
nonisolated enum PurchaseOutcome: Equatable, Sendable {
    case created(RecordedPurchase)
    case confirmationRequired(warnings: [BudgetWarning], token: String)   // warnings is never empty, token never empty
}
nonisolated enum RecordPurchaseError: Error, LocalizedError, Equatable, Sendable {
    case notFound, unauthorized, forbidden, cannotPurchaseOwnList
    case validation(message: String), invalidPrice
    case rateLimited(retryAfter: TimeInterval), sessionEnded, network, invalidResponse, server
    var userMessage: String       // plain; never interpolates a payload, id or raw error
    var errorDescription: String? // == userMessage
    var closesForm: Bool          // true only for .notFound (item or list gone)
    var isRetryable: Bool         // true for network, server, rateLimited, invalidResponse
}
// ListItem (Core/Models/ListItem.swift) gains: let quantityPurchased: Int?; let quantityRemaining: Int?  (init params last, default nil)

// Mapping (Features/Purchases/Repositories/PurchaseMapping.swift), generated types in, domain out, money via doubleToDecimal
nonisolated func mapRecordedPurchase(_ purchase: Components.Schemas.Purchase) throws -> RecordedPurchase          // non-convertible money -> RecordPurchaseError.invalidResponse
nonisolated func mapBudgetWarning(_ warning: Components.Schemas.BudgetOverageWarning) throws -> BudgetWarning
nonisolated func mapCreatedOutcome(_ result: Components.Schemas.PurchaseResult) throws -> PurchaseOutcome          // the 201 body
nonisolated func mapConfirmationOutcome(_ result: Components.Schemas.PurchaseResult, warnings: [Components.Schemas.BudgetOverageWarning]) throws -> PurchaseOutcome   // the 200 body
```
Mapping rules: the 201 body must carry `created`; a `confirmationRequired` payload in a 201 is `invalidResponse`. The 200 body with `confirmationRequired` needs at least one warning and a non-empty token (the token of the first warning with a non-empty token; the warnings share one token) else `invalidResponse`; it NEVER becomes `created`, whatever the generated shape of the (null) purchase member is. A 200 body that carries `created` maps to `created` (the purchase exists). Item mapping: `mapListItem` fills quantityPurchased and quantityRemaining from the generated Item (nil when absent); the detail mapping inherits them from value1.

```swift
// Form rules (Features/Purchases/ViewState/RecordPurchaseFormState.swift)
nonisolated struct RecordPurchaseFormInput: Equatable, Sendable {
    var quantity: Int; var totalCostText: String
    var storeName: String; var notes: String; var confirmationNumber: String; var trackingNumber: String
}
nonisolated struct RecordPurchaseFormState: Equatable, Sendable {
    init(input: RecordPurchaseFormInput, quantityRemaining: Int?, currencyCode: String = "USD", locale: Locale = Locale(identifier: "en_US"))
    let quantityInvalid: Bool        // quantity < 1 (the generated schema has a minimum of 1 and no maximum)
    let totalCostInvalid: Bool       // text empty or not a valid cost
    let storeNameInvalid: Bool       // trimmed length over 200
    let notesInvalid: Bool           // over 1000
    let confirmationNumberInvalid: Bool  // over 100
    let trackingNumberInvalid: Bool      // over 100
    var isValid: Bool
    let draft: PurchaseDraft?        // nil unless valid; optional strings trimmed, nil when blank
    let unitCostText: String?        // currency text of totalCost / quantity (Decimal, rounded to 2 places); nil unless valid
    let overPurchasePrompt: OverPurchasePrompt?
    static func defaultQuantity(quantityRemaining: Int?) -> Int            // max(1, remaining) when known and > 0, else 1
    static func parseTotalCost(_ text: String, locale: Locale) -> Decimal? // see rules
}
nonisolated struct OverPurchasePrompt: Equatable, Sendable { let title: String; let message: String; let confirmButtonTitle: String }
```
Rules: `parseTotalCost` trims, requires the locale's decimal separator only (grouping separators and any sign, exponent, currency symbol or other character are REJECTED, documented), at most two fraction digits (three decimals rejected), value greater than 0 and at most 999999.99 (so "0", "0.00", negative, "1000000.00" and "999999.995" are nil; "999999.99" and "0.01" pass); with locale en_US "12.50" parses and "12,50" is nil; with a locale whose decimal separator is a comma (de_DE) "12,50" parses and "12.50" is nil. Over-purchase prompt: non-nil only when quantityRemaining is non-nil and quantity > quantityRemaining and the form is valid; title "Record anyway?"; confirmButtonTitle "Continue Anyway"; message when remaining > 0: "Only \(remaining) remaining. You're recording \(quantity)." and when remaining == 0: "This item has already been fully purchased, and others may have bought it too." A nil quantityRemaining never produces a prompt or any computed value. The prompt never affects `isValid` or `draft`.

```swift
// Warning panel (Features/Purchases/ViewState/BudgetWarningPanelState.swift)
nonisolated struct BudgetWarningRowState: Equatable, Sendable {
    let label: String         // "Over the budget for \(name)" (level recipient); "Over your total budget" (level total);
                              // level recipient with nil or blank name: "Over the budget for this recipient"
    let budgetLimitText: String; let alreadySpentText: String; let thisPurchaseText: String; let overByText: String   // currency formatted from Decimal
}
nonisolated struct BudgetWarningPanelState: Equatable, Sendable {
    init(warnings: [BudgetWarning], notice: String?, currencyCode: String = "USD", locale: Locale = Locale(identifier: "en_US"))
    let rows: [BudgetWarningRowState]      // one per warning, same order
    let noticeText: String?                // the notice when present
    let cancelTitle = "Cancel"; let confirmTitle = "Record Anyway"; let editTitle = "Edit Details"
    let announcement: String               // "Budget warning. \(rows.count) item(s) over budget." style text, no amounts and no names
}
nonisolated enum RecordPurchaseCopy {
    static let budgetChangedNotice = "The amounts changed since the last warning. Review them and confirm again."
    static let expiredMessage = "This confirmation has expired. Review the details and record again."
}

// Flow (Features/Purchases/ViewState/RecordPurchaseFlow.swift)
nonisolated struct PendingConfirmation: Equatable, Sendable { let warnings: [BudgetWarning]; let token: String; let issuedAt: Date; let notice: String? }
nonisolated enum RecordPurchaseFlowState: Equatable, Sendable {
    case editing
    case submitting(isConfirmed: Bool)            // carries no token
    case awaitingConfirmation(PendingConfirmation)
    case expired                                  // added to the brief's list: the expired message with one button back to editing
    case recorded(RecordedPurchase)
    case failed(RecordPurchaseError)
}
nonisolated enum RecordPurchaseFlowEvent: Equatable, Sendable {
    case submit, serverCreated(RecordedPurchase), serverConfirmationRequired(warnings: [BudgetWarning], token: String)
    case serverError(RecordPurchaseError), confirm, cancel, editDetails, clockTick, retry, dismissError
}
nonisolated enum RecordPurchaseFlowEffect: Equatable, Sendable {
    case send(confirmationToken: String?)   // the caller performs the request with the same draft
    case close                              // the form closes without recording
}
nonisolated struct RecordPurchaseFlow: Sendable {
    static let confirmationLifetime: TimeInterval = 270   // 4 min 30 s; ONE place; a comment states the server limit is 5 minutes
    init(now: @escaping @Sendable () -> Date)
    private(set) var state: RecordPurchaseFlowState
    var fieldsAreReadOnly: Bool          // true in submitting, awaitingConfirmation, expired, recorded; false in editing and failed
    var noticeText: String?              // the pending confirmation's notice, else nil
    mutating func handle(_ event: RecordPurchaseFlowEvent) -> RecordPurchaseFlowEffect?
}
```
Transition table (an event not listed for a state is ignored: state unchanged, no effect):
- editing: submit -> submitting(isConfirmed: false), effect send(nil). cancel -> editing, effect close.
- submitting(isConfirmed: c): serverCreated(p) -> recorded(p). serverConfirmationRequired(w,t) -> awaitingConfirmation(PendingConfirmation(w, t, issuedAt: now(), notice: c ? budgetChangedNotice : nil)), no effect (nothing is created, nothing is resubmitted). serverError(e) -> failed(e). Every other event is ignored (cancel is ignored while a request is in flight).
- awaitingConfirmation(p): confirm -> if now() - p.issuedAt >= confirmationLifetime then expired (no effect), else submitting(isConfirmed: true) and effect send(p.token). editDetails -> editing (token discarded). cancel -> editing, effect close (token discarded). clockTick -> expired when now() - p.issuedAt >= confirmationLifetime, otherwise unchanged.
- expired: editDetails -> editing; cancel -> editing, effect close.
- failed(e): retry -> submitting(isConfirmed: false), effect send(nil) (a retry never carries a token: the token was dropped when the confirmed request was sent, so a retried overage purchase asks again); dismissError -> editing; editDetails -> editing; cancel -> editing, effect close.
- recorded: terminal, every event ignored.
- The token appears only inside awaitingConfirmation and in the send effect; it is gone from the state after every transition out of awaitingConfirmation. There is no token-error branch (the contract documents none).

Test list for Story A (Swift Testing, fake data): form validity truth table (zero, negative, 0.01, 999999.99, 1000000.00, three decimals, quantity 0, 1 and large, empty text, over-length strings); default quantity (remaining 5, 0, nil, negative); soft prompt (exceeded, equal, below, zero remaining, nil, invalid form) and its wording; parseTotalCost per locale (en_US and de_DE, grouping and sign rejected); unit cost (divisible, rounding, nil when invalid); panel state (one recipient, one total, both, notice, blank recipient name, formatted amounts); the full flow transition table including expiry exactly at 270 s and just before, the S12 replacement (new warnings, new token, new issuedAt, notice, no effect, a NEW explicit confirm required), edit details discarding the token, cancel producing close and no send, retry going out without a token, a repeat purchase after recorded (a fresh flow, submit goes out send(nil)) and ignored events; message mapping for every RecordPurchaseError plus closesForm and isRetryable; mapping of the 201 and 200 payloads including absent optional fields, null purchase, two warnings sharing a token, empty warnings, missing token, 201 carrying confirmation_required, 200 carrying created, non-finite money; the item mapping with the two quantities present and absent; ItemDetailState remaining text from quantityRemaining (present, absent, hidden when the caller cannot see gift activity). Existing tests that assert the OLD computed remaining quantity (ItemDetailStateTests "Remaining quantity is requested minus purchased" and the ItemDetailStateRemainingTests expectations that derive it from totalQuantityPurchased) change deliberately; each is named in the report with this decision as the reason.

## Story B: the generated repository, the mock, and the service
- Contract slice: createPurchase with every documented Output case.
- New interface: yes (PurchaseRecording protocol, GeneratedClientPurchaseRepository, MockPurchaseRecorder, PurchaseService, an environment key).
- Acceptance: every documented response maps through the real factory-built client with a fake transport and guide-accurate fixtures; the request is exactly the draft plus the token on the resubmit; the service is session-safe, never retains the token, never publishes an error; the mock reproduces S12 deterministically; the clearable count becomes 8 with a stated reason; mock types are constructed only inside makeMock.
- Scoped files: new files under App/Features/Purchases/Repositories and Services; App/Core/Extensions (environment key); App/ChristmasTrackerApp.swift and App/App/InertRepositories.swift (composition); App/Features/Authentication/Services/SessionClearable.swift; the clearable-count tests; the Story A follow-ups below (RecordPurchaseFormState.swift parser, token redaction in RecordPurchaseFlow.swift, PurchaseOutcome.swift); new tests.

Decisions recorded by Brian after Story A (they are part of this story):
1. `RecordPurchaseError` is the approved name; it is never renamed (package I4b removes the legacy PurchaseError).
2. PARSER: `RecordPurchaseFormState.parseTotalCost` also accepts ".50" (as 0.50) and "12." (as 12) in the locale's decimal separator ("," variants for a comma locale such as de_DE: ",50", "12,"). It keeps rejecting three decimals, grouping separators, multiple separators, signs, exponents, symbols and the lone separator ("." or ","). Each of these is pinned by a test, with the comma variants for the injected locale. (Zero still fails the greater-than-0 rule: ".00", "0." and "0.0" are nil.)
3. TOKEN REDACTION: every type that stores a confirmation token (PendingConfirmation, RecordPurchaseFlowState, RecordPurchaseFlowEvent, RecordPurchaseFlowEffect, RecordPurchaseFlow, PurchaseOutcome, and any new type in this story that holds one) implements CustomStringConvertible, CustomDebugStringConvertible and, where the stored value would otherwise show through a Mirror (dump), CustomReflectable, printing the placeholder `<redacted token>` in place of the token and nothing else secret. Equatable stays as it is. `String(describing:)`, `String(reflecting:)`, `dump`, string interpolation and error descriptions of the flow state in awaitingConfirmation, of the confirmationRequired outcome, of the send effect and event, and of the warnings value never contain the token string. The existing scanning tests for logs and accessibility identifiers stay.
4. The extra state `expired` and the event `dismissError` are accepted.

Interface (Story B):

```swift
// Repository protocol (Features/Purchases/Repositories/PurchaseRecording.swift). It does NOT inherit the legacy Repository protocol (Core/Networking is deleted in I4b).
nonisolated protocol PurchaseRecording: Sendable {
    func createPurchase(itemId: String, draft: PurchaseDraft, confirmationToken: String?) async throws -> PurchaseOutcome
}
// Real: nonisolated final class GeneratedClientPurchaseRepository: PurchaseRecording, Sendable { init(client: any APIProtocol) }   (@Instrumented createPurchase)
// Inert: nonisolated final class InertPurchaseRecorder: PurchaseRecording (throws ConfigurationError.clientUnavailable)   in App/InertRepositories.swift
// Mock: actor MockPurchaseRecorder: PurchaseRecording
//   init(access: @escaping @Sendable (_ itemId: String) -> MockPurchaseAccess,
//        buyer: ListItemPerson = MockItemRepository.defaultUser,
//        now: @escaping @Sendable () -> Date = { Date() })
//   nonisolated enum MockPurchaseAccess: Sendable, Equatable { case allowed(recipient: ListItemPerson), ownList, forbidden, unknown }
//   nonisolated enum MockPurchaseRules { static let recipientBudgetLimit: Decimal = 50; static let totalBudgetLimit: Decimal = 50; static let tokenLifetime: TimeInterval = 300 }  (documented mock data)

// Service (Features/Purchases/Services/PurchaseService.swift)
@MainActor @Observable final class PurchaseService: SessionClearable {
    init(repository: any PurchaseRecording)
    private(set) var isMutating: Bool
    func recordPurchase(itemId: String, draft: PurchaseDraft, confirmationToken: String?) async throws -> PurchaseOutcome
    func clearForSession() async throws
}
// Environment (Core/Extensions/EnvironmentValues+PurchaseService.swift): var purchaseService: PurchaseService (default built on a mock recorder, like the item key).
// Composition: AppDependencies gains `purchaseRecorder: any PurchaseRecording` (makeMock: MockPurchaseRecorder with access derived from the mock seed items and MockListRepository.capabilities; makeReal: GeneratedClientPurchaseRepository(client:); makeInert: InertPurchaseRecorder()).
// makeProductionClearables gains a final parameter purchaseService: PurchaseService and returns it LAST (8 clearables, index 7).
```
Deviation from the brief wording (recorded): the brief says the service "returns the RecordedPurchase"; the two-step budget flow needs the warnings and token on the first answer, so `recordPurchase` returns the `PurchaseOutcome` (`created(RecordedPurchase)` or `confirmationRequired`). The caller (Story C) treats `created` as success.

Repository rules: the request body is the generated `Operations.CreatePurchase.Input.Body.JsonPayload` built from the draft only (quantity; totalCost through `decimalToDouble`; storeName, notes, confirmationNumber and trackingNumber only when non-nil; confirmationToken only when the argument is non-nil); nil optionals are omitted from the JSON. Output mapping, every case explicit with no default: `.created` (201) -> `mapCreatedOutcome`; `.ok` (200) -> `mapConfirmationOutcome(data, warnings:)`; `.badRequest` -> INVALID_PRICE (errorCode "INVALID_PRICE" or code 3007) is `.invalidPrice`, anything else `.validation(message:)` with the server's message (blank when absent); `.unauthorized` -> `.unauthorized`; `.forbidden` -> `.cannotPurchaseOwnList` when the envelope's errorCode is "CANNOT_PURCHASE_OWN_LIST" or its code is 6104, otherwise `.forbidden`; `.notFound` -> `.notFound`; `.tooManyRequests` -> `.rateLimited(retryAfter: 0)`; `.internalServerError` -> `.server`; `.undocumented(status, _)` -> `.server` for status >= 500 else `.invalidResponse` (so a 422 is `.invalidResponse`: the spec documents none). A thrown `TrackerAPIError` maps like the item repository (`rateLimited(retryAfter:)` kept, `.network` -> `.network`, `.decoding` -> `.invalidResponse`, `.server`, `.undocumented(status:)` by the same rule, `.unauthorized`, `.forbidden`, `.notFound`, `.validation(message)`); a `ClientError` wrapping a `DecodingError` -> `.invalidResponse` (a 400 whose envelope cannot be decoded -> `.validation(message: "")`); a `URLError` -> `.network` (`.cancelled` -> `CancellationError`); `SessionRefreshError` -> `.network`; `CancellationError` passes through; no blanket default. `.sessionEnded` is never produced by the repository. The generated `PurchaseConfirmationRequiredData` has no purchase member (re-verified after the regeneration in P0): whatever the null purchase looks like, a 200 `confirmation_required` maps to `confirmationRequired(warnings, token)` and NEVER to a created purchase. Nothing is logged by the repository; the token, amounts and ids never reach a log or Sentry.

Service rules (like ItemService; manual Sentry span "service.purchases.recordPurchase" because the method is @MainActor, with a comment; no data in the span): captures a generation before the first await; runs the repository call in a cancellable task registered for teardown; `isMutating` is true while a call runs (counted); after the call, if the generation changed or the task was cancelled the call throws `CancellationError` and writes nothing; a typed `RecordPurchaseError` from the repository is rethrown as is, any other error becomes `.server`; the error is never stored or published (no error property exists); only operation and state names are logged (`LogError("record purchase failed", category: .business)`), never the error value, an id, an amount, a name or the token; the token argument is used for that one call and kept nowhere (no property of the service holds it, so a second call without a token goes out without one); `clearForSession()` bumps the generation, cancels in-flight calls, clears `isMutating`.

Mock rules (MockPurchaseRecorder): state is the buyer's recorded spend in total and per recipient (Decimal) and the issued tokens; `access` decides: `.unknown` -> notFound, `.ownList` -> cannotPurchaseOwnList, `.forbidden` -> forbidden, `.allowed(recipient)` proceeds; quantity < 1 -> validation, a total cost that is not greater than 0, above 999999.99 or with more than two decimals -> invalidPrice; any quantity >= 1 and any item status is accepted; the purchase is over budget when (recipient spend + amount) > recipientBudgetLimit or (total spend + amount) > totalBudgetLimit; an over-budget request WITHOUT a valid token returns `confirmationRequired` with one warning per exceeded level (recipient warning carries the recipient name; both share ONE fresh token like "mock-token-N") and creates nothing; the token is bound to (itemId, quantity, amount, recipient spend, total spend) and lasts tokenLifetime from the injected clock; an over-budget request with a valid, unexpired, matching token records the purchase; ANY recorded purchase changes the spend, so every outstanding token stops matching and a repeat over-budget purchase (same item, quantity and amount) returns `confirmationRequired` AGAIN with a NEW token; an expired, unknown or mismatched token behaves exactly like no token (a fresh `confirmationRequired`, never an error, as the contract says); a within-budget request is recorded immediately (a supplied token is ignored). Recorded purchases get ids "mock-purchase-N", the buyer as purchaser, the access recipient as recipient, shippingStatus notTracked, dates from the injected clock. The mock does not change the mock items (documented limitation: counts and status in mock mode do not move after a mock purchase).

Test list for Story B (Swift Testing; REAL factory-built client with a fake ClientTransport, following how GeneratedClientItemRepositoryTests/ItemWireSupport build theirs, with guide-accurate literal JSON fixtures including the full meta object): repository: 201 created (all fields, and absent optional fields); 200 confirmation_required with one warning and with two warnings sharing one token (all details present, `purchase: null` in the body); 400 INVALID_PRICE (3007) and 400 with a validation message and 400 with an undecodable envelope; 401; 403 CANNOT_PURCHASE_OWN_LIST (6104) and another 403; 404; 422 (-> invalidResponse); 429; 500; an undocumented 418 and 503; a transport failure; a decoding failure; a 200 whose body is `created`; a 200 confirmation_required with empty warnings; the request: the body is exactly the draft fields (a first request has no confirmationToken key, the resubmit has it, nil optionals absent, the totalCost JSON number has at most two decimals for 79.99, 10, 0.5), the method, path and item id, the money crossing as Decimal both ways (79.99 round trip). Service (fakes with deterministic handshakes, no sleeps): created and confirmationRequired pass through unchanged; every RecordPurchaseError case is rethrown as is and nothing is published (no error property: a Mirror/source scan); non-typed error -> `.server`; isMutating true during and false after (success, error, cancel), two overlapping calls keep it true until both end; teardown during a call -> `CancellationError`, `isMutating` false, nothing written after; a late result after `clearForSession()` or after a user switch (clear then a new call) is discarded and the new call works; cancelling the caller -> `CancellationError`; the token is not retained (call with token then without: the second reaches the repository with nil; a Mirror of the service never contains the token string); the arguments reach the repository unchanged; the Sentry/log scanning test: PurchaseService and the new repository files interpolate no token, amount, name or id and contain no raw error value. Mock: the full S12 table (within budget; over budget -> two shared-token warnings and nothing recorded; resubmit with that token -> recorded; a repeat over-budget purchase -> confirmationRequired with a NEW token; a stale token after another purchase -> fresh confirmationRequired; expiry after tokenLifetime via the injected clock; unknown token; mismatched quantity or amount; ownList, forbidden, unknown access; price bound 999999.99 passes and 1000000.00 fails; quantity 0 fails; any quantity and any item accepted). Composition: makeMock/makeReal/makeInert wire the right types; the mock recorder is constructed only inside makeMock (BootstrapSourceScanTests); the clearable tests move from 7 to 8 (SessionTeardownTests, InactivityLockIntegrationTests, ChildServiceClearableTests, each named with the reason: the PurchaseService clearable is appended last) and a new test pins that index 7 is the purchase service and that clearing it ends an in-flight call. Story A follow-ups: the parser tests for ".50", "12.", ",50", "12," (de_DE), "." and "," alone, ".00", "0.", "1.2.3", "1,2,3"; and the redaction tests for String(describing:), String(reflecting:), dump and interpolation of the flow state (awaitingConfirmation, with a distinctive token), the confirmationRequired outcome, the send effect, the serverConfirmationRequired event, and the warnings (none contains the token; the redaction placeholder is present; Equatable still compares tokens).

## Story C: the Record Purchase screen and the item detail
- Contract slice: none new (UI over the story A and B types).
- New interface: no new protocol; the view takes a ListItem and the list's ItemListContext. A pure refresh-plan function is added so the refreshes are testable.
- Acceptance: the Acceptance bullets on visibility, the soft prompt, the inline panel, the four UI rules, the refresh plan, removal of "View Purchase History" and its sheet case, removal of the legacy bridge call (and the bridge itself plus its tests only if nothing else uses it, with a stated reason).
- Scoped files: App/Features/Purchases/Views/RecordPurchaseView.swift (rewritten), new panel and form components, App/Features/Items/Views/ItemDetailView.swift, App/Core/Models/GiftItem.swift (bridge only, conditional), the legacy scan and bridge tests (conditional), new tests. The other legacy purchase files are not touched.

### Story C Gate 1 (detailed; weight: full pipeline, capability-flag-driven UI plus purchase and budget confirmation)
Contract slice: none new. Brian's notes at the start of Story C: (1) Story B decisions accepted (invalidResponse for a 200 `created` without warnings; `recordPurchase` returns `PurchaseOutcome`; the mock does not mutate mock items); (2) the 409 mapping assumption and the exact 300-second token boundary assumption are listed as open items in the Story C report; (3) in mock mode no test assumes counts or statuses change after a purchase, and the refresh plan only lists refreshes; (4) the review must state, with file and line, which control each confirmationDialog is attached to.

New interface: yes, and one more than the brief names. The brief adds only a pure refresh plan; this spec also adds `RecordPurchaseModel`, a `@MainActor @Observable` controller (owned by the view through `@State`) that drives the existing pure `RecordPurchaseFlow` and calls `PurchaseService`. Reason: the screen's behaviour (which effect leads to which service call, which draft and token go out, what happens on cancel, expiry and session end, the gating on `canPurchase`) must be unit tested, and the testing conventions do not unit test views. Recorded as a deviation from the brief for the report.

```swift
// Features/Purchases/ViewState/PurchaseRefreshPlan.swift (pure)
nonisolated enum PurchaseRefreshStep: Equatable, Sendable {
    case itemDetail(id: String)       // itemService.loadItemDetail(id:)
    case itemsRefresh                 // itemService.refreshItems()   (the item service already holds this list)
    case itemsLoad(listId: String)    // itemService.loadItems(listId:) (it holds another list or none)
    case listDetail(id: String)       // listService.refreshListDetail(id:)
}
nonisolated enum PurchaseRefreshPlan {
    /// Always three steps in this order: itemDetail, then itemsRefresh or itemsLoad (the same choice as
    /// ListDetailRefresh.itemsStep), then listDetail. It lists refreshes only: it carries no count, no status and no
    /// quantity, and never infers any (mock mode does not change items after a purchase; a real server may not either).
    static func steps(itemId: String, listId: String, currentItemsListId: String?) -> [PurchaseRefreshStep]
}

// Features/Purchases/ViewState/RecordPurchaseErrorPresentation.swift (pure, like ItemErrorPresentation)
nonisolated enum RecordPurchaseErrorPresentation {
    static func banner(for error: RecordPurchaseError) -> InlineErrorBannerState?   // nil for .sessionEnded; message == error.userMessage; canRetry == error.isRetryable; isDismissible true
}

// Features/Purchases/ViewState/RecordPurchaseItemSummary.swift (pure)
nonisolated struct RecordPurchaseItemSummary: Equatable, Sendable {
    init(item: ListItem, capabilities: ListCapabilities, currencyCode: String, locale: Locale)
    let name: String
    let requestedText: String        // "Requested: N"
    let remainingText: String?       // "N remaining" ONLY when capabilities.canSeeGiftActivity and item.quantityRemaining is non-nil; never computed
    let expectedPriceText: String?   // Decimal currency text, nil when the item has no expected price
    // There is NO "already purchased" member and no member derived from totalQuantityPurchased or from purchases.
}

// Features/Purchases/ViewState/RecordPurchaseModel.swift
nonisolated enum RecordPurchaseFinish: Equatable, Sendable { case recorded(RecordedPurchase), itemGone, cancelled }
@MainActor @Observable final class RecordPurchaseModel {
    init(item: ListItem, context: ItemListContext, service: PurchaseService,
         now: @escaping @Sendable () -> Date = { Date() }, currencyCode: String = "USD", locale: Locale = .current)
    var input: RecordPurchaseFormInput        // initial quantity = defaultQuantity(quantityRemaining: known only when canSeeGiftActivity); an assignment while fieldsAreReadOnly is ignored
    private(set) var flow: RecordPurchaseFlow // the pure state machine; its description is already redacted
    private(set) var finish: RecordPurchaseFinish?
    var isShowingOverPurchasePrompt: Bool     // the binding of the confirmationDialog on the Record button
    var isAllowed: Bool { get }               // context.capabilities.canPurchase and nothing else
    var summary: RecordPurchaseItemSummary? { get }          // nil when not allowed
    var formState: RecordPurchaseFormState { get }
    var fieldsAreReadOnly: Bool { get }
    var overPurchasePrompt: OverPurchasePrompt? { get }      // formState's, only while editing or failed
    var panel: BudgetWarningPanelState? { get }              // non-nil only in awaitingConfirmation (notice from the pending confirmation)
    var showsExpired: Bool { get }                           // true only in expired; text is RecordPurchaseCopy.expiredMessage
    var errorBanner: InlineErrorBannerState? { get }         // only in failed, via RecordPurchaseErrorPresentation
    var showsRecordButton: Bool { get }                      // allowed, and the flow is editing, submitting or failed
    var canTapRecord: Bool { get }                           // showsRecordButton, formState.isValid, flow editing or failed, not submitting
    var isSubmitting: Bool { get }
    var expiryDelay: Duration? { get }                       // awaitingConfirmation only: remaining time until the 4:30 expiry from now(), never negative
    func recordTapped() async          // if overPurchasePrompt != nil: isShowingOverPurchasePrompt = true, nothing is sent; else submit
    func confirmOverPurchase() async   // closes the prompt and submits (from the dialog's "Continue Anyway")
    func confirmBudget() async         // "Record Anyway": flow.confirm; sends the SAME draft with the pending token
    func editDetails()                 // flow.editDetails: token discarded, fields editable again
    func cancel()                      // flow.cancel: finish = .cancelled when the flow answers close; nothing recorded; ignored while a request is in flight
    func retry() async                 // failed state, flow.retry: goes out WITHOUT a token
    func dismissError()                // flow.dismissError
    func expiryReached()               // flow.clockTick
}
```
Model rules: (1) EVERY action is a no-op and the service is NEVER called when `isAllowed` is false (blind owner, blind co-owner, viewer-role member, PUBLIC non-member, whatever the item); `summary` is nil, `showsRecordButton` false. (2) The first submit takes the draft from `formState.draft` (nil draft: no call), stores it as the in-flight draft, and calls `service.recordPurchase(itemId:draft:confirmationToken: nil)`; the confirmed resubmit and retry reuse the IDENTICAL stored draft; the stored draft is dropped on editDetails, on dismissError and when the flow returns to editing. (3) The service result feeds the flow: `created` -> serverCreated and `finish = .recorded(purchase)`; `confirmationRequired` -> serverConfirmationRequired (nothing is recorded, nothing is resubmitted automatically; a confirmation_required answering a CONFIRMED resubmit shows the S12 notice and needs a new explicit confirmBudget); a thrown `RecordPurchaseError` -> serverError (if `closesForm`, `finish = .itemGone`); `CancellationError` -> serverError(.sessionEnded) (no banner; the app is leaving); any other error -> serverError(.server). (4) The token exists only inside the flow's pending confirmation and in the local value passed to the one service call; the model has no token property, never logs, and never puts anything in an accessibility identifier; after editDetails, cancel, expiry, success or failure the flow holds no token. (5) Expiry: `confirmBudget` after 270 s is refused by the flow (expired state, no call); `expiryReached` moves to expired when due. (6) A second action while a request is in flight does not start a second call. (7) The model never reads a role; never computes a status, count or remaining value; `finish == .recorded` is its only success signal and it does not refresh anything (the view hands the plan to the detail screen).

Views (not unit tested; covered by the scans below, previews and the reviewer reading the files):
- `RecordPurchaseView(item: ListItem, context: ItemListContext, onFinish: (RecordPurchaseFinish) -> Void)` owns `@State private var model`; sheet-presented from the item detail inside its own NavigationStack; a form with the summary, quantity stepper (at least 1, no maximum), total cost field, optional store name, confirmation number, tracking number, notes (all four exist in the generated body), the unit cost line only when `formState.unitCostText` is non-nil, the INLINE `BudgetWarningPanel` (rows, notice, Cancel, prominent Record Anyway, Edit Details) in place of the Record button while awaiting confirmation, the expired message with one button back to editing, and an `InlineErrorBanner` (Try Again only when retryable, dismissible) at the top of the form for `errorBanner`. Fields disabled while `fieldsAreReadOnly`. Toolbar: Cancel (calls `model.cancel()`), disabled while submitting. When `model.finish` becomes non-nil the view calls `onFinish` once. While awaiting confirmation a `.task(id:)` sleeps for `expiryDelay` and calls `expiryReached()` (no GCD, no Combine).
- ONE confirmationDialog in the whole package: the soft over-purchase prompt, attached with `.confirmationDialog(...)` directly to the Record button (the Button in the form's Record section), bound to `model.isShowingOverPurchasePrompt`, title/message/"Continue Anyway" from `OverPurchasePrompt`, Cancel with `role: .cancel`. The budget panel is inline and is NOT a dialog or alert. No `.alert` for errors anywhere in the new or rewritten files. No confirmationDialog on a List, ScrollView, Form, NavigationStack, sheet or screen container.
- `ItemDetailView`: the Record Purchase button appears exactly when `state.showsPurchaseEntry`; the "View Purchase History" button, `DetailSheet.purchaseHistory` and `item.legacyPurchaseItem` are removed; the sheet presents the new `RecordPurchaseView(item:context:onFinish:)`. On `.recorded` the sheet closes and the screen runs `PurchaseRefreshPlan.steps(itemId:listId:currentItemsListId: itemService.currentListId)` in order (itemService.loadItemDetail, then itemService.refreshItems or loadItems, then listService.refreshListDetail); a failed follow-up never turns the recorded purchase into an error and never shows a purchase error: the screens' own existing banners apply. On `.itemGone` the sheet closes and the detail screen dismisses (a 404 means gone, never forbidden). On `.cancelled` the sheet closes. Nothing else changes in the detail screen.
- Bridge: `ListItem.legacyPurchaseItem` (GiftItem.swift) is deleted together with its tests (GiftItemLegacyBridgeTests and the allowlist entries) ONLY if nothing else uses it after this story; the report states what was searched and the reason. The legacy GiftItem and the other legacy purchase files stay untouched. No new or rewritten file references GiftItem, ShippingStatus, PurchaseWarning or the legacy Purchase types.
- Design: DesignSystem tokens only (AppColors, AppTypography, AppSpacing, AppIcons); no raw colors, spacing or fonts; previews for editing, over-purchase, awaiting confirmation (one recipient and one total warning), expired and error states.

Test list for Story C (Swift Testing, fake data, no sleeps; use PurchaseServiceHarness/GatedPurchaseRecorder-style fakes for the service): (a) PurchaseRefreshPlan: both branches, order, ids, no other members, an unrelated current list, nil current list. (b) RecordPurchaseErrorPresentation: every RecordPurchaseError case (message, retry, nil for sessionEnded). (c) RecordPurchaseItemSummary: remaining present, absent, zero, hidden without gift activity, no already-purchased text; price text. (d) VISIBILITY for every persona, with and without an ARCHIVED list (non-blind owner, non-blind co-owner, ACTIVE MEMBER-role member -> entry shown with quantities; blind owner, blind co-owner, viewer-role member, PUBLIC non-member -> `ItemDetailState.showsPurchaseEntry` false, remainingQuantity nil, statusMarker nil, progress nil, purchases empty, the model `isAllowed` false, `summary` nil, `showsRecordButton` false, every model action a no-op that never reaches the service). (e) RecordPurchaseModel: initial quantity (remaining 5, 0, nil, hidden when no gift activity); input locked while read-only; created path (finish recorded, one service call, request carries the draft and no token); soft prompt (shown only when remaining is known and exceeded, tapping Record sends nothing until confirmOverPurchase, the zero-remaining wording, absent remaining never prompts, never blocks); confirmation path (confirmationRequired creates nothing, panel rows and token not exposed, confirmBudget resubmits the identical draft with the token, edit details discards the token and the next submit goes out without one, cancel finishes `cancelled` with no further call and drops the token); S12 (a confirmed resubmit answered by a new confirmation_required replaces the warnings and token, shows the notice, makes NO automatic call, and needs a new confirmBudget that carries the NEW token); repeat purchase after success goes out WITHOUT a token and gets confirmation_required again; expiry at 270 s with an injected clock (confirmBudget refused with no call, `expiryReached`, expiry message, back to editing; `expiryDelay` values); every error (banner text, retry without a token, dismiss returns to editing, 404 -> finish itemGone, sessionEnded and CancellationError -> no banner, 429 retryable, validation, invalidPrice, cannotPurchaseOwnList not retryable); double tap does not start two calls; the model and its Mirror never contain the token string, `String(describing:)` of the flow never contains it. (f) Source scans over the new and rewritten files (RecordPurchaseView, BudgetWarningPanel, form components, RecordPurchaseModel, ItemDetailView): no GiftItem or legacy purchase type names, no `.alert(`, exactly one `.confirmationDialog(` in the package and it sits on the Record button, no Double arithmetic on money, no raw colors/fonts/spacing, no `confirmationToken`/`token` reference in any view file, no Log call or accessibilityIdentifier that interpolates a token, an amount, a name or an id, no Combine/GCD, no force unwraps, "View Purchase History" gone, legacyPurchaseItem gone from ItemDetailView. (g) The existing suites that pinned the old behaviour (LegacyGiftItemScanTests allowlist, GiftItemLegacyBridgeTests) change deliberately, each named in the report with this decision as the reason.

## Story D: handoff and the real-mode check (docs only)
- Contract slice: none. New interface: none.
- Acceptance: Docs/handoffs/<run date>-ios-to-brian-i4a.md with the sections the prompt lists, including "Brian's real-mode check" with the fifteen steps exactly as specified, the not-performed items stated, the spec has no delete-purchase operation noted as an I4b risk, and a section 9 line for PROGRAM.md.
- Scoped files: Docs/handoffs/ and Docs/reports/I4a-5-handoff.md only.
