# Baseline Test Fix — ListServiceTests

**Branch:** chore/ios-setup  
**Date:** 2026-11-02

## Summary

Both failing tests exposed **real bugs (type c) in ListService.swift**. Both have been fixed with one commit each. A new test was added to cover the error-path `isLoading` reset.

---

## Failure 1: `testFilterShared()`

**Classification: (c) Real bug in ListService**  
**Status: Fixed — commit `fix: shared list filter selects member and viewer lists`**

**Root cause:** Copy-paste error in the `.shared` case of `filteredLists` at  
`ChristmasTracker/ChristmasTracker/Features/Lists/Services/ListService.swift:43`

```swift
// before
case .shared:
    return lists.filter { $0.myRole == .owner || $0.myRole == .coOwner }

// after
case .shared:
    return lists.filter { $0.myRole == .member || $0.myRole == .viewer }
```

---

## Failure 2: `testLoadLists()`

**Classification: (c) Real bug in ListService**  
**Status: Fixed — commit `fix: loadLists always resets isLoading`**

**Root cause (combined):**
1. `isLoading` was never reset to `false` on the successful non-cached fetch path or the error path. Only the cached-hit path had a reset.
2. `dataStore.setLists(fetchedLists)` was never called in the non-cached path (the "Update cache" comment was misleading — only the in-memory `lists` property was set), so `testLoadLists`'s cache verification check `cached.count == 3` also failed.

**Fix applied:** Added `defer { isLoading = false }` immediately after `isLoading = true`, removing the now-redundant reset in the cached-hit path. Added `await dataStore.setLists(fetchedLists)` before `lists = fetchedLists` in the non-cached path.

**New test added:** `testLoadListsFailureResetsIsLoading()` — verifies that a failing `fetchLists` call leaves `isLoading == false` and sets `error != nil`.

---

## Commands and output

```
scripts/test.sh "ChristmasTrackerTests/ListServiceTests"
--- tests: 10 passed, 0 failed, 0 skipped ---

scripts/verify.sh
--- tests: 37 passed, 0 failed, 0 skipped ---
```

---

## Not done or partial

None.
