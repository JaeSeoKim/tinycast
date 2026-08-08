import AppKit
import SwiftUI

/// Opens the Settings scene and gates its content; docs/ui.md#settings covers both.
@MainActor
@Observable
final class SettingsWindowPresenter {
    nonisolated static let windowID = "settings"

    /// Drives the scene's content. False means the panes are not in memory.
    private(set) var isOpen = false
    /// The pane a fresh mount starts on; the tree is rebuilt on every open.
    private(set) var initialTab: SettingsTab = .general

    @ObservationIgnored private var openWindow: OpenWindowAction?
    /// Weak: SwiftUI owns this window's lifetime, and a closed one must not read as open.
    @ObservationIgnored private weak var window: NSWindow?
    @ObservationIgnored private var closeObserver: NotificationToken?

    func adopt(_ action: OpenWindowAction) {
        openWindow = action
    }

    /// Called when the scene mounts. SwiftUI owns the delegate, so the close is observed instead.
    func bind(_ window: NSWindow) {
        guard window !== self.window else { return }
        self.window = window
        let token = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isOpen = false
                DockPresence.syncAfterClose()
            }
        }
        closeObserver = NotificationToken(token, center: .default)
    }

    /// Opens Settings on `tab`, or switches an already-open window to it.
    func show(tab: SettingsTab) {
        DockPresence.promote()
        NSApp.activate(ignoringOtherApps: true)

        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NotificationCenter.default.post(name: .tinycastSelectSettingsTab, object: tab)
            return
        }

        // Mount the panes before the window exists, so the fresh tree starts on `tab`.
        initialTab = tab
        isOpen = true
        openWindow?(id: Self.windowID)
        DispatchQueue.main.async {
            self.window?.makeKeyAndOrderFront(nil)
        }
    }

    /// Re-raise an open Settings window, or false when there isn't one.
    @discardableResult
    func focusExisting() -> Bool {
        guard let window, window.isVisible else { return false }
        DockPresence.promote()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return true
    }
}
