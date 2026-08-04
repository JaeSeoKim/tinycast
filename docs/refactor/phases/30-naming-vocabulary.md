# Phase 30 — Naming vocabulary renames

**Milestone:** M6 · **Effort:** M · **Risk:** Low · **Context:** Med

---

## Overview

Apply the ten-suffix naming vocabulary from the review, and record it in `AGENTS.md` so it holds. Five
type renames, one file rename, no logic changes.

## Why this phase exists

Roughly twenty competing suffixes are in use — `Manager`, `Service`, `Store`, `Index`, `Session`,
`Controller`, `Registry`, `Catalog`, `Runner`, `Monitor`, `Center`, `Presenter`, `Repository`,
`Scanner`, `Policy`, `Engine`, `Injector`, `Launcher`, `Mover`, `Tap`, `ViewModel`. Most carry real
meaning; the problem is that some are synonyms for each other and no rule is written down.

## Architecture Review reference

**L-3, L-4, L-5, L-10** · §4.1 naming vocabulary

## Objectives

1. Apply five renames.
2. Write the ten-suffix table into `AGENTS.md`.
3. Change nothing else.

## Renames

| Today | Becomes | Why |
|---|---|---|
| `ClipboardManager` | `ClipboardMonitor` | It polls an external stream — that is what `Monitor` means |
| `HotKeyManager` | `HotKeyBindings` | It persists and publishes bindings; `HotKeyCenter` is already the Carbon layer |
| `CommandRegistry` | `CommandCatalog` | Matches `SystemActionCatalog`, `WindowCommandCatalog` |
| `PaletteViewModel` | `PaletteState` | It is shared app state read by the window controller and the panel, not a per-view VM |
| `Bundle+AppName.swift` | already `AppDisplayName.swift` (phase 27) | Concept-named, like `CursorScreen.swift` |

## Expected files to modify

Every file referencing a renamed type — roughly 20 — plus `AGENTS.md`.

## Files that must NOT change

- No behaviour anywhere. This phase is `git grep` and rename.
- Any **persisted string**: `UserDefaults` keys, SQLite table and column names, JSON `CodingKeys`,
  file names on disk, `NSPasteboard` type identifiers, `Notification.Name` raw values.
- `Tools/*.swift` assertions — only the type names they reference, if any.

## Implementation boundaries

- **Renames only.** Do not move a file, change a signature, or "tidy" anything while renaming.
- **Persisted identifiers are frozen.** In particular:
  - `ClipboardManager.internalType` is `"com.tinycast.internal"` — the *string* does not change.
  - `HotKeyManager`'s defaults keys (`boundAppBundleIDs`, `boundPaneBundleIDs`,
    `boundCustomCommandIDs`, `boundQuicklinkIDs`, `KeyboardShortcuts_<name>`) do not change.
  - `CommandID`'s raw values (`"command:clipboard-history"`, …) do not change — they are `AppEntry` ids.
  - `Notification.Name.tinycastSelectSettingsTab`'s raw value does not change.
- The renamed file name must match its renamed type.
- Do **not** rename `AppLauncher` or `QuicklinkLauncher`. "Launcher" is clearer than "Runner" for
  opening things; document them in `AGENTS.md` as a reserved synonym for `NSWorkspace.open` wrappers.
- Do **not** rename `SnippetRepository`. Its conflict-detecting, revision-checked file semantics earn
  the name; document it as the eleventh suffix.
- Do **not** rename `SnippetTextInjector`, `WindowMover`, `HyperKeyTap` — domain terms with no better
  alternative.

## Detailed acceptance criteria

1. All five renames applied consistently; no old name remains
   (`git grep -n "ClipboardManager\|HotKeyManager\|CommandRegistry\|PaletteViewModel"` → empty).
2. Every file's name matches its primary type.
3. **No persisted string changed** — verified by a `defaults export` diff and by opening an existing
   clipboard database.
4. `AGENTS.md` contains the ten-suffix table plus the three documented exceptions
   (`Launcher`, `Repository`, and the domain terms).
5. All 18 harnesses pass.
6. Zero behaviour change.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — all 18
- [ ] `checklists/regression.md` — Core sweep + **Clipboard** + **Hotkeys** + **Data safety**
- [ ] `defaults export com.tinycast.app.dev` before and after → **no diff**
- [ ] Existing clipboard history still loads (SQLite schema untouched)
- [ ] Existing hotkey bindings still fire
- [ ] Copy something → it is captured (the pasteboard marker string is unchanged)
- [ ] Paste from Tinycast → it is **not** re-captured (the marker still works)
- [ ] Settings ▸ a pane switch from the palette still works (the notification name is unchanged)
- [ ] Export a settings backup → diff against one from before → identical

## Regression risks

| Risk | Mitigation |
|---|---|
| **A persisted key gets renamed along with its type** — the classic rename bug. Every user loses their hotkeys. | AC3, the `defaults export` diff, and the explicit frozen-identifier list |
| The pasteboard marker string changes → Tinycast re-captures its own pastes in an infinite loop | The paste-then-check test |
| `CommandID` raw values change → every built-in command's `AppEntry` id changes → favourites, hidden items and rankings for them are orphaned | Explicit boundary; check the enum in the diff |
| A rename lands in a `Tools/` harness assertion string | All 18 harnesses |

## Rollback strategy

`git revert <sha>`. Safe **provided AC3 held**. If a persisted key did change and shipped, a revert
orphans the new key — verify AC3 before merging, not after.

## Expected commit size

~20 files, mostly one-line identifier changes. `AGENTS.md` +40 lines.

## Suggested commit message

```
Apply the naming vocabulary

ClipboardManager → ClipboardMonitor, HotKeyManager → HotKeyBindings,
CommandRegistry → CommandCatalog, PaletteViewModel → PaletteState. The
ten-suffix table goes into AGENTS.md along with the three documented
exceptions. No persisted string changes: defaults keys, SQLite columns,
CommandID raw values and the pasteboard marker are all untouched.
```

## Dependencies

**Phase 29 (hard).**

## Definition of Done

- All acceptance criteria met
- `defaults export` diff clean
- Vocabulary table in `AGENTS.md`
- Merged

## Estimated difficulty

**Low–Medium.** IDE-driven, with one sharp edge.

## Estimated Claude context usage

**Medium.**

## Notes for reviewers

- **Search the diff for string literals.** Any changed string literal in a rename-only phase is a bug
  until proven otherwise. `git diff -U0 | grep '^[-+].*"'` is a fast first pass.
- The `defaults export` diff is mandatory, not optional. A renamed defaults key is silent, permanent
  data loss for every user who upgrades.
- Check `CommandID`'s raw values specifically — they double as `AppEntry.id`, so changing one orphans
  that command's favourite, visibility and ranking records.
- Confirm the `AGENTS.md` table lists the exceptions with reasons. A vocabulary with undocumented
  exceptions is a vocabulary nobody follows.
