import BrotypistRuntime
import Foundation
import OSLog

public enum InputMethodRuntime {
    public static let logger = Logger(subsystem: "com.ezraapple.brotypist.inputmethod", category: "im")

    @MainActor private static var isSuggestionDriverConfigured = false

    public static func bootstrapExtension() {
        _ = InputController.self
    }

    @MainActor
    public static func configureSuggestionDriver(bundle: Bundle = .main) {
        guard !isSuggestionDriverConfigured else { return }

        let modelURL = defaultModelURL(bundle: bundle)
        logger.info("Loading model path=\(modelURL.path, privacy: .public)")
        let engine = LlamaCompletionEngine(modelURL: modelURL)
        SuggestionDriver.shared.configure(engine: engine)
        isSuggestionDriverConfigured = true
    }

    private static func defaultModelURL(bundle: Bundle) -> URL {
        let modelPath = "Models/qwen3-0.6b-base-q4_k_m.gguf"
        if let resourceURL = bundle.resourceURL {
            let bundledModel = resourceURL.appendingPathComponent(modelPath)
            if FileManager.default.fileExists(atPath: bundledModel.path) {
                return bundledModel
            }
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(modelPath)
    }
}
