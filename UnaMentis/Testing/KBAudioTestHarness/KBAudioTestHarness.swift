//
//  KBAudioTestHarness.swift
//  UnaMentis
//
//  Main coordinator for KB audio Q&A pipeline testing
//  Orchestrates: TTS generation -> Audio injection -> STT -> Validation
//

import AVFoundation
import OSLog
@preconcurrency import Darwin

// MARK: - Audio Test Harness

/// Coordinates KB audio Q&A pipeline testing
///
/// Enables iterative testing of the full audio pipeline in the Simulator:
/// 1. Generate TTS audio from expected answers
/// 2. Inject audio directly into STT (bypassing microphone)
/// 3. Get transcript from STT
/// 4. Validate transcript against expected answer semantically
/// 5. Report detailed results with per-phase latencies
///
/// Usage:
/// ```swift
/// let harness = KBAudioTestHarness()
/// let testCase = KBAudioTestCase.simple(
///     questionText: "What is the capital of France?",
///     expectedAnswer: "Paris"
/// )
/// let result = try await harness.runTest(testCase)
/// print("Success: \(result.isSuccess)")
/// ```
actor KBAudioTestHarness {
    private let logger = Logger(subsystem: "com.unamentis", category: "KBAudioTestHarness")

    // MARK: - Components

    private let audioGenerator: KBAudioGenerator
    private let audioInjector: KBAudioInjector
    private var transcriptValidator: KBTranscriptValidator

    // MARK: - STT Service

    private var sttService: (any STTService)?

    // MARK: - State

    private var isRunning = false
    private var isCancelled = false
    private var currentTestCase: KBAudioTestCase?

    // MARK: - Initialization

    init(
        sttService: (any STTService)? = nil,
        embeddingsService: KBEmbeddingsService? = nil,
        llmValidator: KBLLMValidator? = nil
    ) {
        self.audioGenerator = KBAudioGenerator()
        self.audioInjector = KBAudioInjector()
        self.transcriptValidator = KBTranscriptValidator(
            strictness: .standard,
            embeddingsService: embeddingsService,
            llmValidator: llmValidator
        )
        self.sttService = sttService
    }

    // MARK: - Configuration

    /// Configure the STT service to use
    func setSTTService(_ service: any STTService) {
        self.sttService = service
    }

    /// Configure validation strictness
    func setValidationStrictness(_ strictness: KBTranscriptValidator.StrictnessLevel) {
        self.transcriptValidator = KBTranscriptValidator(strictness: strictness)
    }

    // MARK: - Single Test Execution

    /// Run a single test case
    func runTest(_ testCase: KBAudioTestCase) async throws -> KBAudioTestResult {
        guard !isRunning else {
            throw KBAudioTestHarnessError.alreadyRunning
        }

        isRunning = true
        isCancelled = false
        currentTestCase = testCase

        defer {
            isRunning = false
            currentTestCase = nil
        }

        let pipelineStart = CFAbsoluteTimeGetCurrent()

        logger.info("Starting test: \(testCase.name)")

        // Check for cancellation
        if isCancelled {
            throw KBAudioTestHarnessError.cancelled
        }

        // PHASE 1: Generate or load audio
        let generatedAudio: KBAudioGenerator.GeneratedAudio
        do {
            generatedAudio = try await audioGenerator.generateFromSource(
                testCase.audioSource,
                text: testCase.expectedAnswer
            )
        } catch {
            logger.error("Audio generation failed: \(error.localizedDescription)")
            return .failed(testCase: testCase, error: error)
        }

        if isCancelled {
            throw KBAudioTestHarnessError.cancelled
        }

        // PHASE 2: Inject audio and transcribe
        let transcriptionResult: KBAudioInjector.TranscriptionResult
        do {
            if let sttService = sttService {
                transcriptionResult = try await audioInjector.injectAndTranscribe(
                    buffer: generatedAudio.buffer,
                    using: sttService
                )
            } else {
                // Default to on-device STT
                transcriptionResult = try await audioInjector.injectAndTranscribeOnDevice(
                    buffer: generatedAudio.buffer
                )
            }
        } catch {
            logger.error("STT failed: \(error.localizedDescription)")
            return .failed(testCase: testCase, error: error)
        }

        if isCancelled {
            throw KBAudioTestHarnessError.cancelled
        }

        // PHASE 3: Validate transcript
        let validationStart = CFAbsoluteTimeGetCurrent()
        let validationResult = await transcriptValidator.validate(
            transcript: transcriptionResult.transcript,
            expected: testCase.expectedAnswer,
            answerType: testCase.answerType,
            config: testCase.validationConfig
        )
        let validationLatencyMs = (CFAbsoluteTimeGetCurrent() - validationStart) * 1000

        // Calculate total pipeline time
        let totalPipelineMs = (CFAbsoluteTimeGetCurrent() - pipelineStart) * 1000

        // Build result
        let result = KBAudioTestResult(
            testCaseId: testCase.id,
            testCaseName: testCase.name,
            audioGenerationLatencyMs: generatedAudio.latencyMs,
            audioDurationMs: generatedAudio.durationMs,
            sttLatencyMs: transcriptionResult.latencyMs,
            sttConfidence: transcriptionResult.confidence,
            transcribedText: transcriptionResult.transcript,
            validationLatencyMs: validationLatencyMs,
            validationResult: validationResult,
            totalPipelineMs: totalPipelineMs,
            peakMemoryMB: getCurrentMemoryMB(),
            thermalState: getThermalState()
        )

        logger.info("Test complete: \(result.isSuccess ? "PASS" : "FAIL") - \(testCase.name)")

        return result
    }

    // MARK: - Suite Execution

    /// Run a test suite
    func runSuite(_ suite: KBAudioTestSuite) async throws -> KBAudioTestSuiteResult {
        let startTime = Date()
        var results: [KBAudioTestResult] = []

        logger.info("Starting suite: \(suite.name) (\(suite.totalExecutions) tests)")

        for repetition in 0..<suite.repetitions {
            for testCase in suite.testCases {
                if isCancelled {
                    throw KBAudioTestHarnessError.cancelled
                }

                do {
                    let result = try await runTest(testCase)
                    results.append(result)
                } catch {
                    // Record failed result but continue
                    let failedResult = KBAudioTestResult.failed(
                        testCase: testCase,
                        error: error
                    )
                    results.append(failedResult)
                }

                // Small delay between tests to let system settle
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }

            if suite.repetitions > 1 {
                logger.info("Completed repetition \(repetition + 1)/\(suite.repetitions)")
            }
        }

        let suiteResult = KBAudioTestSuiteResult(
            suiteId: suite.id,
            suiteName: suite.name,
            startTime: startTime,
            results: results
        )

        logger.info("Suite complete: \(suiteResult.passedTests)/\(suiteResult.totalTests) passed")

        return suiteResult
    }

    /// Run test cases directly (without suite wrapper)
    func runTests(_ testCases: [KBAudioTestCase]) async throws -> [KBAudioTestResult] {
        let suite = KBAudioTestSuite(
            name: "Ad-hoc Tests",
            testCases: testCases
        )

        let result = try await runSuite(suite)
        return result.results
    }

    // MARK: - Cancellation

    /// Cancel the current test execution
    func cancel() {
        isCancelled = true
        logger.info("Cancellation requested")
    }

    /// Check if harness is currently running
    var running: Bool {
        isRunning
    }

    // MARK: - Private Helpers

    private func getCurrentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Double(info.resident_size) / 1_000_000.0 : 0
    }

    private func getThermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - Convenience Extensions

extension KBAudioTestHarness {
    /// Quick test with a simple question/answer pair
    func quickTest(
        question: String,
        answer: String,
        answerType: KBAnswerType = .text
    ) async throws -> KBAudioTestResult {
        let testCase = KBAudioTestCase.simple(
            questionText: question,
            expectedAnswer: answer,
            answerType: answerType
        )
        return try await runTest(testCase)
    }

    /// Run sample tests for verification (simple answers only)
    #if DEBUG
    func runSampleTests() async throws -> KBAudioTestSuiteResult {
        return try await runSuite(KBAudioTestCase.sampleSuite)
    }

    /// Run complex tests with sentence-length answers requiring semantic evaluation
    func runComplexTests() async throws -> KBAudioTestSuiteResult {
        return try await runSuite(KBAudioTestCase.complexSuite)
    }

    /// Run full test suite (simple + complex)
    func runFullTests() async throws -> KBAudioTestSuiteResult {
        return try await runSuite(KBAudioTestCase.fullSuite)
    }
    #endif
}

// MARK: - Errors

/// Errors from the audio test harness
enum KBAudioTestHarnessError: Error, LocalizedError {
    case alreadyRunning
    case cancelled
    case noSTTService
    case testFailed(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Test harness is already running"
        case .cancelled:
            return "Test was cancelled"
        case .noSTTService:
            return "No STT service configured"
        case .testFailed(let message):
            return "Test failed: \(message)"
        }
    }
}
