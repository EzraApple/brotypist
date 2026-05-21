import Foundation

public struct SuggestionRequest: Equatable, Sendable {
    public var prefix: String
    public var appName: String
    public var windowTitle: String?
    public var visualContext: String?
    public var maxPredictionWords: Int

    public init(
        prefix: String,
        appName: String = "",
        windowTitle: String? = nil,
        visualContext: String? = nil,
        maxPredictionWords: Int = 6
    ) {
        self.prefix = prefix
        self.appName = appName
        self.windowTitle = windowTitle
        self.visualContext = visualContext
        self.maxPredictionWords = max(1, maxPredictionWords)
    }
}
