# Quick Actions

Global shortcuts that act on whatever text is selected, in whatever app is frontmost. Four of them —
Fix Grammar, Rewrite, Translate and Summarize — each with its own bindable shortcut in
**Settings → Quick Actions**. Three go through the AI provider layer; Translate goes to Apple's own
translator. The result either replaces the selection or arrives in a floating panel, per action.

Quick Actions is the provider layer's second consumer. It shares nothing with AI Chat but the
provider protocol and the connections behind it.

## Invariants

- **Off out of the box, and off means the shortcuts do nothing.** `AppSettings.quickActionsEnabled`
  is the flag and `QuickActionCoordinator` is the only place that reads it: no selection is read, no
  provider is built, no panel opens. Carbon bindings stay registered, so re-enabling restores every
  shortcut without touching the hotkey layer. The flag grants keystroke delivery into other apps, so
  like `snippetsEnabled` it is excluded from settings backups — an import must never arm it.
- **Enabling is consent, and it is the only place Accessibility is requested.** The toggle confirms
  through `DialogController` first and then calls `Permissions.ensureAccessibility()`, the pattern
  `SnippetExpansionCoordinator.setSnippetsEnabled` established. Everything else — a shortcut press, a
  delivery — uses `isAccessibilityTrusted()` and degrades to a HUD.
- **Tinycast is never the target.** `QuickActionRunner.selection(in:)` refuses our own bundle
  identifier, and `TextInjector.targetAcceptsInjection` refuses it again before every event post,
  along with anything raised while Secure Event Input is up. A shortcut pressed with Settings
  frontmost, or in a password field, does nothing and says so.
- **One run at a time.** Two overlapping runs would race for one selection, and the second would
  replace text the first had already changed. `QuickActionCoordinator` holds a single task and
  refuses a second while it lives.
- **`Model/` stays Foundation-only.** `quick-action-test` compiles that folder standalone, which is
  what keeps `FoundationModels`, `Translation` and `NaturalLanguage` in `Service/` and `UI/`.
- **Quick Actions route themselves.** `quickActionModel` is a second routing decision, defaulting to
  Apple Intelligence and falling back to chat's model. A shortcut pressed all day should not bill an
  API every time, and that is not a choice chat's default can make on its behalf.
- **The reader's own text gets permissive guardrails.** `AppCore.quickActionProvider()` asks for
  `SystemLanguageModel.Guardrails.permissiveContentTransformations`. The default filter is tuned for
  a model writing fresh prose and refuses to transform text somebody already wrote, which is the
  whole feature.
- **The selection is untrusted input.** `QuickActionPrompt` tells every model that the text is
  material to work on and never instructions to follow, and that only the transformed text may come
  back — no preamble, no fences. The output is pasted into somebody's document.

## The actions

`QuickAction` is the whole extensibility story: a fifth action is one case there plus its prompt in
`QuickActionPrompt`. The shortcut, the settings row and the panel all read that list, and
`HotKeyAction.quickAction(QuickAction)` is parameterised so the hotkey enum never changes again.

| Action | Engine | Default result | Diff |
| --- | --- | --- | --- |
| Fix Grammar | provider | replaces directly | yes |
| Rewrite | provider | panel | yes |
| Translate | Apple Translation | panel | no |
| Summarize | provider | panel, always | no |

Only Fix Grammar applies unseen: it changes what was wrong, where a rewrite changes the voice.
Summarize can never be told to replace text unseen — it answers a question *about* the text, so
replacing the text with the answer has to be a choice made in the panel. Every other default is a
checkbox in the pane, and `QuickActionSettings` stores only what the reader actually changed, so a
new action arrives with its own default rather than whatever a missing key would have meant.

## Translation

`TextTranslator` uses Apple's translator rather than the language model: it runs on device, costs
nothing on every route, and a 3B model is markedly worse at it. `NLLanguageRecognizer` supplies the
source language, because `TranslationSession(installedSource:target:)` needs a concrete one and
`LanguageAvailability` reports only a status.

`TranslationError` is annotated `macOS 26.4` while the deployment floor is `26.0`, so failures are
caught as plain `Error` and reported by what was asked rather than by matching its cases.

**The picker offers Apple's own list, never the reader's preferred languages.** `supportedLanguages`
is 47 entries on macOS 26 and is the framework's to change; building the menu from
`Locale.preferredLanguages` instead would put a language the translator cannot reach in front of
someone, where it could only fail at press time. Notably **Bengali is not among the 47**. The list
loads asynchronously, so the coordinator holds it as observed state rather than a computed property.
Names come from `minimalIdentifier` — the maximal form carries the script, and `es` would read
"Spanish (Latin, Spain)" in a menu that should say "Spanish".

A pair that is supported but not downloaded **opens the panel**, whatever the action's usual result.
Fetching one needs SwiftUI's `translationTask`, and there is no other API for it — so the download
has a surface to live on rather than a shortcut that silently does nothing, and text is never
replaced once a download the reader never saw has finished.

## The panel

`QuickActionPanel` is Tinycast's **fourth borderless surface**, beside the dialog, the notes panel
and the join preview. It takes the same recipe — `panelScrim`, then `VisualEffectView`, then the
clip — and sits at `.floating` like the join preview, so a failure report still lands on top of it.
Its buttons are a deliberate copy of the dialog's rather than a share, for the reason
[ui.md](../ui.md) gives: a panel that had to move with `DialogButton` would couple two unrelated
surfaces.

It could not have been built on `HUDPresenter`: `HUDPanel` sets `ignoresMouseEvents` and returns
`false` from `canBecomeKey`, so it is click-through and hosts no buttons. Nor on `DialogAccessory`,
which is a closed two-case enum measured once at present time — a growing stream would clip.

Non-activating, so the target app keeps its selection while the panel holds key. Keys go through
`sendEvent`: `↵` replaces, `⌘C` copies, `esc` dismisses; click-away dismisses like every other
borderless surface. The panel is anchored by its **top-left** and re-measured as the reply arrives —
centring on every measure would walk it up the screen. `MarkdownView` and `MarkdownBlock.parse` are
reused from chat; neither takes palette state.

`TextDiffEngine` shows what changed when the output is the input, edited. Its LCS matrix is
quadratic, so past `maxTokens` a side it degrades to whole-text rather than asking for gigabytes.

## Delivery

`TextInjector` — shared with Snippets and Quicklinks, and owned by `AppCore` — does the replacement.
`replaceSelection(with:in:)` takes the interactive path: no keyword to match, no generation to
cancel, because a shortcut is an explicit gesture rather than an expansion the app decided to
attempt. Its serial delivery queue is what stops two features fighting over the pasteboard lease.

The Accessibility tier replaces the live selection atomically. The event tiers behind it type or
paste over it, which every app treats as replacing a selection — but that is the target app's
behaviour rather than something Tinycast asserts, so it is the part worth checking by hand.

### Manual sweep

- Select text in Safari, Chrome, Slack, Mail, Notes, VS Code and Terminal, press Fix Grammar, and
  confirm the selection is **replaced** rather than appended to.
- Press a shortcut with Tinycast's own Settings window frontmost: refused, with a HUD.
- Press one in a password field: refused.
- Summarize a long selection: the panel streams, grows without the title drifting, and scrolls past
  `quickActionPanelBody`.
- Translate into a language that has not been downloaded: the panel offers the download, then
  translates.
- Revoke Accessibility while enabled: a HUD explains instead of failing silently.
- Harness: `quick-action-test` (action metadata, prompt boundaries, preview choices, diffs).
