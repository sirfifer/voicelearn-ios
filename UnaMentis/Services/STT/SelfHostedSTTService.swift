// UnaMentis - Self-Hosted STT Service
// OpenAI-compatible Speech-to-Text service for self-hosted Whisper servers
//
// Part of Services/STT

import Foundation
import Logging
import AVFoundation

/// Self-hosted STT service compatible with OpenAI Whisper API format
///
/// Works with:
/// - whisper.cpp server
/// - faster-whisper server
/// - UnaMentis gateway STT endpoint
/// - Any OpenAI-compatible transcription API
public actor SelfHostedSTTService: STTService {

    // MARK: - Properties

    private let logger = Logger(label: "com.unamentis.stt.selfhosted")
    private let baseURL: URL
    private let authToken: String?
    private let language: String
    private let modelHint: String?

    /// Performance metrics
    public private(set) var metrics: STTMetrics = STTMetrics(
        averageLatency: 0.3,
        wordErrorRate: 0.05
    )

    private var latencyValues: [TimeInterval] = []

    // MARK: - Initialization

    /// Initialize with explicit configuration
    /// - Parameters:
    ///   - baseURL: Base URL of the server (e.g., http://localhost:11401)
    ///   - language: Language code (e.g., "en", "auto")
    ///   - modelHint: Optional model hint for the server
    ///   - authToken: Optional authentication token
    public init(
        baseURL: URL,
        language: String = "en",
        modelHint: String? = nil,
        authToken: String? = nil
    ) {
        self.baseURL = baseURL
        self.language = language
        self.modelHint = modelHint
        self.authToken = authToken
        logger.info("SelfHostedSTTService initialized: \(baseURL.absoluteString)")
    }

    /// Initialize from ServerConfig
    public init?(server: ServerConfig, language: String = "en") {
        guard let baseURL = server.baseURL else {
            return nil
        }
        self.baseURL = baseURL
        self.language = language
        self.modelHint = nil
        self.authToken = nil
        logger.info("SelfHostedSTTService initialized from server config: \(server.name)")
    }

    /// Initialize with auto-discovery
    public init?() async {
        let serverManager = ServerConfigManager.shared
        let healthyServers = await serverManager.getHealthySTTServers()

        guard let server = healthyServers.first,
              let baseURL = server.baseURL else {
            return nil
        }

        self.baseURL = baseURL
        self.language = "en"
        self.modelHint = nil
        self.authToken = nil
    }

    // MARK: - STTService Protocol

    /// Transcribe audio data to text
    public func transcribe(audioData: Data) async throws -> TranscriptionResult {
        let startTime = Date()

        // Build URL for transcription endpoint
        let transcribeURL = baseURL.appendingPathComponent("v1/audio/transcriptions")

        // Create multipart form request
        let boundary = UUID().uuidString
        var request = URLRequest(url: transcribeURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Build multipart body
        var body = Data()

        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add model hint if provided
        if let model = modelHint {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(model)\r\n".data(using: .utf8)!)
        }

        // Add language
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(language)\r\n".data(using: .utf8)!)

        // Add response format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("verbose_json\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw STTError.connectionFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            throw STTError.connectionFailed("HTTP \(httpResponse.statusCode)")
        }

        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw STTError.connectionFailed("Invalid JSON response")
        }

        let text = json["text"] as? String ?? ""
        let duration = json["duration"] as? Double ?? 0

        // Parse word-level timestamps if available
        var words: [TranscribedWord] = []
        if let segments = json["segments"] as? [[String: Any]] {
            for segment in segments {
                if let segmentWords = segment["words"] as? [[String: Any]] {
                    for wordInfo in segmentWords {
                        if let word = wordInfo["word"] as? String,
                           let start = wordInfo["start"] as? Double,
                           let end = wordInfo["end"] as? Double {
                            words.append(TranscribedWord(
                                word: word.trimmingCharacters(in: .whitespaces),
                                startTime: start,
                                endTime: end,
                                confidence: wordInfo["probability"] as? Float ?? 0.9
                            ))
                        }
                    }
                }
            }
        }

        // Calculate latency
        let latency = Date().timeIntervalSince(startTime)
        latencyValues.append(latency)
        updateMetrics()

        logger.debug("Transcription complete: \(text.prefix(50))... (latency: \(String(format: "%.3f", latency))s)")

        return TranscriptionResult(
            text: text,
            words: words,
            language: json["language"] as? String ?? language,
            duration: duration,
            isFinal: true
        )
    }

    // MARK: - Streaming Transcription

    /// Start streaming transcription (for servers that support it)
    public func startStreamingTranscription() async throws -> AsyncStream<TranscriptionResult> {
        // Note: Many self-hosted Whisper servers don't support true streaming
        // This is a placeholder for servers that do support WebSocket streaming

        logger.warning("Streaming transcription not implemented for HTTP-based STT service")
        throw STTError.connectionFailed("Streaming not supported")
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

    // MARK: - Private Methods

    private func updateMetrics() {
        let avgLatency = latencyValues.isEmpty ? 0.3 : latencyValues.reduce(0, +) / Double(latencyValues.count)

        metrics = STTMetrics(
            averageLatency: avgLatency,
            wordErrorRate: 0.05  // Estimated, would need ground truth to calculate
        )
    }
}

// MARK: - Factory

extension SelfHostedSTTService {

    /// Create a service connected to local Whisper server
    public static func whisper(
        host: String = "localhost",
        port: Int = 11401,
        language: String = "en"
    ) -> SelfHostedSTTService {
        let url = URL(string: "http://\(host):\(port)")!
        return SelfHostedSTTService(baseURL: url, language: language)
    }

    /// Create a service connected to UnaMentis gateway
    public static func voicelearnGateway(
        host: String = "localhost",
        port: Int = 11400,
        language: String = "en"
    ) -> SelfHostedSTTService {
        let url = URL(string: "http://\(host):\(port)")!
        return SelfHostedSTTService(baseURL: url, language: language)
    }

    /// Create a service from auto-discovered server
    public static func autoDiscover() async -> SelfHostedSTTService? {
        await SelfHostedSTTService()
    }
}

// MARK: - Supporting Types

/// Result of a transcription
public struct TranscriptionResult: Sendable {
    public let text: String
    public let words: [TranscribedWord]
    public let language: String
    public let duration: Double
    public let isFinal: Bool
}

/// A single transcribed word with timing
public struct TranscribedWord: Sendable {
    public let word: String
    public let startTime: Double
    public let endTime: Double
    public let confidence: Float
}

/// STT service metrics
public struct STTMetrics: Sendable {
    public let averageLatency: TimeInterval
    public let wordErrorRate: Double
}

/// STT service errors
public enum STTError: Error, LocalizedError {
    case connectionFailed(String)
    case authenticationFailed
    case invalidAudioFormat
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let message): return "Connection failed: \(message)"
        case .authenticationFailed: return "Authentication failed"
        case .invalidAudioFormat: return "Invalid audio format"
        case .serverError(let message): return "Server error: \(message)"
        }
    }
}
