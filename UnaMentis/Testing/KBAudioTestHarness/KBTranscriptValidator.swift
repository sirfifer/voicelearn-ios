//
//  KBTranscriptValidator.swift
//  UnaMentis
//
//  Semantic validation of transcripts against expected answers
//  Wraps KBAnswerValidator for use in audio testing
//

import Foundation
import OSLog

// MARK: - Transcript Validator

/// Validates STT transcripts against expected answers using semantic matching
///
/// Uses the existing KBAnswerValidator infrastructure with its 3-tier validation:
/// - Tier 1: Rule-based (exact, acceptable, fuzzy, phonetic, n-gram, token, linguistic)
/// - Tier 2: Embeddings-based semantic similarity
/// - Tier 3: LLM-based expert validation
actor KBTranscriptValidator {
    private let logger = Logger(subsystem: "com.unamentis", category: "KBTranscriptValidator")

    // MARK: - Configuration

    /// Validation strictness level
    public enum StrictnessLevel: Sendable {
        /// Only exact and acceptable matches
        case strict

        /// Rule-based matching with fuzzy algorithms
        case standard

        /// All tiers including embeddings and LLM
        case lenient
    }

    private let strictness: StrictnessLevel

    // Tier 1 matchers
    private let phoneticMatcher: KBPhoneticMatcher
    private let ngramMatcher: KBNGramMatcher
    private let tokenMatcher: KBTokenMatcher
    private let linguisticMatcher: KBLinguisticMatcher

    // Tier 2 & 3 (optional)
    private let embeddingsService: KBEmbeddingsService?
    private let llmValidator: KBLLMValidator?

    // MARK: - Initialization

    init(
        strictness: StrictnessLevel = .standard,
        embeddingsService: KBEmbeddingsService? = nil,
        llmValidator: KBLLMValidator? = nil
    ) {
        self.strictness = strictness
        self.phoneticMatcher = KBPhoneticMatcher()
        self.ngramMatcher = KBNGramMatcher()
        self.tokenMatcher = KBTokenMatcher()
        self.linguisticMatcher = KBLinguisticMatcher()
        self.embeddingsService = embeddingsService
        self.llmValidator = llmValidator
    }

    /// Create validator from test case validation config
    init(config: KBAudioTestCase.ValidationConfig) {
        let strictness: StrictnessLevel
        if config.useLLMValidation || config.useEmbeddings {
            strictness = .lenient
        } else if config.useFuzzyMatching {
            strictness = .standard
        } else {
            strictness = .strict
        }

        self.strictness = strictness
        self.phoneticMatcher = KBPhoneticMatcher()
        self.ngramMatcher = KBNGramMatcher()
        self.tokenMatcher = KBTokenMatcher()
        self.linguisticMatcher = KBLinguisticMatcher()
        self.embeddingsService = nil
        self.llmValidator = nil
    }

    // MARK: - Public API

    /// Validate a transcript against an expected answer
    ///
    /// - Parameters:
    ///   - transcript: The STT output text
    ///   - expected: The expected correct answer
    ///   - answerType: Type of answer for specialized matching
    ///   - config: Optional validation configuration
    /// - Returns: Validation result with pass/fail and confidence
    func validate(
        transcript: String,
        expected: String,
        answerType: KBAnswerType,
        config: KBAudioTestCase.ValidationConfig? = nil
    ) async -> KBAudioTestResult.ValidationOutcome {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Create a synthetic KBQuestion for the validator
        let question = KBQuestion(
            text: "",
            answer: KBAnswer(
                primary: expected,
                answerType: answerType
            ),
            domain: .science
        )

        // Determine strictness from config if provided
        let effectiveStrictness: KBValidationStrictness
        if let config = config {
            if config.useLLMValidation || config.useEmbeddings {
                effectiveStrictness = .lenient
            } else if config.useFuzzyMatching {
                effectiveStrictness = .standard
            } else {
                effectiveStrictness = .strict
            }
        } else {
            effectiveStrictness = mapToKBStrictness(strictness)
        }

        // Create answer validator with appropriate config
        let validator = KBAnswerValidator(
            config: .init(
                fuzzyThresholdPercent: 0.25,  // Slightly more lenient for STT errors
                minimumConfidence: config?.minimumConfidence ?? 0.6,
                strictMode: effectiveStrictness == .strict
            ),
            strictness: effectiveStrictness,
            phoneticMatcher: phoneticMatcher,
            ngramMatcher: ngramMatcher,
            tokenMatcher: tokenMatcher,
            linguisticMatcher: linguisticMatcher,
            embeddingsService: embeddingsService,
            llmValidator: llmValidator
        )

        // Validate
        let result = await validator.validate(userAnswer: transcript, question: question)

        let latencyMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        logger.info("Validation: \"\(transcript)\" vs \"\(expected)\" -> \(result.isCorrect ? "PASS" : "FAIL") (\(result.matchType.rawValue), \(String(format: "%.2f", result.confidence)))")

        return KBAudioTestResult.ValidationOutcome(
            isPass: result.isCorrect,
            confidence: result.confidence,
            matchType: result.matchType,
            matchedAnswer: result.matchedAnswer,
            reasoning: "Match type: \(result.matchType.rawValue)"
        )
    }

    /// Validate transcript using a full KBQuestion
    func validate(
        transcript: String,
        question: KBQuestion,
        config: KBAudioTestCase.ValidationConfig? = nil
    ) async -> KBAudioTestResult.ValidationOutcome {
        return await validate(
            transcript: transcript,
            expected: question.answer.primary,
            answerType: question.answer.answerType,
            config: config
        )
    }

    /// Quick check if transcript matches expected (simple exact/fuzzy)
    /// - Note: This is nonisolated because it only uses pure functions
    nonisolated func quickMatch(
        transcript: String,
        expected: String,
        answerType: KBAnswerType = .text
    ) -> Bool {
        let normalizedTranscript = normalizeText(transcript, for: answerType)
        let normalizedExpected = normalizeText(expected, for: answerType)

        // Exact match
        if normalizedTranscript == normalizedExpected {
            return true
        }

        // Fuzzy match (Levenshtein)
        let distance = levenshteinDistance(normalizedTranscript, normalizedExpected)
        let threshold = max(2, Int(Double(normalizedExpected.count) * 0.25))

        return distance <= threshold
    }

    // MARK: - Private Helpers

    private func mapToKBStrictness(_ level: StrictnessLevel) -> KBValidationStrictness {
        switch level {
        case .strict: return .strict
        case .standard: return .standard
        case .lenient: return .lenient
        }
    }

}

// MARK: - Pure Helper Functions (nonisolated)

/// Normalize text for comparison (pure function, not actor-isolated)
private func normalizeText(_ text: String, for type: KBAnswerType) -> String {
    var normalized = text
        .lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)

    // Remove common punctuation
    normalized = normalized.replacingOccurrences(
        of: "[.,!?;:'\"()-]",
        with: "",
        options: .regularExpression
    )

    // Collapse whitespace
    normalized = normalized.replacingOccurrences(
        of: "\\s+",
        with: " ",
        options: .regularExpression
    )

    // Remove articles for certain types
    if type == .title || type == .place {
        let articles = ["the ", "a ", "an "]
        for article in articles {
            if normalized.hasPrefix(article) {
                normalized = String(normalized.dropFirst(article.count))
            }
        }
    }

    return normalized.trimmingCharacters(in: .whitespaces)
}

/// Calculate Levenshtein distance (pure function, not actor-isolated)
private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
    let m = s1.count
    let n = s2.count

    if m == 0 { return n }
    if n == 0 { return m }

    let (shorter, longer) = m < n ? (s1, s2) : (s2, s1)
    let shortLen = shorter.count
    let longLen = longer.count

    let shortArray = Array(shorter)
    let longArray = Array(longer)

    var previousRow = [Int](0...shortLen)
    var currentRow = [Int](repeating: 0, count: shortLen + 1)

    for i in 1...longLen {
        currentRow[0] = i

        for j in 1...shortLen {
            let cost = longArray[i - 1] == shortArray[j - 1] ? 0 : 1
            currentRow[j] = min(
                previousRow[j] + 1,
                currentRow[j - 1] + 1,
                previousRow[j - 1] + cost
            )
        }

        swap(&previousRow, &currentRow)
    }

    return previousRow[shortLen]
}

// Note: Uses KBValidationStrictness from KBRegionalConfig.swift
