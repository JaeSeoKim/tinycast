import AppKit

/// The Dock icon follows the titled windows, so the untitled palette panel can never move it.
@MainActor
enum DockPresence {
    static func promote() {
        NSApp.setActivationPolicy(.regular)
    }

    /// Deferred a turn: on `willClose` the closing window is still listed in `NSApp.windows`.
    static func syncAfterClose() {
        DispatchQueue.main.async {
            let titled = NSApp.windows.contains {
                $0.isVisible && $0.styleMask.contains(.titled)
            }
            if !titled { NSApp.setActivationPolicy(.accessory) }
        }
    }
}
