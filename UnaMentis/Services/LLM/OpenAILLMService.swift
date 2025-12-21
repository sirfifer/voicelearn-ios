// UnaMentis - OpenAI LLM Service
// Streaming LLM using OpenAI GPT-4o/GPT-4o-mini
//
// Part of Provider Implementations (TDD Section 6)

import Foundation
import Logging

/// OpenAI GPT-4 streaming LLM implementation
///
/// Provides:
/// - Streaming token generation
/// - Token counting and cost tracking
/// - Multiple model support (gpt-4o, gpt-4o-mini)
public actor OpenAILLMService: LLMService {
    
    // MARK: - Properties
    
    private let logger = Logger(label: "com.unamentis.llm.openai")
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    /// Performance metrics
    public private(set) var metrics: LLMMetrics = LLMMetrics(
        medianTTFT: 0.2,
        p99TTFT: 0.5,
        totalInputTokens: 0,
        totalOutputTokens: 0
    )
    
    /// Cost per input token (GPT-4o: $2.50/1M, GPT-4o-mini: $0.15/1M)
    public var costPerInputToken: Decimal {
        currentModel.contains("mini") ? Decimal(0.15) / 1_000_000 : Decimal(2.50) / 1_000_000
    }
    
    /// Cost per output token (GPT-4o: $10/1M, GPT-4o-mini: $0.60/1M)
    public var costPerOutputToken: Decimal {
        currentModel.contains("mini") ? Decimal(0.60) / 1_000_000 : Decimal(10.0) / 1_000_000
    }
    
    /// Current model in use
    private var currentModel: String = "gpt-4o"
    
    /// Track TTFT for metrics
    private var ttftValues: [TimeInterval] = []
    private var totalInputTokensCount: Int = 0
    private var totalOutputTokensCount: Int = 0
    
    // MARK: - Initialization
    
    public init(apiKey: String) {
        self.apiKey = apiKey
        logger.info("OpenAILLMService initialized")
    }
    
    // MARK: - LLMService Protocol
    
    public func streamCompletion(
        messages: [LLMMessage],
        config: LLMConfig
    ) async throws -> AsyncStream<LLMToken> {
        currentModel = config.model
        
        logger.info("Starting stream completion with model: \(config.model)")
        let startTime = Date()
        
        // Build request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build message array
        var apiMessages: [[String: String]] = []
        
        if let systemPrompt = config.systemPrompt {
            apiMessages.append(["role": "system", "content": systemPrompt])
        }
        
        for message in messages {
            apiMessages.append([
                "role": message.role.rawValue,
                "content": message.content
            ])
        }
        
        var body: [String: Any] = [
            "model": config.model,
            "messages": apiMessages,
            "max_tokens": config.maxTokens,
            "temperature": config.temperature,
            "stream": config.stream
        ]
        
        if let topP = config.topP {
            body["top_p"] = topP
        }
        
        if let stops = config.stopSequences {
            body["stop"] = stops
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Estimate input tokens (rough: 4 chars per token)
        let inputChars = apiMessages.reduce(0) { $0 + ($1["content"]?.count ?? 0) }
        let estimatedInputTokens = inputChars / 4
        totalInputTokensCount += estimatedInputTokens
        
        return AsyncStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LLMError.connectionFailed("Invalid response")
                    }
                    
                    if httpResponse.statusCode == 401 {
                        throw LLMError.authenticationFailed
                    }
                    
                    if httpResponse.statusCode == 429 {
                        let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                            .flatMap { Double($0) }
                        throw LLMError.rateLimited(retryAfter: retryAfter)
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        throw LLMError.connectionFailed("HTTP \(httpResponse.statusCode)")
                    }
                    
                    var isFirst = true
                    var outputTokens = 0
                    var lineBuffer = ""
                    
                    for try await byte in bytes {
                        lineBuffer.append(Character(UnicodeScalar(byte)))
                        
                        // Process complete lines
                        while let newlineIndex = lineBuffer.firstIndex(of: "\n") {
                            let line = String(lineBuffer[..<newlineIndex])
                            lineBuffer.removeSubrange(...newlineIndex)
                            
                            // Parse SSE data
                            if line.hasPrefix("data: ") {
                                let jsonStr = String(line.dropFirst(6))
                                
                                if jsonStr == "[DONE]" {
                                    continuation.yield(LLMToken(
                                        content: "",
                                        isDone: true,
                                        stopReason: .endTurn,
                                        tokenCount: outputTokens
                                    ))
                                    self.totalOutputTokensCount += outputTokens
                                    await self.updateMetrics()
                                    continuation.finish()
                                    return
                                }
                                
                                if let data = jsonStr.data(using: .utf8),
                                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let choices = json["choices"] as? [[String: Any]],
                                   let firstChoice = choices.first,
                                   let delta = firstChoice["delta"] as? [String: Any],
                                   let content = delta["content"] as? String {
                                    
                                    if isFirst {
                                        let ttft = Date().timeIntervalSince(startTime)
                                        self.ttftValues.append(ttft)
                                        isFirst = false
                                    }
                                    
                                    outputTokens += 1  // Rough estimate
                                    
                                    // Check for finish reason
                                    let finishReason = firstChoice["finish_reason"] as? String
                                    let stopReason: StopReason? = finishReason.flatMap { reason in
                                        switch reason {
                                        case "stop": return .endTurn
                                        case "length": return .maxTokens
                                        default: return nil
                                        }
                                    }
                                    
                                    continuation.yield(LLMToken(
                                        content: content,
                                        isDone: stopReason != nil,
                                        stopReason: stopReason
                                    ))
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    self.logger.error("LLM stream failed: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateMetrics() {
        let sorted = ttftValues.sorted()
        let medianIndex = sorted.count / 2
        let p99Index = Int(Double(sorted.count) * 0.99)
        
        metrics = LLMMetrics(
            medianTTFT: sorted.isEmpty ? 0.2 : sorted[medianIndex],
            p99TTFT: sorted.isEmpty ? 0.5 : sorted[Swift.min(p99Index, Swift.max(0, sorted.count - 1))],
            totalInputTokens: totalInputTokensCount,
            totalOutputTokens: totalOutputTokensCount
        )
    }
}
