//
//  KBLLMValidator.swift
//  UnaMentis
//
//  LLM-based answer validation for Knowledge Bowl (Tier 3)
//  Uses Llama 3.2 1B (4-bit quantized) via llama.cpp for expert-level validation
//

import Foundation
import OSLog

// MARK: - LLM Validator

/// LLM-based validator using Llama 3.2 1B for expert-level answer validation
actor KBLLMValidator {
    private let logger = Logger(subsystem: "com.unamentis", category: "KBLLMValidator")

    // MARK: - Model State

    enum ModelState: Sendable, Equatable {
        case notDownloaded
        case downloading(Float)  // Progress 0.0-1.0
        case available           // Downloaded but not loaded
        case loaded              // Ready for inference
        case error(String)       // Error occurred

        static func == (lhs: ModelState, rhs: ModelState) -> Bool {
            switch (lhs, rhs) {
            case (.notDownloaded, .notDownloaded),
                 (.available, .available),
                 (.loaded, .loaded):
                return true
            case let (.downloading(p1), .downloading(p2)):
                return abs(p1 - p2) < 0.01
            case let (.error(e1), .error(e2)):
                return e1 == e2
            default:
                return false
            }
        }
    }

    private var state: ModelState = .notDownloaded
    private nonisolated(unsafe) var llamaContext: OpaquePointer?

    // MARK: - Configuration

    private let modelName = "llama-3.2-1b-q4"
    private let modelURL: URL
    private let downloadURL = "https://models.unamentis.com/kb/llama-3.2-1b-q4.gguf"
    private let maxTokens = 512
    private let temperature: Float = 0.1  // Low temperature for deterministic validation

    // MARK: - Initialization

    init() {
        // Model storage location
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.modelURL = documentsURL.appendingPathComponent("\(modelName).gguf")

        // Check if model already exists
        Task {
            await checkModelAvailability()
        }
    }

    deinit {
        // Clean up llama.cpp context
        if let context = llamaContext {
            // llama_free(context) // TODO: Uncomment when llama.cpp is integrated
            logger.info("Released LLM context")
        }
    }

    // MARK: - Public API

    /// Get current model state
    nonisolated func currentState() async -> ModelState {
        await state
    }

    /// Download the LLM model
    /// - Parameter progressHandler: Called with download progress (0.0-1.0)
    func downloadModel(progressHandler: @Sendable @escaping (Float) -> Void) async throws {
        logger.info("Starting LLM model download")
        state = .downloading(0.0)

        guard let url = URL(string: downloadURL) else {
            let error = "Invalid download URL"
            logger.error("\(error)")
            state = .error(error)
            throw KBLLMError.invalidURL
        }

        // Download with progress tracking
        let (localURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let error = "Download failed with status \((response as? HTTPURLResponse)?.statusCode ?? 0)"
            logger.error("\(error)")
            state = .error(error)
            throw KBLLMError.downloadFailed
        }

        // Move to final location
        if FileManager.default.fileExists(atPath: modelURL.path) {
            try FileManager.default.removeItem(at: modelURL)
        }
        try FileManager.default.moveItem(at: localURL, to: modelURL)

        state = .available
        logger.info("LLM model downloaded successfully")
    }

    /// Load the model into memory
    func loadModel() async throws {
        logger.info("Loading LLM model")

        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            let error = "Model not found at \(modelURL.path)"
            logger.error("\(error)")
            state = .error(error)
            throw KBLLMError.modelNotFound
        }

        // Initialize llama.cpp context
        // TODO: Uncomment and update this implementation when llama.cpp is integrated.
        // var params = llama_context_default_params()
        // params.n_ctx = UInt32(maxTokens)
        // params.n_gpu_layers = 0  // CPU only for now
        //
        // llamaContext = llama_init_from_file(modelURL.path, params)
        //
        // guard llamaContext != nil else {
        //     throw LLMError.loadFailed(NSError(domain: "LLM", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize llama context"]))
        // }
        // state = .loaded
        // logger.info("LLM model loaded successfully")

        let errorMsg = "LLM inference not implemented: llama.cpp integration is currently disabled"
        logger.error("\(errorMsg)")
        state = .error(errorMsg)
        let underlyingError = NSError(
            domain: "KBLLMValidator",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: errorMsg]
        )
        throw KBLLMError.loadFailed(underlyingError)
    }

    /// Unload the model from memory
    func unloadModel() {
        logger.info("Unloading LLM model")

        if let context = llamaContext {
            // llama_free(context) // TODO: Uncomment when llama.cpp is integrated
            llamaContext = nil
        }

        state = .available
    }

    /// Validate answer using LLM
    /// - Parameters:
    ///   - userAnswer: User's answer
    ///   - correctAnswer: Correct answer
    ///   - question: Question text
    ///   - answerType: Answer type for domain-specific rules
    /// - Returns: True if LLM judges answer as correct
    func validate(
        userAnswer: String,
        correctAnswer: String,
        question: String,
        answerType: KBAnswerType
    ) async throws -> Bool {
        guard state == .loaded, llamaContext != nil else {
            logger.error("Model not loaded")
            throw KBLLMError.modelNotLoaded
        }

        // Build validation prompt
        let prompt = buildPrompt(
            question: question,
            correctAnswer: correctAnswer,
            userAnswer: userAnswer,
            answerType: answerType
        )

        logger.debug("LLM validation prompt: \(prompt)")

        // Run inference
        let response = try await runInference(prompt: prompt)

        logger.debug("LLM response: \(response)")

        // Parse response (expect "CORRECT" or "INCORRECT")
        let isCorrect = response.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "CORRECT"

        return isCorrect
    }

    // MARK: - Private Helpers

    private func checkModelAvailability() {
        if FileManager.default.fileExists(atPath: modelURL.path) {
            state = .available
            logger.info("LLM model found at \(self.modelURL.path)")
        } else {
            state = .notDownloaded
            logger.info("LLM model not downloaded")
        }
    }

    private func buildPrompt(
        question: String,
        correctAnswer: String,
        userAnswer: String,
        answerType: KBAnswerType
    ) -> String {
        """
        You are an expert Knowledge Bowl judge. Determine if the student's answer is semantically equivalent to the correct answer.

        Question: \(question)
        Correct Answer: \(correctAnswer)
        Student Answer: \(userAnswer)
        Answer Type: \(answerType.rawValue)

        Rules:
        1. Accept answers that convey the same meaning even if worded differently
        2. Accept common abbreviations and alternative names
        3. Reject close but factually incorrect answers
        4. Consider the answer type for domain-specific rules

        Respond with exactly one word: "CORRECT" or "INCORRECT"

        Your judgment:
        """
    }

    private func runInference(prompt: String) async throws -> String {
        // TODO: Implement actual llama.cpp inference
        // This is a placeholder implementation

        guard llamaContext != nil else {
            throw KBLLMError.modelNotLoaded
        }

        // Placeholder: In production, this would:
        // 1. Tokenize the prompt
        // 2. Run llama_eval to process tokens
        // 3. Sample from the model with low temperature
        // 4. Decode tokens back to text
        // 5. Stop at newline or max tokens

        // For now, return placeholder
        logger.warning("LLM inference not yet implemented")
        return "CORRECT"  // Placeholder
    }
}

// MARK: - KB LLM Error

enum KBLLMError: Error, LocalizedError {
    case invalidURL
    case downloadFailed
    case modelNotFound
    case loadFailed(Error)
    case modelNotLoaded
    case inferenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid model download URL"
        case .downloadFailed:
            return "Failed to download LLM model"
        case .modelNotFound:
            return "LLM model file not found"
        case .loadFailed(let error):
            return "Failed to load LLM model: \(error.localizedDescription)"
        case .modelNotLoaded:
            return "LLM model not loaded into memory"
        case .inferenceFailed(let message):
            return "LLM inference failed: \(message)"
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension KBLLMValidator {
    static func preview() -> KBLLMValidator {
        KBLLMValidator()
    }
}
#endif
