# Contract Issues

Client agents file contract mismatches here when the server disagrees with
`contract/openapi.json` or the documented behaviour. Do not work around a mismatch —
add a row and stop that item until the backend resolves it.

| # | Filed | Endpoint | Contract says | Server did | Status |
|---|---|---|---|---|---|
| 1 | 2026-11-06 | POST /auth/login | `Operations.Login.Output` has no `.forbidden` case; spec does not document 403 | `Docs/error-codes.md` and `Docs/client-guide.md` document that 1008 ACCOUNT_DISABLED is returned as 403 on login; server sends 403 JSON error body. Arrives as `.undocumented(403,…)` in the generated client. iOS handles via undocumented path per client-guide. | Resolved: fixed in 99e15fb (C15), synced at 5c86cc3 (contract content of C16, backend f1d4f57, spec sha256 55f570342c69). iOS now handles login 403 through the typed `.forbidden` case; the `.undocumented(403)` special case is removed (I2b-2c U1). Originally: spec gap, docs authoritative; not blocking I2b-2b. Client: ios |
