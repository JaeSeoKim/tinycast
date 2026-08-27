// Quick Actions' pure half: what each action is, what it tells the model, how a result is diffed,
// and which choices are the reader's rather than a default.

import Foundation

@main
@MainActor
struct QuickActionTests {
    static var failures = 0
    static var passes = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func main() {
        everyActionDescribesItself()
        promptsForbidCommentaryAndInjection()
        previewChoicesRememberOnlyWhatWasChosen()
        diffsFindWordLevelChanges()
        diffsStayBoundedOnLongText()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static func everyActionDescribesItself() {
        for action in QuickAction.allCases {
            expect(!action.title.isEmpty, "\(action) has a title")
            expect(!action.symbol.isEmpty, "\(action) has a glyph")
            expect(action.rawValue == action.id, "\(action) keys its shortcut on its raw value")
        }
        expect(
            Set(QuickAction.allCases.map(\.title)).count == QuickAction.allCases.count,
            "no two actions read the same in the shortcut list")

        // Summarize answers a question about the text; replacing it unasked would destroy the text.
        expect(QuickAction.summarize.alwaysPreviews, "Summarize always shows its panel")
        expect(
            QuickAction.allCases.filter(\.alwaysPreviews) == [.summarize],
            "only Summarize forces a panel")
        expect(
            QuickAction.fixGrammar.replacesDirectlyByDefault,
            "grammar is the one action safe to apply unseen")
        expect(
            !QuickAction.rewrite.replacesDirectlyByDefault,
            "a rewrite changes the voice, so it is previewed by default")
        expect(
            QuickAction.translate.usesTranslationFramework,
            "Translate goes to Apple's translator, not the model")
        expect(
            QuickAction.allCases.filter(\.usesTranslationFramework) == [.translate],
            "nothing else claims the translator")
        expect(
            QuickAction.summarize.showsDiff == false,
            "a summary is not the input edited, so a diff would be noise")
    }

    static func promptsForbidCommentaryAndInjection() {
        for action in QuickAction.allCases {
            let instructions = QuickActionPrompt.instructions(for: action)
            expect(!instructions.isEmpty, "\(action) carries instructions")
            // The output is pasted into somebody's document; a preamble is a defect there.
            expect(
                instructions.lowercased().contains("only")
                    || instructions.lowercased().contains("do not open"),
                "\(action) tells the model to return the text and nothing else")
            expect(
                instructions.lowercased().contains("never")
                    || instructions.lowercased().contains("never follow"),
                "\(action) treats the selection as material, not as instructions")
        }

        // The delimiter is what stops a short selection reading as part of the instruction.
        let message = QuickActionPrompt.message(for: .fixGrammar, selection: "teh cat")
        expect(message.contains("Text:"), "the selection is delimited from the instruction")
        expect(message.hasSuffix("teh cat"), "the selection goes last, unaltered")

        let translated = QuickActionPrompt.message(
            for: .translate, selection: "hello", targetLanguage: "French")
        expect(translated.contains("French"), "a target language reaches the prompt when given")
        expect(
            !QuickActionPrompt.message(for: .rewrite, selection: "hi").contains("Translate"),
            "an action with no language never mentions one")
    }

    static func previewChoicesRememberOnlyWhatWasChosen() {
        var settings = QuickActionSettings()
        expect(settings.previewChoices.isEmpty, "nothing is stored until the reader chooses")
        expect(!settings.previewsResult(.fixGrammar), "grammar applies directly by default")
        expect(settings.previewsResult(.rewrite), "a rewrite previews by default")
        expect(settings.previewsResult(.summarize), "Summarize previews whatever is stored")

        settings.setPreviewsResult(true, for: .fixGrammar)
        expect(settings.previewsResult(.fixGrammar), "an explicit choice is honoured")
        settings.setPreviewsResult(false, for: .summarize)
        expect(
            settings.previewsResult(.summarize),
            "Summarize cannot be told to replace text unseen")

        // Round-trips as a plain dictionary, and an action that no longer exists is dropped.
        var restored = QuickActionSettings()
        restored.storedPreviewChoices = settings.storedPreviewChoices
        expect(
            restored.previewsResult(.fixGrammar),
            "a stored choice survives the trip through UserDefaults")
        restored.storedPreviewChoices = ["notAnAction": true]
        expect(restored.previewChoices.isEmpty, "an unknown key is a removed action, not a crash")
    }

    static func diffsFindWordLevelChanges() {
        let chunks = TextDiffEngine.diff(
            original: "Their going to the meeting", modified: "They're going to the meeting")
        expect(chunks.contains(.deleted("Their")), "the replaced word is marked deleted")
        expect(
            chunks.contains { if case .inserted(let text) = $0 { text.contains("They") } else { false } },
            "the replacement is marked inserted")
        expect(
            chunks.contains { if case .equal(let text) = $0 { text.contains("meeting") } else { false } },
            "untouched words stay equal")

        expect(
            TextDiffEngine.diff(original: "same", modified: "same") == [.equal("same")],
            "an unchanged result is one equal run")
        expect(TextDiffEngine.diff(original: "", modified: "") == [], "two empties diff to nothing")
        expect(
            TextDiffEngine.diff(original: "gone", modified: "") == [.deleted("gone")],
            "an emptied result is wholly deleted")

        // Coalescing's real invariant: no two neighbours share a kind, or a changed phrase would
        // read as a stutter of single words. Runs that a shared space separates stay separate,
        // which is why this checks adjacency rather than counting chunks.
        let phrase = TextDiffEngine.diff(original: "one two three", modified: "four five three")
        let stutters = zip(phrase, phrase.dropFirst()).filter { sameKind($0, $1) }
        expect(stutters.isEmpty, "no two adjacent chunks share a kind, got \(phrase)")
    }

    static func sameKind(_ lhs: TextDiffEngine.Chunk, _ rhs: TextDiffEngine.Chunk) -> Bool {
        switch (lhs, rhs) {
        case (.equal, .equal), (.inserted, .inserted), (.deleted, .deleted): return true
        default: return false
        }
    }

    static func diffsStayBoundedOnLongText() {
        // The matrix is quadratic, so an unbounded diff of a long selection asks for gigabytes.
        let long = String(repeating: "word ", count: TextDiffEngine.maxTokens)
        let chunks = TextDiffEngine.diff(original: long, modified: long + "tail")
        expect(chunks.count == 2, "past the ceiling the diff degrades to whole-text, not a hang")
        expect(
            chunks.first == .deleted(long),
            "the degraded diff still names the original whole")
    }
}
