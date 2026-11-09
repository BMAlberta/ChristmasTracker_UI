# I3a: Lists on the generated client
Track: iOS. Depends on: I2b-2d, T1, I6b-1b (merged) and the contract sync on this branch (decisions revision 26: P22, C17, P23). Blocks: I3b (members, children, co-owner, leave), I3c (items), I4 (purchases).
Contract state: CONFORMANT. API models come only from the generated client.

Why: the list screens still run on the hand-written network stack, whose models disagree with the server (snake_case request keys, a hand-built envelope, no capability flags) and whose views decide permissions from the user's role. The product's core promise is that surprise gifts are not revealed, so what a person sees and can do must follow the server's capability flags, never the role. This package moves the list operations (list, get, create, update, delete) onto the generated client, adds the flags to the domain models, puts every permission decision behind one tested flag-driven function, and rebuilds the list screens on it.

Server facts (client guide, privacy matrix, decisions, the API handoff; confirm each against the synced files): every ListSummary and ListDetail carries per-viewer booleans isRecipient, canSeeGiftActivity, canPurchase, canAddOffList, canSeeOffList, canCreateItem, canSeeMembers (P22), canEditList, canDeleteList, canManageMembers, canSetCoOwner and canLeaveList (P23), plus myRole (display only; viewer for both a VIEWER-role member and a PUBLIC non-member). canEditList, canDeleteList and canManageMembers are true for the owner and co-owner (blind or not) while the list is not ARCHIVED; canSetCoOwner for the owner only while not ARCHIVED; canLeaveList for an ACTIVE MEMBER-role or VIEWER-role member on a list of any status and never for the owner, the co-owner, or a non-member (a PUBLIC non-member included); canSeeMembers for the owner, co-owner, and MEMBER-role members. A true flag means the server accepts the action now; the server enforces everything with 403 or 404 regardless. Blind viewers (the recipient, or the owner or co-owner of a list whose recipient can log in) get no itemCount or purchasedCount, every item shows as available, no off-list items, no purchases; viewer-role members and PUBLIC non-members get the same restrictions; a PUBLIC list is not in a non-member's list of lists and is reachable only by id. ListDetail.members is ABSENT (not empty) unless canSeeMembers is true; memberCount is always present. GET /lists takes one optional status value (DRAFT, ACTIVE, ARCHIVED) and has no default; delete (DELETE /lists/{id}) archives the list, which then stays in GET /lists with status ARCHIVED and cannot be un-archived or edited (PATCH returns 422 CANNOT_EDIT_ARCHIVED_LIST); DRAFT behaves exactly like ACTIVE and is never created. POST /lists and PATCH /lists/{id} return a ListDetail with fresh flags; DELETE returns only a message. Lists: one per recipient per year (409 LIST_ALREADY_EXISTS, 5002); the recipient cannot change after creation; creating a list for a child needs a child you own, and a bad recipient is an identical 404 RECIPIENT_NOT_FOUND (4010). Create body: recipientId (uuid), year (2000 to 2100), name (1 to 200), theme (optional, up to 500), visibility (PRIVATE, INVITE_ONLY, FRIENDS_ONLY, PUBLIC; default PRIVATE). Error codes: USER_NOT_FOUND (4002) now means only that the account behind the token no longer exists, and with ACCOUNT_DISABLED (1008) is re-login on an authenticated call; the new PERSON_NOT_FOUND (4011) is a plain not-found and never ends the session. Money in responses is a JSON number with at most two decimals (convert with the package helpers; never arithmetic on the raw Double).

Scope
1. Story H1 (regenerate and adopt C17) and H2 (hardening) first.
2. Domain models: GiftList and ListDetail rebuilt from the generated ListSummary and ListDetail (including the allOf flags), with a ListCapabilities value (all thirteen booleans above), myRole kept for display only, memberCount, optional members, optional counts, money as Decimal; the old hand-written wire types deleted.
3. ListPermissions: ONE pure, nonisolated, flag-driven function (or small type) that answers every list-level question the screens need. It never reads myRole.
4. GeneratedClientListRepository for list, get, create, update, delete with typed errors; the Mock repository updated to the new models with flag scenarios.
5. ListService on the new repository, safe against sign-out and user switching, hiding ARCHIVED lists.
6. The list screens (list of lists, detail, create for yourself, edit, delete) on flags and ListPermissions.

Decisions
- Every affordance follows a flag: Edit list = canEditList; Delete list = canDeleteList; the Members section (I3b) = canSeeMembers; Manage members (I3b) = canManageMembers; Change co-owner (I3b) = canSetCoOwner; Leave list (I3b) = canLeaveList. Item counts and progress show only when canSeeGiftActivity is true and the counts are present. They live ONLY in ListPermissions, with a truth table test. The "owned" versus "shared" filter is a display grouping: owned = canEditList or canDeleteList or canManageMembers, shared otherwise (a named category function in ListPermissions; no role read). myRole is shown only as a badge.
- ARCHIVED lists are hidden everywhere: GET /lists is called WITHOUT the status parameter (the server has no multi-value filter and no default) and archived lists are dropped on the client; DRAFT is shown like ACTIVE. After a delete the list is removed from the service and cache and stays hidden after later refreshes. Because management flags are false on an archived list, no archived list is ever editable.
- After create and update use the returned ListDetail (fresh flags) and update the service and cache from it; after delete remove the list locally; do not refetch to learn the result.
- The list cache (ListDataStore) is per session and is cleared at teardown (existing). In-flight loads must not write results after the session ended or the user changed: use a session generation and cancellation.
- Creating a list in this package is for YOURSELF only (recipient = the signed-in user's id, taken from the in-memory session user). Choosing a child recipient, creating or deleting children, members, co-owner management, and leaving a list are package I3b; do not build them, and do not remove anything I3b will need except the hand-written wire types.
- The session-ending rule is unchanged (a 403 ACCOUNT_DISABLED or a 404 USER_NOT_FOUND from an authenticated call ends the session; 404 PERSON_NOT_FOUND never does). Do NOT add any exemption for getUser.
- Error messages are plain and never include server data beyond the documented message text; no list names or ids in logs.

Non-goals: items, purchases, stats, members management, children management, co-owner by email, leaving a list, invitations, search, push, the version manager screen.

Acceptance
- Through the REAL factory-built client with a fake transport, list, get, create, update, and delete map every documented response (success, 400 with the validation message, 401 as unauthorized after the middleware's refresh attempt, 403, 404 for list not found and recipient not found, 409 duplicate, 422 archived list read-only, 429, 500, undocumented, transport failure) with guide-accurate fixtures including the full meta object.
- All thirteen flags and the optional fields decode and map correctly for every privacy scenario (blind owner without counts, member with counts, viewer-role member, public non-member, blind co-owner, canSeeMembers true and false, members present and absent).
- ListPermissions has a full truth table test, and no production file reads myRole except the badge display function (grep or text-scanning evidence); no production file reads isOwner or canEdit.
- The hand-written list wire types are gone (grep evidence); the app builds, links, and passes verify.
- Sign-out or a user switch during a load never leaves the previous user's data in the service or the cache (tests with deterministic handshakes). Archived lists never appear.
- The error-code classification matches the synced Docs/error-codes.md (4002 and 1008 re-login, 4011 not found), the session-ending middleware ignores 4011 and still fires on 4002 and 1008, and login still shows the administrator message for a 403.
- The negative or NaN Retry-After crash path is fixed with tests; the sign-in-during-end race and the flaky lock test are fixed.
- No change under contract/, .claude/, any .pbxproj, or the synced Docs files; LocalPackages/TrackerAPI changed only as H1 and H2 allow.

---

# Inventory (read-only, taken on branch feat/i3a-lists before any code change)

Preconditions (P1 to P3), recorded 2026-11-09:
- P1: branch feat/i3a-lists, working tree clean, newest commit 557b69c "chore: sync the contract at 4193c78".
- P2: STATUS.md CONFORMANT; VERSION decisions_revision=26, spec_sha256 begins 3074067d16f5. VERSION names backend commit 8109ef3 (the sync commit message says 4193c78); the brief allows a later docs-only commit and says the checksum is what matters. The checksum matches. DECISIONS.md has P22, C17, P23; error-codes.md has 4011 PERSON_NOT_FOUND (treat as not found), 4002 USER_NOT_FOUND and 1008 ACCOUNT_DISABLED (re-login); client-guide.md names all six new flags.
- P3: scripts/verify.sh fails at its first stage as expected: "Derived spec is out of date. Run scripts/make-client-spec.sh to regenerate." (transformed count 5).

## Spec operations (contract/openapi.json, paths prefixed /tracker/v2)
| operationId | Method and path | Query | Documented responses |
|---|---|---|---|
| listLists | GET /lists | year, visibility, status, role (all optional; this package sends none) | 200 401 403 404 429 500 |
| createList | POST /lists | none | 201 400 401 403 404 409 429 500 |
| getList | GET /lists/{id} | none | 200 401 403 404 429 500 |
| updateList | PATCH /lists/{id} | none | 200 400 401 403 404 422 429 500 |
| deleteList | DELETE /lists/{id} | none | 200 401 403 404 429 500 |
| getUser | GET /users/{id} | none | 200 401 403 404 429 500 |

Note: the spec lists year, visibility and role as additional optional query parameters on GET /lists; the brief mentions only status. This package sends none of them. The old derived spec is stale, so the generated Swift signatures (Input structs, Output cases, payload shapes) are NOT pasted here: they are read from the regenerated sources in story H1 and recorded in the H1 report and the L1/L2 Gate 1 sections.

## Hand-written list types (to delete or rewrite)
- Core/Models/GiftList.swift (GiftList, ListRole, ListVisibility, ListStatus, ListPerson; isOwner and canEdit at lines 54 to 59).
- Core/Models/ListDetail.swift (ListDetail, ListMember; isOwner and canEdit at lines 59 to 64).
- Features/Lists/Repositories/ListRespository.swift (protocol ListRepository; ListError with six cases; CreateListRequest and UpdateListRequest are referenced here).
- Features/Lists/Repositories/NetworkListRepository.swift (hand-written APIClient stack; ListResponse<T>, ListsData, EmptyData; uses .put for update; logs list ids, which must not survive).
- Features/Lists/Repositories/MockListRepository.swift, DataStores/ListDataStore.swift, Services/ListService.swift (filteredLists at lines 36 to 43 filters by myRole).

## Uses of the names (files with at least one match, app and tests)
Tests: ListServiceTests (3), LogoutPathTests (3), SessionTeardownTests (6, includes a fake ListRepository using CreateListRequest and UpdateListRequest and four ListError cases).
App: GiftList.swift (13), ListDetail.swift (14), MockData.swift (14), ListDataStore (9), MockListRepository (35), EditListView (7), ListRespository (11), CreateListView (8), ListService (9), NetworkListRepository (11), ListDetailView (8), DashboardListResponse (2), DashboardViewModel (1), ListPreviewCard (4), DashboardView (2), ItemRow (1).

## Reads of myRole, isOwner, canEdit, filteredLists (production, outside models)
- ListDetailView lines 40, 69, 103, 108, 236, 282 (detail.canEdit; myRole badge; detail.myRole == .owner).
- DashboardView lines 84 (filteredLists) and 163 (list.myRole == .owner).
- ListPreviewCard lines 19, 20 (myRole badge), 172 (preview).
- ListService lines 36 to 43 (filteredLists by myRole); ListDataStore line 64; MockListRepository lines 49, 94, 137, 188, 227, 257; MockData lines 88, 105.
- Not list-related, out of scope: GiftItem.canEdit (Core/Models/GiftItem.swift:54), ItemDetailView lines 41 and 298, PurchaseDetailView lines 32, 43, 69. The L1 scan test must be scoped so these item and purchase `canEdit` members do not fail it (see L1 Gate 1).
- Tests: ListServiceTests lines 97 to 109 (filteredLists by myRole), LogoutPathTests line 90, SessionTeardownTests lines 29 and 76.

## Screens that show lists
Dashboard (DashboardView, DashboardViewModel, DashboardListResponse, ListPreviewCard), ListDetailView, CreateListView, EditListView, ItemRow (reads a list type). Dashboard is a list-of-lists consumer and is in scope for L3.

## Composition
ChristmasTrackerApp.swift: the dependency container holds `listRepository: ListRepository` (line 87). Mock mode builds MockListRepository (line 102); real mode builds NetworkListRepository(apiClient:) (lines 114 and 133). Environment default in Core/Extensions/EnvironmentValues+ListService.swift builds a MockListRepository. Previews build MockListRepository directly.

## Error-code classification today
Package: LocalPackages/TrackerAPI/Sources/TrackerAPI/TrackerAPIError.swift, `classifyErrorCode(errorCode:)` lines 44 to 59: 1005, 1006, 1013 -> reLogin; 1002, 1003, 1004 -> refreshAndReplay; 1014 -> forceUpdate; 4001 to 4007 and 4010 -> notFound (includes 4002); 8001, 8002, 9001, 9002 -> backOff; default showMessage. 1008 falls to showMessage and 4011 is absent. Table tests: TrackerAPIErrorTests.swift lines 153 onward (4002 asserted notFound at line 203). Session-ending middleware: Middleware/SessionEndingMiddleware.swift fires on (403, ACCOUNT_DISABLED) line 77 and (404, USER_NOT_FOUND) line 79 by code-string match.

## Open questions flagged now
- The brief's "update the classification" changes 4002 from notFound to reLogin; the existing test at line 203 asserts the old value and is rewritten (named in the H1 report).

---

# Gate 1 specs

## H1: regenerate and adopt C17
- Contract slice: whole spec at revision 26; error-codes.md rows 1008, 4002, 4011.
- Acceptance: make-client-spec.sh in write mode; transformed-property guard holds at 5 or the change is justified; package and app build; exhaustive switches gain new cases deliberately; fixtures carry six new required booleans and optional members, PERSON_NOT_FOUND on getUser, 422 on updateList; public-operation pin test unchanged; classifyErrorCode: 4002 and 1008 -> reLogin, 4011 -> notFound; login 403 message unchanged; package tests: middleware does not fire on 404 PERSON_NOT_FOUND (getUser included), fires on 404 USER_NOT_FOUND and 403 ACCOUNT_DISABLED.
- Scope: scripts output (derived spec), LocalPackages/TrackerAPI Sources/Tests fixtures and classification, app files that fail to compile against the regenerated types. No other change.
- New interface: no. Path: full pipeline (generated-client layer).

## H2: hardening
- Contract slice: client guide section 9 (rate limits).
- Acceptance: RateLimitMiddleware and DefaultSleeper never trap on negative, NaN, infinite or huge waits (clamp to [0, cap], non-finite treated as absent); AuthenticationService session generation: sign-in during an in-flight end is not wiped, old end tears down old data once; flaky lock test deterministic (5 alone runs plus a full run).
- Scope: LocalPackages/TrackerAPI RateLimitMiddleware, DefaultSleeper and tests; AuthenticationService and its tests; InactivityLockController tests. 
- New interface: a generation counter on AuthenticationService (internal, no protocol). Path: full pipeline (auth and session).

## L1: domain models and ListPermissions
- Contract slice: ListSummary and ListDetail schemas (regenerated), privacy matrix list and member rows.
- Acceptance: as the L1 text in the brief; scope: Core/Models/{GiftList,ListDetail}.swift, new Core/Models/ListCapabilities.swift and ListPermissions.swift (placement final in the Gate 1 addendum written after H1), pure mapping functions in Features/Lists/Repositories, tests under ChristmasTrackerTests/Core and Features/Lists.
- New interface: yes (ListCapabilities, ListPermissions, ListCategory, mapping functions). Path: full pipeline (capability-flag-driven).
- The text-scanning test is scoped to Features/Lists, Features/Dashboard, Core/Models/{GiftList,ListDetail,ListCapabilities,ListPermissions,ListRoleBadge}.swift and PreviewContent so item and purchase `canEdit` is not flagged.

### L1 Gate 1 addendum (written after H1, from the regenerated sources)
Generated shapes (signatures only):
- `Components.Schemas.ListSummary { value1: ListSummary.Value1Payload; value2: CapabilityFlags }` (allOf). Value1Payload: id, name: String; theme: String?; year: Int; visibility: ListVisibility (_private, inviteOnly, friendsOnly, _public); status: ListStatus (draft, active, archived); recipient, owner: PersonRef; coOwner: PersonRef?; myRole: ListRole (owner, coOwner "co-owner", member, viewer); canSeeMembers, canEditList, canDeleteList, canManageMembers, canSetCoOwner, canLeaveList: Bool; itemCount, purchasedCount: Int?; memberCount: Int; createdAt, updatedAt: Date. `CapabilityFlags { isRecipient, canSeeGiftActivity, canPurchase, canAddOffList, canSeeOffList, canCreateItem: Bool }`. `PersonRef { id, displayName: String }`.
- `Components.Schemas.ListDetail { value1: ListSummary; value2: Value2Payload { members: [MemberSummary]? } }`. `MemberSummary { id, userId, displayName: String; email: String?; role: MembershipRole (member, viewer); status: StatusPayload (invited, active, removed, expired); invitedAt: Date; acceptedAt, expiresAt: Date? }`.
- There is NO description, totalBudget or totalSpent on ListSummary or ListDetail, so those domain fields are dropped (and the old hand-written ones with them). No money crosses the list boundary in this package.
- Requests: `Operations.CreateList.Input.Body.JsonPayload(recipientId, year, name, theme?, visibility?, coOwnerEmail?)`; the app never sends coOwnerEmail. `Operations.UpdateList.Input.Body.JsonPayload(name?, theme?, visibility?, status?, coOwnerEmail?)`; the app sends only name, theme and visibility and never status or coOwnerEmail. Responses are envelopes `{success, data, meta}`.
New domain interface (Core/Models, all `nonisolated`, Sendable, Equatable unless noted; names fixed here so the test-writer can code against them):
- `struct ListCapabilities { isRecipient, canSeeGiftActivity, canPurchase, canAddOffList, canSeeOffList, canCreateItem, canSeeMembers, canEditList, canDeleteList, canManageMembers, canSetCoOwner, canLeaveList: Bool; init(all thirteen, memberwise, no defaults) }` (twelve flags plus myRole makes the "thirteen" of the brief: the brief counts myRole separately; the struct holds the twelve booleans. Recorded as a deviation note in the L1 report.)
- `struct GiftList { id, name: String; theme: String?; year: Int; visibility: ListVisibility; status: ListStatus; recipient: ListPerson; owner: ListPerson; coOwner: ListPerson?; myRole: ListRole; capabilities: ListCapabilities; memberCount: Int; itemCount: Int?; purchasedCount: Int?; createdAt, updatedAt: Date; var progress: Double? }` (`progress` is non-nil only when both counts are present and itemCount > 0). `struct ListDetail` has the same fields plus `members: [ListMember]?`. `ListMember { id, userId, displayName: String; email: String?; role: ListMemberRole; status: ListMemberStatus; invitedAt: Date; acceptedAt, expiresAt: Date? }` (domain values; email is held for I3b and must never be logged). ListPerson { id, displayName }. ListRole { owner, coOwner, member, viewer } stays for the badge. ListVisibility { private, inviteOnly, friendsOnly, public } and ListStatus { draft, active, archived } stay as domain enums with the generated raw values.
- `struct ListPermissions { init(_ capabilities: ListCapabilities); let canEditList, canDeleteList, canManageMembers, canSetCoOwner, canLeaveList, showsMembersSection: Bool; func showsCounts(itemCount: Int?, purchasedCount: Int?) -> Bool; func showsProgress(itemCount: Int?, purchasedCount: Int?) -> Bool; var category: ListCategory }` where `enum ListCategory { owned, shared }`, `owned = canEditList || canDeleteList || canManageMembers`. Names deliberately avoid the bare word `canEdit`. showsCounts = canSeeGiftActivity && itemCount != nil && purchasedCount != nil; showsProgress = showsCounts && itemCount > 0. Nothing in ListPermissions reads myRole.
- `ListRoleBadge` (new file Core/Models/ListRoleBadge.swift; the ONLY production file allowed to read `.myRole`): `init(list: GiftList)`, `init(detail: ListDetail)`, `var title: String`, `var color`-neutral token name (view maps to AppColors). Views use ListRoleBadge, never `.myRole`.
- Mapping (Features/Lists/Repositories/ListMapping.swift, pure, nonisolated): `mapListSummary(_ summary: Components.Schemas.ListSummary) -> GiftList`; `mapListDetail(_ detail: Components.Schemas.ListDetail) -> ListDetail`; `mapListPerson`. Tests build the generated values by decoding literal JSON with the generated Codable types (Date decoding per the package decoder helpers) or by memberwise init; there is no hand parsing.
- Scan test scope and rule: files under Features/Lists, Features/Dashboard, PreviewContent and Core/Models/{GiftList,ListDetail,ListCapabilities,ListPermissions}.swift must not contain the regex `\.myRole\b`, `\bisOwner\b`, or `\bcanEdit\b`; ListRoleBadge.swift is exempt for `.myRole`. Bare `myRole` as a property inside the model types and `myRole:` argument labels are not `.myRole` accesses and are allowed. Item and purchase `canEdit` live outside the scoped files.
- Truth table reduction: ListPermissions depends on at most twelve booleans; the test enumerates all 2^12 = 4096 flag combinations against an independently written oracle (each named result mirrors exactly one flag; showsCounts/showsProgress depend on canSeeGiftActivity and the counts; category on three flags). No reduction needed.

## L2: repository, mock, service
- Contract slice: five list operations with every documented response.
- Acceptance: as the L2 text in the brief; scope: Features/Lists/Repositories, Services, DataStores, ChristmasTrackerApp.swift composition, tests; NetworkListRepository deleted.
- New interface: yes (GeneratedClientListRepository, expanded ListError, CreateListInput and UpdateListInput domain values). Path: full pipeline (generated-client and repository layer).

### L2 Gate 1 addendum (written after L1 was committed)
Generated surface (signatures only; read from the regenerated sources): `Operations.ListLists.Input(query:headers:)` (query: year, visibility, status, role, all optional and NOT sent), `GetList.Input(path: .init(id:), headers:)`, `CreateList.Input(headers:body: .json(JsonPayload(recipientId:year:name:theme:visibility:coOwnerEmail:)))`, `UpdateList.Input(path:headers:body: .json(JsonPayload(name:theme:visibility:status:coOwnerEmail:)))`, `DeleteList.Input(path:headers:)`. Output cases: listLists/getList/deleteList: ok, unauthorized, forbidden, notFound, tooManyRequests, internalServerError, plus the generator's default and `undocumented(statusCode:_)`; createList: created, badRequest, unauthorized, forbidden, notFound, conflict, tooManyRequests, internalServerError; updateList: ok, badRequest, unauthorized, forbidden, notFound, unprocessableContent, tooManyRequests, internalServerError. Follow the precedent in Features/Authentication/Repositories/GeneratedClientAuthenticationRepository.swift for how the client, middleware errors (`TrackerAPIError`), and the error envelope are handled.
New and changed interface:
- `GeneratedClientListRepository: ListRepository` (Features/Lists/Repositories; `@Instrumented` on its async throws functions per CLAUDE.md), init takes the generated client the same way the auth repository does. `fetchLists()` sends NO query parameters. `createList(_ input: CreateListInput)` sends recipientId, year, name, visibility and theme only if supplied, never coOwnerEmail. `updateList(id:_ input: UpdateListInput)` sends only the fields that are non-nil, never status or coOwnerEmail. Create and update return `mapListDetail(...)`; delete returns Void.
- `ListError` becomes: `forbidden, notFound, recipientNotFound, duplicateRecipientYear, archivedReadOnly, validation(message: String), rateLimited(retryAfter: TimeInterval), unauthorized, sessionEnded, network, invalidResponse, server` (Equatable). The old generic cases fetchFailed, createFailed, updateFailed, deleteFailed are REMOVED; the mock and the existing test fakes that threw them now throw `.server` (rewrite those tests' throws, same meaning, and name them). A pure `var userMessage: String` (and `errorDescription` returning it) gives plain messages: documented server message text is allowed only for `validation`; no ids or names.
- Mapping rules: 200/201 -> mapped domain values; 400 -> validation(message from the envelope, or a plain fallback); 401 -> unauthorized; 403 -> forbidden; 404 -> notFound, EXCEPT a createList 404 whose error code is RECIPIENT_NOT_FOUND (4010) -> recipientNotFound; 409 -> duplicateRecipientYear (createList); 422 -> archivedReadOnly (updateList); 429 or a thrown `TrackerAPIError.rateLimited` -> rateLimited; 500/5xx -> server; undocumented or default -> server for 5xx, invalidResponse otherwise; a decoding failure (`ClientError` with a decoding cause, or `TrackerAPIError.decoding`) -> invalidResponse; transport failures (`TrackerAPIError.network`, URLError) -> network; `CancellationError` rethrown as is. No blanket catch-all hiding a case; every Output case is listed.
- Count hardening (L1 advisory A): `mapListSummary`/`mapListDetail` set itemCount and purchasedCount to nil when `canSeeGiftActivity` is false.
- `ListService`: gains a private session generation incremented when the session is cleared (the service must be cleared at teardown: register it, or have the existing clearable for the list cache clear the service, whichever the existing SessionManager registration pattern allows; tests prove the effect through `SessionManager.teardown`). Every load, refresh, detail load, create, update and delete captures the generation and cancels/ignores its result after any await if it changed; clearForSession cancels in-flight tasks, empties `lists`, `currentListDetail`, the cache and any error. The service never sets `error` after the session ended or after cancellation (a `CancellationError` or a stale generation produces no error). ARCHIVED lists are dropped on load/refresh (DRAFT kept); a successful delete removes the list from `lists`, `currentListDetail` (if it is that list) and the cache without refetching, and a later refresh that still returns it as ARCHIVED keeps it hidden; create and update use the returned detail (flags included) to update `lists`, `currentListDetail` and the cache. `ListError`s from the repository are kept as the service error (typed) with `error.userMessage` for display. The sleeps in the existing service tests are replaced by deterministic handshakes (continuation or AsyncStream gated fakes, no real sleeps, no Task.yield loops) where those tests wait on async work.
- Composition: real mode builds `GeneratedClientListRepository` from the generated client (replacing the TEMPORARY placeholder in ChristmasTrackerApp.swift, both real branches); mock mode keeps MockListRepository.
- Scope: Features/Lists/{Repositories,Services,DataStores}, Core/Models only for the count hardening via ListMapping, ChristmasTrackerApp.swift composition, the affected tests. Views are L3 (compile adaptations only).

## L3: list screens
- Contract slice: flags only. Acceptance and scope as the L3 text in the brief (Features/Lists/Views, Features/Dashboard consumers of list models, view-state functions and their tests).
- New interface: yes (pure view-state functions per screen). Path: full pipeline (capability-flag-driven UI).

## L4: handoff
- Docs only: Docs/handoffs/<run date>-ios-to-brian-i3a.md and Docs/reports/I3a-6-handoff.md. No interface. Path: solo, convention-reviewer at Gate 2 (acceptance-reviewer also, as the brief asks for it on every story).
