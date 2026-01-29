//
//  KBLLMValidator.swift
//  UnaMentis
//
//  LLM-based answer validation for Knowledge Bowl (Tier 3)
//  Uses any LLMService (on-device or cloud) for expert-level validation
//

import Foundation
import OSLog

// MARK: - LLM Validator

/// LLM-based validator for expert-level answer validation
///
/// Uses the `LLMService` protocol which can be backed by:
/// - `OnDeviceLLMService` - On-device inference via llama.cpp
/// - `SelfHostedLLMService` - Server-based inference
/// - `AnthropicLLMService` - Cloud-based inference
/// - Any other LLMService implementation
///
/// The validator is designed for short, deterministic responses (CORRECT/INCORRECT)
/// using low temperature to ensure consistent judgments.
///
/// ## Usage
/// ```swift
/// // With on-device LLM
/// let llmService = OnDeviceLLMService()
/// let validator = KBLLMValidator(service: llmService)
///
/// // Or with cloud LLM
/// let validator = KBLLMValidator(service: anthropicService)
///
/// let isCorrect = try await validator.validate(
///     userAnswer: "Paris",
///     correctAnswer: "Paris",
///     question: "What is the capital of France?",
///     answerType: .place
/// )
/// ```
actor KBLLMValidator {
    private let logger = Logger(subsystem: "com.unamentis", category: "KBLLMValidator")

    // MARK: - Model State

    public enum ModelState: Sendable, Equatable {
        case notConfigured     // No service provided
        case available         // Service provided, ready to use
        case loading           // Currently initializing
        case loaded            // Ready for inference
        case error(String)     // Error occurred

        public static func == (lhs: ModelState, rhs: ModelState) -> Bool {
            switch (lhs, rhs) {
            case (.notConfigured, .notConfigured),
                 (.available, .available),
                 (.loading, .loading),
                 (.loaded, .loaded):
                return true
            case let (.error(e1), .error(e2)):
                return e1 == e2
            default:
                return false
            }
        }
    }

    private var state: ModelState = .notConfigured

    // MARK: - LLM Service

    /// The LLM service to use for validation
    private let llmService: any LLMService

    // MARK: - Configuration

    /// Maximum tokens to generate (short response expected)
    private let maxTokens = 32

    /// Low temperature for deterministic validation
    private let temperature: Float = 0.1

    // MARK: - Initialization

    /// Create validator with a specific LLM service
    /// - Parameter service: The LLM service to use for validation
    init(service: any LLMService) {
        self.llmService = service
        self.state = .available
    }

    // MARK: - Public API

    /// Get current model state
    nonisolated func currentState() async -> ModelState {
        await state
    }

    /// Prepare the LLM service for validation
    /// For OnDeviceLLMService, this loads the model into memory
    func loadModel() async throws {
        guard state != .loaded else {
            logger.debug("LLM service already loaded")
            return
        }

        logger.info("Preparing LLM service for KB validation")
        state = .loading

        do {
            // For services that need explicit loading (like OnDeviceLLMService)
            // we check if they conform to the loading protocol
            if let loadable = llmService as? LLMLoadableService {
                try await loadable.loadModel()
            }

            state = .loaded
            logger.info("LLM service ready for KB validation")
        } catch {
            let errorMsg = "Failed to prepare LLM service: \(error.localizedDescription)"
            logger.error("\(errorMsg)")
            state = .error(errorMsg)
            throw KBLLMError.loadFailed(error)
        }
    }

    /// Unload the LLM service from memory
    func unloadModel() async {
        logger.info("Unloading LLM service")

        if let loadable = llmService as? LLMLoadableService {
            await loadable.unloadModel()
        }

        state = .available
    }

    /// Validate answer using LLM
    /// - Parameters:
    ///   - userAnswer: User's answer
    ///   - correctAnswer: Correct answer
    ///   - question: Question text
    ///   - answerType: Answer type for domain-specific rules
    ///   - guidance: Optional evaluation guidance for complex answers
    /// - Returns: True if LLM judges answer as correct
    func validate(
        userAnswer: String,
        correctAnswer: String,
        question: String,
        answerType: KBAnswerType,
        guidance: String? = nil
    ) async throws -> Bool {
        // Auto-load if not loaded
        if state != .loaded {
            try await loadModel()
        }

        // Build validation prompt
        let prompt = buildPrompt(
            question: question,
            correctAnswer: correctAnswer,
            userAnswer: userAnswer,
            answerType: answerType,
            guidance: guidance
        )

        logger.debug("LLM validation prompt: \(prompt)")

        // Run inference
        let response = try await runInference(prompt: prompt)

        logger.debug("LLM response: \(response)")

        // Parse response (expect "CORRECT" or "INCORRECT")
        let normalizedResponse = response.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).uppercased()
        let isCorrect = normalizedResponse.contains("CORRECT") && !normalizedResponse.contains("INCORRECT")

        logger.info("KB LLM validation: '\(userAnswer)' vs '\(correctAnswer)' = \(isCorrect ? "CORRECT" : "INCORRECT")")

        return isCorrect
    }

    // MARK: - Private Helpers

    private func buildPrompt(
        question: String,
        correctAnswer: String,
        userAnswer: String,
        answerType: KBAnswerType,
        guidance: String? = nil
    ) -> String {
        var prompt = """
        You are an expert Knowledge Bowl judge. Determine if the student's answer is semantically equivalent to the correct answer.

        Question: \(question)
        Correct Answer: \(correctAnswer)
        Student Answer: \(userAnswer)
        Answer Type: \(answerType.rawValue)
        """

        // Add guidance if provided (for complex sentence-length answers)
        if let guidance = guidance, !guidance.isEmpty {
            prompt += """


        Evaluation Guidance:
        \(guidance)
        """
        }

        prompt += """


        Rules:
        1. Accept answers that convey the same meaning even if worded differently
        2. Accept common abbreviations and alternative names
        3. Reject close but factually incorrect answers
        4. Consider the answer type for domain-specific rules
        5. If evaluation guidance is provided, follow it carefully

        Respond with exactly one word: "CORRECT" or "INCORRECT"

        Your judgment:
        """

        return prompt
    }

    private func runInference(prompt: String) async throws -> String {
        // Create message for the LLM
        let messages = [
            LLMMessage(role: .user, content: prompt)
        ]

        // Configure for short, deterministic response
        let config = LLMConfig(
            model: "on-device",
            maxTokens: maxTokens,
            temperature: temperature,
            stream: true
        )

        // Collect streamed response
        var response = ""
        let stream = try await llmService.streamCompletion(messages: messages, config: config)

        for await token in stream {
            response += token.content

            // Stop early if we have a clear answer
            let upperResponse = response.uppercased()
            if upperResponse.contains("CORRECT") || upperResponse.contains("INCORRECT") {
                // Wait for a bit more context but don't need the whole response
                if response.count > 10 {
                    break
                }
            }

            // Hard stop if response is getting too long
            if response.count > 50 {
                break
            }
        }

        return response
    }
}

// MARK: - Loadable Service Protocol

/// Protocol for LLM services that need explicit loading/unloading
/// Services like OnDeviceLLMService that load models into memory should conform to this
protocol LLMLoadableService: LLMService {
    func loadModel() async throws
    func unloadModel() async
}

// MARK: - KB LLM Error

enum KBLLMError: Error, LocalizedError {
    case modelNotFound
    case loadFailed(Error)
    case modelNotLoaded
    case inferenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "LLM service not configured"
        case .loadFailed(let error):
            return "Failed to load LLM: \(error.localizedDescription)"
        case .modelNotLoaded:
            return "LLM not loaded into memory"
        case .inferenceFailed(let message):
            return "LLM inference failed: \(message)"
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension KBLLMValidator {
    /// Create a mock validator for previews using MockLLMService
    static func preview() -> KBLLMValidator {
        KBLLMValidator(service: MockLLMService())
    }
}
#endif
