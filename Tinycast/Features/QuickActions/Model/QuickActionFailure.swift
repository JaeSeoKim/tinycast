import Foundation

/// One case per cause: folded into a single "nothing selected", a stale Accessibility grant told
/// the reader to select text they had already selected.
enum QuickActionFailure: LocalizedError, Equatable {
    case needsAccessibility
    case noTarget
    /// The app answered, but exposes no focused text element — Chromium before its tree is built,
    /// or a surface that simply is not text.
    case unreadableApp(String)
    case noSelection
    case tooLong

    var errorDescription: String? {
        switch self {
        case .needsAccessibility:
            return "Tinycast needs the Accessibility permission to read the selected text."
        case .noTarget:
            return "Select text in another app first."
        case .unreadableApp(let name):
            return "\(name) doesn't share its text with Tinycast."
        case .noSelection:
            return "Select some text first."
        case .tooLong:
            return "That selection is too long to work on."
        }
    }

    /// The only failure with somewhere to send the reader, and so the only one worth a dialog.
    var opensAccessibilitySettings: Bool { self == .needsAccessibility }
}
