# Baseline Test Fix — ListServiceTests

**Branch:** chore/ios-setup  
**Date:** 2026-11-02

## Summary

Both failing tests expose **real bugs (type c) in ListService.swift**. No production code was changed. Tests remain failing per the standing rule: do not modify production code to hide real bugs.

---

## Failure 1: `testFilterShared()`

**Classification: (c) Real bug in ListService**

**Root cause:** Copy-paste error in the `.shared` case of `filteredLists` at  
`ChristmasTracker/ChristmasTracker/Features/Lists/Services/ListService.swift:43`

```swift
case .shared:
    return lists.filter { $0.myRole == .owner || $0.myRole == .coOwner }
```

The `.shared` case uses the identical predicate as `.owned`. It should filter for `.member || .viewer`. The mock data has one list with `myRole: .member` and two with `.owner`/`.coOwner`, so the filter returns all three instead of one, and `allSatisfy { .member || .viewer }` fails.

**Fix required:** Change line 43 to `$0.myRole == .member || $0.myRole == .viewer`.  
**Action taken:** None — real production bug; left failing.

---

## Failure 2: `testLoadLists()`

**Classification: (c) Real bug in ListService**

**Root cause:** `isLoading` is set to `true` at the start of `loadLists()` but is never reset to `false` in the successful non-cached fetch path.  
`ChristmasTracker/ChristmasTracker/Features/Lists/Services/ListService.swift`  
Lines 53–85: the `do` block ends after `lastUpdated = Date()` with no `isLoading = false`. The `catch` block also does not reset the flag. Only the cached-hit path (line 63) resets it.

The test creates a fresh `ListDataStore` (empty cache), so the non-cached path runs. After `fetchLists()` returns the mock data successfully, `isLoading` stays `true`.

**Fix required:** Add `isLoading = false` after `lastUpdated = Date()` on line 78, and also after `self.error = handleError(...)` in the catch block.  
**Action taken:** None — real production bug; left failing.

---

## Commands and output

```
scripts/test.sh "ChristmasTrackerTests/ListServiceTests"
--- tests: 7 passed, 2 failed, 0 skipped ---
FAIL ListServiceTests/testFilterShared()
FAIL ListServiceTests/testLoadLists()

scripts/verify.sh
--- tests: 34 passed, 2 failed, 0 skipped ---
```

---

## Not done or partial

- Both production bugs are left unfixed pending a story assignment. The bugs are localized:  
  1. `ListService.swift:43` — wrong predicate in `.shared` filter case  
  2. `ListService.swift:53-85` — `isLoading` not reset on successful non-cached fetch path
