import BrotypistCore
import BrotypistRuntime
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
let useStub = arguments.contains("--stub")
let prefixParts = arguments.filter { $0 != "--stub" && $0 != "--model" }
let prefix = prefixParts.isEmpty ? "Can you send" : prefixParts.joined(separator: " ")
let request = SuggestionRequest(prefix: prefix, appName: "brotypistctl", maxPredictionWords: 6)

let engine: any TextCompletionEngine
let llamaEngine: LlamaCompletionEngine?
if useStub {
    engine = StaticCompletionEngine()
    llamaEngine = nil
} else {
    let modelURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Models/Qwen3-0.6B-Q4_K_M.gguf")
    let runtime = LlamaCompletionEngine(modelURL: modelURL)
    engine = runtime
    llamaEngine = runtime
}

let suggestion = try await engine.complete(request: request)
await llamaEngine?.shutdown()

print(suggestion)
