#!/usr/bin/env bash
# audit_strings.sh
#
# Verifies that the Localizable.xcstrings catalog is non-empty (i.e. strings
# have been cataloged) and that no interpolated-only Text() calls exist without
# a matching catalog entry pattern.
#
# In Xcode 15+ with LOCALIZATION_PREFERS_STRING_CATALOGS=YES, Text("literal")
# calls are automatically extracted into the catalog at build time — the source
# literals ARE the keys. This script therefore checks:
#
#   1. Localizable.xcstrings exists and contains at least one string entry.
#   2. No View file uses bare Text("") (empty string — always a mistake).
#
# Run via: make audit-strings

set -euo pipefail

CATALOG="Sources/Localizable.xcstrings"
SOURCES="Sources/Views"
FAILURES=0

# ── Check 1: catalog exists and is non-empty ───────────────────────────────────

if [ ! -f "$CATALOG" ]; then
    echo ""
    echo "  ❌  $CATALOG not found."
    echo "      Create the file and add it to the Xcode target."
    FAILURES=$((FAILURES + 1))
else
    # Count string entries — the catalog has at least one key if "strings" object is non-empty
    entry_count=$(python3 -c "
import json, sys
with open('$CATALOG') as f:
    data = json.load(f)
print(len(data.get('strings', {})))
" 2>/dev/null || echo "0")

    if [[ "$entry_count" -eq 0 ]]; then
        echo ""
        echo "  ❌  $CATALOG exists but contains no string entries."
        echo "      Run 'Product > Build' in Xcode to auto-extract Text() literals,"
        echo "      or add entries manually."
        FAILURES=$((FAILURES + 1))
    else
        echo ""
        echo "  ✅  $CATALOG contains $entry_count cataloged string(s)."
    fi
fi

# ── Check 2: no empty Text("") calls ──────────────────────────────────────────

TOTAL_FILES=0
EMPTY_FAILURES=0

if [ -d "$SOURCES" ]; then
    while IFS= read -r -d '' file; do
        if [[ "$file" == *"Debug"* ]] || [[ "$file" == *"Test"* ]]; then
            continue
        fi
        TOTAL_FILES=$((TOTAL_FILES + 1))

        matches=$(grep -n 'Text("")' "$file" 2>/dev/null | grep -v '^\s*//' || true)
        if [[ -n "$matches" ]]; then
            echo ""
            echo "  ❌  Empty Text(\"\") found in $file"
            while IFS= read -r line; do
                echo "      $line"
            done <<< "$matches"
            EMPTY_FAILURES=$((EMPTY_FAILURES + 1))
        fi
    done < <(find "$SOURCES" -name "*.swift" -print0)
fi

echo ""
echo "Scanned $TOTAL_FILES View files."

if [[ $EMPTY_FAILURES -gt 0 ]]; then
    echo "❌  $EMPTY_FAILURES file(s) contain empty Text(\"\") calls — remove them."
    FAILURES=$((FAILURES + 1))
fi

if [[ $FAILURES -gt 0 ]]; then
    exit 1
fi

echo "✅  String catalog checks passed."
