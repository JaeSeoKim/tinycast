import AppKit

/// Owns `NSApp.mainMenu`. It only ever fronts while a titled window is open, so it is Settings' menu
/// bar: ⌘Q closes that window rather than terminating, and quitting stays with the menu-bar extra
/// and the launcher's Quit command.
@MainActor
final class MainMenuController: NSObject {
    private unowned let core: AppCore

    init(core: AppCore) {
        self.core = core
    }

    /// Installed after SwiftUI has published its own menu in `applicationWillFinishLaunching`.
    func install(appName: String) {
        let menu = NSMenu()
        menu.addItem(appMenuItem(appName: appName))
        menu.addItem(editMenuItem())
        menu.addItem(windowMenuItem())
        NSApp.mainMenu = menu
    }

    // MARK: - Menus

    private func appMenuItem(appName: String) -> NSMenuItem {
        let menu = NSMenu(title: appName)
        menu.addItem(item("About \(appName)", #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(showSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Hide \(appName)", #selector(NSApplication.hide(_:)), key: "h"))
        let hideOthers = item(
            "Hide Others", #selector(NSApplication.hideOtherApplications(_:)), key: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(hideOthers)
        menu.addItem(item("Show All", #selector(NSApplication.unhideAllApplications(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Close Settings", #selector(closeSettings), key: "q"))
        return submenu(menu)
    }

    private func editMenuItem() -> NSMenuItem {
        let menu = NSMenu(title: "Edit")
        // Extra parens: no Swift declaration exists for these two, so `#selector` cannot name them.
        menu.addItem(item("Undo", Selector(("undo:")), key: "z"))
        let redo = item("Redo", Selector(("redo:")), key: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redo)
        menu.addItem(.separator())
        menu.addItem(item("Cut", #selector(NSText.cut(_:)), key: "x"))
        menu.addItem(item("Copy", #selector(NSText.copy(_:)), key: "c"))
        menu.addItem(item("Paste", #selector(NSText.paste(_:)), key: "v"))
        menu.addItem(item("Delete", #selector(NSText.delete(_:))))
        menu.addItem(item("Select All", #selector(NSText.selectAll(_:)), key: "a"))
        return submenu(menu)
    }

    /// Not `NSApp.windowsMenu`: the auto-populated list would advertise the palette and the HUDs.
    private func windowMenuItem() -> NSMenuItem {
        let menu = NSMenu(title: "Window")
        menu.addItem(item("Minimize", #selector(NSWindow.performMiniaturize(_:)), key: "m"))
        menu.addItem(item("Zoom", #selector(NSWindow.performZoom(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Close", #selector(NSWindow.performClose(_:)), key: "w"))
        menu.addItem(.separator())
        menu.addItem(item("Bring All to Front", #selector(NSApplication.arrangeInFront(_:))))
        return submenu(menu)
    }

    // MARK: - Actions

    @objc private func showAbout(_ sender: Any?) {
        core.settingsCoordinator.showAbout()
    }

    @objc private func showSettings(_ sender: Any?) {
        core.settingsCoordinator.showSettings()
    }

    @objc private func closeSettings(_ sender: Any?) {
        core.settingsCoordinator.closeSettings()
    }

    // MARK: - Building blocks

    /// Our own items target this controller; the rest are left to the responder chain.
    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        if responds(to: action) { item.target = self }
        return item
    }

    private func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
}

extension MainMenuController: NSMenuItemValidation {
    /// Greys "Close Settings" out rather than letting ⌘Q silently do nothing with no window up.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(closeSettings) else { return true }
        return core.settingsCoordinator.isOpen
    }
}
