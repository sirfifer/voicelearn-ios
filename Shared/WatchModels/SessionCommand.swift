// UnaMentis - Session Command
// Commands sent from Watch to iOS to control session
//
// Used by both iOS and watchOS targets via target membership

import Foundation

/// Commands that can be sent from Watch to iOS
public enum SessionCommand: String, Codable, Sendable, CaseIterable {
    case pause = "pause"
    case resume = "resume"
    case mute = "mute"
    case unmute = "unmute"
    case stop = "stop"

    /// Human-readable description for logging
    public var commandDescription: String {
        switch self {
        case .pause: return "Pause Session"
        case .resume: return "Resume Session"
        case .mute: return "Mute Microphone"
        case .unmute: return "Unmute Microphone"
        case .stop: return "Stop Session"
        }
    }
}

/// Response sent back to Watch after command execution
public struct CommandResponse: Codable, Sendable {
    public let command: SessionCommand
    public let success: Bool
    public let error: String?
    public let updatedState: WatchSessionState?

    public init(
        command: SessionCommand,
        success: Bool,
        error: String? = nil,
        updatedState: WatchSessionState? = nil
    ) {
        self.command = command
        self.success = success
        self.error = error
        self.updatedState = updatedState
    }
}
