import Foundation

/// How long saved conversations are kept. Days as the raw value, `forever` negative so an unset
/// key — `integer(forKey:)` answers 0 — matches no case and falls to the default.
enum AIRetention: Int, CaseIterable, Identifiable, Sendable {
    case week = 7
    case month = 30
    case threeMonths = 90
    case forever = -1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .week: return "7 Days"
        case .month: return "30 Days"
        case .threeMonths: return "3 Months"
        case .forever: return "Forever"
        }
    }

    var maxAge: TimeInterval {
        self == .forever ? .greatestFiniteMagnitude : TimeInterval(rawValue) * 86_400
    }

    /// The instant before which a conversation is too old to keep, or `nil` when nothing expires.
    func cutoff(from now: Date) -> Date? {
        self == .forever ? nil : now.addingTimeInterval(-maxAge)
    }
}
