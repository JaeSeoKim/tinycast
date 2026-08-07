#!/bin/bash
# One-command editor setup: SourceKit-LSP code intelligence for VS Code. Idempotent; safe to re-run.
# `--index-tests` skips the buildServer step and only refreshes the Tests/ entries, which the VS Code
# build task does after every build because xcode-build-server rewrites .compile.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

# xcodebuild never compiles the harnesses — they are not in the project — so .compile has no entry for
# them and nothing in Tests/ resolves. run-tests.sh owns the source lists; this reads them from it.
index_tests() {
    [ -f .compile ] || echo '[]' > .compile
    ./Scripts/run-tests.sh --compile-db > "${TMPDIR:-/tmp}/tinycast-harness-db.json"
    python3 - "$PWD/.compile" "${TMPDIR:-/tmp}/tinycast-harness-db.json" <<'PY'
import json, sys

compile_path, harness_path = sys.argv[1], sys.argv[2]
with open(compile_path) as handle:
    entries = json.load(handle)
with open(harness_path) as handle:
    harnesses = json.load(handle)

def is_harness(entry):
    return any("/Tests/" in path for path in entry.get("files") or [])

merged = [entry for entry in entries if not is_harness(entry)] + harnesses
with open(compile_path, "w") as handle:
    json.dump(merged, handle, indent=1)
print(f"  {len(harnesses)} harness entries indexed")
PY
}

if [ "${1:-}" = "--index-tests" ]; then
    index_tests
    exit 0
fi

command -v xcode-build-server >/dev/null || {
    echo "✗ xcode-build-server not found. Install it with:  brew install xcode-build-server" >&2
    exit 1
}

# --build_root must match the -derivedDataPath in .vscode/tasks.json, or the editor indexes a
# different build than the one F5 runs.
xcode-build-server config -project Tinycast.xcodeproj -scheme Tinycast \
    --build_root "$PWD/build/DerivedData"

echo "✓ buildServer.json written (git-ignored — it embeds an absolute path)."
index_tests
echo "  Run the 'Build Tinycast.app (debug)' task once (⌘⇧B) to populate the index."
