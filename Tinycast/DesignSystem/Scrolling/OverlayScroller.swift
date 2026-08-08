import AppKit
import SwiftUI

extension View {
    func overlayScroller() -> some View {
        background(OverlayScrollerConfigurator().frame(width: 0, height: 0))
    }
}

private struct OverlayScrollerConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ProbeView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ProbeView)?.applyOverlayStyle()
    }

    private final class ProbeView: NSView {
        private var attemptsRemaining = 12
        private var styleObserver: NotificationToken?

        override init(frame frameRect: NSRect) { super.init(frame: frameRect) }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else {
                styleObserver = nil
                return
            }
            observeStyleChanges()
            attemptsRemaining = 12  // re-attached to a fresh hierarchy; give the splice a few ticks again
            applyOverlayStyle()
        }

        /// AppKit resets the style on this, so re-apply after its own handler runs.
        private func observeStyleChanges() {
            guard styleObserver == nil else { return }
            let token = NotificationCenter.default.addObserver(
                forName: NSScroller.preferredScrollerStyleDidChangeNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.async { self?.applyOverlayStyle() }
            }
            styleObserver = NotificationToken(token, center: .default)
        }

        /// A `Form` or `List` builds its own scroll view, so a `.background` probe on one is a
        /// cousin of that scroll view rather than a descendant and `enclosingScrollView` misses it.
        /// Climb until an ancestor's subtree holds one; content nested *inside* a scroll view still
        /// takes the exact first branch.
        private var targetScrollView: NSScrollView? {
            if let scrollView = enclosingScrollView { return scrollView }
            var ancestor = superview
            while let current = ancestor {
                if let scrollView = current.firstScrollViewInSubtree { return scrollView }
                ancestor = current.superview
            }
            return nil
        }

        func applyOverlayStyle() {
            guard let scrollView = targetScrollView else {
                // Not spliced in yet; retry next tick, bounded so it can't spin forever.
                guard attemptsRemaining > 0 else { return }
                attemptsRemaining -= 1
                DispatchQueue.main.async { [weak self] in self?.applyOverlayStyle() }
                return
            }
            // Touch only what is actually wrong. Re-asserting a setting the scroll view already
            // holds makes AppKit re-tile and flash the scrollers — once per pane, on every switch.
            if scrollView.scrollerStyle != .overlay {
                scrollView.scrollerStyle = .overlay  // thin floating knob that reserves no width
            }
            if !scrollView.autohidesScrollers {
                scrollView.autohidesScrollers = true
            }
            if !scrollView.hasVerticalScroller {
                scrollView.hasVerticalScroller = true
            }
        }
    }
}

extension NSView {
    fileprivate var firstScrollViewInSubtree: NSScrollView? {
        for subview in subviews {
            if let scrollView = subview as? NSScrollView { return scrollView }
            if let nested = subview.firstScrollViewInSubtree { return nested }
        }
        return nil
    }
}
