//
//  KBOnDeviceTTS.swift
//  UnaMentis
//
//  On-device text-to-speech using AVSpeechSynthesizer for Knowledge Bowl oral rounds
//
//  TODO: Consider full TTSService protocol conformance for provider flexibility

import AVFoundation
import OSLog

// MARK: - On-Device TTS Service

/// Provides offline text-to-speech capability using AVSpeechSynthesizer
actor KBOnDeviceTTS {
    // MARK: - State

    private(set) var isSpeaking = false
    private(set) var isPaused = false
    private(set) var progress: Float = 0

    // MARK: - Private State

    // MainActor-only properties (AVSpeechSynthesizer requires main thread)
    nonisolated(unsafe) private var synthesizer: AVSpeechSynthesizer?
    nonisolated(unsafe) private var delegateHandler: TTSDelegateHandler?
    nonisolated(unsafe) private var currentUtterance: AVSpeechUtterance?

    private var completionContinuation: CheckedContinuation<Void, Never>?
    private let logger = Logger(subsystem: "com.unamentis", category: "KBOnDeviceTTS")

    // MARK: - Configuration

    /// Voice configuration for questions
    struct VoiceConfig: Sendable {
        var language: String = "en-US"
        var rate: Float = AVSpeechUtteranceDefaultSpeechRate
        var pitchMultiplier: Float = 1.0
        var volume: Float = 1.0
        var preUtteranceDelay: TimeInterval = 0
        var postUtteranceDelay: TimeInterval = 0

        /// Standard reading pace for questions
        static let questionPace = VoiceConfig(
            rate: AVSpeechUtteranceDefaultSpeechRate * 0.9,
            pitchMultiplier: 1.0
        )

        /// Slower pace for complex questions
        static let slowPace = VoiceConfig(
            rate: AVSpeechUtteranceDefaultSpeechRate * 0.75,
            pitchMultiplier: 1.0
        )

        /// Faster pace for experienced users
        static let fastPace = VoiceConfig(
            rate: AVSpeechUtteranceDefaultSpeechRate * 1.1,
            pitchMultiplier: 1.0
        )
    }

    // MARK: - Initialization

    init() {
        logger.info("KBOnDeviceTTS initialized")
    }

    // MARK: - Public API

    /// Speak text with default configuration
    func speak(_ text: String) async {
        await speak(text, config: .questionPace)
    }

    /// Speak text with custom configuration
    func speak(_ text: String, config: VoiceConfig) async {
        // Ensure synthesizer is created on main thread
        if synthesizer == nil {
            await MainActor.run {
                let synth = AVSpeechSynthesizer()
                self.delegateHandler = TTSDelegateHandler(actor: self)
                synth.delegate = self.delegateHandler
                self.synthesizer = synth
                self.configureAudioSession()
            }
        }

        guard synthesizer != nil else {
            logger.error("Failed to create synthesizer")
            return
        }

        // Stop any current speech
        if isSpeaking {
            await MainActor.run {
                self.synthesizer?.stopSpeaking(at: .immediate)
            }
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task {
                await self.startSpeech(text, config: config, continuation: continuation)
            }
        }
    }

    private func startSpeech(_ text: String, config: VoiceConfig, continuation: CheckedContinuation<Void, Never>) async {
        completionContinuation = continuation
        progress = 0
        isSpeaking = true
        isPaused = false

        logger.debug("Speaking: \(text.prefix(50))...")

        // Create and speak utterance on main thread
        await MainActor.run {
            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = config.rate
            utterance.pitchMultiplier = config.pitchMultiplier
            utterance.volume = config.volume
            utterance.preUtteranceDelay = config.preUtteranceDelay
            utterance.postUtteranceDelay = config.postUtteranceDelay

            // Select voice
            if let voice = AVSpeechSynthesisVoice(language: config.language) {
                utterance.voice = voice
            }

            self.currentUtterance = utterance
            self.synthesizer?.speak(utterance)
        }
    }

    /// Speak a Knowledge Bowl question
    func speakQuestion(_ question: KBQuestion, config: VoiceConfig = .questionPace) async {
        await speak(question.text, config: config)
    }

    /// Pause speech
    func pause() {
        guard isSpeaking, !isPaused else { return }
        Task { @MainActor in
            self.synthesizer?.pauseSpeaking(at: .word)
        }
        isPaused = true
        logger.debug("Speech paused")
    }

    /// Resume speech
    func resume() {
        guard isPaused else { return }
        Task { @MainActor in
            self.synthesizer?.continueSpeaking()
        }
        isPaused = false
        logger.debug("Speech resumed")
    }

    /// Stop speech immediately
    func stop() {
        Task { @MainActor in
            self.synthesizer?.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        isPaused = false
        progress = 0
        currentUtterance = nil

        // CRITICAL: Resume continuation to prevent leak
        if let continuation = completionContinuation {
            continuation.resume()
            completionContinuation = nil
        }

        logger.debug("Speech stopped")
    }

    // MARK: - Audio Session

    @MainActor
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Delegate Callbacks

    func speechDidStart() {
        isSpeaking = true
        logger.debug("Speech started")
    }

    func speechDidFinish() {
        isSpeaking = false
        isPaused = false
        progress = 1.0
        logger.debug("Speech finished")

        // Resume continuation on completion
        if let continuation = completionContinuation {
            continuation.resume()
            completionContinuation = nil
        }
        currentUtterance = nil
    }

    func speechDidCancel() {
        isSpeaking = false
        isPaused = false
        progress = 0
        logger.debug("Speech cancelled")

        // CRITICAL: Resume continuation to prevent leak
        if let continuation = completionContinuation {
            continuation.resume()
            completionContinuation = nil
        }
        currentUtterance = nil
    }

    func speechProgressUpdated(_ newProgress: Float) {
        progress = newProgress
    }

    func speechDidPause() {
        isPaused = true
        logger.debug("Speech paused (delegate)")
    }

    func speechDidContinue() {
        isPaused = false
        logger.debug("Speech continued (delegate)")
    }

    // MARK: - Available Voices

    /// Get available voices for a language
    static func availableVoices(for language: String = "en-US") -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(language.prefix(2)) }
    }

    /// Get the best quality voice for a language
    static func bestVoice(for language: String = "en-US") -> AVSpeechSynthesisVoice? {
        let voices = availableVoices(for: language)

        // Prefer enhanced or premium voices
        if let enhanced = voices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }

        // Fall back to default
        return AVSpeechSynthesisVoice(language: language)
    }
}

// MARK: - Delegate Handler

/// Helper class to bridge AVSpeechSynthesizerDelegate to actor
@MainActor
private class TTSDelegateHandler: NSObject, AVSpeechSynthesizerDelegate {
    let actor: KBOnDeviceTTS

    init(actor: KBOnDeviceTTS) {
        self.actor = actor
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        Task {
            await actor.speechDidStart()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task {
            await actor.speechDidFinish()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task {
            await actor.speechDidCancel()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        // Calculate progress synchronously to avoid data races
        let totalLength = Float(utterance.speechString.count)
        guard totalLength > 0 else { return }

        let currentPosition = Float(characterRange.location + characterRange.length)
        let newProgress = currentPosition / totalLength

        Task {
            await actor.speechProgressUpdated(newProgress)
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didPause utterance: AVSpeechUtterance
    ) {
        Task {
            await actor.speechDidPause()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didContinue utterance: AVSpeechUtterance
    ) {
        Task {
            await actor.speechDidContinue()
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension KBOnDeviceTTS {
    /// Create a TTS instance for previews
    static func preview() -> KBOnDeviceTTS {
        KBOnDeviceTTS()
    }
}
#endif
