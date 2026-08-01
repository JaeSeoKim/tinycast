import AppKit
import SwiftUI

/// Everything the two HUDs agree on: one panel at a time, replace rather than stack, fade in, sit
/// out its welcome, fade away. They differ only in what goes inside, where it sits, and how long it
/// dwells — so those are the initializer's arguments and nothing else is duplicated between
/// `MessageHUDController` and `VolumeHUDController`.
@MainActor
final class HUDPresenter {
    /// Where the panel sits above the bottom of the visible frame.
    enum Anchor {
        case edgeInset(CGFloat)
        case heightFraction(CGFloat)
    }

    private let anchor: Anchor
    private let dwell: TimeInterval
    private let screen: () -> NSScreen?
    private var panel: HUDPanel?
    private var dismissal: Task<Void, Never>?

    init(anchor: Anchor, dwell: TimeInterval, screen: @escaping () -> NSScreen?) {
        self.anchor = anchor
        self.dwell = dwell
        self.screen = screen
    }

    /// Shows `view`, replacing whatever is up. Pass `size` for a fixed-size readout; leave it nil to
    /// let SwiftUI measure, which is how the pill tracks the width of its message.
    func show(_ view: some View, size: CGSize? = nil) {
        let panel = panel ?? make()
        let host = NSHostingView(rootView: view)
        // Size the window from this local, never from `host.frame` afterwards: attaching a content
        // view resizes it to the window's current content rect, which is zero on a fresh panel — and
        // a zero-width window then "centers" with its leading edge on the screen's midline.
        let content = size ?? host.fittingSize
        host.setFrameSize(content)
        panel.setContentSize(content)
        panel.contentView = host
        place(panel)
        // A panel already on screen may be mid-fade; bring it back rather than starting a second one.
        if panel.isVisible {
            panel.cancelFade()
        } else {
            panel.fadeIn(duration: Theme.Duration.enter) { panel.orderFrontRegardless() }
        }
        scheduleDismissal()
    }

    /// Re-arms the dismissal for a panel whose content updates itself through an observable, so a
    /// repeated command extends the HUD instead of rebuilding — and re-running its entrance animation.
    func extend() {
        guard let panel, panel.isVisible else { return }
        panel.cancelFade()
        scheduleDismissal()
    }

    var isShowing: Bool { panel?.isVisible ?? false }

    private func scheduleDismissal() {
        dismissal?.cancel()
        dismissal = Task { [weak self, dwell] in
            try? await Task.sleep(for: .seconds(dwell))
            guard !Task.isCancelled else { return }
            self?.panel?.fadeOut(duration: Theme.Duration.exit)
        }
    }

    private func make() -> HUDPanel {
        let panel = HUDPanel()
        self.panel = panel
        return panel
    }

    private func place(_ panel: NSPanel) {
        guard let visible = screen()?.visibleFrame else { return }
        let y: CGFloat
        switch anchor {
        case .edgeInset(let inset):
            y = visible.minY + inset
        case .heightFraction(let fraction):
            y = visible.minY + visible.height * fraction
        }
        panel.setFrameOrigin(NSPoint(x: visible.midX - panel.frame.width / 2, y: y))
    }
}
