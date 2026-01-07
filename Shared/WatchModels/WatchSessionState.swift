// UnaMentis - Watch Session State
// Shared model for iOS <-> Watch state synchronization
//
// Used by both iOS and watchOS targets via target membership

import Foundation

/// State synchronized from iOS to Watch for session display
public struct WatchSessionState: Codable, Sendable, Equatable {
    /// Whether a tutoring session is currently active
    public let isActive: Bool

    /// Whether the session is paused
    public let isPaused: Bool

    /// Whether the microphone is muted
    public let isMuted: Bool

    // MARK: - Context Display

    /// Curriculum name (if curriculum-based session)
    public let curriculumTitle: String?

    /// Topic name being studied
    public let topicTitle: String?

    /// Session mode identifier
    public let sessionMode: SessionMode

    // MARK: - Progress Tracking

    /// Current segment index (0-based)
    public let currentSegment: Int

    /// Total number of segments
    public let totalSegments: Int

    /// Progress percentage (0.0 to 1.0)
    public var progressPercentage: Double {
        guard totalSegments > 0 else { return 0.0 }
        return Double(currentSegment) / Double(totalSegments)
    }

    // MARK: - Timing

    /// Elapsed time in seconds since session start
    public let elapsedSeconds: TimeInterval

    /// Timestamp when state was generated (for staleness detection)
    public let timestamp: Date

    // MARK: - Session Mode

    public enum SessionMode: String, Codable, Sendable {
        case freeform = "freeform"
        case curriculum = "curriculum"
        case directStreaming = "directStreaming"

        public var displayName: String {
            switch self {
            case .freeform: return "Voice Chat"
            case .curriculum: return "Lesson"
            case .directStreaming: return "Lecture"
            }
        }
    }

    // MARK: - Initialization

    public init(
        isActive: Bool,
        isPaused: Bool,
        isMuted: Bool,
        curriculumTitle: String?,
        topicTitle: String?,
        sessionMode: SessionMode,
        currentSegment: Int,
        totalSegments: Int,
        elapsedSeconds: TimeInterval,
        timestamp: Date = Date()
    ) {
        self.isActive = isActive
        self.isPaused = isPaused
        self.isMuted = isMuted
        self.curriculumTitle = curriculumTitle
        self.topicTitle = topicTitle
        self.sessionMode = sessionMode
        self.currentSegment = currentSegment
        self.totalSegments = totalSegments
        self.elapsedSeconds = elapsedSeconds
        self.timestamp = timestamp
    }

    /// Idle state constant
    public static let idle = WatchSessionState(
        isActive: false,
        isPaused: false,
        isMuted: false,
        curriculumTitle: nil,
        topicTitle: nil,
        sessionMode: .freeform,
        currentSegment: 0,
        totalSegments: 0,
        elapsedSeconds: 0,
        timestamp: Date()
    )

    #if DEBUG
    /// Mock state for simulator UI testing
    public static let debugMock = WatchSessionState(
        isActive: true,
        isPaused: false,
        isMuted: false,
        curriculumTitle: "Calculus 101",
        topicTitle: "Introduction to Derivatives",
        sessionMode: .curriculum,
        currentSegment: 7,
        totalSegments: 20,
        elapsedSeconds: 420,
        timestamp: Date()
    )
    #endif
}
