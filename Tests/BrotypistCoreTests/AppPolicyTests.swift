import Foundation
import Testing
@testable import BrotypistCore

@Suite("AppPolicy (fixtures)")
struct AppPolicyTests {
    @Test("is_denied cases")
    func isDenied() throws {
        let file = try FixtureLoader.load(AppPolicyFile.self, resource: "app_policy")
        for testCase in file.isDenied.cases {
            let actual = AppPolicy.isDenied(appName: testCase.input)
            #expect(actual == testCase.expected, "[\(testCase.name)] expected \(testCase.expected), got \(actual)")
        }
    }
}

private struct AppPolicyFile: Decodable {
    let isDenied: BoolGroup

    enum CodingKeys: String, CodingKey {
        case isDenied = "is_denied"
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
