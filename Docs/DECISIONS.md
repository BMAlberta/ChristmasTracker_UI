# Christmas Tracker v2 Decision Log

**Revision:** 34 (2026-11-12)
**Status:** Draft for owner review
**Canonical copy:** `API_rewrite/Docs/DECISIONS.md`. The copies in `web-ui` and the iOS repo are read-only mirrors at the same relative path.
**Applies to:** `API_rewrite` (backend), `web-ui`, and the iOS app

## 0. How to use this log

- The backend code is the source of truth. The OpenAPI spec comes from the backend, and both clients generate their types from it.
- The PRD and design docs state intent. Where they conflict with this log, this log wins, and the PRD gets amended (section 11).
- Each decision has an ID. Agents cite the ID in commits and acceptance checks.
- Tags: **B** backend, **W** web, **I** iOS.

### Changes in revision 34

- **S15 (new)** [B W I]: an empty string clears a purchase's notes or tracking number, on both PATCH operations; the field is stored and returned as null.

### Changes in revision 33

- **S14 (new)** [B W I]: a purchaser can delete their own purchase; the item status, the counts and the buyer's spend follow.

### Changes in revision 32

- **S13 (new)** [B W I]: a purchase never changes the status of a WRAPPED or GIFTED item; the purchase and the quantity counts are still recorded.

### Changes in revision 31

- **P24 (new)** [B W I]: Item carries quantityPurchased and quantityRemaining, returned only to callers who can see gift activity.
- **S12 (new)** [B W I]: the budget confirmation token is also bound to the buyer's spend at the time of the warning, so a repeat purchase gets a fresh warning.

### Changes in revision 30

- **L17 (new)** [B W I]: a child can be deleted when none of their lists is ACTIVE or DRAFT; archived lists stay visible with the child's name.

### Changes in revision 29

- **L16 (new)** [B W I]: archiving a list closes list management only; items, off-list items and purchases are still accepted on an archived list.

### Changes in revision 28

- **L15 (new)** [B W I]: DELETE /lists/{id}/co-owner clears the co-owner with the same rules as setting it; PATCH with coOwnerEmail null keeps working.

### Changes in revision 27

- **D9 (new)** [B]: the api container runs without no-new-privileges and without init on the production host (snap Docker); the compensating controls are dropped capabilities, a read-only root, a non-root user and no published port.

### Changes in revision 26

- **P22 (new)** [B W I]: ListDetail.members is returned only to callers who may call GET /lists/{id}/members, and a new canSeeMembers flag says so; this closes the deferral in C14.
- **C17 (new)** [B W I]: USER_NOT_FOUND (4002) means only that the account behind the authenticated token no longer exists; GET /users/{id} returns PERSON_NOT_FOUND for a stranger or an unknown id.
- **P23 (new)** [B W I]: ListSummary and ListDetail carry the required booleans canEditList, canDeleteList, canManageMembers, canSetCoOwner and canLeaveList, which say what the server accepts for the caller on that list now (false on an archived list except canLeaveList).

### Changes in revision 25

- **A16 (new)** [B W]: POST /auth/register accepts an optional rememberMe (default true) with the same meaning as on login.

### Changes in revision 24

- **C16 (new)** [B W I]: the user object returned to its owner always carries a non-null email, and login, register and refresh return expiresIn (seconds, derived from JWT_EXPIRY).

### Changes in revision 23

- **C15 (new)** [B W I]: every operation documents the middleware statuses (429 and 500 everywhere; 401, 403 and 404 on authenticated operations; 400 on operations with a request body).

### Changes in revision 22

- **D7 (revised)**: Behind the Cloudflare Tunnel the client IP comes from the `CF-Connecting-IP` header (`CLIENT_IP_SOURCE=cf-connecting-ip`), trusted only when the connecting address is inside `TRUSTED_PROXY_CIDRS`; Express `trust proxy` is not used. The auth rate limiter keys on the client IP plus the normalized email, and the general limiter keys on the verified user id, otherwise on the client IP.
- **D8 (new)**: v2 runs as a Docker Compose stack (the API and PostgreSQL 18) on the production host. The Cloudflare Tunnel connector reaches the API over a shared Docker network for the path `^/tracker/v2` of `api.bmalberta.com`, ahead of the existing v1 rule; the API publishes no host port and Traefik is not in the API path. Migrations run as an explicit deploy step, never at container start. Backups are nightly `pg_dump` files encrypted with `age` and stored in R2.

### Changes in revision 21

- **A15 (new)** [I B]: iOS keeps its refresh token across logout; clients never send a refresh token to logout.

### Changes in revision 20

- **C9 (new)**: Every integration and e2e response is validated against its documented OpenAPI response schema in strict mode in CI.
- **C10 (new)**: Every path key in the OpenAPI spec carries the /tracker/v2 prefix; `servers` entries are host-only. Clients set their generated client's base URL to the host only and never append the prefix.
- **C11 (new)**: Money amounts in responses are JSON numbers with at most two decimal places on every endpoint. Decimal strings are not used.
- **C12 (new)**: Every operation documents a 500 response using the shared Error envelope.
- **C13 (new)**: Every purchase response includes item {id, name, listId}.
- **C14 (new)**: List summaries (GET /lists) carry memberCount (the number of ACTIVE members, always present) and no members array. List detail carries members as an optional field. Gating detail members by L9 is deferred.

### Changes in revision 19

- **P14 (rev 2)**: VIEWER-role members and PUBLIC non-members receive **neither** `itemCount` **nor** `purchasedCount` on `ListSummary` and `ListDetail`. Both fields are gated on `canSeeGiftActivity`, which is `false` for viewers and non-members. The previous revision 4 wording erroneously stated "their `itemCount` reflects only visible items"; in the implementation `itemCount` is `undefined` for any caller with `canSeeGiftActivity = false`. Clients must count visible items from the items list if they need a count. PRD 3.2 table and 7.2 reporting rules updated accordingly.

### Changes in revision 18

- **S11 (new)**: Money amounts in requests carry at most two decimal places; otherwise 400 INVALID_PRICE. The shared `moneyAmountSchema` validates `String(value)` against `/^\d+(\.\d{1,2})?$/`, which also rejects exponent forms and floating-point noise (e.g. `0.1 + 0.2`). Applies to `totalCost`, `expectedUnitPrice`, `totalBudget`, and `maxSpend`. The internal `toCents` rounding is unchanged. See section 6.

### Changes in revision 17

- **R1 (revised — implemented)**: The append-only audit log is implemented as a single `audit_log` table. All membership lifecycle (add/remove/leave/re-add/co-owner), list (created/visibility-change/archived), budget (created/updated/deleted/duplicated), and shipping-status events are written inside the same transaction as the change they record. There is no read API in v1; audit rows are queried by administrators using `npm run audit:show`. Payloads carry ids, roles, statuses, and amounts in integer cents only; emails, names, password hashes, tokens, and notes are excluded. Retention is indefinite. Dedicated per-entity history tables remain deferred.

### Changes in revision 16

- **R1 (new — revised in revision 17)**: v1 persists item status history; budget, membership, and shipping changes are represented by current state and timestamps. Event tables are deferred. Specifically: `ItemStatusHistory` records every item status transition (previous status, new status, userId, reason, timestamp). Membership lifecycle is tracked by state and timestamps on the `memberships` row (`createdAt`, `removedAt`); no separate `MembershipEvent` table. Budget changes are persisted in place on the `Budget` record; no `BudgetChangeHistory` table. Shipping transitions are captured by `shippedAt`/`deliveredAt` timestamps per S3; no per-transition event log. Dedicated event tables for membership, budget, and shipping are deferred to a future work package.

### Changes in revision 15

- **P16 (updated)**: INVITE_ONLY and FRIENDS_ONLY both behave as PRIVATE for non-members. Non-members of either list type receive the identical 404 as a PRIVATE list on every route. FRIENDS_ONLY is reserved for a future friends-graph feature; when that system is built, this decision must be revisited. INVITE_ONLY is available for invite-based access flows. The `ListVisibility` enum retains all four values: PRIVATE, INVITE_ONLY, FRIENDS_ONLY, PUBLIC. The previous wording erroneously implied INVITE_ONLY had been removed; it exists and has identical non-member behavior to FRIENDS_ONLY.

### Changes in revision 14

- **P21 implemented** on branch `fix/item-type-by-role`: `offList` removed from the `createItemSchema`; `createItem` now derives the value from `privacy.canAddOffList` (true for MEMBER-role callers, false for owners and co-owners). Old clients that send an `offList` field have it silently stripped by Zod. The `CANNOT_CREATE_OFF_LIST_ITEM` error code is no longer reachable from the create-item path; the P5 rev-7 note about "403 CANNOT_CREATE_OFF_LIST_ITEM for owners" no longer applies (owners simply produce normal items regardless of any stale `offList` field in the body). P5, P20, and P21 wording from revision 13 already describes the implemented behaviour and is unchanged.

### Changes in revision 13

- **P21 (new)**: Item type is derived from who adds it. An item added by an owner or co-owner is a normal item; an item added by a member is an off-list item. `POST /lists/:id/items` carries no `offList` flag; the server derives the type from the caller's role and ignores an `offList` field if sent. See PRD 4.1.
- **P5 (updated)**: Off-list items are created when a member calls `POST /lists/:id/items` (P21); the item type is derived from the caller's role, not a request flag. Visibility and edit/delete rules unchanged: all non-blind viewers can see them; only the creator can edit or delete.
- **P20 (updated)**: `canCreateItem` is `true` for owners, co-owners, and members (including blind owners). Clarification: the resulting item type depends on the caller's role per P21 — owners and co-owners produce normal items; members produce off-list items. `canCreateItem` continues to control whether the add-item button is shown.

### Changes in revision 12

- **V1**: `app_version_policies` schema expanded with `minimumBuild`, `latestBuild`, `recommendedVersion`, `manifestUrl`, `ipaUrl`, `releaseNotes`, `enabled`, and `updatedAt` (`@updatedAt`). `updateUrl` and `forceUpdate` dropped. Seed rows for `ios` (enabled) and `web` (disabled).
- **V2**: `GET /tracker/v2/app/version-check` implemented. Public, no authentication required. Returns `state` (`ok`, `update_recommended`, `force_update`) plus all policy fields. Additive-only response shape.
- **V3/V4**: `POST /auth/login` and `POST /auth/refresh` return `426 VERSION_OUTDATED` when `X-Platform: ios` and the build or version is below the minimum. A missing `X-Build` or `X-App-Version` header is not enforced — it is not a security control.
- **V5**: `GET /app/version-check` supports `ETag` (derived from `updatedAt`) and `If-None-Match` for `304` responses. `Cache-Control: public, max-age=60`.
- **V6**: Version comparison uses build numbers first (integer comparison when both are > 0), falls back to semantic version.
- **V7**: Policy changes are applied via `npm run policy:set -- --platform <p> [--min-build N] [--latest-build N] [--latest-version X.Y.Z] [--manifest-url URL] [--ipa-url URL] [--notes "text"]`.
- **V9**: The `web` platform has a disabled policy row and always returns `state: ok`. Unknown platforms also return `state: ok`.
- **V10**: Raising `minimumBuild` is the mechanism for breaking-contract changes. The `policy:set` script is the admin tool.
- **Clarifications**: (1) Missing version headers on login/refresh are not enforced — missing is not a security control. (2) Unknown platform returns `ok` from `GET /app/version-check`. (3) Cache-Control on `GET /app/version-check` is `public, max-age=60`.

### Changes in revision 11

- **L3 (E5)**: The 404 error code for an unauthorised recipient in POST /lists is now `RECIPIENT_NOT_FOUND` (4010) instead of `LIST_NOT_FOUND` (4003). The HTTP status remains 404 and the body is identical for all three cases (nonexistent id, another adult, stranger's child). This distinguishes "you can't create a list for this person" from "that list ID doesn't exist". See section 5.

### Changes in revision 10

- **P20 (new)**: `canCreateItem` is returned in `ListSummary` and `ListDetail`. It is `true` for owners, co-owners, and members (including blind owners on their own lists), `false` for viewers and non-members. Clients use it to decide whether to show the add-item button. See section 5.
- **P14 (E1 fix)**: `canSeeGiftActivity` is now `false` for PUBLIC non-members (identical to VIEWER-role members). Previously the formula `!isBlind && !isViewerRole` evaluated to `true` for non-members since they have no role; the corrected formula adds `(isOwner || isCoOwner || isMemberRole)`.

### Changes in revision 9

- **L3 (revised)**: Any `recipientId` that is not the caller themselves or one of the caller's own children returns the identical 404 (`LIST_NOT_FOUND`). This includes nonexistent IDs, another adult, and a credential-less child belonging to another user. The previous 403 `NOT_PARENT_OF_RECIPIENT` for "another adult" is eliminated; the same 404 body is returned for all non-authorised recipients. See section 5.

### Changes in revision 8

- **P19 (new)**: `GET /users/{id}` is tiered by relationship. Self gets the full profile; caller's own child gets id/firstName/lastName/displayName; a user sharing any active list gets PersonSummary (id, firstName, displayName); strangers get the identical 404 as a nonexistent id. See section 5.

### Changes in revision 7

- **P18 (new)**: A non-member of a PUBLIC list gets 403 on every write route (PATCH/DELETE list, POST/PATCH/DELETE/status items, POST/DELETE members). Read routes on PUBLIC lists remain 200. See section 5.
- **P14b (new)**: The `role` field on `PrivacyList.memberships[]` is required (not optional) in TypeScript. A row without a role is treated as neither `member` nor `viewer` — fail-closed. See section 5.
- **L3 (clarified, superseded by revision 9)**: Attempting to create a list for a credential-less child who belongs to another user returns 404. Creating for an adult who is not your child returned 403 `NOT_PARENT_OF_RECIPIENT`. (Revision 9 changed this: adults now return 404 as well.)
- **P5 (corrected)**: `createItem` previously allowed owners and co-owners to create off-list items (code bug: `!isOwnerOrCoOwner` was ORed into the guard). Fixed — `canAddOffList` is the sole gate for off-list creation. Owners and co-owners get 403 `CANNOT_CREATE_OFF_LIST_ITEM`.

### Changes in revision 6

- **L14 (new)**: Co-owners may now delete a list (same as owners). Previously `deleteList` guarded on `ownerId` only; now it accepts `ownerId OR coOwnerId`. Test coverage in `__tests__/integration/coowner-email.test.ts`.
- **T5 clarification**: The `meta` object returned by `GET /purchases` is included in the top-level response body alongside `data`, not nested inside it. `sendSuccess` was updated to accept an optional `meta` parameter that is spread into the response body's existing meta object. This is the authoritative behaviour going forward.
- **T10 (updated)**: `itemsPurchased` and `purchaseCount` are distinct fields in stats responses. `itemsPurchased` is the sum of `quantity`; `purchaseCount` is the number of purchase records. `spendByRecipient[]` entries carry `{ recipientId, displayName, spent, itemsPurchased }`.
- **T11 (new)**: `budget` block shape in stats responses: `{ totalBudget, totalSpent, remaining, recipients[] }` where each recipient has `{ recipientId, displayName, budget, spent, remaining }`. All money fields are floating-point dollars computed via integer-cents arithmetic (toCents/fromCents).

### Changes in revision 5

- **L8** (revised): roles are `member` and `viewer` only. An unknown email (or a user who cannot log in) returns `MEMBER_EMAIL_NOT_FOUND` (4009, HTTP 404).
- **L9** (revised): any active member (role `member` or `viewer`) may remove themselves via `DELETE /lists/:id/members/:userId`. Viewer-role members still get 403 on `GET /lists/:id/members` and `POST /lists/:id/members`.
- **L12** (revised): `coOwnerEmail` replaces `coOwnerId` in create and update request bodies. `coOwnerId` remains in all responses. Setting `coOwnerEmail` when a co-owner already exists replaces the previous co-owner. If the new co-owner is currently a member, that membership is deleted in the same transaction. Only the owner (not the co-owner) may set `coOwnerEmail`. `null` clears the co-owner.
- **L13** (clarified): the member route also rejects any user who cannot log in (null email or null passwordHash). Error is `MEMBER_EMAIL_NOT_FOUND` (404, not `FORBIDDEN`), so no information about the user's existence is leaked.
- **P17** (new): `updatedAt` is omitted from item responses when `canSeeGiftActivity=false` (blind viewers). The `ItemResponse.updatedAt` field is optional; it is absent when `canSeeGiftActivity=false`.
- **PRD amendment note**: `createItem` and `updateItem` responses also omit `updatedAt` for blind callers (P0 fix found during WP5 testing).

### Changes in revision 4

- **P16 (updated in rev 15)**: INVITE_ONLY and FRIENDS_ONLY both behave as PRIVATE. Non-members of either list type receive the identical 404 as a PRIVATE list on every route. No viewer role is granted for either. FRIENDS_ONLY is reserved for a future friends-graph feature; when that system is built, this decision must be revisited. INVITE_ONLY is available for invite-based access flows.
- **P12** (revised): Blind viewers can always soft-delete items, whether or not purchases exist. Purchase records are kept. Non-blind viewers retain `CANNOT_DELETE_ITEM_WITH_PURCHASES`. Acceptance test 5 updated.
- **P14** (new; revised in revision 19): Viewers of PUBLIC lists see only normal (non-off-list) items. `canSeeOffList` is added as an explicit flag. Non-members of a non-PUBLIC list receive `LIST_NOT_FOUND` (404) identical to a nonexistent ID. **Revision 19 correction:** `itemCount` is also omitted for viewers (not only `purchasedCount`); both fields require `canSeeGiftActivity = true`.
- **P15** (new): `CANNOT_PURCHASE_OWN_LIST` maps to HTTP 403.
- **P5** (clarified): Off-list items are visible to non-blind owners, co-owners, and members (`canSeeOffList=true`). Viewers of public lists and blind users see only normal items (`canSeeOffList=false`).
- **Seed (revision 4)**: Scenario C is now Mike's self-list (owner=recipient=Mike, member=John). Jane added as Tommy's second parent in `user_relationships`.
- **`getPurchaseById`** (restricted): `GET /purchases/:id` now restricted to the purchaser only; list owner access removed.

### Changes in revision 3

- S2: step one only adds `NOT_TRACKED`; step two sets the default and converts rows. Both steps are idempotent. Reason: Postgres rejects `SET DEFAULT` with a new enum value in the transaction that adds it.
- S3: timestamp rules for shipping moves.
- S6: warnings carry a top-level `level`; total warnings carry `year` in `details`; an expired, tampered, or mismatched token is ignored with a warn log.
- A14 (new): `rememberMe` cookie behavior.
- S10 (new): budgets are personal.
- T9 (new): money is never aggregated with JavaScript floating point.
- D6 (new): `SameSite=Strict` cookie requires a shared registrable domain; never seed production.
- D7 (new): trust proxy and auth rate limiter keys behind the tunnel.
- Section 13: acceptance tests 20 to 22.

### Changes in revision 2

- Privacy: blind viewers see no purchase status (P3), one shared privacy helper (P10), own-purchases-only in item detail (P11), owners can purchase on non-blind lists (P7).
- Version enforcement is back in scope as an API-based design (section 3, replacing A11).
- New: email-based co-owner (L12), membership guards (L13), registration code (A12), production deployment (section 8).
- Budgets: overage warnings must check the total as well as per-recipient limits (S6).
- Contract: C1 revised to match the spec the API already serves; CI added (C8).
- Distribution is ad hoc sideloading. App Store items are removed from scope.

---

## 1. Contract and process

| ID | Decision | Applies to |
|----|----------|------------|
| C1 | The API already serves its OpenAPI spec at `/tracker/v2/api-docs.json`, built from route annotations. Until a Zod-first migration, the spec is protected by a parity test (registered routes equal documented routes) and a committed snapshot. CI fails if the snapshot differs from the served spec. | B |
| C2 | Web generates types with `openapi-typescript`. iOS generates types and client with swift-openapi-generator. No hand-written API models. | W, I |
| C3 | Stale specs are retired: `trackerAPISpec.yaml` (repo root) and the `tracker-swagger.json` copy in the Claude project. | B |
| C4 | Every route has at least one integration test. The suite must be green before other backend fixes start. First fixes: the unused `PrismaClient` import in `__tests__/setup.ts` and the unused `checkAppVersion` method (TS6133). The production build path (`tsc`) is verified. | B |
| C5 | Duplicate route mounts (`itemRoutes` under `/lists` and `/items`, `purchaseRoutes` under `/purchases` and `/items`) are replaced with explicit registration. The four zombie routes disappear. | B |
| C6 | iOS gets a Debug-Network scheme that runs against a dev or local backend. Debug builds no longer default to mocks only. | I |
| C7 | Enum values come from generated types. Role values are `owner`, `co-owner`, `member`, `viewer`. | W, I |
| C8 | CI (GitHub Actions) runs `tsc`, the test suite, the route parity test, and the spec snapshot check on every push. No CI exists today. | B, W, I |
| C9 | Every integration and e2e response is validated against its documented OpenAPI response schema, in strict mode in CI. The client sync script treats the contract as CONFORMANT only when this row and Docs/contract-conformance-report.md both exist on main. | B, W, I |
| C10 | Every path key in the OpenAPI spec carries the /tracker/v2 prefix. servers entries are host-only: https://api.bmalberta.com (production) and http://localhost:3010 (development). Clients set their generated client's base URL to the host only and never append the prefix. | B, W, I |
| C11 | Money amounts in responses are JSON numbers with at most two decimal places, on every endpoint. Decimal strings are not used. The conformance harness enforces this exactly. | B, W, I |
| C12 | Every operation documents a 500 response using the shared Error envelope. | B, W, I |
| C13 | Every purchase response includes item {id, name, listId}. | B, W, I |
| C14 | List summaries (GET /lists) carry memberCount (the number of ACTIVE members, always present) and no members array. List detail carries members as an optional field. Gating detail members by L9 is deferred. | B, W, I |
| C15 | Every operation documents the statuses that shared middleware can produce: 429 and 500 on every operation, and on every operation that requires authentication also 401, 403 (`ACCOUNT_DISABLED`) and 404 (`USER_NOT_FOUND`); operations with a request body also document 400. A static check enforces it. | B, W, I |
| C16 | In responses about the authenticated user themselves (login, register, refresh, GET /auth/me, GET /users/me), `User.email` is required and never null. Login, register and refresh return `expiresIn`, the access token lifetime in seconds, derived from `JWT_EXPIRY` and equal to the token's `exp` minus `iat`. | B, W, I |
| C17 | `USER_NOT_FOUND` (4002, HTTP 404) is returned only when the account behind the authenticated token no longer exists, so clients may end the session on it. `GET /users/{id}` returns `PERSON_NOT_FOUND` (HTTP 404) for a stranger or an unknown id, with the identical body for both (P19). | B, W, I |

## 2. Auth and sessions

| ID | Decision | Applies to |
|----|----------|------------|
| A1 | `POST /auth/refresh` accepts the refresh token from the httpOnly cookie or the JSON body. The body field is optional. The cookie is preferred. | B |
| A2 | Login, register, and refresh return the refresh token in the response body only when the client sends `X-Client-Platform: ios`. Web receives a cookie only. | B, I |
| A3 | Login and register save a hashed refresh token to `refresh_tokens`. Today they do not, so every refresh fails. | B |
| A4 | Each refresh issues a new 7-day token (sliding). The previous token stays valid for a 30 to 60 second grace window. Reuse after the grace window revokes the token chain. | B |
| A5 | An absolute cap of 90 days from original login applies. After that, the user logs in with a password. | B |
| A6 | Schema additions for A4 and A5: `rotatedAt` and `sessionStartedAt` on `refresh_tokens`. | B |
| A7 | Biometric login is local only. Face ID, using `.biometryCurrentSet`, releases the Keychain-stored refresh token. If the Keychain item is invalidated, the app shows the password screen without an error. | I |
| A8 | The session ping is replaced by a client-side inactivity lock. | I |
| A9 | The backend biometric endpoint is parked. | B |
| A10 | Forgot-password is deferred. Lockouts are handled by an admin reset script. | B |
| A11 | Replaced by section 3 (version enforcement). | B, I |
| A12 | Registration requires the shared code, held in an environment variable. The verification run did not confirm the v2 API enforces it. Add it if missing, with a test. | B |
| A13 | Accounts are created fresh in v2 through registration with the shared code. No migration from the v1 system. | B |
| A14 | `rememberMe: false` on login gives a session cookie (no `Max-Age`). `true` or omitted gives a persistent cookie with `maxAge` derived from `REFRESH_TOKEN_EXPIRY`. The choice is a signed claim in the refresh JWT and is preserved on every rotation. Tokens issued without the claim count as persistent. | B |
| A15 | iOS keeps its Keychain refresh token across an explicit logout and sends neither a cookie nor a refresh token to POST /auth/logout, so the server session is not revoked. The handler revokes the chain for a refresh token sent in the cookie or, with no cookie, in the JSON body, so clients must never send one. Interim until the biometric credential (A9). | B, I |
| A16 | `POST /auth/register` accepts an optional `rememberMe` boolean in the request body, with the same meaning and default as on login: `true` or omitted sets the persistent refresh cookie (7 days), `false` sets a session cookie. | B, W |

## 3. Version enforcement (API-based)

The design exists in the Phase 3 requirements and the Phase 9.5 plan. The `app_version_policies` table exists, and the `checkAppVersion` method is unwired. No route exists yet.

| ID | Decision | Applies to |
|----|----------|------------|
| V1 | One row per platform in `app_version_policies`: `minimumVersion`, `recommendedVersion`, `latestVersion`, plus ad hoc fields `minimumBuild`, `latestBuild`, `manifestUrl` (the `itms-services` manifest), `ipaUrl`, `releaseNotes`, `enabled`. The App Store `updateUrl` is dropped. | B |
| V2 | `GET /app/version-check` needs no authentication. It returns a state (`ok`, `update_recommended`, or `force_update`) plus the policy fields. The response is additive-only so old builds keep working. | B |
| V3 | Clients send `X-App-Version`, `X-Build`, and `X-Platform` on every request. | W, I |
| V4 | `POST /auth/login` and `POST /auth/refresh` return `426 VERSION_OUTDATED` when the build is below the minimum, so enforcement happens at login without waiting for any config to reach the device. | B |
| V5 | The check endpoint supports `ETag` and `304` with a short `Cache-Control`. Clients fail open on timeout or network error, but a cached `force_update` stays enforced. | B, I |
| V6 | Comparison uses build numbers first and falls back to the marketing version. | B |
| V7 | Policy changes go through an admin script (for example `npm run policy:set`), not manual database edits. | B |
| V8 | iOS `VersionManager` checks on cold start, on resume after 15 or more minutes in the background, and every 6 hours in session. It shows a dismissible prompt for a recommended update and a blocking prompt (Update Now or Logout) for a forced one. It ports the existing installer. It ships in build 1, so build 2 can be delivered without a manual reinstall. | I |
| V9 | Web has a disabled policy row and ignores the check. | B, W |
| V10 | Raising the minimum build is the tool for breaking contract changes. Before the backend drops behavior old builds rely on, raise the minimum. | B, I |

## 4. Lists, recipients, and sharing

| ID | Decision | Applies to |
|----|----------|------------|
| L1 | A list has a recipient, one owner, and at most one co-owner. Owner and co-owner are stored on the list, not in memberships. | B |
| L2 | Children are users with no credentials, linked to parents through `user_relationships`. A child is a recipient only, never an owner. | B |
| L3 (rev 9/E5) | Managed recipients are limited to self or own children. Any `recipientId` that is not the caller or one of their own children returns `404 RECIPIENT_NOT_FOUND` — same HTTP status and body shape as a nonexistent ID, including when the target is another adult (previously 403 `NOT_PARENT_OF_RECIPIENT`, then 404 `LIST_NOT_FOUND`). | B, W, I |
| L4 | The recipient cannot change after a list is created. The API rejects attempts. | B |
| L5 | One list per recipient per year. A conflict returns `409 LIST_ALREADY_EXISTS`, and the UI links to the existing list. | B, W, I |
| L6 (rev 2) | `recipientId` stays required on `POST /lists`. For "For me", the client sends its own id. The create screen has two choices: "For me" (default) and "For someone I manage". The second lists the user's children from `GET /users/me/children`, with an inline "Add a child" that asks for a name only. | W, I |
| L7 | Lists display "For {recipient}" and "Managed by {owner} & {co-owner}". The "Created by" label is removed. | W, I |
| L8 (rev 5) | Sharing is direct add. `POST /lists/:id/members` takes `{ email, role }`, where `role` is `member` or `viewer` only. The email is resolved case-insensitively. Only the owner and co-owner can call it. An unknown email (or a user who cannot log in) returns `MEMBER_EMAIL_NOT_FOUND` (404). | B |
| L9 (rev 5) | Member routes: `GET /lists/:id/members` and `DELETE /lists/:id/members/:userId`. Any active member (role `member` or `viewer`) may remove themselves. Only owner and co-owner may remove others. Owner and co-owner cannot be removed via this route. Role changes are deferred. | B |
| L10 | Target state is accept and decline. The same add route will create `INVITED` memberships, with `GET /invitations` and `POST /invitations/:id/accept` and `/decline`. Invitation responses will not reveal whether an account exists. | B |
| L11 | Web wires its `ShareListModal` stubs to the member routes (`memberships` paths become `members`). iOS adds a sharing sheet in build 2. | W, I |
| L12 (rev 5) | The co-owner is set by `coOwnerEmail` on `POST /lists` and `PATCH /lists/:id`, resolved case-insensitively. Only the owner may set it. Setting when one exists replaces it. If the new co-owner is currently a member, that membership is deleted in the same transaction. `null` clears the co-owner. `coOwnerId` is removed from all write bodies (stays in responses). An unknown email or a no-login user returns `MEMBER_EMAIL_NOT_FOUND`. | B |
| L13 | The membership route rejects the recipient, the owner, and the co-owner as members. | B |
| L14 (new) | Co-owners may delete a list (same as owners). `deleteList` accepts `ownerId OR coOwnerId`. | B |
| L15 | `DELETE /lists/{id}/co-owner` clears the list's co-owner and returns the updated `ListDetail`. It applies the same rules as clearing the co-owner through `PATCH /lists/{id}` with `coOwnerEmail: null` (it delegates to it): owner only (L12), 422 `CANNOT_EDIT_ARCHIVED_LIST` on an archived list, the P14 404 for a hidden list, and it succeeds without a change when there is no co-owner. `PATCH` with `coOwnerEmail: null` keeps working; clients whose generated code cannot send an explicit null use the `DELETE` operation. | B, W, I |
| L16 | Archiving a list closes list management only: `PATCH /lists/{id}` returns 422 `CANNOT_EDIT_ARCHIVED_LIST` (including un-archiving) and the management capability flags are `false`. Items, off-list items and purchases are still accepted on an archived list, and `canCreateItem`, `canPurchase`, `canAddOffList` and `canSeeGiftActivity` do not depend on the list status, so a gift recorded late (for example a forgotten purchase) can still be entered. Clients drive the UI from the flags and add no archived-specific rule. | B, W, I |
| L17 | `DELETE /users/me/children/{id}` succeeds when none of the child's lists is ACTIVE or DRAFT (a child with no lists, or only ARCHIVED lists); otherwise it returns 422 `CANNOT_DELETE_RESOURCE`. Deleting removes the parent link and deactivates the child; the child's ARCHIVED lists stay readable by their owner, co-owner and members, with the child's display name, the child no longer appears in `GET /users/me/children`, and no new list can be created for the child. Clients that want to remove a child with active lists archive each list first (`DELETE /lists/{id}`) after asking the user to confirm. | B, W, I |

## 5. Privacy

| ID | Decision | Applies to |
|----|----------|------------|
| P1 | A viewer is **blind** if they are the recipient, or if they are the owner or co-owner of a list whose recipient is a user who can log in (a self-list). | B |
| P2 | Owners, co-owners, and members of a list for a child (no login) are **not blind**. Members are never blind. | B |
| P3 (rev 2) | Blind viewers get no `itemCount`, no `purchasedCount`, no purchases array, no off-list items, and no purchase-derived status. Every item appears as available. | B |
| P4 | The server returns explicit flags per list: `isRecipient`, `canSeeGiftActivity`, `canPurchase`, and `canAddOffList`. Clients never derive privacy from roles. Flag names are provisional. | B, W, I |
| P5 (updated rev 13) | Off-list items are created when a member adds an item (P21); the item type is derived from the caller's role, not a request flag. All non-blind viewers can see them. Only the creator can edit or delete. | B |
| P6 | List counts are item-level. `itemCount` is the number of items the viewer can see (including off-list). `purchasedCount` counts those with status purchased, wrapped, or gifted. Everyone who can see counts sees the same numbers. `purchasedCount` is currently hardcoded to 0 and must be implemented. | B |
| P7 (rev 2) | `createPurchase` rejects only blind viewers. Today it rejects every owner and co-owner with `CANNOT_PURCHASE_OWN_LIST`. | B |
| P8 | A recipient never holds a member role on their own list (see L13). The seed data is corrected. | B |
| P9 | An authenticated recipient who is not an owner (for example a child who later gets a login) is blind. Graduating a child to a login is deferred. | B |
| P10 | One helper, `getViewerPrivacy(list, user)`, decides P1 to P3. Every surface calls it: list summary, list detail, item list, item detail, purchases, and counts. Today four files key on owner and co-owner identity instead. | B |
| P11 | In item detail and `GET /purchases`, each user sees only their own purchases in full. Non-blind viewers also see the aggregate `totalQuantityPurchased`. Nobody sees another user's purchaser identity or amount. | B |
| P12 | Blind viewers can edit and delete items. Errors never reveal that purchases exist, and purchase records are kept. | B |
| P13 | Revealing status after a date (for example Dec 25) is a later, backend-only enhancement. | B |
| P14 (rev 2) | VIEWER-role members and PUBLIC non-members receive **neither** `itemCount` **nor** `purchasedCount` on `ListSummary` and `ListDetail` — both fields require `canSeeGiftActivity = true`. Clients that need a count must call `GET /lists/{id}/items` and count the results. Non-members of a non-PUBLIC list receive `LIST_NOT_FOUND` (404). | B, W, I |
| P17 (new) | `updatedAt` is omitted from item responses when `canSeeGiftActivity=false` (blind viewers). The `ItemResponse.updatedAt` field is optional (`updatedAt?: string`). Also applies to `createItem` and `updateItem` response paths. | B |
| P18 (new) | A non-member of a PUBLIC list gets 403 on every write route: `PATCH /lists/{id}`, `DELETE /lists/{id}`, `POST /lists/{id}/members`, `DELETE /lists/{id}/members/{userId}`, `POST /lists/{id}/items`, `PATCH /items/{id}`, `PATCH /items/{id}/status`, `DELETE /items/{id}`, `POST /items/{id}/purchases`. Read routes (`GET /lists/{id}`, `GET /items/{id}`, `GET /lists/{id}/items`) still return 200. For non-PUBLIC non-member routes the existing P14/P16 rules (404) are unchanged. | B |
| P14b (new) | The `role` field on `PrivacyList.memberships[]` is required in the TypeScript interface (`role: string`, not `role?: string`). Any service that constructs a `PrivacyList` without including `role` fails to compile. At runtime, a row with a missing or unknown role string does not match `'member'` or `'viewer'` and is treated as neither — fail-closed. The structural test in `__tests__/unit/privacy.unit.test.ts` enforces that no service file (except `list.service.ts`) compares membership role strings directly; `list.service.ts` is exempted because it makes three legitimate L9 access-control comparisons: `m.role.toLowerCase() === 'member'` (getMembers scope), `m.role.toLowerCase() === 'viewer'` (getMembers scope), and `callerMembership?.role?.toLowerCase() === 'viewer'` (remove-self guard). | B |
| P19 (new) | `GET /users/{id}` is tiered by relationship: self gets the full profile; caller's own child gets id/firstName/lastName/displayName; a user who shares any active list (as owner, co-owner, member, or recipient) gets PersonSummary (id, firstName, displayName); anyone else gets the identical 404 as a nonexistent id. Adding fields to PersonSummary later is non-breaking. | B |
| P20 (updated rev 13) | `canCreateItem` is returned in `ListSummary` and `ListDetail`. It is `true` for owners, co-owners, and members (including blind owners on their own lists), `false` for viewers and non-members. Clients use it to show the add-item button; the resulting item type depends on the caller's role (P21). | B, W, I |
| P21 (new) | Item type is derived from who adds it: owners and co-owners create normal items; members create off-list items. `POST /lists/:id/items` carries no `offList` flag; the server derives the type from the caller's role and ignores an `offList` field if sent. | B |
| P22 | `ListSummary` and `ListDetail` carry the required boolean `canSeeMembers`: `true` for the owner, the co-owner and MEMBER-role members (the callers who may call `GET /lists/{id}/members`), `false` for VIEWER-role members and PUBLIC non-members. `ListDetail.members` is returned only when `canSeeMembers` is `true` and is absent otherwise; `memberCount` is returned to everyone (C14). | B, W, I |
| P23 | `ListSummary` and `ListDetail` carry five required booleans that say what the server accepts for the caller on this list now: `canEditList` (`PATCH /lists/{id}`), `canDeleteList` (`DELETE /lists/{id}`, L14) and `canManageMembers` (adding members and removing other members, L8), each `true` for the owner and the co-owner (blind or not) while the list is not ARCHIVED; `canSetCoOwner` (`coOwnerEmail`, L12), `true` for the owner only while the list is not ARCHIVED; and `canLeaveList` (removing yourself, L9), `true` for an ACTIVE MEMBER-role or VIEWER-role member on a list of any status and `false` for the owner, the co-owner and every non-member. On an ARCHIVED list `canEditList` and `canSetCoOwner` are `false` because the server refuses with 422 `CANNOT_EDIT_ARCHIVED_LIST`; `canDeleteList` and `canManageMembers` are also `false` so that clients treat archived lists as read-only, although the server still accepts those calls. The server enforces every action regardless of the flags. | B, W, I |
| P24 | `Item` carries the integers `quantityPurchased` (the sum of `quantity` over all purchases of the item) and `quantityRemaining` (`max(0, quantityRequested - quantityPurchased)`) on every response that returns an `Item` or an `ItemDetail`. They are present only when the caller has `canSeeGiftActivity` and are omitted otherwise (P3). The server does not reject a purchase that exceeds the remaining quantity or a purchase on a PURCHASED item; clients use the counts to cap or warn. | B, W, I |

## 6. Purchases, shipping, and budgets

| ID | Decision | Applies to |
|----|----------|------------|
| S1 | `ShippingStatus` becomes `NOT_TRACKED` (default), `NOT_SHIPPED`, `SHIPPED`, `DELIVERED`. | B, W, I |
| S2 | Migration runs in two steps, because Postgres cannot use a new enum value in the transaction that adds it. Step one only adds the `NOT_TRACKED` value. Step two sets the column default to `NOT_TRACKED` and converts existing `NOT_SHIPPED` rows to `NOT_TRACKED`. Postgres rejects `SET DEFAULT` with a new enum value in the same transaction that adds it, so the default cannot move into step one. Both steps are idempotent. Test against a copy of the seeded database first. | B |
| S3 | Any transition among shipping states is allowed, including back to `NOT_TRACKED`, because tracking is manual. Timestamps follow three rules: moving out of `DELIVERED` clears `deliveredAt`; moving to `NOT_SHIPPED` or `NOT_TRACKED` clears both `shippedAt` and `deliveredAt`; a timestamp is never invented, so a jump straight to `DELIVERED` sets `deliveredAt` only if the purchase has none and leaves `shippedAt` as it was. | B |
| S4 | The UI shows no badge (or a subtle one) for `NOT_TRACKED`. iOS decodes unknown enum values to a default case. | W, I |
| S5 | `POST /items/:itemId/purchases` params validation is fixed to `z.object({ itemId: z.string().uuid() })`. This is the canonical purchase URL. | B |
| S6 (rev 2) | The budget confirmation token flow stays. Amounts compare as integer cents. The response is an explicit union (`created` or `confirmation_required`). Overage warnings check both the per-recipient limit and the total budget, per PRD section 6. Today `Budget.totalBudget` is never checked. Each warning has a top-level `level` (`"recipient"` or `"total"`). A total warning's `details` carry `year` instead of `recipientId` and `recipientName`. An expired, tampered, or mismatched confirmation token is ignored and answered with a fresh `confirmation_required` response and a warn log (no 4xx). | B, W, I |
| S7 | Budget year is the list's year, not `purchased_at`. The code already does this, so only the PRD changes. | B |
| S8 | `GET /items/:itemId/purchases` (a stub that returns an empty array) is deleted. Clients use `GET /purchases?itemId=`. | B, I |
| S9 (rev 6) | Off-list purchases count toward the buyer's budget. | B |
| S10 | Budgets are personal. A user can read and write only their own budgets. Members and owners never read another user's budget, and a user's budget counts only their own purchases (T3, S9). | B |
| S11 | Money amounts in requests carry at most two decimal places; otherwise 400 INVALID_PRICE. Applies to `totalCost`, `expectedUnitPrice`, `totalBudget`, and `maxSpend`. The internal `toCents` rounding is unchanged. | B, W, I |
| S12 | The budget confirmation token (S6) is also bound to the buyer's recorded spend for the list's year at the time of the warning, both the amount spent on that recipient and the total, so a valid token only confirms the exact purchase against the exact spend it was shown for. Once another purchase changes either figure, the old token is ignored and the client receives a fresh `confirmation_required` response with a new token. | B, W, I |
| S13 | A purchase never changes the status of an item that is `WRAPPED` or `GIFTED`. The purchase and the `quantityPurchased` and `quantityRemaining` counts (P24) are still recorded; only items that are `AVAILABLE`, `PARTIAL` or `PURCHASED` have their status recomputed from the purchases. | B, W, I |
| S14 | A purchaser can delete their own purchase with `DELETE /purchases/{id}`. Anyone else gets 404 `PURCHASE_NOT_FOUND`, identical to a nonexistent id (P11). The core fields stay immutable (PRD 5.2): to correct a purchase, delete it and record a new one. Deleting removes the purchase and its shipping data, recomputes the item status from the remaining purchases (an item that is `WRAPPED` or `GIFTED` keeps its status, S13), and lowers the buyer's recorded spend, so `quantityPurchased`, `quantityRemaining` (P24) and the budget checks (S6, S12) follow. It works whether or not the purchaser can still see the item (for example after leaving the list or after the recipient removed the item). An audit event `PURCHASE_DELETED` records the ids, the quantity and the amount in cents. The response is the deleted purchase, as `GET /purchases/{id}` returns it; clients refetch the item as they do after creating a purchase. | B, W, I |
| S15 | On `PATCH /purchases/{id}` and `PATCH /purchases/{id}/shipping`, an empty string for `notes` (the first operation only) or `trackingNumber` clears the field: it is stored and returned as `null`. An omitted field is left unchanged, and `null` is not accepted (400). | B, W, I |

## 7. Statistics and purchase history

| ID | Decision | Applies to |
|----|----------|------------|
| T1 | `GET /stats?year=YYYY` returns totals (spent, items purchased), spend by recipient, and budget versus actual (total and per recipient). | B |
| T2 | `GET /stats?year=all` (the default) returns lifetime totals plus a `byYear` array of headline fields. Both forms include `availableYears`. | B |
| T3 | Stats cover the requesting user's own purchases only, across all lists. | B |
| T4 | `GET /purchases` filters: `year`, `recipientId`, `listId`, `shippingStatus`, `itemId`. Cursor pagination, newest first. | B |
| T5 | Each row includes the purchase id, item (id, name, image), list (id, name), recipient (id, displayName), quantity, totalCost, purchasedAt, and shippingStatus. The response header carries `filteredTotal` and `filteredCount`. | B |
| T6 | Tapping a pie slice or bar opens purchase history with the matching filters. A "View all purchases" link covers the rest. On web the filters live in the URL. | W, I |
| T7 | Stats and history share one backend filter implementation. A test checks that for every filter combination the sum from `/purchases` equals the matching number from `/stats`. | B |
| T8 | There are no month filters, no monthly timeline, and no line chart. The iOS Phase 7 line chart is removed. | B, W, I |
| T9 | Money is aggregated in SQL or in integer cents, never with JavaScript floating point. `BudgetService`'s `Number()` sums move to cents in work package 6. | B |
| T10 (updated) | `itemsPurchased` and `purchaseCount` are distinct fields. `itemsPurchased` is the sum of `quantity` across all matching purchases. `purchaseCount` is the number of purchase records. A single transaction for qty=3 contributes 3 to `itemsPurchased` but 1 to `purchaseCount`. `spendByRecipient[]` entries carry `{ recipientId, displayName, spent, itemsPurchased }`. | B |
| T11 (new) | `budget` block shape in stats responses (when present): `{ totalBudget, totalSpent, remaining, recipients[] }` where each recipient entry is `{ recipientId, displayName, budget, spent, remaining }`. All money fields are floating-point dollars computed via integer-cents arithmetic (toCents/fromCents). | B |

## 8. Deployment and operations

| ID | Decision | Applies to |
|----|----------|------------|
| D1 | No production instance exists yet. A deployment work package covers the API and Postgres behind the tunnel, secrets and environment config, the registration code, backups, web hosting, and hosting for the IPA and manifest. Build 1 needs the stable production URL. | B, W, I |
| D2 | Distribution is ad hoc sideloading. Device UDIDs are registered, and the profile is renewed before the first release. App Store and TestFlight items (privacy manifest, entitlements for Phases 9 and 10) are out of scope. | I |
| D3 | Family accounts are created fresh through registration. Prior-year lists and purchases are backfilled after release, once all users exist. This is not release-critical. | B |
| D4 | Sentry covers iOS, web, and the API. iOS uploads dSYMs from the build step. Events carry the app version and build. A shared request id links one failure across layers. Auth headers, tokens, passwords, and request bodies are scrubbed. New Relic is removed from iOS. `/logs/batch` is deferred. | B, W, I |
| D5 | Proposed staging: build 1 around Nov 15 (sessions, lists including managed lists, direct-add sharing on web, items, purchases, counts, `VersionManager`). Build 2 in early December (stats, budgets, history, iOS sharing sheet). | All |
| D6 | The refresh cookie is `SameSite=Strict`, so web and API must share a registrable domain (for example `app.example.com` and `api.example.com`). Never run the seed script in production. | B, W |
| D7 | Behind the Cloudflare Tunnel the client IP comes from the `CF-Connecting-IP` header (`CLIENT_IP_SOURCE=cf-connecting-ip`), trusted only when the connecting address is inside `TRUSTED_PROXY_CIDRS`; Express `trust proxy` is not used. The auth rate limiter keys on the client IP plus the normalized email, so several people registering from one IP are not affected; the general limiter keys on the verified user id, otherwise on the client IP. | B |
| D8 | v2 runs as a Docker Compose stack (the API and PostgreSQL 18) on the production host. The Cloudflare Tunnel connector reaches the API over a shared Docker network for the path `^/tracker/v2` of `api.bmalberta.com`, ahead of the existing v1 rule; the API publishes no host port and Traefik is not in the API path. Migrations run as an explicit deploy step, never at container start. Backups are nightly `pg_dump` files encrypted with `age` and stored in R2. | B |
| D9 | On the production host Docker is the snap package, and under its AppArmor confinement every exec fails with `operation not permitted` when `no-new-privileges` is set (`init: true` hits the same failure because it execs the injected `docker-init`). The api container therefore runs without `no-new-privileges` and without `init`. The compensating controls are all capabilities dropped (`cap_drop: ALL`), a read-only root filesystem, the non-root `node` user, no published port and a private network. Revisit if Docker is replaced by Docker Engine from the apt repository. | B |

## 9. Deferred

- Backend biometric endpoint, session ping, forgot-password
- Accept and decline (target state, see L10) and role changes
- Managed recipients other than children
- Graduating a child to a login
- Monthly views and spending by list
- Email and push notifications, share extension
- Zod-first spec generation
- Backfill of prior-year lists and purchases (D3), after release
- Reveal-after-date for blind viewers (P13)

## 10. Open items

- A child created by one parent is linked only to that parent, and no route links a second guardian. The co-owner field covers access, so this is not blocking.
- `/auth/me` and `/users/me` return the same data. Keep both for now and consolidate later.

## 11. PRD amendments needed

- 3.2 (list counts): key the table on the recipient rule (P1 to P3) instead of the owner role, and state that blind viewers see no purchase status.
- 4.1 (off-list items): guardians of a non-login recipient also see off-list items, and blind viewers are defined by P1.
- Budget year: change "year extracted from `purchased_at`" to the list year (S7).
- Section 6: confirm that overage warnings apply at both levels (S6).
- Add the version enforcement design in section 3 (ad hoc fields replace the App Store link).

## 12. Work packages, in order

1. **Baseline:** fix test compilation, dump real routes at runtime, add the parity test, remove duplicate mounts, add CI (C4, C5, C8).
2. **Auth:** A1 to A6 and A12.
3. **Purchases, shipping, budgets:** S1 to S8.
4. **Privacy:** P1 to P12, counts, seed data (three scenarios: a self-list, a child list with two guardians and a member, and an off-list item).
5. **Members and co-owner:** L8, L9, L12, L13.
6. **History and stats:** T1 to T7.
7. **Version enforcement:** V1 to V7.
8. **Deploy production:** D1 to D4, in parallel after package 2.
9. **Contract:** spec snapshot, client regeneration, retire old specs (C1 to C3).
10. **iOS in parallel:** Debug-Network scheme (C6), the P0 fixes from the iOS audit, `VersionManager` (V8), Sentry.

## 13. Acceptance tests

1. A self-list owner sees no counts, no purchases array, no off-list items, and every item as available.
2. On a child's list, the owner and co-owner see counts and off-list items and can record purchases.
3. Members see counts and off-list items on every list.
4. A logged-in recipient is blind on their own list.
5. A blind viewer editing or deleting an item never receives an error that reveals purchases.
6. Changing a list's recipient is rejected.
7. A second list for the same recipient and year returns the 409.
8. Login then refresh succeeds with the cookie, the body, or both. A rotated token works within the grace window and fails after it.
9. A refresh after the 90-day cap fails.
10. Registration without the shared code fails.
11. `/purchases` totals reconcile with `/stats` for each filter combination.
12. Another user's purchases never appear in `/stats`, `/purchases`, or item detail.
13. The total-budget overage warning fires even with no per-recipient budget set.
14. The membership route rejects the recipient, owner, and co-owner.
15. A co-owner who is the owner, the recipient, or a child is rejected.
16. The shipping migration converts existing `NOT_SHIPPED` rows to `NOT_TRACKED`.
17. A build below the minimum gets `426` from login and refresh. `version-check` returns `304` on a matching `ETag`.
18. iOS falls back to the password screen when the Keychain item is invalidated.
19. The route parity test and the spec snapshot check pass in CI.
20. A login with `rememberMe: false` gets a session cookie (no `Max-Age`); `true` or omitted gets a persistent cookie. The choice survives refresh rotation.
21. Shipping timestamps follow S3 on every backward move and on a jump forward to `DELIVERED`.
22. The test database guard refuses to run when `TEST_DATABASE_URL` is unset or the database name does not end in `_test`.
