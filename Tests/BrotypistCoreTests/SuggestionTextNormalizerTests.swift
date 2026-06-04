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

    @Test("rejects suggestions that just repeat text from the input")
    func rejectsParrotedInput() {
        let output = SuggestionTextNormalizer.normalize(
            "Lorem ipsum dolor",
            input: "Lorem ipsum dolor sit amet"
        )

        #expect(output.isEmpty)
    }

    @Test("rejects suggestions that exactly echo the user's tail")
    func rejectsTailEcho() {
        let output = SuggestionTextNormalizer.normalize(
            "the system is",
            input: "I think the system is"
        )

        #expect(output.isEmpty)
    }

    @Test("strips repeated tail-words from the front of a continuation")
    func stripsPrefixOverlap() {
        let output = SuggestionTextNormalizer.normalize(
            "the system is good",
            input: "I think the system is"
        )

        #expect(output == "good")
    }

    @Test("strips a single repeated word when the model echoes the last token")
    func stripsSingleWordEcho() {
        let output = SuggestionTextNormalizer.normalize(
            "think we should ship",
            input: "I think"
        )

        #expect(output == "we should ship")
    }
}
