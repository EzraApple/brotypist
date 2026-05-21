import Testing
@testable import BrotypistCore

@Suite("SuggestionTextNormalizer")
struct SuggestionTextNormalizerTests {
    @Test("keeps a needed leading space when completing a partial sentence")
    func keepsLeadingSpaceWhenNeeded() {
        let output = SuggestionTextNormalizer.normalize(" the invoice tonight.", input: "Can you send")

        #expect(output == " the invoice tonight")
    }

    @Test("trims chatty model boilerplate")
    func rejectsBoilerplate() {
        let output = SuggestionTextNormalizer.normalize("Assistant: sure, here is a continuation", input: "Can you")

        #expect(output.isEmpty)
    }

    @Test("limits autocomplete to requested word count")
    func limitsWordCount() {
        let output = SuggestionTextNormalizer.normalize(
            " this should only return a few words for now",
            input: "I think",
            maxWords: 4
        )

        #expect(output == " this should only return")
    }
}
