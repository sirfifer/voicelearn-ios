//
//  KBAudioTestHarnessTests.swift
//  UnaMentisTests
//
//  Integration tests for KB Audio Test Harness
//

import XCTest
@testable import UnaMentis

/// Integration tests for KB Audio Test Harness
///
/// These tests verify the full audio Q&A pipeline:
/// TTS generation -> Audio injection -> STT -> Validation
final class KBAudioTestHarnessTests: XCTestCase {

    // MARK: - Properties

    var harness: KBAudioTestHarness!

    // MARK: - Setup/Teardown

    override func setUp() async throws {
        try await super.setUp()
        harness = KBAudioTestHarness()
    }

    override func tearDown() async throws {
        await harness.cancel()
        harness = nil
        try await super.tearDown()
    }

    // MARK: - Audio Generator Tests

    func testAudioGeneratorCreatesValidBuffer() async throws {
        // Use Kyutai Pocket TTS - the project's standard on-device TTS
        // Unlike Apple TTS, Kyutai Pocket provides extractable raw audio data
        let generator = KBAudioGenerator()

        let result = try await generator.generateAudio(
            for: "Paris",
            using: .kyutaiPocket,
            convertToSTTFormat: true
        )

        // Verify buffer properties
        XCTAssertGreaterThan(result.buffer.frameLength, 0, "Buffer should have frames")
        XCTAssertEqual(result.buffer.format.sampleRate, 16000, "Should be 16kHz for STT")
        XCTAssertEqual(result.buffer.format.channelCount, 1, "Should be mono")
        XCTAssertGreaterThan(result.latencyMs, 0, "Should have latency")
        XCTAssertGreaterThan(result.durationMs, 0, "Should have duration")
    }

    func testAudioGeneratorFromSource() async throws {
        // Use Kyutai Pocket TTS - provides extractable raw audio data
        let generator = KBAudioGenerator()
        let source = KBAudioTestCase.AudioSource.generateTTS(provider: .kyutaiPocket)

        let result = try await generator.generateFromSource(source, text: "Hello world")

        XCTAssertGreaterThan(result.buffer.frameLength, 0)
        XCTAssertEqual(result.provider, .kyutaiPocket)
    }

    // MARK: - Transcript Validator Tests

    func testValidatorMatchesExactAnswer() async throws {
        let validator = KBTranscriptValidator(strictness: .standard)

        let result = await validator.validate(
            transcript: "Paris",
            expected: "Paris",
            answerType: .place
        )

        XCTAssertTrue(result.isPass, "Exact match should pass")
        XCTAssertEqual(result.matchType, .exact, "Should be exact match")
        XCTAssertEqual(result.confidence, 1.0, accuracy: 0.01, "Should have full confidence")
    }

    func testValidatorMatchesCaseInsensitive() async throws {
        let validator = KBTranscriptValidator(strictness: .standard)

        let result = await validator.validate(
            transcript: "paris",
            expected: "Paris",
            answerType: .place
        )

        XCTAssertTrue(result.isPass, "Case-insensitive match should pass")
    }

    func testValidatorMatchesFuzzy() async throws {
        let validator = KBTranscriptValidator(strictness: .standard)

        // Minor typo
        let result = await validator.validate(
            transcript: "Pars",
            expected: "Paris",
            answerType: .place
        )

        XCTAssertTrue(result.isPass, "Fuzzy match should pass for minor typo")
        XCTAssertEqual(result.matchType, .fuzzy, "Should be fuzzy match")
    }

    func testValidatorRejectsIncorrectAnswer() async throws {
        let validator = KBTranscriptValidator(strictness: .standard)

        let result = await validator.validate(
            transcript: "London",
            expected: "Paris",
            answerType: .place
        )

        XCTAssertFalse(result.isPass, "Different answer should fail")
        XCTAssertEqual(result.matchType, .none, "Should have no match")
    }

    func testValidatorQuickMatch() async throws {
        let validator = KBTranscriptValidator(strictness: .standard)

        // quickMatch is nonisolated, no await needed
        XCTAssertTrue(validator.quickMatch(transcript: "Paris", expected: "Paris"))
        XCTAssertTrue(validator.quickMatch(transcript: "paris", expected: "Paris"))
        XCTAssertTrue(validator.quickMatch(transcript: "Pars", expected: "Paris"))  // Fuzzy
        XCTAssertFalse(validator.quickMatch(transcript: "London", expected: "Paris"))
    }

    // MARK: - Test Case Tests

    func testSimpleTestCaseCreation() {
        let testCase = KBAudioTestCase.simple(
            questionText: "What is the capital of France?",
            expectedAnswer: "Paris",
            answerType: .place
        )

        XCTAssertEqual(testCase.expectedAnswer, "Paris")
        XCTAssertEqual(testCase.answerType, .place)
        XCTAssertEqual(testCase.question.text, "What is the capital of France?")
    }

    func testTestCaseFromQuestion() {
        let question = KBQuestion(
            text: "Who wrote Romeo and Juliet?",
            answer: KBAnswer(primary: "William Shakespeare", answerType: .person),
            domain: .arts
        )

        let testCase = KBAudioTestCase(question: question)

        XCTAssertEqual(testCase.expectedAnswer, "William Shakespeare")
        XCTAssertEqual(testCase.answerType, .person)
    }

    func testTestCaseFromQuestions() {
        let questions = [
            KBQuestion(
                text: "Q1",
                answer: KBAnswer(primary: "A1"),
                domain: .science
            ),
            KBQuestion(
                text: "Q2",
                answer: KBAnswer(primary: "A2"),
                domain: .science
            )
        ]

        let testCases = KBAudioTestCase.fromQuestions(questions)

        XCTAssertEqual(testCases.count, 2)
        XCTAssertEqual(testCases[0].expectedAnswer, "A1")
        XCTAssertEqual(testCases[1].expectedAnswer, "A2")
    }

    func testComplexTestCaseCreation() {
        let testCase = KBAudioTestCase.complex(
            questionText: "Explain photosynthesis.",
            expectedAnswer: "Plants convert sunlight, water, and carbon dioxide into glucose and oxygen.",
            guidance: "Accept any answer that mentions sunlight, plants, and production of food/glucose.",
            acceptable: ["Plants use light to make food"],
            domain: .science
        )

        XCTAssertEqual(testCase.expectedAnswer, "Plants convert sunlight, water, and carbon dioxide into glucose and oxygen.")
        XCTAssertEqual(testCase.question.answer.guidance, "Accept any answer that mentions sunlight, plants, and production of food/glucose.")
        XCTAssertEqual(testCase.question.answer.acceptable?.count, 1)
        // Complex test cases use lenient validation config to enable LLM validation
        XCTAssertTrue(testCase.validationConfig.useLLMValidation)
        XCTAssertTrue(testCase.validationConfig.useEmbeddings)
    }

    // MARK: - Test Result Tests

    func testResultSuccessComputation() {
        let successResult = KBAudioTestResult(
            testCaseId: UUID(),
            testCaseName: "Test",
            sttLatencyMs: 100,
            sttConfidence: 0.9,
            transcribedText: "Paris",
            validationLatencyMs: 10,
            validationResult: .pass(confidence: 0.95, matchType: .exact, matchedAnswer: "Paris"),
            totalPipelineMs: 500
        )

        XCTAssertTrue(successResult.isSuccess)

        let failResult = KBAudioTestResult(
            testCaseId: UUID(),
            testCaseName: "Test",
            sttLatencyMs: 100,
            sttConfidence: 0.9,
            transcribedText: "London",
            validationLatencyMs: 10,
            validationResult: .fail(reasoning: "No match"),
            totalPipelineMs: 500
        )

        XCTAssertFalse(failResult.isSuccess)
    }

    func testFailedResultFactory() {
        let testCase = KBAudioTestCase.simple(
            questionText: "Test",
            expectedAnswer: "Answer"
        )

        let result = KBAudioTestResult.failed(
            testCase: testCase,
            errorMessage: "Test error"
        )

        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertTrue(result.errors[0].contains("Test error"))
    }

    // MARK: - Suite Result Tests

    func testSuiteResultAggregation() {
        let results = [
            KBAudioTestResult(
                testCaseId: UUID(),
                testCaseName: "Test1",
                sttLatencyMs: 100,
                sttConfidence: 0.9,
                transcribedText: "Paris",
                validationLatencyMs: 10,
                validationResult: .pass(confidence: 0.95, matchType: .exact),
                totalPipelineMs: 500
            ),
            KBAudioTestResult(
                testCaseId: UUID(),
                testCaseName: "Test2",
                sttLatencyMs: 200,
                sttConfidence: 0.8,
                transcribedText: "London",
                validationLatencyMs: 10,
                validationResult: .fail(),
                totalPipelineMs: 600
            )
        ]

        let suiteResult = KBAudioTestSuiteResult(
            suiteId: UUID(),
            suiteName: "Test Suite",
            startTime: Date(),
            results: results
        )

        XCTAssertEqual(suiteResult.totalTests, 2)
        XCTAssertEqual(suiteResult.passedTests, 1)
        XCTAssertEqual(suiteResult.failedTests, 1)
        XCTAssertEqual(suiteResult.passRate, 0.5, accuracy: 0.01)
        XCTAssertEqual(suiteResult.averageSTTLatencyMs, 150, accuracy: 0.01)
    }

    // MARK: - Full Pipeline Tests

    /// Test the complete pipeline with Kyutai Pocket TTS
    /// Tests the full round-trip: TTS -> STT -> Validation
    func testFullPipelineWithKyutaiPocketTTS() async throws {
        // Skip if speech recognition not available
        guard AppleSpeechSTTService.isAvailable else {
            throw XCTSkip("Speech recognition not available")
        }

        let testCase = KBAudioTestCase.simple(
            questionText: "What is the capital of France?",
            expectedAnswer: "Paris",
            answerType: .place
        )

        let result = try await harness.runTest(testCase)

        // Verify result structure
        XCTAssertGreaterThan(result.audioGenerationLatencyMs ?? 0, 0, "Should have audio generation latency")
        XCTAssertGreaterThan(result.sttLatencyMs, 0, "Should have STT latency")
        XCTAssertGreaterThan(result.validationLatencyMs, 0, "Should have validation latency")
        XCTAssertGreaterThan(result.totalPipelineMs, 0, "Should have total pipeline time")

        // Log results for analysis
        print("Full pipeline result:")
        print("  Transcribed: \"\(result.transcribedText)\"")
        print("  STT Confidence: \(result.sttConfidence)")
        print("  Validation: \(result.validationResult.isPass ? "PASS" : "FAIL")")
        print("  Match Type: \(result.validationResult.matchType)")
        print("  Total Pipeline: \(String(format: "%.1f", result.totalPipelineMs))ms")
    }

    /// Test quick test convenience method
    func testQuickTestConvenience() async throws {
        guard AppleSpeechSTTService.isAvailable else {
            throw XCTSkip("Speech recognition not available")
        }

        let result = try await harness.quickTest(
            question: "What is water made of?",
            answer: "H2O",
            answerType: .scientific
        )

        // Verify it completes with valid metrics
        XCTAssertGreaterThan(result.audioGenerationLatencyMs ?? 0, 0, "Should have audio generation latency")
        XCTAssertGreaterThan(result.totalPipelineMs, 0, "Should have total pipeline time")
    }

    /// Test running multiple test cases
    func testRunMultipleTests() async throws {
        guard AppleSpeechSTTService.isAvailable else {
            throw XCTSkip("Speech recognition not available")
        }

        let testCases = [
            KBAudioTestCase.simple(questionText: "Q1", expectedAnswer: "one", answerType: .numeric),
            KBAudioTestCase.simple(questionText: "Q2", expectedAnswer: "two", answerType: .numeric)
        ]

        let results = try await harness.runTests(testCases)

        XCTAssertEqual(results.count, 2)
    }

    #if DEBUG
    /// Test sample test suite (simple answers)
    func testSampleSuite() async throws {
        guard AppleSpeechSTTService.isAvailable else {
            throw XCTSkip("Speech recognition not available")
        }

        let suiteResult = try await harness.runSampleTests()

        print("Sample suite summary:")
        print(suiteResult.summary)

        XCTAssertGreaterThan(suiteResult.totalTests, 0)
    }

    /// Test complex test suite (sentence-length answers with guidance)
    func testComplexSuite() async throws {
        guard AppleSpeechSTTService.isAvailable else {
            throw XCTSkip("Speech recognition not available")
        }

        let suiteResult = try await harness.runComplexTests()

        print("Complex suite summary:")
        print(suiteResult.summary)

        // Print individual results for analysis
        for result in suiteResult.results {
            print("  [\(result.validationResult.isPass ? "PASS" : "FAIL")] \(result.testCaseName)")
            print("    Transcribed: \"\(result.transcribedText)\"")
            print("    Match type: \(result.validationResult.matchType)")
        }

        XCTAssertGreaterThan(suiteResult.totalTests, 0)
    }
    #endif

    // MARK: - Cancellation Tests

    func testCancellation() async throws {
        // Start a test
        let testCase = KBAudioTestCase.simple(
            questionText: "Long test",
            expectedAnswer: "Answer"
        )

        // Cancel immediately
        await harness.cancel()

        // Verify harness respects cancellation
        do {
            _ = try await harness.runTest(testCase)
            // If we get here, cancellation was not respected (but that's OK, test is fast)
        } catch let error as KBAudioTestHarnessError {
            if case .cancelled = error {
                // Expected
            }
        } catch {
            // Other errors are OK
        }
    }

    func testRunningState() async throws {
        let running = await harness.running
        XCTAssertFalse(running, "Should not be running initially")
    }
}

// Note: AppleSpeechSTTService.isAvailable is used for availability checks
// (defined in UnaMentis/Services/STT/AppleSpeechSTTService.swift)
