#!/bin/bash
# check-package-imports.sh
# Audits `import X` statements in LocalPackages/TrackerAPI source and test files against
# the products declared in Package.swift.  Exits non-zero if any undeclared import is found.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

PKG="LocalPackages/TrackerAPI"
MANIFEST="$PKG/Package.swift"
FAIL=0

# ---------------------------------------------------------------------------
# 1. Parse declared products from Package.swift
# ---------------------------------------------------------------------------

# Products declared in the main TrackerAPI target dependencies
SOURCE_PRODUCTS=$(grep -E '\.product\(name:' "$MANIFEST" \
    | grep -v "testTarget" \
    | sed -E 's/.*\.product\(name: "([^"]+)".*/\1/' \
    | sort -u)

# Products declared in the test target dependencies
TEST_PRODUCTS=$(grep -E '\.product\(name:' "$MANIFEST" \
    | sed -E 's/.*\.product\(name: "([^"]+)".*/\1/' \
    | sort -u)

# The test target also depends on the TrackerAPI product itself
TEST_PRODUCTS="$TEST_PRODUCTS
TrackerAPI"

# ---------------------------------------------------------------------------
# 2. System module allow-list (never declared in Package.swift)
# ---------------------------------------------------------------------------
SYSTEM_ALLOW="Foundation Swift Darwin Dispatch XCTest Testing os simd Combine ObjectiveC"

is_allowed() {
    local mod="$1"
    local declared="$2"
    # Check system allow-list
    for s in $SYSTEM_ALLOW; do
        [ "$mod" = "$s" ] && return 0
    done
    # Check declared products
    while IFS= read -r p; do
        [ "$mod" = "$p" ] && return 0
    done <<< "$declared"
    return 1
}

# ---------------------------------------------------------------------------
# 3. Audit source files (Sources/TrackerAPI/**/*.swift, excluding .build/)
# ---------------------------------------------------------------------------
echo "--- checking TrackerAPI source imports ---"
while IFS= read -r file; do
    while IFS= read -r mod; do
        [ -z "$mod" ] && continue
        if ! is_allowed "$mod" "$SOURCE_PRODUCTS"; then
            echo "UNDECLARED IMPORT in $file: import $mod"
            FAIL=1
        fi
    done < <(grep -E '^import [A-Za-z_][A-Za-z0-9_]*$' "$file" \
                | sed 's/^import //')
done < <(find "$PKG/Sources" -name "*.swift" -not -path "*/.build/*")

# ---------------------------------------------------------------------------
# 4. Audit test files (Tests/TrackerAPITests/**/*.swift, excluding .build/)
# ---------------------------------------------------------------------------
echo "--- checking TrackerAPITests import ---"
while IFS= read -r file; do
    while IFS= read -r mod; do
        [ -z "$mod" ] && continue
        if ! is_allowed "$mod" "$TEST_PRODUCTS"; then
            echo "UNDECLARED IMPORT in $file: import $mod"
            FAIL=1
        fi
    done < <(grep -E '^import [A-Za-z_][A-Za-z0-9_]*$' "$file" \
                | sed 's/^import //')
done < <(find "$PKG/Tests" -name "*.swift" -not -path "*/.build/*")

# ---------------------------------------------------------------------------
# 5. Result
# ---------------------------------------------------------------------------
if [ "$FAIL" -eq 0 ]; then
    echo "check-package-imports: OK"
else
    echo "check-package-imports: FAILED — undeclared imports detected"
fi
exit "$FAIL"
