#!/bin/bash
# One-command editor setup: SourceKit-LSP code intelligence for VS Code. Idempotent; safe to re-run.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

command -v xcode-build-server >/dev/null || {
    echo "✗ xcode-build-server not found. Install it with:  brew install xcode-build-server" >&2
    exit 1
}

# --build_root must match the -derivedDataPath in .vscode/tasks.json, or the editor indexes a
# different build than the one F5 runs.
xcode-build-server config -project Tinycast.xcodeproj -scheme Tinycast \
    --build_root "$PWD/build/DerivedData"

echo "✓ buildServer.json written (git-ignored — it embeds an absolute path)."
echo "  Run the 'Build Tinycast.app (debug)' task once (⌘⇧B) to populate the index."
