import AppKit
import Carbon.HIToolbox
import SwiftUI

enum ASCIIKeyboardLayout {
    @MainActor static func character(for keyCode: Int) -> String? {
        guard
            let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?
                .takeRetainedValue(),
            let layoutDataPointer = TISGetInputSourceProperty(
                source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let layoutData = unsafeBitCast(layoutDataPointer, to: CFData.self)
        let keyLayout = unsafeBitCast(
            CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)

        let error = UCKeyTranslate(
            keyLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            characters.count,
            &length,
            &characters
        )
        guard error == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length)
    }

    /// SwiftUI exposes the input-source character; recover the logical ASCII key from AppKit.
    @MainActor static func keyEquivalent(fallingBackTo key: KeyEquivalent) -> KeyEquivalent {
        guard let event = NSApp.currentEvent,
            !event.modifierFlags.isDisjoint(with: [.command, .control]),
            let character = character(for: Int(event.keyCode))?.lowercased().first,
            character.unicodeScalars.allSatisfy(\.isASCII)
        else { return key }
        return KeyEquivalent(character)
    }

    @MainActor static func matches(_ key: KeyEquivalent, character: Character) -> Bool {
        keyEquivalent(fallingBackTo: key) == KeyEquivalent(character)
    }
}
