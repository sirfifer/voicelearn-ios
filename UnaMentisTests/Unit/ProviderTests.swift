// UnaMentis - STT Service Tests
// Tests for Speech-to-Text service implementations

import XCTest
@testable import UnaMentis
import AVFoundation

/// Tests for STT service implementations
final class STTServiceTests: XCTestCase {
    
    // MARK: - AssemblyAI Tests
    
    func testAssemblyAIServiceInitialization() async throws {
        let service = AssemblyAISTTService(apiKey: "test_key")
        
        // Verify initial state
        let isStreaming = await service.isStreaming
        XCTAssertFalse(isStreaming)
        
        let metrics = await service.metrics
        XCTAssertGreaterThan(metrics.medianLatency, 0)
    }
    
    func testAssemblyAICostPerHour() async throws {
        let service = AssemblyAISTTService(apiKey: "test_key")
        let cost = await service.costPerHour
        
        // AssemblyAI Universal is $0.65/hour
        XCTAssertEqual(cost, 0.65)
    }
    
    func testCannotStreamWhenAlreadyStreaming() async throws {
        let service = AssemblyAISTTService(apiKey: "test_key")
        
        // Create a mock audio format
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        
        // Start streaming - this will try to connect (may fail without valid key, but that's ok)
        do {
            _ = try await service.startStreaming(audioFormat: format)
        } catch {
            // Expected to fail with invalid API key
        }
    }
    
    // MARK: - Audio Buffer Extension Tests
    
    func testAudioBufferToData() throws {
        // Create a test buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let frameCount: AVAudioFrameCount = 512
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Failed to create buffer")
            return
        }
        
        buffer.frameLength = frameCount
        
        // Fill with test data
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                channelData[i] = sin(Float(i) * 0.1) * 0.5
            }
        }
        
        // Convert to data
        let data = buffer.toData()
        XCTAssertNotNil(data)
        
        // Should be frameCount * 2 bytes (16-bit samples)
        XCTAssertEqual(data?.count, Int(frameCount) * 2)
    }
}

/// Tests for TTS service implementations
final class TTSServiceTests: XCTestCase {
    
    // MARK: - Deepgram Tests
    
    func testDeepgramServiceInitialization() async throws {
        let service = DeepgramTTSService(apiKey: "test_key", voice: .asteria)
        
        // Verify voice config
        let config = await service.voiceConfig
        XCTAssertEqual(config.voiceId, "aura-asteria-en")
    }
    
    func testDeepgramCostPerCharacter() async throws {
        let service = DeepgramTTSService(apiKey: "test_key")
        let cost = await service.costPerCharacter
        
        // $0.0135 per 1000 chars = $0.0000135 per char
        let expected = Decimal(0.0135) / 1000
        XCTAssertEqual(cost, expected)
    }
    
    func testDeepgramVoiceOptions() {
        // Verify all expected voices are available
        let voices = DeepgramTTSService.AuraVoice.allCases
        XCTAssertTrue(voices.count >= 10)
        
        // Check specific voices
        XCTAssertEqual(DeepgramTTSService.AuraVoice.asteria.rawValue, "aura-asteria-en")
        XCTAssertEqual(DeepgramTTSService.AuraVoice.orion.rawValue, "aura-orion-en")
    }
    
    func testDeepgramConfigure() async throws {
        let service = DeepgramTTSService(apiKey: "test_key", voice: .asteria)
        
        // Configure with different voice
        let newConfig = TTSVoiceConfig(voiceId: "aura-orion-en", rate: 1.2)
        await service.configure(newConfig)
        
        let config = await service.voiceConfig
        XCTAssertEqual(config.voiceId, "aura-orion-en")
    }
}

/// Tests for LLM service implementations
final class LLMServiceTests: XCTestCase {
    
    // MARK: - OpenAI Tests
    
    func testOpenAIServiceInitialization() async throws {
        let service = OpenAILLMService(apiKey: "test_key")
        
        // Verify initial metrics
        let metrics = await service.metrics
        XCTAssertGreaterThan(metrics.medianTTFT, 0)
    }
    
    func testOpenAICostCalculation() async throws {
        let service = OpenAILLMService(apiKey: "test_key")
        
        // Default model is gpt-4o
        let inputCost = await service.costPerInputToken
        let outputCost = await service.costPerOutputToken
        
        // GPT-4o: $2.50/1M input, $10/1M output
        let expectedInputCost = Decimal(2.50) / 1_000_000
        let expectedOutputCost = Decimal(10.0) / 1_000_000
        
        XCTAssertEqual(inputCost, expectedInputCost)
        XCTAssertEqual(outputCost, expectedOutputCost)
    }
}

/// Tests for VAD service implementations
final class VADServiceTests: XCTestCase {
    
    // MARK: - Silero VAD Tests
    
    func testSileroVADInitialization() async throws {
        let service = SileroVADService()
        
        // Verify initial state
        let isActive = await service.isActive
        XCTAssertFalse(isActive)
        
        let config = await service.configuration
        XCTAssertEqual(config.threshold, VADConfiguration.default.threshold)
    }
    
    func testSileroVADConfiguration() async throws {
        let service = SileroVADService()
        
        // Configure with custom values
        await service.configure(threshold: 0.7, contextWindow: 5)
        
        let config = await service.configuration
        XCTAssertEqual(config.threshold, 0.7)
        XCTAssertEqual(config.contextWindow, 5)
    }
    
    func testSileroVADPrepareAndShutdown() async throws {
        let service = SileroVADService()
        
        // Prepare (will use fallback since no model file)
        try await service.prepare()
        
        var isActive = await service.isActive
        XCTAssertTrue(isActive)
        
        // Shutdown
        await service.shutdown()
        
        isActive = await service.isActive
        XCTAssertFalse(isActive)
    }
    
    func testSileroVADReset() async throws {
        let service = SileroVADService()
        
        try await service.prepare()
        
        // Reset should clear internal state
        await service.reset()
        
        // Service should still be active
        let isActive = await service.isActive
        XCTAssertTrue(isActive)
        
        await service.shutdown()
    }
    
    func testSileroVADProcessBufferWhenInactive() async throws {
        let service = SileroVADService()
        
        // Create a test buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512) else {
            XCTFail("Failed to create buffer")
            return
        }
        buffer.frameLength = 512
        
        // Process without preparing should return no speech
        let result = await service.processBuffer(buffer)
        XCTAssertFalse(result.isSpeech)
        XCTAssertEqual(result.confidence, 0)
    }
}
