import SwiftUI

/// Settings → Quick Actions. A peer of the AI pane rather than a section inside it: the feature has
/// its own switch, its own route and its own permission, and only borrows the provider layer.
struct QuickActionsSettingsView: View {
    @Environment(AppCore.self) private var core
    @Environment(AppSettings.self) private var appSettings
    @Environment(QuickActionSettingsStore.self) private var store
    @Environment(AISettingsStore.self) private var aiSettings

    var body: some View {
        Form {
            Section {
                Toggle(isOn: enabledBinding) {
                    Text("Enable Quick Actions")
                    Text(
                        "Act on the text you have selected in any app. Nothing is read until you "
                            + "press a shortcut.")
                }
            } header: {
                Text("Quick Actions")
            }

            Group {
                actionsSection
                modelSection
                languageSection
            }
            .settingsEnabled(appSettings.quickActionsEnabled)
        }
        .formStyle(.grouped)
        .onAppear {
            store.resolveModel(
                appleIntelligenceAvailable: aiSettings.isAppleIntelligenceAvailable(),
                fallback: aiSettings.defaultModel)
        }
    }

    private var actionsSection: some View {
        Section {
            ForEach(QuickAction.allCases) { action in
                SettingsRow(title: action.title, subtitle: subtitle(for: action)) {
                    Image(systemName: action.symbol)
                        .frame(width: Theme.Size.settingsRowIcon)
                } trailing: {
                    ShortcutRecorder(action: .quickAction(action), isQuiet: true)
                    Toggle("", isOn: previewBinding(action))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                        .disabled(action.alwaysPreviews)
                        .accessibilityLabel("Preview \(action.title) before replacing")
                }
            }
        } header: {
            Text("Actions")
        } footer: {
            Text(
                "The checkbox shows the result in a panel first. Without it the selection is "
                    + "replaced straight away — undo in the app you were in brings it back."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var modelSection: some View {
        Section {
            if modelChoices.isEmpty {
                Label("No AI provider configured", systemImage: "sparkles")
                    .foregroundStyle(.secondary)
            } else {
                Picker(selection: modelBinding) {
                    ForEach(modelChoices, id: \.selection) { choice in
                        Text(choice.title).tag(Optional(choice.selection))
                    }
                } label: {
                    Text("Model")
                    Text("Used by every action except Translate.")
                }
            }
        } header: {
            Text("Model")
        } footer: {
            Text(
                "Separate from chat's model on purpose: a shortcut you press all day should not "
                    + "bill an API every time. Apple Intelligence runs on this Mac for nothing."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var languageSection: some View {
        Section {
            Picker(selection: languageBinding) {
                Text("Same as this Mac").tag("")
                ForEach(QuickActionCoordinator.offeredLanguages, id: \.maximalIdentifier) {
                    Text(TextTranslator.displayName(of: $0)).tag($0.maximalIdentifier)
                }
            } label: {
                Text("Translate to")
                Text("The panel can still translate into another language once it is open.")
            }
        } header: {
            Text("Translate")
        } footer: {
            Text(
                "Translation uses Apple's own translator on this Mac, so it costs nothing and "
                    + "reaches no provider. A language downloads the first time you use it."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func subtitle(for action: QuickAction) -> String? {
        action.alwaysPreviews ? "Always shown in a panel" : nil
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { appSettings.quickActionsEnabled },
            set: { core.quickActionCoordinator.setEnabled($0) })
    }

    private func previewBinding(_ action: QuickAction) -> Binding<Bool> {
        Binding(
            get: { store.settings.previewsResult(action) },
            set: { store.settings.setPreviewsResult($0, for: action) })
    }

    private var modelBinding: Binding<AIModelSelection?> {
        Binding(get: { store.model }, set: { store.select($0) })
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { store.settings.targetLanguage },
            set: { store.settings.targetLanguage = $0 })
    }

    /// The same routes chat offers, flattened: Quick Actions has no reason to group them.
    private var modelChoices: [(selection: AIModelSelection, title: String)] {
        var choices: [(AIModelSelection, String)] = []
        if aiSettings.isAppleIntelligenceAvailable() {
            choices.append((.appleIntelligence, AppleIntelligence.title))
        }
        for model in core.chatGPTSubscription.models {
            choices.append(
                (.chatGPT(model: model.id, effort: model.resolvedEffort(nil)),
                    "\(model.name) · ChatGPT"))
        }
        for connection in aiSettings.connections {
            for model in connection.models {
                choices.append(
                    (.api(connection: connection.id, model: model),
                        "\(model) · \(connection.title)"))
            }
        }
        return choices
    }
}
