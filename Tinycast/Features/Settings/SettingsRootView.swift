import SwiftUI

/// The Settings shell: a stock `NavigationSplitView`, so its chrome is all AppKit's.
struct SettingsRootView: View {
    @Environment(SettingsWindowPresenter.self) private var presenter

    /// The sidebar clears its selection on ⌘-click; the detail column always needs a pane.
    private var selection: Binding<SettingsTab?> {
        Binding(
            get: { presenter.tab },
            set: { presenter.tab = $0 ?? presenter.tab })
    }

    var body: some View {
        NavigationSplitView {
            List(selection: selection) {
                ForEach(SettingsTab.Group.allCases) { group in
                    Section(group.title) {
                        ForEach(group.tabs) { tab in
                            Label(tab.title, systemImage: tab.systemImage).tag(tab)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("")
            // Every pane is one click away in the list; collapsing the column only hides them.
            .toolbar(removing: .sidebarToggle)
            // Resizable, so AppKit aligns the toolbar's leading items to the split divider.
            .navigationSplitViewColumnWidth(
                min: Theme.Size.settingsSidebar, ideal: Theme.Size.settingsSidebar,
                max: Theme.Size.settingsSidebarMax)
        } detail: {
            detail
                .navigationTitle(presenter.tab.title)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }

    // Not a `TabView`: `NSTabView` re-hosts on selection and breaks the recorder.
    @ViewBuilder
    private var detail: some View {
        switch presenter.tab {
        case .general: GeneralSettingsView()
        case .applications: ApplicationsSettingsView()
        case .systemSettings: SystemSettingsSettingsView()
        case .systemActions: SystemActionsSettingsView()
        case .commands: CommandsSettingsView()
        case .quicklinks: QuicklinksSettingsView()
        case .snippets: SnippetsSettingsView()
        case .windowManagement: WindowManagementSettingsView()
        case .clipboard: ClipboardSettingsView()
        case .emoji: EmojiSettingsView()
        case .permissions: PermissionsSettingsView()
        case .backup: BackupSettingsView()
        case .miscellaneous: MiscellaneousSettingsView()
        case .about: AboutView()
        }
    }
}
