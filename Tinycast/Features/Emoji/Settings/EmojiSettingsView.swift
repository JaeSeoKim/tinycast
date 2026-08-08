import SwiftUI

struct EmojiSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        return SettingsPane {
            SettingsCard(
                header: "Global Shortcuts", footer: "Summon the emoji and symbols palette."
            ) {
                SettingsRow(title: "Emoji & Symbols") {
                    ShortcutRecorder(action: .toggleEmoji)
                }
            }

            SettingsCard(
                header: "Appearance",
                footer: "Applied when an emoji supports skin tones; pastes use it too."
            ) {
                SettingsRow(title: "Emoji Skin Tone") {
                    // A hand per tone, quicker to scan than a dropdown of tone names.
                    Picker("", selection: $settings.emojiSkinTone) {
                        ForEach(EmojiSkinTone.allCases) { tone in
                            Text(tone.sample).tag(tone)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
    }
}
