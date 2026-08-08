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

/// Settings' content, with the environment every pane reads.
private struct SettingsScreen: View {
    private let core = AppCore.shared

    var body: some View {
        SettingsRootView()
            .environment(core)
            .environment(core.settings)
            .environment(core.appIndex)
            .environment(core.hotKeys)
            .environment(core.visibility)
            .environment(core.customCommands)
            .environment(core.snippetsStore)
            .environment(core.quicklinks)
    }
}
