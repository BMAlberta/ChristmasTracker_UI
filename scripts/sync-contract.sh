#!/bin/bash
# sync-contract.sh: copy the API contract files from the backend repo into this
# client repo and stamp the contract version. The same file lives in the iOS and
# web repos (scripts/sync-contract.sh). Human-run; agents must not run it.
#
# Usage:
#   scripts/sync-contract.sh [--backend PATH] [--allow-branch BRANCH] [--check]
#
#   --backend PATH        backend repo (default: $BACKEND_REPO, else ../API_rewrite)
#   --allow-branch NAME   treat NAME as the backend base branch (default: main);
#                         use only for a rehearsal
#   --check               do not copy; report whether this client is behind
#
# Files copied (client-owned files such as Docs/contract-issues.md are never touched):
#   openapi-spec.snapshot.json -> contract/openapi.json
#   Docs/client-guide.md, error-codes.md, DECISIONS.md, PRD.md, privacy-matrix.md
set -euo pipefail

CLIENT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND="${BACKEND_REPO:-$(cd "$CLIENT_ROOT/.." && pwd)/API_rewrite}"
BASE_BRANCH="main"
CHECK=0

fail() { echo "ERROR: $1" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --backend)
      [ $# -ge 2 ] || fail "--backend needs a path"
      BACKEND="$2"; shift 2 ;;
    --allow-branch)
      [ $# -ge 2 ] || fail "--allow-branch needs a branch name"
      BASE_BRANCH="$2"; shift 2 ;;
    --check) CHECK=1; shift ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

PAIRS="openapi-spec.snapshot.json:contract/openapi.json
Docs/client-guide.md:Docs/client-guide.md
Docs/error-codes.md:Docs/error-codes.md
Docs/DECISIONS.md:Docs/DECISIONS.md
Docs/PRD.md:Docs/PRD.md
Docs/privacy-matrix.md:Docs/privacy-matrix.md"

SRC_LIST=""
while IFS=: read -r SRC DST; do
  [ -n "$SRC" ] || continue
  SRC_LIST="$SRC_LIST $SRC"
done <<EOF
$PAIRS
EOF

[ -d "$BACKEND/.git" ] || fail "backend repo not found at '$BACKEND' (use --backend PATH or set BACKEND_REPO)"

while IFS=: read -r SRC DST; do
  [ -n "$SRC" ] || continue
  [ -f "$BACKEND/$SRC" ] || fail "missing in backend: $SRC"
done <<EOF
$PAIRS
EOF

BRANCH="$(git -C "$BACKEND" branch --show-current)"
[ "$BRANCH" = "$BASE_BRANCH" ] || fail "backend is on '$BRANCH', expected '$BASE_BRANCH' (merge first; --allow-branch is for rehearsals only)"

# shellcheck disable=SC2086
DIRTY="$(git -C "$BACKEND" status --porcelain -- $SRC_LIST)"
[ -z "$DIRTY" ] || fail "backend has uncommitted changes in contract files:
$DIRTY"

BEHIND="$(git -C "$BACKEND" rev-list --count "HEAD..origin/$BASE_BRANCH" 2>/dev/null || echo 0)"
if [ "$BEHIND" -gt 0 ]; then
  echo "WARNING: backend $BASE_BRANCH is $BEHIND commits behind origin/$BASE_BRANCH (pull it, then rerun)"
fi

COMMIT="$(git -C "$BACKEND" rev-parse HEAD)"
SHORT="$(git -C "$BACKEND" rev-parse --short HEAD)"
SPEC_SHA="$(shasum -a 256 "$BACKEND/openapi-spec.snapshot.json" | awk '{print $1}')"
DEC_REV="$(grep -m1 -E '^\*\*Revision:\*\*' "$BACKEND/Docs/DECISIONS.md" | sed -E 's/[^0-9]*([0-9]+).*/\1/' || true)"
[ -n "$DEC_REV" ] || DEC_REV="unknown"

STATUS="PRE-CONFORMANCE"
if [ -f "$BACKEND/Docs/contract-conformance-report.md" ] && grep -qE '^\| *C9 ' "$BACKEND/Docs/DECISIONS.md"; then
  STATUS="CONFORMANT"
fi

VERSION_FILE="$CLIENT_ROOT/contract/VERSION"

if [ "$CHECK" -eq 1 ]; then
  [ -f "$VERSION_FILE" ] || fail "no contract/VERSION yet; run scripts/sync-contract.sh"
  SYNCED="$(grep '^backend_commit=' "$VERSION_FILE" | cut -d= -f2)"
  if [ "$SYNCED" = "$COMMIT" ]; then
    echo "contract is current ($SHORT, decisions revision $DEC_REV, $STATUS)"
    exit 0
  fi
  # shellcheck disable=SC2086
  CHANGED="$(git -C "$BACKEND" diff --name-only "$SYNCED" "$COMMIT" -- $SRC_LIST 2>/dev/null || echo "unknown")"
  if [ -z "$CHANGED" ]; then
    echo "backend moved on (${SYNCED:0:7} -> $SHORT) but no contract file changed; client is still current"
    exit 0
  fi
  echo "contract is OUT OF DATE (synced ${SYNCED:0:7}, backend $SHORT). Changed:"
  echo "$CHANGED"
  exit 1
fi

UPDATED=0
while IFS=: read -r SRC DST; do
  [ -n "$SRC" ] || continue
  mkdir -p "$(dirname "$CLIENT_ROOT/$DST")"
  if [ ! -f "$CLIENT_ROOT/$DST" ] || ! cmp -s "$BACKEND/$SRC" "$CLIENT_ROOT/$DST"; then
    cp "$BACKEND/$SRC" "$CLIENT_ROOT/$DST"
    echo "updated  $DST"
    UPDATED=$((UPDATED + 1))
  else
    echo "same     $DST"
  fi
done <<EOF
$PAIRS
EOF

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "$VERSION_FILE" <<EOF
backend_commit=$COMMIT
decisions_revision=$DEC_REV
spec_sha256=$SPEC_SHA
status=$STATUS
synced_at=$NOW
EOF

if [ "$STATUS" = "CONFORMANT" ]; then
  cat > "$CLIENT_ROOT/contract/STATUS.md" <<EOF
# Contract status

Status: CONFORMANT

Synced from the backend at commit $COMMIT (decisions revision $DEC_REV, spec sha256 ${SPEC_SHA:0:12}) on $NOW.
The spec is validated against real responses in the backend's test suite (decision C9).
API models come from this spec. Do not hand-edit contract/openapi.json; rerun scripts/sync-contract.sh.
EOF
else
  cat > "$CLIENT_ROOT/contract/STATUS.md" <<EOF
# Contract status

Status: PRE-CONFORMANCE

contract/openapi.json is known to disagree with the server (for example the login response lacks the
{success, data, meta} envelope and the user object). Do not generate, or hand-write, API models from it.
It becomes CONFORMANT after the backend's contract-conformance package merges and this script is rerun.

Last synced from the backend at commit $COMMIT (decisions revision $DEC_REV) on $NOW.
EOF
fi

echo
echo "Synced contract $SHORT (decisions revision $DEC_REV), status $STATUS. $UPDATED file(s) updated."
echo "Next: review with git diff, run the repo's verify command, then commit:"
echo "  git add contract Docs && git commit -m \"chore: sync contract $SHORT\""
