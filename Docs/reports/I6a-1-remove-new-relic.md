# I6a Story 1 — Remove New Relic code

## Files changed

- **Deleted:** `ChristmasTracker/ChristmasTracker/Core/Logging/NewRelicDestination.swift`
- **Modified:** `ChristmasTracker/ChristmasTracker/Core/Logging/Logger.swift` — removed New Relic block (environment lookup for `NEW_RELIC_LICENSE_KEY`, `NewRelicDestination` init, fallback print) from `setupDestinations()`.

`LogEvent.toAttributes()` was defined as an extension in `NewRelicDestination.swift`. Grep confirmed no other callers; it was deleted with the file.

## verify.sh raw output

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: unit tests ===
--- tests: 65 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## Test arithmetic

Previous total: 65. Tests removed: 0. New tests added: 0. New total: **65**. ✓

No test file exclusively tested `NewRelicDestination` or `LogEvent.toAttributes()`.

## Verification method

- "No NewRelic references remain": verified by running `grep -rn "NewRelic\|NEW_RELIC" --include="*.swift"` over app and test sources — no output.
- Build and test pass: verified by running `scripts/verify.sh` and observing output above.

## Gate 2

**Convention reviewer:** No new or modified async/throws functions at repo/service layer — @Instrumented not required. No new types. No design tokens used (logging layer). Naming conventions unchanged. Git workflow: single commit `I6a: remove New Relic code`. No violations found.

**Acceptance reviewer:** All Gate 1 criteria met:
1. ✓ `NewRelicDestination.swift` deleted.
2. ✓ Logger.setupDestinations has no New Relic block.
3. ✓ `LogEvent.toAttributes()` deleted (no other callers confirmed by grep).
4. ✓ grep returns nothing for NewRelic/NEW_RELIC in app and test sources.
5. ✓ verify.sh passes, 65 tests.

## Stuck-detector log

No loops; single pass.

## Deviations

None.

## Not done or partial

None.
