import Foundation

public struct SuggestionSession: Equatable, Sendable {
    public var anchor: String
    public var suggestion: String

    public init(anchor: String, suggestion: String) {
        self.anchor = anchor
        self.suggestion = suggestion
    }

    public func acceptNextWord() -> SuggestionAcceptance {
        let accepted = firstWordWithLeadingWhitespace(from: suggestion)
        guard !accepted.isEmpty else {
            return SuggestionAcceptance(accepted: "", remaining: nil)
        }

        let remainingText = String(suggestion.dropFirst(accepted.count))
        let remainingSession = remainingText.isEmpty
            ? nil
            : SuggestionSession(anchor: anchor + accepted, suggestion: remainingText)

        return SuggestionAcceptance(accepted: accepted, remaining: remainingSession)
    }

    public func reconcile(currentText: String) -> SuggestionSession? {
        guard currentText.hasPrefix(anchor) else { return nil }

        let consumed = String(currentText.dropFirst(anchor.count))
        if consumed.isEmpty {
            return self
        }

        guard suggestion.hasPrefix(consumed) else { return nil }

        let remainingText = String(suggestion.dropFirst(consumed.count))
        guard !remainingText.isEmpty else { return nil }
        return SuggestionSession(anchor: currentText, suggestion: remainingText)
    }

    private func firstWordWithLeadingWhitespace(from text: String) -> String {
        var index = text.startIndex
        while index < text.endIndex, text[index].isWhitespace {
            index = text.index(after: index)
        }
        guard index < text.endIndex else { return "" }

        var end = index
        while end < text.endIndex, !text[end].isWhitespace {
            end = text.index(after: end)
        }

        return String(text[..<end])
    }
}

public struct SuggestionAcceptance: Equatable, Sendable {
    public var accepted: String
    public var remaining: SuggestionSession?

    public init(accepted: String, remaining: SuggestionSession?) {
        self.accepted = accepted
        self.remaining = remaining
    }
}
