import AppKit

/// The Dock icon follows the titled windows, so the untitled palette panel can never move it.
@MainActor
enum DockPresence {
    static func promote() {
        NSApp.setActivationPolicy(.regular)
    }

    /// `closing` is still listed on `willClose`; miniaturized still counts, it holds the Dock icon.
    static func syncAfterClose(of closing: NSWindow) {
        let titled = NSApp.windows.contains {
            $0 !== closing && $0.styleMask.contains(.titled)
                && ($0.isVisible || $0.isMiniaturized)
        }
        if !titled { NSApp.setActivationPolicy(.accessory) }
    }
}
