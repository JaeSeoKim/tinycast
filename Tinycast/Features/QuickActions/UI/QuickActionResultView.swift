import SwiftUI
@preconcurrency import Translation

/// The result panel's content. Same surface recipe as the dialog and the join preview, so the
/// fourth borderless surface reads as a sibling of the other three.
struct QuickActionResultView: View {
    @Bindable var state: QuickActionPanelState
    let languages: [Locale.Language]
    let onReplace: () -> Void
    let onCopy: () -> Void
    let onCancel: () -> Void
    let onRetranslate: (Locale.Language) -> Void
    let onDownloaded: () -> Void

    /// Set while a download is running; `translationTask` is the only API that can fetch a pair.
    @State private var downloadConfiguration: TranslationSession.Configuration?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Theme.Colors.separator)
            body(for: state.phase)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider().overlay(Theme.Colors.separator)
            footer
        }
        .frame(width: Theme.Size.quickActionPanel)
        .background(Theme.Colors.panelScrim)
        .background(VisualEffectView())
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.dialog, style: .continuous))
        .panelEntrance()
        // `prepareTranslation` is the download, and this modifier is the only API that can start
        // one — which is why an uninstalled pair becomes a panel instead of a silent failure.
        .translationTask(downloadConfiguration) { session in
            try? await session.prepareTranslation()
            await MainActor.run {
                downloadConfiguration = nil
                onDownloaded()
            }
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            SymbolImage(name: state.action.symbol, size: Theme.Size.settingsRowIcon)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(state.action.title)
                .font(Theme.Typography.rowTitle)
            Spacer(minLength: Theme.Spacing.md)
            if state.action == .translate, !languages.isEmpty {
                languageMenu
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.lg)
    }

    @ViewBuilder
    private func body(for phase: QuickActionPanelState.Phase) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                switch phase {
                case .running where state.output.isEmpty:
                    placeholder("Working…")
                case .running, .finished:
                    result
                case .failed(let message):
                    placeholder(message)
                case .needsLanguageDownload:
                    downloadPrompt
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .frame(maxHeight: Theme.Size.quickActionPanelBody)
        .edgeDissolve()
    }

    @ViewBuilder
    private var result: some View {
        let chunks = state.diff
        if chunks.isEmpty {
            MarkdownView(blocks: MarkdownBlock.parse(state.output))
        } else {
            // One Text per chunk would break the wrap, so the run is concatenated.
            chunks.reduce(Text("")) { $0 + styled($1) }
                .font(Theme.Typography.rowTitle)
                .textSelection(.enabled)
        }
    }

    private func styled(_ chunk: TextDiffEngine.Chunk) -> Text {
        switch chunk {
        case .equal(let text):
            return Text(text)
        case .inserted(let text):
            return Text(text).foregroundStyle(Theme.Colors.success)
        case .deleted(let text):
            return Text(text).strikethrough().foregroundStyle(Theme.Colors.destructive)
        }
    }

    private func placeholder(_ message: String) -> some View {
        Text(message)
            .font(Theme.Typography.rowTrailing)
            .foregroundStyle(Theme.Colors.textSecondary)
    }

    private var downloadPrompt: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            placeholder(
                "\(TextTranslator.displayName(of: state.targetLanguage)) needs to be downloaded "
                    + "before Tinycast can translate into it.")
            PanelButton(title: "Download", keyCap: "", role: .standard) {
                downloadConfiguration = TranslationSession.Configuration(
                    source: nil, target: state.targetLanguage)
            }
        }
    }

    private var languageMenu: some View {
        Menu {
            ForEach(languages, id: \.maximalIdentifier) { language in
                Button(TextTranslator.displayName(of: language)) { onRetranslate(language) }
            }
        } label: {
            Text(TextTranslator.displayName(of: state.targetLanguage))
                .font(Theme.Typography.bar)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.md) {
            Spacer(minLength: Theme.Spacing.md)
            PanelButton(title: "Dismiss", keyCap: "esc", role: .cancel, onActivate: onCancel)
            PanelButton(title: "Copy", keyCap: "⌘C", role: .standard, onActivate: onCopy)
                .disabled(!state.canReplace)
            PanelButton(title: "Replace", keyCap: "↵", role: .standard, onActivate: onReplace)
                .disabled(!state.canReplace)
        }
        .padding(Theme.Spacing.xl)
    }
}

/// A deliberate copy of the dialog's button rather than a share: the dialog owns its own, and a
/// panel that had to move with it would couple two unrelated surfaces.
private struct PanelButton: View {
    let title: String
    let keyCap: String
    let role: DialogAction.Role
    let onActivate: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onActivate) {
            Text(title)
                .font(Theme.Typography.bar)
                .foregroundStyle(
                    role == .cancel ? Theme.Colors.textSecondary : Theme.Colors.textPrimary
                )
                .padding(.horizontal, Theme.Spacing.xl)
                .frame(height: Theme.Size.menuButton)
                .contentShape(Capsule())
                .background(Capsule().fill(hovered ? Theme.Colors.menuHover : Color.clear))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .frosted(in: Capsule())
        .tooltip(keyCap)
    }
}
