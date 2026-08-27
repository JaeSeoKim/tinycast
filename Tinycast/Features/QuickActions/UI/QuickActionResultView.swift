import SwiftUI
@preconcurrency import Translation

struct QuickActionResultView: View {
    @Bindable var state: QuickActionPanelState
    let languages: [Locale.Language]
    let onReplace: () -> Void
    let onCopy: () -> Void
    let onCancel: () -> Void
    let onRetranslate: (Locale.Language) -> Void
    let onDownloaded: () -> Void
    let onHeight: (CGFloat) -> Void

    @State private var contentHeight: CGFloat = 0
    @State private var download: TranslationSession.Configuration?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            result
            footer
        }
        .frame(width: Theme.Size.quickActionPanel)
        .background(Theme.Colors.panelScrim)
        .background(VisualEffectView())
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.dialog, style: .continuous))
        .panelEntrance()
        // The panel's own height, which nothing here constrains, so reporting it cannot feed back.
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeight($0) }
        .translationTask(download) { session in
            try? await session.prepareTranslation()
            await MainActor.run {
                download = nil
                onDownloaded()
            }
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Only the title run drags: the handle is an overlay, and over the menu it would eat it.
            HStack(spacing: Theme.Spacing.md) {
                SymbolImage(name: state.action.symbol, size: Theme.Size.settingsRowIcon)
                Text(state.action.title)
                    .font(Theme.Typography.sectionHeader)
                Spacer(minLength: Theme.Spacing.md)
            }
            .foregroundStyle(Theme.Colors.textSecondary)
            .windowDraggable(true)
            if state.action == .translate, !languages.isEmpty { languageMenu }
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.top, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.lg)
    }

    private var result: some View {
        ScrollView {
            body(for: state.phase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.xxl)
                // A `ScrollView` has no ideal height, so the frame below is set, not merely capped.
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .frame(height: bodyHeight)
        .scrollBounceBehavior(.basedOnSize)
        .edgeDissolve()
    }

    private var bodyHeight: CGFloat {
        min(
            max(contentHeight, Theme.Size.quickActionPanelMinBody),
            Theme.Size.quickActionPanelBody)
    }

    @ViewBuilder
    private func body(for phase: QuickActionPanelState.Phase) -> some View {
        switch phase {
        case .running where state.output.isEmpty:
            HStack(spacing: Theme.Spacing.md) {
                ProgressView().controlSize(.small)
                Text("Working…").foregroundStyle(Theme.Colors.textSecondary)
            }
            .font(Theme.Typography.rowTitle)
        case .running, .finished:
            output
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(Theme.Typography.rowTitle)
                .foregroundStyle(Theme.Colors.textSecondary)
        case .needsLanguageDownload:
            downloadPrompt
        }
    }

    @ViewBuilder
    private var output: some View {
        let chunks = state.diff
        if !chunks.isEmpty {
            // One `Text` per chunk would break the wrap, so the styled runs are concatenated.
            chunks.reduce(Text("")) { $0 + styled($1) }
                .font(Theme.Typography.rowTitle)
                .textSelection(.enabled)
        } else if state.action == .summarize {
            MarkdownView(blocks: MarkdownBlock.parse(state.output))
        } else {
            Text(state.output)
                .font(Theme.Typography.rowTitle)
                .textSelection(.enabled)
        }
    }

    private func styled(_ chunk: TextDiffEngine.Chunk) -> Text {
        switch chunk {
        case .equal(let text): Text(text)
        case .inserted(let text): Text(text).foregroundStyle(Theme.Colors.success)
        case .deleted(let text): Text(text).strikethrough().foregroundStyle(Theme.Colors.destructive)
        }
    }

    private var downloadPrompt: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text("\(TextTranslator.displayName(of: state.targetLanguage)) hasn't been downloaded yet.")
                .font(Theme.Typography.rowTitle)
                .foregroundStyle(Theme.Colors.textSecondary)
            Button("Download") {
                download = TranslationSession.Configuration(
                    source: nil, target: state.targetLanguage)
            }
        }
    }

    private var languageMenu: some View {
        Menu(TextTranslator.displayName(of: state.targetLanguage)) {
            ForEach(languages, id: \.minimalIdentifier) { language in
                Button(TextTranslator.displayName(of: language)) { onRetranslate(language) }
            }
        }
        .menuStyle(.button)
        .buttonStyle(.accessoryBar)
        .fixedSize()
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.md) {
            Spacer(minLength: Theme.Spacing.md)
            Button("Dismiss", action: onCancel)
            Button("Copy", action: onCopy).disabled(!state.canReplace)
            Button("Replace", action: onReplace)
                .buttonStyle(.borderedProminent)
                .disabled(!state.canReplace)
        }
        .controlSize(.large)
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.vertical, Theme.Spacing.xl)
    }
}
