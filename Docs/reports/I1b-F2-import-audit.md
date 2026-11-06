# I1-b Story F2: Import Audit Guard

**Package:** I1-b fix pass · **Story:** F2 · **Date:** 2026-11-06

---

## Summary

Replaced the ineffective `=== verify: TrackerAPI Xcode scheme ===` step in `scripts/verify.sh` with a new `scripts/check-package-imports.sh` script and a corresponding `=== verify: TrackerAPI import audit ===` step.

**Root cause of the original gap:** The `xcodebuild build -scheme "TrackerAPI"` step used cached build artifacts; removing `HTTPTypes` from `Package.swift` still produced `BUILD SUCCEEDED` because the incremental build reused the previous artifact. The mutation catch in B4 was due to the pre-existing `=== verify: unit tests ===` step (which recompiles the app via `xcodebuild test`), not the new scheme step.

---

## Files Changed / Added

| File | Change |
|------|--------|
| `scripts/verify.sh` | Replaced `=== verify: TrackerAPI Xcode scheme ===` block (10 lines) with a 2-line `=== verify: TrackerAPI import audit ===` step |
| `scripts/check-package-imports.sh` | New — audits `import X` statements in TrackerAPI source and test files against products declared in Package.swift; exits non-zero on any undeclared import |

---

## How check-package-imports.sh Works

1. Parses declared `.product(name: ...)` entries from `LocalPackages/TrackerAPI/Package.swift` for the main target and test target.
2. For every `.swift` file under `Sources/` and `Tests/` (excluding `.build/`), reads all `import X` lines.
3. Checks each `X` against: (a) the declared products for the relevant target, (b) a system allow-list (`Foundation`, `Swift`, `Darwin`, `Testing`, etc.).
4. Exits `1` and prints `UNDECLARED IMPORT in <file>: import <X>` for any violation; exits `0` when clean.

---

## Mutation Proof

Temporarily removed `HTTPTypes` from `Package.swift` (the top-level dependency entry and both `.product(name: "HTTPTypes", ...)` entries in the target and test-target dependency lists), then ran `scripts/check-package-imports.sh`:

```
--- checking TrackerAPI source imports ---
UNDECLARED IMPORT in LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/VersionOutdatedMiddleware.swift: import HTTPTypes
UNDECLARED IMPORT in LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/RefreshOn401Middleware.swift: import HTTPTypes
UNDECLARED IMPORT in LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/RateLimitMiddleware.swift: import HTTPTypes
UNDECLARED IMPORT in LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/HeadersMiddleware.swift: import HTTPTypes
UNDECLARED IMPORT in LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/BearerAuthMiddleware.swift: import HTTPTypes
--- checking TrackerAPITests import ---
UNDECLARED IMPORT in LocalPackages/TrackerAPI/Tests/TrackerAPITests/TrackerClientFactoryTests.swift: import HTTPTypes
UNDECLARED IMPORT in LocalPackages/TrackerAPI/Tests/TrackerAPITests/RefreshOn401MiddlewareTests.swift: import HTTPTypes
UNDECLARED IMPORT in LocalPackages/TrackerAPI/Tests/TrackerAPITests/RateLimitMiddlewareTests.swift: import HTTPTypes
UNDECLARED IMPORT in LocalPackages/TrackerAPI/Tests/TrackerAPITests/VersionOutdatedMiddlewareTests.swift: import HTTPTypes
UNDECLARED IMPORT in LocalPackages/TrackerAPI/Tests/TrackerAPITests/TestHelpers.swift: import HTTPTypes
UNDECLARED IMPORT in LocalPackages/TrackerAPI/Tests/TrackerAPITests/HeadersMiddlewareTests.swift: import HTTPTypes
check-package-imports: FAILED — undeclared imports detected
exit code: 1
```

`Package.swift` was then restored and `scripts/check-package-imports.sh` exits `0` with `check-package-imports: OK`.

---

## Raw verify.sh Summary (after F2 commit, clean state)

```
=== verify: derived spec ===
Derived spec is up to date.
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 549 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 146 tests in 11 suites passed after 0.011 seconds.
=== verify: TrackerAPI import audit ===
--- checking TrackerAPI source imports ---
--- checking TrackerAPITests import ---
check-package-imports: OK
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Gate 2 Verdict

**Convention reviewer: APPROVED** — old step fully removed; new step uses correct echo format; script has executable bit and shebang; no Swift files changed; no xcodebuild in the new script.

**Acceptance reviewer: APPROVED** — All 5 criteria pass. Live mutation test (remove HTTPTypes → 11 UNDECLARED IMPORT lines, exit 1; restore → exit 0). Old scheme step absent; new audit step present and confirmed to fail on mutation. Mutation proof in report matches live output exactly. All pre-existing verify steps and format unchanged.

---

## Deviations from Spec

None.

---

## Not Done or Partial

None.
