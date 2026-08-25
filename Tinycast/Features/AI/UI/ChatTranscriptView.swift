import AppKit
import SwiftUI

struct ChatTranscriptView: View {
    let messages: [ChatMessage]
    let status: String?
    let usage: AIUsage?
    /// Cleared when the reader scrolls up, so a streaming reply stops dragging them back down.
    @State private var followsTail = true
    @State private var scrollPhase = ScrollPhase.idle

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.xl) {
                    ForEach(messages) { message in
                        ChatMessageView(
                            message: message,
                            status: message.id == messages.last?.id ? status : nil
                        )
                        .id(message.id)
                    }
                    if let total = usage?.totalTokens {
                        Text("\(total.formatted()) tokens")
                            .font(Theme.Typography.rowTrailing)
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    Color.clear
                        .frame(height: Theme.Spacing.xxs)
                        .id("ai-transcript-tail")
                }
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.top, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.chatTranscriptBottom)
            }
            .edgeDissolve()
            .thinScrollbar()
            // Reopened chats start at the latest message; other anchor roles fight the reader.
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .onScrollPhaseChange { _, newPhase in scrollPhase = newPhase }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.containerSize.height
                    >= geometry.contentSize.height - Theme.Spacing.xl
            } action: { _, atBottom in
                // A growing reply moves geometry too; only a user-driven phase may drop the tail.
                if scrollPhase != .idle, scrollPhase != .animating { followsTail = atBottom }
            }
            .onChange(of: messages.count) { follow(proxy, always: true) }
            .onChange(of: messages) { follow(proxy, always: false) }
            .onChange(of: usage) { follow(proxy, always: false) }
        }
    }

    /// A sent message always comes into view; a growing reply only while the reader is at the end.
    private func follow(_ proxy: ScrollViewProxy, always: Bool) {
        guard always || followsTail else { return }
        proxy.scrollTo("ai-transcript-tail", anchor: .bottom)
    }
}

private struct ChatMessageView: View {
    let message: ChatMessage
    let status: String?

    @State private var hovered = false

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: Theme.Spacing.xxl) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: Theme.Spacing.xxs) {
                content
                if message.state != .streaming { footer }
            }
            .contentShape(Rectangle())
            .onHover { isHovered in
                if isHovered {
                    withAnimation(.easeOut(duration: Theme.Duration.chatFooter)) {
                        hovered = true
                    }
                } else {
                    hovered = false
                }
            }
            if message.role == .assistant { Spacer(minLength: Theme.Spacing.xxl) }
        }
    }

    /// Laid out at rest and only faded in, so a hover can't reflow the transcript under the pointer.
    private var footer: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if message.role == .user { timestamp }
            ChatCopyButton(text: message.text)
            if message.role == .assistant { timestamp }
        }
        .opacity(hovered ? 1 : 0)
        // A reply's footer hugs the same `sm` edge as its text.
        .padding(.horizontal, message.role == .user ? Theme.Spacing.md : Theme.Spacing.sm)
    }

    private var timestamp: some View {
        Text(message.sentAt.formatted(date: .omitted, time: .shortened))
            .font(Theme.Typography.keyCap)
            .foregroundStyle(Theme.Colors.textTertiary)
    }

    @ViewBuilder private var content: some View {
        if message.text.isEmpty, message.searches.isEmpty, message.state == .streaming {
            HStack(spacing: Theme.Spacing.sm) {
                ProgressView().controlSize(.small)
                if let status { Text(status).foregroundStyle(.secondary) }
            }
            .padding(Theme.Spacing.md)
        } else {
            bubbleContent
                .font(Theme.Typography.rowTitle)
                .foregroundStyle(message.state == .failed ? Theme.Colors.destructive : .primary)
                .textSelection(.enabled)
                // Only the user bubble is inset: it carries a fill. A reply's `sm` is just enough
                // to put its first pixel under the header's back chevron.
                .padding(.horizontal, message.role == .user ? Theme.Spacing.xl : Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                        .fill(message.role == .user ? Theme.Colors.controlSurface : Color.clear)
                )
        }
    }

    private var bubbleContent: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: Theme.Spacing.sm) {
            if !message.images.isEmpty {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(message.images, id: \.self) { image in
                        ChatImageThumbnail(image: image, edge: Theme.Size.chatImageThumb)
                    }
                }
            }
            if !message.text.isEmpty || !message.searches.isEmpty { rendered }
        }
    }

    /// Only a reply is markdown — what the user typed is shown back exactly as they typed it.
    @ViewBuilder private var rendered: some View {
        if message.role == .assistant {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ForEach(Array(message.segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case .text(let text):
                        MarkdownView(blocks: MarkdownBlock.parse(text))
                    case .search(let search):
                        ChatSearchRow(search: search)
                    }
                }
            }
        } else {
            Text(message.text)
        }
    }
}

/// Decoded once per image off the render path; a streaming transcript re-renders every flush.
struct ChatImageThumbnail: View {
    let image: AIImage
    let edge: CGFloat
    @State private var decoded: NSImage?

    var body: some View {
        Group {
            if let decoded {
                Image(nsImage: decoded)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.clear
            }
        }
        .frame(width: edge, height: edge)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
        .task(id: image) { decoded = NSImage(data: image.data) }
    }
}

/// A web search inside a reply: live while it runs, a record of what it looked up once done.
private struct ChatSearchRow: View {
    let search: ChatSearch

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if search.isComplete {
                Image(systemName: "globe")
                    .font(Theme.Typography.rowTrailing)
                    .symbolRenderingMode(.hierarchical)
            } else {
                ProgressView().controlSize(.small)
            }
            Text(search.isComplete ? "Searched web" : "Searching web")
                .font(Theme.Typography.rowTrailing)
            if let query = search.query, !query.isEmpty {
                Text("· \(query)")
                    .font(Theme.Typography.rowTrailing)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(Theme.Colors.textSecondary)
        .animation(.easeOut(duration: Theme.Duration.chatFooter), value: search.isComplete)
    }
}
