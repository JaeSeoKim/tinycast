import Foundation

/// What an uninstall is aimed at: the app bundle plus the strings a leftover can be attributed to.
/// Foundation-only and pure so `Tools/uninstall-test.swift` can compile it standalone.
struct UninstallTarget: Hashable, Sendable {
    let bundleURL: URL
    let bundleID: String?
    let displayName: String
    /// `CFBundleName` when it differs from the display name — some apps name their support folder after it.
    let bundleName: String?
}

/// How a candidate was attributed to the target.
enum UninstallEvidence: String, Hashable, Sendable, CaseIterable {
    case bundle
    case bundleID
    case groupContainer
    case displayName
    case binSymlink

    /// Shown on the row so the weaker evidence is visible; proof-grade matches say nothing.
    var label: String? {
        switch self {
        case .displayName: return "matched by name"
        case .binSymlink: return "command-line tool"
        case .bundle, .bundleID, .groupContainer: return nil
        }
    }
}

/// The matching-ready form of a target. `make` is where every guard rail is applied, so `UninstallRules` is left with no judgement to exercise.
struct UninstallIdentity: Hashable, Sendable {
    /// Case-folded bundle ID, or nil when the target has none.
    let bundleID: String?
    /// A two-component ID like `com.adobe` names a vendor, not a product — prefix-matching it would sweep every app that vendor ships, so those get exact matches only.
    let allowsBundleIDPrefixMatch: Bool
    /// Every *other* installed app's folded bundle ID. A sibling shipping under a longer ID in the same namespace owns its own artifacts, which is what stops one release channel claiming another's data.
    let otherBundleIDs: Set<String>
    /// Case-folded names safe enough to claim a whole directory. Usually empty or a single entry.
    let names: [String]
    let bundleURL: URL

    /// Below this a name is too generic to attribute anything to — "Go", "1P". Three is the floor
    /// rather than four because real apps live there: Zed, IINA, Xee all name their support folders
    /// after themselves, and the exact-match, reserved-name and installed-app-collision guards below
    /// are what carry the safety, not the length.
    static let minimumNameLength = 3

    /// Standard Library subdirectories that belong to macOS rather than to any app, so an app sharing the name can never claim them.
    static let reservedNames: Set<String> = [
        "apple", "application support", "application scripts", "autosave information", "caches",
        "containers", "cookies", "crashreporter", "fonts", "frameworks", "group containers",
        "httpstorages", "keychains", "launchagents", "launchdaemons", "logs", "metadata",
        "mobilesync", "preferences", "privilegedhelpertools", "scripts", "services", "sync",
        "syncservices", "webkit"
    ]

    /// Nil refuses the whole uninstall: Tinycast can never plan its own removal, and a target with
    /// neither a usable bundle ID nor a safe name has nothing to attribute leftovers by.
    /// `ownBundleID` is the *running* identity, so the Dev channel refuses itself too.
    static func make(
        target: UninstallTarget, otherAppNames: [String], otherBundleIDs: [String] = [],
        ownBundleID: String?, ownBundleURL: URL
    ) -> UninstallIdentity? {
        if let ownBundleID, let bundleID = target.bundleID,
            folded(bundleID) == folded(ownBundleID)
        {
            return nil
        }
        if target.bundleURL.standardizedFileURL == ownBundleURL.standardizedFileURL { return nil }

        let bundleID = target.bundleID.map(folded).flatMap { $0.isEmpty ? nil : $0 }
        let names = safeNames(
            displayName: target.displayName, bundleName: target.bundleName,
            otherAppNames: otherAppNames)
        guard bundleID != nil || !names.isEmpty else { return nil }

        return UninstallIdentity(
            bundleID: bundleID,
            allowsBundleIDPrefixMatch: (bundleID?.split(separator: ".").count ?? 0) >= 3,
            otherBundleIDs: Set(otherBundleIDs.map(folded)).subtracting([bundleID].compactMap { $0 }),
            names: names,
            bundleURL: target.bundleURL.standardizedFileURL)
    }

    /// The four gates a display name has to clear before it may claim a directory: long enough, not
    /// a macOS-owned folder name, and unique among the installed apps — a second app called "Mail"
    /// is exactly what makes `~/Library/Application Support/Mail` unattributable.
    static func safeNames(
        displayName: String, bundleName: String?, otherAppNames: [String]
    ) -> [String] {
        let taken = Set(otherAppNames.map(folded))
        var result: [String] = []
        for candidate in [displayName, bundleName].compactMap({ $0 }) {
            let name = folded(candidate)
            guard name.count >= minimumNameLength, !reservedNames.contains(name),
                !taken.contains(name), !result.contains(name)
            else { continue }
            result.append(name)
        }
        return result
    }

    static func folded(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespaces)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
