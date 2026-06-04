import Foundation

public enum AppPolicy {
    public static let deniedApps: Set<String> = [
        "Terminal",
        "iTerm",
        "iTerm2",
        "Ghostty",
        "Alacritty",
        "WezTerm",
        "Kitty",
        "Warp",
        "Hyper",
        "Tabby"
    ]

    public static func isDenied(appName: String) -> Bool {
        deniedApps.contains(appName)
    }
}
