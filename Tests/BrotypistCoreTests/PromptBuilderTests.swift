import Testing
@testable import BrotypistCore

@Suite("PromptBuilder")
struct PromptBuilderTests {
    @Test("prefix is the final line of the prompt")
    func prefixIsLastLine() {
        let request = SuggestionRequest(prefix: "Hey Sarah, can you send")
        let prompt = PromptBuilder().prompt(for: request)
        #expect(prompt.hasSuffix("Hey Sarah, can you send"))
    }

    @Test("drops instruction header and app/window tags")
    func dropsInstructionAndTags() {
        let request = SuggestionRequest(
            prefix: "Ship it",
            appName: "Mail",
            windowTitle: "Reply",
            visualContext: "ignored"
        )
        let prompt = PromptBuilder().prompt(for: request)
        #expect(!prompt.contains("Continue the user"))
        #expect(!prompt.contains("App:"))
        #expect(!prompt.contains("Window:"))
        #expect(!prompt.contains("Visible context"))
    }

    @Test("includes few-shot examples before the prefix")
    func includesFewShotExamples() {
        let request = SuggestionRequest(prefix: "Ship it")
        let prompt = PromptBuilder().prompt(for: request)
        let lines = prompt.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count >= 3)
        #expect(lines.last.map(String.init) == "Ship it")
    }
}
