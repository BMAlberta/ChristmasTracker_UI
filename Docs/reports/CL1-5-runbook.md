# CL1-5 — Release runbook note

## What changed
- `Docs/release-runbook.md` only: new section "Before any App Store submission" (placed before "Rollback"). It names the blocker: the on-device image fallback reads the non-public `imageMetadata` key path in `Features/LinkPreview/Providers/LinkPresentationProductImageProvider.swift` (marker `APPSTORE-BLOCKER: non-public key path`), which must be removed or replaced first. It states that ad hoc distribution is unaffected and gives the grep for the marker.
- The runbook had no similar section, so a new one was added. No code, no other file changed.

## Commands and raw output
- `grep -rn "APPSTORE-BLOCKER" "ChristmasTracker/ChristmasTracker"` confirmed the marker at line 9 of `LinkPresentationProductImageProvider.swift` before writing.
- `scripts/verify.sh` before and after the commit: see the handoff for the raw summary (docs-only change, test counts unchanged at 5331 app / 212 package).

## Deviations
- None.

## Not done or partial
- Nothing partial. The release scripts (`scripts/release.sh`) were not changed to check for the marker; that was not asked.
