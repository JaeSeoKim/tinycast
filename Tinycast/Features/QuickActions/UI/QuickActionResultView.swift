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

    private var result: some View {
        ScrollView {
            body(for: state.phase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.vertical, Theme.Spacing.lg)
                // A `ScrollView` has no ideal height, so the frame below is set, not merely capped.
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .frame(height: bodyHeight)
        .scrollBounceBehavior(.basedOnSize)
        .mask(scrollFade)
    }

    /// A mask, not the native scroll edge effect: that draws a material where a scroll view meets a
    /// safe area, and over this panel's own vibrancy it composited to nothing.
    @ViewBuilder
    private var scrollFade: some View {
        if contentHeight > bodyHeight {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: Theme.Size.quickActionScrollFade)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: Theme.Size.quickActionScrollFade)
            }
        } else {
            // Fading text that already fits would read as a defect.
            Color.black
        }
    }

    private var bodyHeight: CGFloat {
        min(
            max(contentHeight, Theme.Size.quickActionPanelMinBody),
            Theme.Size.quickActionPanelBody)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Only the title run drags: the handle is an overlay, and would eat the menu's clicks.
            HStack(spacing: Theme.Spacing.sm) {
                SymbolImage(name: state.action.symbol, size: Theme.Size.quickActionHeaderIcon)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(state.action.title)
                    .font(Theme.Typography.panelTitle)
                Spacer(minLength: Theme.Spacing.md)
            }
            .windowDraggable(true)
            if state.action == .translate, !languages.isEmpty { languageMenu }
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.top, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.lg)
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
            // One `Text` per chunk would break the wrap, so the runs are styled inside one string.
            prose(Text(attributed(chunks)))
        } else if state.action == .summarize {
            MarkdownView(blocks: MarkdownBlock.parse(state.output))
        } else {
            prose(Text(state.output))
        }
    }

    /// A result is a paragraph to read rather than a row label, so it is led like one.
    private func prose(_ text: Text) -> some View {
        text
            .font(Theme.Typography.rowTitle)
            .lineSpacing(Theme.Spacing.xs)
            .textSelection(.enabled)
    }

    private func attributed(_ chunks: [TextDiffEngine.Chunk]) -> AttributedString {
        chunks.reduce(into: AttributedString()) { result, chunk in
            switch chunk {
            case .equal(let text):
                result.append(AttributedString(text))
            case .inserted(let text):
                var run = AttributedString(text)
                run.foregroundColor = Theme.Colors.success
                result.append(run)
            case .deleted(let text):
                var run = AttributedString(text)
                run.foregroundColor = Theme.Colors.destructive
                run.strikethroughStyle = .single
                result.append(run)
            }
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
