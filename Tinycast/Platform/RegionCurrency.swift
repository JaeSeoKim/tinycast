import Foundation

/// The Mac's own currency, from System Settings ▸ Language & Region — never CoreLocation.
enum RegionCurrency {
    /// Read fresh: `Locale.current` already re-resolves after the region preference changes.
    static var code: String? { Locale.current.currency?.identifier }
}
