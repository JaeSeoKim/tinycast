import AppKit
import SwiftUI

/// Opens the SwiftUI `Window` scene hosting Settings; docs/ui.md#settings says why it is a scene.
@MainActor
final class SettingsWindowPresenter {
    nonisolated static let windowID = "settings"

    private var openWindow: OpenWindowAction?
    private var closeObserver: NotificationToken?

    func adopt(_ action: OpenWindowAction) {
        openWindow = action
        guard closeObserver == nil else { return }
        // The scene owns this window, so nothing else can demote the app when it closes.
        let token = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { note in
            let closing = note.object as? NSWindow
            MainActor.assumeIsolated {
                guard closing?.identifier?.rawValue == Self.windowID else { return }
                // Another window may still be up; the Dock icon belongs to the last one standing.
                let others = NSApp.windows.filter {
                    $0.isVisible && $0.identifier?.rawValue != Self.windowID
                        && $0.styleMask.contains(.titled)
                }
                if others.isEmpty { NSApp.setActivationPolicy(.accessory) }
            }
        }
        closeObserver = NotificationToken(token, center: .default)
    }

    /// Opens Settings on `tab`, or switches an already-open window to it.
    func show(tab: SettingsTab) {
        // A Dock icon while a real window is up; `AppDelegate` demotes when the last one closes.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let window = existingWindow {
            window.makeKeyAndOrderFront(nil)
            select(tab)
            return
        }

        openWindow?(id: Self.windowID)
        // The scene mounts on `.general`; the pane switch has to wait for it to exist.
        DispatchQueue.main.async {
            self.existingWindow?.makeKeyAndOrderFront(nil)
            self.select(tab)
        }
    }

    /// Re-raise an open Settings window, or false when there isn't one.
    @discardableResult
    func focusExisting() -> Bool {
        guard let window = existingWindow, window.isVisible else { return false }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return true
    }

    private func select(_ tab: SettingsTab) {
        guard tab != .general else { return }
        NotificationCenter.default.post(name: .tinycastSelectSettingsTab, object: tab)
    }

    private var existingWindow: NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue == Self.windowID }
    }
}
