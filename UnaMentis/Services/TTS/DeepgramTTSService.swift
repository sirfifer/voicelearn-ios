// UnaMentis - Deepgram TTS Service
// Streaming Text-to-Speech using Deepgram Aura-2
//
// Part of Provider Implementations (TDD Section 6)

import Foundation
@preconcurrency import AVFoundation
import Logging

/// Deepgram Aura-2 streaming TTS implementation
///
/// Provides:
/// - Low latency streaming synthesis
/// - Multiple voice options
/// - PCM audio output for direct playback
public actor DeepgramTTSService: TTSService {
    
    // MARK: - Properties
    
    private let logger = Logger(label: "com.unamentis.tts.deepgram")
    private let apiKey: String
    private let baseURL = "https://api.deepgram.com/v1/speak"
    
    /// Performance metrics
    public private(set) var metrics: TTSMetrics = TTSMetrics(
        medianTTFB: 0.08,
        p99TTFB: 0.15
    )
    
    /// Cost per character ($0.0135 per 1000 chars for Aura)
    public var costPerCharacter: Decimal {
        0.0135 / 1000
    }
    
    /// Current voice configuration
    public private(set) var voiceConfig: TTSVoiceConfig
    
    /// Track TTFB for metrics
    private var ttfbValues: [TimeInterval] = []
    
    // MARK: - Voice Options
    
    /// Available Deepgram Aura voices
    public enum AuraVoice: String, CaseIterable, Sendable {
        case asteria = "aura-asteria-en"  // American female
        case luna = "aura-luna-en"        // American female
        case stella = "aura-stella-en"     // American female
        case athena = "aura-athena-en"    // British female
        case hera = "aura-hera-en"        // American female
        case orion = "aura-orion-en"      // American male
        case arcas = "aura-arcas-en"      // American male
        case perseus = "aura-perseus-en"  // American male
        case angus = "aura-angus-en"      // Irish male
        case orpheus = "aura-orpheus-en"  // American male
        case helios = "aura-helios-en"    // British male
        case zeus = "aura-zeus-en"        // American male
    }
    
    // MARK: - Initialization
    
    public init(apiKey: String, voice: AuraVoice = .asteria) {
        self.apiKey = apiKey
        self.voiceConfig = TTSVoiceConfig(voiceId: voice.rawValue)
        logger.info("DeepgramTTSService initialized with voice: \(voice.rawValue)")
    }
    
    // MARK: - TTSService Protocol
    
    public func configure(_ config: TTSVoiceConfig) async {
        self.voiceConfig = config
        logger.debug("Configured with voice: \(config.voiceId)")
    }
    
    public func synthesize(text: String) async throws -> AsyncStream<TTSAudioChunk> {
        logger.info("Starting synthesis for text of length \(text.count)")
        
        let startTime = Date()
        
        // Build request URL with parameters
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "model", value: voiceConfig.voiceId),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "24000"),
            URLQueryItem(name: "container", value: "none")
        ]
        
        guard let url = components.url else {
            throw TTSError.synthesizeFailed("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["text": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return AsyncStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        throw TTSError.synthesizeFailed("HTTP error")
                    }
                    
                    var sequenceNumber = 0
                    var isFirst = true
                    var buffer = Data()
                    let chunkSize = 4800 // 100ms at 24kHz, 16-bit mono
                    
                    for try await byte in bytes {
                        buffer.append(byte)
                        
                        // Emit chunks as they accumulate
                        while buffer.count >= chunkSize {
                            let ttfb: TimeInterval? = isFirst ? Date().timeIntervalSince(startTime) : nil
                            if let ttfb = ttfb {
                                self.ttfbValues.append(ttfb)
                            }
                            
                            let chunkData = buffer.prefix(chunkSize)
                            buffer.removeFirst(chunkSize)
                            
                            let chunk = TTSAudioChunk(
                                audioData: Data(chunkData),
                                format: .pcmInt16(sampleRate: 24000, channels: 1),
                                sequenceNumber: sequenceNumber,
                                isFirst: isFirst,
                                isLast: false,
                                timeToFirstByte: ttfb
                            )
                            
                            continuation.yield(chunk)
                            sequenceNumber += 1
                            isFirst = false
                        }
                    }
                    
                    // Emit remaining data as final chunk
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
                    
                    await self.updateMetrics()
                    continuation.finish()
                    
                } catch {
                    self.logger.error("TTS synthesis failed: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }
    
    public func flush() async throws {
        // No buffering in this implementation
        logger.debug("Flush called")
    }
    
    // MARK: - Private Methods
    
    private func updateMetrics() {
        guard !ttfbValues.isEmpty else { return }
        
        let sorted = ttfbValues.sorted()
        let medianIndex = sorted.count / 2
        let p99Index = Int(Double(sorted.count) * 0.99)
        
        metrics = TTSMetrics(
            medianTTFB: sorted[medianIndex],
            p99TTFB: sorted[Swift.min(p99Index, sorted.count - 1)]
        )
    }
}
