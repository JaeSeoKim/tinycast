# Phase 05 — `AppPaths`, one channel-directory helper

**Milestone:** M1 · **Effort:** S · **Risk:** Med · **Context:** Low

---

## Overview

Eight types independently compute their own per-channel storage directory with the same five lines and
the same `?? "com.tinycast.app"` fallback. Replace them with one helper. **Every resolved path must stay
byte-identical.**

## Why this phase exists

Channel isolation is a named invariant: *"Anything newly persisted must stay keyed by
`Bundle.main.bundleIdentifier`"* — so a Dev build never shares prefs, caches or TCC grants with an
installed stable. Eight copies means eight chances for the ninth store to forget, and no single place to
audit.

## Architecture Review reference

**M-5**

## Objectives

1. Add `Tinycast/Core/AppPaths.swift`: `caches(bundleID:)` and `applicationSupport(bundleID:)`, both
   defaulting to `Bundle.main.bundleIdentifier ?? "com.tinycast.app"`.
2. Adopt it in all eight call sites.
3. Change no resolved path.

## Expected files to modify

| File | Current directory |
|---|---|
| `Tinycast/Core/AppPaths.swift` | **New.** ~25 lines. |
| `Tinycast/Core/ClipboardStore.swift` | Caches |
| `Tinycast/Core/LauncherRankingStore.swift` | Caches |
| `Tinycast/Core/CalculatorHistoryStore.swift` | Caches |
| `Tinycast/Core/Emoji/FrequentEmojiStore.swift` | Caches |
| `Tinycast/Core/CurrencyRateStore.swift` | Caches |
| `Tinycast/Core/Quicklinks/QuicklinkStore.swift` | Application Support |
| `Tinycast/Core/OnboardingState.swift` | Application Support |
| `Tinycast/Core/Snippets/SnippetRepository.swift` | Application Support |

## Files that must NOT change

- `Tools/*.swift` — no harness may need editing. If one does, **stop**: see the boundary below.
- `docs/development.md`, `AGENTS.md` harness command lines
- Any view file

## Implementation boundaries

**The harness constraint is the whole difficulty of this phase.**

`ClipboardStore`, `QuicklinkStore`, `LauncherRankingStore` and everything in `Core/Snippets/` are
compiled standalone by `Tools/` harnesses. `AGENTS.md` says each must depend on **no other app source**.

Therefore:

- **`AppPaths` supplies the default argument only.** Each store keeps its existing injectable parameter
  (`directory:`, `fileURL:`, `applicationSupportRoot:`) and keeps its own inline fallback computation.
  Adopt `AppPaths` **only** in the non-harness-compiled types.
- Concretely: adopt in `CalculatorHistoryStore`, `FrequentEmojiStore`, `CurrencyRateStore`,
  `OnboardingState`. **Leave `ClipboardStore`, `QuicklinkStore`, `LauncherRankingStore` and
  `SnippetRepository` alone** — their injection point already serves the same purpose and touching them
  breaks four harnesses.
- If Claude proposes adding `AppPaths.swift` to a harness command line, **reject it**. That is a separate
  decision requiring an `AGENTS.md` invariant change, and it is not this phase.
- `AppPaths` creates the directory (`createDirectory(withIntermediateDirectories: true)`) exactly as the
  current call sites do — do not move that responsibility.
- No path string changes. Not the folder name, not the file name, not the fallback bundle ID.

## Detailed acceptance criteria

1. `AppPaths.swift` exists, is Foundation-only, and has no dependency on any other app type.
2. Adopted in exactly the four non-harness types listed above.
3. The four harness-compiled types are **untouched**.
4. Every resolved path is byte-identical. Verified by logging each store's resolved URL once at launch
   before and after, and diffing.
5. All 17 harnesses pass with **no command-line change**.
6. `AGENTS.md` and `docs/development.md` unchanged.

## Manual verification checklist

- [ ] `checklists/build.md`
- [ ] `checklists/testing.md` — **all 17 harnesses**, no command-line edits
- [ ] `checklists/regression.md` — Core sweep + **Data safety** section in full
- [ ] Before the phase, note `ls -la ~/Library/Caches/com.tinycast.app.dev/` and
      `~/Library/Application Support/com.tinycast.app.dev/`
- [ ] After the phase, same listing — identical file names, no new directory
- [ ] Clipboard history still populated
- [ ] Calculator history still populated
- [ ] Frequently-used emoji section still populated
- [ ] Onboarding does **not** re-run (the marker file was found)
- [ ] Currency rates cache still present if the feature was on

## Regression risks

| Risk | Mitigation |
|---|---|
| **A store silently re-roots and looks empty.** The worst outcome in M1. | AC4 path diff; the Data safety checklist section |
| A harness breaks because a pure file gained a dependency | AC3 + AC5; the boundary forbids touching those four |
| The fallback bundle ID changes and Dev/stable share a directory | AC4 — the fallback string is part of the path |
| `createDirectory` moves and a first-run store fails to write | AC1 keeps creation inside `AppPaths` |

## Rollback strategy

`git revert <sha>`.

**Data risk on revert: none, provided AC4 held.** If a path *did* change and data was written to the new
location, a revert orphans it — which is why AC4 is verified by diffing resolved paths rather than by
inspection. If you discover a path changed after merging, do not revert blindly: move the data back
first.

## Expected commit size

5 files, +35 / −25 lines.

## Suggested commit message

```
Add AppPaths for the per-channel storage directories

Four stores computed the same caches/app-support path with the same
bundle-id fallback. One helper, one place to audit the channel-isolation
invariant. The harness-compiled stores keep their injected directory
parameter and are untouched. Resolved paths unchanged.
```

## Dependencies

Phase 01.

## Definition of Done

- All acceptance criteria met
- Path-identity diff captured in the progress file
- All 17 harnesses green with unmodified command lines
- Merged

## Estimated difficulty

**Low–Medium.** The code is trivial; knowing which four types *not* to touch is the phase.

## Estimated Claude context usage

**Low.**

## Notes for reviewers

- **First thing to check:** did the diff touch `ClipboardStore`, `QuicklinkStore`,
  `LauncherRankingStore` or `SnippetRepository`? If yes, revert immediately — four harnesses are at
  stake and the phase explicitly excluded them.
- **Second:** did any harness command line change in `docs/development.md`, `AGENTS.md` or `ci.yml`? If
  yes, revert. That is a different, larger decision.
- The path-identity check is not optional theatre. A wrong path is invisible in review and catastrophic
  in use — the user simply loses their clipboard history with no error.
