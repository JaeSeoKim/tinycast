import AppKit
import SwiftUI

/// Tinycast's own dialogs. The app deliberately never shows an `NSAlert`: confirmations, failures and
/// the volume control all render in the palette's design system.
@MainActor
final class DialogController: NSObject, NSWindowDelegate {
    private var panel: DialogPanel?
    private var continuation: CheckedContinuation<Int, Never>?
    private var hud: DialogPanel?
    /// A snapshot for the HUD's read-only bar, distinct from the live `VolumeState` the Set Volume slider binds to.
    private let hudVolume = VolumeState(level: 0)
    private var hudDismissal: Task<Void, Never>?

    func confirm(
        title: String, message: String?, symbol: String, tone: DialogTone, confirmTitle: String,
        confirmRole: DialogAction.Role
    ) async -> Bool {
        let request = DialogRequest(
            title: title, message: message, symbol: symbol, tone: tone,
            actions: [
                DialogAction(title: confirmTitle, role: confirmRole),
                DialogAction(title: "Cancel", role: .cancel)
            ],
            defaultIndex: 0, cancelIndex: 1)
        return await present(request) == 0
    }

    func notice(title: String, message: String, symbol: String, tone: DialogTone) async {
        let request = DialogRequest(
            title: title, message: message, symbol: symbol, tone: tone,
            actions: [DialogAction(title: "OK", role: .cancel)], defaultIndex: 0, cancelIndex: 0)
        _ = await present(request)
    }

    /// A failure report: something already went wrong, as opposed to `confirm`'s "about to happen".
    /// Returns true when the user chose the recovery action rather than dismissing.
    func reportFailure(title: String, message: String, symbol: String, recovery: String?) async
        -> Bool {
        var actions = [DialogAction(title: "OK", role: .cancel)]
        if let recovery { actions.append(DialogAction(title: recovery)) }
        // ↵ lands on the recovery action when there is one to take, not on the OK dismissal.
        let recoveryIndex = recovery == nil ? nil : actions.count - 1
        let request = DialogRequest(
            title: title, message: message, symbol: symbol, tone: .danger,
            actions: actions, defaultIndex: recoveryIndex ?? 0, cancelIndex: 0)
        return await present(request) == recoveryIndex
    }

    func pickVolume(current: Float32) async -> Float32? {
        let volume = VolumeState(level: Double(current))
        let request = DialogRequest(
            title: "Set Volume", message: "Choose the output volume.", symbol: "speaker.wave.2",
            tone: .neutral,
            actions: [
                DialogAction(title: "Set Volume"),
                DialogAction(title: "Cancel", role: .cancel)
            ],
            defaultIndex: 0, cancelIndex: 1, volume: volume)
        guard await present(request) == 0 else { return nil }
        return Float32(volume.level)
    }

    /// Feedback for the volume and mute commands, which otherwise change the output with nothing on screen, since macOS only draws its own HUD for real media keys. Success/info toasts for other commands go through `HUDWindowController`'s pill instead, since this box's whole point is showing the level.
    func showVolumeHUD(level: Float32, muted: Bool) {
        hudVolume.level = Double(level)
        hudVolume.muted = muted
        if hud == nil {
            let view = hostingView(
                VolumeHUDView(state: hudVolume), width: Theme.Size.hudWidth,
                minHeight: Theme.Size.hudHeight)
            let panel = DialogPanel(content: view, acceptsKey: false)
            place(panel, anchor: .hud)
            panel.orderFrontRegardless()
            hud = panel
        }
        hudDismissal?.cancel()
        hudDismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Theme.Duration.hud))
            guard !Task.isCancelled else { return }
            self?.dismissHUD()
        }
    }

    private func dismissHUD() {
        hud?.orderOut(nil)
        hud = nil
        hudDismissal = nil
    }

    private func present(_ request: DialogRequest) async -> Int {
        // Carbon hotkeys keep firing while a dialog is up; a held shortcut must not stack a second one, so the extra request resolves as a dismissal. Keyed on the continuation rather than the panel so a dialog still fading out doesn't swallow the next one.
        guard continuation == nil else { return request.cancelIndex }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let content = hostingView(
                DialogView(request: request, onChoose: { [weak self] index in self?.finish(index) }),
                width: Theme.Size.dialogWidth, minHeight: 0)
            let panel = DialogPanel(content: content, acceptsKey: true)
            panel.delegate = self
            panel.onKey = { [weak self] key in
                guard let self else { return }
                switch key {
                case .cancel:
                    finish(request.cancelIndex)
                case .confirm:
                    finish(request.defaultIndex)
                case .adjust(let delta):
                    guard let volume = request.volume else { return }
                    volume.level = min(max(volume.level + delta, 0), 1)
                }
            }
            self.panel = panel
            place(panel, anchor: .center)
            // Non-activating like the palette: the dialog takes key focus for its own keys without pulling app focus away from whatever the user was in.
            panel.fadeIn()
        }
    }

    /// Resumes the caller before the panel finishes fading, so confirming Restart isn't held up by an animation.
    private func finish(_ index: Int) {
        guard let continuation else { return }
        self.continuation = nil
        let closing = panel
        panel = nil
        closing?.delegate = nil
        closing?.onKey = nil
        continuation.resume(returning: index)
        closing?.fadeOut()
    }

    private func hostingView(_ view: some View, width: CGFloat, minHeight: CGFloat) -> NSView {
        let hosting = NSHostingView(rootView: AnyView(view))
        // Measure at the fixed width first: the message wraps, so the height is only knowable once the width is pinned.
        hosting.setFrameSize(NSSize(width: width, height: minHeight))
        let fitted = hosting.fittingSize
        hosting.setFrameSize(NSSize(width: width, height: max(fitted.height, minHeight)))
        return hosting
    }

    private enum Anchor {
        case center
        case hud
    }

    private func place(_ panel: NSPanel, anchor: Anchor) {
        guard let screen = cursorScreen() else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let origin: NSPoint
        switch anchor {
        case .center:
            origin = NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2 + visible.height * Self.centerLift)
        case .hud:
            origin = NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.minY + visible.height * Self.hudBottomFraction)
        }
        panel.setFrameOrigin(origin)
    }

    /// Optical centering: a dialog placed on the exact vertical middle reads low, the same reason the palette sits above center.
    private static let centerLift: CGFloat = 0.08
    private static let hudBottomFraction: CGFloat = 0.12

    /// The display the user is working on. `NSScreen.main` is the key window's screen, which an accessory app driving non-activating panels never reliably has.
    private func cursorScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        // NSMouseInRect, not `contains`: a pointer on a display's topmost row otherwise resolves to the display stacked above it.
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    // MARK: - NSWindowDelegate

    /// Click-away resolves as a dismissal rather than leaving an orphaned dialog behind.
    func windowDidResignKey(_ notification: Notification) {
        guard let panel, notification.object as? NSWindow === panel else { return }
        panel.onKey?(.cancel)
    }
}
