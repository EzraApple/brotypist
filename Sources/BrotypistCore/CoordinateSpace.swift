import CoreGraphics
import Foundation

public struct ScreenSpace: Equatable, Sendable {
    public var displayBoundsInQuartz: CGRect
    public var appKitFrame: CGRect

    public init(displayBoundsInQuartz: CGRect, appKitFrame: CGRect) {
        self.displayBoundsInQuartz = displayBoundsInQuartz
        self.appKitFrame = appKitFrame
    }
}

public enum CoordinateSpace {
    public static func quartzToAppKit(_ rect: CGRect, screens: [ScreenSpace]) -> CGRect {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for screen in screens {
            if screen.displayBoundsInQuartz.contains(center) {
                return CGRect(
                    x: rect.origin.x - screen.displayBoundsInQuartz.origin.x + screen.appKitFrame.origin.x,
                    y: (screen.displayBoundsInQuartz.origin.y + screen.displayBoundsInQuartz.height)
                        - (rect.origin.y + rect.height)
                        + screen.appKitFrame.origin.y,
                    width: rect.width,
                    height: rect.height
                )
            }
        }
        return rect
    }

    public static func screen(containing rect: CGRect, in screens: [ScreenSpace]) -> ScreenSpace? {
        let candidates = [
            CGPoint(x: rect.midX, y: rect.midY),
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]
        return screens.first { screen in
            candidates.contains { screen.appKitFrame.insetBy(dx: -4, dy: -4).contains($0) }
        }
    }
}
