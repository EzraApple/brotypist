import Foundation

public struct PromptBuilder: Sendable {
    public init() {}

    public func prompt(for request: SuggestionRequest) -> String {
        var lines: [String] = [
            "Continue the user's text at the cursor.",
            "Return only the next few words. Do not answer, explain, quote, or add labels.",
            "Maximum words: \(request.maxPredictionWords)."
        ]

        let appName = request.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !appName.isEmpty {
            lines.append("App: \(appName)")
        }

        if let windowTitle = request.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !windowTitle.isEmpty {
            lines.append("Window: \(windowTitle)")
        }

        if let visualContext = request.visualContext?.trimmingCharacters(in: .whitespacesAndNewlines),
           !visualContext.isEmpty {
            lines.append("Visible context:")
            lines.append(visualContext)
        }

        lines.append("")
        lines.append(request.prefix)
        return lines.joined(separator: "\n")
    }
}
