import Foundation

/// Everything the classifier is allowed to know about one path, gathered by `UninstallScanner`.
/// Injecting the facts is what keeps the classifier pure and drivable from the harness.
struct PathFacts: Hashable, Sendable {
    let path: String
    var exists = true
    /// Never followed: a symlinked directory can point anywhere, so sizing through it could walk the
    /// whole disk and classifying it would read facts from outside the roots.
    var isSymbolicLink = false
    var volumeIsReadOnly = false
    /// `SF_RESTRICTED` / `SF_IMMUTABLE` — SIP.
    var isSystemRestricted = false
    /// `UF_IMMUTABLE` — Finder's "Locked" checkbox, which the user can clear themselves.
    var isUserImmutable = false
    var isOwnedByCurrentUser = true
    var parentIsWritable = true
}

/// Process-wide facts, probed once per scan rather than once per candidate.
struct UninstallEnvironment: Hashable, Sendable {
    let home: String
    let hasFullDiskAccess: Bool
}

/// Why a candidate can or can't be moved to the Trash.
///
/// Advisory, not a security boundary: TCC is evaluated at the syscall, so this can be wrong in both
/// directions. It exists to explain why a row is gray and to skip obviously doomed attempts —
/// `UninstallRunner` still reports per-item failure.
enum UninstallProtection: String, Hashable, Sendable, CaseIterable {
    case removable
    case systemProtected
    case userLocked
    case notOwned
    case needsFullDiskAccess
    case parentNotWritable
    case missing

    var isRemovable: Bool { self == .removable }

    /// Nil for exactly `.removable` — the harness asserts that, since the row's lock icon keys off it.
    var lockReason: String? {
        switch self {
        case .removable:
            return nil
        case .systemProtected:
            return "Part of macOS and protected by the system."
        case .userLocked:
            return "Locked in Finder. Unlock it in Get Info, then try again."
        case .notOwned:
            return "Owned by another user. Tinycast never asks for an administrator password."
        case .needsFullDiskAccess:
            return "Needs Full Disk Access, which Tinycast doesn’t request. "
                + "Grant it in System Settings › Privacy & Security to include this item."
        case .parentNotWritable:
            return "Its enclosing folder isn’t writable by you."
        case .missing:
            return "No longer on disk."
        }
    }
}

enum UninstallProtectionRules {
    /// Precedence matters and is asserted: a SIP file is also root-owned and often TCC-gated, and
    /// "part of macOS" is the more useful sentence than either of the others. This is the branch
    /// that locks `/System/Applications/Books.app`, and it falls out of the facts rather than a
    /// hardcoded `/System` prefix.
    static func classify(_ facts: PathFacts, environment: UninstallEnvironment) -> UninstallProtection
    {
        guard facts.exists else { return .missing }
        if facts.isSystemRestricted || facts.volumeIsReadOnly { return .systemProtected }
        if facts.isUserImmutable { return .userLocked }
        if !facts.isOwnedByCurrentUser { return .notOwned }
        if !environment.hasFullDiskAccess,
            isTCCProtected(path: facts.path, home: environment.home)
        {
            return .needsFullDiskAccess
        }
        // Trashing is a rename out of the enclosing directory, so that is the permission that decides it.
        if !facts.parentIsWritable { return .parentNotWritable }
        return .removable
    }

    /// Paths TCC gates for a non-sandboxed app without Full Disk Access. The list runs wider than
    /// the current search roots on purpose, so adding a root later can't silently start attempting
    /// reads macOS would deny.
    static func isTCCProtected(path: String, home: String) -> Bool {
        let relative = tccRelativePrefixes.contains { path.hasPrefix(home + "/" + $0) }
        return relative || path.hasPrefix("/Library/Application Support/com.apple.TCC")
    }

    static let tccRelativePrefixes: [String] = [
        "Library/Containers/",
        "Library/Group Containers/",
        "Library/Application Scripts/",
        "Library/Cookies/",
        "Library/Autosave Information/",
        "Library/Safari",
        "Library/Mail",
        "Library/Messages",
        "Library/Calendars",
        "Library/Suggestions",
        "Library/HomeKit",
        "Library/IdentityServices",
        "Library/Sharing",
        "Library/Biome",
        "Library/Trial",
        "Library/Metadata/CoreSpotlight",
        "Library/Application Support/AddressBook",
        "Library/Application Support/CallHistoryDB",
        "Library/Application Support/com.apple.TCC",
        "Library/Application Support/MobileSync"
    ]
}
