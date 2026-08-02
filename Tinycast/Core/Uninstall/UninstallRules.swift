import Foundation

/// Decides which directory entries belong to an app. Pure by construction: the scanner does the
/// listing and hands over child *names*, so nothing here can touch the filesystem.
///
/// This is the safety-critical half of the feature — a false positive moves an unrelated app's data
/// to the Trash — which is why every rule here is exact or namespace-anchored, never fuzzy.
enum UninstallRules {
    /// Suffixes macOS appends to bundle-ID-named artifacts, stripped before matching so
    /// `com.foo.Bar.plist` compares as `com.foo.Bar`.
    static let strippedExtensions: Set<String> = [
        "plist", "savedstate", "binarycookies", "lockfile", "lock", "sfl", "sfl2", "sfl3",
        // Plug-in wrappers, which are named after the product that installed them.
        "qlgenerator", "saver", "prefpane", "service", "workflow", "mdimporter", "appex",
        "component", "wdgt", "dext", "driver"
    ]

    /// The name plus each successively stripped form. Stripping only ever adds a comparison, so it
    /// can't turn a match into a miss. Bounded because a name is not a trustworthy loop condition.
    static func matchableForms(_ name: String) -> [String] {
        var forms = [name]
        var current = name
        for _ in 0..<3 {
            let ext = (current as NSString).pathExtension.lowercased()
            guard !ext.isEmpty, strippedExtensions.contains(ext) else { break }
            let stripped = (current as NSString).deletingPathExtension
            guard !stripped.isEmpty else { break }
            forms.append(stripped)
            current = stripped
        }
        return forms
    }

    /// What may follow a bundle ID for the remainder to still be part of the same product. `.` is the
    /// ordinary namespace separator; `-` is how vendors name release variants — `dev.zed.Zed-Preview`
    /// belongs to Zed, and if Zed Preview is itself installed the sibling rule below hands it back.
    private static let namespaceSeparators: Set<Character> = [".", "-"]

    /// True when `component` is the bundle ID itself, or a namespaced child of it.
    ///
    /// The boundary is load-bearing. A plain `hasPrefix` makes `com.apple.SafariTechnologyPreview` a
    /// match for `com.apple.Safari` — a separately installed product whose entire profile would go to
    /// the Trash. Requiring a separator next means a match can only be a namespace descendant:
    /// `com.apple.iBooksX.CacheDelete` matches `com.apple.iBooksX`, `com.apple.iBooksXtra` does not.
    static func matchesBundleID(_ component: String, identity: UninstallIdentity) -> Bool {
        guard let id = identity.bundleID else { return false }
        return matchableForms(component).contains { form in
            let folded = UninstallIdentity.folded(form)
            guard owns(folded, id: id, allowingPrefix: identity.allowsBundleIDPrefixMatch)
            else { return false }
            // A sibling app installed under a longer ID in the same namespace owns its own
            // artifacts. Without this, uninstalling Tinycast would also trash the Beta and Dev
            // channels' data — they are separate products, not extensions of the stable one.
            return !identity.otherBundleIDs.contains { other in
                other.count > id.count && owns(folded, id: other, allowingPrefix: true)
            }
        }
    }

    private static func owns(_ folded: String, id: String, allowingPrefix: Bool) -> Bool {
        if folded == id { return true }
        guard allowingPrefix, folded.count > id.count, folded.hasPrefix(id) else { return false }
        // The boundary check is what separates a namespace child from a different product:
        // `com.apple.SafariTechnologyPreview` must never be read as a child of `com.apple.Safari`.
        return namespaceSeparators.contains(folded[folded.index(folded.startIndex, offsetBy: id.count)])
    }

    /// A `/usr/local/bin`-style launcher belongs to the app when it resolves inside the bundle.
    /// Attribution by link target, never by name — the name is whatever the vendor chose.
    static func isBundleSymlink(target: String, bundlePath: String) -> Bool {
        let target = (target as NSString).standardizingPath
        let bundlePath = (bundlePath as NSString).standardizingPath
        return target == bundlePath || isDescendant(target, of: bundlePath)
    }

    /// Strips a leading `group.` and/or a 10-character Team ID, in either order, leaving a plain
    /// bundle ID for the ordinary rule above. Team IDs are exactly 10 uppercase alphanumerics, which
    /// is what stops an arbitrary `something.com.foo.Bar` being read as a container of `com.foo.Bar`.
    static func groupContainerBase(_ component: String) -> String {
        var base = component
        for _ in 0..<2 {
            if base.lowercased().hasPrefix("group.") {
                base = String(base.dropFirst("group.".count))
                continue
            }
            guard let dot = base.firstIndex(of: "."), isTeamID(String(base[base.startIndex..<dot]))
            else { break }
            base = String(base[base.index(after: dot)...])
        }
        return base
    }

    static func isTeamID(_ value: String) -> Bool {
        value.count == 10
            && value.allSatisfy { $0.isASCII && ($0.isUppercase || $0.isNumber) && !$0.isLowercase }
    }

    static func matchesGroupContainer(_ component: String, identity: UninstallIdentity) -> Bool {
        matchesBundleID(groupContainerBase(component), identity: identity)
    }

    /// Exact, case- and diacritic-folded equality only. No prefix and no substring, which is what
    /// makes "Books" and "Books Reader" unable to claim each other's folders in either direction.
    static func matchesDisplayName(_ component: String, identity: UninstallIdentity) -> Bool {
        guard !identity.names.isEmpty else { return false }
        return matchableForms(component).contains { form in
            identity.names.contains(UninstallIdentity.folded(form))
        }
    }

    static func evidence(
        for name: String, in root: UninstallSearchRoot, identity: UninstallIdentity
    ) -> UninstallEvidence? {
        if root.styles.contains(.bundleID), matchesBundleID(name, identity: identity) {
            return .bundleID
        }
        if root.styles.contains(.groupContainer), matchesGroupContainer(name, identity: identity) {
            return .groupContainer
        }
        if root.styles.contains(.displayName), matchesDisplayName(name, identity: identity) {
            return .displayName
        }
        return nil
    }

    static func matches(
        childNames: [String], in root: UninstallSearchRoot, identity: UninstallIdentity
    ) -> [(name: String, evidence: UninstallEvidence)] {
        childNames.compactMap { name in
            evidence(for: name, in: root, identity: identity).map { (name, $0) }
        }
    }

    /// Belt and braces on every path the walk produces, independent of how it matched: it must be an
    /// immediate child of its own root, must not be the home directory or a filesystem root, must
    /// carry no relative components, and must not overlap the app bundle (emitted separately).
    static func isAcceptableCandidate(
        path: String, rootPath: String, home: String, bundlePath: String
    ) -> Bool {
        let path = (path as NSString).standardizingPath
        let home = (home as NSString).standardizingPath
        let bundlePath = (bundlePath as NSString).standardizingPath
        guard path.hasPrefix("/"), path != "/", path != home, path != rootPath else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !components.isEmpty, !components.contains("."), !components.contains("..")
        else { return false }
        guard (path as NSString).deletingLastPathComponent == rootPath else { return false }
        guard path != bundlePath, !isDescendant(path, of: bundlePath),
            !isDescendant(bundlePath, of: path)
        else { return false }
        return true
    }

    static func isDescendant(_ path: String, of ancestor: String) -> Bool {
        path.hasPrefix(ancestor + "/")
    }

    /// Tilde form for the row subtitle. Takes `home` rather than reading it, so it stays pure.
    static func abbreviate(_ path: String, home: String) -> String {
        if path == home { return "~" }
        guard isDescendant(path, of: home) else { return path }
        return "~" + path.dropFirst(home.count)
    }
}
