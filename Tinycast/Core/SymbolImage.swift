import SwiftUI

/// An SF Symbol that falls back to a bundled template asset of the same name. Not every glyph the
/// command catalogs name is a system symbol — `SystemCommand.toggleBluetooth` ships its own artwork
/// because the logo is a SIG trademark — and a raw `Image(systemName:)` renders nothing for those.
/// The size is explicit rather than inherited from the font context so both branches land at the
/// same optical weight.
struct SymbolImage: View {
    let name: String
    let size: CGFloat

    var body: some View {
        if NSImage(systemSymbolName: name, accessibilityDescription: nil) == nil {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: name)
                .font(.system(size: size, weight: .regular))
                .symbolRenderingMode(.hierarchical)
        }
    }
}
