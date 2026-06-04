import Foundation

public enum TriggerRules {
    public static func shouldTrigger(_ text: String) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if text.last?.isWhitespace == true { return true }

        var currentWordLength = 0
        for character in text.reversed() {
            if character.isWhitespace { break }
            currentWordLength += 1
        }
        return currentWordLength >= 2
    }

    public static func currentLine(from text: String) -> String {
        text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .last
            .map(String.init) ?? text
    }
}
