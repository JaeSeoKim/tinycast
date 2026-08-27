import FoundationModels
import Foundation

/// The on-device route: no key, no endpoint, no request leaving this Mac. It is the only provider
/// with nothing to configure, which is why a first run can select it on the reader's behalf.
struct AppleIntelligenceProvider: AIProvider {
    /// Chat writes fresh prose, where the default filter belongs. A rewrite transforms text the
    /// reader already wrote — which is what the permissive setting exists for — so the caller picks
    /// and a later Quick Fix needs no second provider.
    let guardrails: SystemLanguageModel.Guardrails

    init(guardrails: SystemLanguageModel.Guardrails = .default) {
        self.guardrails = guardrails
    }

    static func status() -> AppleIntelligenceStatus {
        switch SystemLanguageModel.default.availability {
        case .available: return .available
        case .unavailable(.deviceNotEligible): return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled): return .notEnabled
        case .unavailable(.modelNotReady): return .modelNotReady
        @unknown default: return .modelNotReady
        }
    }

    func stream(_ request: AIRequest) -> AIProviderStream {
        AIProviderStream { continuation in
            // Detached like every other provider: generation is the model's work, not the main
            // actor's. The session and its stream are both born here, since `ResponseStream` is
            // `sending` and may not cross an isolation domain.
            let task = Task.detached {
                do {
                    if let message = Self.status().message {
                        throw AIProviderError.unavailable(message)
                    }
                    let turn = Self.turn(for: request)
                    guard let prompt = turn.prompt else {
                        throw AIProviderError.responseFailed("There was nothing to send.")
                    }
                    let session = LanguageModelSession(
                        model: SystemLanguageModel(guardrails: guardrails),
                        transcript: turn.transcript)
                    let options = GenerationOptions(
                        maximumResponseTokens: min(
                            request.maxOutputTokens, AppleIntelligence.maxOutputTokens))
                    var delta = AppleIntelligenceDelta()
                    for try await snapshot in session.streamResponse(to: prompt, options: options) {
                        try Task.checkCancellation()
                        let text = delta.delta(from: snapshot.content)
                        if !text.isEmpty { continuation.yield(.text(text)) }
                    }
                    continuation.yield(.finished)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch let error as LanguageModelSession.GenerationError {
                    continuation.finish(throwing: Self.providerError(error))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// A request split the way a session takes it: the newest user turn is the prompt, everything
    /// ahead of it is the transcript the session resumes from. Pictures are dropped — the model is
    /// text-only, and `AIModelCapabilities` already stops the composer offering one.
    static func turn(for request: AIRequest) -> (prompt: String?, transcript: Transcript) {
        var entries: [Transcript.Entry] = []
        if let instructions = request.instructions, !instructions.isEmpty {
            entries.append(
                .instructions(
                    Transcript.Instructions(
                        segments: [.text(Transcript.TextSegment(content: instructions))],
                        toolDefinitions: [])))
        }
        let promptIndex = request.messages.lastIndex { $0.role == .user }
        for message in request.messages[..<(promptIndex ?? request.messages.endIndex)]
        where !message.text.isEmpty {
            let segment = Transcript.Segment.text(Transcript.TextSegment(content: message.text))
            switch message.role {
            case .user:
                entries.append(.prompt(Transcript.Prompt(segments: [segment])))
            case .assistant:
                entries.append(.response(Transcript.Response(assetIDs: [], segments: [segment])))
            case .system:
                continue
            }
        }
        let prompt = promptIndex.map {
            request.messages[$0].text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return (prompt?.isEmpty == true ? nil : prompt, Transcript(entries: entries))
    }

    /// Plain sentences rather than the framework's own copy: a `Context`'s `debugDescription` is
    /// written for a log, and it is the only detail these errors carry.
    static func providerError(_ error: LanguageModelSession.GenerationError) -> AIProviderError {
        switch error {
        case .exceededContextWindowSize:
            return .responseFailed(
                "This conversation is longer than the on-device model can hold. Start a new chat.")
        case .guardrailViolation, .refusal:
            return .responseFailed("Apple Intelligence declined to answer that.")
        case .unsupportedLanguageOrLocale:
            return .responseFailed("Apple Intelligence does not support this language yet.")
        case .assetsUnavailable:
            return .unavailable("Apple Intelligence is still downloading its model.")
        case .rateLimited:
            return .responseFailed("Apple Intelligence is busy. Try again shortly.")
        case .concurrentRequests:
            return .responseFailed("Apple Intelligence is already answering. Try again shortly.")
        case .decodingFailure, .unsupportedGuide:
            return .malformedResponse
        @unknown default:
            return .responseFailed("Apple Intelligence could not complete the response.")
        }
    }
}
