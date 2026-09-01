import Foundation

/// Transient search and highlight state for one open extension dropdown.
@MainActor
@Observable
final class ExtensionSearchDropdownSession {
    var text = ""
    var selectedItemID: Int?

    func begin(with dropdown: ExtensionSearchDropdown) {
        text = ""
        selectedItemID = dropdown.selection(matching: "", preserving: nil)
    }

    func normalize(with dropdown: ExtensionSearchDropdown) {
        selectedItemID = dropdown.selection(matching: text, preserving: selectedItemID)
    }

    /// Returns whether the extension needs its externally-owned search reset too.
    func end() -> Bool {
        let hadSearchText = !text.isEmpty
        text = ""
        selectedItemID = nil
        return hadSearchText
    }
}
