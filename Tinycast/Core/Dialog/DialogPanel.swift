import AppKit
import Carbon.HIToolbox

/// Borderless panel hosting one Tinycast dialog or the volume HUD. Keys are intercepted in
/// `sendEvent` rather than SwiftUI's `onKeyPress` so Esc/↵ work without depending on anything inside
/// the dialog holding focus.
final class DialogPanel: NSPanel {
    enum Key {
        case cancel
        case confirm
        case adjust(Double)
    }

    var onKey: ((Key) -> Void)?
    private let acceptsKey: Bool

    init(content: NSView, acceptsKey: Bool) {
        self.acceptsKey = acceptsKey
        super.init(
            contentRect: NSRect(origin: .zero, size: content.frame.size),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        // Above the palette's `.floating`, so a confirmation is never buried under the window that triggered it.
        level = .modalPanel
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // Suppresses AppKit's own window animation; `fadeIn`/`fadeOut` below replace it.
        animationBehavior = .none
        isReleasedWhenClosed = false
        contentView = content
    }

    /// Fades the whole window rather than just its content, so the drop shadow arrives with the
    /// dialog instead of snapping in ahead of it. `DialogView` scales up over the same duration.
    func fadeIn() {
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Theme.Duration.dialogOpen
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

    func fadeOut() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Theme.Duration.dialogClose
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.orderOut(nil) }
        }
    }

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown, let onKey else {
            super.sendEvent(event)
            return
        }
        switch Int(event.keyCode) {
        case kVK_Escape:
            onKey(.cancel)
        case kVK_Return, kVK_ANSI_KeypadEnter:
            onKey(.confirm)
        case kVK_LeftArrow, kVK_DownArrow:
            onKey(.adjust(-Self.arrowStep))
        case kVK_RightArrow, kVK_UpArrow:
            onKey(.adjust(Self.arrowStep))
        default:
            super.sendEvent(event)
        }
    }

    /// Matches the volume commands' own 1/16 step, so arrowing the slider lands on the same values Turn Volume Up/Down produce.
    private static let arrowStep = 1.0 / 16

    override var canBecomeKey: Bool { acceptsKey }
    override var canBecomeMain: Bool { false }
}
