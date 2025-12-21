// UnaMentis - Session Manager Tests
// Tests for session orchestration

import XCTest
@testable import UnaMentis

/// Tests for SessionManager
final class SessionManagerTests: XCTestCase {
    
    var telemetry: TelemetryEngine!
    
    override func setUp() async throws {
        telemetry = TelemetryEngine()
    }
    
    override func tearDown() async throws {
        telemetry = nil
    }
    
    // MARK: - Initialization Tests

    @MainActor
    func testSessionManagerInitialization() async throws {
        let manager = SessionManager(telemetry: telemetry)
        
        // Verify initial state
        let state = await manager.state
        XCTAssertEqual(state, .idle)
        
        let transcript = await manager.userTranscript
        XCTAssertTrue(transcript.isEmpty)
        
        let response = await manager.aiResponse
        XCTAssertTrue(response.isEmpty)
    }
    
    @MainActor
    func testSessionManagerWithCustomConfig() async throws {
        let config = SessionConfig(
            systemPrompt: "Custom tutor prompt",
            enableCostTracking: false,
            maxDuration: 3600
        )

        let manager = SessionManager(config: config, telemetry: telemetry)
        
        let state = await manager.state
        XCTAssertEqual(state, .idle)
    }
    
    // MARK: - State Tests
    
    func testSessionStateProperties() {
        // Active states
        XCTAssertTrue(SessionState.userSpeaking.isActive)
        XCTAssertTrue(SessionState.aiThinking.isActive)
        XCTAssertTrue(SessionState.aiSpeaking.isActive)
        XCTAssertTrue(SessionState.interrupted.isActive)
        XCTAssertTrue(SessionState.processingUserUtterance.isActive)
        
        // Inactive states
        XCTAssertFalse(SessionState.idle.isActive)
        XCTAssertFalse(SessionState.error.isActive)
    }
    
    func testSessionStateRawValues() {
        XCTAssertEqual(SessionState.idle.rawValue, "Idle")
        XCTAssertEqual(SessionState.userSpeaking.rawValue, "User Speaking")
        XCTAssertEqual(SessionState.aiThinking.rawValue, "AI Thinking")
        XCTAssertEqual(SessionState.aiSpeaking.rawValue, "AI Speaking")
        XCTAssertEqual(SessionState.interrupted.rawValue, "Interrupted")
    }
    
    // MARK: - Configuration Tests
    
    func testDefaultSessionConfig() {
        let config = SessionConfig.default
        
        XCTAssertEqual(config.enableCostTracking, true)
        XCTAssertEqual(config.enableInterruptions, true)
        XCTAssertEqual(config.maxDuration, 5400) // 90 minutes
        XCTAssertFalse(config.systemPrompt.isEmpty)
    }
    
    func testSessionConfigCodable() throws {
        let config = SessionConfig(
            systemPrompt: "Test prompt",
            enableCostTracking: true,
            maxDuration: 1800,
            enableInterruptions: false
        )
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SessionConfig.self, from: data)
        
        XCTAssertEqual(decoded.systemPrompt, "Test prompt")
        XCTAssertEqual(decoded.enableCostTracking, true)
        XCTAssertEqual(decoded.maxDuration, 1800)
        XCTAssertEqual(decoded.enableInterruptions, false)
    }
}

/// Tests for SessionErrors
final class SessionErrorTests: XCTestCase {
    
    func testSessionErrorDescriptions() {
        XCTAssertEqual(
            SessionError.servicesNotConfigured.errorDescription,
            "Required services not configured"
        )
        XCTAssertEqual(
            SessionError.sessionAlreadyActive.errorDescription,
            "Session is already active"
        )
        XCTAssertEqual(
            SessionError.sessionNotActive.errorDescription,
            "No active session"
        )
    }
}
