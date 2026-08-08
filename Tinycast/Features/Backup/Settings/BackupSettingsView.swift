import AppKit
import SwiftUI

struct BackupSettingsView: View {
    @Environment(AppCore.self) private var core
    private var runningApps: RunningAppsMonitor { core.runningApps }
    @State private var raycastFile: URL?
    @State private var passphrase = ""
    @State private var importing = false
    @State private var status: Status?
    @State private var selection: RaycastImportOptions = .all
    @State private var format: RaycastFormat?

    private enum Status {
        case success(String)
        case failure(String)
    }

    private var raycastRunning: Bool {
        runningApps.runningBundleIDs.contains(where: BackupActions.isRaycastBundleID)
    }

    private var raycastFileSubtitle: String {
        guard let name = raycastFile?.lastPathComponent else {
            return "Choose a .rayconfig file exported from Raycast."
        }
        return "\(name) — \(format?.title ?? "not a Raycast export")"
    }

    var body: some View {
        SettingsPane {
            SettingsCard(
                header: "Tinycast",
                footer: "Exporting saves your shortcuts, custom commands, favorites and "
                    + "preferences to JSON. Importing restores from a Tinycast backup, changing "
                    + "only the values the file contains."
            ) {
                SettingsRow(title: "Export Settings") {
                    Button("Export…") { Task { await BackupActions.exportSettings(core: core) } }
                }
                SettingsDivider()
                SettingsRow(title: "Import Settings") {
                    Button("Import…") { Task { await BackupActions.importSettings(core: core) } }
                }
            }

            SettingsCard(
                header: "Import from Raycast",
                footer: "Choose a Raycast export, enter the password you set when exporting it, "
                    + "pick what to bring over, then import."
            ) {
                SettingsRow(title: "Raycast Export", subtitle: raycastFileSubtitle) {
                    Button("Choose…") { chooseRaycastFile() }
                }
                SettingsDivider()
                SettingsRow(title: "Passphrase") {
                    SecureField("Passphrase", text: $passphrase)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: Theme.Size.passphraseField)
                        .onSubmit(runRaycastImport)
                }
                SettingsDivider()
                SettingsRow(title: "Import") {
                    if importing {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Import") { runRaycastImport() }
                            .disabled(format == nil || passphrase.isEmpty || selection.isEmpty)
                    }
                }
                RaycastImportSelection(selection: $selection, format: format)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.lg)
                conflictCallout
                if let status {
                    SettingsDivider()
                    statusRow(status)
                }
            }
        }
    }

    @ViewBuilder
    private var conflictCallout: some View {
        if raycastRunning {
            SettingsCallout(
                title: "Raycast is running — quit it to avoid hotkey conflicts.",
                systemImage: "exclamationmark.triangle.fill",
                tint: .orange
            ) {
                Button("Quit Raycast") { BackupActions.quitRaycast() }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
        } else {
            SettingsCallout(
                title: "Tip: unset the matching Raycast shortcuts to avoid conflicts.",
                systemImage: "info.circle",
                tint: .secondary
            )
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
        }
    }

    @ViewBuilder
    private func statusRow(_ status: Status) -> some View {
        switch status {
        case .success(let message):
            SettingsRow(title: message, statusDot: .green) { EmptyView() }
        case .failure(let message):
            SettingsRow(title: message, statusDot: .orange) { EmptyView() }
        }
    }

    private func chooseRaycastFile() {
        guard let url = BackupActions.pickRaycastFile() else { return }
        raycastFile = url
        format = BackupActions.detectRaycastFormat(of: url)
        status = nil
    }

    private func runRaycastImport() {
        guard let file = raycastFile, format != nil, !passphrase.isEmpty, !selection.isEmpty,
            !importing
        else { return }
        importing = true
        status = nil
        Task {
            defer { importing = false }
            do {
                let outcome = try await BackupActions.importRaycast(
                    core: core, file: file, passphrase: passphrase, options: selection)
                var parts: [String] = []
                if let applied = BackupActions.appliedText(outcome.summary) { parts.append(applied) }
                if outcome.clipboardImported > 0 {
                    parts.append("Imported \(outcome.clipboardImported) clipboard entries.")
                }
                if outcome.snippetsImported > 0 {
                    let noun = outcome.snippetsImported == 1 ? "snippet" : "snippets"
                    parts.append("Imported \(outcome.snippetsImported) \(noun).")
                }
                if let snippetsError = outcome.snippetsError {
                    parts.append("Couldn’t import snippets: \(snippetsError)")
                }
                var message = parts.isEmpty
                    ? BackupActions.nothingImportedText : parts.joined(separator: " ")
                if outcome.missingImages > 0 {
                    message += " \(outcome.missingImages) images were unavailable and skipped."
                }
                status = .success(message)
                passphrase = ""
            } catch {
                status = .failure(error.localizedDescription)
            }
        }
    }
}
