#!/bin/bash
# Format and lint the whole project. `--check` verifies without writing, for use before a PR.
# swift-format ships in the Xcode toolchain; SwiftLint is the one brew dependency.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

check=0
[ "${1:-}" = "--check" ] && check=1

SWIFT_FORMAT="$(xcrun --find swift-format 2>/dev/null)"
[ -x "$SWIFT_FORMAT" ] || {
    echo "✗ swift-format not found in the Xcode toolchain. Is Xcode 26 selected?" >&2
    exit 2
}

# Generated files and the two off-limits files in DesignSystem/Scrolling are never formatted.
sources() {
    find Tinycast Tests -name "*.swift" \
        ! -name "*.generated.swift" \
        ! -name "EdgeDissolve.swift" \
        ! -name "ThinScrollbar.swift"
}

status=0

if [ "$check" -eq 1 ]; then
    while IFS= read -r file; do
        "$SWIFT_FORMAT" format "$file" 2>/dev/null | diff -q - "$file" >/dev/null 2>&1 || {
            echo "needs formatting: $file"
            status=1
        }
    done < <(sources)
else
    sources | xargs "$SWIFT_FORMAT" format --in-place || status=1
fi

if command -v swiftlint >/dev/null; then
    swiftlint lint --quiet || status=1
else
    echo "! swiftlint not found — skipping lint. Install it with:  brew install swiftlint" >&2
fi

if [ "$status" -ne 0 ]; then
    echo
    [ "$check" -eq 1 ] && echo "Run ./Scripts/format.sh to fix what is fixable." >&2
    exit 1
fi
echo "✓ formatted and lint-clean"
