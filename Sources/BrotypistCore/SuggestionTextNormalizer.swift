import Foundation

public enum SuggestionTextNormalizer {
    public static func normalize(
        _ raw: String,
        input: String,
        maxWords: Int = 6
    ) -> String {
        guard !raw.isEmpty else { return "" }

        let hadLeadingWhitespace = raw.first?.isWhitespace == true
        var cleaned = raw
            .replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")

        cleaned = String(cleaned.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
        })
        cleaned = cleaned
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`.,;:!?()[]{}<>/\\"))

        guard !cleaned.isEmpty else { return "" }

        let lowered = cleaned.lowercased()
        let blockedPrefixes = [
            "assistant:",
            "user:",
            "system:",
            "sure,",
            "here is",
            "here's",
            "i can"
        ]
        if blockedPrefixes.contains(where: { lowered.hasPrefix($0) }) {
            return ""
        }

        let blockedFragments = [
            "as an ai",
            "the user",
            "continuation:",
            "next words:",
            "<|im_",
            "<cursor"
        ]
        if blockedFragments.contains(where: { lowered.contains($0) }) {
            return ""
        }

        let words = cleaned.split { $0.isWhitespace || $0.isNewline }
        guard !words.isEmpty else { return "" }
        if words.count > maxWords {
            cleaned = words.prefix(maxWords).joined(separator: " ")
        }

        let suggestionLower = cleaned.lowercased()
        if !suggestionLower.isEmpty, input.lowercased().contains(suggestionLower) {
            return ""
        }

        // Aggressive prefix-overlap strip: if the suggestion's first N words
        // (N ≤ 6) match the input's last N words case-insensitively, drop them
        // so only the new continuation remains.
        cleaned = stripPrefixOverlap(suggestion: cleaned, input: input)
        guard !cleaned.isEmpty else { return "" }

        let inputEndsWithWhitespace = input.last?.isWhitespace ?? false
        if hadLeadingWhitespace, !inputEndsWithWhitespace {
            return " " + cleaned
        }
        return cleaned
    }

    private static func stripPrefixOverlap(suggestion: String, input: String) -> String {
        let inputWords = input.split { $0.isWhitespace || $0.isNewline }.map(String.init)
        let suggestionWords = suggestion.split { $0.isWhitespace || $0.isNewline }.map(String.init)
        guard !inputWords.isEmpty, !suggestionWords.isEmpty else { return suggestion }

        let maxOverlap = min(6, inputWords.count, suggestionWords.count)
        for k in stride(from: maxOverlap, through: 1, by: -1) {
            let inputTail = inputWords.suffix(k).map { $0.lowercased() }
            let suggestionHead = suggestionWords.prefix(k).map { $0.lowercased() }
            if inputTail == suggestionHead {
                return suggestionWords.dropFirst(k).joined(separator: " ")
            }
        }
        return suggestion
    }
}
