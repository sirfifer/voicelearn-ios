// UnaMentis - LLM Endpoint Tests
// Tests for endpoint model, registry, and status management
//
// Part of Patch Panel routing system

import XCTest
@testable import UnaMentis

/// Tests for LLMEndpoint model
final class LLMEndpointTests: XCTestCase {

    // MARK: - Endpoint Creation Tests

    func testEndpointCreation() {
        let endpoint = LLMEndpoint(
            id: "test-endpoint",
            displayName: "Test Endpoint",
            provider: .openAI,
            location: .cloud,
            maxContextTokens: 128_000,
            maxOutputTokens: 4_096,
            supportsStreaming: true,
            supportsSystemPrompt: true,
            supportsFunctionCalling: true,
            expectedTTFTMs: 300,
            expectedTokensPerSec: 80,
            reliabilityScore: 0.99,
            costPerInputToken: 0.0000025,
            costPerOutputToken: 0.00001
        )

        XCTAssertEqual(endpoint.id, "test-endpoint")
        XCTAssertEqual(endpoint.displayName, "Test Endpoint")
        XCTAssertEqual(endpoint.provider, .openAI)
        XCTAssertEqual(endpoint.location, .cloud)
        XCTAssertEqual(endpoint.maxContextTokens, 128_000)
        XCTAssertEqual(endpoint.maxOutputTokens, 4_096)
        XCTAssertTrue(endpoint.supportsStreaming)
        XCTAssertTrue(endpoint.supportsSystemPrompt)
        XCTAssertTrue(endpoint.supportsFunctionCalling)
        XCTAssertEqual(endpoint.expectedTTFTMs, 300)
        XCTAssertEqual(endpoint.expectedTokensPerSec, 80)
        XCTAssertEqual(endpoint.reliabilityScore, 0.99)
        XCTAssertEqual(endpoint.costPerInputToken, 0.0000025)
        XCTAssertEqual(endpoint.costPerOutputToken, 0.00001)
    }

    func testEndpointWithConnectionConfig() {
        let config = EndpointConnectionConfig(
            apiKeyReference: "openai_api_key",
            baseURL: URL(string: "https://api.openai.com/v1")
        )

        var endpoint = LLMEndpoint(
            id: "gpt-4o",
            displayName: "GPT-4o",
            provider: .openAI,
            location: .cloud,
            maxContextTokens: 128_000,
            maxOutputTokens: 4_096,
            supportsStreaming: true,
            supportsSystemPrompt: true,
            supportsFunctionCalling: true,
            expectedTTFTMs: 300,
            expectedTokensPerSec: 80,
            reliabilityScore: 0.99,
            costPerInputToken: 0.0000025,
            costPerOutputToken: 0.00001
        )
        endpoint.connectionConfig = config

        XCTAssertEqual(endpoint.connectionConfig?.apiKeyReference, "openai_api_key")
        XCTAssertEqual(endpoint.connectionConfig?.baseURL?.absoluteString, "https://api.openai.com/v1")
    }

    // MARK: - Provider Tests

    func testEndpointProviderValues() {
        XCTAssertEqual(EndpointProvider.openAI.rawValue, "OpenAI")
        XCTAssertEqual(EndpointProvider.anthropic.rawValue, "Anthropic")
        XCTAssertEqual(EndpointProvider.selfHosted.rawValue, "Self-Hosted")
        XCTAssertEqual(EndpointProvider.onDevice.rawValue, "On-Device")
    }

    func testEndpointProviderIdentifiers() {
        XCTAssertEqual(EndpointProvider.openAI.identifier, "openai")
        XCTAssertEqual(EndpointProvider.anthropic.identifier, "anthropic")
        XCTAssertEqual(EndpointProvider.selfHosted.identifier, "selfhosted")
        XCTAssertEqual(EndpointProvider.onDevice.identifier, "ondevice")
    }

    func testEndpointProviderRequiresNetwork() {
        XCTAssertTrue(EndpointProvider.openAI.requiresNetwork)
        XCTAssertTrue(EndpointProvider.anthropic.requiresNetwork)
        XCTAssertTrue(EndpointProvider.selfHosted.requiresNetwork)
        XCTAssertFalse(EndpointProvider.onDevice.requiresNetwork)
    }

    // MARK: - Location Tests

    func testEndpointLocationValues() {
        XCTAssertEqual(EndpointLocation.cloud.rawValue, "cloud")
        XCTAssertEqual(EndpointLocation.localServer.rawValue, "localServer")
        XCTAssertEqual(EndpointLocation.onDevice.rawValue, "onDevice")
    }

    // MARK: - Status Tests

    func testEndpointStatusValues() {
        XCTAssertEqual(EndpointStatus.available.rawValue, "available")
        XCTAssertEqual(EndpointStatus.degraded.rawValue, "degraded")
        XCTAssertEqual(EndpointStatus.unavailable.rawValue, "unavailable")
        XCTAssertEqual(EndpointStatus.disabled.rawValue, "disabled")
        XCTAssertEqual(EndpointStatus.loading.rawValue, "loading")
    }

    func testEndpointStatusIsUsable() {
        XCTAssertTrue(EndpointStatus.available.isUsable)
        XCTAssertTrue(EndpointStatus.degraded.isUsable)
        XCTAssertFalse(EndpointStatus.unavailable.isUsable)
        XCTAssertFalse(EndpointStatus.disabled.isUsable)
        XCTAssertFalse(EndpointStatus.loading.isUsable)
    }

    // MARK: - Default Registry Tests

    func testDefaultRegistryContainsExpectedEndpoints() {
        let registry = LLMEndpoint.defaultRegistry

        // Should contain cloud endpoints
        XCTAssertTrue(registry.keys.contains("gpt-4o"))
        XCTAssertTrue(registry.keys.contains("gpt-4o-mini"))
        XCTAssertTrue(registry.keys.contains("claude-3.5-sonnet"))
        XCTAssertTrue(registry.keys.contains("claude-3.5-haiku"))

        // Should contain on-device endpoints
        XCTAssertTrue(registry.keys.contains("llama-3b-device"))
        XCTAssertTrue(registry.keys.contains("llama-1b-device"))
    }

    func testDefaultRegistryEndpointProperties() {
        let registry = LLMEndpoint.defaultRegistry

        // GPT-4o should have correct properties
        let gpt4o = registry["gpt-4o"]
        XCTAssertNotNil(gpt4o)
        XCTAssertEqual(gpt4o?.provider, .openAI)
        XCTAssertEqual(gpt4o?.location, .cloud)
        XCTAssertEqual(gpt4o?.maxContextTokens, 128_000)
        XCTAssertTrue(gpt4o?.supportsStreaming ?? false)

        // On-device should have zero cost
        let llama3b = registry["llama-3b-device"]
        XCTAssertNotNil(llama3b)
        XCTAssertEqual(llama3b?.provider, .onDevice)
        XCTAssertEqual(llama3b?.location, .onDevice)
        XCTAssertEqual(llama3b?.costPerInputToken, 0)
        XCTAssertEqual(llama3b?.costPerOutputToken, 0)
    }

    // MARK: - Codable Tests

    func testEndpointCodable() throws {
        let endpoint = LLMEndpoint(
            id: "test",
            displayName: "Test",
            provider: .openAI,
            location: .cloud,
            maxContextTokens: 1000,
            maxOutputTokens: 500,
            supportsStreaming: true,
            supportsSystemPrompt: true,
            supportsFunctionCalling: false,
            expectedTTFTMs: 100,
            expectedTokensPerSec: 50,
            reliabilityScore: 0.95,
            costPerInputToken: 0.001,
            costPerOutputToken: 0.002
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(endpoint)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LLMEndpoint.self, from: data)

        XCTAssertEqual(decoded.id, endpoint.id)
        XCTAssertEqual(decoded.displayName, endpoint.displayName)
        XCTAssertEqual(decoded.provider, endpoint.provider)
        XCTAssertEqual(decoded.location, endpoint.location)
        XCTAssertEqual(decoded.maxContextTokens, endpoint.maxContextTokens)
        XCTAssertEqual(decoded.costPerInputToken, endpoint.costPerInputToken)
    }

    func testConnectionConfigCodable() throws {
        let config = EndpointConnectionConfig(
            apiKeyReference: "test_key",
            baseURL: URL(string: "https://api.test.com"),
            apiVersion: "v1",
            serverHost: "localhost",
            serverPort: 11434,
            modelPath: "/models/test.mlmodelc",
            computeUnits: .cpuAndNeuralEngine
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(EndpointConnectionConfig.self, from: data)

        XCTAssertEqual(decoded.apiKeyReference, config.apiKeyReference)
        XCTAssertEqual(decoded.baseURL, config.baseURL)
        XCTAssertEqual(decoded.serverHost, config.serverHost)
        XCTAssertEqual(decoded.serverPort, config.serverPort)
        XCTAssertEqual(decoded.modelPath, config.modelPath)
        XCTAssertEqual(decoded.computeUnits, config.computeUnits)
    }

    // MARK: - Cost Calculation Tests

    func testEndpointCostEstimation() {
        let endpoint = LLMEndpoint(
            id: "test",
            displayName: "Test",
            provider: .openAI,
            location: .cloud,
            maxContextTokens: 128_000,
            maxOutputTokens: 4_096,
            supportsStreaming: true,
            supportsSystemPrompt: true,
            supportsFunctionCalling: true,
            expectedTTFTMs: 300,
            expectedTokensPerSec: 80,
            reliabilityScore: 0.99,
            costPerInputToken: 0.0000025,  // $2.50 per 1M
            costPerOutputToken: 0.00001    // $10 per 1M
        )

        // 1000 input tokens, 500 output tokens
        let cost = endpoint.estimateCost(inputTokens: 1000, outputTokens: 500)

        // Expected: (1000 * 0.0000025) + (500 * 0.00001) = 0.0025 + 0.005 = 0.0075
        XCTAssertEqual(cost, 0.0075, accuracy: 0.0001)
    }

    func testOnDeviceEndpointHasZeroCost() {
        let endpoint = LLMEndpoint(
            id: "llama-device",
            displayName: "Llama Device",
            provider: .onDevice,
            location: .onDevice,
            maxContextTokens: 4_096,
            maxOutputTokens: 512,
            supportsStreaming: true,
            supportsSystemPrompt: true,
            supportsFunctionCalling: false,
            expectedTTFTMs: 200,
            expectedTokensPerSec: 15,
            reliabilityScore: 0.95,
            costPerInputToken: 0,
            costPerOutputToken: 0
        )

        let cost = endpoint.estimateCost(inputTokens: 10000, outputTokens: 1000)
        XCTAssertEqual(cost, 0)
    }
}

/// Tests for EndpointConnectionConfig
final class EndpointConnectionConfigTests: XCTestCase {

    func testCloudConnectionConfig() {
        let config = EndpointConnectionConfig.cloudConfig(
            apiKeyReference: "openai_key",
            baseURL: URL(string: "https://api.openai.com/v1")!
        )

        XCTAssertEqual(config.apiKeyReference, "openai_key")
        XCTAssertEqual(config.baseURL?.absoluteString, "https://api.openai.com/v1")
        XCTAssertNil(config.serverHost)
        XCTAssertNil(config.modelPath)
    }

    func testServerConnectionConfig() {
        let config = EndpointConnectionConfig.serverConfig(
            host: "192.168.1.100",
            port: 11434
        )

        XCTAssertEqual(config.serverHost, "192.168.1.100")
        XCTAssertEqual(config.serverPort, 11434)
        XCTAssertNil(config.apiKeyReference)
        XCTAssertNil(config.modelPath)
    }

    func testOnDeviceConnectionConfig() {
        let config = EndpointConnectionConfig.onDeviceConfig(
            modelPath: "/models/llama-3b.mlmodelc",
            computeUnits: .cpuAndNeuralEngine
        )

        XCTAssertEqual(config.modelPath, "/models/llama-3b.mlmodelc")
        XCTAssertEqual(config.computeUnits, .cpuAndNeuralEngine)
        XCTAssertNil(config.apiKeyReference)
        XCTAssertNil(config.serverHost)
    }
}
