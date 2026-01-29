//
//  KBAudioTestResult.swift
//  UnaMentis
//
//  Result model for KB audio Q&A pipeline tests
//

import Foundation

// MARK: - Audio Test Result

/// Result from a single KB audio test execution
struct KBAudioTestResult: Codable, Sendable, Identifiable {
    let id: UUID
    let testCaseId: UUID
    let testCaseName: String
    let timestamp: Date

    // MARK: - Pipeline Outputs

    /// Audio generation latency (TTS or file loading) in milliseconds
    let audioGenerationLatencyMs: Double?

    /// Duration of the generated audio in milliseconds
    let audioDurationMs: Double?

    /// STT processing latency in milliseconds
    let sttLatencyMs: Double

    /// Confidence from STT (0.0-1.0)
    let sttConfidence: Float

    /// Raw transcript from STT
    let transcribedText: String

    /// Validation processing latency in milliseconds
    let validationLatencyMs: Double

    /// Detailed validation outcome
    let validationResult: ValidationOutcome

    // MARK: - Aggregate Metrics

    /// Total pipeline latency (audio generation + STT + validation)
    let totalPipelineMs: Double

    /// Peak memory usage during test (MB)
    let peakMemoryMB: Double?

    /// Thermal state during test
    let thermalState: String?

    // MARK: - Errors

    /// Errors encountered during test execution
    let errors: [String]

    /// Whether the test passed
    var isSuccess: Bool {
        errors.isEmpty && validationResult.isPass
    }

    init(
        id: UUID = UUID(),
        testCaseId: UUID,
        testCaseName: String,
        timestamp: Date = Date(),
        audioGenerationLatencyMs: Double? = nil,
        audioDurationMs: Double? = nil,
        sttLatencyMs: Double,
        sttConfidence: Float,
        transcribedText: String,
        validationLatencyMs: Double,
        validationResult: ValidationOutcome,
        totalPipelineMs: Double,
        peakMemoryMB: Double? = nil,
        thermalState: String? = nil,
        errors: [String] = []
    ) {
        self.id = id
        self.testCaseId = testCaseId
        self.testCaseName = testCaseName
        self.timestamp = timestamp
        self.audioGenerationLatencyMs = audioGenerationLatencyMs
        self.audioDurationMs = audioDurationMs
        self.sttLatencyMs = sttLatencyMs
        self.sttConfidence = sttConfidence
        self.transcribedText = transcribedText
        self.validationLatencyMs = validationLatencyMs
        self.validationResult = validationResult
        self.totalPipelineMs = totalPipelineMs
        self.peakMemoryMB = peakMemoryMB
        self.thermalState = thermalState
        self.errors = errors
    }
}

// MARK: - Validation Outcome

extension KBAudioTestResult {
    /// Detailed validation outcome
    public struct ValidationOutcome: Codable, Sendable {
        /// Whether the answer was considered correct
        let isPass: Bool

        /// Confidence of the match (0.0-1.0)
        let confidence: Float

        /// How the answer was matched
        let matchType: KBMatchType

        /// Which answer was matched (if any)
        let matchedAnswer: String?

        /// Similarity score from embeddings (if used)
        let embeddingsSimilarity: Float?

        /// LLM judgment (if used)
        let llmJudgment: Bool?

        /// Reasoning from validation (for debugging)
        let reasoning: String?

        init(
            isPass: Bool,
            confidence: Float,
            matchType: KBMatchType,
            matchedAnswer: String? = nil,
            embeddingsSimilarity: Float? = nil,
            llmJudgment: Bool? = nil,
            reasoning: String? = nil
        ) {
            self.isPass = isPass
            self.confidence = confidence
            self.matchType = matchType
            self.matchedAnswer = matchedAnswer
            self.embeddingsSimilarity = embeddingsSimilarity
            self.llmJudgment = llmJudgment
            self.reasoning = reasoning
        }

        /// Create a passing outcome
        static func pass(
            confidence: Float,
            matchType: KBMatchType,
            matchedAnswer: String? = nil
        ) -> ValidationOutcome {
            ValidationOutcome(
                isPass: true,
                confidence: confidence,
                matchType: matchType,
                matchedAnswer: matchedAnswer
            )
        }

        /// Create a failing outcome
        static func fail(reasoning: String? = nil) -> ValidationOutcome {
            ValidationOutcome(
                isPass: false,
                confidence: 0,
                matchType: .none,
                reasoning: reasoning
            )
        }
    }
}

// MARK: - Result Factory

extension KBAudioTestResult {
    /// Create a failed result with an error
    static func failed(
        testCase: KBAudioTestCase,
        error: Error
    ) -> KBAudioTestResult {
        KBAudioTestResult(
            testCaseId: testCase.id,
            testCaseName: testCase.name,
            sttLatencyMs: 0,
            sttConfidence: 0,
            transcribedText: "",
            validationLatencyMs: 0,
            validationResult: .fail(reasoning: error.localizedDescription),
            totalPipelineMs: 0,
            errors: [error.localizedDescription]
        )
    }

    /// Create a failed result with error message
    static func failed(
        testCase: KBAudioTestCase,
        errorMessage: String
    ) -> KBAudioTestResult {
        KBAudioTestResult(
            testCaseId: testCase.id,
            testCaseName: testCase.name,
            sttLatencyMs: 0,
            sttConfidence: 0,
            transcribedText: "",
            validationLatencyMs: 0,
            validationResult: .fail(reasoning: errorMessage),
            totalPipelineMs: 0,
            errors: [errorMessage]
        )
    }
}

// MARK: - Suite Result

/// Aggregated results from running a test suite
struct KBAudioTestSuiteResult: Codable, Sendable, Identifiable {
    let id: UUID
    let suiteId: UUID
    let suiteName: String
    let startTime: Date
    let endTime: Date
    let results: [KBAudioTestResult]

    // MARK: - Computed Properties

    /// Total number of tests
    var totalTests: Int { results.count }

    /// Number of passed tests
    var passedTests: Int { results.filter(\.isSuccess).count }

    /// Number of failed tests
    var failedTests: Int { results.filter { !$0.isSuccess }.count }

    /// Pass rate (0.0-1.0)
    var passRate: Double {
        guard totalTests > 0 else { return 0 }
        return Double(passedTests) / Double(totalTests)
    }

    /// Total duration in milliseconds
    var totalDurationMs: Double {
        endTime.timeIntervalSince(startTime) * 1000
    }

    /// Average pipeline latency
    var averagePipelineMs: Double {
        guard !results.isEmpty else { return 0 }
        return results.map(\.totalPipelineMs).reduce(0, +) / Double(results.count)
    }

    /// Average STT latency
    var averageSTTLatencyMs: Double {
        guard !results.isEmpty else { return 0 }
        return results.map(\.sttLatencyMs).reduce(0, +) / Double(results.count)
    }

    /// Average STT confidence
    var averageSTTConfidence: Float {
        guard !results.isEmpty else { return 0 }
        return results.map(\.sttConfidence).reduce(0, +) / Float(results.count)
    }

    /// Average validation confidence (for passed tests)
    var averageValidationConfidence: Float {
        let passed = results.filter(\.isSuccess)
        guard !passed.isEmpty else { return 0 }
        return passed.map(\.validationResult.confidence).reduce(0, +) / Float(passed.count)
    }

    init(
        id: UUID = UUID(),
        suiteId: UUID,
        suiteName: String,
        startTime: Date,
        endTime: Date = Date(),
        results: [KBAudioTestResult]
    ) {
        self.id = id
        self.suiteId = suiteId
        self.suiteName = suiteName
        self.startTime = startTime
        self.endTime = endTime
        self.results = results
    }
}

// MARK: - Result Summary

extension KBAudioTestSuiteResult {
    /// Generate a human-readable summary
    var summary: String {
        """
        Test Suite: \(suiteName)
        Duration: \(String(format: "%.1f", totalDurationMs))ms
        Results: \(passedTests)/\(totalTests) passed (\(String(format: "%.1f", passRate * 100))%)
        Avg Pipeline: \(String(format: "%.1f", averagePipelineMs))ms
        Avg STT: \(String(format: "%.1f", averageSTTLatencyMs))ms
        Avg Confidence: \(String(format: "%.2f", averageSTTConfidence))
        """
    }
}
