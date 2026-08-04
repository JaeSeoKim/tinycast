# Phase 05 kickoff — `AppPaths`

Read `docs/refactor/phases/05-app-paths.md` completely before editing. The boundaries section is the
whole phase.

## Task

Add `Tinycast/Core/AppPaths.swift` with `caches(bundleID:)` and `applicationSupport(bundleID:)`, and
adopt it in the **four** non-harness-compiled types.

## Hard gates

**Adopt in exactly these four:**
`CalculatorHistoryStore`, `FrequentEmojiStore`, `CurrencyRateStore`, `OnboardingState`.

**Do NOT touch these four — they are compiled standalone by `Tools/` harnesses and `AGENTS.md` says each
must depend on no other app source:**
`ClipboardStore`, `QuicklinkStore`, `LauncherRankingStore`, `SnippetRepository`.

- **Every resolved path must stay byte-identical** — same folder name, same file name, same
  `?? "com.tinycast.app"` fallback. A wrong path is invisible in review and silently loses the user's
  clipboard history.
- `AppPaths` creates the directory (`createDirectory(withIntermediateDirectories: true)`) exactly as the
  current call sites do.
- `AppPaths` is Foundation-only and depends on no other app type.
- **Do not add `AppPaths.swift` to any harness command line.** If you think you need to, stop and say
  so — that requires an `AGENTS.md` invariant change and it is not this phase.
- `docs/development.md`, `AGENTS.md` and `ci.yml` must not change.

## Verify before you summarise

```
xcodegen generate
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug CODE_SIGNING_ALLOWED=NO
git diff --name-only    # must NOT list ClipboardStore, QuicklinkStore, LauncherRankingStore, SnippetRepository
```

Run **all** harnesses from `docs/development.md`, unmodified.

## Summarise

Use the system-prompt format. **List every resolved path before and after, explicitly**, so the reviewer
can confirm they are identical without launching the app.
