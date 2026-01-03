// UnaMentis - Chatterbox TTS Service
// Text-to-Speech service for Chatterbox (Resemble AI)
//
// Part of Services/TTS

import Foundation
import Logging
import AVFoundation

/// Chatterbox TTS service with full feature support
///
/// Features:
/// - Emotion control via exaggeration parameter
/// - CFG weight for generation fidelity
/// - Paralinguistic tags ([laugh], [cough], etc.)
/// - Zero-shot voice cloning from reference audio
/// - Multilingual support (23 languages)
/// - Streaming and non-streaming modes
/// - Automatic fallback to Piper/VibeVoice
///
/// Endpoints:
/// - Streaming: `/tts` returns audio chunks progressively
/// - Non-streaming: `/v1/audio/speech` (OpenAI-compatible)
public actor ChatterboxTTSService: TTSService {

    // MARK: - Properties

    private let logger = Logger(label: "com.unamentis.tts.chatterbox")
    private let baseURL: URL
    private var chatterboxConfig: ChatterboxConfig
    private let providerName = "Chatterbox"

    /// Performance metrics
    public private(set) var metrics: TTSMetrics = TTSMetrics(
        medianTTFB: 0.472,  // Chatterbox streaming TTFB
        p99TTFB: 0.8
    )

    /// Cost per character (free for self-hosted)
    public var costPerCharacter: Decimal { 0 }

    /// Current voice configuration
    public private(set) var voiceConfig: TTSVoiceConfig

    /// Fallback service for when Chatterbox is unavailable
    private var fallbackService: SelfHostedTTSService?

    /// Whether fallback is enabled
    private var enableFallback: Bool = true

    /// Latency tracking
    private var latencyValues: [TimeInterval] = []

    // MARK: - Initialization

    /// Initialize with explicit configuration
    /// - Parameters:
    ///   - baseURL: Base URL of the Chatterbox server (e.g., http://localhost:8004)
    ///   - config: Chatterbox-specific configuration
    ///   - voiceConfig: Standard TTS voice configuration
    ///   - fallbackService: Optional fallback TTS service
    public init(
        baseURL: URL,
        config: ChatterboxConfig = .default,
        voiceConfig: TTSVoiceConfig = .default,
        fallbackService: SelfHostedTTSService? = nil
    ) {
        self.baseURL = baseURL
        self.chatterboxConfig = config
        self.voiceConfig = voiceConfig
        self.fallbackService = fallbackService
        logger.info("ChatterboxTTSService initialized: \(baseURL.absoluteString)")
    }

    // MARK: - Factory Methods

    /// Create a Chatterbox service with Piper fallback
    /// - Parameters:
    ///   - host: Server hostname or IP (default: localhost)
    ///   - port: Chatterbox port (default: 8004)
    ///   - config: Chatterbox configuration
    /// - Returns: Configured Chatterbox TTS service
    public static func chatterbox(
        host: String = "localhost",
        port: Int = 8004,
        config: ChatterboxConfig = .default
    ) -> ChatterboxTTSService {
        let url = URL(string: "http://\(host):\(port)")!

        // Add Piper as fallback
        let piperURL = URL(string: "http://\(host):11402")!
        let fallback = SelfHostedTTSService(
            baseURL: piperURL,
            voiceId: "nova",
            sampleRate: 22050,
            providerName: "Piper"
        )

        return ChatterboxTTSService(
            baseURL: url,
            config: config,
            fallbackService: fallback
        )
    }

    /// Create a Chatterbox service with VibeVoice fallback
    /// - Parameters:
    ///   - host: Server hostname or IP
    ///   - port: Chatterbox port (default: 8004)
    ///   - config: Chatterbox configuration
    /// - Returns: Configured Chatterbox TTS service with VibeVoice fallback
    public static func chatterboxWithVibeVoiceFallback(
        host: String = "localhost",
        port: Int = 8004,
        config: ChatterboxConfig = .default
    ) -> ChatterboxTTSService {
        let url = URL(string: "http://\(host):\(port)")!

        // Add VibeVoice as fallback
        let vibeVoiceURL = URL(string: "http://\(host):8880")!
        let fallback = SelfHostedTTSService(
            baseURL: vibeVoiceURL,
            voiceId: "nova",
            sampleRate: 24000,
            providerName: "VibeVoice"
        )

        return ChatterboxTTSService(
            baseURL: url,
            config: config,
            fallbackService: fallback
        )
    }

    // MARK: - TTSService Protocol

    /// Configure voice settings
    public func configure(_ config: TTSVoiceConfig) async {
        self.voiceConfig = config
        logger.debug("Voice configured: \(config.voiceId)")
    }

    /// Configure Chatterbox-specific settings
    public func configureChatterbox(_ config: ChatterboxConfig) async {
        self.chatterboxConfig = config
        logger.debug("Chatterbox configured: exaggeration=\(config.exaggeration), cfgWeight=\(config.cfgWeight)")
    }

    /// Get current Chatterbox configuration
    public func getChatterboxConfig() -> ChatterboxConfig {
        return chatterboxConfig
    }

    /// Synthesize text to audio stream
    public func synthesize(text: String) async throws -> AsyncStream<TTSAudioChunk> {
        logger.info("[Chatterbox] synthesize called - text length: \(text.count)")
        logger.debug("[Chatterbox] config: exaggeration=\(chatterboxConfig.exaggeration), cfg=\(chatterboxConfig.cfgWeight), streaming=\(chatterboxConfig.useStreaming)")

        do {
            if chatterboxConfig.useStreaming {
                return try await synthesizeStreaming(text: text)
            } else {
                return try await synthesizeNonStreaming(text: text)
            }
        } catch {
            // Try fallback if enabled
            if enableFallback, let fallback = fallbackService {
                logger.warning("[Chatterbox] Primary failed, trying fallback: \(error.localizedDescription)")
                return try await fallback.synthesize(text: text)
            }
            throw error
        }
    }

    /// Flush any pending audio and stop synthesis
    public func flush() async throws {
        // For non-streaming TTS, nothing to flush
        logger.debug("[Chatterbox] flush called (no-op for current implementation)")
    }

    // MARK: - Streaming Synthesis

    /// Synthesize using the streaming endpoint
    private func synthesizeStreaming(text: String) async throws -> AsyncStream<TTSAudioChunk> {
        let startTime = Date()
        let processedText = processParalinguisticTags(text)

        // Use /tts streaming endpoint
        let endpoint = baseURL.appendingPathComponent("tts")
        logger.info("[Chatterbox] Streaming request to: \(endpoint.absoluteString)")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        // Build request body with Chatterbox parameters
        var body: [String: Any] = [
            "text": processedText,
            "exaggeration": chatterboxConfig.exaggeration,
            "cfg_weight": chatterboxConfig.cfgWeight,
            "speed": chatterboxConfig.speed
        ]

        // Add language for multilingual model
        if chatterboxConfig.useMultilingual {
            body["language"] = chatterboxConfig.language
            body["model"] = "multilingual"
        } else {
            body["model"] = "turbo"
        }

        // Add seed for reproducibility
        if let seed = chatterboxConfig.seed {
            body["seed"] = seed
        }

        // Add reference audio for voice cloning (if available)
        if let refPath = chatterboxConfig.referenceAudioPath,
           let refAudio = try? loadReferenceAudio(path: refPath) {
            body["reference_audio"] = refAudio
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return AsyncStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        self.logger.error("[Chatterbox] Invalid response type")
                        continuation.finish()
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        self.logger.error("[Chatterbox] HTTP \(httpResponse.statusCode)")
                        throw TTSError.connectionFailed("HTTP \(httpResponse.statusCode)")
                    }

                    var buffer = Data()
                    let chunkSize = 4800  // ~100ms at 24kHz 16-bit mono
                    var sequenceNumber = 0
                    var isFirst = true
                    var ttfb: TimeInterval?

                    for try await byte in bytes {
                        buffer.append(byte)

                        // Emit chunks as they accumulate
                        while buffer.count >= chunkSize {
                            if isFirst {
                                ttfb = Date().timeIntervalSince(startTime)
                                self.latencyValues.append(ttfb!)
                                self.updateMetrics()
                                self.logger.info("[Chatterbox] TTFB: \(String(format: "%.3f", ttfb!))s")
                            }

                            let chunkData = Data(buffer.prefix(chunkSize))
                            let chunk = TTSAudioChunk(
                                audioData: chunkData,
                                format: .pcmInt16(sampleRate: 24000, channels: 1),
                                sequenceNumber: sequenceNumber,
                                isFirst: isFirst,
                                isLast: false,
                                timeToFirstByte: isFirst ? ttfb : nil
                            )

                            continuation.yield(chunk)
                            buffer.removeFirst(chunkSize)
                            sequenceNumber += 1
                            isFirst = false
                        }
                    }

                    // Emit final chunk with remaining data
                    if !buffer.isEmpty {
                        let chunk = TTSAudioChunk(
                            audioData: buffer,
                            format: .pcmInt16(sampleRate: 24000, channels: 1),
                            sequenceNumber: sequenceNumber,
                            isFirst: isFirst,
                            isLast: true,
                            timeToFirstByte: isFirst ? Date().timeIntervalSince(startTime) : nil
                        )
                        continuation.yield(chunk)
                    }

                    let totalTime = Date().timeIntervalSince(startTime)
                    self.logger.info("[Chatterbox] Streaming complete: \(text.count) chars in \(String(format: "%.3f", totalTime))s")

                } catch {
                    self.logger.error("[Chatterbox] Streaming error: \(error.localizedDescription)")
                }

                continuation.finish()
            }
        }
    }

    // MARK: - Non-Streaming Synthesis

    /// Synthesize using the OpenAI-compatible endpoint
    private func synthesizeNonStreaming(text: String) async throws -> AsyncStream<TTSAudioChunk> {
        let startTime = Date()
        let processedText = processParalinguisticTags(text)

        // Use OpenAI-compatible /v1/audio/speech endpoint
        let endpoint = baseURL.appendingPathComponent("v1/audio/speech")
        logger.info("[Chatterbox] Non-streaming request to: \(endpoint.absoluteString)")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        // Build request body with Chatterbox-specific parameters
        var body: [String: Any] = [
            "model": chatterboxConfig.useMultilingual ? "chatterbox-multilingual" : "chatterbox-turbo",
            "input": processedText,
            "voice": voiceConfig.voiceId.isEmpty ? "default" : voiceConfig.voiceId,
            "response_format": "wav",
            "exaggeration": chatterboxConfig.exaggeration,
            "cfg_weight": chatterboxConfig.cfgWeight,
            "speed": chatterboxConfig.speed
        ]

        // Add language for multilingual model
        if chatterboxConfig.useMultilingual {
            body["language"] = chatterboxConfig.language
        }

        // Add seed for reproducibility
        if let seed = chatterboxConfig.seed {
            body["seed"] = seed
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        logger.debug("[Chatterbox] Request body: model=\(body["model"] ?? ""), exaggeration=\(chatterboxConfig.exaggeration)")

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        let ttfb = Date().timeIntervalSince(startTime)
        latencyValues.append(ttfb)
        updateMetrics()

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("[Chatterbox] Invalid response type")
            throw TTSError.connectionFailed("Invalid response type")
        }

        logger.info("[Chatterbox] HTTP \(httpResponse.statusCode), \(data.count) bytes, TTFB: \(String(format: "%.3f", ttfb))s")

        guard httpResponse.statusCode == 200 else {
            if let errorBody = String(data: data, encoding: .utf8) {
                logger.error("[Chatterbox] Error response: \(errorBody.prefix(200))")
            }
            throw TTSError.connectionFailed("HTTP \(httpResponse.statusCode)")
        }

        // Validate audio data
        guard data.count > 44 else {  // WAV header is 44 bytes
            logger.error("[Chatterbox] Audio data too small: \(data.count) bytes")
            throw TTSError.connectionFailed("Audio data too small")
        }

        return AsyncStream { continuation in
            // Create single chunk with complete audio
            let chunk = TTSAudioChunk(
                audioData: data,
                format: .pcmInt16(sampleRate: 24000, channels: 1),
                sequenceNumber: 0,
                isFirst: true,
                isLast: true,
                timeToFirstByte: ttfb
            )

            continuation.yield(chunk)
            continuation.finish()

            self.logger.info("[Chatterbox] Synthesis complete: \(text.count) chars -> \(data.count) bytes")
        }
    }

    // MARK: - Text Processing

    /// Process paralinguistic tags in text
    /// - Parameter text: Input text potentially containing tags
    /// - Returns: Processed text (tags left in or stripped based on config)
    private func processParalinguisticTags(_ text: String) -> String {
        if chatterboxConfig.enableParalinguisticTags {
            // Tags are left in for Chatterbox to process
            return text
        } else {
            // Strip out paralinguistic tags
            let pattern = "\\[(?:laugh|cough|chuckle|sigh|gasp)\\]"
            return text.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
    }

    /// Load reference audio for voice cloning
    /// - Parameter path: Path to audio file
    /// - Returns: Base64-encoded audio data
    private func loadReferenceAudio(path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        return data.base64EncodedString()
    }

    // MARK: - Metrics

    /// Update performance metrics
    private func updateMetrics() {
        guard !latencyValues.isEmpty else { return }

        let sorted = latencyValues.sorted()
        let medianIndex = sorted.count / 2
        let p99Index = min(Int(Double(sorted.count) * 0.99), sorted.count - 1)

        metrics = TTSMetrics(
            medianTTFB: sorted[medianIndex],
            p99TTFB: sorted[p99Index]
        )
    }

    // MARK: - Health Check

    /// Check if the Chatterbox server is healthy
    public func checkHealth() async -> Bool {
        let healthURL = baseURL.appendingPathComponent("health")

        do {
            var request = URLRequest(url: healthURL)
            request.timeoutInterval = 5

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                logger.debug("[Chatterbox] Health check passed")
                return true
            }
        } catch {
            logger.warning("[Chatterbox] Health check failed: \(error.localizedDescription)")
        }

        return false
    }

    /// Check if multilingual model is available on server
    public func checkMultilingualSupport() async -> Bool {
        // Probe the server for model capabilities
        let modelsURL = baseURL.appendingPathComponent("v1/models")

        do {
            let (data, response) = try await URLSession.shared.data(from: modelsURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [String] {
                return models.contains { $0.contains("multilingual") }
            }
        } catch {
            logger.debug("[Chatterbox] Models check failed: \(error.localizedDescription)")
        }

        return false
    }

    // MARK: - Fallback Configuration

    /// Set fallback service
    public func setFallback(_ service: SelfHostedTTSService?) {
        self.fallbackService = service
        logger.info("[Chatterbox] Fallback service \(service != nil ? "configured" : "removed")")
    }

    /// Enable or disable automatic fallback
    public func setFallbackEnabled(_ enabled: Bool) {
        self.enableFallback = enabled
        logger.info("[Chatterbox] Fallback \(enabled ? "enabled" : "disabled")")
    }
}

// MARK: - Convenience Extensions

extension ChatterboxTTSService {

    /// Apply a preset configuration
    public func applyPreset(_ preset: ChatterboxPreset) async {
        switch preset {
        case .default:
            await configureChatterbox(.default)
        case .natural:
            await configureChatterbox(.natural)
        case .expressive:
            await configureChatterbox(.expressive)
        case .lowLatency:
            await configureChatterbox(.lowLatency)
        case .custom:
            // Custom preset doesn't change config, user's values are preserved
            break
        }
        logger.info("[Chatterbox] Applied preset: \(preset.displayName)")
    }

    /// Update a single configuration parameter
    public func updateExaggeration(_ value: Float) async {
        var config = chatterboxConfig
        config.exaggeration = value
        await configureChatterbox(config)
    }

    /// Update CFG weight
    public func updateCfgWeight(_ value: Float) async {
        var config = chatterboxConfig
        config.cfgWeight = value
        await configureChatterbox(config)
    }

    /// Update speed
    public func updateSpeed(_ value: Float) async {
        var config = chatterboxConfig
        config.speed = value
        await configureChatterbox(config)
    }

    /// Toggle paralinguistic tags
    public func setParalinguisticTagsEnabled(_ enabled: Bool) async {
        var config = chatterboxConfig
        config.enableParalinguisticTags = enabled
        await configureChatterbox(config)
    }

    /// Set language for multilingual model
    public func setLanguage(_ language: ChatterboxLanguage) async {
        var config = chatterboxConfig
        config.language = language.rawValue
        config.useMultilingual = true
        await configureChatterbox(config)
    }

    /// Toggle streaming mode
    public func setStreamingEnabled(_ enabled: Bool) async {
        var config = chatterboxConfig
        config.useStreaming = enabled
        await configureChatterbox(config)
    }
}
