import BrotypistCore
import Foundation
import LlamaSwift

public protocol TextCompletionEngine: Sendable {
    func complete(request: SuggestionRequest) async throws -> String
}

public enum CompletionEngineError: Error, LocalizedError {
    case modelUnavailable(String)
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelUnavailable(let message):
            return message
        case .generationFailed(let message):
            return message
        }
    }
}

public struct StaticCompletionEngine: TextCompletionEngine {
    private let suggestion: String

    public init(suggestion: String = " the rest") {
        self.suggestion = suggestion
    }

    public func complete(request: SuggestionRequest) async throws -> String {
        suggestion
    }
}

public struct LlamaCompletionOptions: Sendable {
    public var maxPredictionTokens: Int
    public var contextTokens: Int32
    public var batchTokens: Int32
    public var temperature: Float
    public var topK: Int32
    public var topP: Float
    public var minP: Float
    public var seed: UInt32

    public init(
        maxPredictionTokens: Int = 12,
        contextTokens: Int32 = 2048,
        batchTokens: Int32 = 512,
        temperature: Float = 0.0,
        topK: Int32 = 20,
        topP: Float = 0.9,
        minP: Float = 0.05,
        seed: UInt32 = 0
    ) {
        self.maxPredictionTokens = max(1, maxPredictionTokens)
        self.contextTokens = contextTokens
        self.batchTokens = batchTokens
        self.temperature = temperature
        self.topK = topK
        self.topP = topP
        self.minP = minP
        self.seed = seed
    }
}

public actor LlamaCompletionEngine: TextCompletionEngine {
    private static var loggingSilenced = false
    private static let sequenceID: llama_seq_id = 0

    private let modelURL: URL
    private let options: LlamaCompletionOptions
    private var backendInitialized = false
    private var model: OpaquePointer?

    public init(modelURL: URL, options: LlamaCompletionOptions = LlamaCompletionOptions()) {
        self.modelURL = modelURL
        self.options = options
    }

    public func complete(request: SuggestionRequest) async throws -> String {
        try Task.checkCancellation()
        try loadIfNeeded()
        let prompt = PromptBuilder().prompt(for: request)
        let raw = try generate(prompt: prompt)
        return SuggestionTextNormalizer.normalize(raw, input: request.prefix, maxWords: request.maxPredictionWords)
    }

    public func warmup() throws {
        try loadIfNeeded()
    }

    public func shutdown() {
        shutdownSync()
    }

    private func loadIfNeeded() throws {
        if model != nil { return }

        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw CompletionEngineError.modelUnavailable("Model not found at \(modelURL.path). Run ./scripts/download-model.sh first.")
        }

        if !backendInitialized {
            if !Self.loggingSilenced {
                llama_log_set({ _, _, _ in }, nil)
                Self.loggingSilenced = true
            }
            llama_backend_init()
            backendInitialized = true
        }

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = llama_supports_gpu_offload() ? -1 : 0
        modelParams.use_mmap = true
        modelParams.use_mlock = false

        guard let loadedModel = modelURL.path.withCString({ llama_model_load_from_file($0, modelParams) }) else {
            throw CompletionEngineError.modelUnavailable("Unable to load model at \(modelURL.path).")
        }

        model = loadedModel
    }

    private func generate(prompt: String) throws -> String {
        guard let model else {
            throw CompletionEngineError.modelUnavailable("Model is not loaded.")
        }
        guard let vocab = llama_model_get_vocab(model) else {
            throw CompletionEngineError.generationFailed("Unable to access model vocabulary.")
        }

        let allTokens = try tokenize(prompt: prompt, vocab: vocab)
        let maxPromptTokens = max(1, Int(options.contextTokens) - options.maxPredictionTokens)
        let promptTokens = allTokens.count > maxPromptTokens
            ? Array(allTokens.suffix(maxPromptTokens))
            : allTokens

        let context = try makeContext(model: model)
        defer { llama_free(context) }

        try decodePrompt(promptTokens, in: context)
        let sampler = try makeSampler()
        defer { llama_sampler_free(sampler) }

        var generated = ""
        var position = Int32(promptTokens.count)
        var sawVisibleText = false

        for _ in 0 ..< options.maxPredictionTokens {
            try Task.checkCancellation()

            let nextToken = llama_sampler_sample(sampler, context, -1)
            if nextToken < 0 || nextToken == llama_vocab_eos(vocab) || llama_vocab_is_eog(vocab, nextToken) {
                break
            }

            let piece = pieceString(for: nextToken, vocab: vocab)
            if piece.contains("<|") { break }

            generated += piece
            llama_sampler_accept(sampler, nextToken)

            if piece.unicodeScalars.contains(where: Self.isVisibleScalar) {
                sawVisibleText = true
            }
            if sawVisibleText && (generated.contains("\n") || generated.contains("\r")) {
                break
            }

            try decodeToken(nextToken, position: position, in: context)
            position += 1
        }

        return generated
    }

    private func makeContext(model: OpaquePointer) throws -> OpaquePointer {
        var params = llama_context_default_params()
        params.n_ctx = UInt32(options.contextTokens)
        params.n_batch = UInt32(options.batchTokens)
        params.n_ubatch = UInt32(options.batchTokens)
        params.n_seq_max = 1
        params.n_threads = Int32(max(1, min(8, ProcessInfo.processInfo.processorCount - 2)))
        params.n_threads_batch = params.n_threads
        params.offload_kqv = true

        guard let context = llama_init_from_model(model, params) else {
            throw CompletionEngineError.generationFailed("Unable to create llama context.")
        }

        return context
    }

    private func tokenize(prompt: String, vocab: OpaquePointer) throws -> [llama_token] {
        var capacity = max(prompt.utf8.count + 8, 32)
        let addSpecial = llama_vocab_get_add_bos(vocab)

        while true {
            var tokens = [llama_token](repeating: 0, count: capacity)
            let count = prompt.withCString { pointer in
                llama_tokenize(
                    vocab,
                    pointer,
                    Int32(prompt.utf8.count),
                    &tokens,
                    Int32(tokens.count),
                    addSpecial,
                    false
                )
            }

            if count > 0 {
                return Array(tokens.prefix(Int(count)))
            }
            if count == 0 {
                throw CompletionEngineError.generationFailed("Tokenization returned no tokens.")
            }
            capacity = max(capacity * 2, Int(-count))
        }
    }

    private func decodePrompt(_ tokens: [llama_token], in context: OpaquePointer) throws {
        guard !tokens.isEmpty else { return }

        var cursor = 0
        let batchCapacity = max(1, Int(options.batchTokens))
        var batch = llama_batch_init(Int32(batchCapacity), 0, 1)
        defer { llama_batch_free(batch) }

        while cursor < tokens.count {
            let chunkEnd = min(cursor + batchCapacity, tokens.count)
            let chunkSize = chunkEnd - cursor
            batch.n_tokens = Int32(chunkSize)

            for offset in 0 ..< chunkSize {
                let index = cursor + offset
                batch.token[offset] = tokens[index]
                batch.pos[offset] = Int32(index)
                batch.n_seq_id[offset] = 1
                if let seqIDs = batch.seq_id, let seqID = seqIDs[offset] {
                    seqID[0] = Self.sequenceID
                }
                batch.logits[offset] = (chunkEnd == tokens.count && offset == chunkSize - 1) ? 1 : 0
            }

            guard llama_decode(context, batch) == 0 else {
                throw CompletionEngineError.generationFailed("llama_decode failed while evaluating prompt.")
            }
            cursor = chunkEnd
        }
    }

    private func decodeToken(_ token: llama_token, position: Int32, in context: OpaquePointer) throws {
        var batch = llama_batch_init(1, 0, 1)
        defer { llama_batch_free(batch) }

        batch.n_tokens = 1
        batch.token[0] = token
        batch.pos[0] = position
        batch.n_seq_id[0] = 1
        if let seqIDs = batch.seq_id, let seqID = seqIDs[0] {
            seqID[0] = Self.sequenceID
        }
        batch.logits[0] = 1

        guard llama_decode(context, batch) == 0 else {
            throw CompletionEngineError.generationFailed("llama_decode failed while generating.")
        }
    }

    private func makeSampler() throws -> UnsafeMutablePointer<llama_sampler> {
        guard let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params()) else {
            throw CompletionEngineError.generationFailed("Unable to initialize sampler.")
        }

        if options.topK > 0, let topK = llama_sampler_init_top_k(options.topK) {
            llama_sampler_chain_add(sampler, topK)
        }
        if options.topP > 0, options.topP < 1, let topP = llama_sampler_init_top_p(options.topP, 1) {
            llama_sampler_chain_add(sampler, topP)
        }
        if options.minP > 0, options.minP < 1, let minP = llama_sampler_init_min_p(options.minP, 1) {
            llama_sampler_chain_add(sampler, minP)
        }

        if options.temperature > 0 {
            if let temp = llama_sampler_init_temp(options.temperature) {
                llama_sampler_chain_add(sampler, temp)
            }
            if let dist = llama_sampler_init_dist(options.seed == 0 ? UInt32.random(in: UInt32.min ... UInt32.max) : options.seed) {
                llama_sampler_chain_add(sampler, dist)
            }
        } else if let greedy = llama_sampler_init_greedy() {
            llama_sampler_chain_add(sampler, greedy)
        }

        return sampler
    }

    private func pieceString(for token: llama_token, vocab: OpaquePointer) -> String {
        var capacity = 32

        while true {
            var buffer = [CChar](repeating: 0, count: capacity)
            let written = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
            if written < 0 {
                capacity = max(capacity * 2, Int(-written) + 1)
                continue
            }

            let bytes = buffer.prefix(Int(written)).map { UInt8(bitPattern: $0) }
            return String(bytes: bytes, encoding: .utf8) ?? ""
        }
    }

    private func shutdownSync() {
        if let model {
            llama_model_free(model)
            self.model = nil
        }
        if backendInitialized {
            llama_backend_free()
            backendInitialized = false
        }
    }

    nonisolated private static func isVisibleScalar(_ scalar: UnicodeScalar) -> Bool {
        if CharacterSet.controlCharacters.contains(scalar) {
            return false
        }
        return !CharacterSet.whitespacesAndNewlines.contains(scalar)
    }
}
