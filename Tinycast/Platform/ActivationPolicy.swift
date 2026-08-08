import AppKit

/// The app runs as an accessory; a titled window needs `.regular` for a Dock icon, a main menu and
/// working traffic lights, so the policy follows how many are open rather than any one window.
@MainActor
enum ActivationPolicy {
    private static var openWindows = 0

    static func windowDidOpen() {
        openWindows += 1
        NSApp.setActivationPolicy(.regular)
    }

    static func windowDidClose() {
        openWindows = max(0, openWindows - 1)
        if openWindows == 0 { NSApp.setActivationPolicy(.accessory) }
    }
}
