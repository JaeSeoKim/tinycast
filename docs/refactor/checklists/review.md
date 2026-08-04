# Code review checklist

Read the diff properly before committing. Claude is fast and confident; neither is the same as correct.

Budget ~10 minutes for a small phase, ~25 for M3/M4.

---

## 1 · Scope — before reading a single line of code

```
git diff --stat
git diff --name-only
```

- [ ] Every changed file appears in the phase's **Expected files to modify**
- [ ] **No file from "Files that must NOT change" appears.** If one does: revert the whole phase. No
      discussion, no partial rescue.
- [ ] Total changed lines within ~2× the phase's **Expected commit size**
- [ ] No new file was created that the phase did not name
- [ ] No file was deleted that the phase did not authorise
- [ ] `Tinycast.xcodeproj` changed only if files were added, removed or moved

> Scope creep is the dominant failure mode, and it is fully visible in the file list. Catch it here and
> you save yourself reading 900 lines of unasked-for improvement.

---

## 2 · Behaviour preservation

Read the actual hunks. For each one ask: *does this change what the program does, or only how it is
arranged?*

- [ ] No condition added, removed or inverted
- [ ] No comparison operator changed
- [ ] No default value changed
- [ ] No `guard`/`else` branch dropped or merged
- [ ] No statement with side effects reordered relative to another
- [ ] No early return added or removed
- [ ] No `?`/`!`/`??` changed in a way that alters nil handling
- [ ] Every moved function is byte-identical to its original apart from indentation
- [ ] Every user-visible string is character-identical, including punctuation and curly quotes

**Any "yes" needs an explanation in Claude's summary.** If it is not in the summary, ask. Silent
behaviour changes are what this checklist exists to catch.

---

## 3 · Concurrency

- [ ] No `@MainActor` added or removed unless the phase asked for it
- [ ] No `nonisolated` added or removed unless the phase asked for it
- [ ] No new `MainActor.assumeIsolated` — it traps at runtime if the assumption is ever wrong
- [ ] No new `@unchecked Sendable` or `nonisolated(unsafe)`
- [ ] No `Task.detached` added where a structured child task would do
- [ ] Any new long-lived `Task` is stored and cancelled in `stop()` or `deinit`
- [ ] Any new `Timer` is invalidated on teardown
- [ ] Any new observer uses `NotificationToken`, not a bare `addObserver`
- [ ] No `DispatchQueue.main.async` added to paper over an ordering problem

---

## 4 · Memory and lifetime

- [ ] Every escaping closure capturing `self` uses `[weak self]` (the house idiom throughout)
- [ ] No new retain cycle: check every stored closure, delegate and callback property
- [ ] No new cache, and no existing cache ceiling raised
- [ ] Nothing newly retained for the process lifetime
- [ ] `NSImage`, `Data` and SQLite handles have the same lifetimes as before

---

## 5 · Comments — H-1 budget

```
git diff -U0 | grep -c '^+\s*//'          # comment lines added
git diff -U0 | grep -A1 '^+\s*//' | grep -c '^+\s*//'   # rough stacking signal
```

- [ ] **Zero** new stacked comment blocks (two consecutive `//` lines)
- [ ] No new comment exceeds 100 characters including indentation
- [ ] No comment explains "why I changed this" — the diff is not the audience
- [ ] Moved comments moved verbatim, not rewritten
- [ ] Net comment lines added is small, and ideally negative

---

## 6 · Dead code

- [ ] Nothing orphaned by the change was left behind: no unused function, property, type or import
- [ ] No compatibility shim, deprecated alias, or forwarding wrapper the phase did not ask for
- [ ] No commented-out old implementation
- [ ] No `TODO`, `FIXME` or `HACK` added

Confirm by searching for the old symbol name across the repo — the compiler will not always tell you.

---

## 7 · Project invariants

Spot-check the ones this phase's blast radius could reach:

- [ ] `AppCore` is still the sole owner of long-lived state; no competing singleton appeared
- [ ] `PaletteWindowController` still solely owns the palette frame; `sizingOptions = []` intact
- [ ] Flat `selection` index still matches visible row order, calculator card included
- [ ] `AppEntry.Kind` is still the only thing that says what an entry is — nothing sniffs an entry ID
- [ ] Pure-layer files gained no AppKit/SwiftUI import (see `checklists/testing.md`)
- [ ] Uninstall still uses `trashItem`; `removeItem` appears nowhere in that feature
- [ ] Consent flags still live on their owning store, not in `AppSettings`
- [ ] Hotkey persistence still uses the legacy `KeyboardShortcuts_<name>` keys
- [ ] Dialogs still go through `DialogController`; no `NSAlert` reintroduced
- [ ] `EdgeDissolve.swift` and `ThinScrollbar.swift` contents untouched

---

## 8 · The summary

- [ ] Claude produced the required summary format
- [ ] **Behaviour changes** says `NONE`, or lists only changes the phase authorised
- [ ] Every acceptance criterion is marked MET with something checkable behind it
- [ ] Build result is stated honestly — if it says PASS, you saw the build run
- [ ] Out-of-scope observations are recorded (copy them into the progress file's **Follow-up work**)

---

## Verdict

| Outcome | Action |
|---|---|
| All sections clean | Fill in the progress file, commit, merge, **stop for the day** |
| Small scoped fixes needed | Same conversation, one specific instruction each, re-review |
| Scope creep, or an untouchable file changed | `git reset --hard`, re-run with tightened constraints |
| Unexplained behaviour change | `git reset --hard`. Do not attempt to salvage. |
| Phase turned out to be mis-specified | Reset, mark **Blocked** in `ROADMAP.md`, write it up, re-plan the phase doc |
