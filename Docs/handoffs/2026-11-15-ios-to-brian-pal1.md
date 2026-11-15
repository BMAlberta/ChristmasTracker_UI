# Handoff: iOS to Brian, package PAL1 (palette revision 1)

Date: 2026-11-15. Branch `feat/pal1-palette-revision` (from master at the BA1 merge 6405309). Not pushed.

## Contract issues found

None. No networking, API model, repository, service or navigation change.

## What changed

Visual only. Four value changes, two new tokens, a thin edge on two pills, one bar token and new role badge looks.

| Token | Before (light / dark) | After (light / dark) | Pair that moved | Ratio before | Ratio after |
|---|---|---|---|---|---|
| textMuted | #6B7280 / #9AA5A1 | #656B77 / #9AA5A1 | light on backgroundSecondary | 4.22 | 4.67 |
| accent (and `destructiveColor`, which is the accent colorset) | #B23A48 / #E06A75 | #B23A48 / #E8737E | dark on surface | 4.39 | 4.86 |
| statusWrapped | #B23A48 / #E06A75 | #B23A48 / #E8737E | dark on surface | 4.39 | 4.86 |
| budgetOver | #B23A48 / #E06A75 | #B23A48 / #E8737E | dark on surface | 4.39 | 4.86 |
| highlightStrong (new) | n/a | #9C7A2E / #E4C76A | light on backgroundPrimary / surface | n/a | 3.81 / 4.01 |
| budgetWarningBar (new) | n/a | #9C7A2E / #E4C76A | light on backgroundPrimary / surface / backgroundSecondary | n/a | 3.81 / 4.01 / 3.50 |

- All 36 text pairs now reach 4.5:1. The three pinned text exceptions were removed, not loosened. The lowest text pair is light white on statusShipped (4.56).
- Edges: a 1 point `highlightStrong` stroke on `StatusPill` and `StatusDotLabel`, for the fills the table computes as under 3:1 on both light backgrounds (`ThemeEdgeRule`). Today that is Partial and Gifted. A new sub-3:1 light status fill without an edge fails a test.
- Near-limit budget bar: `BudgetStateStyle` near-limit token is now `budgetWarningBar` (bar fill only). `budgetWarning` is no longer used by any view; its token and colorset stay, with a pinned light exception (2.02 / 1.92) and a scan test.
- Role badges: Owner = primary fill; Co-owner = primary outline; Member = backgroundSecondary fill, `border` edge, textPrimary text; Viewer = no fill, `border` edge, muted text. No role badge uses `highlightColor` or `accentColor`. Badge text pairs, light / dark: Owner label on primary 9.63 / 6.00; Co-owner primary on surface 9.63 / 4.79 and on backgroundPrimary 9.15 / 6.00; Member textPrimary on backgroundSecondary 12.87 / 13.15; Viewer textMuted on surface 5.35 / 5.59 and on backgroundPrimary 5.09 / 7.01.
- Tests: app 4647 to 4679 (P1 +5, P2 +14, P3 +13); TrackerAPI 212 unchanged. Reports: `Docs/reports/PAL1-1-tokens.md`, `PAL1-2-edges.md`, `PAL1-3-badges.md`, `PAL1-4-handoff.md`. Brief: `Docs/epics/PAL1-palette-revision.md`.

## Commits (`git log --oneline master..HEAD` before this handoff commit)

```
1373387 PAL1: give role badges neutral and green looks
e41c413 PAL1: add the edge to gold pills and the stronger near-limit bar
d9c6b11 PAL1: revise the palette for contrast and add two tokens
d21807c PAL1: add epic brief and inventory
```

The handoff commit (`PAL1: add the package handoff note`) follows these.

## What the API team must do

Nothing.

## Open risks and deviations

- `theme.pdf` needs regenerating from the revised table (agents did not edit it).
- The dark cranberry is slightly lighter everywhere it is used (destructive buttons, swipe Delete, Leave list, Logout, Wrapped, over-budget).
- Decision 3 assumed the dark edge is invisible on both gold pills. It is for Partial (dark fill #E4C76A equals the edge). Dark Gifted is #F0D97C, so it shows a faint, slightly darker 1 point ring. Cosmetic, accepted by the Orchestrator, not changed. If you want it gone, the fix is a dark `highlightStrong` of #F0D97C or no edge in dark mode.
- The real near-limit ProgressView track is system-drawn and not measured. `budgetWarningBar` is pinned at 3:1 against backgroundPrimary, surface and backgroundSecondary only.
- Member badge text uses the neutral `textPrimary` token (reading of "primary text color"); a one-token change if you meant the green `primary`.
- The role badge `border` edge is decorative and faint (1.23 to 1.59:1). The words and the Member fill carry the badge. Viewer is muted text on a hairline.
- `ItemRow.swift:39` and `ItemDetailView.swift:224` still use `highlightColor` (not role badges, out of scope).
- Process: P2 tests were written after the production edit (the implementer said so); the pinned assertions would still fail on the old values.

## Section 9 of PROGRAM.md (one line)

PAL1 (iOS, 2026-11-15): palette revision 1 shipped on `feat/pal1-palette-revision` (muted text and dark cranberry darker/lighter to pass 4.5:1, gold pill edge and deeper near-limit bar, neutral/green role badges); no contract change, nothing for the API team; theme.pdf to be regenerated.

## Brian's real-mode check

State at handoff: Brian has not run any of these checks (all NOT PERFORMED). The agents never saw the simulator; previews were compiled by the build but nobody looked at them.

1. **Role badges.** Open the list screens and a list detail where you are owner, co-owner, member and viewer (switch seeded users if needed).
   - Light mode, then dark mode.
   - Expect: Owner solid green, Co-owner green outline, Member and Viewer quiet neutral badges; no gold or red badge anywhere.
2. **Gold pills, light.** Find an item with Partial and one with Gifted status.
   - Expect: the same gold fill as before with a thin darker gold edge; text readable.
3. **Gold pills, dark.** Same items in dark mode.
   - Expect: Partial shows no visible edge and looks as before. Gifted may show a faint, slightly darker ring (known, see open risks).
4. **Budget bar.** On Statistics, find a budget at or above the near-limit threshold (the seed has one).
   - Light, then dark.
   - Expect: the bar is a slightly deeper gold in light mode and unchanged in dark mode.
5. **Muted text.** Look at secondary captions on the Profile and list screens in light mode.
   - Expect: text a touch darker, no layout change.
6. **Red items, dark.** Open a child's swipe Delete, the Leave list button, the Logout button and an over-budget card in dark mode.
   - Expect: a slightly lighter red than before, all still clearly red.
7. **Nothing else moved.** Scroll the dashboard, a list, an item and Profile.
   - Expect: no layout or color change beyond the above.
