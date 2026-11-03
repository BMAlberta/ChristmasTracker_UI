# Cache Check — ListDataStore Staleness Audit

## Cache path table

| Path | File : Line | Updates / Invalidates Cache? | How |
|---|---|---|---|
| `loadLists()` | ListService.swift:53 | ✅ Yes (cold miss) | `dataStore.setLists()` (line 77); warm hit serves cache; background `refreshLists()` if `shouldRefresh()` returns true |
| `refreshLists()` | ListService.swift:88 | ✅ Yes | `dataStore.setLists()` (line 96) |
| `loadListDetail(id:)` | ListService.swift:110 | ✅ Yes (cache miss) | `dataStore.setListDetail()` (line 124) |
| `createList()` | ListService.swift:136 | ✅ Yes | `dataStore.setListDetail(newList)` (line 143) + `refreshLists()` (line 145) overwrites summary cache |
| `updateList(id:_:)` | ListService.swift:157 | ✅ Yes | `dataStore.setListDetail(updated)` (line 163) + `refreshLists()` (line 168) |
| `deleteList(id:)` | ListService.swift:181 | ✅ Yes | `dataStore.removeList(id:)` (line 188) removes both summary and detail entries |
| `logout()` | AuthenticationService.swift:140 | ❌ **No** — bug | Clears `NetworkCache` (line 149) but never calls `dataStore.clear()`. Prior user's lists remain cached. |

**Cache expiry:** `ListDataStore.shouldRefresh()` (ListDataStore.swift:75) returns `true` after 15 minutes since the last `setLists()` call. This only triggers a *background* refresh on the warm path; it does not evict. No TTL on individual `listDetails` entries.

## Bug found

**Logout does not clear `ListDataStore`.** After a user logs out, `listSummaries` and `listDetails` retain the previous session's data. On the next `loadLists()` call (e.g. by a different user who logs into the same app process), the cache is non-empty so `loadLists()` serves the stale data directly and may skip the network fetch entirely if `shouldRefresh()` returns false (within 15-minute window).

Create and delete were already correct — no stale-data bugs found in those paths.

## Tests added

File: `ChristmasTrackerTests/Features/Lists/ListServiceTests.swift`

| Test | Purpose | Result before fix | Result after fix |
|---|---|---|---|
| `testLoadListsAfterCreateReflectsNewList` | Verifies create + refreshLists keeps cache consistent | PASS (already correct) | PASS |
| `testLoadListsAfterDeleteDoesNotServeDeletedList` | Verifies deleteList removes entry from cache | PASS (already correct) | PASS |
| `testLoadListsAfterLogoutFetchesFreshData` | Verifies clearCache() evicts stale data; next loadLists() fetches fresh | **FAIL** (compile error: `clearCache` did not exist) | PASS |

Also added `setDelay(_:)` to the `MockListRepository` extension so tests can run at zero delay.

## Commits

1. `1330f6a` — `fix: add ListService.clearCache() and tests for cache stale-data paths`
   - Added `clearCache()` to `ListService` (calls `dataStore.clear()`, resets `lists` and `currentListDetail`)
   - Added 3 tests + `setDelay` extension to `ListServiceTests`

2. `ca465e1` — `fix: clear ListService cache on logout`
   - `ProfileView` now injects `listService` and calls `listService.clearCache()` before `authService.logout()`

## verify.sh

```
--- tests: 40 passed, 0 failed, 0 skipped ---
=== verify: OK ===
```

## Not done or partial

The `ItemDataStore` is a parallel cache not covered by this task; it has the same logout-staleness risk and should be audited separately.
