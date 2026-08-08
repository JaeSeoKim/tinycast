import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppCore.self) private var core
    @Environment(AppSettings.self) private var settings
    private var hyperTap: HyperKeyTap { core.hyperKeyTap }
    private var launcherRanking: LauncherRankingStore { core.launcherRanking }
    // The same key `MenuBarExtra(isInserted:)` binds, so this updates the icon live.
    @AppStorage(SettingsKey.showInMenuBar) private var showInMenuBar = true
    @State private var confirmingRankingReset = false

    /// The Hyper modifier chord as prose glyphs, tracking the Include Shift toggle.
    private var hyperGlyphs: String { settings.hyperKeyIncludesShift ? "⌃⌥⇧⌘" : "⌃⌥⌘" }

    private var hyperStatusDot: Color? {
        switch hyperTap.status {
        case .off: return nil
        case .active: return .green
        case .needsAccessibility: return .orange
        }
    }

    private var hyperSubtitle: String {
        guard settings.hyperKey != .none else {
            return
                "Select a physical key to remap to the \(hyperGlyphs) modifier keys simultaneously."
        }
        var text =
            "Pressing \(settings.hyperKey.title) will trigger the left \(hyperGlyphs) modifier keys."
            + " Hyper Key shortcuts are shown in Tinycast with ✦."
        if hyperTap.status == .needsAccessibility {
            text += " Tinycast needs Accessibility access to remap keys."
        }
        return text
    }

    var body: some View {
        @Bindable var settings = settings
        return SettingsPane {
            SettingsCard(header: "Global Shortcuts", footer: "Summon the fuzzy app launcher.") {
                SettingsRow(title: "App Launcher") {
                    ShortcutRecorder(action: .togglePalette)
                }
            }

            SettingsCard(
                header: "Search",
                footer: "Tinycast privately learns which results you choose for each query. "
                    + "Reset all learned choices to restore the default order."
            ) {
                SettingsRow(title: "Learned ranking") {
                    Button("Reset…", role: .destructive) {
                        confirmingRankingReset = true
                    }
                    .disabled(launcherRanking.isEmpty)
                }
            }

            SettingsCard(header: "Hyper Key") {
                SettingsRow(
                    title: "Hyper Key",
                    subtitle: hyperSubtitle,
                    statusDot: hyperStatusDot
                ) {
                    if hyperTap.status == .needsAccessibility {
                        Button("Grant Access…") { Permissions.openAccessibilitySettings() }
                    }
                    Picker("", selection: $settings.hyperKey) {
                        ForEach(HyperKeyPhysicalKey.allCases) { key in
                            Text(key.title).tag(key)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .onChange(of: settings.hyperKey) { _, newKey in
                        // A Quick Press choice is meaningless for a different key.
                        settings.hyperKeyQuickPress = .none
                        if newKey != .none { Permissions.ensureAccessibility() }
                    }
                }
                if settings.hyperKey.hasOriginalFunction {
                    SettingsDivider()
                    SettingsRow(
                        title: "Quick Press",
                        subtitle:
                            "Select an action to perform when \(settings.hyperKey.title) is pressed without any other keys."
                    ) {
                        Picker("", selection: $settings.hyperKeyQuickPress) {
                            Text("Does Nothing").tag(HyperKeyQuickPress.none)
                            if let original = settings.hyperKey.quickPressOriginalTitle {
                                Text(original).tag(HyperKeyQuickPress.originalKey)
                            }
                            Text("Trigger Escape").tag(HyperKeyQuickPress.escape)
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                SettingsDivider()
                SettingsRow(title: "Include Shift (⇧)") {
                    SettingsSwitch(
                        title: "Include Shift", isOn: $settings.hyperKeyIncludesShift
                    )
                    // Flipping it re-points recorded chords, so it needs a chord to mean.
                    .disabled(settings.hyperKey == .none)
                }
                .opacity(settings.hyperKey == .none ? Theme.Opacity.disabled : 1)
            }

            SettingsCard(
                header: "Appearance",
                footer: "Compact mode opens the launcher as a slim search bar that expands into "
                    + "the full list as you type, with favorite app icons pinned to its right "
                    + "(⌘1–⌘5 to launch). Following the cursor opens it on whichever display the "
                    + "pointer is on, rather than the one with the menu bar."
            ) {
                SettingsRow(title: "Compact mode") {
                    SettingsSwitch(title: "Compact mode", isOn: $settings.compactMode)
                }
                SettingsDivider()
                SettingsRow(title: "Show favorites in compact mode") {
                    SettingsSwitch(
                        title: "Show favorites in compact mode",
                        isOn: $settings.showFavoritesInCompactMode
                    )
                    .disabled(!settings.compactMode)
                }
                .opacity(settings.compactMode ? 1 : Theme.Opacity.disabled)
                SettingsDivider()
                SettingsRow(title: "Follow the cursor across displays") {
                    SettingsSwitch(
                        title: "Follow the cursor across displays",
                        isOn: $settings.openOnCursorScreen)
                }
            }

            SettingsCard(
                header: "General",
                footer: "Tinycast can start automatically when you log in, and its shortcuts still "
                    + "work with the menu bar icon hidden. Pop to Root Search resets the window to "
                    + "the launcher that long after it closes."
            ) {
                SettingsRow(title: "Launch at login") {
                    SettingsSwitch(title: "Launch at login", isOn: $settings.launchAtLogin)
                }
                SettingsDivider()
                SettingsRow(title: "Show in menu bar") {
                    SettingsSwitch(title: "Show in menu bar", isOn: $showInMenuBar)
                }
                SettingsDivider()
                SettingsRow(title: "Pop to Root Search") {
                    Picker("", selection: $settings.popToRootTimeout) {
                        ForEach(PopToRootTimeout.allCases) { timeout in
                            Text(timeout.title).tag(timeout)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
        .confirmationDialog(
            "Reset learned launcher ranking?",
            isPresented: $confirmingRankingReset,
            titleVisibility: .visible
        ) {
            Button("Reset Ranking", role: .destructive) {
                launcherRanking.resetAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Tinycast will relearn your preferred results as you use the launcher.")
        }
    }
}
