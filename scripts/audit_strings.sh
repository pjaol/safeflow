#!/usr/bin/env bash
# audit_strings.sh
#
# Fails if any SwiftUI View file contains hardcoded Text("...") string literals.
# Run via: make audit-strings
#
# Excludes:
#   - Empty strings: Text("")
#   - Debug/ directories
#   - Lines that are comments
#   - accessibilityIdentifier / accessibilityLabel calls (those are IDs, not UI strings)
#   - Single-character strings (icons, separators)
#   - Test files

set -euo pipefail

SOURCES="Sources/Views"
FAILURES=0
TOTAL_FILES=0

if [ ! -d "$SOURCES" ]; then
    echo "Error: Sources directory not found at $SOURCES"
    echo "Run this script from the project root."
    exit 1
fi

while IFS= read -r -d '' file; do
    # Skip debug and test files
    if [[ "$file" == *"Debug"* ]] || [[ "$file" == *"Test"* ]]; then
        continue
    fi

    TOTAL_FILES=$((TOTAL_FILES + 1))

    # Find Text("...") calls with non-empty, non-single-char content
    # Exclude comment lines, accessibilityIdentifier, accessibilityLabel assignments,
    # and strings that are clearly SF Symbol names (contain only dots and lowercase)
    matches=$(grep -n 'Text("' "$file" 2>/dev/null | \
        grep -v '^\s*//' | \
        grep -v 'Text("")' | \
        grep -v 'Text(".")' | \
        grep -v 'accessibilityIdentifier' | \
        grep -v '.accessibilityLabel("' | \
        grep -v '.accessibilityHint("' || true)

    if [[ -n "$matches" ]]; then
        echo ""
        echo "  ❌  $file"
        while IFS= read -r line; do
            echo "      $line"
        done <<< "$matches"
        FAILURES=$((FAILURES + 1))
    fi
done < <(find "$SOURCES" -name "*.swift" -print0)

echo ""
echo "Scanned $TOTAL_FILES View files."

if [[ $FAILURES -gt 0 ]]; then
    echo "❌  $FAILURES file(s) contain hardcoded Text() strings."
    echo "    Extract them into Localizable.xcstrings before merging to release/1.1."
    exit 1
fi

echo "✅  No hardcoded Text() strings found."
