//
//  KBAudioInjector.swift
//  UnaMentis
//
//  Audio injection into STT pipeline for KB audio testing
//  Bypasses microphone to enable Simulator testing
//

import AVFoundation
import OSLog

// MARK: - Audio Injector

/// Injects audio buffers directly into STT service for testing
///
/// This enables testing the STT pipeline without a physical microphone,
/// making it possible to run automated tests in the Simulator.
///
/// Based on the pattern from `LatencyTestCoordinator.transcribeAudioFile()`
actor KBAudioInjector {
    private let logger = Logger(subsystem: "com.unamentis", category: "KBAudioInjector")

    /// Default chunk size: 100ms at 16kHz = 1600 frames
    private let defaultChunkSize: AVAudioFrameCount = 1600

    // MARK: - Public API

    /// Inject audio buffer into STT and get transcript
    ///
    /// - Parameters:
    ///   - buffer: Audio buffer to inject (should be 16kHz mono float32)
    ///   - sttService: STT service to use
    ///   - chunkSize: Size of chunks to send (frames, default 1600 = 100ms at 16kHz)
    /// - Returns: Transcription result with transcript, confidence, and latency
    func injectAndTranscribe(
        buffer: AVAudioPCMBuffer,
        using sttService: any STTService,
        chunkSize: AVAudioFrameCount? = nil
    ) async throws -> TranscriptionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let chunkFrames = chunkSize ?? defaultChunkSize

        // Ensure buffer is in correct format (16kHz mono float32)
        let sttBuffer = try ensureSTTFormat(buffer)

        logger.info("Injecting audio: \(sttBuffer.frameLength) frames, \(sttBuffer.format.sampleRate)Hz")

        // Start STT streaming
        nonisolated(unsafe) let capturedFormat = sttBuffer.format
        let resultStream = try await sttService.startStreaming(audioFormat: capturedFormat)

        // Send audio in chunks
        try await sendAudioInChunks(sttBuffer, to: sttService, chunkSize: chunkFrames)

        // Signal end of audio
        try await sttService.stopStreaming()

        // Collect final transcript
        var finalTranscript = ""
        var sttConfidence: Float = 0

        for await result in resultStream {
            if result.isFinal {
                finalTranscript = result.transcript
                sttConfidence = result.confidence
                break
            }
        }

        let latencyMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        logger.info("Transcription complete: \"\(finalTranscript.prefix(50))...\" (confidence: \(String(format: "%.2f", sttConfidence)), latency: \(String(format: "%.1f", latencyMs))ms)")

        return TranscriptionResult(
            transcript: finalTranscript,
            confidence: sttConfidence,
            latencyMs: latencyMs,
            frameCount: Int(sttBuffer.frameLength)
        )
    }

    /// Inject audio and transcribe using on-device STT (Apple Speech)
    ///
    /// Uses AppleSpeechSTTService which accepts injected buffers without
    /// creating its own audio engine. This is the correct service for testing.
    func injectAndTranscribeOnDevice(
        buffer: AVAudioPCMBuffer
    ) async throws -> TranscriptionResult {
        // Use AppleSpeechSTTService (not KBOnDeviceSTT) because:
        // - AppleSpeechSTTService only receives audio via sendAudio() - no internal audio engine
        // - KBOnDeviceSTT creates its own AVAudioEngine which fails in Simulator
        // - AppleSpeechSTTService has simulator-specific handling for server-based recognition
        let sttService = AppleSpeechSTTService()
        return try await injectAndTranscribe(buffer: buffer, using: sttService)
    }

    // MARK: - Private Helpers

    /// Ensure buffer is in STT format (16kHz mono float32)
    private func ensureSTTFormat(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        let sourceFormat = buffer.format
        let targetFormat = KBAudioGenerator.sttFormat

        // Check if already in correct format
        if sourceFormat.sampleRate == targetFormat.sampleRate &&
            sourceFormat.channelCount == targetFormat.channelCount &&
            sourceFormat.commonFormat == targetFormat.commonFormat {
            return buffer
        }

        // Need to convert
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw KBAudioInjectorError.formatConversionFailed("Cannot create converter")
        }

        // Calculate output frame count
        let ratio = targetFormat.sampleRate / sourceFormat.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
            throw KBAudioInjectorError.bufferCreationFailed
        }

        var error: NSError?
        nonisolated(unsafe) let capturedSource = buffer
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return capturedSource
        }

        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if status == .error, let error = error {
            throw KBAudioInjectorError.formatConversionFailed(error.localizedDescription)
        }

        logger.debug("Converted buffer: \(sourceFormat.sampleRate)Hz -> \(targetFormat.sampleRate)Hz")

        return outputBuffer
    }

    /// Send audio buffer to STT in chunks
    private func sendAudioInChunks(
        _ buffer: AVAudioPCMBuffer,
        to sttService: any STTService,
        chunkSize: AVAudioFrameCount
    ) async throws {
        let targetFormat = buffer.format
        var offset: AVAudioFramePosition = 0
        let totalFrames = AVAudioFramePosition(buffer.frameLength)

        while offset < totalFrames {
            let remainingFrames = AVAudioFrameCount(totalFrames - offset)
            let framesToSend = min(chunkSize, remainingFrames)

            // Create chunk buffer
            guard let chunkBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: framesToSend) else {
                throw KBAudioInjectorError.bufferCreationFailed
            }

            // Copy frames to chunk
            if let sourceData = buffer.floatChannelData?[0],
               let destData = chunkBuffer.floatChannelData?[0] {
                memcpy(destData, sourceData.advanced(by: Int(offset)), Int(framesToSend) * MemoryLayout<Float>.size)
                chunkBuffer.frameLength = framesToSend
            }

            // Send chunk to STT
            nonisolated(unsafe) let sendBuffer = chunkBuffer
            try await sttService.sendAudio(sendBuffer)
            offset += AVAudioFramePosition(framesToSend)

            // Optional: small delay to simulate real-time streaming
            // Uncomment if STT service has issues with fast injection
            // try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        logger.debug("Sent \(totalFrames) frames in \(Int(ceil(Double(totalFrames) / Double(chunkSize)))) chunks")
    }
}

// MARK: - Transcription Result

extension KBAudioInjector {
    /// Result from audio injection and transcription
    public struct TranscriptionResult: Sendable {
        /// Transcribed text
        let transcript: String

        /// STT confidence (0.0-1.0)
        let confidence: Float

        /// Time to transcribe (ms)
        let latencyMs: Double

        /// Number of frames processed
        let frameCount: Int

        /// Duration of audio (ms), assuming 16kHz
        var audioDurationMs: Double {
            Double(frameCount) / 16000.0 * 1000.0
        }
    }
}

// MARK: - Errors

/// Errors from audio injection
enum KBAudioInjectorError: Error, LocalizedError {
    case formatConversionFailed(String)
    case bufferCreationFailed
    case sttStartFailed(String)
    case sttSendFailed(String)

    var errorDescription: String? {
        switch self {
        case .formatConversionFailed(let message):
            return "Audio format conversion failed: \(message)"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .sttStartFailed(let message):
            return "Failed to start STT streaming: \(message)"
        case .sttSendFailed(let message):
            return "Failed to send audio to STT: \(message)"
        }
    }
}
