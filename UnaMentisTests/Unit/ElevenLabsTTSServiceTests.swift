// UnaMentis - ElevenLabsTTSServiceTests
// Unit tests for ElevenLabs TTS Service
//
// Tests cover:
// - Initialization
// - Voice configuration
// - Cost calculation

import XCTest
import AVFoundation
@testable import UnaMentis

@MainActor
final class ElevenLabsTTSServiceTests: XCTestCase {
    
    var service: ElevenLabsTTSService!
    let apiKey = "test_elevenlabs_key"
    
    override func setUp() async throws {
        try await super.setUp()
        service = ElevenLabsTTSService(apiKey: apiKey)
    }
    
    override func tearDown() async throws {
        service = nil
        try await super.tearDown()
    }
    
    func testElevenLabsServiceInitialization() async {
        XCTAssertNotNil(service)
    }
    
    func testElevenLabsCostPerCharacter() async {
        // ElevenLabs Turbo is ~$0.015/1000 chars (standard tier)
        // Flash is cheaper.
        // We'll verify cost calculation logic
        let cost = await service.costPerCharacter
        XCTAssertEqual(NSDecimalNumber(decimal: cost).doubleValue, 0.000018, accuracy: 0.000001) // $18/1m chars for Turbo v2.5
    }
    
    func testElevenLabsVoiceConfig() async {
        let config = TTSVoiceConfig(voiceId: "cjVigY5qzO862AIGy5LS") // Jessica
        await service.configure(config)
        let voiceId = await service.voiceConfig.voiceId
        XCTAssertEqual(voiceId, "cjVigY5qzO862AIGy5LS")
    }
}
