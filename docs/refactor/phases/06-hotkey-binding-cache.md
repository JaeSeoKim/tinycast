# Phase 06 — HotKey binding cache

**Milestone:** M1 · **Effort:** M · **Risk:** Med · **Context:** Med

---

## Overview

`HotKeyManager.binding(for:)` reads `UserDefaults` and JSON-decodes on every call — ~140 times at launch,
up to ~70 per keystroke while a shortcut recorder is open, and once per visible launcher row per render.
Load the bindings into memory once and write through on change.

## Why this phase exists

Beyond the wasted work, this is a prerequisite: `HotKeyManager` currently calls `objectWillChange.send()`
manually because its state lives in `UserDefaults` rather than in a stored property. Phase 15 cannot
migrate it to `@Observable` until it has real state to observe.

## Architecture Review reference

**M-4** · §6 P-5 · C-3 wave C

## Objectives

1. Add `private var bindings: [HotKeyAction: HotKeyBinding]`, populated once in `start()`.
2. Serve every read from it; write through to `UserDefaults` on every mutation.
3. Cache `candidateActions` and invalidate it in `setBinding`.
4. Keep `UserDefaults` the on-disk source of truth, in the **exact legacy key format**.

## Expected files to modify

| File | Change |
|---|---|
| `Tinycast/Core/HotKeyManager.swift` | The cache, the write-through, the cached `candidateActions`. |

## Files that must NOT change

- `Tinycast/Core/HotKey/HotKeyBinding.swift` — its `Codable` conformance is the compatibility seam
- `Tinycast/Core/HotKey/KeyShortcut.swift`
- `Tinycast/Core/HotKey/HotKeyCenter.swift`
- `Tinycast/Core/HotKey/DoubleTapMonitor.swift`
- `Tinycast/Core/Backup/SettingsBackup.swift` — it reads through `binding(for:)` and must keep working
  unchanged

## Implementation boundaries

- **The persisted format is frozen.** A `.combo` still encodes as the bare
  `{"carbonKeyCode":N,"carbonModifiers":N}` JSON *string* under `KeyboardShortcuts_<name>`. Decoding
  still tries that shape first. Break this and every existing user binding and every old backup dies.
- The four bound-ID index keys (`boundAppBundleIDs`, `boundPaneBundleIDs`, `boundCustomCommandIDs`,
  `boundQuicklinkIDs`) keep their names, their contents and their sort order.
- `binding(for:)` keeps its exact signature and return type.
- **Do not** make the cache lazy-per-key. Populate the whole map in `start()` from `candidateActions`, so
  there is one load and no cache-miss path to reason about.
- `prune(key:live:action:)` must still delete the orphaned defaults keys *and* update the index — the
  in-memory map must reflect the pruned state.
- Do not add `@Observable`, do not remove `objectWillChange.send()`. That is phase 15.
- Do not change `conflictOwner`'s semantics: comparing whole `HotKeyBinding` values is what gives
  double-taps conflict detection on the same terms as combos.

## Detailed acceptance criteria

1. `binding(for:)` performs no `UserDefaults` read and no JSON decode after `start()` has run.
2. `setBinding` updates the map **and** `UserDefaults` **and** the relevant bound-ID index, atomically
   from the caller's point of view.
3. `candidateActions` is computed at most once per mutation, not once per access.
4. `syncDoubleTaps()` reads the map, not `UserDefaults`.
5. Stored JSON is byte-identical to what the previous implementation wrote — verified by inspecting
   `defaults read com.tinycast.app.dev` before and after setting a shortcut.
6. A binding set before this phase still fires after it, with **no migration step**.
7. `SettingsBackup.gather` produces an identical file to before.
8. Launch-time `binding(for:)` calls drop from ~140 to the single population pass.

## Manual verification checklist

- [ ] `checklists/build.md` including the **startup timing** step
- [ ] `checklists/testing.md` — `hotkey-test`
- [ ] `checklists/regression.md` — Core sweep + **Hotkeys** in full
- [ ] **Before the phase:** `defaults export com.tinycast.app.dev ~/Desktop/before.plist`
- [ ] **After:** set no new shortcut, relaunch, `defaults export … after.plist`, `diff` them — expect no
      change
- [ ] Set a new combo shortcut; diff again — only the expected key appears, in the legacy string format
- [ ] Set a double-tap binding; it fires; it survives relaunch
- [ ] Delete a binding with plain Delete in the recorder; it stops firing and the key is removed
- [ ] Trigger a conflict; the recorder names the correct current owner
- [ ] Delete a custom command that had a binding; the binding and its index entry are both cleaned up
- [ ] Export a settings backup and diff it against one taken before the phase

## Regression risks

| Risk | Mitigation |
|---|---|
| **Legacy key format changes and every user binding is lost** | AC5/AC6, plus the `defaults export` diff |
| Cache and `UserDefaults` drift after a prune | AC2; verify by deleting a bound custom command |
| A binding set by an *external* write (a settings import) is not seen | `SettingsBackup.apply` calls `setBinding`, so it goes through the write-through path — confirm it does |
| Recorder conflict detection breaks | Manual conflict test |
| Double-tap map rebuilt from stale data | AC4 |

## Rollback strategy

`git revert <sha>`. Safe: `UserDefaults` remains the source of truth throughout, so a revert simply goes
back to reading it directly. **No data risk**, provided AC5 held.

## Expected commit size

1 file, +55 / −25 lines.

## Suggested commit message

```
Cache hotkey bindings in memory

binding(for:) re-read UserDefaults and JSON-decoded on every call —
~140 times at launch and up to ~70 per keystroke while recording. Load
once in start(), write through on change. Persisted format unchanged.
```

## Dependencies

Phase 01. **Blocks phase 15.**

## Definition of Done

- All acceptance criteria met
- `defaults export` diff clean, captured in the progress file
- Bindings verified to survive a relaunch
- Merged

## Estimated difficulty

**Medium.** The logic is simple; the compatibility surface is not.

## Estimated Claude context usage

**Medium** — one file, but it is 227 dense lines with four persistence namespaces.

## Notes for reviewers

- **The `defaults export` diff is the acceptance test.** Read it yourself. Anything other than the key
  you deliberately set is a defect.
- Check `prune` carefully: it runs at `start()` *before* the map is populated, or must populate after.
  Getting that order wrong means a pruned binding stays live in memory for the session.
- `setBinding` has four `switch` arms updating four different index keys. Confirm all four still work —
  app, settings pane, custom command, quicklink.
- Reject any attempt to "simplify" `HotKeyBinding.Codable`. That file is on the do-not-change list for a
  reason.
