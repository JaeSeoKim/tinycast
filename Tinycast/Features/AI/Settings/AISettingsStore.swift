import Foundation
import Observation

@MainActor
@Observable
final class AISettingsStore {
    private let defaults: UserDefaults

    private(set) var connections: [AIConnection] {
        didSet { persistConnections() }
    }
    private(set) var defaultModel: AIModelSelection? {
        didSet { persistDefaultModel() }
    }
    /// Off by default: a prompt reaches a search engine only once the user has said so.
    var webSearchEnabled: Bool {
        didSet { defaults.set(webSearchEnabled, forKey: AppSettingsKey.aiWebSearch.rawValue) }
    }
    /// Appended to `AIInstructions.preamble` on every turn, so it is billed on every turn.
    var systemPrompt: String {
        didSet { defaults.set(systemPrompt, forKey: AppSettingsKey.aiSystemPrompt.rawValue) }
    }
    /// On by default: without it a model has no idea what app it is answering for.
    var systemPromptEnabled: Bool {
        didSet {
            defaults.set(systemPromptEnabled, forKey: AppSettingsKey.aiSystemPromptEnabled.rawValue)
        }
    }

    /// Asked each time, not captured: the model finishes downloading while the app is running, and
    /// a flag read once at launch would keep saying "not ready" for the rest of the session. It is
    /// injected because the check belongs to FoundationModels and this type is compiled standalone
    /// by `ai-provider-test` to prove it stays Foundation-only. Reading it inside a view body also
    /// leaves SwiftUI observing the framework's own `Observable` state, so the picker refreshes
    /// itself when the model lands.
    @ObservationIgnored let isAppleIntelligenceAvailable: @Sendable () -> Bool

    init(
        defaults: UserDefaults = .standard,
        isAppleIntelligenceAvailable: @escaping @Sendable () -> Bool = { false }
    ) {
        self.defaults = defaults
        self.isAppleIntelligenceAvailable = isAppleIntelligenceAvailable
        connections = Self.decodeConnections(
            defaults.data(forKey: AppSettingsKey.aiConnections.rawValue))
        defaultModel = Self.decodeDefaultModel(
            defaults.data(forKey: AppSettingsKey.aiDefaultModel.rawValue))
        webSearchEnabled =
            defaults.object(forKey: AppSettingsKey.aiWebSearch.rawValue) as? Bool ?? false
        systemPrompt = defaults.string(forKey: AppSettingsKey.aiSystemPrompt.rawValue) ?? ""
        systemPromptEnabled =
            defaults.object(forKey: AppSettingsKey.aiSystemPromptEnabled.rawValue) as? Bool ?? true
        if case .api(let connection, let model) = defaultModel,
            !connections.contains(where: { $0.id == connection && $0.models.contains(model) })
        {
            defaultModel = firstAvailableSelection()
        }
    }

    func connection(id: UUID) -> AIConnection? {
        connections.first { $0.id == id }
    }

    func select(_ selection: AIModelSelection) {
        if case .api(let connection, let model) = selection {
            guard self.connection(id: connection)?.models.contains(model) == true else { return }
        }
        defaultModel = selection
    }

    func save(_ connection: AIConnection) {
        let connection = normalized(connection)
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
        } else {
            connections.append(connection)
        }
        if case .api(connection.id, let model) = defaultModel,
            !connection.models.contains(model)
        {
            defaultModel = connection.models.first.map {
                .api(connection: connection.id, model: $0)
            }
        }
        if defaultModel == nil, let model = connection.models.first {
            defaultModel = .api(connection: connection.id, model: model)
        }
    }

    func removeConnection(id: UUID) {
        connections.removeAll { $0.id == id }
        guard case .api(id, _) = defaultModel else { return }
        defaultModel = firstAvailableSelection()
    }

    func reconcile(chatGPTModels models: [ChatGPTSubscription.Model], isSignedOut: Bool) {
        guard case .chatGPT(let model, let effort) = defaultModel else { return }
        if isSignedOut {
            defaultModel = firstAvailableSelection()
            return
        }
        guard !models.isEmpty else { return }
        if let match = models.first(where: { $0.id == model }) {
            let resolved = match.resolvedEffort(effort)
            if resolved != effort { defaultModel = .chatGPT(model: model, effort: resolved) }
            return
        }
        guard let replacement = models.first(where: \.isDefault) ?? models.first else { return }
        defaultModel = .chatGPT(
            model: replacement.id, effort: replacement.resolvedEffort(nil))
    }

    /// Nothing chosen yet takes the route that needs no account. Called from the chat screen and
    /// the AI pane, so whichever the reader opens first leaves a real selection behind rather than
    /// a hidden default — the routing decision stays the one persisted value that names it.
    func resolveDefaultModel() {
        guard defaultModel == nil, let selection = firstAvailableSelection() else { return }
        defaultModel = selection
    }

    /// Where a route that no longer exists falls forward to. The on-device model leads: it is free,
    /// private and always configured, so it is never the surprising place to land.
    private func firstAvailableSelection() -> AIModelSelection? {
        if isAppleIntelligenceAvailable() { return .appleIntelligence }
        for connection in connections {
            if let model = connection.models.first {
                return .api(connection: connection.id, model: model)
            }
        }
        return nil
    }

    private func persistConnections() {
        guard let data = try? JSONEncoder().encode(connections) else { return }
        defaults.set(data, forKey: AppSettingsKey.aiConnections.rawValue)
    }

    private func persistDefaultModel() {
        guard let defaultModel, let data = try? JSONEncoder().encode(defaultModel) else {
            defaults.removeObject(forKey: AppSettingsKey.aiDefaultModel.rawValue)
            return
        }
        defaults.set(data, forKey: AppSettingsKey.aiDefaultModel.rawValue)
    }

    private func normalized(_ connection: AIConnection) -> AIConnection {
        var connection = connection
        connection.name = connection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        connection.baseURL = connection.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        connection.models = connection.models.compactMap {
            let model = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !model.isEmpty, seen.insert(model).inserted else { return nil }
            return model
        }
        connection.visionModels = connection.visionModels.filter(seen.contains)
        return connection
    }

    private static func decodeConnections(_ data: Data?) -> [AIConnection] {
        guard let data,
            let connections = try? JSONDecoder().decode([AIConnection].self, from: data)
        else { return [] }
        return connections
    }

    private static func decodeDefaultModel(_ data: Data?) -> AIModelSelection? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(AIModelSelection.self, from: data)
    }
}
