import AppKit

/// Reads the selection and transforms it. Owns no UI and no delivery: whether the result replaces
/// the text is the coordinator's call.
@MainActor
final class QuickActionRunner {
    /// A selection is read over Accessibility and sent whole, so the ceiling is here rather than at
    /// the provider, where it would come back as an opaque context error.
    static let maxSelectionBytes = 32_768

    /// Reads what is selected in `targetApp`, refusing anything a transform must not touch.
    /// Tinycast's own windows are excluded: the palette and Settings are not somebody's document.
    static func selection(in targetApp: NSRunningApplication?) throws -> String {
        // A shortcut press is an explicit gesture, so it may prompt, as snippet expansion does.
        guard Permissions.ensureAccessibility() else { throw QuickActionFailure.needsAccessibility }
        guard let targetApp,
            targetApp.bundleIdentifier != Bundle.main.bundleIdentifier
        else { throw QuickActionFailure.noTarget }

        switch AccessibilityText.read(in: targetApp) {
        case .noFocusedElement:
            throw QuickActionFailure.unreadableApp(targetApp.localizedName ?? "That app")
        case .empty:
            throw QuickActionFailure.noSelection
        case .text(let text):
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw QuickActionFailure.noSelection
            }
            guard text.utf8.count <= maxSelectionBytes else { throw QuickActionFailure.tooLong }
            return text
        }
    }

    /// Drains a provider stream into one string. Quick Actions have no transcript to grow, so a
    /// caller that wants to show progress reads `onDelta`; one that does not simply awaits.
    static func run(
        _ action: QuickAction, selection: String, using provider: any AIProvider,
        targetLanguage: String? = nil,
        onDelta: @MainActor (String) -> Void = { _ in }
    ) async throws -> String {
        let request = AIRequest(
            instructions: QuickActionPrompt.instructions(for: action),
            messages: [
                AIMessage(
                    role: .user,
                    text: QuickActionPrompt.message(
                        for: action, selection: selection, targetLanguage: targetLanguage))
            ],
            maxOutputTokens: maxOutputTokens(for: action, selection: selection))
        var text = ""
        for try await event in provider.stream(request) {
            guard case .text(let delta) = event else { continue }
            text += delta
            onDelta(delta)
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIProviderError.responseFailed("The model returned nothing.")
        }
        return trimmed
    }

    /// A transform returns roughly what it was given; a summary returns less. Both need a ceiling,
    /// because the on-device window counts the prompt and the reply against one budget.
    private static func maxOutputTokens(for action: QuickAction, selection: String) -> Int {
        let approximateTokens = max(selection.count / 3, 64)
        return action == .summarize
            ? min(approximateTokens, 512) : min(approximateTokens * 2, 2_048)
    }
}
