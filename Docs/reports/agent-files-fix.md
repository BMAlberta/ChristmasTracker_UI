# Agent Files Fix — 2026-11-02

## Changes per file

### CLAUDE.md
- **Authoritative reads**: added `contract/VERSION` next to `contract/STATUS.md`; added
  `Docs/privacy-matrix.md` entry; marked `Docs/client-guide.md` and `Docs/error-codes.md`
  as synced by `scripts/sync-contract.sh`; marked `Docs/ios-state-audit.md` as historical
  snapshot. Removed the sentence about copying after conformance package merges.
- **Branch rule**: removed "Verify the default branch (main) before branching" from
  Behavior gates; moved the base-branch bullet (master, tag 4.4, legacy/4.4,
  `gh pr create --base master`) from the Read list into Behavior gates as a single rule.
- **sync-contract note**: added prohibition on running or editing files synced by
  `scripts/sync-contract.sh`.
- **@Instrumented scope**: removed "view-model" — now repository and service layers only.
- **Network rules**: new section covering required headers, cookie handling, token refresh,
  Keychain storage, Decimal money, no offList on create-item, 401/403/404/426/429/
  confirmation_required handling, and Sentry privacy rule. Points to client-guide sections 2–6.
- **Package end**: new section specifying handoff doc path and format, and that Brian
  updates PROGRAM.md.

### .claude/agents/implementer.md
- PRE-CONFORMANCE + network/model story: now stops and reports to the Orchestrator
  (previously only noted the limitation in the attempt log).
- Single-test re-run command added: `scripts/test.sh ChristmasTrackerTests/<Suite>/<test>`.
- New file/project rules: files go only in existing file-synchronized folders; never edit
  `.pbxproj`; never add docs or non-asset files to the app target.
- Money rule added: use `Decimal`, never `Double` or `Float`.
- Screenshot check: if no simulator is running, log "not performed" and continue rather
  than blocking.

### .claude/agents/test-writer.md
- Renamed "UI story — ViewModel tests" to "Presentation-state tests (formatting, derived
  state, view-state enums)".
- Flag-driven UI section added: take role-to-flag expectations from `Docs/privacy-matrix.md`;
  once CONFORMANT, use fixtures from `Docs/client-guide.md` examples.
- Mock paths: each path is now verified with Glob before use; if actual path differs from
  the listed path, the agent uses the real path and reports the difference.

### .claude/agents/convention-reviewer.md
- Hard block added: `myRole` used to decide what a user may see or do (changed lines).
- Hard block added: new `.md`, `.pdf`, or `.png` file under `ChristmasTracker/` outside
  `Assets.xcassets` (changed lines).
- Hard block added: `offList` field on a create-item request type (changed lines).
- Warning added: `Double` or `Float` used for a monetary amount.
- Warning added (hard block once CONFORMANT): hand-written struct mirroring a raw API
  response outside the repository mapping layer.
- Output section updated to list the new hard-block categories.

### .claude/agents/acceptance-reviewer.md
- Description and "every path" wording updated to "runs on the full pipeline path, and on
  any story the Orchestrator asks it to review".
- "TDD intent" replaced with "Gate 1 spec and epic brief intent" throughout.
- PRE-CONFORMANCE check added as item 4: story touching API models or networking while
  STATUS.md says PRE-CONFORMANCE is an immediate rejection ("should not have started"),
  routed to the Orchestrator; contract comparison advisory for stories without network or
  model change.
- Visual check updated: if no simulator is booted, record "not performed" and do not block.
- Client-guide conformance expanded to explicitly check 401, 426, 429, and
  confirmation_required handling.
- Money type check added: `Decimal` required, not `Double` or `Float`.
- Sentry/log privacy check added: no tokens, passwords, or email addresses.

## Commands and output

```
scripts/verify.sh
--- tests: 40 passed, 0 failed, 0 skipped ---
```

## Deviations

None.

## Not done or partial

None.
