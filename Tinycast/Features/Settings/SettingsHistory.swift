/// Browser-shaped back/forward history over the Settings panes visited this session.
struct SettingsHistory {
    private(set) var entries: [SettingsTab]
    private(set) var cursor: Int

    init(_ start: SettingsTab) {
        entries = [start]
        cursor = 0
    }

    var current: SettingsTab { entries[cursor] }
    var canGoBack: Bool { cursor > 0 }
    var canGoForward: Bool { cursor < entries.count - 1 }

    /// Visiting from anywhere but the tip discards the branch ahead, as a browser does.
    mutating func visit(_ tab: SettingsTab) {
        guard tab != current else { return }
        entries.removeSubrange((cursor + 1)...)
        entries.append(tab)
        cursor = entries.count - 1
    }

    mutating func goBack() {
        if canGoBack { cursor -= 1 }
    }

    mutating func goForward() {
        if canGoForward { cursor += 1 }
    }
}
