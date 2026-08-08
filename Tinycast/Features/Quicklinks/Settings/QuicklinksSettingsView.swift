import SwiftUI

/// The quicklink library plus the behaviour that applies to all of them.
struct QuicklinksSettingsView: View {
    @Environment(QuicklinkStore.self) private var store
    @Environment(AppCore.self) private var core
    @Environment(AppSettings.self) private var settings
    @State private var query = ""
    @State private var pendingDeletion: Quicklink?

    var body: some View {
        @Bindable var core = core
        @Bindable var settings = settings
        return SettingsPane {
            FeatureSwitchCard(
                header: "Quicklinks",
                enableTitle: "Enable quicklinks",
                footer: "Open saved destinations from the launcher, a shortcut, or Search "
                    + "Quicklinks. Showing them in the launcher makes them findable from search.",
                isEnabled: $settings.quicklinksEnabled,
                showsInLauncher: $settings.quicklinksShowInLauncher)

            Group {
                if !store.isAvailable { storageCallout }
                library
                behaviour
                transfer
            }
            // Same dim as a hidden launcher category; the switch above stays live.
            .opacity(settings.quicklinksEnabled ? 1 : Theme.Opacity.disabled)
            .disabled(!settings.quicklinksEnabled)
        }
        // Presented from the pane, so "Create Quicklink" can open it from the palette.
        .sheet(item: $core.pendingQuicklinkEdit) { request in
            QuicklinkEditorSheet(quicklink: request.quicklink)
        }
        .alert(item: $pendingDeletion) { quicklink in
            Alert(
                title: Text("Delete “\(quicklink.name)”?"),
                message: Text("Its global shortcut and launcher references will also be removed."),
                primaryButton: .destructive(Text("Delete")) {
                    Task { await core.quicklinkCoordinator.deleteQuicklink(id: quicklink.id, confirming: false) }
                },
                secondaryButton: .cancel())
        }
    }

    // MARK: - Cards

    private var storageCallout: some View {
        SettingsCallout(
            title: "Quicklinks can't be saved",
            message:
                "The quicklinks database couldn't be opened, so nothing you change here will stick. "
                + "The existing file was left untouched.",
            systemImage: "exclamationmark.triangle.fill",
            tint: .orange)
    }

    @ViewBuilder
    private var library: some View {
        if !store.quicklinks.isEmpty {
            SettingsSearchField(prompt: "Search quicklinks…", query: $query)
        }
        SettingsCard(
            footer: "Name a quicklink, paste a link, then give it a shortcut if you want one."
        ) {
            if results.isEmpty {
                SettingsRow(
                    title: store.quicklinks.isEmpty ? "No quicklinks" : "No matches",
                    subtitle: store.quicklinks.isEmpty
                        ? nil : "No quicklink matches “\(query)”."
                ) {
                    EmptyView()
                }
            } else {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, quicklink in
                    if index > 0 { SettingsDivider() }
                    QuicklinkSettingsRow(
                        quicklink: quicklink,
                        onEdit: { core.quicklinkCoordinator.editQuicklink(quicklink) },
                        onDelete: { pendingDeletion = quicklink })
                }
            }
            SettingsDivider()

            SettingsRow(title: "Add Quicklink") {
                Button("Add…") { core.quicklinkCoordinator.editQuicklink(nil) }
            }
        }
    }

    private var behaviour: some View {
        @Bindable var settings = settings
        return SettingsCard(
            header: "Behaviour",
            footer: "A new window is asked of the handler instead of reusing its frontmost tab; "
                + "only apps that accept a new-window argument can honour it. The fallback covers "
                + "what {selection} does when the app in front exposes nothing to read."
        ) {
            SettingsRow(title: "Open in a new window") {
                SettingsSwitch(
                    title: "Open in a new window", isOn: $settings.quicklinkOpensNewWindow)
            }
            SettingsDivider()
            SettingsRow(title: "When there's no selected text") {
                Picker("", selection: $settings.quicklinkSelectionFallback) {
                    ForEach(QuicklinkSelectionFallback.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            SettingsDivider()
            SettingsRow(title: "Confirm before deleting") {
                SettingsSwitch(
                    title: "Confirm before deleting",
                    isOn: $settings.quicklinkConfirmsBeforeDelete)
            }
        }
    }

    private var transfer: some View {
        SettingsCard(
            header: "Import & Export",
            footer: "Importing adds quicklinks from a JSON file, skipping any you already have. "
                + "Exporting writes your whole library to one."
        ) {
            SettingsRow(title: "Import quicklinks") {
                Button("Import…") { Task { await core.quicklinkCoordinator.importQuicklinks() } }
            }
            SettingsDivider()
            SettingsRow(title: "Export quicklinks") {
                Button("Export…") { Task { await core.quicklinkCoordinator.exportQuicklinks() } }
                    .disabled(store.quicklinks.isEmpty)
            }
        }
    }

    /// The store already publishes display order, so filtering keeps pins at the top.
    private var results: [Quicklink] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return store.quicklinks }
        return store.quicklinks.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.link.localizedCaseInsensitiveContains(trimmed)
        }
    }
}

private struct QuicklinkSettingsRow: View {
    let quicklink: Quicklink
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            // The symbol is the quicklink's own identity, so it stays — monochrome, not tinted.
            SymbolImage(name: symbol, size: 13)
                .foregroundStyle(.secondary)
                .frame(width: Theme.Size.settingsGlyph)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(quicklink.name)
                        .font(Theme.Typography.rowTitle)
                        .lineLimit(1)
                    if quicklink.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .help("Pinned to the top")
                    }
                    if !quicklink.showsInRootSearch {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .help("Hidden from root search")
                    }
                }
                Text(quicklink.link)
                    .font(Theme.Typography.rowSubtitle.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(quicklink.link)
            }

            Spacer(minLength: Theme.Spacing.lg)
            ShortcutRecorder(action: .quicklink(id: quicklink.id))

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .help("Edit Quicklink")
            .accessibilityLabel("Edit \(quicklink.name)")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Delete Quicklink")
            .accessibilityLabel("Delete \(quicklink.name)")
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.lg)
    }

    private var symbol: String {
        quicklink.iconSymbol ?? QuicklinkDestination.detect(quicklink.link)?.defaultSymbol
            ?? Quicklink.sfSymbol
    }
}
