// UnaMentis - Anthropic LLM Service
// Streaming LLM interface for Claude 3.5 Sonnet
//
// Part of Provider Implementations (Phase 5)

import Foundation
import Logging

/// Anthropic Claude 3.5 Sonnet streaming LLM implementation
public actor AnthropicLLMService: LLMService {
    
    // MARK: - Properties
    
    private let logger = Logger(label: "com.unamentis.llm.anthropic")
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-3-5-sonnet-20241022"
    
    public private(set) var metrics = LLMMetrics(
        medianTTFT: 0.5,
        p99TTFT: 0.8,
        totalInputTokens: 0,
        totalOutputTokens: 0
    )
    
    /// Estimated cost per 1M tokens: Input $3.00, Output $15.00
    private let inputCostPerToken: Decimal = 3.00 / 1_000_000
    private let outputCostPerToken: Decimal = 15.00 / 1_000_000
    
    // MARK: - Initialization
    
    public init(apiKey: String) {
        self.apiKey = apiKey
        logger.info("AnthropicLLMService initialized with default model: \(model)")
    }
    
    // MARK: - LLMService Protocol
    
    public var costPerInputToken: Decimal { inputCostPerToken }
    public var costPerOutputToken: Decimal { outputCostPerToken }
    
    public func streamCompletion(
        messages: [LLMMessage],
        config: LLMConfig
    ) async throws -> AsyncStream<LLMToken> {
        // Use config model or default
        let model = config.model
        
        // Construct messages
        var requestMessages = messages.map { mapMessage($0) }
        
        // Build request body
        let body: [String: Any] = [
            "model": model,
            "max_tokens": config.maxTokens,
            "stream": true,
            "system": config.systemPrompt as Any,
            "messages": requestMessages,
            "temperature": config.temperature
        ].compactMapValues { $0 }
        
        // Build URL Request
        guard let url = URL(string: baseURL) else { throw LLMError.connectionFailed("Invalid URL") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return AsyncStream { continuation in
            Task {
                do {
                    let startTime = Date()
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse, 
                          (200...299).contains(httpResponse.statusCode) else {
                        throw LLMError.rateLimited(retryAfter: nil) // Simplified, could parse retry header
                    }
                    
                    var isFirst = true
                    var fullText = ""
                    
                    for try await line in bytes.lines {
                        guard line.starts(with: "data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        
                        if jsonStr == "[DONE]" { break }
                        
                        guard let data = jsonStr.data(using: .utf8),
                              let event = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: data) else {
                            continue
                        }
                        
                        // Handle content block delta
                        if let delta = event.delta, let text = delta.text {
                            let ttft = isFirst ? Date().timeIntervalSince(startTime) : 0
                            if isFirst { isFirst = false }
                            
                            fullText += text
                            
                            let token = LLMToken(
                                content: text,
                                isDone: false
                            )
                            continuation.yield(token)
                        }
                        
                        // Handle completion (message_stop)
                        if event.type == "message_stop" {
                            break
                        }
                    }
                    
                    // Final token
                    let finalToken = LLMToken(
                        content: "",
                        isDone: true,
                        stopReason: .endTurn,
                        tokenCount: Int(Double(fullText.count) / 4.0) // Approximation
                    )
                    continuation.yield(finalToken)
                    continuation.finish()
                    
                } catch {
                    logger.error("Anthropic stream failed: \(error)")
                    continuation.finish()
                }
            }
        }
    }
    
    public func complete(messages: [LLMMessage], config: LLMConfig) async throws -> String {
        // Use default implementation via protocol extension which calls streamCompletion
        var result = ""
        let stream = try await streamCompletion(messages: messages, config: config)
        for await token in stream {
            result += token.content
        }
        return result
    }
    
    public func calculateCost(input: Int, output: Int) async -> Decimal {
        let inputDecimal = Decimal(input)
        let outputDecimal = Decimal(output)
        return (inputDecimal * inputCostPerToken) + (outputDecimal * outputCostPerToken)
    }
    
    // MARK: - Private Methods
    
    private func mapMessage(_ message: LLMMessage) -> [String: String] {
        return [
            "role": message.role == .user ? "user" : "assistant",
            "content": message.content
        ]
    }
}

// MARK: - Models

private struct AnthropicStreamEvent: Codable {
    let type: String
    let delta: Delta?
    
    struct Delta: Codable {
        let type: String?
        let text: String?
    }
}
