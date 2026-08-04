# Phase 30 kickoff — Naming vocabulary renames

Read `docs/refactor/phases/30-naming-vocabulary.md` completely.

## Task

Five renames, plus write the ten-suffix vocabulary table into `AGENTS.md`.

| Today | Becomes |
|---|---|
| `ClipboardManager` | `ClipboardMonitor` |
| `HotKeyManager` | `HotKeyBindings` |
| `CommandRegistry` | `CommandCatalog` |
| `PaletteViewModel` | `PaletteState` |

## Hard gates — one sharp edge, and it is severe

**Persisted identifiers are frozen. Renaming one is silent, permanent data loss for every user.**
Specifically, these strings do **not** change:

- `ClipboardManager.internalType` = `"com.tinycast.internal"` — change it and Tinycast re-captures its
  own pastes in a loop
- `boundAppBundleIDs`, `boundPaneBundleIDs`, `boundCustomCommandIDs`, `boundQuicklinkIDs`, and the
  `KeyboardShortcuts_<name>` key format
- **every `CommandID` raw value** (`"command:clipboard-history"`, …) — they double as `AppEntry.id`, so
  changing one orphans that command's favourite, visibility and ranking records
- `Notification.Name.tinycastSelectSettingsTab`'s raw value
- every SQLite table and column name, every `CodingKey`, every on-disk file name

Also:

- **Renames only.** Do not move a file, change a signature, or tidy anything while renaming.
- Each renamed file's name must match its renamed type.
- **Do not rename** `AppLauncher`, `QuicklinkLauncher` (Launcher is clearer for opening things),
  `SnippetRepository` (its conflict-detecting file semantics earn the name), `SnippetTextInjector`,
  `WindowMover` or `HyperKeyTap` (domain terms). Document all of these as exceptions in `AGENTS.md`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
git grep -n "ClipboardManager\|HotKeyManager\|CommandRegistry\|PaletteViewModel"    # must be empty
git diff -U0 | grep '^[-+].*"'    # inspect EVERY changed string literal
```

**Any changed string literal in a rename-only phase is a bug until proven otherwise.**

Run all 18 harnesses.

## Summarise

Use the system-prompt format. **Paste the output of the changed-string-literal grep** and account for
every line in it. Confirm the `AGENTS.md` table includes the documented exceptions with reasons.
