import Testing
@testable import BrotypistCore

@Suite("PromptBuilder")
struct PromptBuilderTests {
    @Test("renders a compact autocomplete prompt around the current line")
    func rendersCompactAutocompletePrompt() {
        let request = SuggestionRequest(
            prefix: "Hey Sarah, can you send",
            appName: "Mail",
            windowTitle: "Reply",
            visualContext: nil,
            maxPredictionWords: 6
        )

        let prompt = PromptBuilder().prompt(for: request)

        #expect(prompt.contains("Continue the user's text at the cursor."))
        #expect(prompt.contains("App: Mail"))
        #expect(prompt.contains("Window: Reply"))
        #expect(prompt.hasSuffix("Hey Sarah, can you send"))
    }

    @Test("omits empty context fields")
    func omitsEmptyContextFields() {
        let request = SuggestionRequest(
            prefix: "Ship it",
            appName: "",
            windowTitle: nil,
            visualContext: "",
            maxPredictionWords: 6
        )

        let prompt = PromptBuilder().prompt(for: request)

        #expect(!prompt.contains("App:"))
        #expect(!prompt.contains("Window:"))
        #expect(!prompt.contains("Visible context:"))
    }
}
