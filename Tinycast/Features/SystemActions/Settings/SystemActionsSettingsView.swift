import SwiftUI

struct SystemActionsSettingsView: View {
    var body: some View {
        SettingsPane {
            LauncherItemsCard(
                kind: .systemAction,
                header: "System Actions",
                searchPrompt: "Search system actions…")
        }
    }
}
