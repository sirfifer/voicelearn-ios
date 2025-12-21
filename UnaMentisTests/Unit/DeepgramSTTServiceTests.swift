// UnaMentis - DeepgramSTTServiceTests
// Unit tests for Deepgram STT Service
//
// Tests cover:
// - Initialization
// - Streaming configuration
// - Cost calculation

import XCTest
import AVFoundation
@testable import UnaMentis

@MainActor
final class DeepgramSTTServiceTests: XCTestCase {
    
    var service: DeepgramSTTService!
    let apiKey = "test_deepgram_key"
    
    override func setUp() async throws {
        try await super.setUp()
        service = DeepgramSTTService(apiKey: apiKey)
    }
    
    override func tearDown() async throws {
        service = nil
        try await super.tearDown()
    }
    
    func testDeepgramServiceInitialization() async {
        XCTAssertNotNil(service)
        let streaming = await service.isStreaming
        XCTAssertFalse(streaming)
    }
    
    func testDeepgramCostPerMinute() async {
        // Deepgram Nova-2 is $0.0043/min ($0.000072/sec) approx
        // We'll verify cost calculation logic
        let cost = await service.costPerHour
        // Expected: $0.26 / hour ($0.0043 * 60)
        XCTAssertEqual(NSDecimalNumber(decimal: cost).doubleValue, 0.258, accuracy: 0.01)
    }
    
    // Note: Streaming tests require mocking URLSessionWebSocketTask which is complex
    // We will verifying public API and state transitions
}
