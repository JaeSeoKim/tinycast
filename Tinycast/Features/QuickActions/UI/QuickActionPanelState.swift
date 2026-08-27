import Foundation
import Observation

/// What the result panel is showing. Owned by its controller, not the view, so a reply keeps
/// arriving while SwiftUI re-renders around it.
@MainActor
@Observable
final class QuickActionPanelState {
    enum Phase: Equatable {
        case running
        case finished
        case failed(String)
        /// The pair is supported but not downloaded; only SwiftUI's `translationTask` can fetch it.
        case needsLanguageDownload
    }

    let action: QuickAction
    let original: String
    private(set) var output = ""
    private(set) var phase: Phase = .running
    /// The language the panel is translating into; a switcher rewrites it and re-runs.
    var targetLanguage: Locale.Language

    /// Shown instead of the plain output when the result is the input, edited.
    var diff: [TextDiffEngine.Chunk] {
        guard action.showsDiff, phase == .finished else { return [] }
        return TextDiffEngine.diff(original: original, modified: output)
    }

    var isRunning: Bool { phase == .running }

    var canReplace: Bool { phase == .finished && !output.isEmpty }

    init(action: QuickAction, original: String, targetLanguage: Locale.Language) {
        self.action = action
        self.original = original
        self.targetLanguage = targetLanguage
    }

    func append(_ delta: String) {
        output += delta
    }

    func restart() {
        output = ""
        phase = .running
    }

    func finish(_ text: String) {
        output = text
        phase = .finished
    }

    func fail(_ message: String) {
        phase = .failed(message)
    }

    func requireLanguageDownload() {
        phase = .needsLanguageDownload
    }
}
