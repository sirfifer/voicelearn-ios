// UnaMentis - AnthropicLLMServiceTests
// Unit tests for Anthropic LLM Service
//
// Tests cover:
// - Initialization
// - Cost calculation
// - Model configuration

import XCTest
import Combine
@testable import UnaMentis

@MainActor
final class AnthropicLLMServiceTests: XCTestCase {
    
    var service: AnthropicLLMService!
    let apiKey = "test_anthropic_key"
    
    override func setUp() async throws {
        try await super.setUp()
        service = AnthropicLLMService(apiKey: apiKey)
    }
    
    override func tearDown() async throws {
        service = nil
        try await super.tearDown()
    }
    
    func testAnthropicServiceInitialization() async {
        XCTAssertNotNil(service)
    }
    
    func testAnthropicCostCalculation() async {
        // Claude 3.5 Sonnet: Input $3.00/MTok, Output $15.00/MTok
        // Input: $0.000003/token
        // Output: $0.000015/token
        
        let messages = [LLMMessage(role: .user, content: "Hello")] // ~1 token
        let response = "Hi there" // ~2 tokens
        
        let inputCost = await service.calculateCost(input: 1000, output: 0)
        XCTAssertEqual(NSDecimalNumber(decimal: inputCost).doubleValue, 0.003, accuracy: 0.0001)
        
        let outputCost = await service.calculateCost(input: 0, output: 1000)
        XCTAssertEqual(NSDecimalNumber(decimal: outputCost).doubleValue, 0.015, accuracy: 0.0001)
    }
    
    // Note: Streaming tests require mocking URLSession which is complex
}
