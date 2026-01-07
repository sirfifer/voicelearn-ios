// UnaMentis Tests - Watch Session State Tests

import XCTest
@testable import UnaMentis

final class WatchSessionStateTests: XCTestCase {

    func testEncodingDecodingRoundtrip() throws {
        let state = WatchSessionState(
            isActive: true,
            isPaused: false,
            isMuted: true,
            curriculumTitle: "Calculus 101",
            topicTitle: "Derivatives",
            sessionMode: .curriculum,
            currentSegment: 5,
            totalSegments: 20,
            elapsedSeconds: 300,
            timestamp: Date()
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(WatchSessionState.self, from: data)

        XCTAssertEqual(decoded.isActive, true)
        XCTAssertEqual(decoded.isPaused, false)
        XCTAssertEqual(decoded.isMuted, true)
        XCTAssertEqual(decoded.curriculumTitle, "Calculus 101")
        XCTAssertEqual(decoded.topicTitle, "Derivatives")
        XCTAssertEqual(decoded.sessionMode, .curriculum)
        XCTAssertEqual(decoded.currentSegment, 5)
        XCTAssertEqual(decoded.totalSegments, 20)
        XCTAssertEqual(decoded.elapsedSeconds, 300, accuracy: 0.01)
    }

    func testProgressPercentageCalculation() {
        let state = WatchSessionState(
            isActive: true,
            isPaused: false,
            isMuted: false,
            curriculumTitle: nil,
            topicTitle: nil,
            sessionMode: .curriculum,
            currentSegment: 5,
            totalSegments: 20,
            elapsedSeconds: 0
        )

        XCTAssertEqual(state.progressPercentage, 0.25, accuracy: 0.01)
    }

    func testProgressPercentageZeroSegments() {
        let state = WatchSessionState(
            isActive: true,
            isPaused: false,
            isMuted: false,
            curriculumTitle: nil,
            topicTitle: nil,
            sessionMode: .freeform,
            currentSegment: 0,
            totalSegments: 0,
            elapsedSeconds: 0
        )

        XCTAssertEqual(state.progressPercentage, 0.0)
    }

    func testProgressPercentageComplete() {
        let state = WatchSessionState(
            isActive: true,
            isPaused: false,
            isMuted: false,
            curriculumTitle: nil,
            topicTitle: nil,
            sessionMode: .curriculum,
            currentSegment: 10,
            totalSegments: 10,
            elapsedSeconds: 0
        )

        XCTAssertEqual(state.progressPercentage, 1.0, accuracy: 0.01)
    }

    func testIdleStateConstant() {
        let idle = WatchSessionState.idle

        XCTAssertFalse(idle.isActive)
        XCTAssertFalse(idle.isPaused)
        XCTAssertFalse(idle.isMuted)
        XCTAssertNil(idle.curriculumTitle)
        XCTAssertNil(idle.topicTitle)
        XCTAssertEqual(idle.sessionMode, .freeform)
        XCTAssertEqual(idle.currentSegment, 0)
        XCTAssertEqual(idle.totalSegments, 0)
    }

    func testSessionModeDisplayNames() {
        XCTAssertEqual(WatchSessionState.SessionMode.freeform.displayName, "Voice Chat")
        XCTAssertEqual(WatchSessionState.SessionMode.curriculum.displayName, "Lesson")
        XCTAssertEqual(WatchSessionState.SessionMode.directStreaming.displayName, "Lecture")
    }

    func testEquatable() {
        let state1 = WatchSessionState(
            isActive: true,
            isPaused: false,
            isMuted: false,
            curriculumTitle: "Math",
            topicTitle: "Algebra",
            sessionMode: .curriculum,
            currentSegment: 1,
            totalSegments: 10,
            elapsedSeconds: 60,
            timestamp: Date(timeIntervalSince1970: 1000)
        )

        let state2 = WatchSessionState(
            isActive: true,
            isPaused: false,
            isMuted: false,
            curriculumTitle: "Math",
            topicTitle: "Algebra",
            sessionMode: .curriculum,
            currentSegment: 1,
            totalSegments: 10,
            elapsedSeconds: 60,
            timestamp: Date(timeIntervalSince1970: 1000)
        )

        XCTAssertEqual(state1, state2)
    }
}

// MARK: - SessionCommand Tests

final class SessionCommandTests: XCTestCase {

    func testCommandEncodingDecoding() throws {
        for command in SessionCommand.allCases {
            let data = try JSONEncoder().encode(command)
            let decoded = try JSONDecoder().decode(SessionCommand.self, from: data)
            XCTAssertEqual(decoded, command)
        }
    }

    func testCommandDescriptions() {
        XCTAssertEqual(SessionCommand.pause.commandDescription, "Pause Session")
        XCTAssertEqual(SessionCommand.resume.commandDescription, "Resume Session")
        XCTAssertEqual(SessionCommand.mute.commandDescription, "Mute Microphone")
        XCTAssertEqual(SessionCommand.unmute.commandDescription, "Unmute Microphone")
        XCTAssertEqual(SessionCommand.stop.commandDescription, "Stop Session")
    }

    func testCommandResponseSuccess() {
        let response = CommandResponse(
            command: .pause,
            success: true,
            error: nil,
            updatedState: nil
        )

        XCTAssertEqual(response.command, .pause)
        XCTAssertTrue(response.success)
        XCTAssertNil(response.error)
        XCTAssertNil(response.updatedState)
    }

    func testCommandResponseFailure() {
        let response = CommandResponse(
            command: .stop,
            success: false,
            error: "No active session",
            updatedState: nil
        )

        XCTAssertEqual(response.command, .stop)
        XCTAssertFalse(response.success)
        XCTAssertEqual(response.error, "No active session")
    }

    func testCommandResponseWithState() throws {
        let state = WatchSessionState(
            isActive: true,
            isPaused: true,
            isMuted: false,
            curriculumTitle: nil,
            topicTitle: nil,
            sessionMode: .freeform,
            currentSegment: 0,
            totalSegments: 0,
            elapsedSeconds: 0
        )

        let response = CommandResponse(
            command: .pause,
            success: true,
            error: nil,
            updatedState: state
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(CommandResponse.self, from: data)

        XCTAssertEqual(decoded.command, .pause)
        XCTAssertTrue(decoded.success)
        XCTAssertNotNil(decoded.updatedState)
        XCTAssertEqual(decoded.updatedState?.isPaused, true)
    }
}
