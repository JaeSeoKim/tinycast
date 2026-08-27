import Foundation

/// Whether this Mac can run the on-device model, and what to tell the reader when it cannot.
/// The FoundationModels enum it mirrors lives in `Service/`, so this stays Foundation-only.
enum AppleIntelligenceStatus: Equatable, Sendable {
    case available
    case deviceNotEligible
    case notEnabled
    case modelNotReady

    var isAvailable: Bool { self == .available }

    /// `nil` while the model can run, so a caller can treat it as the whole failure condition.
    var message: String? {
        switch self {
        case .available:
            return nil
        case .deviceNotEligible:
            return "This Mac does not support Apple Intelligence."
        case .notEnabled:
            return "Turn on Apple Intelligence in System Settings to chat on device."
        case .modelNotReady:
            return "Apple Intelligence is still downloading its model. Try again shortly."
        }
    }
}

enum AppleIntelligence {
    /// What `AIModelSelection.model` reports for this route; it names no remote model, so the id is
    /// ours rather than a vendor's.
    static let modelID = "apple-intelligence"
    static let title = "Apple Intelligence"

    /// The on-device window holds the prompt and the reply together in a few thousand tokens, so
    /// history gets a fraction of what a cloud route sends and the reply is capped to leave room.
    static let contextBudget = 6_000
    static let maxOutputTokens = 1_024
}

/// FoundationModels streams the whole answer so far in every snapshot; every other transport — and
/// `AIStreamEvent.text` with it — speaks in deltas. This is the one place that difference lives.
struct AppleIntelligenceDelta {
    private var emitted = ""

    /// The part of `snapshot` not yet seen, or the whole of it when the model revised what it had
    /// already written rather than extending it.
    mutating func delta(from snapshot: String) -> String {
        defer { emitted = snapshot }
        guard snapshot.hasPrefix(emitted) else { return snapshot }
        return String(snapshot.dropFirst(emitted.count))
    }
}
