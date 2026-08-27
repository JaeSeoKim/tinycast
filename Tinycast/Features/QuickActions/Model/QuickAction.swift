import Foundation

/// What a Quick Action does to the selected text. Adding a fifth is a case here plus its prompt in
/// `QuickActionPrompt` — the hotkey, the settings row and the panel all read this list.
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
        case .fixGrammar: return "textformat.abc.dottedunderline"
        case .rewrite: return "wand.and.sparkles"
        case .translate: return "translate"
        case .summarize: return "text.line.3.summary"
        }
    }

    /// Summarize answers a question about the text rather than restating it, so replacing the
    /// selection with the answer is a choice the reader makes in the panel, never the default.
    var alwaysPreviews: Bool { self == .summarize }

    /// Whether the result goes straight into the field when the reader has expressed no preference.
    /// Only grammar is safe unseen: it changes what was wrong, where a rewrite changes the voice.
    var replacesDirectlyByDefault: Bool { self == .fixGrammar }

    /// Showing what changed only reads when the output is the input, edited.
    var showsDiff: Bool { self == .fixGrammar || self == .rewrite }

    /// Apple's translator handles this one; the rest are prompts.
    var usesTranslationFramework: Bool { self == .translate }
}
