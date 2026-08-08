import SwiftUI

@main
struct TinycastApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    // `@AppStorage` republishes only on change, avoiding a scene ⇄ binding loop.
    @AppStorage(SettingsKey.showInMenuBar) private var showInMenuBar = true

    // Channel-aware: "Tinycast", "Tinycast Dev", or "Tinycast Beta".
    private let appName = Bundle.main.appDisplayName

    var body: some Scene {
        MenuBarExtra(isInserted: $showInMenuBar) {
            Button("Open \(appName)") {
                AppCore.shared.paletteCoordinator.showPalette(mode: .launcher)
            }
            Button("Clipboard History") {
                AppCore.shared.paletteCoordinator.showPalette(mode: .clipboard)
            }
            Divider()
            Button("Settings...") { AppCore.shared.paletteCoordinator.showSettings() }
                .keyboardShortcut(",")
            Divider()
            Button("Quit \(appName)") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            MenuBarLabel(appName: appName)
        }

        // SwiftUI has to own this window; see `SettingsWindowPresenter` for why.
        Window("Settings", id: SettingsWindowPresenter.windowID) {
            SettingsScreen()
        }
        .defaultSize(width: Theme.Size.settingsWindow.width, height: Theme.Size.settingsWindow.height)
        // Min, not exact: `defaultSize` still picks the opening size.
        .windowResizability(.contentMinSize)
        .commandsRemoved()
    }
}

/// The menu bar icon, and the always-on-screen view that hands `openWindow` to the presenter.
private struct MenuBarLabel: View {
    let appName: String

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "macwindow.on.rectangle")
            .accessibilityLabel(appName)
            .onAppear { AppCore.shared.settingsWindow.adopt(openWindow) }
    }
}

/// Settings' content. Built with the window, so it never mounts over one already on screen.
private struct SettingsScreen: View {
    private let core = AppCore.shared

    var body: some View {
        SettingsRootView()
            .frame(
                minWidth: Theme.Size.settingsWindowMin.width,
                minHeight: Theme.Size.settingsWindowMin.height)
            .background(WindowBinder { core.settingsWindow.bind($0) })
            .environment(core)
            .environment(core.settingsWindow)
            .environment(core.settings)
            .environment(core.appIndex)
            .environment(core.hotKeys)
            .environment(core.visibility)
            .environment(core.customCommands)
            .environment(core.snippetsStore)
            .environment(core.quicklinks)
    }
}

/// Hands the scene's `NSWindow` to the presenter: a scene window has no delegate to hook.
private struct WindowBinder: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView { BinderView(onWindow: onWindow) }

    func updateNSView(_ view: NSView, context: Context) {}

    private final class BinderView: NSView {
        private let onWindow: (NSWindow) -> Void

        init(onWindow: @escaping (NSWindow) -> Void) {
            self.onWindow = onWindow
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            onWindow(window)
        }
    }
}
