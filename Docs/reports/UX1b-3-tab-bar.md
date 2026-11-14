# UX1b Story B3: The tab bar

Branch: feat/ux1b-dialogs-colors-and-polish. Pipeline: full (test-writer, implementer, convention-reviewer, acceptance-reviewer, sequential).

## What changed
- Navigation/TabBarView.swift: `.tabBarMinimizeBehavior(.onScrollDown)` added once on the TabView, after `.tint(.primaryColor)`, with a one-line comment (UX1b rule 4). Tabs, tags, tints and navigation unchanged.
- SDK check (acceptance-reviewer, from the installed swiftinterface): `View.tabBarMinimizeBehavior(_:)` is iOS 26.0; `TabBarMinimizeBehavior` has `automatic`, `onScrollDown`, `onScrollUp`, `never`; the deployment target is 26.0/26.2 in every configuration, so no availability guard is used.

## Tab roots (the note the story requires)
- Dashboard: NavigationStack > VStack(segment picker, banners, content). Normal state is a `List`, loading is a `ScrollView`. The full-error and empty states are non-scrolling views, so the tab bar will not minimize there (nothing to scroll). The scroll view sits inside a VStack, so minimizing keys off the nested scroll view; this is an inference, not tested.
- Statistics: NavigationStack > Group > `ProgressView` (brief, before the model exists) or `StatsContentView` (a `ScrollView` in every phase).
- Profile: NavigationStack > `ScrollView` in all states.

## Files
Changed: Navigation/TabBarView.swift; Docs/reports/UX1b-2-destructive-colors.md (after-commit verify line). Added (test): ChristmasTrackerTests/Navigation/TabBarMinimizeScanTests.swift (5 tests: setExactlyOnce, chainedOnTheTabView, nowhereElse, tabsUnchanged, tabRootsScroll). Deleted: none. Existing tests changed: none.

## Test arithmetic (app suite)
4340 + 5 new (grep -c @Test) - 0 = 4345. Measured by scripts/verify.sh: 4345. Package 212, release scripts 92, destination scripts 17.

## Raw output (from running commands)
Red before the change: setExactlyOnce and chainedOnTheTabView failed (0 occurrences), 4343 others passed (test-writer run). Before commit:
```
--- tests: 4345 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
After commit: see the line added at the end of this report after the commit run.

## Gate 2
- convention-reviewer: APPROVE. Warning: three test lines over 120 characters (TabBarMinimizeScanTests.swift 46, 55, 71).
- acceptance-reviewer: APPROVE. Notes: the test header "the three tab roots are vertical scroll views" overstates slightly (see tab roots above); `tabRootsScroll` is a loose source guard; `setExactlyOnce` is spelling-specific on purpose.
- Rejections: none. Stuck detector: none.

## Verification sources
Counts and OK lines from running commands; SDK and tab-root claims from the acceptance-reviewer reading the swiftinterface and views. No simulator run.

## Not done or partial
- No simulator run: that the bar actually shrinks on scroll down and returns on scroll up (and does so with the List nested in the Dashboard VStack) is proven only by Brian's real-mode check.
- Dashboard empty/error states and the brief initial Statistics state do not scroll, so the bar does not minimize there (by design of the platform).
