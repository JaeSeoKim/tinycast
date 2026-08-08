import AppKit

/// The Dock icon follows the titled windows, so the untitled palette panel can never move it.
@MainActor
enum DockPresence {
    static func promote() {
        NSApp.setActivationPolicy(.regular)
    }

    /// `closing` is excluded by identity: on `willClose` it is still listed and still visible.
    static func syncAfterClose(of closing: NSWindow) {
        let titled = NSApp.windows.contains {
            $0 !== closing && $0.isVisible && $0.styleMask.contains(.titled)
        }
        if !titled { NSApp.setActivationPolicy(.accessory) }
    }
}
