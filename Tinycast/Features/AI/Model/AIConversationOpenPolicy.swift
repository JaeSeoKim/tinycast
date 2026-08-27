import Foundation

/// What summoning AI Chat lands on. `newConversation` is the case that used to be implicit: Pop to
/// Root reset the transcript on every palette hide, so a chat never outlived the window.
enum AIOpensTo: Int, CaseIterable, Identifiable, Sendable {
    case recent = 0
    case newConversation = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .recent: return "Recent Conversation"
        case .newConversation: return "A New Conversation"
        }
    }
}

/// How long a conversation may sit idle and still be resumed. Minutes as the raw value, `never`
/// negative so it does not collide with the 0 an unset key reads as — the default is five minutes,
/// and a zero case would swallow it.
enum AINewChatAfter: Int, CaseIterable, Identifiable, Sendable {
    case twoMinutes = 2
    case fiveMinutes = 5
    case tenMinutes = 10
    case thirtyMinutes = 30
    case never = -1

    var id: Int { rawValue }

    var title: String {
        self == .never ? "Never" : "\(rawValue) Minutes"
    }

    var interval: TimeInterval { TimeInterval(rawValue) * 60 }
}

/// The single authority on whether opening chat resumes or starts fresh.
///
/// This used to be `PaletteWindowController`'s business: Pop to Root fired on every hide and ended
/// the conversation with the screen. Deciding here instead means one clock rather than two racing
/// over the same state, and a verdict read from a timestamp survives a relaunch — which a timer
/// scheduled at hide does not.
enum AIConversationOpenPolicy {
    enum Decision: Equatable, Sendable {
        case resume
        case startNew
    }

    /// `lastActiveAt` is nil when there is nothing to go back to, which is already a new chat.
    static func decide(
        opensTo: AIOpensTo, newAfter: AINewChatAfter, lastActiveAt: Date?, now: Date
    ) -> Decision {
        guard opensTo == .recent, let lastActiveAt else { return .startNew }
        guard newAfter != .never else { return .resume }
        // A clock that has gone backwards — a manual change, or NTP — must not strand the reader in
        // a conversation they cannot leave, so only elapsed time counts.
        let idle = now.timeIntervalSince(lastActiveAt)
        return idle >= newAfter.interval ? .startNew : .resume
    }
}
