# Contract Status

**Status: PRE-CONFORMANCE**

`contract/openapi.json` is known to disagree with the live server. Known mismatches include:
- The login response shape in the spec is flat `{accessToken, refreshToken}` but the server
  may return an envelope `{success, data: {...}}` or vice versa — unverified.
- The `User` object fields (`firstName`, `lastName`, `displayName`) do not match the app's
  current `User` model (`name`, snake_case CodingKeys).

**Do not generate, or hand-write, API models from `contract/openapi.json` until this status
is updated.** All network-layer story work must wait for the backend's contract-conformance
package to merge.

After the backend's contract-conformance package merges:
1. Replace `contract/openapi.json` with the backend snapshot.
2. Change this status to **CONFORMANT** and record the backend commit hash below.

Backend commit hash (fill in when conformant): _pending_
