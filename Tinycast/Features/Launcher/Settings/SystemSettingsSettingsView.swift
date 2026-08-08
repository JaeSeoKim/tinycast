import SwiftUI

/// The launcher category for macOS System Settings panes — hence the doubled name.
struct SystemSettingsSettingsView: View {
    var body: some View {
        SettingsPane {
            LauncherItemsCard(
                kind: .systemSettings,
                header: "System Settings",
                searchPrompt: "Search System Settings…")
        }
    }
}
