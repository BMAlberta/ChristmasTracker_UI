# Handoff — I1-a Fix Pass (G1–G4)
**Date:** 2026-11-05  
**Branch:** feat/i1a-api-client-package  
**From:** iOS (Claude)  
**To:** Brian

---

## What Changed (Fix Pass Only)

This handoff supplements `Docs/handoffs/2026-11-05-ios-to-brian.md` (the original I1-a handoff). The fix pass addressed defects H1–H7 found during review. All work is on the same branch.

| Story | Commit | Summary |
|-------|--------|---------|
| G1 | eed4b93 | Derived spec: `scripts/make-client-spec.sh`, committed derived `openapi.json`, `SpecConformanceTests` |
| G2 | b92f546 | Factory: `make` throws + URL validation, `TrackerDateTranscoder` wired, `publicOperationIDs` consolidated |
| G3 | 95b7fe4 | Money: `doubleToDecimal` rewritten (no private fields, returns `Decimal?`); `classifyErrorCode` added; stale-token replay in `RefreshOn401Middleware` |
| G4 | (this commit) | Docs corrections to handoff and I1a-3 report |

---

## Contract Issues Found

None. The fix pass touched only the client package. No server behavior was changed.

---

## What the API Team Must Do

Nothing.

---

## Key Facts for I1-b Integration

1. **Derived spec** — `scripts/make-client-spec.sh` must be run if `contract/openapi.json` is updated. `scripts/verify.sh` enforces this.

2. **5 nullable fields now generated correctly** — these are now optional Swift properties, not missing:
   - `listSummary.value1.coOwner: Components.Schemas.PersonRef?`
   - `item.expectedUnitPrice: Double?`
   - `statsYearResponse.value1.totalBudget: Double?` (the field may be on `value1` depending on allOf layout — check generated types)
   - `statsYearResponse.value1.budget: Components.Schemas.BudgetStats?`
   - `PurchaseConfirmationRequiredData.purchase`: removed from spec (was bare null); no field exists

3. **`TrackerClientFactory.make` now throws** `TrackerAPIError.invalidServerURL` for bad URLs. Call sites must `try`.

4. **`classifyErrorCode(errorCode:)`** — use this to decide what to do with error codes from server 4xx responses. `.reLogin` means drop all tokens and go to login. `.refreshAndReplay` means the middleware already handled it; if it bubbles up, go to login. `.showMessage` means show `error.message`.

5. **`doubleToDecimal` returns `Decimal?`** — unwrap before mapping to domain `Decimal`. Nil means the server sent NaN or Infinity, which should not happen for money fields; treat as nil/zero at the mapping layer.

---

## Section 9 of PROGRAM.md (one line, replaces original)

> I1-a + fix pass complete: derived spec, 141 package tests, `classifyErrorCode`, stale-token replay; I1-b wires into Xcode and builds domain mapping layer.
