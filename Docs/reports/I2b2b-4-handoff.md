# I2b-2b C4 Report: Real-Mode Check and Handoff

**Story:** C4 — Real-mode check and handoff  
**Package:** I2b-2b  
**Date:** 2026-11-06  
**Branch:** feat/i2b2b-generated-auth  
**Commit:** (see below)

---

## What Changed

### New files
- `Docs/handoffs/2026-11-06-ios-to-brian-i2b2b.md` — Full handoff document per CLAUDE.md spec.

### No code changes
This story is docs-only. No production or test files were modified.

---

## Commands and Raw Output

**git diff --stat master...HEAD (abbreviated — no forbidden paths):**
- No changes under `contract/`
- No changes under `.claude/`
- No changes to any `.pbxproj`
- No changes under `LocalPackages/TrackerAPI`
- No changes to lists, items, members, purchases, or stats code

**verify.sh at C3 HEAD (unchanged by C4):**
```
=== verify: unit tests ===
--- tests: 609 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 146 tests in 11 suites passed
=== verify: OK ===
```

---

## Acceptance Criteria Verification

1. **Brian's real-mode check:** 9 steps present in handoff — login success, login wrong password, login account disabled (403), registration success, registration existing email, registration invalid code, forgot password, Face ID enrollment, Face ID auto-attempt.
2. **What still uses the hand-written stack:** Lists, items, members, purchases, stats — all waiting for I3/I4.
3. **Open risks listed:** 900-second expiresIn assumption, nil-email rejection, RolePayload gap, Login 403 undocumented path, removed protocol members, appIsActive default.
4. **git diff --stat master...HEAD:** Confirmed no changes under contract/, .claude/, .pbxproj, LocalPackages/TrackerAPI, or lists/items code.

---

## Deviations

None.

---

## Not Done or Partial

None. Package I2b-2b is complete (C1–C4 all committed on `feat/i2b2b-generated-auth`).
