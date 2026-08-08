import AppKit
import SwiftUI

/// One titled app window with its own lifecycle: built on first show, torn down on close so its
/// SwiftUI tree deallocates. Closing it never touches another surface, and never quits the app.
@MainActor
final class AppWindowController: NSObject, NSWindowDelegate {
    private let title: String
    private let contentSize: CGSize
    private let isResizable: Bool
    private let autosaveName: String?
    private var window: NSWindow?

    init(
        title: String, contentSize: CGSize, resizable: Bool = false, autosaveName: String? = nil
    ) {
        self.title = title
        self.contentSize = contentSize
        self.isResizable = resizable
        self.autosaveName = autosaveName
    }

    /// Open, including while miniaturized — `NSWindow.isVisible` reads false in the Dock.
    var isOpen: Bool { window != nil }

    /// Returns `true` when a window was built, `false` when an already-open one was re-raised.
    @discardableResult
    func show<Content: View>(@ViewBuilder content: () -> Content) -> Bool {
        if let window {
            raise(window)
            return false
        }
        let window = makeWindow(hosting: content())
        self.window = window
        ActivationPolicy.windowDidOpen()
        raise(window)
        return true
    }

    /// Re-raise an open window without rebuilding it; `false` when none is open.
    @discardableResult
    func focus() -> Bool {
        guard let window else { return false }
        raise(window)
        return true
    }

    func close() {
        window?.close()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard window != nil else { return }
        window = nil
        ActivationPolicy.windowDidClose()
    }

    // MARK: - Private

    private func makeWindow<Content: View>(hosting root: Content) -> NSWindow {
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        if isResizable { style.insert(.resizable) }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        window.title = title
        // Edge-to-edge under a transparent titlebar, so it reads as one surface.
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        // AppKit would otherwise resurrect the window at launch, before anything is wired up.
        window.isRestorable = false
        window.contentMinSize = contentSize
        window.delegate = self

        let hosting = NSHostingView(rootView: root)
        // Keep the window's size authoritative: an unconstrained fill would drive the frame instead.
        hosting.sizingOptions = []
        window.contentView = hosting

        if let autosaveName {
            window.setFrameAutosaveName(autosaveName)
            if !window.setFrameUsingName(autosaveName) { window.center() }
        } else {
            window.center()
        }
        return window
    }

    private func raise(_ window: NSWindow) {
        if window.isMiniaturized { window.deminiaturize(nil) }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // `NSApp.activate` is async, so re-assert key next turn to land it up front.
        DispatchQueue.main.async {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
