import AppKit

/// Watches System Settings → Appearance → **Icon & widget style**. macOS restyles the icons
/// `NSWorkspace` hands out, so every one Tinycast has cached goes stale with it. KVO on the global
/// domain fires cross-process, so System Settings writing the key is itself the signal.
@MainActor
final class IconStyleMonitor {
    /// `NSKeyValueObservation` deregisters when it deinits, so holding it is the whole lifecycle.
    private let observation: NSKeyValueObservation

    init() {
        observation = UserDefaults.standard.observe(\.appleIconAppearanceTheme, options: []) { _, _ in
            MainActor.assumeIsolated { IconCache.invalidateStyled() }
        }
    }
}

extension UserDefaults {
    /// The `@objc` name has to be the default's own spelling — measured: `UserDefaults` synthesizes
    /// notifications for that key path, and the Swift-cased one never fires.
    @objc(AppleIconAppearanceTheme) dynamic var appleIconAppearanceTheme: String? {
        string(forKey: "AppleIconAppearanceTheme")
    }
}
