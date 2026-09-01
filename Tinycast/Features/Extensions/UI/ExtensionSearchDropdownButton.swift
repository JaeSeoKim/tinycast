import SwiftUI

struct ExtensionSearchDropdownButton: View {
    let title: String
    let isOpen: Bool
    let help: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.barControl, style: .continuous)
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                SymbolImage(name: "line.3.horizontal.decrease", size: Metrics.leadingIconSize)
                    .accessibilityHidden(true)
                Text(title)
                    .font(Theme.Typography.bar)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: Metrics.titleWidth)
                SymbolImage(
                    name: isOpen ? "chevron.up" : "chevron.down",
                    size: Metrics.disclosureIconSize
                )
                .accessibilityHidden(true)
            }
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.md)
            .frame(height: Theme.Size.barButtonHeight)
            .contentShape(shape)
            .background(shape.fill(hovered ? Theme.Colors.rowHover : Color.clear))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(help)
        .accessibilityLabel(help)
        .accessibilityValue(title)
        .fixedSize(horizontal: true, vertical: false)
    }

    private enum Metrics {
        static let leadingIconSize: CGFloat = 13
        static let disclosureIconSize: CGFloat = 10
        static let titleWidth: CGFloat = 160
    }
}
