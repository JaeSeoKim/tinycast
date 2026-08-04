# Phase 16 — Observation: `AppSettings`

**Milestone:** M2 · **Effort:** L · **Risk:** High · **Context:** Med

---

## Overview

Migrate `AppSettings` — 25 `@Published` properties, each with a `didSet` writing `UserDefaults`,
observed by the palette, every launcher row, and most Settings panes.

## Why this phase exists

This single type is the widest invalidation source in the app. Any one of its 25 properties changing
currently re-renders everything observing it. Under `@Observable`, changing `windowGap` stops
re-rendering the launcher.

It is also the riskiest wave-B type: a missed `didSet` silently stops persisting a setting, and the user
only finds out after a relaunch.

## Architecture Review reference

**C-3** wave B · §6 P-1

## Objectives

1. Migrate `AppSettings` to `@Observable`.
2. Preserve **every** UserDefaults key, default value, and absence-vs-`false` distinction.
3. Update every consumer.

## Expected files to modify

| File | Change |
|---|---|
| `Tinycast/Core/AppSettings.swift` | `@Observable`; 25 properties. |
| `Tinycast/Core/PaletteWindowController.swift` | If it injects settings. |
| `Tinycast/Core/AppCore.swift` | The `settings.$…` Combine sinks **stay for now** — phase 18 removes them. See boundaries. |
| `Tinycast/Features/RootPaletteView.swift` | `@ObservedObject private var settings` → plain `let` / `@Environment`. |
| `Tinycast/Features/Launcher/LauncherView.swift` | `AppRow`'s settings observation. |
| `Tinycast/Features/Settings/*SettingsView.swift` | ~10 panes using `@ObservedObject … settings` and `$settings.x` bindings. |
| `Tinycast/Core/HotKey/HyperKeyTap.swift` | Its `settings.$hyperKey` sink — see boundaries. |
| `Tinycast/Core/AppIndex.swift` | Its `settings.$searchScopes` sink — see boundaries. |

## Files that must NOT change

- `Tinycast/Core/Backup/SettingsBackup.swift` — it reads and writes `settings` properties directly and
  must keep compiling unchanged. **Phase 33 handles it.**
- `Tinycast/Core/SearchScopes.swift`, `Core/VolumeLevel.swift`, `Core/HotKey/DoubleTap*` — harness-compiled
- `Tinycast/Core/CurrencyRateStore.swift` — its consent flag deliberately lives outside `AppSettings`

## Implementation boundaries

- **Every key, default and absence check is frozen.** In particular the eight properties that
  distinguish "unset" from "stored false" via `defaults.object(forKey:) == nil || defaults.bool(…)` must
  keep that exact logic:
  `hyperKeyIncludesShift`, `hyperKeyReplacesGlyph`, `showFavoritesInCompactMode`, `openOnCursorScreen`,
  `customCommandsShowInLauncher`, `snippetsShowInLauncher`, `windowManagementShowInLauncher`,
  `quicklinksShowInLauncher`, `quicklinkConfirmsBeforeDelete`. Getting one of these wrong flips a
  default for every existing user.
- **`didSet` persistence stays.** `@Observable` supports `didSet` on stored properties. Do **not**
  convert to a computed property backed by `UserDefaults` — that changes read cost on a hot path and
  loses the in-memory value.
- A small `@ObservationIgnored private let defaults` is expected; the property wrapper approach the
  review mentions (`stored(_:default:)`) is **optional** and only acceptable if it preserves every
  default exactly. **Prefer keeping the explicit `didSet` blocks in this phase** — one change at a time.
- **The Combine sinks in `AppCore.start()`, `AppIndex.start()` and `HyperKeyTap.start()` stay in this
  phase.** They subscribe to `settings.$x`, which disappears with `@Published` — so they must be
  converted to *something* to compile. Convert them to the minimal `withObservationTracking` form that
  preserves current behaviour, and leave the wider cleanup (removing the deferral `Task`s, deleting
  `assumeIsolated`) to phase 18. Note in the summary exactly what you changed.
- `SettingsKey.showInMenuBar` stays an `@AppStorage` key shared with `TinycastApp`'s `MenuBarExtra`. Do
  not fold it into `AppSettings`.
- `launchAtLogin`'s `didSet` calls `LaunchAtLogin.set` — a side effect, not persistence. Keep it.

## Detailed acceptance criteria

1. `AppSettings` is `@Observable`; no `@Published`.
2. All 25 UserDefaults keys are unchanged, verified against the `Key` enum.
3. All eight absence-vs-false checks are byte-identical.
4. `$settings.x` bindings in Settings panes are replaced with the `@Bindable` form and every control
   still writes through.
5. Every setting persists across a relaunch.
6. Changing `windowGap` no longer re-renders the launcher — verified with `_printChanges`.
7. `SettingsBackup` compiles unchanged and round-trips correctly.
8. `AppCore`'s feature-presence reconciliation still fires on every relevant toggle.

## Manual verification checklist

- [ ] `checklists/build.md` including the **startup timing** step
- [ ] `checklists/testing.md` — `callout-test`, `scopes-test`, `volume-test`
- [ ] `checklists/regression.md` — Core sweep + **Settings & backup** in full + **Hotkeys**
- [ ] **Walk every single Settings pane and toggle every control.** All 14 panes.
- [ ] Quit and relaunch → **verify every changed setting stuck**
- [ ] `defaults export com.tinycast.app.dev` before and after → only keys you deliberately changed differ
- [ ] Toggle each of the four feature switches (custom commands, snippets, window management,
      quicklinks) → the launcher section appears/disappears immediately
- [ ] Toggle each "show in launcher" companion → only the section changes, the feature stays on
- [ ] Change search scopes → the app list re-indexes
- [ ] Change the Hyper Key → the tap reconfigures, the status dot updates
- [ ] Change Pop to Root timeout → verify the new timeout behaviour
- [ ] Toggle compact mode → the palette resizes on next open
- [ ] Toggle "Show in menu bar" → the menu-bar icon appears/disappears
- [ ] With `_printChanges` in `RootPaletteView.body`: change `windowGap` → **no palette re-evaluation**

## Regression risks

| Risk | Mitigation |
|---|---|
| **A setting silently stops persisting** | AC5 + the `defaults export` diff + walking all 14 panes |
| **A default flips for existing users** because an absence check was simplified | AC3 — read all eight in the diff |
| A `$settings.x` binding is converted to a read-only value and a control goes dead | AC4 + toggling every control |
| The Combine sinks are over-cleaned here and feature reconciliation breaks | Boundary: minimal conversion only, phase 18 does the rest |
| `SettingsBackup` breaks | AC7 |

## Rollback strategy

`git revert <sha>`. UserDefaults keys and formats are unchanged, so a revert reads the same data.

**Data risk: none if AC2/AC3 held.** If a key name changed and shipped, a revert orphans the new key and
the user's setting reverts to default — recoverable but visible.

## Expected commit size

~14 files, +90 / −110 lines.

## Suggested commit message

```
Migrate AppSettings to @Observable

25 properties, the widest invalidation source in the app: a windowGap
change no longer re-renders every launcher row. Keys, defaults and the
absence-vs-stored-false checks are unchanged; the didSet persistence
blocks stay. The settings.$x sinks are converted minimally to compile —
phase 18 does the wider Combine cleanup.
```

## Dependencies

Phase 11. **Blocks phases 18 and 33.**

## Definition of Done

- All acceptance criteria met
- All 14 Settings panes exercised and persistence verified after a relaunch
- `defaults export` diff clean
- Merged

## Estimated difficulty

**High.** Not conceptually — by surface area. 25 properties × 14 panes × persistence.

## Estimated Claude context usage

**Medium–High.**

## Notes for reviewers

- **Read the eight absence-vs-false checks line by line.** This is the highest-consequence detail in the
  phase: getting one wrong silently flips a default for every existing install, and nothing in the build
  or the harnesses will tell you.
- **Walk all 14 panes yourself.** A dead binding looks completely normal until you toggle it.
- Check the `Key` enum against the diff — 25 string constants, all unchanged.
- If Claude introduced a `stored(_:default:)` property wrapper, scrutinise every default it produces
  against the current `init`. Prefer asking it to revert to explicit `didSet` blocks; the wrapper is a
  separate improvement and can wait.
- Confirm `SettingsBackup.swift` does not appear in the diff.
