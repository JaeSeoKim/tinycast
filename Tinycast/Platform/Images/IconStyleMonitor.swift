import AppKit

/// Watches System Settings → Appearance → **Icon & widget style**. macOS restyles the icons
/// `NSWorkspace` hands out, so every one Tinycast has cached is stale the moment it changes.
///
/// KVO on the global domain fires cross-process, so System Settings writing the key *is* the signal
/// and no distributed notification is involved. Delivery needs a running main runloop, so a harness
/// that only sleeps will never see it.
@MainActor
final class IconStyleMonitor {
    /// The observation deregisters itself when it deinits, so holding it is the whole lifecycle.
    private let observation: NSKeyValueObservation

    init() {
        observation = UserDefaults.standard.observe(\.appleIconAppearanceTheme, options: []) { _, _ in
            MainActor.assumeIsolated { IconCache.invalidateStyled() }
        }
    }
}

extension UserDefaults {
    /// The `@objc` name has to be the default's own spelling. `UserDefaults` synthesizes KVO
    /// notifications for a key path named exactly like the key, and the Swift-cased name is one
    /// nothing ever writes — measured: observing `appleIconAppearanceTheme` never fires.
    @objc(AppleIconAppearanceTheme) dynamic var appleIconAppearanceTheme: String? {
        string(forKey: "AppleIconAppearanceTheme")
    }
}
