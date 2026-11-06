# Contract Issues

Client agents file contract mismatches here when the server disagrees with
`contract/openapi.json` or the documented behaviour. Do not work around a mismatch —
add a row and stop that item until the backend resolves it.

| # | Filed | Endpoint | Contract says | Server did | Status |
|---|---|---|---|---|---|
| 1 | 2026-11-06 | POST /auth/login | `Operations.Login.Output` has no `.forbidden` case; spec does not document 403 | `Docs/error-codes.md` and `Docs/client-guide.md` document that 1008 ACCOUNT_DISABLED is returned as 403 on login; server sends 403 JSON error body. Arrives as `.undocumented(403,…)` in the generated client. iOS handles via undocumented path per client-guide. | Spec gap — docs authoritative; not blocking I2b-2b (epic brief accounts for it). Backend to add `403 ForbiddenError` to the login operation in openapi.json. Client: ios |
| 2 | 2026-11-06 | All auth endpoints returning User | `Components.Schemas.User.RolePayload` is `@frozen` with only `case user = "USER"` and `case admin = "ADMIN"` | App domain `UserRole` enum has `.viewer`, `.member`, `.owner`, `.blindViewer` cases. Backend evidently returns role values other than `USER`/`ADMIN` (e.g. `viewer`, `member`). Strict generated decoder fails on those values. iOS works around with `JSONSerialization` fallback and manual role string mapping. | Spec gap — `openapi.json` missing role values. Backend to add `viewer`, `member`, `owner`, `blind_viewer` as valid `RolePayload` enum values and regenerate. Client: ios |
