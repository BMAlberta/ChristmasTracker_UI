# CL1-1 — Install link edges

## What changed
- `Features/Version/UpdateInstallLink.swift`
  - https scheme still matched case-insensitively; the built link now always carries lowercase `https://` (scheme replaced before encoding).
  - The authority (up to the first `/`, `?` or `#`) is rejected (nil) if it contains a backslash, whitespace or a control character.
  - itms-services inputs: unchanged rule (decoded inner URL passes the same rules and re-encodes to exactly the same value). Because the built link is always lowercase, an inner URL with an uppercase or mixed-case scheme is not canonical and is rejected. This is a consequence of the "always lowercase" rule, stated as a choice.
- `UpdateInstallLinkTests.swift`: tests added only (+47 lines, 0 deleted): `uppercaseSchemeNormalized`, `mixedCaseSchemeSameAsLowercase`, `backslashHostRejected` (3 inputs), `whitespaceHostRejected` (space, tab, newline), `controlCharacterHostRejected`, `itmsUppercaseInnerSchemeRejected` (2 inputs).

## Commands and raw output
Red first: the new tests failed before the change. After the change, `scripts/verify.sh` (run by the implementer on the working tree):
```
--- tests: 5326 passed, 0 failed, 0 skipped ---
TrackerAPI package: Test run with 212 tests in 16 suites passed
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
Baseline before the story: 5320 app tests, 212 package tests.

## Gate 2
- convention-reviewer: APPROVE, no findings.
- EDITED tests: none.

## Deviations
- The itms-services uppercase-inner-scheme rejection goes slightly beyond the literal "rule unchanged" wording (see above).

## Not done or partial
- Nothing partial. Simulator and network were not exercised (pure type, unit tests only). The package-level acceptance review is still to run.
