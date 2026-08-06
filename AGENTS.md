## Project

Tinycast is a native macOS menu-bar launcher (a minimal Raycast): fuzzy app launcher, global and per-app
hotkeys, a text/image clipboard history, an inline calculator, snippets, quicklinks, window management and
an emoji picker. SwiftUI + AppKit, running as an accessory with no Dock icon (`LSUIElement`). Targets
**macOS 26+** (Liquid Glass) and builds with the **Xcode 26** toolchain in **Swift 6 language mode**.

- **Build:** XcodeGen owns the project — `Tinycast.xcodeproj` is committed but generated from
  `project.yml`. After editing `project.yml`, run `xcodegen generate` and commit. There is **no**
  `Package.swift` / SwiftPM, and never use `Bundle.module`.
- **Test:** `./Tools/run-tests.sh`. There is no XCTest target; each harness compiles the shipped sources
  it guards, so a harness that stops *compiling* is as real a failure as one that asserts.
- **Channels:** Debug builds are their own channel — `Tinycast Dev.app` / `com.tinycast.app.dev` — so a
  local run never shares prefs, caches, TCC grants or login item with an installed stable/beta. Anything
  newly persisted must stay keyed by `Bundle.main.bundleIdentifier`.

## Where things are

```
Tinycast/App/          @main, AppDelegate, AppCore — the composition root
Tinycast/DesignSystem/ shared visual primitives; Theme.swift is the only design-token source
Tinycast/Platform/     system shims: Permissions, AppPaths, Signposts, NotificationToken, …
Tinycast/Palette/      the palette shell: panel, window controller, RootPaletteView, PaletteScreen
Tinycast/Windows/      the non-palette AppKit surfaces: Dialog/, HUD/, About/, AuxWindowController
Tinycast/Features/     one folder per feature; larger ones split Model/ Service/ UI/ Settings/
Tools/                 the harnesses, run-tests.sh, and the two data generators
```

| Read this | For |
| --- | --- |
| [docs/architecture.md](docs/architecture.md) | the layers, who owns what, windows, Observation, the full tree |
| [docs/standards.md](docs/standards.md) | naming, style, concurrency, performance budgets, comments |
| [docs/decisions.md](docs/decisions.md) | why something odd-looking is deliberate — check before "fixing" it |
| [docs/testing.md](docs/testing.md) | what to run, the purity checks, the manual sweep |
| [docs/development.md](docs/development.md) | build, dev channel, generated data, packaging, release |
| [docs/ui.md](docs/ui.md) | the design system — **read before any new view or restyle** |
| [docs/features/](docs/features/) | one doc per feature, each opening with that feature's invariants |

## Non-negotiables

Never break these without an explicit task to do so. Anything feature-specific lives in that feature's
doc, which opens with its own `## Invariants`.

- **`AppCore` is the sole owner.** New long-lived state goes on `AppCore`, wired in `start()`; don't
  create a competing singleton or wire managers elsewhere. Views call a feature's **coordinator** via
  `@Environment`, not `AppCore`.
- **A file under `Features/*/Model/` may not import AppKit or SwiftUI**, and takes every environment fact
  (clock, filesystem, home directory, rates) as an injected parameter. This is what the harnesses check.
- **The app is locked to `.darkAqua` globally.** The Liquid Glass material is tuned for a dark surface
  only; do not add light-mode styling.
- **`AppEntry.Kind` is the only thing that says what an entry is.** One case per launcher section, per
  `VisibilityStore` category and per Settings pane — never re-derive a category by sniffing an entry ID.
- **Every networked feature ships off and is consent-gated.** The dialog names the provider, the cadence
  and what leaves the machine; the owning store re-checks consent at every entry point, including both
  sides of the `await`. Consent flags live on that store, **never** in `AppSettings`. Fetch on a private
  cacheless `URLSession` (`.ephemeral`, `urlCache = nil`). `CurrencyRateStore` is the reference — follow
  it rather than inventing a second shape.
- **`snippetsEnabled` is excluded from settings backups**, and that exclusion is a security control: the
  switch doubles as consent to keystroke listening, so an import must not be able to grant it.
- **Swift 6 language mode: data-race violations are hard errors.** Almost everything is `@MainActor`;
  cross-actor model types are `Sendable`; heavy/IO work goes off-main via `Task.detached` / `nonisolated`.
  Keep that boundary, and don't add a second actor.
- **Tinycast presents its own dialogs, never `NSAlert` / `NSSlider` / system popovers.** Everything goes
  through `DialogController` (a question) or a HUD via `HUDPresenter` (a report).
- **Generated files are never hand-edited.** `EmojiData.generated.swift` comes from
  `node Tools/gen-emoji.js`, `CurrencyData.generated.swift` from `node Tools/gen-currencies.js`.
- **`DesignSystem/Scrolling/EdgeDissolve.swift` and `ThinScrollbar.swift` are off-limits.** Both are tuned
  by eye against the palette's floating bars, so any edit is a visual regression. Needing to touch one to
  fix a scroll bug means the real fix belongs elsewhere.

## Naming

A type's suffix says what it *is*. **Semantic correctness comes first** — pick the suffix that names the
responsibility honestly, and add one when none fits. Full table and reasoning in
[standards.md](docs/standards.md#naming).

`Store` (persisted state) · `Repository` (conflict-detecting file semantics) · `Coordinator` (a feature's
action surface) · `Controller` (one AppKit window) · `Presenter` (presentation policy) · `Manager`
(lifecycle *and* policy, started from `AppCore.start()`) · `Service` / `Provider` · `Monitor` (watches a
stream, owns no policy) · `Scanner` · `Runner` · `Launcher` (an `NSWorkspace.open` wrapper) · `Center`
(Carbon registration) · `Session` (one in-progress interaction) · `State` (shared, persists nothing) ·
`Catalog` (static table) · `Index` (searchable, rebuilt) · `Engine` (pure evaluator) · `Policy` (pure
decision).

`Manager` means lifecycle *plus* policy, which is a lot for one type — there are two (`ClipboardManager`,
`HotKeyManager`) and a third is fine if it genuinely owns both halves, but check whether `Store`,
`Monitor` or `Coordinator` fits better first. `Registry` and `ViewModel` are retired. One top-level type
per file, named for it. SwiftUI-layer names (`View`, `Screen`, `Card`, `Row`, `Sheet`) are a separate
vocabulary.

## Comments

Minimal code, not annotated prose.

1. **One line.** Never two consecutive comment lines — `///` included. If it needs two, it needs a named
   function, a named constant, or a type.
2. **Hard cap 100 characters**, including indentation. Longer belongs in a doc under `docs/`.
3. Comment the *why*, the gotcha, or the invariant. Never restate the code, never narrate a sequence,
   never argue a decision at length in-line — that is what `docs/decisions.md` is for.
4. **Prefer deleting a comment to updating it.**
5. Never add a comment explaining a change you just made. The diff is not the audience.

Rules 1 and 2 are checkable, and both must return `0`:

```sh
find Tinycast -name "*.swift" ! -name "*.generated.swift" -exec \
  awk '/^[[:space:]]*\/\//{r++; if(r==2) b++; next} {r=0} END{print b+0}' {} \; | awk '{s+=$1} END {print s}'
grep -rhE '^\s*(//|///)' Tinycast --include="*.swift" \
  --exclude="*.generated.swift" --exclude=EdgeDissolve.swift --exclude=ThinScrollbar.swift \
  | awk 'length>100' | wc -l
```

## Before you finish

- `./Tools/run-tests.sh` passes.
- The Debug build compiles with **no new warnings**.
- Both comment-budget commands return `0`.
- `grep -rln 'import AppKit\|import SwiftUI\|import Cocoa' Tinycast/Features/*/Model/` returns nothing.
- Any doc your change made wrong is fixed in the same commit.
