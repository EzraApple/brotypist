import CoreGraphics
import Foundation
import Testing
@testable import BrotypistCore

@Suite("OverlayLayout (fixtures)")
struct OverlayLayoutTests {
    @Test("overlay_layout.json cases")
    func runFixtures() throws {
        let file = try FixtureLoader.load(OverlayLayoutFile.self, resource: "overlay_layout")
        for testCase in file.cases {
            let actual = OverlayLayout.frame(
                caretRect: testCase.input.caretRect.cgRect,
                suggestionSize: testCase.input.suggestionSize.cgSize,
                visibleFrame: testCase.input.visibleFrame?.cgRect
            )
            let expected = testCase.expectedFrame.cgRect
            #expect(actual == expected, "[\(testCase.name)] expected \(expected), got \(actual)")
        }
    }

    @Test("fallback_caret.json cases")
    func fallbackCaretFixtures() throws {
        let file = try FixtureLoader.load(FallbackCaretFile.self, resource: "fallback_caret")
        for testCase in file.cases {
            let actual = OverlayLayout.fallbackCaret(
                elementFrame: testCase.input.elementFrame.cgRect,
                cursorTextWidth: testCase.input.cursorTextWidth
            )
            let expected = testCase.expectedCaret.cgRect
            #expect(actual == expected, "[\(testCase.name)] expected \(expected), got \(actual)")
        }
    }
}

private struct FallbackCaretFile: Decodable {
    let cases: [FallbackCaretCase]
}

private struct FallbackCaretCase: Decodable {
    let name: String
    let input: Input
    let expectedCaret: FixtureRect

    enum CodingKeys: String, CodingKey {
        case name, input
        case expectedCaret = "expected_caret"
    }

    struct Input: Decodable {
        let elementFrame: FixtureRect
        let cursorTextWidth: CGFloat

        enum CodingKeys: String, CodingKey {
            case elementFrame = "element_frame"
            case cursorTextWidth = "cursor_text_width"
        }
    }
}

private struct OverlayLayoutFile: Decodable {
    let cases: [OverlayLayoutCase]
}

private struct OverlayLayoutCase: Decodable {
    let name: String
    let input: Input
    let expectedFrame: FixtureRect

    enum CodingKeys: String, CodingKey {
        case name, input
        case expectedFrame = "expected_frame"
    }

    struct Input: Decodable {
        let caretRect: FixtureRect
        let suggestionSize: FixtureSize
        let visibleFrame: FixtureRect?

        enum CodingKeys: String, CodingKey {
            case caretRect = "caret_rect"
            case suggestionSize = "suggestion_size"
            case visibleFrame = "visible_frame"
        }
    }
}
