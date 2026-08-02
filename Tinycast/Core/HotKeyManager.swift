import Foundation

/// Owns all global shortcut bindings: persistence, registration with the two engines (`HotKeyCenter` for combos, `DoubleTapMonitor` for double-tapped modifiers), conflict lookup, and dispatch.
@MainActor
final class HotKeyManager: ObservableObject {
    var onTogglePalette: (() -> Void)?
    var onToggleClipboard: (() -> Void)?
    var onToggleEmoji: (() -> Void)?
    var onRunCustomCommand: ((UUID) -> Void)?
    var onRunSystemAction: ((SystemAction.ID) -> Void)?
    var onRunWindowCommand: ((WindowCommand.ID) -> Void)?

    /// The recorder currently capturing keystrokes, or `nil`; keeping this as plain app state makes recorders glitch-free, and any active recorder pauses both engines so the shortcut being typed can't fire the binding it's replacing.
    @Published var recordingAction: HotKeyAction? {
        didSet {
            let recording = recordingAction != nil
            center.isPaused = recording
            doubleTapMonitor.isPaused = recording
        }
    }

    /// Read-only to callers, who observe its `status` to surface the Accessibility grant a double-tap binding needs.
    let doubleTapMonitor = DoubleTapMonitor()

    private let center = HotKeyCenter()
    private var doubleTaps: [DoubleTapModifier: HotKeyAction] = [:]
    private let boundKey = "boundAppBundleIDs"
    private let boundPaneKey = "boundPaneBundleIDs"
    private let boundCustomCommandKey = "boundCustomCommandIDs"

    func start(customCommandIDs: Set<UUID>) {
        let stale = Set(boundCustomCommandIDs).subtracting(customCommandIDs)
        for id in stale {
            UserDefaults.standard.removeObject(forKey: HotKeyAction.customCommand(id: id).defaultsKey)
        }
        persistBoundCustomCommandIDs(Set(boundCustomCommandIDs).intersection(customCommandIDs))

        // `register` no-ops on an unbound item, so the fixed catalogs need no index of their own.
        for action in candidateActions { register(action) }

        doubleTapMonitor.onDoubleTap = { [weak self] modifier in
            guard let self, let action = doubleTaps[modifier] else { return }
            perform(action)
        }
        doubleTapMonitor.start()
        syncDoubleTaps()
    }

    /// Bundle IDs that currently have a per-app hotkey — lets `start()` know which records to load and lets launcher rows show keycaps.
    var boundBundleIDs: [String] {
        UserDefaults.standard.stringArray(forKey: boundKey) ?? []
    }

    /// Settings-pane bundle IDs with a hotkey — same role as `boundBundleIDs`, own namespace.
    var boundPaneBundleIDs: [String] {
        UserDefaults.standard.stringArray(forKey: boundPaneKey) ?? []
    }

    /// Custom-command UUIDs with a binding, indexed separately so startup can re-register them.
    var boundCustomCommandIDs: [UUID] {
        (UserDefaults.standard.stringArray(forKey: boundCustomCommandKey) ?? [])
            .compactMap(UUID.init(uuidString:))
    }

    func binding(for action: HotKeyAction) -> HotKeyBinding? {
        // The stored value is a JSON *string* (a legacy package format); anything else reads as unbound.
        guard
            let json = UserDefaults.standard.string(forKey: action.defaultsKey),
            let data = json.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(HotKeyBinding.self, from: data)
    }

    /// Persists (or clears, when `nil`) the binding, swaps the live registration, and publishes so the launcher and recorders re-render.
    func setBinding(_ binding: HotKeyBinding?, for action: HotKeyAction) {
        objectWillChange.send()
        if let binding,
            let data = try? JSONEncoder().encode(binding),
            let json = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(json, forKey: action.defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: action.defaultsKey)
        }
        // Unregister unconditionally: the previous binding may have been a combo even when the new one isn't.
        center.unregister(id: action.defaultsKey)
        register(action)

        switch action {
        case .app(let bundleID):
            var set = Set(boundBundleIDs)
            if binding == nil { set.remove(bundleID) } else { set.insert(bundleID) }
            UserDefaults.standard.set(Array(set), forKey: boundKey)
        case .settingsPane(let bundleID):
            var set = Set(boundPaneBundleIDs)
            if binding == nil { set.remove(bundleID) } else { set.insert(bundleID) }
            UserDefaults.standard.set(Array(set), forKey: boundPaneKey)
        case .customCommand(let id):
            var set = Set(boundCustomCommandIDs)
            if binding == nil { set.remove(id) } else { set.insert(id) }
            persistBoundCustomCommandIDs(set)
        case .togglePalette, .toggleClipboard, .toggleEmoji, .systemAction, .windowCommand:
            break
        }
        syncDoubleTaps()
    }

    /// The display name of whatever else `binding` is bound to (or `nil` if free), driving the recorder's "Used by …" message. Comparing whole bindings means double-taps get conflict detection on the same terms as combos — two actions can never claim the same modifier.
    func conflictOwner(of binding: HotKeyBinding, excluding action: HotKeyAction) -> String? {
        for candidate in candidateActions
        where candidate != action && self.binding(for: candidate) == binding {
            return displayName(of: candidate)
        }
        return nil
    }

    /// Every action that could currently hold a binding: the three toggles, whatever the bound-ID indices name, and the two fixed catalogs.
    private var candidateActions: [HotKeyAction] {
        var actions: [HotKeyAction] = [.togglePalette, .toggleClipboard, .toggleEmoji]
        actions += boundBundleIDs.map { .app(bundleID: $0) }
        actions += boundPaneBundleIDs.map { .settingsPane(bundleID: $0) }
        actions += boundCustomCommandIDs.map { .customCommand(id: $0) }
        actions += SystemAction.ID.allCases.map { .systemAction(id: $0) }
        actions += WindowCommand.ID.allCases.map { .windowCommand(id: $0) }
        return actions
    }

    private func displayName(of action: HotKeyAction) -> String {
        switch action {
        case .togglePalette:
            return "App Launcher"
        case .toggleClipboard:
            return "Clipboard History"
        case .toggleEmoji:
            return "Emoji & Symbols"
        case .app(let bundleID):
            let apps = AppCore.shared.appIndex.apps
            return apps.first { $0.kind == .application && $0.bundleID == bundleID }?.name
                ?? bundleID
        case .settingsPane(let bundleID):
            let apps = AppCore.shared.appIndex.apps
            return apps.first { $0.kind == .systemSettings && $0.bundleID == bundleID }?.name
                ?? bundleID
        case .customCommand(let id):
            return AppCore.shared.customCommands.command(id: id)?.name ?? "Custom Command"
        case .systemAction(let id):
            return SystemActionCatalog.action(id: id).name
        case .windowCommand(let id):
            return WindowCommandCatalog.command(id: id)?.name ?? "Window Command"
        }
    }

    /// Hands a combo to Carbon; a double-tap needs no per-action registration — `syncDoubleTaps` rebuilds the whole modifier map instead.
    private func register(_ action: HotKeyAction) {
        guard let shortcut = binding(for: action)?.shortcut else { return }
        center.register(id: action.defaultsKey, shortcut: shortcut) { [weak self] in
            self?.perform(action)
        }
    }

    /// Rebuilt wholesale rather than patched, so the map can't drift from what's on disk. Conflict detection keeps it one action per modifier.
    private func syncDoubleTaps() {
        doubleTaps = [:]
        for action in candidateActions {
            guard let modifier = binding(for: action)?.doubleTapModifier else { continue }
            doubleTaps[modifier] = action
        }
        doubleTapMonitor.update(bound: Set(doubleTaps.keys))
    }

    private func perform(_ action: HotKeyAction) {
        switch action {
        case .togglePalette: onTogglePalette?()
        case .toggleClipboard: onToggleClipboard?()
        case .toggleEmoji: onToggleEmoji?()
        case .app(let bundleID): AppLauncher.toggle(bundleID: bundleID)
        case .settingsPane(let bundleID): AppLauncher.openSettingsPane(bundleID: bundleID)
        case .customCommand(let id): onRunCustomCommand?(id)
        case .systemAction(let id): onRunSystemAction?(id)
        case .windowCommand(let id): onRunWindowCommand?(id)
        }
    }

    private func persistBoundCustomCommandIDs(_ ids: Set<UUID>) {
        UserDefaults.standard.set(
            ids.map { $0.uuidString.lowercased() }.sorted(), forKey: boundCustomCommandKey)
    }
}
