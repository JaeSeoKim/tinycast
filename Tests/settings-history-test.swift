import Foundation

/// Drives `SettingsHistory` against the real `SettingsTab`, so a reordered or renamed pane can't
/// leave these assertions describing a sidebar that no longer exists.
@main
@MainActor
struct SettingsHistoryTests {
    static var failures = 0
    static var passes = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func main() {
        startsAtOneEntry()
        visiting()
        truncatesTheForwardBranch()
        walkingBothWays()
        sidebarOrderMatchesGroups()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    // MARK: - The empty case

    static func startsAtOneEntry() {
        let history = SettingsHistory(.general)
        expect(history.current == .general, "a fresh history sits on the pane it opened with")
        expect(!history.canGoBack, "with nothing behind it")
        expect(!history.canGoForward, "and nothing ahead")
    }

    // MARK: - Visiting

    static func visiting() {
        var history = SettingsHistory(.general)
        history.visit(.clipboard)
        expect(history.current == .clipboard, "visiting moves to the pane")
        expect(history.canGoBack, "and leaves something behind")
        expect(!history.canGoForward, "but nothing ahead")

        // Re-selecting the open pane must not stack a duplicate you'd have to click back through.
        history.visit(.clipboard)
        expect(history.entries.count == 2, "revisiting the current pane is a no-op")
    }

    // MARK: - The branch that actually trips people up

    /// Going back then somewhere new discards the old forward branch, as a browser does.
    static func truncatesTheForwardBranch() {
        var history = SettingsHistory(.general)
        history.visit(.clipboard)
        history.visit(.about)
        history.goBack()
        expect(history.current == .clipboard, "back lands on the previous pane")
        expect(history.canGoForward, "and About is still ahead")

        history.visit(.snippets)
        expect(history.current == .snippets, "visiting from mid-history moves there")
        expect(!history.canGoForward, "and About is gone, not still reachable")
        expect(
            history.entries == [.general, .clipboard, .snippets],
            "the discarded branch left no trace")
    }

    // MARK: - Walking

    static func walkingBothWays() {
        var history = SettingsHistory(.general)
        history.visit(.emoji)
        history.visit(.backup)

        history.goBack()
        history.goBack()
        expect(history.current == .general, "back walks all the way to the first pane")

        // Both ends clamp: an extra step is a no-op, never a crash or a wrap.
        history.goBack()
        expect(history.current == .general, "back at the first pane does nothing")
        history.goForward()
        history.goForward()
        history.goForward()
        expect(history.current == .backup, "forward walks to the tip and stops there")
        expect(!history.canGoForward, "which is where it stays")
    }

    // MARK: - Sidebar coverage

    /// The sidebar renders `Group.tabs`, not `allCases`, so a pane missing from a group would
    /// silently vanish from the window while still being reachable by deep link.
    static func sidebarOrderMatchesGroups() {
        let grouped = SettingsTab.Group.allCases.flatMap(\.tabs)
        expect(grouped == SettingsTab.allCases, "the groups list every pane, in declaration order")
        expect(Set(grouped).count == grouped.count, "and none of them twice")
    }
}
