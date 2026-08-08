enum SettingsTab: Int, CaseIterable, Identifiable, Hashable {
    // Declaration order is sidebar order; `Group.tabs` slices it, so keep each group contiguous.
    case general, permissions
    case applications, systemSettings, systemActions, commands, quicklinks
    case snippets, windowManagement, clipboard, emoji
    case backup, miscellaneous, about
    var id: Int { rawValue }

    /// A sidebar section, so fourteen panes read as four short lists rather than one long one.
    enum Group: CaseIterable, Identifiable {
        case general, sources, tools, app
        var id: Self { self }

        var title: String {
            switch self {
            case .general: return "General"
            case .sources: return "Search Sources"
            case .tools: return "Tools"
            case .app: return "App"
            }
        }

        var tabs: [SettingsTab] { SettingsTab.allCases.filter { $0.group == self } }
    }

    var group: Group {
        switch self {
        case .general, .permissions: return .general
        case .applications, .systemSettings, .systemActions, .commands, .quicklinks: return .sources
        case .snippets, .windowManagement, .clipboard, .emoji: return .tools
        case .backup, .miscellaneous, .about: return .app
        }
    }

    var title: String {
        switch self {
        case .general: return "General"
        case .applications: return "Applications"
        case .systemSettings: return "System Settings"
        case .systemActions: return "System Actions"
        case .commands: return "Commands"
        case .quicklinks: return "Quicklinks"
        case .snippets: return "Snippets"
        case .windowManagement: return "Window Management"
        case .clipboard: return "Clipboard"
        case .emoji: return "Emoji & Symbols"
        case .permissions: return "Permissions"
        case .backup: return "Backup"
        case .miscellaneous: return "Miscellaneous"
        case .about: return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "switch.2"
        case .applications: return "square.grid.2x2"
        case .systemSettings: return "gearshape"
        case .systemActions: return "bolt"
        case .commands: return "terminal"
        case .quicklinks: return "link"
        case .snippets: return "curlybraces"
        case .windowManagement: return "macwindow"
        case .clipboard: return "doc.on.clipboard"
        case .emoji: return "face.smiling"
        case .permissions: return "lock.shield"
        case .backup: return "arrow.up.arrow.down.circle"
        case .miscellaneous: return "ellipsis.circle"
        case .about: return "info.circle"
        }
    }
}
