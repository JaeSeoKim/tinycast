import SwiftUI

extension Notification.Name {
    /// Switch an already-open Settings window to a pane (object: the target `SettingsTab`).
    static let tinycastSelectSettingsTab = Notification.Name("TinycastSelectSettingsTab")
}

/// The Settings shell: a stock `NavigationSplitView`, so its chrome is all AppKit's.
struct SettingsRootView: View {
    @State private var history: SettingsHistory

    init(initialTab: SettingsTab = .general) {
        _history = State(initialValue: SettingsHistory(initialTab))
    }

    private var selection: Binding<SettingsTab?> {
        Binding(
            get: { history.current },
            set: { if let tab = $0 { history.visit(tab) } })
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
            NavigationStack {
                detail
                    .navigationTitle(history.current.title)
                    .toolbar {
                        // Two adjacent bordered `.navigation` items: AppKit draws the capsule.
                        ToolbarItem(placement: .navigation) {
                            Button { history.goBack() } label: {
                                Image(systemName: "chevron.backward")
                            }
                            .help("Back")
                            .accessibilityLabel("Back")
                            .disabled(!history.canGoBack)
                        }
                        ToolbarItem(placement: .navigation) {
                            Button { history.goForward() } label: {
                                Image(systemName: "chevron.forward")
                            }
                            .help("Forward")
                            .accessibilityLabel("Forward")
                            .disabled(!history.canGoForward)
                        }
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .onReceive(NotificationCenter.default.publisher(for: .tinycastSelectSettingsTab)) { note in
            if let target = note.object as? SettingsTab { history.visit(target) }
        }
    }

    // Not a `TabView`: `NSTabView` re-hosts on selection and breaks the recorder.
    @ViewBuilder
    private var detail: some View {
        switch history.current {
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
