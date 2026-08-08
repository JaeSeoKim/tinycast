import Foundation

/// The sidebar renders `Group.tabs`, not `allCases`, so a pane that falls out of the grouping
/// would silently vanish from the window while still being reachable by deep link.
@main
@MainActor
struct SettingsTabsTests {
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
        groupsCoverEveryPane()
        groupsAreContiguous()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static func groupsCoverEveryPane() {
        let grouped = SettingsTab.Group.allCases.flatMap(\.tabs)
        expect(Set(grouped) == Set(SettingsTab.allCases), "every pane lands in a group")
        expect(Set(grouped).count == grouped.count, "and none of them in two")
    }

    /// `Group.tabs` filters `allCases`, so the sidebar only reads in declaration order while each
    /// group stays contiguous. Interleaving two groups reorders the window, not this array.
    static func groupsAreContiguous() {
        let grouped = SettingsTab.Group.allCases.flatMap(\.tabs)
        expect(grouped == SettingsTab.allCases, "the groups list every pane, in declaration order")
    }
}
