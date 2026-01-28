//
//  KBAudioGenerator.swift
//  UnaMentis
//
//  Audio generation for KB audio test harness
//  Generates audio from text via TTS or loads from files
//

import AVFoundation
import OSLog

// MARK: - Audio Generator

/// Generates audio buffers for KB audio testing
///
/// Supports:
/// - TTS generation using various providers
/// - Loading audio from files
/// - Converting to STT-compatible format (16kHz mono float32)
actor KBAudioGenerator {
    private let logger = Logger(subsystem: "com.unamentis", category: "KBAudioGenerator")

    /// Target format for STT (16kHz mono float32)
    static let sttFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    // MARK: - Public API

    /// Generate audio from text using TTS
    ///
    /// - Parameters:
    ///   - text: Text to synthesize
    ///   - provider: TTS provider to use
    ///   - convertToSTTFormat: Whether to convert to 16kHz mono for STT
    /// - Returns: Audio buffer and generation latency
    func generateAudio(
        for text: String,
        using provider: TTSProvider,
        convertToSTTFormat: Bool = true
    ) async throws -> GeneratedAudio {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Create TTS service for the provider
        let ttsService = try createTTSService(for: provider)

        // Synthesize audio
        let audioStream = try await ttsService.synthesize(text: text)

        // Collect all audio chunks
        var chunks: [TTSAudioChunk] = []
        for try await chunk in audioStream {
            chunks.append(chunk)
        }

        guard !chunks.isEmpty else {
            throw KBAudioGeneratorError.noAudioGenerated
        }

        // Combine chunks into a single buffer
        let buffer = try combineChunks(chunks)

        // Convert to STT format if requested
        let outputBuffer: AVAudioPCMBuffer
        if convertToSTTFormat {
            outputBuffer = try convertBufferToSTTFormat(buffer)
        } else {
            outputBuffer = buffer
        }

        let latencyMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let durationMs = Double(outputBuffer.frameLength) / outputBuffer.format.sampleRate * 1000

        logger.info("Generated audio: \(text.prefix(30))... (\(String(format: "%.1f", latencyMs))ms, \(String(format: "%.1f", durationMs))ms duration)")

        return GeneratedAudio(
            buffer: outputBuffer,
            latencyMs: latencyMs,
            durationMs: durationMs,
            provider: provider
        )
    }

    /// Load audio from a file path
    ///
    /// - Parameters:
    ///   - path: Path to audio file
    ///   - convertToSTTFormat: Whether to convert to 16kHz mono for STT
    /// - Returns: Audio buffer and loading latency
    func loadAudioFile(
        at path: String,
        convertToSTTFormat: Bool = true
    ) async throws -> GeneratedAudio {
        let startTime = CFAbsoluteTimeGetCurrent()
        let fileURL = URL(fileURLWithPath: path)

        // Verify file exists
        guard FileManager.default.fileExists(atPath: path) else {
            throw KBAudioGeneratorError.fileNotFound(path)
        }

        // Load audio file
        let audioFile = try AVAudioFile(forReading: fileURL)
        let sourceFormat = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        // Create buffer and read file
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
            throw KBAudioGeneratorError.bufferCreationFailed
        }

        try audioFile.read(into: sourceBuffer)

        // Convert to STT format if requested
        let outputBuffer: AVAudioPCMBuffer
        if convertToSTTFormat {
            outputBuffer = try convertBufferToSTTFormat(sourceBuffer)
        } else {
            outputBuffer = sourceBuffer
        }

        let latencyMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let durationMs = Double(outputBuffer.frameLength) / outputBuffer.format.sampleRate * 1000

        logger.info("Loaded audio: \(path) (\(String(format: "%.1f", latencyMs))ms, \(String(format: "%.1f", durationMs))ms duration)")

        return GeneratedAudio(
            buffer: outputBuffer,
            latencyMs: latencyMs,
            durationMs: durationMs,
            provider: nil
        )
    }

    /// Load audio from app bundle
    func loadBundleAudio(
        name: String,
        extension ext: String,
        convertToSTTFormat: Bool = true
    ) async throws -> GeneratedAudio {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            throw KBAudioGeneratorError.bundleResourceNotFound(name, ext)
        }

        return try await loadAudioFile(at: url.path, convertToSTTFormat: convertToSTTFormat)
    }

    /// Generate audio from an audio source specification
    func generateFromSource(
        _ source: KBAudioTestCase.AudioSource,
        text: String
    ) async throws -> GeneratedAudio {
        switch source {
        case .generateTTS(let provider):
            return try await generateAudio(for: text, using: provider)

        case .prerecordedFile(let path):
            return try await loadAudioFile(at: path)

        case .prerecordedBundle(let name, let ext):
            return try await loadBundleAudio(name: name, extension: ext)

        case .rawAudioData(let data, let format):
            return try createBufferFromRawData(data, format: format)
        }
    }

    // MARK: - Private Helpers

    /// Create TTS service for provider
    private func createTTSService(for provider: TTSProvider) throws -> any TTSService {
        switch provider {
        case .appleTTS:
            return AppleTTSService()

        case .kyutaiPocket:
            return KyutaiPocketTTSService()

        // For cloud/self-hosted providers, we'd need server configuration
        // For testing, we primarily use on-device providers
        default:
            throw KBAudioGeneratorError.providerNotSupported(provider)
        }
    }

    /// Combine TTS audio chunks into a single buffer
    private func combineChunks(_ chunks: [TTSAudioChunk]) throws -> AVAudioPCMBuffer {
        guard let firstChunk = chunks.first else {
            throw KBAudioGeneratorError.noAudioGenerated
        }

        // Get format from first chunk
        guard let format = firstChunk.format.avAudioFormat else {
            throw KBAudioGeneratorError.invalidAudioFormat
        }

        // Combine all audio data
        var combinedData = Data()
        for chunk in chunks {
            combinedData.append(chunk.audioData)
        }

        // Calculate frame count
        let bytesPerFrame = format.streamDescription.pointee.mBytesPerFrame
        let frameCount = UInt32(combinedData.count) / bytesPerFrame

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw KBAudioGeneratorError.bufferCreationFailed
        }

        buffer.frameLength = frameCount

        // Copy data to buffer based on format
        combinedData.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }

            switch firstChunk.format {
            case .pcmFloat32:
                if let channelData = buffer.floatChannelData?[0] {
                    memcpy(channelData, baseAddress, combinedData.count)
                }
            case .pcmInt16:
                if let channelData = buffer.int16ChannelData?[0] {
                    memcpy(channelData, baseAddress, combinedData.count)
                }
            default:
                break
            }
        }

        return buffer
    }

    /// Convert buffer to STT format (16kHz mono float32)
    private func convertBufferToSTTFormat(_ sourceBuffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        let sourceFormat = sourceBuffer.format
        let targetFormat = Self.sttFormat

        // If already in target format, return as-is
        if sourceFormat.sampleRate == targetFormat.sampleRate &&
            sourceFormat.channelCount == targetFormat.channelCount &&
            sourceFormat.commonFormat == targetFormat.commonFormat {
            return sourceBuffer
        }

        // Create converter
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw KBAudioGeneratorError.conversionFailed("Failed to create audio converter")
        }

        // Calculate output frame count
        let ratio = targetFormat.sampleRate / sourceFormat.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(sourceBuffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
            throw KBAudioGeneratorError.bufferCreationFailed
        }

        // Perform conversion
        var error: NSError?
        nonisolated(unsafe) let capturedSource = sourceBuffer
        nonisolated(unsafe) var hasProvidedData = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if hasProvidedData {
                outStatus.pointee = .endOfStream
                return nil
            }
            hasProvidedData = true
            outStatus.pointee = .haveData
            return capturedSource
        }

        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if status == .error, let error = error {
            throw KBAudioGeneratorError.conversionFailed(error.localizedDescription)
        }

        // Set frame length to actual converted frames
        if outputBuffer.frameLength == 0 {
            outputBuffer.frameLength = outputFrameCount
        }

        return outputBuffer
    }

    /// Create buffer from raw audio data
    private func createBufferFromRawData(
        _ data: Data,
        format: KBAudioTestCase.AudioSource.AudioFormat
    ) throws -> GeneratedAudio {
        let startTime = CFAbsoluteTimeGetCurrent()

        let commonFormat: AVAudioCommonFormat = format.isFloat ? .pcmFormatFloat32 : .pcmFormatInt16

        guard let audioFormat = AVAudioFormat(
            commonFormat: commonFormat,
            sampleRate: format.sampleRate,
            channels: format.channels,
            interleaved: false
        ) else {
            throw KBAudioGeneratorError.invalidAudioFormat
        }

        let bytesPerFrame = audioFormat.streamDescription.pointee.mBytesPerFrame
        let frameCount = UInt32(data.count) / bytesPerFrame

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            throw KBAudioGeneratorError.bufferCreationFailed
        }

        buffer.frameLength = frameCount

        // Copy data to buffer
        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }

            if format.isFloat {
                if let channelData = buffer.floatChannelData?[0] {
                    memcpy(channelData, baseAddress, data.count)
                }
            } else {
                if let channelData = buffer.int16ChannelData?[0] {
                    memcpy(channelData, baseAddress, data.count)
                }
            }
        }

        // Convert to STT format
        let outputBuffer = try convertBufferToSTTFormat(buffer)

        let latencyMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let durationMs = Double(outputBuffer.frameLength) / outputBuffer.format.sampleRate * 1000

        return GeneratedAudio(
            buffer: outputBuffer,
            latencyMs: latencyMs,
            durationMs: durationMs,
            provider: nil
        )
    }
}

// MARK: - Generated Audio Result

extension KBAudioGenerator {
    /// Result from audio generation
    /// - Note: @unchecked Sendable because AVAudioPCMBuffer is not Sendable, but we control access through actors
    struct GeneratedAudio: @unchecked Sendable {
        /// Audio buffer ready for STT injection
        let buffer: AVAudioPCMBuffer

        /// Time to generate/load audio (ms)
        let latencyMs: Double

        /// Duration of audio (ms)
        let durationMs: Double

        /// TTS provider used (if applicable)
        let provider: TTSProvider?
    }
}

// MARK: - Errors

/// Errors from audio generation
enum KBAudioGeneratorError: Error, LocalizedError {
    case providerNotSupported(TTSProvider)
    case noAudioGenerated
    case invalidAudioFormat
    case bufferCreationFailed
    case conversionFailed(String)
    case fileNotFound(String)
    case bundleResourceNotFound(String, String)

    var errorDescription: String? {
        switch self {
        case .providerNotSupported(let provider):
            return "TTS provider not supported for testing: \(provider.displayName)"
        case .noAudioGenerated:
            return "TTS synthesis produced no audio"
        case .invalidAudioFormat:
            return "Invalid or unsupported audio format"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .conversionFailed(let message):
            return "Audio conversion failed: \(message)"
        case .fileNotFound(let path):
            return "Audio file not found: \(path)"
        case .bundleResourceNotFound(let name, let ext):
            return "Bundle resource not found: \(name).\(ext)"
        }
    }
}
