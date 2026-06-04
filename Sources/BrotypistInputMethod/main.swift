import AppKit
import BrotypistCore
import BrotypistRuntime
import Foundation
import InputMethodKit
import OSLog

let imLogger = Logger(subsystem: "com.ezraapple.brotypist.inputmethod", category: "im")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var server: IMKServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundle = Bundle.main
        let connectionName = (bundle.infoDictionary?["InputMethodConnectionName"] as? String)
            ?? "BrotypistInputMethod_Connection"
        let bundleId = bundle.bundleIdentifier ?? "com.ezraapple.brotypist.inputmethod"

        imLogger.info("Brotypist IM starting connection=\(connectionName, privacy: .public) bundle=\(bundleId, privacy: .public)")

        server = IMKServer(name: connectionName, bundleIdentifier: bundleId)

        let modelURL = Self.defaultModelURL()
        imLogger.info("Loading model path=\(modelURL.path, privacy: .public)")
        let engine = LlamaCompletionEngine(modelURL: modelURL)
        SuggestionDriver.shared.configure(engine: engine)
    }

    private static func defaultModelURL() -> URL {
        let modelPath = "Models/qwen3-0.6b-base-q4_k_m.gguf"
        if let resourceURL = Bundle.main.resourceURL {
            let bundledModel = resourceURL.appendingPathComponent(modelPath)
            if FileManager.default.fileExists(atPath: bundledModel.path) {
                return bundledModel
            }
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(modelPath)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
