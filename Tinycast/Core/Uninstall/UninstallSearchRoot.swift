import Foundation

/// One directory the uninstaller looks in, and the match styles allowed there. A table rather than
/// per-root code: branching per directory is how a matcher grows unreviewable special cases.
struct UninstallSearchRoot: Hashable, Sendable {
    enum Base: Hashable, Sendable {
        case userLibrary
        case systemLibrary
    }

    enum MatchStyle: String, Hashable, Sendable, CaseIterable {
        case bundleID
        case groupContainer
        case displayName
    }

    let base: Base
    /// Relative to `base`, never empty.
    let relativePath: String
    let styles: Set<MatchStyle>

    func path(home: String) -> String {
        switch base {
        case .userLibrary: return home + "/Library/" + relativePath
        case .systemLibrary: return "/Library/" + relativePath
        }
    }

    /// Only immediate children are ever listed. `Preferences/ByHost` is its own root instead of
    /// raising `Preferences` to depth 2, which would descend into every unrelated app's subfolder.
    ///
    /// Display-name matching is enabled only where a child is a human-named folder. In Preferences,
    /// Containers, Group Containers, Saved Application State and the launch directories a child is a
    /// bundle ID by construction, so a name match there would be a false positive by definition.
    ///
    /// The home directory itself is **not** a root, deliberately. Claiming `~/<name>` needs a name
    /// match, and that is the one place a wrong match costs the user their own work rather than an
    /// app's cache — VS Code's `CFBundleName` is literally "Code", and `~/Code` is a source tree on
    /// a great many machines. Restricting it to dot-folders only moves the problem: an app named
    /// "Local" would claim `~/.local`, and screening that needs a hand-kept blocklist with no source
    /// of truth, which rots. Measured against 62 installed apps the whole root was worth one 115 kB
    /// folder, so it buys almost nothing and carries the only catastrophic failure mode.
    ///
    /// Deliberately absent: `/private/var/db/receipts` (root-owned, and deleting a receipt corrupts
    /// the installer's view of the system), `~/Library/Keychains` (credentials in shared files),
    /// `/Library/Extensions` and `/usr/local` (shared between products), and every user-document
    /// location — the user's own data is never ours to reap.
    static let all: [UninstallSearchRoot] = [
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "Application Support",
            styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "Caches", styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "Logs", styles: [.bundleID, .displayName]),
        UninstallSearchRoot(base: .userLibrary, relativePath: "Containers", styles: [.bundleID]),
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "Group Containers", styles: [.groupContainer]),
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "Application Scripts",
            styles: [.bundleID, .groupContainer]),
        UninstallSearchRoot(base: .userLibrary, relativePath: "Preferences", styles: [.bundleID]),
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "Preferences/ByHost", styles: [.bundleID]),
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "Saved Application State", styles: [.bundleID]),
        UninstallSearchRoot(base: .userLibrary, relativePath: "HTTPStorages", styles: [.bundleID]),
        UninstallSearchRoot(base: .userLibrary, relativePath: "WebKit", styles: [.bundleID]),
        UninstallSearchRoot(base: .userLibrary, relativePath: "Cookies", styles: [.bundleID]),
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "Autosave Information", styles: [.bundleID]),
        UninstallSearchRoot(base: .userLibrary, relativePath: "LaunchAgents", styles: [.bundleID]),
        // Plug-in wells. A child here is a wrapper named after the product that installed it, so
        // both styles apply once `strippedExtensions` has taken the `.qlgenerator`/`.saver`/… off.
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "Internet Plug-Ins", styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "QuickLook", styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "Services", styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "PreferencePanes", styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "Screen Savers", styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "Spotlight", styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "Automator", styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "Input Methods", styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "Audio/Plug-Ins/HAL", styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .userLibrary, relativePath: "Audio/Plug-Ins/Components",
            styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .systemLibrary, relativePath: "Application Support",
            styles: [.bundleID, .displayName]),
        UninstallSearchRoot(base: .systemLibrary, relativePath: "Caches", styles: [.bundleID]),
        UninstallSearchRoot(base: .systemLibrary, relativePath: "Logs", styles: [.bundleID]),
        UninstallSearchRoot(base: .systemLibrary, relativePath: "Preferences", styles: [.bundleID]),
        UninstallSearchRoot(base: .systemLibrary, relativePath: "LaunchAgents", styles: [.bundleID]),
        UninstallSearchRoot(
            base: .systemLibrary, relativePath: "LaunchDaemons", styles: [.bundleID]),
        UninstallSearchRoot(
            base: .systemLibrary, relativePath: "PrivilegedHelperTools", styles: [.bundleID]),
        UninstallSearchRoot(
            base: .systemLibrary, relativePath: "Internet Plug-Ins",
            styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .systemLibrary, relativePath: "QuickLook", styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .systemLibrary, relativePath: "PreferencePanes", styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .systemLibrary, relativePath: "Screen Savers", styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .systemLibrary, relativePath: "Audio/Plug-Ins/HAL",
            styles: [.bundleID, .displayName]),
        UninstallSearchRoot(
            base: .systemLibrary, relativePath: "Audio/Plug-Ins/Components",
            styles: [.bundleID, .displayName])
    ]

    /// Where a CLI launcher lands. Scanned by link target rather than by name — see
    /// `UninstallRules.isBundleSymlink` — so nothing here is matched by what the vendor called it.
    static let binDirectories: [String] = [
        "/usr/local/bin", "/opt/homebrew/bin", "~/.local/bin", "~/bin"
    ]
}
