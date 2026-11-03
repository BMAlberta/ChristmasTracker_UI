# Testing Conventions (Agent-Facing Digest)

**Status:** Active · **Audience:** Test-writer subagent (and Implementer in solo mode)

Tests are written **test-first**, against the Gate 1 interface contract, and must **fail
for the right reason** before any implementation exists.

---

## Framework

- **Swift Testing** is the default for logic tests: `@Test`, `#expect`, `#require`.
- **`async throws` test functions** for asynchronous work. **No `XCTestExpectation`.**
- **One test type/class per file.**

## What gets tested, by layer

| Layer | Test type | What's tested |
|---|---|---|
| Repository | Unit | Network request shape, response decoding, mock injection |
| Service | Unit | Business logic, cache expiry, state transitions |
| View / UI | — | Not unit-tested — covered by Previews; XCUITest for flows |

## System-under-test & mocks

- Construct the SUT through a **`makeSUT` factory** so setup is uniform.
- **Reuse the existing mocks** — do not hand-roll a duplicate:
  - `MockAPIClient` — `Core/Networking/MockAPIClient.swift`
  - `MockAuthenticationRepository` — `Features/Authentication/Repositories/`
  - `MockListRepository` — `Features/Lists/Repositories/`
  - `MockItemRepository` — `Features/Items/Repositories/`
  - `MockPurchaseRepository` — `Features/Purchases/Repositories/`
  - `MockData` (preview fixtures) — `PreviewContent/MockData.swift`
- Mock types live alongside the production code they stand in for, not inside the test
  target, so Xcode Previews and tests share the same fixtures.

## Assertions

- Assert against **behavior visible through the interface**, never private state.
- Acceptance criteria must be **verifiable** — a passing test or an observable behavior.
- Cover the non-happy paths: loading / empty / error / offline / boundary.

## UI stories

- **XCUITest** for element presence, navigation flows, state transitions (loading / empty
  / error / populated) when a full UI flow is in scope.
- **ViewModel / presentation tests** for formatting, derived state, and view-state enums
  via Swift Testing, even for UI-only stories.

## CI note

Tests run against the `ChristmasTrackerTests` target via `scripts/test.sh`. XCUITests
are in a separate flow; keep unit coverage as the fast gate.
