import Foundation
import Testing
@testable import BrotypistCore

@Suite("TriggerRules (fixtures)")
struct TriggerRulesTests {
    @Test("should_trigger cases")
    func shouldTrigger() throws {
        let file = try FixtureLoader.load(TriggerRulesFile.self, resource: "trigger_rules")
        for testCase in file.shouldTrigger.cases {
            let actual = TriggerRules.shouldTrigger(testCase.input)
            #expect(actual == testCase.expected, "[\(testCase.name)] expected \(testCase.expected), got \(actual) for input \(testCase.input.debugDescription)")
        }
    }

    @Test("current_line cases")
    func currentLine() throws {
        let file = try FixtureLoader.load(TriggerRulesFile.self, resource: "trigger_rules")
        for testCase in file.currentLine.cases {
            let actual = TriggerRules.currentLine(from: testCase.input)
            #expect(actual == testCase.expected, "[\(testCase.name)] expected \(testCase.expected.debugDescription), got \(actual.debugDescription) for input \(testCase.input.debugDescription)")
        }
    }
}

private struct TriggerRulesFile: Decodable {
    let shouldTrigger: BoolGroup
    let currentLine: StringGroup

    enum CodingKeys: String, CodingKey {
        case shouldTrigger = "should_trigger"
        case currentLine = "current_line"
    }
}

private struct BoolGroup: Decodable {
    let cases: [BoolCase]
}

private struct BoolCase: Decodable {
    let name: String
    let input: String
    let expected: Bool
}

private struct StringGroup: Decodable {
    let cases: [StringCase]
}

private struct StringCase: Decodable {
    let name: String
    let input: String
    let expected: String
}
