import AppKit
import SwiftUI

struct ExtensionSearchDropdownPanel: View {
    let dropdown: ExtensionSearchDropdown
    let assetsPath: String?
    @Bindable var session: ExtensionSearchDropdownSession
    let onActivate: (Int) -> Void
    let onSearchTextChange: (String) -> Void
    let onDismiss: () -> Void

    @Environment(\.isDarkAppearance) private var isDark
    @Environment(PaletteState.self) private var palette
    @FocusState private var searchFocused: Bool
    @State private var pointerSelection: Int?

    private var surface: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.menuPanel, style: .continuous)
    }

    var body: some View {
        let sections = dropdown.sections(matching: session.text)
        let items = sections.flatMap(\.items)
        let rows = rows(in: sections)
        return VStack(alignment: .leading, spacing: 0) {
            searchField
            if let tooltip = dropdown.tooltip {
                header(tooltip)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    if rows.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                            ForEach(rows) { row in
                                switch row {
                                case .separator:
                                    Divider().padding(.vertical, Theme.Spacing.xs)
                                case .title(_, let title):
                                    sectionTitle(title)
                                case .item(let item):
                                    itemRow(item)
                                        .onContinuousHover {
                                            if case .active = $0 { hover(item.id) }
                                        }
                                }
                            }
                        }
                    }
                }
                .frame(height: Metrics.height(for: dropdown.sections))
                .scrollIndicators(.never)
                .scrollBounceBehavior(.basedOnSize)
                .overflowFade()
                .onAppear { scrollToSelection(in: items, with: proxy) }
                .onChange(of: items.map(\.id)) {
                    scrollToSelection(in: items, with: proxy)
                }
                .onChange(of: session.selectedItemID) {
                    let movedByPointer = pointerSelection == session.selectedItemID
                    pointerSelection = nil
                    if !movedByPointer { scrollToSelection(in: items, with: proxy) }
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .frame(width: Metrics.width)
        .glassEffect(.regular, in: surface)
        .clipShape(surface)
        .onAppear {
            session.normalize(with: dropdown)
            searchFocused = true
        }
        .onChange(of: session.text) { session.normalize(with: dropdown) }
        .onChange(of: dropdown) { session.normalize(with: dropdown) }
        .onKeyPress(keys: [.downArrow], phases: [.down, .repeat]) { _ in
            moveSelection(1, in: items)
            return .handled
        }
        .onKeyPress(keys: [.upArrow], phases: [.down, .repeat]) { _ in
            moveSelection(-1, in: items)
            return .handled
        }
        .onKeyPress(keys: [.return], phases: .down) { _ in
            guard !isComposing else { return .ignored }
            if let selectedItemID = session.selectedItemID,
                let item = items.first(where: { $0.id == selectedItemID })
            {
                onActivate(item.id)
            }
            return .handled
        }
        .onKeyPress(phases: .down) { press in
            guard press.modifiers.contains(.command),
                ASCIIKeyboardLayout.matches(press.key, character: "p")
            else { return .ignored }
            onDismiss()
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    private var searchField: some View {
        HStack(spacing: Theme.Spacing.sm) {
            SymbolImage(name: "magnifyingglass", size: Metrics.searchIconSize)
                .foregroundStyle(Theme.Colors.textTertiary)
                .accessibilityHidden(true)
            TextField("", text: searchText, prompt: Text(dropdown.placeholder))
                .textFieldStyle(.plain)
                .font(Theme.Typography.menuRow)
                .focused($searchFocused)
                .accessibilityLabel(dropdown.placeholder)
            if dropdown.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Loading")
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: Metrics.searchHeight)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.menuRow, style: .continuous)
                .fill(Theme.Colors.rowHover)
        )
        .padding(.bottom, Theme.Spacing.xs)
    }

    private var searchText: Binding<String> {
        Binding(
            get: { session.text },
            set: { value in
                guard value != session.text else { return }
                session.text = value
                onSearchTextChange(value)
            })
    }

    private var emptyState: some View {
        Text("No Results")
            .font(Theme.Typography.menuRow)
            .foregroundStyle(Theme.Colors.textTertiary)
            .frame(maxWidth: .infinity, minHeight: Metrics.rowHeight)
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.sectionHeader)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(height: Metrics.headerHeight, alignment: .center)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.sectionHeader)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(height: Metrics.sectionTitleHeight, alignment: .center)
    }

    private func itemRow(_ item: ExtensionSearchDropdown.Item) -> some View {
        Button {
            onActivate(item.id)
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                itemIcon(item)
                Text(item.title)
                    .font(Theme.Typography.menuRow)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: Theme.Spacing.sm)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(
                maxWidth: .infinity, minHeight: Metrics.rowHeight, maxHeight: Metrics.rowHeight,
                alignment: .leading
            )
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.menuRow, style: .continuous)
                    .fill(session.selectedItemID == item.id ? Theme.Colors.menuHover : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func itemIcon(_ item: ExtensionSearchDropdown.Item) -> some View {
        if let icon = item.icon {
            ExtensionIconView(
                resolved: ExtensionImage.resolve(
                    icon, assetsPath: assetsPath, isDark: isDark),
                size: Theme.Size.menuIcon)
        } else {
            Color.clear.frame(width: Theme.Size.menuIcon, height: Theme.Size.menuIcon)
        }
    }

    private func hover(_ itemID: Int) {
        guard palette.hoverHighlightArmed, itemID != session.selectedItemID else { return }
        pointerSelection = itemID
        session.selectedItemID = itemID
    }

    private func rows(in sections: [ExtensionSearchDropdown.Section]) -> [Row] {
        sections.enumerated().flatMap { sectionIndex, section -> [Row] in
            var rows: [Row] = sectionIndex == 0 ? [] : [.separator(sectionIndex)]
            if let title = section.title, !title.isEmpty {
                rows.append(.title(sectionIndex, title))
            }
            rows.append(contentsOf: section.items.map(Row.item))
            return rows
        }
    }

    private func moveSelection(_ delta: Int, in items: [ExtensionSearchDropdown.Item]) {
        guard !items.isEmpty else { return }
        guard let index = items.firstIndex(where: { $0.id == session.selectedItemID }) else {
            session.selectedItemID = delta > 0 ? items[0].id : items[items.count - 1].id
            return
        }
        session.selectedItemID = items[min(max(index + delta, 0), items.count - 1)].id
    }

    private func scrollToSelection(
        in items: [ExtensionSearchDropdown.Item], with proxy: ScrollViewProxy
    ) {
        guard let selectedItemID = session.selectedItemID,
            items.contains(where: { $0.id == selectedItemID })
        else { return }
        proxy.scrollTo(Row.itemID(selectedItemID))
    }

    private var isComposing: Bool {
        searchFocused && (NSApp.keyWindow?.firstResponder as? NSTextView)?.hasMarkedText() == true
    }

    private enum Row: Identifiable {
        case separator(Int)
        case title(Int, String)
        case item(ExtensionSearchDropdown.Item)

        var id: String {
            switch self {
            case .separator(let index): return "separator:\(index)"
            case .title(let index, _): return "title:\(index)"
            case .item(let item): return Self.itemID(item.id)
            }
        }

        static func itemID(_ id: Int) -> String { "item:\(id)" }
    }

    private enum Metrics {
        static let width: CGFloat = 300
        static let searchHeight: CGFloat = 34
        static let searchIconSize: CGFloat = 13
        static let rowHeight: CGFloat = Theme.Size.menuIcon + Theme.Spacing.md * 2
        static let rowSpacing: CGFloat = 1
        static let headerHeight: CGFloat = 28
        static let sectionTitleHeight: CGFloat = 24
        static let separatorHeight: CGFloat = Theme.Spacing.xs * 2 + 1
        static let visibleRows: CGFloat = 6.5
        static var maximumRowsHeight: CGFloat {
            (visibleRows * (rowHeight + rowSpacing)).rounded()
        }

        static func height(for sections: [ExtensionSearchDropdown.Section]) -> CGFloat {
            let itemCount = sections.reduce(0) { $0 + $1.items.count }
            let separatorCount = max(sections.count - 1, 0)
            let titleCount = sections.filter { $0.title?.isEmpty == false }.count
            let contentHeight =
                CGFloat(itemCount) * rowHeight
                + CGFloat(separatorCount) * separatorHeight
                + CGFloat(titleCount) * sectionTitleHeight
            let spacing = CGFloat(max(itemCount + separatorCount + titleCount - 1, 0)) * rowSpacing
            return max(min(contentHeight + spacing, maximumRowsHeight), rowHeight)
        }
    }

    struct SyncModifier: ViewModifier {
        let dropdown: ExtensionSearchDropdown?
        let sync: () -> Void

        func body(content: Content) -> some View {
            // The panel is a separate window, so an extension rerender cannot update it by itself.
            content.onChange(of: dropdown) { sync() }
        }
    }
}
