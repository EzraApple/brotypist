import CoreGraphics
import Foundation

public struct FontSpec: Equatable, Sendable {
    public var name: String
    public var pointSize: CGFloat

    public init(name: String, pointSize: CGFloat) {
        self.name = name
        self.pointSize = pointSize
    }
}

/// Hardcoded font hints for apps that don't expose a usable font via AX
/// (Electron/CEF text inputs in particular). The named fonts are chosen to be
/// system-installed AND a close metric match for the app's real font, so that
/// width measurement and rendered ghost-text size both line up.
public enum AppFontHints {
    private static let hints: [String: FontSpec] = [
        "Slack": FontSpec(name: "HelveticaNeue", pointSize: 15),
        "Discord": FontSpec(name: "HelveticaNeue", pointSize: 15),
        "Notion": FontSpec(name: "HelveticaNeue", pointSize: 16),
        "ChatGPT": FontSpec(name: "HelveticaNeue", pointSize: 15),
        "Cursor": FontSpec(name: "Menlo", pointSize: 14),
        "Code": FontSpec(name: "Menlo", pointSize: 14),
        "Visual Studio Code": FontSpec(name: "Menlo", pointSize: 14)
    ]

    public static func hint(for appName: String) -> FontSpec? {
        hints[appName]
    }
}
