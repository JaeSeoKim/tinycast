> **⚠ An approved architecture refactor is in progress.** Structural rules below — file layout, type
> ownership, which type does what — are being changed by it, so a `docs/refactor/` phase contradicting
> one is **not** an error: the phase document wins. Precedence ladder in
> [`docs/refactor/prompts/system-prompt.md`](docs/refactor/prompts/system-prompt.md); compatibility rules
> in [`docs/refactor/POLICY.md`](docs/refactor/POLICY.md). **Behavioral invariants always hold** (UI,
> keyboard, accessibility, permissions/consent, Swift 6 safety, off-limits files) — a phase contradicting
> one of those is wrong: stop and say so. Not working from a phase? Ignore this box.

## Project

Tinycast is a native macOS menu-bar launcher (a minimal Raycast): fuzzy app launcher, global +
per-app hotkeys, a text/image clipboard history, an inline calculator, and an emoji picker. SwiftUI +
AppKit, runs as an accessory (no Dock icon, `LSUIElement`). Targets **macOS 26+** (Liquid Glass) and
builds with the **Xcode 26** toolchain.

- **Build:** XcodeGen owns the project — `Tinycast.xcodeproj` is committed but generated from
  `project.yml`. After editing it, run `xcodegen generate` and commit. No SwiftPM, no `Package.swift`,
  **no third-party dependencies**. See [development.md](docs/development.md), [signing.md](docs/signing.md).
- **Channels:** Debug is its own channel (`Tinycast Dev.app` / `com.tinycast.app.dev`), so a local run
  never shares prefs, caches, TCC grants or login item with an installed build. Anything newly persisted
  stays keyed by `Bundle.main.bundleIdentifier`.
- **Tests:** no XCTest target — standalone `swiftc` harnesses in `Tools/`. See the purity table below.

## Philosophy

Production-quality, as if written by a senior macOS engineer. Prefer simple over clever; preserve
existing behavior unless the task changes it. Views stay declarative — logic lives in models/managers.
Remove dead code rather than adding compatibility layers.

**Comments are single-line** — never stacked, never over 100 characters. Comment the *why*, the gotcha
or the invariant; never restate the code. Long rationale belongs in `docs/<subsystem>.md`.

## Architecture

Full detail: [architecture.md](docs/architecture.md).

- **Single-owner core.** `AppCore.shared` (`Core/AppCore.swift`) is a `@MainActor` singleton owning every
  long-lived manager and the window controllers. `AppDelegate.applicationDidFinishLaunching` calls
  `AppCore.shared.start()` and nothing else — the one wiring point. Palette / paste / launch actions are
  methods on `AppCore` that views call.
- **Mostly AppKit windows.** `TinycastApp` (`@main`) declares only a `MenuBarExtra` scene. The palette is
  a borderless floating `NSPanel` hosting SwiftUI; Settings/About are plain `NSWindow`s via
  `AuxWindowController`. SwiftUI `Settings` / `Window` scenes are deliberately avoided (unreliable for
  accessory apps).

**Subsystem docs** — read the relevant one before changing that area:
[palette](docs/palette.md) · [launcher](docs/launcher.md) · [calculator](docs/calculator.md) ·
[clipboard](docs/clipboard.md) · [emoji](docs/emoji.md) · [snippets](docs/snippets.md) ·
[quicklinks](docs/quicklinks.md) · [window management](docs/window-management.md) ·
[hotkeys](docs/hotkeys.md) · [uninstall](docs/uninstall.md) ·
[Raycast import](docs/raycast-import.md) · [UI & design system](docs/ui.md) ·
[development](docs/development.md) · [signing](docs/signing.md)

## Critical Invariants

Never break these without an explicit task to do so. Each links the doc holding its full rationale.

### Ownership & state

- **`AppCore` is the sole owner.** New long-lived state goes on `AppCore`, wired in `start()`. No
  competing singletons, no managers wired elsewhere.
- **`PaletteWindowController` solely owns the palette frame.** The hosting view sets `sizingOptions = []`
  so SwiftUI never drives window size — otherwise the top edge drifts on the compact↔expanded swap.
- **The flat `selection` index must match visible row order exactly**, calculator card at index 0
  included. Selection is the single source of truth for highlight and activation.
- **`AppEntry.Kind` is the only thing that says what an entry is** — never sniff an entry ID. A new
  category means: a new case, a slice in `AppIndex.publishEntries()`, then the filter in
  `LauncherList.rows`, in that order.
- **Searchable fields stay separate** — name, Spotlight alternates, bundle id, executable are never
  flattened, because the field picks the band. A new field means a new `Band` case + a `consider` call.
  [launcher.md](docs/launcher.md)

### Purity — breaking one of these breaks its harness

These files stay Foundation-only (plus the noted exceptions) with every environment fact **injected**,
because a `Tools/` harness compiles the real source rather than a copy. Full command lines:
[development.md](docs/development.md).

| Must stay pure | Harness | Injected / notes |
|---|---|---|
| `Core/SearchRelevance.swift` | `fuzz-test` | — |
| `Core/LauncherRankingStore.swift` | `ranking-test` | clock via `now`, path via `fileURL` |
| `Core/SearchScopes.swift` | `scopes-test` | — |
| `Core/Calculator/*` | `calc-test` | clock via `now`/`calendar`, FX via `rates` |
| `Core/Emoji/{EmojiCatalog,EmojiGridGeometry}` | `emoji-test` | — |
| `Core/ClipboardStore.swift` | `clipboard-test` | + SQLite3; **no other app source** |
| `Core/Snippets/*` (whole directory) | `snippets-test` | AppKit files stub-able |
| `Core/{CustomCommand,ShellCommandRunner}.swift` | `custom-command-test` | + Combine, Darwin |
| `Core/SystemAction.swift` | `system-action-test` | effects in `SystemActionRunner` |
| `Core/VolumeLevel.swift` | `volume-test` | CoreAudio in `SystemActionRunner` |
| `Core/WindowManagement/{WindowCommand,WindowLayout,WindowActionMemory}` | `window-command-test` | + CoreGraphics; `now` a parameter |
| `Core/Uninstall/{Target,SearchRoot,Rules,Protection,Plan}` | `uninstall-test` | rules get **names**, classifier gets `PathFacts` |
| `Core/Quicklinks/{Quicklink,Destination,Store,Archive}` | `quicklink-test` | + SQLite3; home dir injected |
| `Core/HotKey/{DoubleTapModifier,DoubleTapDetector}` | `hotkey-test` | clock a parameter |
| `Core/Backup/{RaycastFormat,RaycastV1Decoder}` | `raycast-test` | + CommonCrypto, Carbon |
| `Core/Theme.swift`, `Core/CalloutPlacement.swift` | `callout-test` | — |

**Generated, never hand-edited:** `EmojiData.generated.swift` (`node Tools/gen-emoji.js`),
`CurrencyData.generated.swift` (`node Tools/gen-currencies.js`). The only hand-maintained currency data
is `CalcCurrency.contested`; don't add slang there — no source of truth, so it rots.

### Safety & permissions

- **Every networked feature ships off and is consent-gated.** Opt-in behind a Settings dialog naming the
  provider, cadence and what leaves the machine; the owning store re-checks consent at every entry point
  **including both sides of the `await`**. Consent flags live on the owning store, never in `AppSettings`.
  Fetch on a cacheless `.ephemeral` `URLSession`, never `URLSession.shared`. `CurrencyRateStore` is the
  reference — follow it. [calculator.md](docs/calculator.md)
- **Uninstall moves to the Trash and never deletes.** `trashItem` only; `removeItem` must never appear.
  FDA is **detected, never requested**; the TCC list is **measured, not assumed**; a locked candidate can
  never enter the checked set; Tinycast refuses to uninstall itself, compared against the *running*
  identity. [uninstall.md](docs/uninstall.md)
- **Snippets: channel-isolated, path-identified, off by default.** `StoredSnippet.ID` is the standardized
  source path; external rename is delete + create. The enable switch doubles as keyword-expansion
  consent, is excluded from backups, and is the **only** place Accessibility may be requested — never
  from startup, callbacks, watchers or health checks. [snippets.md](docs/snippets.md)
- **Focus restoration is load-bearing.** Paste targets the recorded `previousApp` and requires
  Accessibility. [palette.md](docs/palette.md)
- **Swift 6 language mode: data races are hard errors.** Almost everything `@MainActor`; cross-actor
  models `Sendable`; heavy/IO work off-main via `Task.detached`/`nonisolated`. House idioms:
  `NotificationToken` (RAII) for block observers, `isolated deinit` for SQLite teardown, decode raw
  Carbon/C pointers to plain values before crossing into actor code.

### Data & formats

- **Quicklinks are authored data; their store never deletes.** Database in **Application Support**, not
  Caches — a database that won't open is *reported, never discarded* (`ClipboardStore`'s
  delete-and-recreate is only sound because history is regenerable). `Quicklink.precedes` is the one
  display order. **One template engine**: quicklinks expand through `SnippetTemplateEngine`, which is
  what makes `| raw` mean something. [quicklinks.md](docs/quicklinks.md)
- **Clipboard writes stamp a private `internalType` marker** so the poller skips Tinycast's own writes.
  [clipboard.md](docs/clipboard.md)
- **Hotkeys:** `HotKeyBinding` is the one thing an action binds to, with two cases and two engines — a
  `.combo` is a Carbon registration, a `.doubleTap` is recognized by `DoubleTapMonitor` (Carbon cannot
  see a lone modifier). `DoubleTapMonitor` is listen-only, installs *only* while something is bound, and
  never prompts. Persisted under legacy `KeyboardShortcuts_<name>` keys; its `Codable` conformance is the
  compatibility seam. *(Both superseded by `docs/refactor/POLICY.md` during the refactor — see phase 35.)*
  [hotkeys.md](docs/hotkeys.md)
- **The two Raycast export formats share no mapper.** `RaycastFormat.detect` is the *only* branch; V1 and
  V2 own their own decrypt and field mapping and are never tried as a fallback for each other — that is
  what makes a wrong passphrase report a wrong passphrase. Never commit a real `.rayconfig` as a fixture.
  [raycast-import.md](docs/raycast-import.md)
- **`WindowLayout` works exclusively in AX space** (global, top-left origin, +Y down).
  `WindowMover.AXGeometry` is the only converter and anchors the flip on the **primary** display's
  height, never the window's own screen. Nothing here touches `backingScaleFactor`.
  [window-management.md](docs/window-management.md)

### UI — read [ui.md](docs/ui.md) before any restyle or new view

- **`Core/EdgeDissolve.swift` and `Core/ThinScrollbar.swift` are off-limits.** Tuned by eye; any edit is
  a visual regression. Needing to touch them means the real fix is elsewhere.
- **The app is locked to `.darkAqua`.** The Liquid Glass material is tuned for a dark surface — never add
  light-mode styling. `Core/Theme.swift` is the single design-token source.
- **Tinycast presents its own dialogs — never `NSAlert` / `NSSlider` / system popovers.** Everything goes
  through `DialogController` (owned by `AppCore`; reachable via `AppCore.showNotice` / `confirm`).
  Presentation is `async` — no nested run loop — and the presenter refuses a second dialog while one is
  up, which is what stops a held hotkey stacking dialogs. ↵ runs the primary action, Escape cancels,
  Cancel always renders leading.
- **A dialog has three independent axes; never let one infer another.** Icon = the *subject's* own glyph
  (tone never picks it) · tone tints only that glyph · button colour comes from `DialogAction.Role`.
  Resolve glyphs through `SymbolImage`, not `Image(systemName:)`.
- **A transient readout is a HUD, not a dialog.** `VolumeHUDController` for levels, `MessageHUDController`
  for everything else, both over `HUDPresenter`. A new HUD means a new presenter.
- **Glass is for controls; content takes the panel recipe** (`panelDimming` → `VisualEffectView` →
  `clipShape`). `glassEffect` needs a backdrop to lens; on a bare panel it falls back to an opaque
  backing and shows a dark edge.
- **While a footer menu is open the palette search field never resigns first responder** — input is
  frozen instead. [palette.md](docs/palette.md)

## Project Layout

- `Tinycast/Core/` — managers, stores, windows, AppKit glue (no view bodies beyond hosting).
  `Calculator/` and `Emoji/` are pure engines; `Snippets/` is a harness input in full and owns the
  template engine Quicklinks also uses; `WindowManagement/` and `Uninstall/` and `Quicklinks/` each split
  pure-decision files from their one effect file; `HotKey/` is the in-house hotkey stack;
  `Theme.swift` is the design-token source.
- `Tinycast/Features/` — SwiftUI views: `RootPaletteView`, plus a folder per feature and `Settings/`.
  Each `SettingsTab` maps to one `…SettingsView` built on the `SettingsPane` / `SettingsCard` scaffold;
  the four launcher-category panes are thin wrappers over the shared `LauncherItemsCard`.
- `Tinycast/App/` — `@main` app + delegate. `Tools/` — harnesses and generators.
- `.github/workflows/release.yml` — the entire release pipeline.
