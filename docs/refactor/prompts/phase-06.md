# Phase 06 kickoff — HotKey binding cache

Read `docs/refactor/phases/06-hotkey-binding-cache.md` completely before editing.

## Task

`HotKeyManager.binding(for:)` reads `UserDefaults` and JSON-decodes on every call — ~140 times at
launch, up to ~70 per keystroke while recording. Load bindings into an in-memory
`[HotKeyAction: HotKeyBinding]` once in `start()`, write through on mutation, serve every read from it.

## Hard gates

- **The persisted format is frozen.** A `.combo` still encodes as the bare
  `{"carbonKeyCode":N,"carbonModifiers":N}` JSON *string* under `KeyboardShortcuts_<name>`, and decoding
  still tries that shape first. Break this and every existing user binding and every old backup dies.
- The four bound-ID index keys keep their names, contents and sort order:
  `boundAppBundleIDs`, `boundPaneBundleIDs`, `boundCustomCommandIDs`, `boundQuicklinkIDs`.
- `binding(for:)` keeps its exact signature and return type.
- **Populate the whole map in `start()`.** Do not make it lazy per key — there must be no cache-miss
  path to reason about.
- `setBinding` must update the map, `UserDefaults`, **and** the relevant bound-ID index.
- `prune(key:live:action:)` must still delete orphaned defaults keys *and* leave the in-memory map
  reflecting the pruned state. Mind the ordering relative to population.
- **Do not** add `@Observable` and **do not** remove `objectWillChange.send()`. That is phase 15.
- Do not modify `HotKeyBinding.swift`, `KeyShortcut.swift`, `HotKeyCenter.swift`,
  `DoubleTapMonitor.swift` or `SettingsBackup.swift`.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Run the hotkey harness. Then, if you can, capture `defaults export com.tinycast.app.dev` before and
after a binding change and confirm only the expected key differs, in the legacy string format.

## Summarise

Use the system-prompt format. State explicitly where the map is populated, where it is written through,
and how `prune` interacts with population order.
