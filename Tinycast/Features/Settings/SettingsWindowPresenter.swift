import AppKit
import SwiftUI

/// Opens the Settings scene and owns which pane it shows; docs/ui.md#settings covers both.
@MainActor
@Observable
final class SettingsWindowPresenter {
    nonisolated static let windowID = "settings"

    /// The pane on screen. The sidebar binds straight to it, so opening on a pane is an assignment.
    var tab: SettingsTab = .general

    @ObservationIgnored private var openWindow: OpenWindowAction?
    /// Weak: SwiftUI owns the scene's window, and it outlives every close.
    @ObservationIgnored private weak var window: NSWindow?
    @ObservationIgnored private var closeObserver: NotificationToken?

    /// Miniaturized is not `isVisible`, but the window is still open — and still in the Dock.
    private var isOpen: Bool {
        guard let window else { return false }
        return window.isVisible || window.isMiniaturized
    }

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
            Task { @MainActor in
                guard let window = self?.window else { return }
                DockPresence.syncAfterClose(of: window)
            }
        }
        closeObserver = NotificationToken(token, center: .default)
    }

    /// Opens Settings on `tab`, or switches an already-open window to it.
    func show(tab: SettingsTab) {
        // Without a route to the scene there is no window to own; promoting would strand the icon.
        guard let openWindow else { return }
        self.tab = tab
        DockPresence.promote()
        NSApp.activate(ignoringOtherApps: true)
        if isOpen {
            raise()
        } else {
            openWindow(id: Self.windowID)
        }
    }

    /// Re-raise an open Settings window, or false when there isn't one.
    @discardableResult
    func focusExisting() -> Bool {
        guard isOpen else { return false }
        DockPresence.promote()
        NSApp.activate(ignoringOtherApps: true)
        raise()
        return true
    }

    /// Deminiaturize first: a window in the Dock ignores `makeKeyAndOrderFront`.
    private func raise() {
        guard let window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    }
}
