import Foundation
import NaturalLanguage
import Translation

/// Translation goes through Apple's translator rather than the language model: it is free on every
/// route, it runs on device, and a 3B model is markedly worse at it.
///
/// `TranslationError` is annotated macOS 26.4 while the deployment floor is 26.0, so failures are
/// caught as plain `Error` and reported by what was asked rather than by matching its cases.
enum TextTranslator {
    enum Failure: LocalizedError, Equatable {
        case undetectableSource
        case unsupported
        case notInstalled(language: String)
        case failed

        var errorDescription: String? {
            switch self {
            case .undetectableSource:
                return "The language of the selected text could not be identified."
            case .unsupported:
                return "Apple's translator does not support this language pair."
            case .notInstalled(let language):
                return "\(language) needs to be downloaded before it can be used."
            case .failed:
                return "The text could not be translated."
            }
        }
    }

    /// `TranslationSession(installedSource:target:)` needs a concrete source, and
    /// `LanguageAvailability` reports only a status, so the language itself comes from here.
    static func sourceLanguage(of text: String) -> Locale.Language? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let dominant = recognizer.dominantLanguage, dominant != .undetermined else {
            return nil
        }
        return Locale.Language(identifier: dominant.rawValue)
    }

    /// What the caller can do with this pair right now: translate it, offer the download, or say no.
    static func status(from source: Locale.Language, to target: Locale.Language) async
        -> LanguageAvailability.Status
    {
        await LanguageAvailability().status(from: source, to: target)
    }

    /// Only ever translates an already-installed pair. Fetching one needs SwiftUI's
    /// `translationTask`, which is why an uninstalled pair opens the panel instead of silently
    /// replacing the reader's text once a download they never saw has finished.
    static func translate(_ text: String, to target: Locale.Language) async throws -> String {
        guard let source = sourceLanguage(of: text) else { throw Failure.undetectableSource }
        guard !source.isEquivalent(to: target) else { return text }
        switch await status(from: source, to: target) {
        case .installed:
            break
        case .supported:
            throw Failure.notInstalled(language: displayName(of: target))
        case .unsupported:
            throw Failure.unsupported
        @unknown default:
            throw Failure.unsupported
        }
        do {
            let session = TranslationSession(installedSource: source, target: target)
            return try await session.translate(text).targetText
        } catch {
            throw Failure.failed
        }
    }

    /// Minimal, not maximal: the maximal form carries the script, so `es` would read
    /// "Spanish (Latin, Spain)" in a menu where the reader expects "Spanish".
    static func displayName(of language: Locale.Language) -> String {
        Locale.current.localizedString(forIdentifier: language.minimalIdentifier)
            ?? language.minimalIdentifier
    }

    /// What Apple's translator can actually reach, so the picker cannot offer a language that only
    /// fails at press time. 47 of them as of macOS 26, and the list is the framework's to change.
    static func supportedLanguages() async -> [Locale.Language] {
        await LanguageAvailability().supportedLanguages
            .sorted { displayName(of: $0) < displayName(of: $1) }
    }
}
