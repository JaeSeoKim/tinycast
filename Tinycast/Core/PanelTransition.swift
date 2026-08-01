import AppKit
import SwiftUI

// How every borderless surface in the app arrives and leaves: the window fades, its content scales.
// Both halves share one duration pair so a dialog and a HUD read as the same gesture.

extension NSWindow {
    /// Fades the whole window — shadow included, which a content-only fade would leave snapping in
    /// ahead of the surface. `order` runs while the window is still invisible.
    func fadeIn(duration: TimeInterval, order: () -> Void) {
        alphaValue = 0
        order()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        } completionHandler: { [weak self] in
            // AppKit runs the handler on the main thread; the parameter just isn't typed for it.
            MainActor.assumeIsolated {
                // The shadow is cached from the frame it was first drawn at, which is the scaled-down one.
                self?.invalidateShadow()
            }
        }
    }

    /// Fades out and orders out. Safe to interrupt: `cancelFade` reinstates full opacity, and the
    /// in-flight handler checks that before hiding, so a re-shown window is never pulled out from under itself.
    func fadeOut(duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.alphaValue == 0 else { return }
                self.orderOut(nil)
            }
        }
    }

    /// Snaps back to full opacity, replacing any running fade on the same key path.
    func cancelFade() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            animator().alphaValue = 1
        }
    }
}

extension View {
    /// Scales up as the window fades in, so a surface arrives rather than appearing. Scaling *up*
    /// inside the measured frame leaves `fittingSize` untouched and clips nothing, which is why this
    /// is a `scaleEffect` rather than a `CALayer` transform fighting `NSHostingView` over `anchorPoint`.
    func panelEntrance() -> some View {
        modifier(PanelEntrance())
    }
}

private struct PanelEntrance: ViewModifier {
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1 : Self.entryScale)
            .onAppear {
                withAnimation(.easeOut(duration: Theme.Duration.enter)) { appeared = true }
            }
    }

    private static let entryScale: CGFloat = 0.94
}
