// UnaMentis - Mock LLM Service
// Provides mock responses for testing without API keys or models
//
// Used for simulator testing and development

import Foundation
import Logging

/// Mock LLM service that provides canned responses for testing
/// Use this for simulator testing without requiring API keys or model files
public actor MockLLMService: LLMService {

    // MARK: - Properties

    private let logger = Logger(label: "com.unamentis.llm.mock")

    /// Performance metrics
    public private(set) var metrics = LLMMetrics(
        medianTTFT: 0.05,
        p99TTFT: 0.1,
        totalInputTokens: 0,
        totalOutputTokens: 0
    )

    /// Cost per input token (mock = $0)
    public var costPerInputToken: Decimal { 0 }

    /// Cost per output token (mock = $0)
    public var costPerOutputToken: Decimal { 0 }

    // MARK: - Response Templates

    private let greetings = [
        "Hello! I'm your AI tutor. How can I help you learn today?",
        "Hi there! Ready to explore some new topics together?",
        "Welcome! What would you like to learn about today?",
    ]

    private let acknowledgments = [
        "That's a great question! Let me help you understand this better.",
        "I see what you're asking. Here's what I think about that.",
        "Good point! Let me share some thoughts on this topic.",
    ]

    private let followUps = [
        "Does that make sense? Feel free to ask if you'd like me to clarify anything.",
        "What do you think about that? I'd love to hear your perspective.",
        "Is there anything specific about this topic you'd like to explore further?",
    ]

    // MARK: - Initialization

    public init() {
        logger.info("MockLLMService initialized - using canned responses for testing")
    }

    // MARK: - LLMService Protocol

    public func streamCompletion(
        messages: [LLMMessage],
        config: LLMConfig
    ) async throws -> AsyncStream<LLMToken> {
        // Get the last user message
        let lastUserMessage = messages.last { $0.role == .user }?.content ?? ""

        // Generate a response based on the input
        let response = generateResponse(for: lastUserMessage)

        logger.info("Mock LLM generating response for: \(lastUserMessage.prefix(50))...")

        // Simulate streaming by yielding words with small delays
        return AsyncStream { continuation in
            Task {
                // Simulate initial latency
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

                let words = response.components(separatedBy: " ")
                for (index, word) in words.enumerated() {
                    let isLast = index == words.count - 1
                    let content = isLast ? word : word + " "

                    continuation.yield(LLMToken(
                        content: content,
                        isDone: isLast,
                        stopReason: isLast ? .endTurn : nil,
                        tokenCount: 1
                    ))

                    // Small delay between words to simulate streaming
                    try? await Task.sleep(nanoseconds: 30_000_000) // 30ms per word
                }

                continuation.finish()
            }
        }
    }

    // MARK: - Response Generation

    private func generateResponse(for input: String) -> String {
        let lowercasedInput = input.lowercased()

        // Check for common patterns and generate appropriate responses
        if lowercasedInput.contains("hello") || lowercasedInput.contains("hi") || input.isEmpty {
            return greetings.randomElement()!
        }

        if lowercasedInput.contains("thank") {
            return "You're welcome! I'm here to help anytime. What else would you like to learn about?"
        }

        if lowercasedInput.contains("help") {
            return "I'd be happy to help! Just tell me what topic you'd like to explore, and we can work through it together. I can explain concepts, answer questions, or quiz you on material."
        }

        if lowercasedInput.contains("test") || lowercasedInput.contains("quiz") {
            return "Great idea! Testing yourself is an excellent way to learn. Let me think of a question for you... Actually, why don't you tell me what topic you'd like to be quizzed on?"
        }

        if lowercasedInput.contains("explain") {
            return "Sure, I'll explain that! \(acknowledgments.randomElement()!) The key thing to understand here is that learning happens best through practice and repetition. \(followUps.randomElement()!)"
        }

        // Default response for any other input
        return "\(acknowledgments.randomElement()!) Based on what you said about '\(input.prefix(30))...', I think this is an interesting topic to explore. In a real session, I would provide detailed information from my training. \(followUps.randomElement()!)"
    }
}
