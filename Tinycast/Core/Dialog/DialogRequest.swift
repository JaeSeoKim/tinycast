import Foundation

/// One button on a dialog. The role decides the label's color and nothing else; a dialog's severity
/// lives in `DialogTone`, so a neutral dialog can still carry a destructive button and vice versa.
struct DialogAction {
    enum Role {
        case standard
        case destructive
        case cancel
    }

    let title: String
    var role: Role = .standard
}

/// How serious a dialog is. Tints the leading glyph and the pill HUD's status dot; it never picks an
/// icon — that always comes from the subject the dialog is about.
enum DialogTone: Sendable {
    case neutral
    case success
    case danger
}

struct DialogRequest {
    let title: String
    var message: String?
    /// The subject's own glyph: the command being confirmed, the thing that failed. Resolved through
    /// `SymbolImage`, so a bundled asset name works as well as an SF Symbol.
    let symbol: String
    var tone: DialogTone = .neutral
    var actions: [DialogAction]
    /// The button ↵ fires, normally the primary action.
    var defaultIndex: Int
    /// Resolved when the dialog goes away without a choice: Esc, or losing key status to a click elsewhere.
    var cancelIndex: Int
    /// Set only by the Set Volume prompt; the slider binds to it and the caller reads the result.
    var volume: VolumeState?
}
