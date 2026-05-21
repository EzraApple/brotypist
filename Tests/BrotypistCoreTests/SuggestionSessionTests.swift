import Testing
@testable import BrotypistCore

@Suite("SuggestionSession")
struct SuggestionSessionTests {
    @Test("accepts the next word while preserving the remaining suggestion")
    func acceptsNextWord() {
        let session = SuggestionSession(anchor: "Can you", suggestion: " send the invoice")

        let result = session.acceptNextWord()

        #expect(result.accepted == " send")
        #expect(result.remaining?.suggestion == " the invoice")
        #expect(result.remaining?.anchor == "Can you send")
    }

    @Test("advances when the user manually types the visible suggestion prefix")
    func reconcilesTypedPrefix() {
        let session = SuggestionSession(anchor: "Can you", suggestion: " send the invoice")

        let advanced = session.reconcile(currentText: "Can you send")

        #expect(advanced?.suggestion == " the invoice")
        #expect(advanced?.anchor == "Can you send")
    }

    @Test("drops stale suggestions when text diverges")
    func dropsDivergence() {
        let session = SuggestionSession(anchor: "Can you", suggestion: " send the invoice")

        #expect(session.reconcile(currentText: "Can we") == nil)
    }
}
