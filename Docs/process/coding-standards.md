# Coding Standards (Agent-Facing Digest)

**Status:** Active · **Audience:** Implementer + Convention Reviewer subagents

---

## Concurrency & architecture (hard rules)

- **Swift 6 strict concurrency.** All code compiles clean under strict concurrency with
  `-strict-concurrency=complete`.
- **No Combine.** `import Combine` is a hard block. Use `@Observable` and `AsyncSequence`.
- **No GCD.** `DispatchQueue.*` is a hard block. Use `async`/`await`, actors, `TaskGroup`.
- **`@Observable` service layer.** Services and view-facing types use `@Observable`
  (implicitly `@MainActor`). Actors are used where isolated mutable state is needed
  (e.g. DataStore types).
- **Protocol-first with the `-ing` suffix.** `ListRepositing`, `AuthenticatingService`.
  Concretes use the noun or `Impl`/`Live`.
- **Bare existentials use `any`.** Write `any ListRepositing`.
- **No global mutable state.** File-scope `var` is disallowed — use `let`, an actor, or
  encapsulate in a type.

## Safety & error handling

- **No `force_unwrapping`** in production code. Hard block in new code.
- **Typed errors in `catch`**; `fatalError` must carry a message.
- **`final` by default** on classes.
- **Explicit access control** on top-level declarations.

## Instrumentation (standing requirement)

- **`@Instrumented` is mandatory** on every new or modified `async`/`throws` function at
  the repository or service layer, applied **at implementation time — never retrofitted.**
- **Actor exception.** Actor-isolated methods skip the macro and use manual Sentry
  instrumentation, with a comment explaining the omission.
- Sentry operation naming: `layer.component.operation`
  (e.g. `repository.lists.fetchAll`).

## DesignSystem tokens (hard rules for views)

- **No raw hex/color literals** in views. Use `AppColors`.
- **No raw spacing values** in views. Use `AppSpacing`.
- **No raw `Font` constructors** in views. Use `AppTypography`.
- **No raw SF Symbol strings** where `AppIcons` provides the constant.

## SwiftUI patterns

- **`@Observable` + `@Environment`** for services. No prop-drilling.
- **`async`/`await` via `.task { }`**, never `onAppear` for data fetching.
- **`NavigationStack`** with a typed `NavigationDestination` enum — never inline
  `NavigationLink(destination:)`.
- **`@State` is always `private`**; ViewModels owned via `@State` in the view they serve.
- **Previews required** for non-trivial views — multiple states (loading/loaded/error/empty).
- **List/ForEach identity is `Identifiable` with a stable id** — `id: \.self` only for
  plain, duplication-free value types.

## Size limits

| Metric | Warning | Error |
|---|---|---|
| Line length | 120 | 160 |
| File length | 400 | 600 |
| Type body length | 200 | 300 |
| Function body length | 40 | 60 |

## Formatting

- No commented-out code — delete it, git history preserves it.
- `TODO`/`FIXME` permitted with a date and owner.
- Imports sorted.
