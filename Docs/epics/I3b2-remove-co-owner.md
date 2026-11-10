# I3b-2: Remove the co-owner through the new removeCoOwner operation
Track: iOS. Depends on: I3b (reviewed and committed on feat/i3b-members-children, not yet merged). Blocks: nothing.
Contract state: CONFORMANT at decisions revision 28 (backend cf6b90c, spec sha256 begins 88d054721d59). API models come only from the generated client.

Why: I3b could not clear a co-owner because the generated update payload cannot send an explicit JSON null (Docs/contract-issues.md row 2). The backend answered with decision L15: `DELETE /lists/{id}/co-owner` (operationId `removeCoOwner`). This package regenerates the client from revision 28, clears the co-owner only through that operation, and shows "Remove co-owner" in the edit screen.

## Server facts (decision L15, client guide sections on lists and the co-owner; confirmed against the synced files on 2026-11-10)
- `DELETE /tracker/v2/lists/{id}/co-owner`, operationId `removeCoOwner`, bearer required, no request body.
- Same rules as `PATCH /lists/{id}` with `coOwnerEmail: null` (it delegates to it): owner only (L12).
- 200: the updated `ListDetail` with `coOwner: null`; flags and roster are recomputed for the caller, so the screen updates from the response and does not refetch.
- 403 `FORBIDDEN` for the co-owner and for MEMBER-role members, VIEWER-role members and PUBLIC non-members.
- 404 `LIST_NOT_FOUND` for an unknown list or a non-member of a private list (never "forbidden").
- 422 `CANNOT_EDIT_ARCHIVED_LIST` on an archived list.
- Idempotent: 200 with no change when there is no co-owner.
- The usual 401, 403 `ACCOUNT_DISABLED`, 404 `USER_NOT_FOUND`, 429 and 500 apply. Setting a co-owner still uses `PATCH /lists/{id}` with `coOwnerEmail`.
- "Remove co-owner" is offered exactly when `canSetCoOwner` is true (owner only) and a co-owner exists.

## Decisions
- Removing the co-owner is a dedicated action with its own confirmation, separate from the edit form's Save: a "Remove co-owner" button in the co-owner section, shown when `CoOwnerSectionState` says clearing is supported, `canSetCoOwner` is true and the detail has a co-owner.
- The `.clear` case is removed from `CoOwnerChange` (and any dead path in `UpdateListInput` and the edit screen); the PATCH path only sets.
- After a successful removal the service updates `currentListDetail`, the list in `lists` and the cache from the RETURNED `ListDetail`; no refetch.
- The service is session-safe like the other list mutations (generation, cancellation, nothing written after the session ended; the mutating flag; the I3b removal-sequence guard is unaffected).
- Errors: 403 forbidden, 404 notFound (leave the screen), 422 archivedReadOnly (leave the screen), 429 rateLimited; plain messages; no list names, ids or emails in logs.
- No workaround for clearing other than the new operation (no hand-built request, no empty-string guess, no PATCH null).

## Scope
- R1: regenerate the derived spec and the generated client from revision 28 (additive: the new operation and its types).
- R2: `ListRepository.removeCoOwner(listId:)`, the generated-client and mock implementations, `ListService.removeCoOwner(listId:)`; remove the typed refusal of a clear request and the `.clear` case.
- R3: `CoOwnerSectionState`, the edit screen's co-owner section with a confirmation dialog.
- R4: contract-issues row 2 resolved; the I3b handoff updated in place for one combined real-mode check; a short I3b-2 handoff.

Non-goals: any I3b behavior beyond the co-owner paths; items, purchases, stats, children, the members screens beyond the co-owner control, the privacy cover, the lock, Face ID, FirstLaunchWipe, the release scripts.

## Acceptance
- The derived-spec transformed-property count guard holds (5) and the regeneration changes nothing except the new operation.
- Clearing goes only through `removeCoOwner`; the PATCH path only sets and never carries a null `coOwnerEmail`.
- Through the real factory-built client with a fake transport, every documented response of `removeCoOwner` maps as specified (200, idempotent 200, 401, 403, 404, 422, 429 with retryAfter, 500, undocumented, transport failure) with guide-accurate fixtures including the full meta object.
- The service updates from the returned detail without a refetch and writes nothing after teardown or a user switch (deterministic tests).
- The Remove control shows exactly when `canSetCoOwner` is true and a co-owner exists; no role is read.
- notFound and archivedReadOnly leave the screen.
- No list name, id, email or member name in any log call in changed or added files.
- No change under contract/ beyond Brian's sync commit, `.claude/`, any `.pbxproj`, the synced Docs files, or LocalPackages/TrackerAPI beyond R1.

---

# Inventory (read-only, taken 2026-11-10 on branch feat/i3b-members-children before any code change)

Preconditions: P1 clean tree, newest commit ce80457 (Brian's contract sync), below it 0b32e4b (I3b-fix report) and cfaa81c (I3b handoff). P2 STATUS.md CONFORMANT, VERSION decisions_revision=28, spec_sha256 begins 88d054721d59; DECISIONS.md contains L15; client-guide.md documents `DELETE /lists/{id}/co-owner`; contract/openapi.json contains `removeCoOwner`. P3 `scripts/verify.sh` failed at its first gate ("ERROR: Derived spec is out of date. Run scripts/make-client-spec.sh to regenerate."); `swift test --package-path "LocalPackages/TrackerAPI"`: 212 tests in 16 suites, 1 issue (the test "Derived spec file matches the Swift-transform applied to contract/openapi.json").

## Production code (file and line)
- `Core/Models/MemberInputs.swift:28-35`: `enum CoOwnerChange { unchanged, set(email:), clear }`; `.clear` at :34 (doc comment at :33).
- `Core/Models/ListDetail.swift:161-168`: `UpdateListInput` holds `let coOwner: CoOwnerChange` (:166), init default `.unchanged` (:168).
- `Features/Lists/ViewState/ListViewState.swift:222`: a view-state input builder takes `coOwner: CoOwnerChange = .unchanged`.
- `Features/Lists/ViewState/CoOwnerViewState.swift:11-29`: `CoOwnerSectionState`; `static let clearingSupported = false` (:17); `showsRemove = canSetCoOwner && coOwner != nil && clearingSupported` (:27); `CoOwnerFormValidation.makeChange` returns `CoOwnerChange?` (:45).
- `Features/Lists/Repositories/GeneratedClientListRepository.swift`: `updateList` maps `.unchanged`/`.set`, and TYPED REFUSAL of `.clear` at :145-146 (`ListError.validation(message: coOwnerClearUnavailableMessage)`, before any request); the message constant `coOwnerClearUnavailableMessage` at :227; `createList` passes `coOwnerEmail: nil` (:95).
- `Features/Lists/Repositories/MockListRepository.swift:125-126`: the mock refuses `.clear` with the same message.
- `Features/Lists/Views/EditListView.swift`: `coOwnerState` (:39-40), `coOwnerChange` builds `.clear` when `showsRemove` and `removesCoOwner` (:49-50), `CoOwnerFormValidation.makeChange` (:52), `canSubmit` (:59), co-owner email field (:169-177).
- `Features/Lists/Services/ListService.swift`: existing `setCoOwner(listId:email:)` goes through `updateList` (used in tests at `ListServiceMemberTests.swift:444-489`).

## Tests that mention the old behavior
- `ChristmasTrackerTests/Core/MemberDomainTests.swift:47-73`: `.clear` equality and `UpdateListInput` carrying `.clear` (to be rewritten).
- `ChristmasTrackerTests/Features/Lists/ListUpdateInputCoOwnerTests.swift:26,44-47`: "Clearing the co-owner alone gives an input that carries .clear" (exclusively the old behavior; to be removed).
- `ChristmasTrackerTests/Features/Lists/GeneratedClientListRepositoryCoOwnerTests.swift:10,36,114-118`: `.clear` refused before any request (exclusively the old "clearing is blocked" behavior; to be removed).
- `ChristmasTrackerTests/Features/Lists/MockMemberRepositoryTests.swift:257-264`: mock refuses `.clear` (exclusively the old behavior; to be replaced).
- `ChristmasTrackerTests/Features/Lists/CoOwnerSectionStateTests.swift:5-7,32-51`: `clearingSupported == false` and `showsRemove == false` always (exclusively the old behavior; to be rewritten).
- `ChristmasTrackerTests/Features/Lists/CoOwnerFormValidationTests.swift:52`: `change != .clear` (to be dropped with the case).
- `ChristmasTrackerTests/Features/Lists/MembersTruthTableTests.swift:44,170`: truth table uses `CoOwnerSectionState` (showsRemove expectations change).
- `ChristmasTrackerTests/Features/Children/MembersChildrenViewScanTests.swift:359` and `Lists/MembersSourceScanTests.swift:155`: source scans that name `CoOwnerSectionState`.

## Generated signatures of `Operations.RemoveCoOwner`
Read after the R1 regeneration from `GeneratedSources/Types+Operations.swift:8903` (signatures only; the generated sources are the truth):
```swift
Operations.RemoveCoOwner.Input(path: .init(id: Swift.String), headers: .init())   // no body
// Output (frozen enum), cases:
//   ok(Operations.RemoveCoOwner.Output.Ok)               // 200
//   unauthorized(Components.Responses.UnauthorizedError)  // 401
//   forbidden(Components.Responses.ForbiddenError)        // 403
//   notFound(Components.Responses.NotFoundError)          // 404
//   unprocessableContent(Components.Responses.UnprocessableEntityError) // 422
//   tooManyRequests(Components.Responses.RateLimitError)  // 429
//   internalServerError(Components.Responses.InternalError) // 500
//   undocumented(statusCode: Swift.Int, OpenAPIRuntime.UndocumentedPayload)
// Output.Ok.Body.json -> JsonPayload { success: Swift.Bool; data: Components.Schemas.ListDetail; meta: Components.Schemas.Meta }
// Client: func removeCoOwner(_ input: Operations.RemoveCoOwner.Input) async throws -> Operations.RemoveCoOwner.Output
```
There is no badRequest and no conflict case. The payload is the same `Components.Schemas.ListDetail` that getList and updateList return, so the existing `mapListDetail` applies.

---

# Gate 1 spec, story R1 (regenerate; no new interface, solo-weight, regeneration only)
- Contract slice: the derived spec gains `/tracker/v2/lists/{id}/co-owner` (DELETE, `removeCoOwner`); nothing else.
- Acceptance: `scripts/make-client-spec.sh` prints "Transformed 5 null-schema properties."; the derived-spec diff has only insertions for the new path; package tests 212 pass unchanged (including the public-operation pin test); the app builds; `scripts/verify.sh` is green.
- Files: `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json` (regenerated), this brief, `Docs/reports/I3b2-1-regenerate.md`.
- New interface: none.

## Contract issue
`Docs/contract-issues.md` row 2 (filed 2026-11-09, "Open: blocks only clearing a co-owner (I3b)") is resolved in R4.
