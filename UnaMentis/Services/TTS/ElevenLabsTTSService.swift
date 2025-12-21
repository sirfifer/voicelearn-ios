// UnaMentis - ElevenLabs TTS Service
// Streaming Text-to-Speech using ElevenLabs Turbo v2.5 via WebSockets
//
// Part of Provider Implementations (Phase 5)

import Foundation
import AVFoundation
import Logging

/// ElevenLabs Turbo v2.5 streaming TTS implementation
public actor ElevenLabsTTSService: TTSService {
    
    // MARK: - Properties
    
    private let logger = Logger(label: "com.unamentis.tts.elevenlabs")
    private let apiKey: String
    private let baseURL = "wss://api.elevenlabs.io/v1/text-to-speech"
    
    /// Performance metrics
    public private(set) var metrics = TTSMetrics(
        medianTTFB: 0.25,
        p99TTFB: 0.4
    )
    
    /// Cost per character (Turbo v2.5 is ~$18 per 1M characters = $0.000018/char)
    public var costPerCharacter: Decimal {
        Decimal(string: "0.000018")!
    }
    
    /// Current voice configuration
    public private(set) var voiceConfig: TTSVoiceConfig
    
    // WebSocket
    private var webSocketTask: URLSessionWebSocketTask?
    private var streamContinuation: AsyncStream<TTSAudioChunk>.Continuation?
    private var isStreaming = false
    private var sequenceNumber = 0
    private var hasReceivedFirstByte = false
    private var startTime: Date?
    
    // MARK: - Initialization
    
    public init(apiKey: String, voiceId: String = "cjVigY5qzO862AIGy5LS") { // Jessica
        self.apiKey = apiKey
        self.voiceConfig = TTSVoiceConfig(voiceId: voiceId)
        logger.info("ElevenLabsTTSService initialized")
    }
    
    // MARK: - TTSService Protocol
    
    public func configure(_ config: TTSVoiceConfig) async {
        self.voiceConfig = config
        logger.debug("Configured with voice: \(config.voiceId)")
    }
    
    public func synthesize(text: String) async throws -> AsyncStream<TTSAudioChunk> {
        logger.info("Starting synthesis for text: \(text.prefix(20))...")
        
        // If we are not already connected/streaming, we need to establish connection or just do a single-shot streaming request (HTTP also supports streaming, but WS is lower latency for continuous flow).
        // For simple synthesis(text:), standard HTTP streaming might be easier, but WS allows input streaming. 
        // Given the protocol definition `synthesize(text: String)`, it implies a single request. 
        // We will use WebSocket for best latency, sending the whole text and waiting for audio.
        
        let voiceId = voiceConfig.voiceId
        let modelId = "eleven_turbo_v2_5"
        let urlString = "\(baseURL)/\(voiceId)/stream-input?model_id=\(modelId)"
        
        guard let url = URL(string: urlString) else { throw TTSError.synthesizeFailed("Invalid URL") }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        isStreaming = true
        sequenceNumber = 0
        hasReceivedFirstByte = false
        startTime = Date()
        
        // Send initial connection message (BOS)
        let bosMessage: [String: Any] = [
            "text": " ", // Space to trigger connection
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ],
            "generation_config": [
                "chunk_length_schedule": [50]
            ]
        ]
        
        try await sendJSON(bosMessage)
        
        // Send actual text
        let textMessage: [String: Any] = [
            "text": text,
            "try_trigger_generation": true
        ]
        try await sendJSON(textMessage)
        
        // Send EOS
        let eosMessage: [String: Any] = ["text": ""]
        try await sendJSON(eosMessage)
        
        return AsyncStream { continuation in
            self.streamContinuation = continuation
            
            Task {
                await self.listenForMessages()
            }
            
            continuation.onTermination = { @Sendable _ in
                Task { [weak self] in
                    try? await self?.cancel()
                }
            }
        }
    }
    
    public func flush() async throws {
        // Not applicable for single-shot synthesis call, but if we had a persistent stream we would send flush signal
    }
    
    // MARK: - Private Methods
    
    private func sendJSON(_ json: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: json)
        let message = URLSessionWebSocketTask.Message.data(data)
        try await webSocketTask?.send(message)
    }
    
    private func cancel() async throws {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isStreaming = false
        streamContinuation?.finish()
        streamContinuation = nil
    }
    
    private func listenForMessages() async {
        guard let ws = webSocketTask else { return }
        
        do {
            let message = try await ws.receive()
            
            if isStreaming {
                switch message {
                case .string(let text):
                    await handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await handleMessage(text)
                    }
                @unknown default:
                    break
                }
                
                await listenForMessages()
            }
        } catch {
            logger.error("WebSocket receive failed: \(error)")
            // If error, finish stream
            streamContinuation?.finish()
        }
    }
    
    private func handleMessage(_ jsonString: String) async {
        guard let data = jsonString.data(using: .utf8) else { return }
        
        do {
            let response = try JSONDecoder().decode(ElevenLabsResponse.self, from: data)
            
            if let audioBase64 = response.audio {
                if let audioData = Data(base64Encoded: audioBase64) {
                    
                    let ttfb: TimeInterval? = (!hasReceivedFirstByte && startTime != nil) ? Date().timeIntervalSince(startTime!) : nil
                    if ttfb != nil { hasReceivedFirstByte = true }
                    
                    let chunk = TTSAudioChunk(
                        audioData: audioData,
                        format: .mp3, // ElevenLabs sends mp3 by default via WS
                        sequenceNumber: sequenceNumber,
                        isFirst: ttfb != nil,
                        isLast: response.isFinal ?? false,
                        timeToFirstByte: ttfb
                    )
                    
                    streamContinuation?.yield(chunk)
                    sequenceNumber += 1
                }
            }
            
            if response.isFinal == true {
                streamContinuation?.finish()
                try? await cancel()
            }
            
        } catch {
            logger.error("Failed to parse ElevenLabs response: \(error)")
        }
    }
}

// MARK: - Models

private struct ElevenLabsResponse: Codable {
    let audio: String?
    let isFinal: Bool?
    let normalizedAlignment: Alignment?
    
    enum CodingKeys: String, CodingKey {
        case audio
        case isFinal = "isFinal" // Note: Check API docs for casing, usually "isFinal" or snake_case? ElevenLabs docs say "isFinal": bool (optional)
        case normalizedAlignment = "normalizedAlignment"
    }
}

private struct Alignment: Codable {
    let charStartTimesMs: [Int]?
    let charsDurationsMs: [Int]?
    let chars: [String]?
}
