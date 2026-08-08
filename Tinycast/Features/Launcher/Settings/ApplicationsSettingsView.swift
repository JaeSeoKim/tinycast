import SwiftUI

struct ApplicationsSettingsView: View {
    var body: some View {
        SettingsPane {
            // Scopes first: they decide what gets indexed, so they read before the results.
            SearchScopesCard()

            LauncherItemsCard(
                kind: .application,
                header: "Applications",
                searchPrompt: "Search applications…")
        }
    }
}
