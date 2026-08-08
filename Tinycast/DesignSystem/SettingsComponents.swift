import SwiftUI

// Settings building blocks; metrics come from `Theme`, so it shares the palette's vocabulary.

// MARK: - Pane scaffold

/// The standard pane layout. No title: the toolbar names the pane.
struct SettingsPane<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                content
            }
            // The toolbar owns the top inset now, so this is a plain margin on all four sides.
            .padding(Theme.Spacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            // The native overlay scroller here, matching other windowed setting lists.
            .overlayScroller()
        }
        // Outside the ScrollView, so an open recorder's callout isn't clipped by it.
        .shortcutRecorderPopoverHost()
    }
}

// MARK: - Grouped card

/// The System Settings "card". Its fill carries the group alone: a border reads as a web card.
struct SettingsCard<Content: View>: View {
    var header: String?
    /// One paragraph explaining the whole group, so its rows can stay a single line each.
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if let header {
                Text(header)
                    .font(Theme.Typography.cardHeader)
                    .padding(.leading, Theme.Spacing.xs)
            }
            // Clipped, so a row's own hover fill takes the card's corners.
            VStack(spacing: 0) { content }
                .background(Theme.Colors.cardFill)
                .clipShape(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            if let footer {
                Text(footer)
                    .font(Theme.Typography.cardFooter)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Spacing.xs)
            }
        }
    }
}

/// Every settings switch: one size, and its title as the label, so no call site can drift.
struct SettingsSwitch: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
    }
}

/// A feature pane's top card: the master switch, then its visibility companion.
struct FeatureSwitchCard: View {
    let header: String
    let enableTitle: String
    /// One paragraph covering both switches, so neither row needs its own caption.
    let footer: String
    @Binding var isEnabled: Bool
    @Binding var showsInLauncher: Bool

    var body: some View {
        SettingsCard(header: header, footer: footer) {
            SettingsRow(title: enableTitle) {
                SettingsSwitch(title: enableTitle, isOn: $isEnabled)
            }
            SettingsDivider()
            SettingsRow(title: "Show in launcher") {
                SettingsSwitch(title: "Show in launcher", isOn: $showsInLauncher)
            }
            .opacity(isEnabled ? 1 : Theme.Opacity.disabled)
            .disabled(!isEnabled)
        }
    }
}

/// The filter field above a long list, styled to read as part of the group below.
struct SettingsSearchField: View {
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
        .font(.body)
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .fill(Theme.Colors.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .strokeBorder(Theme.Colors.cardStroke, lineWidth: 1)
        )
    }
}

/// Inset divider inside a `SettingsCard`, aligned under the row's title.
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Colors.cardStroke)
            .frame(height: 1)
            .padding(.leading, Theme.Spacing.xl)
    }
}

// MARK: - Row

/// One settings line: label and control. Its `xl` inset places a recorder — see `callout-test`.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    /// Optional state indicator rendered after the title (green = active, orange = attention).
    var statusDot: Color?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(title)
                        .font(Theme.Typography.rowTitle)
                    if let statusDot {
                        Circle()
                            .fill(statusDot)
                            .frame(width: Theme.Size.statusDot, height: Theme.Size.statusDot)
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.rowSubtitle)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Theme.Spacing.xl)
            trailing
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.xl)
    }
}

// MARK: - Callout

/// A tinted notice box inside a `SettingsCard`, with an optional trailing control.
struct SettingsCallout<Trailing: View>: View {
    let title: String
    var message: String?
    var systemImage: String = "info.circle"
    var tint: Color = .secondary
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: Theme.Size.settingsGlyph)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                Text(title).font(Theme.Typography.rowTitle)
                if let message {
                    Text(message)
                        .font(Theme.Typography.rowSubtitle)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Theme.Spacing.xl)
            trailing
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
        )
    }
}

extension SettingsCallout where Trailing == EmptyView {
    init(title: String, message: String? = nil, systemImage: String = "info.circle", tint: Color = .secondary) {
        self.init(title: title, message: message, systemImage: systemImage, tint: tint) { EmptyView() }
    }
}
