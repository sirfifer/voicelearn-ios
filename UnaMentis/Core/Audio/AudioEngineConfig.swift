// UnaMentis - Audio Engine Configuration
// Configuration for iOS audio capture and playback
//
// Part of Core Components (TDD Section 3.1)

import AVFoundation

/// Configuration for the AudioEngine
///
/// All parameters exposed in settings UI per TDD requirements
public struct AudioEngineConfig: Codable, Sendable {
    
    // MARK: - Core Audio Settings
    
    /// Sample rate in Hz (16000, 24000, 48000)
    public var sampleRate: Double
    
    /// Number of audio channels (1 = mono recommended for voice)
    public var channels: UInt32
    
    /// Bit depth for audio samples
    public var bitDepth: BitDepth
    
    // MARK: - Voice Processing
    
    /// Enable hardware voice processing (AEC, AGC, NS)
    public var enableVoiceProcessing: Bool
    
    /// Enable echo cancellation
    public var enableEchoCancellation: Bool
    
    /// Enable noise suppression
    public var enableNoiseSuppression: Bool
    
    /// Enable automatic gain control
    public var enableAutomaticGainControl: Bool
    
    // MARK: - VAD Settings
    
    /// VAD provider to use
    public var vadProvider: VADProvider
    
    /// VAD detection threshold (0.0 - 1.0)
    public var vadThreshold: Float
    
    /// Number of frames for VAD context
    public var vadContextWindow: Int
    
    /// Number of frames for VAD smoothing
    public var vadSmoothingWindow: Int
    
    // MARK: - Interruption Handling
    
    /// Enable barge-in (user can interrupt AI)
    public var enableBargeIn: Bool
    
    /// VAD confidence threshold to trigger interruption
    public var bargeInThreshold: Float
    
    /// Clear TTS buffer on interruption
    public var ttsClearOnInterrupt: Bool
    
    // MARK: - Performance Tuning
    
    /// Audio buffer size in frames
    public var bufferSize: UInt32
    
    /// Enable adaptive quality based on thermal state
    public var enableAdaptiveQuality: Bool
    
    /// Thermal state at which to throttle
    public var thermalThrottleThreshold: ThermalThreshold
    
    // MARK: - Monitoring
    
    /// Enable audio level monitoring for UI
    public var enableAudioLevelMonitoring: Bool
    
    /// Interval for level updates in seconds
    public var levelUpdateInterval: TimeInterval
    
    // MARK: - Presets
    
    /// Default balanced configuration
    public static let `default` = AudioEngineConfig(
        sampleRate: 48000,
        channels: 1,
        bitDepth: .float32,
        enableVoiceProcessing: true,
        enableEchoCancellation: true,
        enableNoiseSuppression: true,
        enableAutomaticGainControl: true,
        vadProvider: .silero,
        vadThreshold: 0.5,
        vadContextWindow: 3,
        vadSmoothingWindow: 5,
        enableBargeIn: true,
        bargeInThreshold: 0.7,
        ttsClearOnInterrupt: true,
        bufferSize: 1024,
        enableAdaptiveQuality: true,
        thermalThrottleThreshold: .serious,
        enableAudioLevelMonitoring: true,
        levelUpdateInterval: 0.1
    )
    
    /// Low latency preset
    public static let lowLatency = AudioEngineConfig(
        sampleRate: 24000,
        channels: 1,
        bitDepth: .float32,
        enableVoiceProcessing: true,
        enableEchoCancellation: true,
        enableNoiseSuppression: true,
        enableAutomaticGainControl: true,
        vadProvider: .silero,
        vadThreshold: 0.4,
        vadContextWindow: 2,
        vadSmoothingWindow: 3,
        enableBargeIn: true,
        bargeInThreshold: 0.6,
        ttsClearOnInterrupt: true,
        bufferSize: 512,
        enableAdaptiveQuality: true,
        thermalThrottleThreshold: .serious,
        enableAudioLevelMonitoring: true,
        levelUpdateInterval: 0.05
    )
    
    /// Privacy-first preset (on-device only)
    public static let privacyFirst = AudioEngineConfig(
        sampleRate: 16000,
        channels: 1,
        bitDepth: .int16,
        enableVoiceProcessing: true,
        enableEchoCancellation: true,
        enableNoiseSuppression: true,
        enableAutomaticGainControl: true,
        vadProvider: .silero,
        vadThreshold: 0.5,
        vadContextWindow: 3,
        vadSmoothingWindow: 5,
        enableBargeIn: true,
        bargeInThreshold: 0.7,
        ttsClearOnInterrupt: true,
        bufferSize: 1024,
        enableAdaptiveQuality: false,
        thermalThrottleThreshold: .critical,
        enableAudioLevelMonitoring: true,
        levelUpdateInterval: 0.1
    )
    
    // MARK: - Initialization
    
    public init(
        sampleRate: Double = 48000,
        channels: UInt32 = 1,
        bitDepth: BitDepth = .float32,
        enableVoiceProcessing: Bool = true,
        enableEchoCancellation: Bool = true,
        enableNoiseSuppression: Bool = true,
        enableAutomaticGainControl: Bool = true,
        vadProvider: VADProvider = .silero,
        vadThreshold: Float = 0.5,
        vadContextWindow: Int = 3,
        vadSmoothingWindow: Int = 5,
        enableBargeIn: Bool = true,
        bargeInThreshold: Float = 0.7,
        ttsClearOnInterrupt: Bool = true,
        bufferSize: UInt32 = 1024,
        enableAdaptiveQuality: Bool = true,
        thermalThrottleThreshold: ThermalThreshold = .serious,
        enableAudioLevelMonitoring: Bool = true,
        levelUpdateInterval: TimeInterval = 0.1
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitDepth = bitDepth
        self.enableVoiceProcessing = enableVoiceProcessing
        self.enableEchoCancellation = enableEchoCancellation
        self.enableNoiseSuppression = enableNoiseSuppression
        self.enableAutomaticGainControl = enableAutomaticGainControl
        self.vadProvider = vadProvider
        self.vadThreshold = vadThreshold
        self.vadContextWindow = vadContextWindow
        self.vadSmoothingWindow = vadSmoothingWindow
        self.enableBargeIn = enableBargeIn
        self.bargeInThreshold = bargeInThreshold
        self.ttsClearOnInterrupt = ttsClearOnInterrupt
        self.bufferSize = bufferSize
        self.enableAdaptiveQuality = enableAdaptiveQuality
        self.thermalThrottleThreshold = thermalThrottleThreshold
        self.enableAudioLevelMonitoring = enableAudioLevelMonitoring
        self.levelUpdateInterval = levelUpdateInterval
    }
}

// MARK: - Supporting Types

/// Audio bit depth options
public enum BitDepth: String, Codable, Sendable, CaseIterable {
    case int16 = "16-bit Integer"
    case int32 = "32-bit Integer"
    case float32 = "32-bit Float"
    
    /// Convert to AVAudioCommonFormat
    public var avFormat: AVAudioCommonFormat {
        switch self {
        case .int16: return .pcmFormatInt16
        case .int32: return .pcmFormatInt32
        case .float32: return .pcmFormatFloat32
        }
    }
}

/// Thermal state threshold for quality adaptation
public enum ThermalThreshold: String, Codable, Sendable, CaseIterable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"
    
    /// Convert from ProcessInfo.ThermalState
    public init(from state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .serious
        }
    }
    
    /// Compare with ProcessInfo.ThermalState
    public func isExceededBy(_ state: ProcessInfo.ThermalState) -> Bool {
        let selfValue: Int
        let stateValue: Int
        
        switch self {
        case .nominal: selfValue = 0
        case .fair: selfValue = 1
        case .serious: selfValue = 2
        case .critical: selfValue = 3
        }
        
        switch state {
        case .nominal: stateValue = 0
        case .fair: stateValue = 1
        case .serious: stateValue = 2
        case .critical: stateValue = 3
        @unknown default: stateValue = 2
        }
        
        return stateValue >= selfValue
    }
}

// MARK: - AudioEngine Errors

/// Errors that can occur in AudioEngine
public enum AudioEngineError: Error, Sendable {
    case audioSessionConfigurationFailed(String)
    case engineStartFailed(String)
    case voiceProcessingNotAvailable
    case invalidConfiguration(String)
    case notRunning
    case alreadyRunning
    case playbackFailed(String)
    case bufferConversionFailed
}

extension AudioEngineError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .audioSessionConfigurationFailed(let message):
            return "Audio session configuration failed: \(message)"
        case .engineStartFailed(let message):
            return "Audio engine start failed: \(message)"
        case .voiceProcessingNotAvailable:
            return "Voice processing is not available on this device"
        case .invalidConfiguration(let message):
            return "Invalid audio configuration: \(message)"
        case .notRunning:
            return "Audio engine is not running"
        case .alreadyRunning:
            return "Audio engine is already running"
        case .playbackFailed(let message):
            return "Audio playback failed: \(message)"
        case .bufferConversionFailed:
            return "Failed to convert audio data to playable buffer"
        }
    }
}
