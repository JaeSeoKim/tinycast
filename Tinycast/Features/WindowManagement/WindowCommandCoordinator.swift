import AppKit

/// The one funnel from a palette row or a global hotkey to the mover or the Space switcher.
@MainActor
final class WindowCommandCoordinator {
    private let settings: AppSettings
    private let paletteCoordinator: PaletteCoordinator
    private let windowMover: WindowMover

    init(
        settings: AppSettings, paletteCoordinator: PaletteCoordinator, windowMover: WindowMover
    ) {
        self.settings = settings
        self.paletteCoordinator = paletteCoordinator
        self.windowMover = windowMover
    }

    /// The one funnel for palette and hotkey alike. See docs/features/window-management.md#wiring.
    func runWindowCommand(id: WindowCommand.ID) {
        guard settings.windowManagementEnabled else { return }
        switch id {
        case .switchToPreviousSpace: switchSpace(.previous)
        case .switchToNextSpace: switchSpace(.next)
        default: moveWindow(id)
        }
    }

    /// Nothing to act on, so focus is left to fall where the Space we land on puts it.
    private func switchSpace(_ direction: SpaceSwitcher.Direction) {
        if paletteCoordinator.isVisible { paletteCoordinator.hidePalette(restoreFocus: false) }
        SpaceSwitcher.switchSpace(direction)
    }

    private func moveWindow(_ id: WindowCommand.ID) {
        let target = paletteCoordinator.targetApp
        if paletteCoordinator.isVisible { paletteCoordinator.hidePalette(restoreFocus: true) }
        windowMover.perform(
            id, target: target, gap: CGFloat(settings.windowGap),
            cycleOnRepeat: settings.windowCycleOnRepeat)
    }
}
