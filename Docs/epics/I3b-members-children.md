# I3b: Members, co-owner, leaving a list, children, and child lists
Track: iOS. Depends on: I3a (merged). Blocks: I3c (items), I4 (purchases).
Contract state: CONFORMANT at decisions revision 26. API models come only from the generated client.

Why: lists exist but nobody can be added to them, a list cannot be created for a child, and a member cannot leave. This package adds the roster, adding and removing members, setting the co-owner, leaving a list, managing children, and creating a list for a child, all driven by the server's capability flags, and fixes the items carried forward from I3a (most importantly: in real mode the app must never silently fall back to mock data).

Server facts (client guide, privacy matrix, error codes; confirm each against the synced files): ListDetail.members is present only when canSeeMembers is true (the owner, co-owner, and ACTIVE MEMBER-role members, blind or not) and is absent otherwise; memberCount is always present. Add a member: POST /lists/{id}/members with email and role (member or viewer), flag canManageMembers (owner and co-owner); it returns only the new MemberSummary with status ACTIVE (no invitation); unknown or credential-less email gives 404 MEMBER_EMAIL_NOT_FOUND (4009, show message); an existing member gives 409 MEMBERSHIP_ALREADY_EXISTS (5004). Remove another member: DELETE /lists/{id}/members/{userId}, flag canManageMembers; the owner and co-owner cannot be removed (403); 404 MEMBERSHIP_NOT_FOUND (4006). Leave a list: DELETE /lists/{id}/members/{your userId}, flag canLeaveList (an ACTIVE MEMBER-role or VIEWER-role member; never the owner, the co-owner, or a PUBLIC non-member: do not use myRole for it). Delete calls return only a message: after add and remove, refetch GET /lists/{id}; after a leave, drop the list from the service and cache. Co-owner: coOwnerEmail on PATCH /lists/{id} (and on create), flag canSetCoOwner (owner only; a co-owner gets 403); an unknown email gives 404 MEMBER_EMAIL_NOT_FOUND; the owner or recipient cannot be co-owner (403); an archived list is read-only (422). Children: GET /users/me/children, POST /users/me/children (firstName 1 to 100, lastName 1 to 100, displayName optional 1 to 200, relationshipType PARENT, GUARDIAN, or CARETAKER, default PARENT; returns 201 with id, firstName, lastName, displayName, relationshipType; the child has no email or password and can never log in), DELETE /users/me/children/{id} (soft delete; 404 RESOURCE_NOT_FOUND for an unknown or foreign child; 422 CANNOT_DELETE_RESOURCE (6501) when the child has lists). A list for a child: POST /lists with recipientId = a child you own (otherwise 404 RECIPIENT_NOT_FOUND, 4010, identical for every bad id); the creator of a child's list is not blind (sees counts and everything); one list per recipient per year (409 LIST_ALREADY_EXISTS). All errors use the standard envelope; USER_NOT_FOUND (4002) and ACCOUNT_DISABLED (1008) on an authenticated call end the session (middleware, unchanged); PERSON_NOT_FOUND (4011) never does.

Scope
1. Story K0: carried-forward fixes (below).
2. Domain models and pure view-state rules for the members section, the co-owner section, the children screen, and the create-list recipient picker.
3. Generated-client repositories (members, children) and the co-owner change through the update-list operation, services that are session-safe, mocks with privacy scenarios.
4. Screens: the Members section of the list detail (roster, add, remove, leave), the co-owner control in the edit screen, a Children screen reached from Profile, and a recipient picker in the create-list form.

Decisions
- Every affordance follows a flag (through ListPermissions or the new view-state functions that take it): the Members section shows when canSeeMembers is true and members is present, otherwise only memberCount; Add and Remove show only when canManageMembers; Change co-owner only when canSetCoOwner; Leave list only when canLeaveList. The ONLY role read is the MEMBERSHIP role of a roster row (to hide Remove on the owner and co-owner rows and to label rows); the viewer's own role (myRole) is still read only by the badge.
- Add member: email plus a role picker (member or viewer, default member); show the server's message for 4009 and 5004; after success refetch the list detail (do not splice the response into the roster); the roster is read from the detail's members, never from a separate call.
- Remove and leave: confirmation dialogs; after a successful removal refetch the detail; after a successful leave remove the list from the service and cache and leave the screen.
- Co-owner: a control in the edit screen showing the current co-owner (display name only) with "Change co-owner" (email field) and "Remove co-owner" shown only when canSetCoOwner is true. FIRST check what the generated update payload offers for coOwnerEmail: if it cannot encode an explicit JSON null (a nil optional is normally omitted), clearing the co-owner is NOT possible through the generated client; build setting the co-owner, STOP at clearing, do not work around it (no hand-built request, no empty-string guess), file a row in Docs/contract-issues.md (a proposal: the contract documents coOwnerEmail null to clear, but the generated client cannot send null; ask for an explicit clearing mechanism, for example an empty string or a dedicated operation), hide "Remove co-owner" in the UI until it is resolved, and say so in the report and handoff.
- Children live under Profile, in a "Children" screen: list, add (first name, last name, optional display name, relationship), delete with a confirmation; a 422 shows the message that the child still has lists; children's names are never logged.
- Create list: the form gets a recipient picker: "For me" (default) and each child (fetched when the form appears; loading, empty, and error states; a failed fetch leaves "For me" usable); the recipient is sent as recipientId; the screen explains nothing about blindness. A child's list shows counts and progress to the creator (the flags decide).
- In real mode the app NEVER falls back to mock data: if the generated client cannot be built, the app shows a blocking error screen ("This version can't connect to the server. Please reinstall the latest version.") and nothing else, reports one Sentry event with an error category only, constructs no Mock repository, and offers no sign-in. Mock mode is unchanged.
- Services stay session-safe (the I3a pattern: generation, cancellation, no state or error written after the session ended, cleared at teardown); every new store or service is registered with the session teardown and covered by the production-wiring test (update the pinned count with a stated reason).
- Error messages are plain; no member emails, names, or ids in any log or analytics.

Non-goals: items, purchases, stats, budgets, invitations, searching users, member role changes (unless the spec has an update-role operation: report it, do not build it), push, the version manager screen, editing a child (the spec has no such operation), the DesignSystem follow-ups (theme pass).

Acceptance
- Through the REAL factory-built client with a fake transport, add member, remove member, list children, create child, delete child, and update list with a co-owner map every documented response (success, 400 with the validation message, 401, 403, 404 for each code above, 409, 422, 429, 500, undocumented, transport failure) with guide-accurate fixtures including the full meta object and the flags.
- Pure view-state functions and a truth table show who sees the Members section, Add, Remove (per row), Leave, Change co-owner, and the roster, for the owner, co-owner, blind co-owner, MEMBER-role member, VIEWER-role member, PUBLIC non-member, and the recipient; no screen reads myRole to decide any of it.
- Members appear only when canSeeMembers is true; a viewer or public non-member sees memberCount only.
- After add and remove the detail is refetched; after leave the list is gone from the service and cache; stale results after teardown or a user switch are impossible (deterministic tests).
- The co-owner clearing question is answered with evidence (the generated payload shape) and, if it cannot be done, a contract-issues row exists and the UI hides the control.
- In real mode with a client that cannot be built, no mock repository exists and the blocking screen shows (test through the composition root); mock mode is unchanged.
- No list names or ids, emails, member names, or children's names appear in any log call in the changed or added files (pattern-scan evidence).
- No change under contract/, .claude/, any .pbxproj, the synced Docs files, or LocalPackages/TrackerAPI.

---

# Inventory (read-only, taken 2026-11-09 on branch feat/i3b-members-children before any code change)

Preconditions: P1 clean tree, newest commit 0ef0974 (merge of PR 26, I3a). P2 STATUS.md CONFORMANT, VERSION decisions_revision=26, spec_sha256 begins 3074067d16f5. P3 scripts/verify.sh: 946 app tests passed, 92 release-script, 17 destination-script, `=== verify: OK ===`; `swift test --package-path "LocalPackages/TrackerAPI"`: 212 tests in 16 suites passed.

## Spec operations (contract/openapi.json, paths prefixed /tracker/v2; the derived spec has the same paths, ids and codes)
Every operation also has the Output cases unauthorized (401), forbidden (403), notFound (404), tooManyRequests (429), internalServerError (500) and `undocumented(statusCode:_)` (no `default` response is in the spec).

| operationId | Method and path | Request body | Success | Extra cases |
|---|---|---|---|---|
| addMember | POST /lists/{id}/members | email, role (member or viewer), both required | created (201), data MemberSummary | badRequest 400, conflict 409 |
| removeMember | DELETE /lists/{id}/members/{userId} | none | ok (200), data only a message | none |
| listMembers | GET /lists/{id}/members | none | ok (200), [MemberSummary] | none (NOT used by the app: the roster comes from the detail) |
| listChildren | GET /users/me/children | none | ok (200) | none |
| createChild | POST /users/me/children | firstName, lastName, displayName?, relationshipType? | created (201) | badRequest 400 |
| deleteChild | DELETE /users/me/children/{id} | none | ok (200), data only a message | unprocessableContent 422 |
| updateList | PATCH /lists/{id} | name?, theme?, visibility?, status?, coOwnerEmail? | ok (200), ListDetail | badRequest 400, unprocessableContent 422 |
| createList | POST /lists | recipientId, year, name, theme?, visibility?, coOwnerEmail? | created (201) | badRequest 400, conflict 409 |

Update-role operation: NONE exists (under /members the spec has only addMember, listMembers, removeMember). Member role changes are therefore out of scope and reported, not built.
All operationIds touching /lists, /members, /users: createItem, listItems, addMember, listMembers, removeMember, createList, listLists, getList, updateList, deleteList, getMe, updateMe, updatePassword, listChildren, createChild, deleteChild, getUser.

## Generated signatures (signatures only)
```swift
Operations.AddMember.Input(path: .init(id: String), headers: .init(), body: .json(.init(email: String, role: Components.Schemas.MembershipRole)))
Operations.RemoveMember.Input(path: .init(id: String, userId: String), headers: .init())
Operations.ListChildren.Input(headers: .init())
Operations.CreateChild.Input(headers: .init(), body: .json(.init(firstName: String, lastName: String, displayName: String? = nil, relationshipType: Components.Schemas.RelationshipType? = nil)))
Operations.DeleteChild.Input(path: .init(id: String), headers: .init())
Operations.UpdateList.Input.Body.JsonPayload(name: String? = nil, theme: String? = nil, visibility: ListVisibility? = nil, status: ListStatus? = nil, coOwnerEmail: String? = nil)
enum MembershipRole: String { member, viewer }
enum RelationshipType: String { parent = "PARENT", guardian = "GUARDIAN", caretaker = "CARETAKER" }
struct MemberSummary { id, userId, displayName: String; email: String?; role: MembershipRole; status: StatusPayload (INVITED, ACTIVE, REMOVED, EXPIRED); invitedAt: Date; acceptedAt, expiresAt: Date? }
```
Children have NO named schema. listChildren element: inline `DataPayloadPayload { id, firstName, lastName: String; displayName: String?; relationshipType: RelationshipType }`. createChild response: inline `DataPayload { id, firstName, lastName: String; displayName: String?; relationshipType: Swift.String }` (a plain String, not the enum: the mapper must parse it and treat an unknown value as invalidResponse). Spec default for relationshipType is PARENT but Swift has no default (nil is omitted; the server applies PARENT). Remove and delete responses carry `data: { message: String }`.

## coOwnerEmail null question (answered with evidence)
`coOwnerEmail` is `Swift.String?` in the UpdateList and CreateList payloads (a plain Optional, no nullable wrapper). The struct uses compiler-synthesized Codable (CodingKeys only, no custom encode(to:)), so a nil is OMITTED (encodeIfPresent) and an explicit JSON null cannot be sent. The contract and the derived spec both type it `["string","null"]` ("Set or clear the co-owner by email"); scripts/make-client-spec.sh transforms only the anyOf null form, not this one. Conclusion: setting a co-owner works; CLEARING is not possible through the generated client. Per the Decisions: build set only, hide "Remove co-owner", file a Docs/contract-issues.md row (in M2, where the repository change lands), no workaround. Note: client-guide section 7.4 shows only the set example; the "set or clear" wording comes from the spec and the guide's action table.

## Existing app code (file and line)
- Core/Models/ListDetail.swift: ListDetail (:12, `members: [ListMember]?` :46), ListMemberRole {member, viewer} (:122), ListMemberStatus (:130), ListMember (:137, email must never be logged), CreateListInput (:152), UpdateListInput (:161, name, theme, visibility only). ListRole lives in Core/Models/GiftList.swift:98 (badge only).
- Features/Lists/Repositories/ListRespository.swift: protocol ListRepository (:10; fetchLists, fetchListDetail, createList, updateList, deleteList), ListError (:39; forbidden, notFound, recipientNotFound, duplicateRecipientYear, archivedReadOnly, validation, rateLimited, unauthorized, sessionEnded, network, invalidResponse, server). GeneratedClientListRepository and MockListRepository (actor, :10; init(withMockData:includeAllScenarios:); fixtures incl. ownerOfChildList :230, allLists :290, allScenarios :293).
- Features/Lists/Services/ListService.swift: @Observable class, state lists, currentListDetail, isLoading (:22), isRefreshing, error, lastUpdated; loadLists :68, refreshLists :110, loadListDetail :139, createList :176, updateList :213, deleteList :250, clearForSession :301, session generation helpers perform :340, ensureCurrent :353, record :359. isLoading is set in loadLists (:74), loadListDetail (:147), createList (:184), updateList (:221), deleteList (:258).
- Features/Authentication/Services/SessionClearable.swift:24 makeProductionClearables returns 6 clearables (listDataStore, itemDataStore, listService, itemService, networkCache, lockController). Pinned test: ChristmasTrackerTests/Features/Authentication/InactivityLockIntegrationTests.swift:58 and :71 (`clearables.count == 6`, index tests follow at :75, :91). ChristmasTrackerApp.swift:280 comment "6 total".
- ChristmasTrackerApp.swift: AppDependencies (:81 to 141): makeMock :97 (MockListRepository :102), makeReal(generatedClient:) :109 (GeneratedClientListRepository :114, NetworkItemRepository :115), the legacy `make()` :121 whose `.real` branch (:125 to 138) builds a MOCK auth repository and MockListRepository(withMockData: false); buildGeneratedClient :148 (returns nil when mode is not real or the URL is nil, LogError at :170 interpolating the thrown error). The composition root (init): builtClient :244; THE MOCK FALLBACK at :257 to 262 (`if apiMode == .real, let client = builtClient { makeReal } else { makeMock() }`); ListService :266 to 271; makeProductionClearables :281; SessionManager :289; AuthenticationService :297; VersionService :305 to 318; environment injection :371 to 374.
- Logging API (Core/Logging/Logger.swift): LogDebug :153, LogInfo :160, LogWarning :167, LogError :173, LogCritical :179 (message, category, metadata).
- Profile: Features/Profile/Views/ProfileView.swift: environment authenticationService only; body sections in order UserInfoCardView, SettingsSectionView (toggle model; stub callbacks), AboutSectionView, LogoutButtonView; helpers SectionHeaderView, SettingsRowView, CardContainerView. A Children row goes in a new section between Settings and About.
- CreateListView (Features/Lists/Views): recipient is `authenticationService.currentUser?.id` (:178 to 181); input via ListFormValidation.makeCreateInput (:188 to 194).
- Tests reading ListService.isLoading: ListServiceSessionSafetyTests.swift:135, :185; ListServiceTests.swift:67, 249, 418, 486, 516, 533, 566, 622, 650, 672, 700, 723, 739. The myRole scan: ChristmasTrackerTests/Features/Lists/ListSourceScanTests.swift (regex `\.myRole\b` at :195, scope Features/Lists, Features/Dashboard, PreviewContent, four Core/Models files) and ListViewScanTests.swift:60, :210.

## Log calls in Features/ that interpolate list, person or child values (to fix or justify)
- Items/Services/ItemService.swift:99 (list id), :151 (item name), :177 (whole item).
- Items/Repositories/NetworkItemRepository.swift:20, :29, :37 (list id; item name), :46, :63 (item names).
- Items/Repositories/MockItemRepository.swift:40 (list id), :72, :107, :124 (item names).
- Authentication/Repositories/MockAuthenticationRepository.swift:36, :63 (email).
- Purchases/Views/PurchaseHistoryView.swift:175 (`\(error)`, unknown contents).
- Lists code, GeneratedClientListRepository and ListService log only counts or constants.
Item names are item data, not list or person values; they are listed for K0's scanning test decision (the test pattern names list ids, emails and person names; item names are handled in K0 only where they match the pattern or the brief's "other Log call that interpolates a list id, list name, email, or person value").

## Doc check against the brief
All server facts in the brief agree with the guide, privacy matrix and error codes (4006, 4009, 4010, 4011, 5004, 6501 present). Gaps: the guide section 7.3 does not mention the 409 on addMember although the spec has it; the privacy matrix does not show the 422 on deleteChild. Not contract disagreements.

---

# Gate 1 specs

## K0: carried-forward fixes
- Contract slice: none (client behavior). Path: full pipeline (session, composition root, privacy-sensitive logging).
- Acceptance: as the K0 text in the task. Pure `resolveBootstrap(mode:clientAvailable:) -> BootstrapState {ready, failed}` (nonisolated, Sendable); `ConfigurationErrorView` driven by a pure `ConfigurationErrorState` (message, showsSignIn == false); inert repositories (throw a typed unavailable error, never data) built when failed; one Sentry event, category only; AppDependencies.make() real branch deleted. ListService: session-local deleted-ids set (cleared at teardown), separate `isLoadingLists`, `isLoadingDetail`, `isMutating` flags replacing `isLoading` (tests keep every assertion, mapped to the right flag); detail and edit screens leave on shouldLeaveScreen, dashboard drops the list; log hygiene plus a text-scanning test over Features/**/*.swift.
- Scope: ChristmasTrackerApp.swift, new Core/Composition or Features/Bootstrap files, ListService, list/dashboard views, ItemService and any Log call matching the pattern, ListErrorPresentation consumers, tests.
- New interface: yes (BootstrapState, resolveBootstrap, ConfigurationErrorState/View, inert repositories, loading flags). Scanning-test pattern, allowlist and rationale are written in the K0 report.

## M1: domain models, errors, pure rules
- Contract slice: MemberSummary, MembershipRole, the child shapes, error codes 4006, 4009, 4010, 5004, 6501; privacy-matrix members and children rows.
- Acceptance: as the M1 text in the task. New pure Sendable types: ListMember (rebuilt, adds a membership role covering owner and co-owner rows as the roster provides), MemberRole, Child, ChildRelationship, AddMemberInput, CreateChildInput, CoOwnerChange {unchanged, set(email), clear} on UpdateListInput; ListError gains memberEmailNotFound, alreadyMember, membershipNotFound (and any other the documented responses need); ChildError; MembersSectionState, CoOwnerSectionState, ChildrenState, CreateListRecipientOptions, form validity functions, request builders.
- Roster-row note: the generated MembershipRole has only member and viewer, and the owner and co-owner rows are identified in the roster by the detail's owner and coOwner person ids, not by a role on the wire. The row's membership label is derived from the detail (owner id, co-owner id, else the row role) inside MembersSectionState only; the viewer's own role is never read.
- Truth-table reduction: MembersSectionState depends on four flags (canSeeMembers, canManageMembers, canLeaveList, canSetCoOwner) plus members presence plus per-row kind; enumerate all 2^4 flag combinations times presence times row kind against an independent oracle, plus the seven named personas as concrete fixtures.
- Scope: Core/Models, Features/Lists/ViewState (new MembersViewState, CoOwnerViewState), new Features/Children/ViewState, tests, scan test extension. New interface: yes.

## M2: repositories, services, mocks
- Contract slice: addMember, removeMember, listChildren, createChild, deleteChild, updateList(coOwnerEmail), every documented response.
- Acceptance: as the M2 text in the task. MemberRepository and ChildRepository protocols (-ing suffix rule: protocol names follow the existing repository naming), GeneratedClientMemberRepository, GeneratedClientChildRepository, Mock versions, ListService addMember/removeMember/leaveList/setCoOwner (no clearCoOwner: payload cannot express null), ChildService (@MainActor @Observable) registered as clearable 7 (pinned count 6 to 7, reason: a new session-scoped store), environment key, composition. A Docs/contract-issues.md row for the coOwnerEmail clearing gap is added in this story.
- New interface: yes. Path: full pipeline.

## M3: screens
- Contract slice: flags only. Views: Members section (roster, add sheet, remove, leave) in ListDetailView, co-owner control in EditListView, Children screen from Profile, recipient picker in CreateListView. All bind to the M1 view-state functions. swiftui-expert-skill applied. Dead code removed and named in the report.
- New interface: view-state glue only. Path: full pipeline (capability-flag-driven UI).

## M4: real-mode check and handoff
- Docs only. Handoff Docs/handoffs/2026-11-09-ios-to-brian-i3b.md (or the run date) with the "Brian's real-mode check" section carrying exactly the 13 steps of the task text, and Docs/reports/I3b-5-handoff.md. Path: solo plus both reviewers per the task.
