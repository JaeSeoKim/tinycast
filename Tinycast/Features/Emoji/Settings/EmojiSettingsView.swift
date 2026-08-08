import SwiftUI

struct EmojiSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        return SettingsPane {
            SettingsCard(header: "Global Shortcuts") {
                SettingsRow(
                    title: "Emoji & Symbols",
                    subtitle: "Summon the emoji and symbols palette."
                ) {
                    ShortcutRecorder(action: .toggleEmoji)
                }
            }

            SettingsCard(header: "Appearance") {
                SettingsRow(
                    title: "Emoji Skin Tone",
                    subtitle: "Applied when an emoji supports skin tones; pastes use it too."
                ) {
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
