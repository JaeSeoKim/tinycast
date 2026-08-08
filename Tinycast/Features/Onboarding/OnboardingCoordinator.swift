import SwiftUI

/// The first-run wizard's own window lifecycle, also re-runnable from Settings.
@MainActor
final class OnboardingCoordinator {
    private let window: AppWindowController
    /// Environment injection only — never for state this type owns.
    private unowned let core: AppCore

    init(core: AppCore) {
        self.core = core
        window = AppWindowController(
            title: "Welcome to Tinycast", contentSize: OnboardingView.windowSize,
            activation: core.activationPolicy)
    }

    var isOpen: Bool { window.isOpen }

    func showOnboarding() {
        window.show {
            OnboardingView()
                .environment(self.core)
                .environment(self.core.settings)
                .environment(self.core.hotKeys)
        }
    }

    /// Final step: close the wizard and drop straight into the launcher.
    func finishOnboarding() {
        window.close()
        core.paletteCoordinator.showPalette(mode: .launcher)
    }

    @discardableResult
    func focusExisting() -> Bool {
        window.focus()
    }
}
