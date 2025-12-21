// UnaMentis - Apple TTS Service
// On-device Text-to-Speech using AVSpeechSynthesizer
//
// This service provides free, on-device TTS with no network required.
// Uses Apple's AVSpeechSynthesizer for voice synthesis.

import Foundation
@preconcurrency import AVFoundation
import Logging

/// On-device TTS service using Apple's AVSpeechSynthesizer
///
/// Benefits:
/// - Free (no API costs)
/// - Works offline
/// - Low latency
/// - Privacy-preserving
public actor AppleTTSService: TTSService {

    // MARK: - Properties

    private let logger = Logger(label: "com.unamentis.tts.apple")
    private let synthesizer: AVSpeechSynthesizer
    private let delegate: SynthesizerDelegate

    /// Performance metrics
    public private(set) var metrics = TTSMetrics(
        medianTTFB: 0.05,  // Very fast on-device
        p99TTFB: 0.1
    )

    /// Cost per character ($0 - free on-device)
    public var costPerCharacter: Decimal { Decimal(0) }

    /// Current voice configuration
    public private(set) var voiceConfig: TTSVoiceConfig

    // MARK: - Initialization

    public init(voiceConfig: TTSVoiceConfig = .default) {
        self.voiceConfig = voiceConfig
        self.synthesizer = AVSpeechSynthesizer()
        self.delegate = SynthesizerDelegate()
        self.synthesizer.delegate = delegate
        logger.info("AppleTTSService initialized")
    }

    // MARK: - TTSService Protocol

    public func configure(_ config: TTSVoiceConfig) async {
        self.voiceConfig = config
        logger.debug("Voice configured: \(config.voiceId)")
    }

    public func synthesize(text: String) async throws -> AsyncStream<TTSAudioChunk> {
        logger.info("Synthesizing text: \(text.prefix(50))...")

        let startTime = Date()

        // Capture voice config values before entering MainActor context
        let voiceId = voiceConfig.voiceId
        let rate = voiceConfig.rate
        let pitch = voiceConfig.pitch
        let volume = voiceConfig.volume
        let localSynthesizer = synthesizer
        let localDelegate = delegate

        return AsyncStream { continuation in
            Task { @MainActor in
                // Create utterance
                let utterance = AVSpeechUtterance(string: text)

                // Configure voice
                if voiceId != "default" {
                    utterance.voice = AVSpeechSynthesisVoice(identifier: voiceId)
                } else {
                    // Use best available English voice
                    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                }

                // Apply settings
                utterance.rate = AVSpeechUtteranceDefaultSpeechRate * rate
                utterance.pitchMultiplier = 1.0 + pitch
                utterance.volume = volume

                // Set up completion handler
                localDelegate.onCompletion = {
                    let ttfb = Date().timeIntervalSince(startTime)

                    // For Apple TTS, we emit a single "chunk" when synthesis completes
                    // The actual audio is played directly by AVSpeechSynthesizer
                    let chunk = TTSAudioChunk(
                        audioData: Data(),  // Apple TTS plays directly, no raw data access
                        format: .pcmFloat32(sampleRate: 22050, channels: 1),
                        sequenceNumber: 0,
                        isFirst: true,
                        isLast: true,
                        timeToFirstByte: ttfb
                    )
                    continuation.yield(chunk)
                    continuation.finish()
                }

                localDelegate.onError = { error in
                    continuation.finish()
                }

                // Start speaking
                localSynthesizer.speak(utterance)
            }
        }
    }

    public func flush() async throws {
        await MainActor.run {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    /// Stop current speech
    public func stop() async {
        await MainActor.run {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    /// Check if currently speaking
    public var isSpeaking: Bool {
        get async {
            await MainActor.run {
                synthesizer.isSpeaking
            }
        }
    }
}

// MARK: - Synthesizer Delegate

private class SynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    var onCompletion: (() -> Void)?
    var onError: ((Error) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onCompletion?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onCompletion?()
    }
}

// MARK: - Available Voices

extension AppleTTSService {
    /// Get all available voices
    public static var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
    }

    /// Get available voices for a specific language
    public static func voices(forLanguage language: String) -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language.starts(with: language) }
    }

    /// Get enhanced (higher quality) voices
    public static var enhancedVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.quality == .enhanced }
    }
}
