import SwiftUI

struct WindowManagementSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        return Form {
            FeatureSwitchSection(
                header: "Window Management",
                enableTitle: "Enable window management",
                enableSubtitle:
                    "Moves the window you were last in, using the Accessibility permission Tinycast already uses to paste.",
                launcherSubtitle: "Find the window commands in launcher search.",
                isEnabled: $settings.windowManagementEnabled,
                showsInLauncher: $settings.windowManagementShowInLauncher)

            Group {
                options
                commands
            }
            // Same dim as a hidden launcher category; the switch above stays live.
            .opacity(settings.windowManagementEnabled ? 1 : 0.45)
            .disabled(!settings.windowManagementEnabled)
        }
        .formStyle(.grouped)
        .overlayScroller()
    }

    private var options: some View {
        @Bindable var settings = settings
        return Section {
            Toggle(isOn: $settings.windowCycleOnRepeat) {
                Text("Cycle sizes on repeat")
                Text(
                    "Triggering a half again steps it through a third and two thirds before returning."
                )
            }

            LabeledContent {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("\(settings.windowGap) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Stepper("Gap between windows", value: $settings.windowGap, in: 0...64, step: 2)
                        .labelsHidden()
                }
            } label: {
                Text("Gap between windows")
                Text("Points left between tiled windows and around the screen edge.")
            }
        } header: {
            Text("Options")
        }
    }

    /// One section per catalog group, so the sidebar's own grouping carries the headings.
    private var commands: some View {
        ForEach(WindowCommandCatalog.grouped(), id: \.group) { section in
            Section {
                ForEach(section.commands) { command in
                    WindowCommandSettingsRow(command: command)
                }
            } header: {
                Text(section.group.title)
            }
        }
    }
}

/// One command's shortcut recorder and visibility checkbox, shaped like the shortcuts row.
private struct WindowCommandSettingsRow: View {
    let command: WindowCommand
    @Environment(VisibilityStore.self) private var visibility

    var body: some View {
        LabeledContent {
            HStack(spacing: Theme.Spacing.lg) {
                ShortcutRecorder(action: .windowCommand(id: command.id))

                Toggle("", isOn: visibilityBinding)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .help("Show in launcher")
                    .accessibilityLabel("Show \(command.name) in launcher")
            }
        } label: {
            Label(command.name, systemImage: command.sfSymbol)
                .lineLimit(1)
        }
    }

    /// `VisibilityStore` keys on the entry, so this builds the same entry `AppIndex` publishes.
    private var entry: AppEntry {
        AppEntry(
            id: command.entryID, name: command.name,
            url: URL(string: "tinycast://window-command/" + command.id.rawValue)!, bundleID: nil,
            kind: .windowCommand)
    }

    private var visibilityBinding: Binding<Bool> {
        Binding(
            get: { visibility.isItemVisible(entry) },
            set: { visibility.setItemVisible($0, for: entry) })
    }
}
