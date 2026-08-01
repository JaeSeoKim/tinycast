import AppKit

/// The message pill: a transient confirmation flashed near the bottom of the active screen after
/// something succeeds. Any feature can use it — snippets confirm an insertion, custom commands
/// confirm a run, system commands report a state they landed in.
@MainActor
final class MessageHUDController {
    private let presenter: HUDPresenter

    init(settings: AppSettings) {
        presenter = HUDPresenter(
            anchor: .edgeInset(Theme.Size.hudEdgeOffset),
            dwell: Theme.Duration.messageHUD,
            screen: { settings.openOnCursorScreen ? .underCursor : .main })
    }

    func show(message: String, tone: DialogTone = .success) {
        presenter.show(MessageHUDView(message: message, tone: tone))
    }
}
