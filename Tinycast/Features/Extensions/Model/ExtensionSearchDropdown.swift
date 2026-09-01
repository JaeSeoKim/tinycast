import Foundation

struct ExtensionSearchDropdown: Sendable, Equatable {
    struct Item: Sendable, Equatable, Identifiable {
        let id: Int
        let title: String
        let value: String
        let icon: RenderValue?
        let keywords: [String]
    }

    struct Section: Sendable, Equatable {
        let title: String?
        let items: [Item]
    }

    private struct RankedItem {
        let item: Item
        let score: Int
        let index: Int
    }

    private struct RankedSection {
        let section: Section
        let score: Int
        let index: Int
    }

    let tooltip: String?
    let placeholder: String
    let value: String?
    let handler: String?
    let searchHandler: String?
    let filtersLocally: Bool
    let keepsSectionOrder: Bool
    let isLoading: Bool
    let sections: [Section]
    let items: [Item]

    init?(_ node: RenderNode?) {
        guard let node, node.type == "List.Dropdown" || node.type == "Grid.Dropdown" else {
            return nil
        }
        let itemType = node.type + ".Item"
        let sectionType = node.type + ".Section"
        func items(in nodes: [RenderNode], sectionTitle: String? = nil) -> [Item] {
            ExtensionSearchDropdown.itemNodes(in: nodes, type: itemType).compactMap { node in
                guard let value = node.string("value") else { return nil }
                let keywords = node.props["keywords"] == nil
                    ? [sectionTitle].compactMap { $0 }
                    : node.array("keywords").compactMap(\.stringValue)
                return Item(
                    id: node.id,
                    title: node.string("title") ?? value,
                    value: value,
                    icon: node.props["icon"],
                    keywords: keywords)
            }
        }
        var sections: [Section] = []
        var unsectioned: [RenderNode] = []
        func appendUnsectioned() {
            let parsed = items(in: unsectioned)
            if !parsed.isEmpty { sections.append(Section(title: nil, items: parsed)) }
            unsectioned.removeAll(keepingCapacity: true)
        }
        for child in node.children {
            if child.type == sectionType {
                appendUnsectioned()
                let title = child.string("title")
                let parsed = items(in: child.children, sectionTitle: title)
                if !parsed.isEmpty {
                    sections.append(Section(title: title, items: parsed))
                }
            } else {
                unsectioned.append(child)
            }
        }
        appendUnsectioned()
        let items = sections.flatMap(\.items)
        tooltip = node.string("tooltip")
        placeholder = node.string("placeholder") ?? "Search…"
        value = node.string("value")
        handler = node.handler("onTinycastChange")
        searchHandler = node.handler("onTinycastSearchTextChange")
        filtersLocally = node.bool("filtering") ?? (node.object("filtering") != nil || searchHandler == nil)
        keepsSectionOrder =
            node.object("filtering")?["keepSectionOrder"]?.boolValue ?? false
        isLoading = node.bool("isLoading") ?? false
        self.sections = sections
        self.items = items
    }

    var selectedItemID: Int? { items.first { $0.value == value }?.id }

    func activationIndex(for itemID: Int) -> Int? {
        items.firstIndex { $0.id == itemID }
    }

    var title: String {
        items.first { $0.value == value }?.title ?? items.first?.title ?? "Filter"
    }

    func sections(matching query: String) -> [Section] {
        let needle = FuzzyMatch.Query(query.trimmingCharacters(in: .whitespaces))
        guard filtersLocally, !needle.isEmpty else { return sections }
        var rankedSections: [RankedSection] = []
        rankedSections.reserveCapacity(sections.count)
        for (sectionIndex, section) in sections.enumerated() {
            var rankedItems: [RankedItem] = []
            rankedItems.reserveCapacity(section.items.count)
            for (itemIndex, item) in section.items.enumerated() {
                guard let itemScore = score(item, against: needle) else { continue }
                rankedItems.append(RankedItem(item: item, score: itemScore, index: itemIndex))
            }
            rankedItems.sort {
                $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index
            }
            guard let bestScore = rankedItems.first?.score else { continue }
            rankedSections.append(
                RankedSection(
                    section: Section(title: section.title, items: rankedItems.map { $0.item }),
                    score: bestScore,
                    index: sectionIndex))
        }
        if !keepsSectionOrder {
            rankedSections.sort {
                $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index
            }
        }
        return rankedSections.map { $0.section }
    }

    func selection(matching query: String, preserving selectedItemID: Int?) -> Int? {
        let visibleItems = sections(matching: query).flatMap(\.items)
        if let selectedItemID, visibleItems.contains(where: { $0.id == selectedItemID }) {
            return selectedItemID
        }
        if let renderedSelection = self.selectedItemID,
            visibleItems.contains(where: { $0.id == renderedSelection })
        {
            return renderedSelection
        }
        return visibleItems.first?.id
    }

    private func score(_ item: Item, against needle: FuzzyMatch.Query) -> Int? {
        ([item.title] + item.keywords).compactMap {
            FuzzyMatch.score(needle, candidate: $0)
        }.max()
    }

    private static func itemNodes(in nodes: [RenderNode], type: String) -> [RenderNode] {
        nodes.flatMap { node -> [RenderNode] in
            node.type == type ? [node] : itemNodes(in: node.children, type: type)
        }
    }
}
