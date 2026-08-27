import Foundation
import Observation

/// Quick Actions' own persisted state, kept apart from `AISettingsStore` because the feature is a
/// peer of chat rather than part of it — it has its own switch, its own route and its own pane.
@MainActor
@Observable
final class QuickActionSettingsStore {
    private let defaults: UserDefaults

    var settings: QuickActionSettings {
        didSet { persistSettings() }
    }
    /// Its own routing decision, defaulting to the on-device model. A grammar fix fires far more
    /// often than a chat turn does, and billing one per keystroke is not a default anyone chooses.
    private(set) var model: AIModelSelection? {
        didSet { persistModel() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var loaded = QuickActionSettings()
        loaded.storedPreviewChoices =
            defaults.dictionary(forKey: AppSettingsKey.quickActionPreviews.rawValue)
            as? [String: Bool] ?? [:]
        loaded.targetLanguage =
            defaults.string(forKey: AppSettingsKey.quickActionLanguage.rawValue) ?? ""
        settings = loaded
        model = Self.decodeModel(
            defaults.data(forKey: AppSettingsKey.quickActionModel.rawValue))
    }

    func select(_ selection: AIModelSelection?) {
        model = selection
    }

    /// Nothing chosen takes the route that needs no account, the way chat's own default resolves.
    func resolveModel(appleIntelligenceAvailable: Bool, fallback: AIModelSelection?) {
        guard model == nil else { return }
        model = appleIntelligenceAvailable ? .appleIntelligence : fallback
    }

    /// A connection the reader removed must not leave this pointing at a route that cannot answer.
    func repairModel(against connections: [AIConnection], fallback: AIModelSelection?) {
        guard case .api(let id, let name) = model,
            !connections.contains(where: { $0.id == id && $0.models.contains(name) })
        else { return }
        model = fallback
    }

    private func persistSettings() {
        defaults.set(
            settings.storedPreviewChoices, forKey: AppSettingsKey.quickActionPreviews.rawValue)
        defaults.set(settings.targetLanguage, forKey: AppSettingsKey.quickActionLanguage.rawValue)
    }

    private func persistModel() {
        guard let model, let data = try? JSONEncoder().encode(model) else {
            defaults.removeObject(forKey: AppSettingsKey.quickActionModel.rawValue)
            return
        }
        defaults.set(data, forKey: AppSettingsKey.quickActionModel.rawValue)
    }

    private static func decodeModel(_ data: Data?) -> AIModelSelection? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(AIModelSelection.self, from: data)
    }
}
