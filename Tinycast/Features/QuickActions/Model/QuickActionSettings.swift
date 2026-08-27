import Foundation

/// The per-action and shared choices behind Quick Actions, held as plain values so this stays
/// Foundation-only and the harness compiles it standalone.
struct QuickActionSettings: Equatable, Sendable {
    /// Only what the reader actually chose. An absent action takes its own default, so adding one
    /// never depends on what a missing key would have meant — and changing a default later moves
    /// only the readers who never expressed a preference.
    var previewChoices: [QuickAction: Bool] = [:]

    /// BCP-47, e.g. `es-419`. Empty means the Mac's own language.
    var targetLanguage: String = ""

    func previewsResult(_ action: QuickAction) -> Bool {
        if action.alwaysPreviews { return true }
        return previewChoices[action] ?? !action.replacesDirectlyByDefault
    }

    mutating func setPreviewsResult(_ previews: Bool, for action: QuickAction) {
        guard !action.alwaysPreviews else { return }
        previewChoices[action] = previews
    }

    /// Round-trips through `UserDefaults`; an unknown key is an action that no longer exists.
    var storedPreviewChoices: [String: Bool] {
        get { Dictionary(uniqueKeysWithValues: previewChoices.map { ($0.rawValue, $1) }) }
        set {
            previewChoices = Dictionary(
                uniqueKeysWithValues: newValue.compactMap { key, value in
                    QuickAction(rawValue: key).map { ($0, value) }
                })
        }
    }
}
