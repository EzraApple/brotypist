import CoreGraphics
import Foundation
import Testing
@testable import BrotypistCore

@Suite("CoordinateSpace (fixtures)")
struct CoordinateSpaceTests {
    @Test("quartz_to_appkit cases")
    func quartzToAppKit() throws {
        let file = try FixtureLoader.load(CoordinateSpaceFile.self, resource: "coordinate_space")
        for testCase in file.quartzToAppKit.cases {
            let screens = testCase.input.screens.map { $0.screenSpace }
            let actual = CoordinateSpace.quartzToAppKit(testCase.input.rect.cgRect, screens: screens)
            let expected = testCase.expectedRect.cgRect
            #expect(actual == expected, "[\(testCase.name)] expected \(expected), got \(actual)")
        }
    }

    @Test("screen_containing cases")
    func screenContaining() throws {
        let file = try FixtureLoader.load(CoordinateSpaceFile.self, resource: "coordinate_space")
        for testCase in file.screenContaining.cases {
            let screens = testCase.input.screens.map { $0.screenSpace }
            let actual = CoordinateSpace.screen(containing: testCase.input.rect.cgRect, in: screens)
            switch testCase.expectedScreenIndex {
            case .none:
                #expect(actual == nil, "[\(testCase.name)] expected nil, got \(String(describing: actual))")
            case .some(let index):
                #expect(actual == screens[index], "[\(testCase.name)] expected screens[\(index)], got \(String(describing: actual))")
            }
        }
    }
}

private struct CoordinateSpaceFile: Decodable {
    let quartzToAppKit: QuartzToAppKitGroup
    let screenContaining: ScreenContainingGroup

    enum CodingKeys: String, CodingKey {
        case quartzToAppKit = "quartz_to_appkit"
        case screenContaining = "screen_containing"
    }
}

private struct QuartzToAppKitGroup: Decodable {
    let cases: [QuartzToAppKitCase]
}

private struct QuartzToAppKitCase: Decodable {
    let name: String
    let input: Input
    let expectedRect: FixtureRect

    enum CodingKeys: String, CodingKey {
        case name, input
        case expectedRect = "expected_rect"
    }

    struct Input: Decodable {
        let rect: FixtureRect
        let screens: [FixtureScreen]
    }
}

private struct ScreenContainingGroup: Decodable {
    let cases: [ScreenContainingCase]
}

private struct ScreenContainingCase: Decodable {
    let name: String
    let input: Input
    let expectedScreenIndex: Int?

    enum CodingKeys: String, CodingKey {
        case name, input
        case expectedScreenIndex = "expected_screen_index"
    }

    struct Input: Decodable {
        let rect: FixtureRect
        let screens: [FixtureScreen]
    }
}
