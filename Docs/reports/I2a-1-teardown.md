# I2a Story 1 — Session Teardown and Clearable Stores

Branch: `feat/i2a-session-hygiene`

## What changed

### Files added
- `ChristmasTracker/ChristmasTracker/Features/Authentication/Services/SessionClearable.swift` — `SessionClearable` protocol and `TeardownReason` enum.
- `ChristmasTracker/ChristmasTracker/Core/Extensions/NetworkCache+SessionClearable.swift` — `NetworkCache: SessionClearable` conformance extension (outside `Core/Networking/` per brief).
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/SessionTeardownTests.swift` — 10 tests.
- `ChristmasTracker/ChristmasTrackerTests/Features/Authentication/MockSessionClearable.swift` — Spy clearable for testing.

### Files modified
- `Features/Authentication/Services/SessionManager.swift` — Added `clearables` array, `register(_:)`, and `teardown(reason:)` to the actor.
- `Features/Authentication/Services/AuthenticationService.swift` — Added `SessionClearable` conformance extension (same file for `private` method access); calls `clearAuthState()` and `clearStoredTokens()`.
- `Features/Lists/DataStores/ListDataStore.swift` — Added `SessionClearable` conformance; calls existing `clear()`.
- `Features/Items/DataStores/ItemDataStore.swift` — Added `SessionClearable` conformance; calls existing `clearAll()`.
- `Features/Lists/Services/ListService.swift` — Added `clearForSession()` in class body + empty conformance extension; changed stored property to `nonisolated let`.
- `Features/Items/Services/ItemService.swift` — Added `clearForSession()` in class body + empty conformance extension; changed stored property to `nonisolated let`.

### Files modified outside original Gate 1 scoped list (justified)
- `Features/Lists/Repositories/ListRespository.swift` — Added `nonisolated` to `protocol ListRepository`. Required because Swift 6.3.3 / iOS 26 SDK enables `InferIsolatedConformances`, which was inferring the protocol as `@MainActor` from its `ListService` usage. The test's actor-based mock conformance is otherwise impossible.
- `Features/Items/Repositories/ItemRepository.swift` — Same fix for `ItemRepository`.
- `Core/Models/GiftItem.swift` — Added `nonisolated` to `struct GiftItem` and `struct ItemPerson`; `@MainActor` on `ItemStatus.color`. `InferIsolatedConformances` was inferring `GiftItem` as `@MainActor`, making its properties inaccessible from non-isolated actor contexts.
- `Core/Models/GiftList.swift` — `@MainActor` on `ListRole.color` (same reason).
- `Core/Models/Purchase.swift` — `@MainActor` on `ShippingStatus.color` (same reason).

All out-of-scope changes are driven by the same toolchain inference issue; they are safe, backwards-compatible additions that add isolation clarity rather than change behaviour.

**Core/Networking files touched:** None. `NetworkCache` conformance lives in `Core/Extensions/NetworkCache+SessionClearable.swift`.

## verify.sh (verbatim)

```
=== verify: build ===
--- errors (first 20) ---
--- last 8 lines of /tmp/ct-build.log ---
note: Removed stale file ...
** BUILD SUCCEEDED **

=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 50 passed, 0 failed, 0 skipped ---
--- result bundle: /tmp/ct-results-1793719225.xcresult ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## Test arithmetic

Previous total: 40 tests.  
New tests added: 10 (`SessionTeardownTests.swift`).  
New total: **50 tests**.  

Swift Testing tests ARE counted by `scripts/verify.sh` (verified by output: 50 passed). Total rose by exactly 10.

New test names:
1. `listDataStoreIsEmptyAfterTeardown`
2. `itemDataStoreIsEmptyAfterTeardown`
3. `listServiceIsEmptyAfterTeardown`
4. `itemServiceIsEmptyAfterTeardown`
5. `authServiceIsSignedOutAfterTeardown`
6. `networkCacheIsEmptyAfterTeardown`
7. `failingClearableDoesNotBlockOthers`
8. `teardownIsIdempotent`
9. `signedOutStateReachedEvenWhenClearableThrows`
10. `deviceLevelDefaultsSurviveTeardown`

Verification source: running `scripts/verify.sh` (command output).

## Gate 2 results

**Convention reviewer:** APPROVED — 0 blockers, 2 warnings.
- Warning 1: `SessionClearable` and `TeardownReason` lacked explicit `internal` access modifier. **Fixed** by Orchestrator before commit.
- Warning 2: `ListRepository` and `ItemRepository` protocol names (pre-existing, not introduced by this story). Not fixed; tracked for I2b or a naming cleanup story.

**Acceptance reviewer:** APPROVED — all 10 acceptance criteria met by passing tests and code inspection.

## Stuck-detector log

No stuck-detector trigger. Implementer completed in one pass.

## Suspected-flaky tests

None identified.

## Deviations from prompt

1. `@Instrumented` absent on new `async throws` functions — approved deviation (I6a; macro not in codebase).
2. Repository protocols and model structs modified outside Gate 1 scoped list — justified above (toolchain `InferIsolatedConformances` inference).

## Recommendations for I1

- **Late-response risk**: services (`ListService`, `ItemService`) have no in-flight task cancellation. A `loadLists()` or `loadItems()` task started before teardown can complete after stores are cleared and repopulate the `ListDataStore`/`ItemDataStore`. I1 should add task handles and cancel them at the start of `teardown(reason:)`.
- **Logout ordering risk**: `AuthenticationService.logout()` still calls the server before local teardown (addressed in Story 2). The server call can timeout/fail and the teardown still runs (deferred block ensures it); ordering is noted.

## Not done or partial

None.

---

## Appendix: Isolation-edit diffs (added by R3)

This appendix was added during the R3 rework review (Story R3) to document the exact changes made outside the original Gate 1 scoped file list. Each diff is verbatim from `git diff master...HEAD -- "<path>"`.

### ListRespository.swift

```diff
diff --git a/ChristmasTracker/ChristmasTracker/Features/Lists/Repositories/ListRespository.swift b/ChristmasTracker/ChristmasTracker/Features/Lists/Repositories/ListRespository.swift
index 758c900..53f6cc0 100644
--- a/ChristmasTracker/ChristmasTracker/Features/Lists/Repositories/ListRespository.swift
+++ b/ChristmasTracker/ChristmasTracker/Features/Lists/Repositories/ListRespository.swift
@@ -7,27 +7,27 @@
 
 import Foundation
 
-protocol ListRepository: Repository {
-    
+nonisolated protocol ListRepository: Repository {
+
     /// Fetch all lists visible to the current user.
     /// - Returns: Array of GiftList objects.
     func fetchLists() async throws -> [GiftList]
-    
+
     /// Fetch detailed information for a specific list
     /// - Parameter id: ID of the list in question
     /// - Returns: ListDetail
     func fetchListDetail(id: String) async throws -> ListDetail
-    
+
     /// Create a new list
     /// - Parameter request: CreateListRequest with new list information.
     /// - Returns: ListDetail
     func createList(_ request: CreateListRequest) async throws -> ListDetail
-    
+
     /// Update an existing list.
     /// - Parameter request: UpdateListRequest with the updated list information.
     /// - Returns: ListDetail
     func updateList(id: String, _ request: UpdateListRequest) async throws -> ListDetail
-    
+
     /// Delete a list
     /// - Parameter id: ID of the list to be deleted.
     func deleteList(id: String) async throws
```

**Analysis:** Every changed line is either: (a) adding `nonisolated` to the protocol declaration — isolation annotation only, or (b) removing trailing whitespace from blank lines — cosmetic. No method signatures changed. `CreateItemRequest`, `UpdateItemRequest`, `ItemsResponse`, and `ItemResponse` are not present in this file and were not changed.

### ItemRepository.swift

```diff
diff --git a/ChristmasTracker/ChristmasTracker/Features/Items/Repositories/ItemRepository.swift b/ChristmasTracker/ChristmasTracker/Features/Items/Repositories/ItemRepository.swift
index 0a17160..f323eaf 100644
--- a/ChristmasTracker/ChristmasTracker/Features/Items/Repositories/ItemRepository.swift
+++ b/ChristmasTracker/ChristmasTracker/Features/Items/Repositories/ItemRepository.swift
@@ -7,29 +7,29 @@
 
 import Foundation
 
-protocol ItemRepository: Repository {
+nonisolated protocol ItemRepository: Repository {
     /// Fetch all items for a given list.
     /// - Parameter listId: String representing the list id.
     /// - Returns: Array of GiftItems.
     func fetchItems(listId: String) async throws -> [GiftItem]
-    
+
     /// Adds a new item to a list.
     /// - Parameters:
     ///   - listId: String representing the list into which the item will be added.
     ///   - request: CreateItemRequest
     /// - Returns: GiftItem for the new item.
     func createItem(listId: String, _ request: CreateItemRequest) async throws -> GiftItem
-    
+
     /// Update an existing item.
     /// - Parameters:
     ///   - id: String represented the list on which to update an item.
     ///   - request: UpdateItem details
     /// - Returns: Updated GiftItem
     func updateItem(id: String, _ request: UpdateItemRequest) async throws -> GiftItem
-    
+
     /// Delete an item by Id.
     /// - Parameter id: String representing the Id of the item to delete.
     func deleteItem(id: String) async throws
-    
+
     func fetchItemDetail(id: String) async throws -> GiftItem
 }
```

**Analysis:** Every changed line is either: (a) adding `nonisolated` to the protocol declaration — isolation annotation only, or (b) removing trailing whitespace — cosmetic. The file references `CreateItemRequest` and `UpdateItemRequest` by name in doc comments and method signatures, but those types themselves were NOT changed — only the `nonisolated` annotation on the enclosing protocol was added. `ItemsResponse` and `ItemResponse` do not appear in this file. **No request/response model types were modified.**

### GiftItem.swift

```diff
diff --git a/ChristmasTracker/ChristmasTracker/Core/Models/GiftItem.swift b/ChristmasTracker/ChristmasTracker/Core/Models/GiftItem.swift
index f092157..1fc0bf4 100644
--- a/ChristmasTracker/ChristmasTracker/Core/Models/GiftItem.swift
+++ b/ChristmasTracker/ChristmasTracker/Core/Models/GiftItem.swift
@@ -7,7 +7,7 @@
 import SwiftUI
 import Foundation
 
-struct GiftItem: Identifiable, Codable, Sendable, Hashable {
+nonisolated struct GiftItem: Identifiable, Codable, Sendable, Hashable {
 
     ...
 
-struct ItemPerson: Codable, Sendable, Identifiable, Hashable {
+nonisolated struct ItemPerson: Codable, Sendable, Identifiable, Hashable {
     let id: String
     let displayName: String
 }
 
-    var color: Color {
+    @MainActor var color: Color {
         switch self {
         case .available: return .gray
         ...
```

**Analysis:**
- `nonisolated struct GiftItem` — isolation annotation only (adding `nonisolated` to existing struct declaration).
- `nonisolated struct ItemPerson` — isolation annotation only.
- `@MainActor var color: Color` on `ItemStatus` — isolation annotation only (adding `@MainActor` to existing computed property).
- Trailing whitespace removal — cosmetic.

`CreateItemRequest` and `UpdateItemRequest` are defined elsewhere (in `ItemRepository.swift` as parameter types, not in `GiftItem.swift`). `ItemsResponse` and `ItemResponse` are API-layer types. **None of these were changed.** The domain model types `GiftItem` and `ItemPerson` were annotated but their stored properties, Codable conformance, and field names are unchanged.

### GiftList.swift

```diff
diff --git a/ChristmasTracker/ChristmasTracker/Core/Models/GiftList.swift b/ChristmasTracker/ChristmasTracker/Core/Models/GiftList.swift
index af8ff99..54432de 100644
--- a/ChristmasTracker/ChristmasTracker/Core/Models/GiftList.swift
+++ b/ChristmasTracker/ChristmasTracker/Core/Models/GiftList.swift
@@ -94,7 +94,7 @@
-    var color: Color {
+    @MainActor var color: Color {
         switch self {
         case .owner: return .primaryColor
         ...
```

**Analysis:** One changed line — `@MainActor` added to `ListRole.color` computed property. Isolation annotation only. No other fields, methods, or Codable conformances changed. `CreateItemRequest`, `UpdateItemRequest`, `ItemsResponse`, `ItemResponse` not present in this file.

### Purchase.swift

```diff
diff --git a/ChristmasTracker/ChristmasTracker/Core/Models/Purchase.swift b/ChristmasTracker/ChristmasTracker/Core/Models/Purchase.swift
index d7c3541..7d51979 100644
--- a/ChristmasTracker/ChristmasTracker/Core/Models/Purchase.swift
+++ b/ChristmasTracker/ChristmasTracker/Core/Models/Purchase.swift
@@ -92,7 +92,7 @@
-    var color: Color {
+    @MainActor var color: Color {
         switch self {
         case .notShipped: return .gray
         ...
```

**Analysis:** One changed line — `@MainActor` added to `ShippingStatus.color`. Isolation annotation only. `CreateItemRequest`, `UpdateItemRequest`, `ItemsResponse`, `ItemResponse` not present in this file.

---

### Summary for R3 step 3

All changes outside the original Gate 1 scoped list are exclusively isolation annotations (`nonisolated` or `@MainActor`). No behavioral changes, no field additions, no method signature changes. **`CreateItemRequest`, `UpdateItemRequest`, `ItemsResponse`, and `ItemResponse` were not changed.**

No deviations beyond isolation annotations were found. None to report.

---

### R3 step 4: cause of Story 1 isolation edits

Running `xcodebuild -showBuildSettings -project ChristmasTracker/ChristmasTracker.xcodeproj -scheme ChristmasTracker -configuration Debug` piped to grep for `SWIFT_DEFAULT_ACTOR_ISOLATION`, `SWIFT_APPROACHABLE_CONCURRENCY`, `SWIFT_UPCOMING_FEATURE`:

```
SWIFT_APPROACHABLE_CONCURRENCY = YES
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES
```

`SWIFT_UPCOMING_FEATURE_INFER_ISOLATED_CONFORMANCES` is **not set** (not present in the output).

**Conclusion:** The real cause of the Story 1 isolation edits is `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, not `InferIsolatedConformances` as the original Story 1 report stated. With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, all types in the module that do not have explicit isolation are inferred as `@MainActor`. This made the protocol declarations and model structs `@MainActor` by default, which prevented actor-based test mock conformances from compiling. The fix — adding `nonisolated` to the protocol declarations and struct declarations, and `@MainActor` to `Color`-returning computed properties that genuinely need `@MainActor` — is correct for this build setting, regardless of `InferIsolatedConformances`.

The Story 1 report's description of the cause as `InferIsolatedConformances` is inaccurate. The actual driver is the project-wide `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` setting (enabled via `SWIFT_APPROACHABLE_CONCURRENCY = YES` in Xcode 26 / Swift 6.3 or later). The fix applied is correct; only the explanation in the report was wrong.
