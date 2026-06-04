import CoreGraphics
import Foundation
@testable import BrotypistCore

struct FixtureRect: Decodable {
    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    let h: CGFloat

    var cgRect: CGRect { CGRect(x: x, y: y, width: w, height: h) }
}

struct FixtureSize: Decodable {
    let w: CGFloat
    let h: CGFloat

    var cgSize: CGSize { CGSize(width: w, height: h) }
}

struct FixtureScreen: Decodable {
    let displayBoundsQuartz: FixtureRect
    let appkitFrame: FixtureRect

    enum CodingKeys: String, CodingKey {
        case displayBoundsQuartz = "display_bounds_quartz"
        case appkitFrame = "appkit_frame"
    }

    var screenSpace: ScreenSpace {
        ScreenSpace(
            displayBoundsInQuartz: displayBoundsQuartz.cgRect,
            appKitFrame: appkitFrame.cgRect
        )
    }
}

enum FixtureLoader {
    enum Error: Swift.Error, CustomStringConvertible {
        case missingResource(String)

        var description: String {
            switch self {
            case .missingResource(let name): return "Missing fixture resource: \(name)"
            }
        }
    }

    static func load<T: Decodable>(_ type: T.Type, resource: String) throws -> T {
        guard let url = Bundle.module.url(forResource: resource, withExtension: "json", subdirectory: "Fixtures") else {
            throw Error.missingResource(resource)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
