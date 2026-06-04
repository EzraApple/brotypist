import Foundation

public struct PromptBuilder: Sendable {
    public init() {}

    public func prompt(for request: SuggestionRequest) -> String {
        // Base-model continuation: feed a handful of short, casual examples in
        // the target register, then the live prefix. No instruction header — the
        // pattern in the examples teaches the model what to produce. An App: tag
        // would just pull a 0.6B model toward off-topic brand associations.
        var lines = Self.examples
        lines.append(request.prefix)
        return lines.joined(separator: "\n")
    }

    // Examples deliberately avoid common message openers (Hey/I think/Can you/
    // Thanks/Sounds good) so a 0.6B model can't trivially copy a continuation
    // when the user types one of those openers.
    private static let examples: [String] = [
        "Let me know once the deploy finishes.",
        "Forecast says rain through Tuesday.",
        "We can sync on it next week if that works.",
        "Quick note before the meeting starts."
    ]
}
