import Foundation

/// The state behind the palette's Uninstall screen: one scan, its plan, and what the user checked.
/// The checked-set invariant lives in `UninstallSelection`, so this class only owns the lifecycle.
@MainActor
final class UninstallSession: ObservableObject {
    enum State: Equatable {
        case idle
        case scanning
        case ready(UninstallPlan)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var selection: UninstallSelection?
    @Published private(set) var isTrashing = false
    /// The app being uninstalled, kept for the confirmation copy and post-uninstall cleanup.
    private(set) var app: AppEntry?

    private var scanTask: Task<Void, Never>?

    var plan: UninstallPlan? {
        if case .ready(let plan) = state { return plan }
        return nil
    }

    var candidates: [UninstallCandidate] { plan?.candidates ?? [] }
    var selectedCount: Int { selection?.count ?? 0 }
    var selectedBytes: Int64 {
        guard let plan, let selection else { return 0 }
        return selection.bytes(in: plan)
    }
    var selectedCandidates: [UninstallCandidate] {
        guard let plan, let selection else { return [] }
        return selection.candidates(in: plan)
    }
    var canConfirm: Bool { selectedCount > 0 && !isTrashing }

    func begin(app: AppEntry, otherAppNames: [String], otherBundleIDs: [String], isRunning: Bool) {
        cancel()
        self.app = app
        state = .scanning
        selection = nil
        let url = app.url
        let name = app.name
        let bundleID = app.bundleID
        scanTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Result {
                    try UninstallScanner.scan(
                        target: Self.makeTarget(url: url, name: name, bundleID: bundleID),
                        otherAppNames: otherAppNames, otherBundleIDs: otherBundleIDs,
                        isTargetRunning: isRunning)
                }
            }.value
            guard let self, !Task.isCancelled else { return }
            switch result {
            case .success(let plan):
                state = .ready(plan)
                selection = plan.defaultSelection
            case .failure(let error):
                state = .failed(
                    (error as? UninstallScanner.Failure)?.errorDescription
                        ?? error.localizedDescription)
            }
        }
    }

    /// Releases an in-flight scan. Called whenever the palette leaves the Uninstall screen.
    func cancel() {
        scanTask?.cancel()
        scanTask = nil
        state = .idle
        selection = nil
        app = nil
    }

    func toggle(_ id: UninstallCandidate.ID) {
        guard let plan else { return }
        selection?.toggle(id, in: plan)
    }

    func setAll(_ on: Bool) {
        guard let plan else { return }
        selection?.setAll(on, in: plan)
    }

    func setTrashing(_ trashing: Bool) {
        isTrashing = trashing
    }

    /// Reads the bundle for the names a leftover can be attributed by. Off-main: it opens a file.
    private nonisolated static func makeTarget(url: URL, name: String, bundleID: String?)
        -> UninstallTarget
    {
        let info = Bundle(url: url)?.infoDictionary
        return UninstallTarget(
            bundleURL: url, bundleID: bundleID,
            displayName: (info?["CFBundleDisplayName"] as? String) ?? name,
            bundleName: info?["CFBundleName"] as? String)
    }
}
