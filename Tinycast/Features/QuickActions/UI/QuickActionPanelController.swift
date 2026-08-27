import AppKit
import SwiftUI

/// Owns the result panel: one at a time, and the target app keeps its selection while it is up.
@MainActor
final class QuickActionPanelController: NSObject, NSWindowDelegate {
    enum Outcome: Equatable {
        case replace(String)
        case dismissed
    }

    private var panel: QuickActionPanel?
    private var state: QuickActionPanelState?
    private var onOutcome: ((Outcome) -> Void)?
    private var onRetranslate: ((Locale.Language) -> Void)?
    private var onDownloaded: (() -> Void)?
    /// The panel's top-left, held so a reply growing under the reader does not push the title up.
    private var anchor: NSPoint?

    var isShowing: Bool { panel?.isVisible ?? false }

    func present(
        _ state: QuickActionPanelState,
        languages: [Locale.Language],
        onRetranslate: @escaping (Locale.Language) -> Void,
        onDownloaded: @escaping () -> Void,
        onOutcome: @escaping (Outcome) -> Void
    ) {
        dismiss()
        self.state = state
        self.onOutcome = onOutcome
        self.onRetranslate = onRetranslate
        self.onDownloaded = onDownloaded

        let view = QuickActionResultView(
            state: state,
            languages: languages,
            onReplace: { [weak self] in self?.finish(.replace(state.output)) },
            onCopy: { [weak self] in self?.copyOutput() },
            onCancel: { [weak self] in self?.finish(.dismissed) },
            onRetranslate: { [weak self] in self?.onRetranslate?($0) },
            onDownloaded: { [weak self] in self?.onDownloaded?() })
        let hosting = NSHostingView(rootView: view)
        // The controller owns the frame; without this the top edge drifts as the reply grows.
        hosting.sizingOptions = []
        hosting.setFrameSize(hosting.fittingSize)

        let panel = QuickActionPanel(content: hosting)
        panel.delegate = self
        panel.onKey = { [weak self] key in
            guard let self, let state = self.state else { return }
            switch key {
            case .replace: if state.canReplace { self.finish(.replace(state.output)) }
            case .copy: if state.canReplace { self.copyOutput() }
            case .cancel: self.finish(.dismissed)
            }
        }
        self.panel = panel
        place(panel, size: hosting.fittingSize)
        // Non-activating like the palette: key focus without pulling the reader out of their app.
        panel.fadeIn(duration: Theme.Duration.enter) {
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
        }
    }

    /// Re-measures after the content changed. Called by the coordinator as the reply lands, since
    /// it drives the stream; SwiftUI resizes its own view but never the window around it.
    func resizeToFit() {
        guard let panel, let hosting = panel.contentView else { return }
        let fitted = hosting.fittingSize
        guard abs(fitted.height - panel.frame.height) > 0.5 else { return }
        hosting.setFrameSize(fitted)
        place(panel, size: fitted)
    }

    func dismiss() {
        guard let closing = panel else { return }
        panel = nil
        state = nil
        onOutcome = nil
        onRetranslate = nil
        onDownloaded = nil
        anchor = nil
        closing.delegate = nil
        closing.onKey = nil
        closing.fadeOut(duration: Theme.Duration.exit)
    }

    private func copyOutput() {
        guard let state else { return }
        Paster.copyPlainText(state.output)
    }

    private func finish(_ outcome: Outcome) {
        let callback = onOutcome
        dismiss()
        callback?(outcome)
    }

    /// Anchored by its top-left: a panel centred on every re-measure would crawl up the screen as
    /// the reply arrives.
    private func place(_ panel: NSPanel, size: NSSize) {
        guard let visible = NSScreen.underCursor?.visibleFrame else { return }
        let anchor =
            anchor
            ?? NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY + size.height / 2 + visible.height * Self.centerLift)
        self.anchor = anchor
        panel.setFrame(
            NSRect(x: anchor.x, y: anchor.y - size.height, width: size.width, height: size.height),
            display: true)
    }

    /// Optical centering, the same lift a dialog takes.
    private static let centerLift: CGFloat = 0.08

    // MARK: - NSWindowDelegate

    /// Click-away dismisses, like every other borderless surface.
    func windowDidResignKey(_ notification: Notification) {
        guard let panel, notification.object as? NSWindow === panel else { return }
        finish(.dismissed)
    }
}
