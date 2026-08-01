import AppKit

/// The volume readout, shown after a volume or mute command since macOS only draws its own HUD for
/// real media keys and a CoreAudio change would otherwise be silent. It is a box rather than the
/// message pill because a level needs an actual bar and number, not a one-line sentence.
@MainActor
final class VolumeHUDController {
    private let presenter = HUDPresenter(
        anchor: .heightFraction(bottomFraction), dwell: Theme.Duration.volumeHUD,
        screen: { .underCursor })
    private let state = VolumeState(level: 0)

    func show(level: Float32, muted: Bool) {
        // The view observes `state`, so a repeat command animates the bar to its new value in place
        // rather than rebuilding the panel and replaying the entrance.
        let showing = presenter.isShowing
        state.level = VolumeLevel.clamped(Double(level))
        state.muted = muted
        if showing {
            presenter.extend()
        } else {
            presenter.show(
                VolumeHUDView(state: state),
                size: CGSize(width: Theme.Size.hudWidth, height: Theme.Size.hudHeight))
        }
    }

    /// Sits a little higher than the message pill: the box is taller, and this keeps their optical
    /// distance from the screen edge the same.
    private static let bottomFraction: CGFloat = 0.12
}
