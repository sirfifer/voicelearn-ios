// UnaMentis - Self-Hosted TTS Service
// OpenAI-compatible Text-to-Speech service for self-hosted servers
//
// Part of Services/TTS

import Foundation
import Logging
import AVFoundation

/// Self-hosted TTS service compatible with OpenAI TTS API format
///
/// Works with:
/// - Piper TTS server (port 11402, 22050 Hz)
/// - VibeVoice (Microsoft VibeVoice-Realtime-0.5B, port 8880, 24000 Hz)
/// - OpenedAI Speech
/// - Coqui TTS server
/// - UnaMentis gateway TTS endpoint
/// - Any OpenAI-compatible TTS API
public actor SelfHostedTTSService: TTSService {

    // MARK: - Properties

    private let logger = Logger(label: "com.unamentis.tts.selfhosted")
    private let baseURL: URL
    private let authToken: String?
    private var voiceId: String
    private let outputFormat: AudioFormat
    private let sampleRate: Double  // Sample rate for audio output (22050 for Piper, 24000 for VibeVoice)
    private let providerName: String  // For logging purposes

    /// Performance metrics
    public private(set) var metrics: TTSMetrics = TTSMetrics(
        medianTTFB: 0.1,
        p99TTFB: 0.3
    )

    /// Cost per character (free for self-hosted)
    public var costPerCharacter: Decimal { 0 }

    /// Current voice configuration
    public private(set) var voiceConfig: TTSVoiceConfig

    private var latencyValues: [TimeInterval] = []
    private var characterCounts: [Int] = []
    private var synthesisTimings: [TimeInterval] = []

    // MARK: - Initialization

    /// Initialize with explicit configuration
    /// - Parameters:
    ///   - baseURL: Base URL of the server (e.g., http://localhost:11402)
    ///   - voiceId: Voice identifier (depends on server)
    ///   - outputFormat: Desired audio format
    ///   - sampleRate: Audio sample rate (22050 for Piper, 24000 for VibeVoice)
    ///   - providerName: Name for logging (e.g., "Piper", "VibeVoice")
    ///   - authToken: Optional authentication token
    public init(
        baseURL: URL,
        voiceId: String = "nova",
        outputFormat: AudioFormat = .wav,
        sampleRate: Double = 22050,
        providerName: String = "SelfHosted",
        authToken: String? = nil
    ) {
        self.baseURL = baseURL
        self.voiceId = voiceId
        self.outputFormat = outputFormat
        self.sampleRate = sampleRate
        self.providerName = providerName
        self.authToken = authToken
        self.voiceConfig = TTSVoiceConfig(voiceId: voiceId)
        logger.info("\(providerName)TTSService initialized: \(baseURL.absoluteString), sampleRate=\(Int(sampleRate))Hz")
    }

    /// Initialize from ServerConfig
    public init?(server: ServerConfig, voiceId: String = "nova", sampleRate: Double = 22050, providerName: String = "SelfHosted") {
        guard let baseURL = server.baseURL else {
            return nil
        }
        self.baseURL = baseURL
        self.voiceId = voiceId
        self.outputFormat = .wav
        self.sampleRate = sampleRate
        self.providerName = providerName
        self.authToken = nil
        self.voiceConfig = TTSVoiceConfig(voiceId: voiceId)
        logger.info("\(providerName)TTSService initialized from server config: \(server.name)")
    }

    /// Initialize with auto-discovery
    public init?() async {
        let serverManager = ServerConfigManager.shared
        let healthyServers = await serverManager.getHealthyTTSServers()

        guard let server = healthyServers.first,
              let baseURL = server.baseURL else {
            return nil
        }

        self.baseURL = baseURL
        self.voiceId = "nova"
        self.outputFormat = .wav
        self.sampleRate = 22050  // Default to Piper
        self.providerName = "SelfHosted"
        self.authToken = nil
        self.voiceConfig = TTSVoiceConfig(voiceId: "nova")
    }

    // MARK: - TTSService Protocol

    /// Configure voice settings
    public func configure(_ config: TTSVoiceConfig) async {
        self.voiceConfig = config
        self.voiceId = config.voiceId
        logger.debug("Voice configured: \(config.voiceId)")
    }

    /// Synthesize text to audio stream
    public func synthesize(text: String) async throws -> AsyncStream<TTSAudioChunk> {
        logger.info("[\(providerName)] synthesize called - text length: \(text.count), first 50 chars: '\(text.prefix(50))...'")
        logger.info("[\(providerName)] config - baseURL: \(baseURL.absoluteString), voice: \(voiceId), sampleRate: \(Int(sampleRate))Hz")

        let startTime = Date()
        let currentVoiceId = voiceId

        return AsyncStream { continuation in
            Task {
                do {
                    // Build URL for speech endpoint
                    let speechURL = self.baseURL.appendingPathComponent("v1/audio/speech")
                    self.logger.info("TTS request URL: \(speechURL.absoluteString)")

                    var request = URLRequest(url: speechURL)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.timeoutInterval = 60  // Allow up to 60 seconds for TTS

                    if let token = self.authToken {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }

                    // Build request body (OpenAI-compatible format)
                    let body: [String: Any] = [
                        "model": "tts-1",
                        "input": text,
                        "voice": currentVoiceId,
                        "response_format": self.outputFormat.rawValue
                    ]

                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    self.logger.debug("TTS request body: model=tts-1, voice=\(currentVoiceId), format=\(self.outputFormat.rawValue)")

                    // Make request
                    self.logger.info("Sending TTS request to Piper server...")
                    let (data, response) = try await URLSession.shared.data(for: request)
                    self.logger.info("TTS response received - data size: \(data.count) bytes")

                    guard let httpResponse = response as? HTTPURLResponse else {
                        self.logger.error("TTS response is not HTTPURLResponse")
                        throw TTSError.connectionFailed("Invalid response type")
                    }

                    self.logger.info("TTS HTTP status: \(httpResponse.statusCode)")

                    guard httpResponse.statusCode == 200 else {
                        // Try to read error body
                        if let errorBody = String(data: data, encoding: .utf8) {
                            self.logger.error("TTS error response body: \(errorBody)")
                        }
                        throw TTSError.connectionFailed("HTTP \(httpResponse.statusCode)")
                    }

                    // Create audio chunk from response data
                    // Piper outputs WAV at 22050 Hz, VibeVoice outputs WAV at 24000 Hz (both PCM 16-bit mono)
                    self.logger.info("[\(self.providerName)] Creating TTSAudioChunk with \(data.count) bytes of audio data, sampleRate=\(Int(self.sampleRate))Hz")
                    let chunk = TTSAudioChunk(
                        audioData: data,
                        format: .pcmInt16(sampleRate: self.sampleRate, channels: 1),
                        sequenceNumber: 0,
                        isFirst: true,
                        isLast: true
                    )

                    self.logger.info("Yielding TTS chunk to stream")
                    continuation.yield(chunk)

                    // Update metrics
                    let latency = Date().timeIntervalSince(startTime)
                    self.latencyValues.append(latency)
                    self.characterCounts.append(text.count)
                    self.synthesisTimings.append(latency)
                    self.updateMetrics()

                    self.logger.info("TTS synthesis complete: \(text.count) chars -> \(data.count) bytes in \(String(format: "%.3f", latency))s")

                    continuation.finish()
                } catch {
                    self.logger.error("TTS synthesis failed: \(error.localizedDescription), full error: \(error)")
                    continuation.finish()
                }
            }
        }
    }

    /// Flush any pending audio and stop synthesis
    public func flush() async throws {
        // For non-streaming TTS, nothing to flush
        logger.debug("TTS flush called (no-op for non-streaming)")
    }

    // MARK: - Health Check

    /// Check if the server is healthy
    public func checkHealth() async -> Bool {
        let healthURL = baseURL.appendingPathComponent("health")

        do {
            var request = URLRequest(url: healthURL)
            request.timeoutInterval = 5

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                return true
            }
        } catch {
            logger.warning("Health check failed: \(error.localizedDescription)")
        }

        return false
    }

    // MARK: - Voice Management

    /// List available voices (if server supports it)
    public func listVoices() async throws -> [VoiceInfo] {
        let voicesURL = baseURL.appendingPathComponent("v1/voices")

        do {
            let (data, response) = try await URLSession.shared.data(from: voicesURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return defaultVoices
            }

            // Try to parse voice list
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let voices = json["voices"] as? [[String: Any]] {
                return voices.compactMap { voiceData -> VoiceInfo? in
                    guard let id = voiceData["id"] as? String ?? voiceData["voice_id"] as? String,
                          let name = voiceData["name"] as? String else {
                        return nil
                    }
                    return VoiceInfo(
                        id: id,
                        name: name,
                        language: voiceData["language"] as? String ?? "en",
                        gender: voiceData["gender"] as? String
                    )
                }
            }
        } catch {
            logger.debug("Could not list voices, using defaults")
        }

        return defaultVoices
    }

    private var defaultVoices: [VoiceInfo] {
        [
            VoiceInfo(id: "nova", name: "Nova", language: "en", gender: "female"),
            VoiceInfo(id: "alloy", name: "Alloy", language: "en", gender: "neutral"),
            VoiceInfo(id: "echo", name: "Echo", language: "en", gender: "male"),
            VoiceInfo(id: "fable", name: "Fable", language: "en", gender: "male"),
            VoiceInfo(id: "onyx", name: "Onyx", language: "en", gender: "male"),
            VoiceInfo(id: "shimmer", name: "Shimmer", language: "en", gender: "female")
        ]
    }

    // MARK: - Private Methods

    private func updateMetrics() {
        // Calculate median and p99 TTFB from latency values
        guard !latencyValues.isEmpty else { return }

        let sorted = latencyValues.sorted()
        let medianIndex = sorted.count / 2
        let p99Index = min(Int(Double(sorted.count) * 0.99), sorted.count - 1)

        metrics = TTSMetrics(
            medianTTFB: sorted[medianIndex],
            p99TTFB: sorted[p99Index]
        )
    }
}

// MARK: - Factory

extension SelfHostedTTSService {

    /// Create a service connected to local Piper server
    /// - Parameters:
    ///   - host: Server hostname or IP (default: localhost)
    ///   - port: Piper port (default: 11402)
    ///   - voice: Voice ID (default: nova)
    /// - Returns: Configured TTS service for Piper (22050 Hz)
    public static func piper(
        host: String = "localhost",
        port: Int = 11402,
        voice: String = "nova"
    ) -> SelfHostedTTSService {
        let url = URL(string: "http://\(host):\(port)")!
        return SelfHostedTTSService(
            baseURL: url,
            voiceId: voice,
            sampleRate: 22050,  // Piper outputs 22050 Hz
            providerName: "Piper"
        )
    }

    /// Create a service connected to local VibeVoice server (Microsoft VibeVoice-Realtime-0.5B)
    /// - Parameters:
    ///   - host: Server hostname or IP (default: localhost)
    ///   - port: VibeVoice port (default: 8880)
    ///   - voice: Voice ID - supports OpenAI aliases: alloy, echo, fable, onyx, nova, shimmer (default: nova)
    /// - Returns: Configured TTS service for VibeVoice (24000 Hz)
    public static func vibeVoice(
        host: String = "localhost",
        port: Int = 8880,
        voice: String = "nova"
    ) -> SelfHostedTTSService {
        let url = URL(string: "http://\(host):\(port)")!
        return SelfHostedTTSService(
            baseURL: url,
            voiceId: voice,
            sampleRate: 24000,  // VibeVoice outputs 24000 Hz
            providerName: "VibeVoice"
        )
    }

    /// Create a service connected to UnaMentis gateway
    public static func voicelearnGateway(
        host: String = "localhost",
        port: Int = 11400,
        voice: String = "nova"
    ) -> SelfHostedTTSService {
        let url = URL(string: "http://\(host):\(port)")!
        return SelfHostedTTSService(
            baseURL: url,
            voiceId: voice,
            sampleRate: 22050,
            providerName: "Gateway"
        )
    }

    /// Create a service from auto-discovered server
    public static func autoDiscover() async -> SelfHostedTTSService? {
        await SelfHostedTTSService()
    }

    /// Create a TTS service based on provider type
    /// - Parameters:
    ///   - provider: The TTS provider to use
    ///   - host: Server hostname or IP
    ///   - voice: Voice ID
    /// - Returns: Configured TTS service for the specified provider
    public static func forProvider(
        _ provider: TTSProvider,
        host: String,
        voice: String = "nova"
    ) -> SelfHostedTTSService? {
        switch provider {
        case .selfHosted:
            return piper(host: host, voice: voice)
        case .vibeVoice:
            return vibeVoice(host: host, voice: voice)
        default:
            return nil  // Not a self-hosted provider
        }
    }
}

// MARK: - Supporting Types

/// Audio format for TTS output
public enum AudioFormat: String, Sendable {
    case wav = "wav"
    case mp3 = "mp3"
    case opus = "opus"
    case aac = "aac"
    case flac = "flac"
    case pcm = "pcm"
}

/// Information about a TTS voice
public struct VoiceInfo: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let language: String
    public let gender: String?
}

// Note: TTSMetrics and TTSError are defined in TTSService.swift
