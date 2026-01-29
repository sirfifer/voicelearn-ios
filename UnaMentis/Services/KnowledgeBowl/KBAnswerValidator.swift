//
//  KBAnswerValidator.swift
//  UnaMentis
//
//  Answer validation with rule-based matching for Knowledge Bowl
//

import Foundation
import OSLog

// MARK: - Answer Validator

/// Validates user answers against correct answers using various matching strategies
actor KBAnswerValidator {
    private let logger = Logger(subsystem: "com.unamentis", category: "KBAnswerValidator")

    // MARK: - Configuration

    /// Configuration for answer validation
    struct Config: Sendable {
        /// Maximum Levenshtein distance for fuzzy matching (as percentage of answer length)
        var fuzzyThresholdPercent: Double = 0.20 // Allow ~20% error

        /// Minimum confidence for a match to be considered correct
        var minimumConfidence: Float = 0.6

        /// Whether to use strict mode (exact match only)
        var strictMode: Bool = false

        static let standard = Config()
        static let strict = Config(strictMode: true)
        static let lenient = Config(fuzzyThresholdPercent: 0.30, minimumConfidence: 0.5)
    }

    private let config: Config
    private let strictness: KBValidationStrictness

    // MARK: - Tier 1 Algorithms

    private let phoneticMatcher: KBPhoneticMatcher?
    private let ngramMatcher: KBNGramMatcher?
    private let tokenMatcher: KBTokenMatcher?
    private let synonymMatcher: KBSynonymMatcher?
    private let linguisticMatcher: KBLinguisticMatcher?

    // MARK: - Tier 2 & 3 Models

    private let embeddingsService: KBEmbeddingsService?
    private let llmValidator: KBLLMValidator?
    private let featureFlags: KBFeatureFlags?

    // MARK: - Initialization

    init(
        config: Config = .standard,
        strictness: KBValidationStrictness = .standard,
        phoneticMatcher: KBPhoneticMatcher? = KBPhoneticMatcher(),
        ngramMatcher: KBNGramMatcher? = KBNGramMatcher(),
        tokenMatcher: KBTokenMatcher? = KBTokenMatcher(),
        synonymMatcher: KBSynonymMatcher? = KBSynonymMatcher(),
        linguisticMatcher: KBLinguisticMatcher? = KBLinguisticMatcher(),
        embeddingsService: KBEmbeddingsService? = nil,
        llmValidator: KBLLMValidator? = nil,
        featureFlags: KBFeatureFlags? = nil
    ) {
        self.config = config
        self.strictness = strictness
        self.phoneticMatcher = phoneticMatcher
        self.ngramMatcher = ngramMatcher
        self.tokenMatcher = tokenMatcher
        self.synonymMatcher = synonymMatcher
        self.linguisticMatcher = linguisticMatcher
        self.embeddingsService = embeddingsService
        self.llmValidator = llmValidator
        self.featureFlags = featureFlags
    }

    // MARK: - Public API

    /// Validate a user's answer against the question's correct answer
    nonisolated func validate(userAnswer: String, question: KBQuestion) async -> KBValidationResult {
        let answer = question.answer

        // Normalize the user answer
        let normalizedUser = normalize(userAnswer, for: answer.answerType)

        // 1. Check exact primary match
        let normalizedPrimary = normalize(answer.primary, for: answer.answerType)
        if normalizedUser == normalizedPrimary {
            logger.debug("Exact match for: \(userAnswer)")
            return KBValidationResult(
                isCorrect: true,
                confidence: 1.0,
                matchType: .exact,
                matchedAnswer: answer.primary
            )
        }

        // 2. Check acceptable alternatives
        if let acceptable = answer.acceptable {
            for alt in acceptable {
                let normalizedAlt = normalize(alt, for: answer.answerType)
                if normalizedUser == normalizedAlt {
                    logger.debug("Acceptable match for: \(userAnswer) -> \(alt)")
                    return KBValidationResult(
                        isCorrect: true,
                        confidence: 1.0,
                        matchType: .acceptable,
                        matchedAnswer: alt
                    )
                }
            }
        }

        // 3. Fuzzy matching (if not in strict mode)
        if !config.strictMode {
            let fuzzyResult = await fuzzyMatch(normalizedUser, against: answer, question: question)
            if fuzzyResult.isCorrect {
                return fuzzyResult
            }
        }

        // No match found
        logger.debug("No match for: \(userAnswer)")
        return KBValidationResult(
            isCorrect: false,
            confidence: 0,
            matchType: .none,
            matchedAnswer: nil
        )
    }

    /// Validate an MCQ selection
    nonisolated func validateMCQ(selectedIndex: Int, question: KBQuestion) -> KBValidationResult {
        guard let options = question.mcqOptions,
              selectedIndex >= 0 && selectedIndex < options.count else {
            return KBValidationResult(
                isCorrect: false,
                confidence: 0,
                matchType: .none,
                matchedAnswer: nil
            )
        }

        let selectedOption = options[selectedIndex]
        let isCorrect = normalize(selectedOption, for: .text) ==
            normalize(question.answer.primary, for: .text)

        return KBValidationResult(
            isCorrect: isCorrect,
            confidence: isCorrect ? 1.0 : 0,
            matchType: isCorrect ? .exact : .none,
            matchedAnswer: isCorrect ? selectedOption : nil
        )
    }

    // MARK: - Normalization

    /// Normalize text based on answer type
    nonisolated private func normalize(_ text: String, for type: KBAnswerType) -> String {
        var normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch type {
        case .text:
            normalized = normalizeText(normalized)

        case .person:
            normalized = normalizePerson(normalized)

        case .place:
            normalized = normalizePlace(normalized)

        case .numeric:
            normalized = normalizeNumber(normalized)

        case .date:
            normalized = normalizeDate(normalized)

        case .title:
            normalized = normalizeTitle(normalized)

        case .scientific:
            normalized = normalizeScientific(normalized)

        case .multipleChoice:
            // Just extract the letter
            normalized = normalized.filter { $0.isLetter }.prefix(1).lowercased()
        }

        return normalized
    }

    nonisolated private func normalizeText(_ text: String) -> String {
        var result = text
        // Remove common punctuation
        result = result.replacingOccurrences(of: "[.,!?;:'\"()-]", with: "", options: .regularExpression)
        // Collapse multiple spaces
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        // Remove articles
        result = removeArticles(result)
        return result.trimmingCharacters(in: .whitespaces)
    }

    nonisolated private func normalizePerson(_ text: String) -> String {
        var result = normalizeText(text)
        // Remove titles
        let titles = ["dr", "mr", "mrs", "ms", "miss", "prof", "professor", "sir", "dame", "lord", "lady"]
        for title in titles {
            result = result.replacingOccurrences(of: "^\(title)\\.?\\s+", with: "", options: .regularExpression)
        }
        // Handle "First Last" vs "Last, First"
        if result.contains(",") {
            let parts = result.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                result = "\(parts[1]) \(parts[0])"
            }
        }
        return result
    }

    nonisolated private func normalizePlace(_ text: String) -> String {
        var result = normalizeText(text)
        // Handle common abbreviations
        let abbreviations: [String: String] = [
            "usa": "united states of america",
            "us": "united states",
            "uk": "united kingdom",
            "uae": "united arab emirates",
            "mt": "mount",
            "st": "saint",
            "ft": "fort"
        ]
        for (abbr, full) in abbreviations {
            if result == abbr {
                result = full
            }
        }
        return result
    }

    nonisolated private func normalizeNumber(_ text: String) -> String {
        var result = normalizeText(text)

        // Parse written numbers
        let wordNumbers: [String: String] = [
            "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
            "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
            "ten": "10", "eleven": "11", "twelve": "12", "thirteen": "13",
            "fourteen": "14", "fifteen": "15", "sixteen": "16", "seventeen": "17",
            "eighteen": "18", "nineteen": "19", "twenty": "20", "thirty": "30",
            "forty": "40", "fifty": "50", "sixty": "60", "seventy": "70",
            "eighty": "80", "ninety": "90", "hundred": "100", "thousand": "1000",
            "million": "1000000", "billion": "1000000000"
        ]

        for (word, num) in wordNumbers {
            if result == word {
                return num
            }
        }

        // Remove commas from numbers
        result = result.replacingOccurrences(of: ",", with: "")

        return result
    }

    nonisolated private func normalizeDate(_ text: String) -> String {
        // Basic date normalization - could be expanded
        var result = normalizeText(text)
        // Handle month names
        let months: [String: String] = [
            "january": "1", "jan": "1", "february": "2", "feb": "2",
            "march": "3", "mar": "3", "april": "4", "apr": "4",
            "may": "5", "june": "6", "jun": "6", "july": "7", "jul": "7",
            "august": "8", "aug": "8", "september": "9", "sep": "9", "sept": "9",
            "october": "10", "oct": "10", "november": "11", "nov": "11",
            "december": "12", "dec": "12"
        ]
        for (name, num) in months {
            result = result.replacingOccurrences(of: name, with: num)
        }
        return result
    }

    nonisolated private func normalizeTitle(_ text: String) -> String {
        var result = normalizeText(text)
        // Remove leading "the"
        result = result.replacingOccurrences(of: "^the\\s+", with: "", options: .regularExpression)
        // Remove subtitle after colon
        if let colonIndex = result.firstIndex(of: ":") {
            result = String(result[..<colonIndex])
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    nonisolated private func normalizeScientific(_ text: String) -> String {
        var result = text.lowercased()
        // Keep some special characters for formulas
        result = result.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        return result
    }

    nonisolated private func removeArticles(_ text: String) -> String {
        var result = text
        let articles = ["the ", "a ", "an "]
        for article in articles {
            if result.hasPrefix(article) {
                result = String(result.dropFirst(article.count))
            }
        }
        return result
    }

    // MARK: - Fuzzy Matching

    nonisolated private func fuzzyMatch(_ userAnswer: String, against answer: KBAnswer, question: KBQuestion) async -> KBValidationResult {
        let candidates = [answer.primary] + (answer.acceptable ?? [])

        // 1. Levenshtein fuzzy matching (baseline)
        for candidate in candidates {
            let normalizedCandidate = normalize(candidate, for: answer.answerType)
            let distance = levenshteinDistance(userAnswer, normalizedCandidate)
            let candidateThreshold = max(2, Int(Double(candidate.count) * config.fuzzyThresholdPercent))

            if distance <= candidateThreshold {
                let confidence = 1.0 - (Float(distance) / Float(max(1, candidate.count)))
                if confidence >= config.minimumConfidence {
                    logger.debug("Levenshtein match (distance \(distance)): \(userAnswer) -> \(candidate)")
                    return KBValidationResult(
                        isCorrect: true,
                        confidence: confidence,
                        matchType: .fuzzy,
                        matchedAnswer: candidate
                    )
                }
            }
        }

        // Enhanced algorithms (if strictness >= .standard)
        guard strictness >= .standard else {
            return KBValidationResult(isCorrect: false, confidence: 0, matchType: .none, matchedAnswer: nil)
        }

        // 2. Synonym check
        if let synonymMatcher = synonymMatcher {
            for candidate in candidates {
                if synonymMatcher.areSynonyms(userAnswer, candidate, for: answer.answerType) {
                    logger.debug("Synonym match: \(userAnswer) -> \(candidate)")
                    return KBValidationResult(
                        isCorrect: true,
                        confidence: 0.95,
                        matchType: .fuzzy,
                        matchedAnswer: candidate
                    )
                }
            }
        }

        // 3. Phonetic check (Double Metaphone)
        if let phoneticMatcher = phoneticMatcher {
            for candidate in candidates {
                if phoneticMatcher.arePhoneticMatch(userAnswer, candidate) {
                    logger.debug("Phonetic match: \(userAnswer) -> \(candidate)")
                    return KBValidationResult(
                        isCorrect: true,
                        confidence: 0.90,
                        matchType: .fuzzy,
                        matchedAnswer: candidate
                    )
                }
            }
        }

        // 4. N-gram similarity check
        if let ngramMatcher = ngramMatcher {
            for candidate in candidates {
                let score = ngramMatcher.nGramScore(userAnswer, candidate)
                if score >= 0.80 {
                    logger.debug("N-gram match (score \(score)): \(userAnswer) -> \(candidate)")
                    return KBValidationResult(
                        isCorrect: true,
                        confidence: score,
                        matchType: .fuzzy,
                        matchedAnswer: candidate
                    )
                }
            }
        }

        // 5. Token-based similarity
        if let tokenMatcher = tokenMatcher {
            for candidate in candidates {
                let score = tokenMatcher.tokenScore(userAnswer, candidate)
                if score >= 0.80 {
                    logger.debug("Token match (score \(score)): \(userAnswer) -> \(candidate)")
                    return KBValidationResult(
                        isCorrect: true,
                        confidence: score,
                        matchType: .fuzzy,
                        matchedAnswer: candidate
                    )
                }
            }
        }

        // 6. Linguistic matching (lemmatization)
        if let linguisticMatcher = linguisticMatcher {
            for candidate in candidates {
                if linguisticMatcher.areLemmasEquivalent(userAnswer, candidate) {
                    logger.debug("Linguistic match: \(userAnswer) -> \(candidate)")
                    return KBValidationResult(
                        isCorrect: true,
                        confidence: 0.85,
                        matchType: .fuzzy,
                        matchedAnswer: candidate
                    )
                }
            }
        }

        // Semantic algorithms (if strictness >= .lenient)
        guard strictness >= .lenient else {
            return KBValidationResult(isCorrect: false, confidence: 0, matchType: .none, matchedAnswer: nil)
        }

        // 7. Embeddings-based semantic matching (Tier 2)
        if let embeddingsService = embeddingsService,
           await embeddingsService.currentState() == .loaded {
            do {
                for candidate in candidates {
                    let similarity = try await embeddingsService.similarity(userAnswer, candidate)
                    if similarity >= 0.85 {
                        logger.debug("Embeddings match (similarity \(similarity)): \(userAnswer) -> \(candidate)")
                        return KBValidationResult(
                            isCorrect: true,
                            confidence: similarity,
                            matchType: .ai,
                            matchedAnswer: candidate
                        )
                    }
                }
            } catch {
                logger.error("Embeddings inference failed: \(error.localizedDescription)")
                // Fall through to next tier
            }
        }

        // 8. LLM validation (Tier 3)
        // LLM validator now auto-loads, so check if models are available (not in error/notAvailable state)
        let llmState = await llmValidator?.currentState()
        let llmAvailable = llmState == .available || llmState == .loaded || llmState == .loading
        if let llmValidator = llmValidator,
           let featureFlags = featureFlags,
           llmAvailable,
           await featureFlags.isFeatureEnabled(.llmValidation) {
            do {
                // LLM validates against primary answer with question context and guidance
                let isCorrect = try await llmValidator.validate(
                    userAnswer: userAnswer,
                    correctAnswer: answer.primary,
                    question: question.text,
                    answerType: answer.answerType,
                    guidance: answer.guidance
                )

                if isCorrect {
                    logger.debug("LLM validation match: \(userAnswer) -> \(answer.primary)")
                    return KBValidationResult(
                        isCorrect: true,
                        confidence: 0.98,
                        matchType: .ai,
                        matchedAnswer: answer.primary
                    )
                }
            } catch {
                logger.error("LLM validation failed: \(error.localizedDescription)")
                // Fall through to incorrect
            }
        }

        return KBValidationResult(isCorrect: false, confidence: 0, matchType: .none, matchedAnswer: nil)
    }

    /// Calculate Levenshtein distance between two strings
    /// Optimized to use O(min(m,n)) space instead of O(m*n)
    nonisolated private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count

        if m == 0 { return n }
        if n == 0 { return m }

        // Ensure s2 is the shorter string for space optimization
        let (shorter, longer) = m < n ? (s1, s2) : (s2, s1)
        let shortLen = shorter.count
        let longLen = longer.count

        let shortArray = Array(shorter)
        let longArray = Array(longer)

        // Only keep two rows: previous and current
        var previousRow = [Int](0...shortLen)
        var currentRow = [Int](repeating: 0, count: shortLen + 1)

        for i in 1...longLen {
            currentRow[0] = i

            for j in 1...shortLen {
                let cost = longArray[i - 1] == shortArray[j - 1] ? 0 : 1
                currentRow[j] = min(
                    previousRow[j] + 1,        // deletion
                    currentRow[j - 1] + 1,     // insertion
                    previousRow[j - 1] + cost  // substitution
                )
            }

            swap(&previousRow, &currentRow)
        }

        return previousRow[shortLen]
    }
}

// MARK: - Validation Result

/// Result of answer validation
struct KBValidationResult: Sendable {
    /// Whether the answer was correct
    let isCorrect: Bool

    /// Confidence level of the match (0.0-1.0)
    let confidence: Float

    /// How the answer was matched
    let matchType: KBMatchType

    /// The answer that was matched against (if correct)
    let matchedAnswer: String?

    /// Points earned (can be modified by caller based on timing, rebound, etc.)
    var pointsEarned: Int {
        isCorrect ? 1 : 0
    }
}

// MARK: - Preview Support

#if DEBUG
extension KBAnswerValidator {
    /// Create a validator for previews
    static func preview() -> KBAnswerValidator {
        KBAnswerValidator()
    }
}
#endif
