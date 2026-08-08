import SwiftUI
import UniformTypeIdentifiers

struct ClipboardSettingsView: View {
    @Environment(AppCore.self) private var core
    @Environment(AppSettings.self) private var settings
    @State private var confirmingClear = false
    @State private var showingAppPicker = false

    var body: some View {
        @Bindable var settings = settings
        return SettingsPane {
            SettingsCard(header: "Shortcut") {
                SettingsRow(
                    title: "Clipboard History",
                    subtitle: "Open the clipboard history browser."
                ) {
                    ShortcutRecorder(action: .toggleClipboard)
                }
            }

            SettingsCard(header: "History") {
                SettingsRow(
                    title: "Keep history for",
                    subtitle: "Entries older than this are deleted automatically."
                ) {
                    Picker("", selection: $settings.clipboardRetention) {
                        ForEach(ClipboardRetention.allCases) { retention in
                            Text(retention.title).tag(retention)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .onChange(of: settings.clipboardRetention) {
                        core.clipboardCoordinator.applyRetention(settings.clipboardRetention)
                    }
                }
            }

            SettingsCard(
                header: "Disabled Applications",
                footer: "Clipboard changes from these apps won't be recorded."
            ) {
                ForEach(settings.clipboardDisabledApps, id: \.self) { bundleID in
                    DisabledAppRow(bundleID: bundleID) {
                        settings.clipboardDisabledApps.removeAll { $0 == bundleID }
                    }
                    SettingsDivider()
                }

                SettingsRow(title: "Add application") {
                    Button {
                        showingAppPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .popover(isPresented: $showingAppPicker, arrowEdge: .bottom) {
                        AppPickerPopover(excluded: Set(settings.clipboardDisabledApps)) { bundleID in
                            if let bundleID { settings.clipboardDisabledApps.append(bundleID) }
                            showingAppPicker = false
                        }
                    }
                }
            }

            SettingsCard(header: "Danger Zone") {
                SettingsRow(
                    title: "Clear history",
                    subtitle: "Permanently remove every saved clip and image."
                ) {
                    Button("Clear…", role: .destructive) { confirmingClear = true }
                }
            }
        }
        .confirmationDialog(
            "Clear clipboard history?",
            isPresented: $confirmingClear,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) {
                core.clipboardStore.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }
}

/// One excluded app; only the bundle ID is stored, so name and icon resolve on the fly.
private struct DisabledAppRow: View {
    let bundleID: String
    let onRemove: () -> Void

    @Environment(AppIndex.self) private var appIndex

    var body: some View {
        let (name, icon) = AppPresentation.resolve(bundleID: bundleID, in: appIndex)
        HStack(spacing: Theme.Spacing.lg) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 22, height: 22)
            Text(name)
                .font(Theme.Typography.rowTitle)
                .lineLimit(1)
            Spacer(minLength: Theme.Spacing.xl)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        // `lg` beside a 22pt icon lands on the same height as a plain `SettingsRow`.
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.lg)
    }
}
