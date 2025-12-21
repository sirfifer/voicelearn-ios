// UnaMentis - VAD Service Protocol
// Protocol defining Voice Activity Detection interface
//
// Part of the Provider Abstraction Layer (TDD Section 6)

import AVFoundation

// MARK: - VAD Result

/// Result from Voice Activity Detection processing
public struct VADResult: Sendable {
    /// Whether speech was detected in the audio frame
    public let isSpeech: Bool
    
    /// Confidence level of the detection (0.0 - 1.0)
    public let confidence: Float
    
    /// Timestamp of the detection
    public let timestamp: TimeInterval
    
    /// Duration of the analyzed audio segment in seconds
    public let segmentDuration: TimeInterval
    
    public init(
        isSpeech: Bool,
        confidence: Float,
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        segmentDuration: TimeInterval = 0.0
    ) {
        self.isSpeech = isSpeech
        self.confidence = min(max(confidence, 0.0), 1.0)
        self.timestamp = timestamp
        self.segmentDuration = segmentDuration
    }
}

// MARK: - VAD Configuration

/// Configuration for VAD services
public struct VADConfiguration: Sendable {
    /// Threshold for speech detection (0.0 - 1.0)
    public var threshold: Float
    
    /// Number of frames to consider for context
    public var contextWindow: Int
    
    /// Number of frames for smoothing detections
    public var smoothingWindow: Int
    
    /// Minimum speech duration to trigger detection (seconds)
    public var minSpeechDuration: TimeInterval
    
    /// Minimum silence duration to end speech (seconds)
    public var minSilenceDuration: TimeInterval
    
    public static let `default` = VADConfiguration(
        threshold: 0.5,
        contextWindow: 3,
        smoothingWindow: 5,
        minSpeechDuration: 0.1,
        minSilenceDuration: 0.5
    )
    
    public init(
        threshold: Float = 0.5,
        contextWindow: Int = 3,
        smoothingWindow: Int = 5,
        minSpeechDuration: TimeInterval = 0.1,
        minSilenceDuration: TimeInterval = 0.5
    ) {
        self.threshold = threshold
        self.contextWindow = contextWindow
        self.smoothingWindow = smoothingWindow
        self.minSpeechDuration = minSpeechDuration
        self.minSilenceDuration = minSilenceDuration
    }
}

// MARK: - VAD Service Protocol

/// Protocol for Voice Activity Detection services
///
/// Implementations include:
/// - SileroVADService: CoreML-based VAD using Silero model on Neural Engine
/// - TENVADService: TEN VAD implementation
/// - WebRTCVADService: WebRTC VAD fallback
public protocol VADService: Actor {
    /// Current configuration
    var configuration: VADConfiguration { get }
    
    /// Whether the service is currently active
    var isActive: Bool { get }
    
    /// Configure the VAD service
    /// - Parameters:
    ///   - threshold: Detection threshold (0.0 - 1.0)
    ///   - contextWindow: Number of context frames
    func configure(threshold: Float, contextWindow: Int) async
    
    /// Configure with full configuration object
    func configure(_ configuration: VADConfiguration) async
    
    /// Process an audio buffer and return VAD result
    /// - Parameter buffer: Audio buffer to analyze
    /// - Returns: VAD detection result
    func processBuffer(_ buffer: AVAudioPCMBuffer) async -> VADResult
    
    /// Reset internal state (useful between sessions)
    func reset() async
    
    /// Prepare the VAD service (load models, etc.)
    func prepare() async throws
    
    /// Release resources
    func shutdown() async
}

// MARK: - VAD Provider Enum

/// Available VAD provider implementations
public enum VADProvider: String, Codable, Sendable, CaseIterable {
    case silero = "Silero VAD (Neural Engine)"
    case ten = "TEN VAD"
    case webrtc = "WebRTC VAD"
    
    /// Display name for UI
    public var displayName: String {
        rawValue
    }
    
    /// Short identifier
    public var identifier: String {
        switch self {
        case .silero: return "silero"
        case .ten: return "ten"
        case .webrtc: return "webrtc"
        }
    }
}

// MARK: - VAD Errors

/// Errors that can occur during VAD processing
public enum VADError: Error, Sendable {
    case modelLoadFailed(String)
    case processingFailed(String)
    case invalidAudioFormat
    case notPrepared
    case configurationError(String)
}

extension VADError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let message):
            return "Failed to load VAD model: \(message)"
        case .processingFailed(let message):
            return "VAD processing failed: \(message)"
        case .invalidAudioFormat:
            return "Invalid audio format for VAD processing"
        case .notPrepared:
            return "VAD service not prepared. Call prepare() first."
        case .configurationError(let message):
            return "VAD configuration error: \(message)"
        }
    }
}
