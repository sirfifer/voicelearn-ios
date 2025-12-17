// VoiceLearn - On-Device LLM Service
// Local Language Model using llama.cpp
//
// This service provides fully on-device LLM inference with no network required.
// Uses llama.cpp for efficient inference on Apple Silicon.
//
// Recommended models for iPhone 17 Pro Max (12GB RAM):
// - Llama-3.2-3B-Instruct-Q4_K_M (~2GB)
// - Phi-3-mini-4k-instruct-Q4_K_M (~2.2GB)
// - Qwen2-1.5B-Instruct-Q4_K_M (~1GB)

import Foundation
import Logging

// llama.cpp integration - requires C++ interop
#if LLAMA_AVAILABLE
import llama
private let llamaAvailable = true
#else
private let llamaAvailable = false
// Stub types for compilation when llama is not available
private typealias llama_token = Int32
private typealias llama_pos = Int32
private typealias llama_seq_id = Int32
#endif

/// On-device LLM service using llama.cpp
///
/// Benefits:
/// - Free (no API costs)
/// - Works offline
/// - Privacy-preserving (data never leaves device)
/// - Low latency for short responses
public actor OnDeviceLLMService: LLMService {

    // MARK: - Types

    public enum OnDeviceLLMError: Error, LocalizedError {
        case modelNotFound(String)
        case modelLoadFailed(String)
        case inferenceError(String)
        case notConfigured
        case llamaNotAvailable

        public var errorDescription: String? {
            switch self {
            case .modelNotFound(let name): return "Model not found: \(name)"
            case .modelLoadFailed(let msg): return "Failed to load model: \(msg)"
            case .inferenceError(let msg): return "Inference error: \(msg)"
            case .notConfigured: return "On-device LLM not configured"
            case .llamaNotAvailable: return "llama.cpp not available - requires C++ interop"
            }
        }
    }

    /// Configuration for on-device LLM
    public struct Configuration: Sendable {
        /// Path to GGUF model file
        public let modelPath: URL
        /// Context size (tokens)
        public let contextSize: Int32
        /// Number of GPU layers
        public let gpuLayers: Int32
        /// Number of threads
        public let threads: Int

        public init(
            modelPath: URL,
            contextSize: Int32 = 4096,
            gpuLayers: Int32 = 99,
            threads: Int = 4
        ) {
            self.modelPath = modelPath
            self.contextSize = contextSize
            self.gpuLayers = gpuLayers
            self.threads = threads
        }

        public static var `default`: Configuration {
            // Look for model in app bundle or documents
            // Priority: Llama-3.2 > GLM-ASR-nano (can also do chat)
            let bundleLlamaPath = Bundle.main.url(
                forResource: "llama-3.2-3b-instruct-q4km",
                withExtension: "gguf"
            )
            let bundleGLMPath = Bundle.main.url(
                forResource: "glm-asr-nano-q4km",
                withExtension: "gguf"
            )
            let documentsLlamaPath = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first?.appendingPathComponent("models/llama-3.2-3b-instruct-q4km.gguf")
            let documentsGLMPath = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first?.appendingPathComponent("models/glm-asr-nano/glm-asr-nano-q4km.gguf")

            // Use first available model
            let modelPath = bundleLlamaPath ?? bundleGLMPath ?? documentsLlamaPath ?? documentsGLMPath ?? URL(fileURLWithPath: "/models/chat.gguf")

            return Configuration(modelPath: modelPath)
        }
    }

    // MARK: - Properties

    private let logger = Logger(label: "com.voicelearn.llm.ondevice")
    private let configuration: Configuration

    // llama.cpp state
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var isLoaded: Bool = false

    // Token tracking
    private var totalInputTokens: Int = 0
    private var totalOutputTokens: Int = 0
    private var ttftMeasurements: [TimeInterval] = []

    /// Performance metrics
    public var metrics: LLMMetrics {
        let sortedTTFT = ttftMeasurements.sorted()
        let median = sortedTTFT.isEmpty ? 0.5 : sortedTTFT[sortedTTFT.count / 2]
        let p99Index = min(Int(Double(sortedTTFT.count) * 0.99), max(0, sortedTTFT.count - 1))
        let p99 = sortedTTFT.isEmpty ? 1.0 : sortedTTFT[p99Index]

        return LLMMetrics(
            medianTTFT: median,
            p99TTFT: p99,
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens
        )
    }

    /// Cost per input token ($0 - free on-device)
    public var costPerInputToken: Decimal { Decimal(0) }

    /// Cost per output token ($0 - free on-device)
    public var costPerOutputToken: Decimal { Decimal(0) }

    // MARK: - Initialization

    public init(configuration: Configuration = .default) {
        self.configuration = configuration
        logger.info("OnDeviceLLMService initialized")
    }

    deinit {
        // Note: Can't call unloadModel() here due to actor isolation
        // Ensure stopStreaming() or explicit cleanup is called before release
    }

    // MARK: - Model Loading

    public func loadModel() async throws {
        guard !isLoaded else { return }

        #if LLAMA_AVAILABLE
        logger.info("Loading on-device LLM from \(configuration.modelPath.path)")

        guard FileManager.default.fileExists(atPath: configuration.modelPath.path) else {
            throw OnDeviceLLMError.modelNotFound(configuration.modelPath.lastPathComponent)
        }

        // Initialize llama backend
        llama_backend_init()

        // Load model
        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = configuration.gpuLayers

        model = llama_load_model_from_file(configuration.modelPath.path, modelParams)
        guard model != nil else {
            throw OnDeviceLLMError.modelLoadFailed("llama_load_model_from_file failed")
        }

        // Create context
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = UInt32(configuration.contextSize)
        ctxParams.n_threads = UInt32(configuration.threads)
        ctxParams.n_threads_batch = UInt32(configuration.threads)

        context = llama_new_context_with_model(model, ctxParams)
        guard context != nil else {
            llama_free_model(model)
            model = nil
            throw OnDeviceLLMError.modelLoadFailed("llama_new_context_with_model failed")
        }

        isLoaded = true
        logger.info("On-device LLM loaded successfully")
        #else
        throw OnDeviceLLMError.llamaNotAvailable
        #endif
    }

    public func unloadModel() {
        #if LLAMA_AVAILABLE
        if let ctx = context {
            llama_free(ctx)
            context = nil
        }
        if let mdl = model {
            llama_free_model(mdl)
            model = nil
        }
        llama_backend_free()
        #endif
        isLoaded = false
    }

    // MARK: - LLMService Protocol

    public func streamCompletion(
        messages: [LLMMessage],
        config: LLMConfig
    ) async throws -> AsyncStream<LLMToken> {
        // Load model if needed
        if !isLoaded {
            try await loadModel()
        }

        #if LLAMA_AVAILABLE
        guard let ctx = context, let mdl = model else {
            throw OnDeviceLLMError.notConfigured
        }

        // Format messages into prompt
        let prompt = formatChatPrompt(messages: messages, systemPrompt: config.systemPrompt)
        logger.debug("Prompt: \(prompt.prefix(200))...")

        let startTime = Date()

        return AsyncStream { continuation in
            Task {
                do {
                    // Tokenize prompt
                    let tokens = self.tokenize(prompt, model: mdl)
                    self.totalInputTokens += tokens.count

                    // Evaluate prompt
                    var batch = llama_batch_init(Int32(tokens.count + config.maxTokens), 0, 1)
                    defer { llama_batch_free(batch) }

                    // Add prompt tokens
                    for (i, token) in tokens.enumerated() {
                        batch.token[i] = token
                        batch.pos[i] = Int32(i)
                        batch.n_seq_id[i] = 1
                        batch.seq_id[i]![0] = 0
                        batch.logits[i] = 0
                    }
                    batch.logits[tokens.count - 1] = 1
                    batch.n_tokens = Int32(tokens.count)

                    if llama_decode(ctx, batch) != 0 {
                        throw OnDeviceLLMError.inferenceError("Initial decode failed")
                    }

                    // Generate tokens
                    var nCur = Int32(tokens.count)
                    let maxTokens = Int32(config.maxTokens)
                    let nVocab = llama_n_vocab(mdl)
                    var generatedCount = 0
                    var firstTokenEmitted = false

                    while nCur < Int32(tokens.count) + maxTokens {
                        guard let logits = llama_get_logits_ith(ctx, -1) else {
                            break
                        }

                        // Sample next token
                        var candidates = [llama_token_data]()
                        candidates.reserveCapacity(Int(nVocab))
                        for tokenId in 0..<nVocab {
                            candidates.append(llama_token_data(
                                id: tokenId,
                                logit: logits[Int(tokenId)],
                                p: 0
                            ))
                        }

                        let newToken: llama_token = candidates.withUnsafeMutableBufferPointer { buffer in
                            var candidatesArray = llama_token_data_array(
                                data: buffer.baseAddress,
                                size: buffer.count,
                                sorted: false
                            )
                            llama_sample_temp(ctx, &candidatesArray, config.temperature)
                            if let topP = config.topP {
                                llama_sample_top_p(ctx, &candidatesArray, topP, 1)
                            }
                            return llama_sample_token(ctx, &candidatesArray)
                        }

                        // Check for end of generation
                        if llama_token_is_eog(mdl, newToken) {
                            break
                        }

                        // Decode token to text
                        let tokenText = self.detokenize([newToken], model: mdl)

                        // Record TTFT
                        if !firstTokenEmitted {
                            let ttft = Date().timeIntervalSince(startTime)
                            self.ttftMeasurements.append(ttft)
                            firstTokenEmitted = true
                        }

                        generatedCount += 1

                        // Emit token
                        continuation.yield(LLMToken(
                            content: tokenText,
                            isDone: false,
                            stopReason: nil,
                            tokenCount: generatedCount
                        ))

                        // Prepare next batch
                        self.batchClear(&batch)
                        batch.token[0] = newToken
                        batch.pos[0] = nCur
                        batch.n_seq_id[0] = 1
                        batch.seq_id[0]![0] = 0
                        batch.logits[0] = 1
                        batch.n_tokens = 1

                        if llama_decode(ctx, batch) != 0 {
                            break
                        }

                        nCur += 1

                        // Check stop sequences
                        // Note: Would need to track full output to properly check stop sequences
                    }

                    self.totalOutputTokens += generatedCount

                    // Final token
                    continuation.yield(LLMToken(
                        content: "",
                        isDone: true,
                        stopReason: .endTurn,
                        tokenCount: generatedCount
                    ))
                    continuation.finish()

                } catch {
                    self.logger.error("Stream completion failed: \(error)")
                    continuation.finish()
                }
            }
        }
        #else
        throw OnDeviceLLMError.llamaNotAvailable
        #endif
    }

    // MARK: - Helpers

    private func formatChatPrompt(messages: [LLMMessage], systemPrompt: String?) -> String {
        // Format for Llama-3 Instruct style
        var prompt = ""

        // Add system prompt if present
        let system = systemPrompt ?? messages.first(where: { $0.role == .system })?.content
        if let system = system {
            prompt += "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n\(system)<|eot_id|>"
        } else {
            prompt += "<|begin_of_text|>"
        }

        // Add conversation messages
        for message in messages where message.role != .system {
            let role = message.role == .user ? "user" : "assistant"
            prompt += "<|start_header_id|>\(role)<|end_header_id|>\n\n\(message.content)<|eot_id|>"
        }

        // Add assistant header for response
        prompt += "<|start_header_id|>assistant<|end_header_id|>\n\n"

        return prompt
    }

    #if LLAMA_AVAILABLE
    private func tokenize(_ text: String, model: OpaquePointer) -> [llama_token] {
        let utf8Count = text.utf8.count
        let maxTokens = utf8Count + 16
        let tokens = UnsafeMutablePointer<llama_token>.allocate(capacity: maxTokens)
        defer { tokens.deallocate() }

        let tokenCount = llama_tokenize(model, text, Int32(utf8Count), tokens, Int32(maxTokens), true, false)

        var result: [llama_token] = []
        for i in 0..<Int(max(0, tokenCount)) {
            result.append(tokens[i])
        }
        return result
    }

    private func detokenize(_ tokens: [llama_token], model: OpaquePointer) -> String {
        var result = ""
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: 256)
        defer { buffer.deallocate() }

        for token in tokens {
            let length = llama_token_to_piece(model, token, buffer, 256, false)
            if length > 0 {
                buffer[Int(length)] = 0
                if let str = String(cString: buffer, encoding: .utf8) {
                    result += str
                }
            }
        }

        return result
    }

    private func batchClear(_ batch: inout llama_batch) {
        batch.n_tokens = 0
    }
    #endif
}

// MARK: - Device Capability Check

extension OnDeviceLLMService {
    /// Check if the current device supports on-device LLM
    public static var isDeviceSupported: Bool {
        // Check available memory (need ~4GB free for 3B model)
        let memoryGB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
        guard memoryGB >= 6 else {
            return false
        }

        #if targetEnvironment(simulator)
        // Check if model exists for simulator testing
        return FileManager.default.fileExists(
            atPath: Configuration.default.modelPath.path
        )
        #else
        return true
        #endif
    }

    /// Check if on-device models are available
    public static var areModelsAvailable: Bool {
        FileManager.default.fileExists(atPath: Configuration.default.modelPath.path)
    }
}
