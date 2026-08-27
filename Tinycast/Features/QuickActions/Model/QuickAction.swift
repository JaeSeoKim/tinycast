import Foundation

/// What a Quick Action does to the selected text; a fifth is one case here plus its prompt.
enum QuickAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case fixGrammar
    case rewrite
    case translate
    case summarize

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixGrammar: return "Fix Grammar"
        case .rewrite: return "Rewrite"
        case .translate: return "Translate"
        case .summarize: return "Summarize"
        }
    }

    var symbol: String {
        switch self {
        case .fixGrammar: return "textformat"
        case .rewrite: return "wand.and.sparkles"
        case .translate: return "translate"
        case .summarize: return "text.line.3.summary"
        }
    }

    /// Summarize answers a question about the text, so replacing it unasked would destroy it.
    var alwaysPreviews: Bool { self == .summarize }

    /// Only grammar is safe unseen: it fixes what was wrong, where a rewrite changes the voice.
    var replacesDirectlyByDefault: Bool { self == .fixGrammar }

    var showsDiff: Bool { self == .fixGrammar || self == .rewrite }

    var usesTranslationFramework: Bool { self == .translate }
}
