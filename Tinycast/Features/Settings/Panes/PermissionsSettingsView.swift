import Combine
import SwiftUI

struct PermissionsSettingsView: View {
    @State private var accessibilityTrusted = Permissions.isAccessibilityTrusted()
    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        SettingsPane {
            SettingsCard(
                header: "Accessibility",
                footer: "Accessibility lets Tinycast paste a clipboard item into the app you were "
                    + "using, and remap the Hyper Key. Granting it opens Privacy & Security › "
                    + "Accessibility."
            ) {
                SettingsRow(title: "Accessibility") {
                    statusBadge
                }
                SettingsDivider()
                SettingsRow(
                    title: accessibilityTrusted ? "Manage in System Settings" : "Grant access"
                ) {
                    Button(accessibilityTrusted ? "Open…" : "Open Settings…") {
                        Permissions.openAccessibilitySettings()
                    }
                }
            }
        }
        .onAppear { accessibilityTrusted = Permissions.isAccessibilityTrusted() }
        .onReceive(refreshTimer) { _ in
            let trusted = Permissions.isAccessibilityTrusted()
            if trusted != accessibilityTrusted { accessibilityTrusted = trusted }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: Theme.Spacing.xs + 1) {
            Image(
                systemName: accessibilityTrusted
                    ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            Text(accessibilityTrusted ? "Granted" : "Not granted")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(accessibilityTrusted ? Color.green : Color.orange)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            Capsule().fill((accessibilityTrusted ? Color.green : Color.orange).opacity(0.14))
        )
    }
}
