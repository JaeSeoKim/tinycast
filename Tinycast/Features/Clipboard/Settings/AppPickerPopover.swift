import AppKit
import SwiftUI

/// Searchable list of installed apps, drawn from the launcher's own index.
struct AppPickerPopover: View {
    /// Bundle IDs to leave out — the ones already chosen.
    var excluded: Set<String> = []
    /// Shown above the list when the caller can also clear its choice.
    var clearTitle: String?
    /// Nil means the `clearTitle` row was tapped.
    let onSelect: (String?) -> Void

    @Environment(AppIndex.self) private var appIndex
    @State private var query = ""

    private var candidates: [AppEntry] {
        (query.isEmpty ? appIndex.apps : appIndex.matches(query))
            .filter { $0.kind == .application }
            .filter { $0.bundleID.map { !excluded.contains($0) } ?? false }
    }

    var body: some View {
        // Both read once: `candidates` fuzzy-matches the whole index on every body pass.
        let apps = candidates
        let clearRow = query.isEmpty ? clearTitle : nil
        VStack(spacing: Theme.Spacing.sm) {
            SettingsSearchField(prompt: "Search apps…", query: $query)
            ScrollView {
                LazyVStack(spacing: 1) {
                    if let clearRow {
                        AppPickerRow(title: clearRow, icon: nil) { onSelect(nil) }
                    }
                    ForEach(apps) { app in
                        AppPickerRow(title: app.name, icon: app.icon) {
                            if let id = app.bundleID { onSelect(id) }
                        }
                    }
                    // Keyed on what is actually drawn: an empty popover reads as a broken one.
                    if apps.isEmpty, clearRow == nil {
                        Text(query.isEmpty ? "No apps left to add." : "No apps match “\(query)”.")
                            .font(Theme.Typography.rowSubtitle)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.xxl)
                    }
                }
                .overlayScroller()
            }
        }
        .padding(Theme.Spacing.md)
        .frame(width: Theme.Size.appPicker.width, height: Theme.Size.appPicker.height)
    }
}

/// One app in the picker, shaped like every other icon-and-name row in the app.
private struct AppPickerRow: View {
    let title: String
    let icon: NSImage?
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Group {
                    if let icon {
                        Image(nsImage: icon).resizable()
                    } else {
                        Image(systemName: "app.dashed")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: Theme.Size.settingsGlyph, height: Theme.Size.settingsGlyph)
                Text(title)
                    .font(Theme.Typography.rowTitle)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.menu, style: .continuous)
                    .fill(hovered ? Theme.Colors.rowHover : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

/// Bundle ID → something showable: the index, then LaunchServices, then a placeholder.
@MainActor
enum AppPresentation {
    static func resolve(bundleID: String, in appIndex: AppIndex) -> (name: String, icon: NSImage) {
        if let app = appIndex.apps.first(where: { $0.bundleID == bundleID }) {
            return (app.name, app.icon)
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return (url.deletingPathExtension().lastPathComponent, IconCache.icon(forFile: url.path))
        }
        return (bundleID, NSWorkspace.shared.icon(for: .applicationBundle))
    }
}
