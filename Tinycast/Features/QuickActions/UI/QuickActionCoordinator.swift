import AppKit
import FoundationModels
import Observation

/// The single funnel for every Quick Action, however it was started. It resolves the target app,
/// reads the selection, runs the action, and either replaces the text or shows the panel.
@MainActor
@Observable
final class QuickActionCoordinator {
    private let settings: AppSettings
    private let store: QuickActionSettingsStore
    private let injector: TextInjector
    private let paletteCoordinator: PaletteCoordinator
    private let panels = QuickActionPanelController()
    private unowned let core: AppCore

    /// One at a time: two runs would race for the same selection, and the second would replace text
    /// the first had already changed.
    @ObservationIgnored private var running: Task<Void, Never>?

    init(
        settings: AppSettings, store: QuickActionSettingsStore, injector: TextInjector,
        paletteCoordinator: PaletteCoordinator, core: AppCore
    ) {
        self.settings = settings
        self.store = store
        self.injector = injector
        self.paletteCoordinator = paletteCoordinator
        self.core = core
    }

    /// Off means the hotkeys do nothing and nothing reads a selection. The bindings stay registered
    /// so re-enabling restores every shortcut without touching Carbon.
    func applyEnabled() {
        guard !settings.quickActionsEnabled else {
            store.resolveModel(
                appleIntelligenceAvailable: AppleIntelligenceProvider.status().isAvailable,
                fallback: core.aiSettings.defaultModel)
            loadLanguages()
            return
        }
        cancel()
    }

    /// The switch funnels here so enabling, which is also consent, confirms first. Reading a
    /// selection and typing over it is the whole feature, and both need Accessibility.
    func setEnabled(_ enabled: Bool) {
        guard enabled != settings.quickActionsEnabled else { return }
        guard enabled else {
            settings.quickActionsEnabled = false
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        Task {
            guard
                await core.confirm(
                    title: "Enable Quick Actions?",
                    message:
                        "Tinycast needs the Accessibility permission to read the text you have "
                        + "selected in other apps and replace it. Nothing is read until you press "
                        + "a shortcut.",
                    symbol: "wand.and.sparkles", confirmTitle: "Continue", tone: .neutral,
                    confirmRole: .standard)
            else { return }
            settings.quickActionsEnabled = true
            // The one prompt for this feature, raised from the gesture that asked for it.
            Permissions.ensureAccessibility()
        }
    }

    func run(_ action: QuickAction) {
        guard settings.quickActionsEnabled else { return }
        guard running == nil else { return }
        let target = paletteCoordinator.targetApp
        let selection: String
        do {
            selection = try QuickActionRunner.selection(in: target)
        } catch {
            core.showMessage(error.localizedDescription, tone: .danger)
            return
        }
        let state = QuickActionPanelState(
            action: action, original: selection, targetLanguage: targetLanguage)
        let previews = store.settings.previewsResult(action)
        if previews { present(state, target: target) }
        running = Task { [weak self] in
            await self?.perform(action, state: state, target: target, previewing: previews)
            self?.running = nil
        }
    }

    func cancel() {
        running?.cancel()
        running = nil
        panels.dismiss()
    }

    private func perform(
        _ action: QuickAction, state: QuickActionPanelState,
        target: NSRunningApplication?, previewing: Bool
    ) async {
        do {
            let text = try await produce(action, state: state, previewing: previewing)
            guard !Task.isCancelled else { return }
            state.finish(text)
            if previewing {
                panels.resizeToFit()
            } else {
                deliver(text, to: target, action: action)
            }
        } catch is CancellationError {
            return
        } catch let error as TextTranslator.Failure where error.needsDownload {
            // Only SwiftUI's `translationTask` can fetch a pair, so this has to become a panel.
            if !previewing { present(state, target: target) }
            state.requireLanguageDownload()
            panels.resizeToFit()
        } catch {
            report(error, state: state, previewing: previewing, target: target)
        }
    }

    private func produce(
        _ action: QuickAction, state: QuickActionPanelState, previewing: Bool
    ) async throws -> String {
        if action.usesTranslationFramework {
            return try await TextTranslator.translate(state.original, to: state.targetLanguage)
        }
        let provider = try core.quickActionProvider()
        return try await QuickActionRunner.run(
            action, selection: state.original, using: provider,
            onDelta: { [weak self] delta in
                guard previewing else { return }
                state.append(delta)
                self?.panels.resizeToFit()
            })
    }

    private func deliver(_ text: String, to target: NSRunningApplication?, action: QuickAction) {
        injector.replaceSelection(with: text, in: target) { [weak self] in
            self?.core.showMessage("\(action.title) applied")
        }
    }

    /// A failure the reader cannot see is a hotkey that silently did nothing, so a direct run
    /// reports through the HUD and a preview keeps the panel open saying why.
    private func report(
        _ error: Error, state: QuickActionPanelState, previewing: Bool,
        target: NSRunningApplication?
    ) {
        guard previewing else {
            core.showMessage(error.localizedDescription, tone: .danger)
            return
        }
        state.fail(error.localizedDescription)
        panels.resizeToFit()
    }

    private func present(_ state: QuickActionPanelState, target: NSRunningApplication?) {
        panels.present(
            state,
            languages: offeredLanguages,
            onRetranslate: { [weak self] language in
                guard let self else { return }
                state.targetLanguage = language
                state.restart()
                self.running?.cancel()
                self.running = Task { [weak self] in
                    await self?.perform(
                        state.action, state: state, target: target, previewing: true)
                    self?.running = nil
                }
            },
            onDownloaded: { [weak self] in
                guard let self else { return }
                state.restart()
                self.running?.cancel()
                self.running = Task { [weak self] in
                    await self?.perform(
                        state.action, state: state, target: target, previewing: true)
                    self?.running = nil
                }
            },
            onOutcome: { [weak self] outcome in
                guard let self, case .replace(let text) = outcome else { return }
                self.deliver(text, to: target, action: state.action)
            })
    }

    private var targetLanguage: Locale.Language {
        let stored = store.settings.targetLanguage
        guard !stored.isEmpty else { return Locale.current.language }
        return Locale.Language(identifier: stored)
    }

    /// Apple's own list, loaded once. Offering the reader's preferred languages instead would put a
    /// language the translator cannot reach in the menu, where it would only fail at press time.
    /// Observed, not ignored: it arrives after the pane has painted, and the picker has to notice.
    private(set) var offeredLanguages: [Locale.Language] = []

    func loadLanguages() {
        guard offeredLanguages.isEmpty else { return }
        Task { [weak self] in
            let languages = await TextTranslator.supportedLanguages()
            self?.offeredLanguages = languages
        }
    }
}

extension TextTranslator.Failure {
    var needsDownload: Bool {
        if case .notInstalled = self { return true }
        return false
    }
}
