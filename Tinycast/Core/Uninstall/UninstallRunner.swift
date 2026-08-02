import Foundation

struct UninstallFailedItem: Hashable, Sendable {
    let name: String
    let reason: String
}

struct UninstallReport: Sendable {
    let trashed: [UninstallCandidate]
    let failed: [UninstallFailedItem]

    var trashedCount: Int { trashed.count }
    var freedBytes: Int64 { trashed.reduce(0) { $0 + $1.size.bytes } }
    var hasFailures: Bool { !failed.isEmpty }
    /// Only when the bundle itself went may the app's hotkey, favorite and ranking be cleared —
    /// a leftovers-only cleanup leaves the app installed.
    var removedBundle: Bool { trashed.contains { $0.evidence == .bundle } }
}

/// Moves an uninstall's checked items to the Trash. `FileManager.trashItem` is the only removal call
/// in this feature — `removeItem` never appears, so every uninstall stays undoable from Finder.
/// Presenting the outcome is `AppCore`'s job; this reports and never shows UI.
enum UninstallRunner {
    static func moveToTrash(_ candidates: [UninstallCandidate]) async -> UninstallReport {
        // Defensive: a locked candidate should never have been checked, so treat one here as a bug
        // to skip rather than an attempt to make.
        let removable = candidates.filter { !$0.isLocked }
        // The bundle goes last. Either order can leave a partial state, but with the bundle still in
        // place the user can re-run the uninstall to retry the leftovers; once it's gone, the
        // launcher entry that reaches this screen is gone with it.
        let ordered =
            removable.filter { $0.evidence != .bundle } + removable.filter { $0.evidence == .bundle }

        return await Task.detached(priority: .userInitiated) {
            var trashed: [UninstallCandidate] = []
            var failed: [UninstallFailedItem] = []
            for candidate in ordered {
                do {
                    try FileManager.default.trashItem(at: candidate.url, resultingItemURL: nil)
                    trashed.append(candidate)
                } catch {
                    failed.append(
                        UninstallFailedItem(
                            name: candidate.name, reason: error.localizedDescription))
                }
            }
            return UninstallReport(trashed: trashed, failed: failed)
        }.value
    }
}
