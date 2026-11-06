#!/bin/bash
# make-client-spec.sh
# Derives LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json from
# contract/openapi.json by transforming nullable schemas that swift-openapi-generator
# 1.14.2 (idiomatic strategy) cannot handle:
#   - anyOf[X, {type:null}] or anyOf[{type:null}, X]  → X (remove from required)
#   - {type:null} standalone property               → property removed entirely
#
# Number of anyOf-null and bare-null transformations. Update if contract schema
# or jq logic changes.
TRANSFORM_EXPECTED_COUNT=5

set -euo pipefail
cd "$(dirname "$0")/.."

SOURCE="contract/openapi.json"
DEST="LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json"

if [ ! -f "$SOURCE" ]; then
    echo "ERROR: $SOURCE does not exist" >&2
    exit 1
fi

# Shared jq definitions — must mirror the Swift transformAnyOfNullable / isPureNull logic
# in SpecConformanceTests.swift exactly, including the obj.count <= 2 guard.
JQ_DEFS='
def is_anyof_null:
  type == "object" and has("anyOf") and ((keys | length) <= 2) and
  ((.anyOf | length) == 2) and (.anyOf | map(type == "object" and .type == "null") | any);

def is_bare_null:
  type == "object" and .type == "null" and ((keys | length) == 1);

def null_part: .anyOf | map(select(type == "object" and .type == "null" | not)) | .[0];

def transform_obj:
  if type == "object" and has("properties") then
    (.properties | to_entries |
      map(select(.value | (is_anyof_null or is_bare_null))) |
      map(.key)) as $keys |
    .properties |= (to_entries | map(
      if (.value | is_bare_null) then empty
      elif (.value | is_anyof_null) then .value = (.value | null_part)
      else .
      end
    ) | from_entries) |
    if has("required") and ($keys | length > 0) then
      .required |= map(select(. as $k | ($keys | index($k)) == null))
    else .
    end
  else .
  end;
'

# Count transformations using a SEPARATE jq invocation (runs before the transform)
COUNT=$(jq -r "${JQ_DEFS}"'
[ .. | objects | select(has("properties")) |
  .properties | to_entries[] |
  select(.value | (is_anyof_null or is_bare_null)) ] | length
' "$SOURCE")

echo "Transformed $COUNT null-schema properties."

if [ "$COUNT" -ne "$TRANSFORM_EXPECTED_COUNT" ]; then
    echo "ERROR: Expected $TRANSFORM_EXPECTED_COUNT transformations but found $COUNT." >&2
    echo "The contract schema may have changed or the jq logic needs review." >&2
    exit 1
fi

# Check mode: compare what we would generate against the existing derived file
if [ "${1:-}" = "--check" ]; then
    TMPFILE=$(mktemp)
    jq "${JQ_DEFS}"'walk(transform_obj)' "$SOURCE" > "$TMPFILE"
    if ! diff -q "$TMPFILE" "$DEST" > /dev/null 2>&1; then
        echo "ERROR: Derived spec is out of date. Run scripts/make-client-spec.sh to regenerate." >&2
        rm -f "$TMPFILE"
        exit 1
    fi
    echo "Derived spec is up to date."
    rm -f "$TMPFILE"
    exit 0
fi

# Normal mode: generate the derived spec
jq "${JQ_DEFS}"'walk(transform_obj)' "$SOURCE" > "$DEST"
echo "Written to $DEST"
