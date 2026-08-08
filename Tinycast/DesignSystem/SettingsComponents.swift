import SwiftUI

// The two pieces more than one Settings pane needs; everything else is a stock `Form` section.

/// A feature pane's opening section: the master switch, then its launcher-visibility companion.
struct FeatureSwitchSection: View {
    let header: String
    let enableTitle: String
    let enableSubtitle: String
    let launcherSubtitle: String
    @Binding var isEnabled: Bool
    @Binding var showsInLauncher: Bool

    var body: some View {
        Section {
            Toggle(isOn: $isEnabled) {
                Text(enableTitle)
                Text(enableSubtitle)
            }
            Toggle(isOn: $showsInLauncher) {
                Text("Show in launcher")
                Text(launcherSubtitle)
            }
            // The switch above stays live so the feature can always be turned back on.
            .disabled(!isEnabled)
        } header: {
            Text(header)
        }
    }
}

/// The filter row above a long list, shaped like a search field rather than a form text field.
struct SettingsFilterField: View {
    let prompt: String
    @Binding var query: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(prompt, text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
    }
}
