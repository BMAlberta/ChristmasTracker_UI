------

# 🎄 Christmas Tracker

**Project Requirements Document v2.1**

**Last Updated:** 2026-11-01

------

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Initial | Original requirements |
| 2.0 | 2025-12-29 | Updated with final design decisions |
| 2.1 | 2026-11-01 | Applied decision log amendments (see Docs/prd-v2.1-changes.md) |

**Key Changes in v2.0:**
- Merged User/Person model (all users in single table)
- Added parent-child relationships
- Eliminated shared budgets (one budget per user per year)
- Added shipping status tracking
- Clarified list visibility rules for item/purchase counts
- Defined purchase conflict resolution strategy
- Defined budget overage behavior
- Specified technology stack and infrastructure

**Key Changes in v2.1:**
- API docs now built from route annotations (not tsoa); snapshot/parity-test protected (C1)
- Monitoring migrated from NewRelic to Sentry across iOS, web, and API (D4)
- iOS distribution: ad hoc sideload for family and friends (D2)
- No admin API in v1; admin tasks performed via scripts (A10, V7)
- Co-owner permissions: identical to owner except setting or changing the co-owner (L14)
- PUBLIC non-members treated as Viewers with read-only access (P14, P18)
- INVITE_ONLY and FRIENDS_ONLY both act as PRIVATE (non-members receive the identical 404 on every route); FRIENDS_ONLY is reserved for a future friends-graph feature (P16)
- List counts table re-keyed on blind/non-blind recipient rule; guardians of child lists see counts (P1–P3, P6)
- Membership: direct add by email, ACTIVE immediately; accept/decline/expiry deferred (L8–L10)
- Off-list items visible to non-blind owners and co-owners as well as members (P5)
- Item type derived from caller's role: owner/co-owner → normal item, member → off-list item; no `offList` flag in create request (P21) — implemented on branch `fix/item-type-by-role`
- Blind viewers see all items as AVAILABLE; blind delete always succeeds and keeps purchase records (P3, P12)
- Shipping status: NOT_TRACKED added as default; any transition allowed (S1–S3)
- Purchase response is an explicit status union; confirmation token binds integer cents; bad/expired token ignored (S6)
- Budget year is the list's year, not purchase date (S7); budgets are personal (S10)
- Stats (GET /stats) and purchase-history (GET /purchases) endpoints added (T1–T11)
- include=items dropped as a recommended pattern
- Auth: sliding 7-day refresh with 90-day cap, rememberMe, iOS token delivery, registration code (A1–A5, A12, A14)
- 4xx responses logged at warn level; version-check rate limit; trust proxy required in production behind the tunnel (D7)
- New section: Version enforcement, section 14 (V1–V10); iOS VersionManager behavior added (V8)

------

## 1. Project Overview

### 1.1 Purpose

Christmas Tracker is a web and iOS application that allows users to:

- Create Christmas gift lists
- View and purchase items from others' lists
- Avoid duplicate purchases
- Track gift status through the purchase lifecycle including shipping
- Manage annual and per-recipient budgets
- Coordinate surprise gifts while preserving privacy

The system supports both **list managers** and **purchasers**, often within the same user account.

------

### 1.2 Platforms & Technology Stack

#### Frontend
- **Web:** React (with TypeScript)
- **Mobile:** SwiftUI (iOS)

#### Backend
- **Framework:** Express.js (TypeScript)
- **ORM:** Prisma
- **Validation:** Zod
- **Authentication:** JWT (access + refresh tokens)
- **API Documentation:** OpenAPI 3.1, built from route annotations; a parity test and committed snapshot guard the spec until a Zod-first migration (C1)

#### Database
- **Engine:** PostgreSQL 18
- **Key Features Used:**
  - Custom ENUM types
  - Materialized views
  - Full-text search (GIN indexes)
  - Covering indexes
  - Row-Level Security (RLS) — available but not yet implemented; privacy is currently enforced in the service layer (future hardening)

#### Infrastructure
- **Production API:** `https://api.bmalberta.com/tracker/v2`
- **Monitoring:** Sentry (iOS, web, and API) (D4)
- **Logging:** Winston (daily rotation)
- **Rate Limiting:** Express Rate Limit
- **Caching:** Redis (future, for sessions)
- **Distribution (iOS):** Ad hoc sideload for family and friends (D2)

Amended in v2.1: C1, D2, D4

------

### 1.3 Goals

- Enable list creation and management year-round
- Prevent duplicate purchases through optimistic concurrency
- Support partial and multi-user purchases
- Track gift lifecycle and history including shipping status
- Support individual budgets with per-recipient allocations
- Support multi-year budget tracking and reuse
- Provide strong privacy guarantees for surprise gifts

------

### 1.4 Non-Goals (v1)

- Payment processing
- Public or social wishlists
- Exporting data (CSV/PDF)
- Email notifications (in-app only)
- Push notifications (APNS support planned for v2)

------

## 2. Users, Roles & Permissions

### 2.1 User Model (Updated)

**All people in the system are "users"** - the distinction is whether they can authenticate.

#### Authenticated User
- Has email and password
- Can:
  - Log in to web/mobile app
  - Own lists
  - Be a list member
  - Create budgets and make purchases
  - Create lists for themselves or their children

#### Non-Authenticated User (e.g., Child)
- No email or password (NULL in database)
- Can:
  - Have lists created for them
  - Receive gifts
  - Participate in budgets
- Cannot:
  - Log in
  - Authenticate
  - Manage their own lists

#### Administrator
- No admin API in v1
- Administrative tasks (such as user resets and policy changes) are performed via scripts (A10, V7)
- Database-level access is managed by the PostgreSQL role, not an API endpoint

Amended in v2.1: A10, V7

### 2.2 Parent-Child Relationships

Users can have parent-child relationships:
- **Parents** can create and manage lists for their **children**
- Relationship types: `PARENT`, `GUARDIAN`, `CARETAKER`
- Authorization: Only parents can create lists for their children
- A child can have multiple parents
- A parent can have multiple children

### 2.3 List Roles

| Role | Description |
| -------- | ------------------------------------------------------ |
| Owner | Primary list owner with full control |
| Co-Owner | Optional second owner with identical permissions except setting or changing the co-owner |
| Member | Can view and purchase items; can create off-list items |
| Viewer | Read-only access |

**Constraints:**
- Exactly **1 Owner**
- At most **1 Co-Owner**
- Unlimited Members
- One list per user per year (enforced at database level)

**Important:** Owners and co-owners are **not** stored in the memberships table.

**Public list access:** Non-members of a PUBLIC list are treated as Viewers and receive read-only access. They receive 403 on all write routes (P14, P18).

Amended in v2.1: L14, P14, P18

------

## 3. Lists

### 3.1 List Visibility

Lists support four visibility modes:

- `PRIVATE` (default) — Only owner, co-owner, and direct-added members; non-members receive 404 (P14)
- `INVITE_ONLY` — Behaves as PRIVATE; non-members receive the same 404 as a PRIVATE list on every route (P16); reserved for the future invitation flow (L10)
- `FRIENDS_ONLY` — Behaves as PRIVATE until a friends feature is built; non-members receive the same 404 as a PRIVATE list on every route (P16)
- `PUBLIC` — All registered users can view; non-members are treated as Viewers (P14, P18)

Visibility can be changed at any time by the owner/co-owner.

**Visibility rules:**
- Visibility controls access only
- Existing purchases are never invalidated
- Switching `PUBLIC → PRIVATE` hides items and purchases from non-members
- Switching back restores full purchase state

Amended in v2.1: P16

### 3.2 List Counts Visibility

**To protect surprise gifts, list counts follow the recipient rule (P1 to P3):**

| Viewer Category | itemCount | purchasedCount |
|-----------|-----------|----------------|
| Blind viewer (self-list owner/co-owner; recipient of their own list) | ❌ Hidden | ❌ Hidden |
| Non-blind owner/co-owner (guardian of a child's list) | ✅ Shown | ✅ Shown |
| Member | ✅ Shown | ✅ Shown |
| Viewer (PUBLIC non-member or viewer-role member) | ❌ Hidden | ❌ Hidden |

**Viewers and PUBLIC non-members** receive `canSeeGiftActivity: false` (P14): **neither** `itemCount` **nor** `purchasedCount` is included in the response. Clients that need an item count must call `GET /lists/{id}/items` and count the results themselves.

**Blind definition (P1):** A viewer is blind if they are the recipient of the list, or if they are the owner/co-owner of a list whose recipient can log in (a self-list).

**Guardians of a child's list** (where the recipient has no login credentials) are not blind and see both counts (P2).

**Rationale:** Blind viewers must not be able to infer the existence of surprise off-list gifts. Viewers are treated identically to blind viewers for count purposes.

**Implementation:** `getViewerPrivacy(list, user)` determines blindness. Both `itemCount` and `purchasedCount` are gated on `canSeeGiftActivity` in `buildListSummary`; the API omits both fields for any caller with `canSeeGiftActivity = false`.

Amended in v2.1: P1, P2, P3, P6, P14

### 3.3 Membership Lifecycle

Membership is by direct add. `POST /lists/:id/members` accepts `{ email, role }` where `role` is `member` or `viewer`. The resolved user's membership becomes `ACTIVE` immediately (L8).

**Membership States:**
- `ACTIVE` — Member can view and participate per their role
- `REMOVED` — Access revoked (record preserved for history)

**Removal:**
- Owners and co-owners can remove any member at any time
- Any active member (role `member` or `viewer`) may remove themselves (L9)
- Removed members lose access immediately
- Their past purchases remain valid and budgeted
- Re-adding a removed member reuses the existing record (returns to ACTIVE)

**Deferred (L10):** Accept, decline, invitation expiry, and role changes are not in v1. The target state is `INVITED` memberships with `GET /invitations`, `POST /invitations/:id/accept`, and `POST /invitations/:id/decline`.

Amended in v2.1: L8, L9, L10

### 3.4 Invitation Delivery (v1)

Acceptance and decline flows are deferred to a future version (L10). In v1, membership is granted directly by the owner or co-owner via email without an invitation step.

**Future (v2):**
- `INVITED` memberships with accept and decline routes
- Invitation responses will not reveal whether an account exists
- Email notifications
- Push notifications (APNS for iOS)

Amended in v2.1: L8, L10

### 3.5 API Behavior Rules

The following rules apply uniformly across all list and item endpoints. Clients must rely on the server-returned capability flags and must not derive privacy or permissions from role names.

**Capability flags (P4, P20):** Every `ListSummary` and `ListDetail` response includes: `isRecipient`, `canSeeGiftActivity`, `canPurchase`, `canAddOffList`, `canSeeOffList`, `canCreateItem`. Clients never derive privacy from roles — they read the flags.

**Recipient immutable (L4):** The list recipient cannot be changed after creation. The API rejects any update that attempts to change `recipientId`.

**One list per recipient per year (L5):** A duplicate `(recipientId, year)` pair returns `409 LIST_ALREADY_EXISTS`. The UI should link to the existing list.

**Authorised recipients (L3):** `recipientId` must be the caller themselves or one of their own children. Any other value — including a nonexistent id, another adult, or a credential-less child belonging to another user — returns an identical `404 RECIPIENT_NOT_FOUND`.

**Co-owner (L12):** The co-owner is set by `coOwnerEmail` on `POST /lists` and `PATCH /lists/:id`. Only the owner may set it. The target must be a user who can log in and must not be the owner or the recipient. Setting `coOwnerEmail` when a co-owner already exists replaces them; if the incoming user is currently a member, that membership is removed in the same transaction. `null` clears the co-owner.

**User lookup (P19):** `GET /users/{id}` is tiered by relationship: self receives the full profile; caller's own child receives `id/firstName/lastName/displayName`; a user who shares any active list returns `PersonSummary (id, firstName, displayName)`; anyone else returns the identical `404` as a nonexistent id.

Amended in v2.1: L3, L4, L5, L12, P4, P19, P20

------

## 4. Items

### 4.1 Item Types

**Item type derivation (P21):** The type of an item follows from who adds it. Items added by an owner or co-owner are **normal items**; items added by a member are **off-list items** (surprise gifts). The `POST /lists/:id/items` request carries no `offList` flag; the server derives the type from the caller's role. An `offList` field sent in the request body is ignored.

#### Normal List Items
- Created by Owner or Co-Owner
- Visible to:
  - Owners
  - Co-owners
  - Members
  - Viewers (if list is PUBLIC)

#### Off-List Items ("Surprise Gifts")
- Created **only by Members** (type derived from caller's role per P21)
- Visible to **Members** and **non-blind Owners and Co-Owners** (P5)
- Hidden from **blind viewers** (self-list owners/co-owners and recipients) and **Viewers** (P14)
- Used to prevent duplicate surprise gifts
- Only the creator can edit/delete their off-list item

**Implementation:** `canSeeOffList` flag from `getViewerPrivacy()` controls visibility at the query layer.

Amended in v2.1: P5, P14, P20, P21

### 4.2 Item Attributes

Each item has:

| Attribute | Required | Notes |
|-----------|----------|-------|
| Name | Yes | Max 200 chars |
| Description | Yes | Max 2000 chars |
| Expected unit price | No | NUMERIC(10,2) for precision |
| URL | No | Product link |
| Quantity requested | Yes | Default: 1, advisory only |
| Priority | Yes | 1-10 (1 = highest), default: 5 |
| Image URL | No | Link to product image |
| Off-list flag | Yes | Default: false |

### 4.3 Item Status (Persisted)

Item status is authoritative and stored at the item level.

| Status | Meaning |
| --------- | ------------------------------ |
| AVAILABLE | No purchases exist |
| PARTIAL | Some quantity purchased (< requested) |
| PURCHASED | Purchased quantity ≥ requested |
| WRAPPED | Optional manual state (owner/co-owner only) |
| GIFTED | Final state (owner/co-owner only) |

**UI-only status:**
- `UNAVAILABLE` is shown to non-purchasing members when an item is `PURCHASED`
- It is not persisted in database

**Blind viewer presentation (P3):** Blind viewers see every item as `AVAILABLE` regardless of its actual status. No purchase-derived status is surfaced to blind viewers.

**Viewer and PUBLIC non-member presentation (P14):** Viewers (viewer-role members and PUBLIC non-members) also see every item as `AVAILABLE` and cannot set item status.

Amended in v2.1: P3, P12, P14

### 4.4 Item Status Rules

**Automatic transitions (via purchase):**
- `AVAILABLE → PARTIAL` - First purchase with qty < requested
- `PARTIAL → PURCHASED` - Total purchased ≥ requested
- Status automatically updates when new purchases are created

**Manual transitions (owner/co-owner only):**
- `PURCHASED → WRAPPED` - Item has been wrapped
- `WRAPPED → GIFTED` - Item has been given

**Immutable fields:**
- Cannot change status backward (e.g., GIFTED → WRAPPED)

**Blind viewers cannot set item status** — they see all items as AVAILABLE and have no purchase-derived transitions (P3). Viewers and PUBLIC non-members (P14) are subject to the same restriction.

All status changes are recorded in `item_status_history`.

Amended in v2.1: P3, P14

### 4.5 Soft Deletion

Items use soft deletion:
- `deleted_at` timestamp set instead of hard delete
- Preserves purchase history
- Filtered from queries via `WHERE deleted_at IS NULL`
- Cannot delete items with existing purchases (business rule)

**Exception (P12):** Blind viewers may always soft-delete items, even when purchases exist. Purchase records are preserved. The blind viewer never receives an error that reveals purchases. Non-blind users retain the restriction.

Amended in v2.1: P12

------

## 5. Purchases

### 5.1 Purchase Model

- One item can have **multiple purchases**
- Purchases:
  - Can overlap in time (optimistic concurrency)
  - Can exceed requested quantity
  - Can be at different prices
  - Have immutable core fields; the purchaser can delete a purchase (S14)

### 5.2 Purchase Attributes

Each purchase records:

| Attribute | Required | Notes |
|-----------|----------|-------|
| Purchaser | Yes | User who made purchase |
| Item | Yes | Item that was purchased |
| Recipient | Yes | Who will receive the gift |
| Quantity | Yes | Number purchased |
| Total cost | Yes | NUMERIC(10,2), actual amount paid |
| Store name | No | Where purchased |
| Purchase date | Yes | When purchased (default: now) |
| Notes | No | Optional notes |
| Confirmation number | No | Order confirmation |
| Tracking number | No | Shipping tracking |
| **Shipping status** | Yes | NOT_TRACKED (default) / NOT_SHIPPED / SHIPPED / DELIVERED |
| **Shipped at** | No | Auto-set when status → SHIPPED |
| **Delivered at** | No | Auto-set when status → DELIVERED |

**Immutability:**
- Core fields (quantity, total_cost, item_id, recipient_id) are **immutable**
- The purchaser can delete their own purchase (S14); to correct a core field, delete the purchase and record a new one
- Metadata fields (notes, tracking, shipping status) can be updated

Amended in v2.1: S1, S2, S3, S11, S14

### 5.3 Shipping Status Tracking

Purchases track shipping status through four states (S1 to S3):

1. **NOT_TRACKED** (default)
   - Tracking not applicable or not yet configured
   - `shippedAt` and `deliveredAt` are NULL

2. **NOT_SHIPPED**
   - Purchase recorded and tracking intended, but item not yet shipped
   - `shippedAt` is NULL

3. **SHIPPED**
   - Item has been shipped
   - `shippedAt` set on transition (unless already set)
   - Tracking number typically added

4. **DELIVERED**
   - Item has been delivered
   - `deliveredAt` set on transition (unless already set)

**Transitions:**
- Any transition is allowed, including backward moves, because tracking is manual (S3)
- Timestamp rules: moving to `NOT_TRACKED` or `NOT_SHIPPED` clears both `shippedAt` and `deliveredAt`; moving out of `DELIVERED` clears `deliveredAt`; a jump straight to `DELIVERED` sets `deliveredAt` only if none exists and leaves `shippedAt` as it was

**Endpoint:** `PATCH /purchases/:id/shipping`

Amended in v2.1: S1, S2, S3

### 5.4 Purchase Conflict Resolution

**Strategy: Optimistic Concurrency (No Locking)**

Multiple users can purchase the same item simultaneously:
- No "item locked" errors
- Better user experience
- Mirrors real-world behavior

**Example:**
- Item requests quantity = 1
- User A purchases quantity = 1
- User B purchases quantity = 1
- Result: Item status = PURCHASED, total quantity = 2

This is **acceptable** - it matches real-world scenarios where multiple people might buy the same gift.

**Alternative (rejected):** Pessimistic locking would create poor UX and unnecessary complexity.

**Purchase response (S6):** The `POST /items/:id/purchases` response is an explicit status union:
- `created` — purchase was recorded immediately; response includes the new purchase record
- `confirmation_required` — purchase would exceed budget; response includes a `warnings` array (one entry per exceeded level, `recipient` or `total`), and a single shared `confirmationToken` (5-minute expiry) binding the purchase amounts in integer cents

The confirmation token encodes the purchase amount in integer cents. A token that is expired, tampered, or does not match the pending amounts is silently ignored; the API answers with a fresh `confirmation_required` response and logs a warn. No 4xx is returned.

Amended in v2.1: S6

------

## 6. Budgets

### 6.1 Budget Model (Updated)

**Key Change:** Eliminated shared budgets for simplicity.

Budgets are:
- Owned by a **single user**
- Tied to a **single year**
- Required for purchase aggregation
- One budget per user per year (enforced at database level)

Each year requires a new budget.

### 6.2 Budget Structure

Each budget has:
- **Total budget** - Annual spending limit across all recipients
- **Recipient budgets** - Per-recipient spending limits

**Rules:**
- Sum of all recipient budgets **must not exceed** total budget
- Enforced at application layer during create/update
- Overages calculated at both total and per-recipient level

Amended in v2.1: S11

### 6.3 Budget Ownership

- **Single owner per budget** (no sharing)
- User sees:
  - Total budget
  - Total spent
  - Spending per recipient
  - Overage amounts

**Eliminated Complexity:**
- No shared budgets
- No isolated purchase ledgers
- Simplified privacy model

### 6.4 Budget Attribution

Purchases are automatically assigned to budgets via:
- Purchaser ID → User's budget for that year
- Recipient ID → Specific recipient budget
- **Budget year is the list's year**, not the purchase date (S7)

**Rules:**
- Off-list purchases **always** count toward budgets
- No manual budget selection
- Budget assignment is automatic and immutable
- Budgets are personal: a user reads and writes only their own budget (S10)

Amended in v2.1: S7, S10

### 6.5 Budget Overage Behavior

**Strategy: Soft Limit with Confirmation**

When a purchase would exceed budget (per-recipient or total):
1. API returns a `confirmation_required` response (not an error) with:
   - A `warnings` array — one entry per exceeded level (`recipient` or `total`), each with overage amount and current spent vs limit
   - A single shared `confirmationToken` (5-minute expiry) binding the purchase amounts as integer cents (S6)
2. User sees warning dialog in UI
3. User can confirm or cancel
4. If confirmed, user resubmits request with the confirmation token
5. Purchase succeeds even though it exceeds budget

**Token handling (S6):** An expired, tampered, or mismatched confirmation token is silently ignored; the API answers with a fresh `confirmation_required` response and logs a warn. No 4xx is returned.

**Example Flow:**
```
POST /items/:id/purchases { quantity: 1, totalCost: 100 }
→ 200 { status: "confirmation_required", warnings: [{ level: "total", ... }], confirmationToken: "..." }
→ User clicks "Confirm Purchase Anyway"
→ POST /items/:id/purchases { quantity: 1, totalCost: 100, confirmationToken: "..." }
→ 201 { status: "created", purchase: {...} }
```

**Rationale:** Provides awareness without blocking purchases (flexibility for special cases).

Amended in v2.1: S6

### 6.6 Historical Budgets

Users can:
- View prior-year budgets and purchases
- Duplicate a prior year's budget configuration to new year
- **Purchases are NOT copied** during duplication
- Only budget structure (total + recipient allocations) is copied

------

## 7. Reporting & Dashboards

### 7.1 Dashboard Views

The system provides multiple dashboard views:

**Overall Dashboard:**
- All owned and member lists
- High-level statistics
- Filters:
  - Status (ACTIVE, ARCHIVED)
  - Role (owner, member, all)
  - Year

**Owned Lists Dashboard:**
- Lists where user is owner or co-owner
- **Item counts and purchase counts:** hidden on self-lists (blind — prevents revealing surprises to the owner who is also the recipient) (P1, P3); shown on lists for a child whose recipient has no login credentials (P2, P3)

**Member Lists Dashboard:**
- Lists where user is an active member
- Shows item counts and purchase counts

**Budget Dashboard:**
- Annual budget view
- Total budget vs actual spent
- Per-recipient breakdown with overages
- Unshipped purchases view

**Stats Endpoint (T1, T2):**
- `GET /stats?year=YYYY` — totals (spent, items purchased), spend by recipient, and budget vs actual
- `GET /stats?year=all` (default) — lifetime totals plus a `byYear` array and `availableYears`
- Covers the requesting user's own purchases only (T3)
- No monthly breakdowns or month filters (T8)

**Purchase History Endpoint (T4, T5):**
- `GET /purchases` — cursor-paginated history, newest first
- Filters: `year`, `recipientId`, `listId`, `shippingStatus`, `itemId`
- Each row includes: purchase id, item (id, name, image), list (id, name), recipient (id, displayName), quantity, totalCost, purchasedAt, shippingStatus

Amended in v2.1: T1, T2, T3, T4, T5, T8

### 7.2 Reporting Rules

All reporting strictly respects:
- **Budget privacy** - Users only see their own budgets
- **List visibility** - Users only see lists they have access to
- **Off-list item secrecy** - Hidden from blind viewers and Viewers; owners and co-owners of a child's list are non-blind and do see off-list items (P5)
- **Count visibility** - Follows the recipient rule in section 3.2 (P1 to P3, P14); blind viewers, VIEWER-role members, and PUBLIC non-members do not see `itemCount` or `purchasedCount`

Amended in v2.1: P1, P2, P3, P5

### 7.3 Data Presentation Strategy

**Lists and Items:**
- **Separate API calls** (not embedded)
- Rationale:
  - Smaller payloads (faster load times)
  - Better client-side caching
  - Flexible (can paginate items if needed)
  - Mobile-friendly (less data transfer)
- Implementation: React Query with 5-minute cache

`GET /lists/:id?include=items` is not offered by default. It may be added if a specific client use case requires it.

Amended in v2.1: T8

### 7.4 Exports

- No CSV or PDF exports in v1
- Future consideration for tax records or gift records

------

## 8. Audit & History

The system persists:

### 8.1 Item Status History
- Every status change recorded
- Includes:
  - Previous status
  - New status
  - Changed by (user ID)
  - Reason (optional)
  - Timestamp

### 8.2 Membership Lifecycle Events
- Member added
- Member removed
- Re-add (record reused)

Membership lifecycle events (MEMBER_ADDED, MEMBER_REMOVED, MEMBER_LEFT, MEMBER_READDED, CO_OWNER_SET, CO_OWNER_CLEARED) are now recorded in the `audit_log` table inside the same transaction as the change. There is no read API in v1; administrators query via `npm run audit:show`. A dedicated `MembershipEvent` history table remains deferred.

Amended in v2.1: L8, L9, L10, R1
Amended in v2.1: R1 (revised — implemented): membership lifecycle events written to `audit_log`; no read API; admin query via `npm run audit:show`

### 8.3 Budget Configuration Changes
- Budget created
- Budget updated (total or recipient allocations)
- Budget duplicated from prior year

Budget events (BUDGET_CREATED, BUDGET_UPDATED, BUDGET_DELETED, BUDGET_DUPLICATED) are now recorded in the `audit_log` table. There is no dedicated `BudgetChangeHistory` table; the audit_log covers these events. There is no read API in v1; administrators query via `npm run audit:show`.

Amended in v2.1: R1
Amended in v2.1: R1 (revised — implemented): budget events written to `audit_log`; no dedicated BudgetChangeHistory table; admin query via `npm run audit:show`

### 8.4 Shipping Status Changes
- Status transitions (NOT_TRACKED / NOT_SHIPPED / SHIPPED / DELIVERED)
- Tracking number added/updated
- Timestamps auto-recorded (`shippedAt`, `deliveredAt` per S3)

SHIPPING_UPDATED events are now recorded in the `audit_log` table for each explicit status change. `shippedAt`/`deliveredAt` remain auto-managed per S3; there is no per-transition event table. There is no read API in v1; administrators query via `npm run audit:show`.

Amended in v2.1: R1
Amended in v2.1: R1 (revised — implemented): SHIPPING_UPDATED events written to `audit_log`; shippedAt/deliveredAt auto-managed per S3; no per-transition event table; admin query via `npm run audit:show`

**Admin Access:**
- Admins can audit all changes via database scripts
- Full visibility regardless of privacy rules
- Service-layer privacy rules are bypassed at the database level via direct script access

------

## 9. Non-Functional Requirements

### 9.1 Performance

- **API response time:** < 500ms for 95th percentile
- **Database queries:** Optimized with indexes and covering indexes
- **Caching:** Materialized views for expensive aggregations
- **Monitoring:** Sentry tracks all endpoints

Amended in v2.1: D4

### 9.2 Security

- **HTTPS only** in production
- **JWT-based authentication (A1 to A5, A12, A14):**
  - Access tokens: 15 minutes
  - Refresh tokens: sliding 7-day window; each rotation issues a new 7-day token
  - Absolute cap: 90 days from original login; after that, re-authentication is required
  - Previous token remains valid for a 30–60 second grace window after rotation; reuse after the grace window revokes the full chain
  - `rememberMe: false` on login issues a session cookie (no `Max-Age`); `true` or omitted issues a persistent cookie
  - iOS clients receive the refresh token in the response body (when `X-Client-Platform: ios`); web receives a cookie only
  - Registration requires a shared code held in an environment variable (A12)
- **iOS biometric unlock (A7–A9):** Local only, using Face ID or Touch ID (`.biometryCurrentSet`) to release a Keychain-stored refresh token. If the Keychain item is invalidated, the app shows the password screen without an error. No backend endpoint.
- **Service-layer privacy:** Privacy is enforced in the service layer via `getViewerPrivacy(list, user)`. Row-Level Security (RLS) is not yet implemented; it is a future hardening goal.
- **Strong data isolation:**
  - Off-list items filtered at query layer by `canSeeOffList` flag
  - Blind viewers cannot see off-list items or purchase-derived status
  - Budgets scoped to individual users
- **Password requirements:**
  - Minimum 8 characters
  - Hashed with bcrypt

Amended in v2.1: A1, A2, A3, A4, A5, A7, A8, A9, A12, A14

### 9.3 Logging & Monitoring

**Logging:**
- **Winston** logger with structured JSON
- **Dual destination:**
  - Local files (daily rotation, 14 days retention)
  - Sentry (5xx and unexpected errors only; 4xx is logged at `warn` to local logs and not forwarded to Sentry)
- **Log levels:** ERROR, WARN, INFO, HTTP, DEBUG
- **4xx responses** are logged at `warn` level; 5xx at `error`
- **Tracking:**
  - Request ID (unique per request)
  - Session ID (tracks entire user session across requests)
  - User ID (when authenticated)

**Monitoring:**
- **Sentry** (iOS, web, and API) (D4):
  - Transaction traces and error tracking
  - iOS uploads dSYMs from the build step
  - Events carry app version, build, and a shared request id that links one failure across layers
  - Auth headers, tokens, passwords, and request bodies are scrubbed
- **Alerts:**
  - High error rates
  - Slow queries (>1 second)
  - Budget overage patterns

Amended in v2.1: D4, D7

### 9.4 Error Handling

**Error Code Taxonomy:**
- **1xxx:** Authentication errors
- **2xxx:** Authorization errors
- **3xxx:** Validation errors
- **4xxx:** Resource not found errors
- **5xxx:** Resource conflict errors
- **6xxx:** Business logic errors
- **7xxx:** External service errors
- **8xxx:** Rate limiting errors
- **9xxx:** System errors

Each error includes:
- Numerical code (e.g., 1001)
- String code (e.g., "INVALID_CREDENTIALS")
- User-friendly message
- Optional details for debugging

### 9.5 Rate Limiting

- **General API:** 100 requests per 15 minutes
- **Auth endpoints:** 5 attempts per 15 minutes; rate limiter keys on IP plus email (D7)
- **Version-check endpoint (`GET /app/version-check`):** 60 requests per minute per IP (tolerant of a family sharing one IP); separate from general API limits (D7)
- **Trust proxy:** Required in production behind the tunnel (D7)
- **Response:** HTTP 429 with retry-after header

Amended in v2.1: D7

### 9.6 API Documentation

- **OpenAPI 3.1 specification**
- **Built from route annotations** (not tsoa); a parity test and committed snapshot protect the spec until a Zod-first migration (C1)
- **Swagger UI** at `/api-docs`
- **Type-safe** - matches actual implementation via snapshot check in CI (C8)

Amended in v2.1: C1

------

## 10. Data Model Decisions

### 10.1 User Model

**Single users table** for all people:
- `email` and `password_hash` nullable
- Non-authenticated users (children) have NULL credentials
- Simplifies queries and relationships

### 10.2 List Constraints

- One list per user (recipient) per year
- Enforced at database level: `UNIQUE (user_id, year)`
- Cannot create duplicate lists

### 10.3 Parent-Child Relationships

**New table:** `user_relationships`
- Links parents to children
- Enables authorization: "Can this user create a list for this child?"
- Supports multiple relationship types

### 10.4 Ownership vs Membership

- Owners stored directly on `lists` table (`owner_id`, `co_owner_id`)
- Members stored in separate `memberships` table
- Clear separation of privileges

### 10.5 Budget Privacy

- No shared budgets
- Each user owns their own budgets
- Simplifies data model and privacy rules

------

## 11. Assumptions

### 11.1 Currency & Localization

- **Single currency:** USD (no multi-currency support in v1)
- **No timezone logic:** Budgets based on calendar year only
- **Date handling:** All timestamps in UTC (TIMESTAMPTZ)

### 11.2 Payment

- **No payment processing** - system tracks purchases only
- Users enter purchase details manually
- No integration with payment gateways

### 11.3 Notifications

- **In-app only (v1):**
  - Users check app for invitations
  - No email or push notifications
- **Future (v2):**
  - Email notifications
  - APNS push notifications (iOS)

### 11.4 Search

- **Full-text search** available via PostgreSQL GIN indexes
- **Fuzzy search** via trigram matching
- **No external search service** (Elasticsearch, etc.)

### 11.5 File Storage

- **Image URLs only** - no file upload in v1
- Users provide URLs to product images
- Future: Consider S3 or similar for user-uploaded images

------

## 12. Future Enhancements (Post-v1)

### 12.1 Notifications
- Email notifications for invitations, purchases
- APNS push notifications (iOS)
- In-app notification center

### 12.2 Collaborative Features
- Comments on items
- Wish list sharing via link
- Gift recommendations

### 12.3 Analytics
- Spending trends over years
- Popular items/stores
- Budget adherence metrics

### 12.4 Export
- PDF gift receipts
- CSV export for tax records
- Budget summary reports

### 12.5 Multi-Platform
- Android app (Kotlin/Compose)
- Progressive Web App (PWA)

### 12.6 Advanced Features
- Gift wrapping service integration
- Price tracking and alerts
- Multi-currency support
- Multiple holiday support (birthdays, anniversaries)

------

## 13. Success Metrics

### 13.1 User Engagement
- Active users per month
- Lists created per user
- Purchases made per list
- Invitation acceptance rate

### 13.2 Performance
- API response time (95th percentile < 500ms)
- Database query performance
- Client-side load times

### 13.3 Business
- User retention month-over-month
- Budget overage frequency
- Feature adoption (off-list items, shipping tracking)

### 13.4 Technical
- System uptime (target: 99.9%)
- Error rate (target: < 0.1%)
- Sentry error rate and Apdex equivalent

Amended in v2.1: D4

------

## 14. Version Enforcement

The API enforces a minimum app version for iOS clients. Web always returns `state: ok` (V9).

### 14.1 Policy Table (V1)

One row per platform in `app_version_policies`:

| Field | Description |
|-------|-------------|
| `minimumVersion` | Semantic version below which clients must update |
| `minimumBuild` | Integer build number below which clients must update |
| `recommendedVersion` | Version for "update available" prompt |
| `latestVersion` / `latestBuild` | Most recent release |
| `manifestUrl` | `itms-services` install manifest URL (iOS sideload) |
| `ipaUrl` | Direct IPA download URL |
| `releaseNotes` | Release notes text |
| `enabled` | Whether enforcement is active for this platform |

### 14.2 Version Check Endpoint (V2, V5, V6)

`GET /app/version-check` — public, no authentication required.

Returns `state` (`ok`, `update_recommended`, or `force_update`) plus all policy fields. The response is additive-only so old builds continue to work.

Supports `ETag` / `If-None-Match` for `304` responses. `Cache-Control: public, max-age=60`.

The client fails open on timeout or network error (the current app state is unaffected). A cached `force_update` response remains enforced until the cache expires or a successful check returns a different state (V5).

Version comparison uses build number first; falls back to semantic version (V6).

Unknown platforms and the `web` platform always return `state: ok` (V9).

### 14.3 Login and Refresh Enforcement (V3, V4)

`POST /auth/login` and `POST /auth/refresh` return `426 VERSION_OUTDATED` when `X-Platform: ios` and the build or version is below the minimum.

Missing `X-Build` or `X-App-Version` headers are not enforced — they are not a security control.

### 14.4 Policy Administration (V7, V10)

Policy changes are applied via `npm run policy:set`. No manual database edits.

**Raising the minimum build is the mechanism for breaking-contract changes** (V10). Before the backend drops behavior old builds rely on, raise the minimum build first.

### 14.5 iOS Client Behavior (V8)

The iOS `VersionManager` checks for updates at three points:

1. **Cold start** — checked on every app launch before the home screen is shown
2. **Resume after background** — checked when the app returns to the foreground after 15 or more minutes in the background
3. **In-session polling** — checked every 6 hours while the app is active

**Prompt behavior:**
- `update_recommended` → dismissible prompt ("Update Available") allowing the user to continue
- `force_update` → blocking prompt with two options: **Update Now** (opens install URL) or **Logout** (clears session and returns to login); no way to dismiss without acting

**Network behavior (V5):**
- On timeout or network error the check fails open — the current app state is unaffected
- A cached `force_update` result remains enforced; fail-open does not lift an existing blocking prompt

Amended in v2.1: V1, V2, V3, V4, V5, V6, V7, V8, V9, V10

------

## Appendix A: Technology Justifications

### PostgreSQL 18
- Native UUID support
- Excellent query optimizer for complex joins
- Materialized views for performance
- Full-text search built-in
- Row-Level Security available for future privacy hardening

### Prisma ORM
- Type-safe database access
- Excellent TypeScript integration
- Built-in migrations
- Active community and support

### Zod Validation
- Runtime type validation
- Excellent TypeScript inference
- Composable schemas
- Clear error messages

### Express.js
- Mature, well-documented framework
- Large ecosystem
- Easy to integrate with Sentry, Winston
- TypeScript support

### Sentry
- Error tracking and transaction tracing across iOS, web, and API layers (D4)
- Shared request ID links one failure across all three layers
- dSYM uploads from the iOS build step for symbolicated crash reports
- Auth headers, tokens, passwords, and request bodies are scrubbed

------

## Appendix B: Key Design Principles

1. **Privacy First:** Off-list items and budget privacy are core features
2. **Type Safety:** TypeScript everywhere, validated at runtime with Zod
3. **Performance:** Database-optimized with indexes and materialized views
4. **User Experience:** Soft limits (budget warnings) over hard blocks
5. **Simplicity:** Eliminated shared budgets, merged user/person model
6. **Auditability:** Item status transitions are fully logged via `item_status_history`. An append-only `audit_log` table is now implemented and records all membership lifecycle (MEMBER_ADDED, MEMBER_REMOVED, MEMBER_LEFT, MEMBER_READDED, CO_OWNER_SET, CO_OWNER_CLEARED), list (created/visibility-change/archived), budget (BUDGET_CREATED, BUDGET_UPDATED, BUDGET_DELETED, BUDGET_DUPLICATED), and shipping-status (SHIPPING_UPDATED) events inside the same transaction as the change. There is no read API in v1; administrators query via `npm run audit:show`. Payloads carry ids, roles, statuses, and amounts in integer cents only; emails, names, password hashes, tokens, and notes are excluded. Dedicated per-entity history tables remain deferred.

Amended in v2.1: R1
Amended in v2.1: R1 (revised — implemented): `audit_log` implemented; records membership, list, budget, and shipping-status events; no read API; admin query via `npm run audit:show`
7. **Flexibility:** Allow over-quantity purchases, budget overages
8. **Real-World:** Optimistic concurrency matches how gifting actually works

------

**End of PRD v2.1**
