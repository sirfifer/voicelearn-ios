# Science Bowl Module Technical Specification

**Module ID:** `com.unamentis.sciencebowl`
**Version:** 1.0
**Last Updated:** 2026-01-17
**Status:** Implementation Planning

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Competition Rules & Format](#2-competition-rules--format)
3. [Data Models](#3-data-models)
4. [Core Services](#4-core-services)
5. [Training Modes](#5-training-modes)
6. [Analytics & Metrics](#6-analytics--metrics)
7. [User Interface](#7-user-interface)
8. [watchOS Integration](#8-watchos-integration)
9. [Implementation Priorities](#9-implementation-priorities)
10. [Testing Requirements](#10-testing-requirements)

---

## 1. Module Overview

### 1.1 Module Manifest

```swift
let scienceBowlManifest = ModuleManifest(
    moduleId: "com.unamentis.sciencebowl",
    displayName: "Science Bowl",
    version: "1.0.0",
    competition: .scienceBowl,
    minimumCoreVersion: "1.0.0",
    optionalModules: [
        "com.unamentis.quizbowl",
        "com.unamentis.knowledgebowl"
    ],
    capabilities: ModuleCapabilities(
        providesQuestions: true,
        consumesSharedQuestions: true,
        providesAnalytics: true,
        consumesUnifiedProfile: true,
        supportsVoiceInterface: true,
        supportsWatchOS: true
    ),
    bundledQuestionCount: 6000,
    supportedDomains: [.biology, .chemistry, .physics, .mathematics, .earthScience, .astronomy, .energy],
    supportedLevels: [.middleSchool, .highSchool]
)
```

### 1.2 Competition Profile

| Attribute | Value |
|-----------|-------|
| **Organizing Body** | US Department of Energy (DOE) |
| **Geographic Scope** | 50 US states + territories |
| **Annual Participants** | ~18,500 students |
| **Grade Levels** | Middle School (6-8) + High School (9-12) |
| **Voice Percentage** | 100% (entirely voice-based) |
| **Match Format** | 2 teams per match |
| **Team Size** | 4 players + 1 alternate |
| **Content Focus** | STEM only (no humanities) |

### 1.3 Key Differentiators

| Feature | Science Bowl | Quiz Bowl | Knowledge Bowl |
|---------|--------------|-----------|----------------|
| Content | **STEM only** | All subjects | All subjects |
| Question Style | Short, direct | Pyramidal | Short, direct |
| Negative Scoring | No | Yes (-5) | No |
| Buzz Procedure | **Recognition first** | Buzz anytime | Buzz anytime |
| Bonus Structure | **4 parts, 10 total** | 3 parts, 30 total | None |
| Multiple Choice | **Yes (tossups)** | No | Yes (written) |

### 1.4 Related Documents

| Document | Purpose |
|----------|---------|
| [MASTER_TECHNICAL_IMPLEMENTATION.md](MASTER_TECHNICAL_IMPLEMENTATION.md) | Platform architecture |
| [ACADEMIC_COMPETITION_MODULAR_ARCHITECTURE.md](ACADEMIC_COMPETITION_MODULAR_ARCHITECTURE.md) | Module integration |
| [UNIFIED_PROFICIENCY_SYSTEM.md](UNIFIED_PROFICIENCY_SYSTEM.md) | Cross-module proficiency |

---

## 2. Competition Rules & Format

### 2.1 Category System

Science Bowl has 6 fixed categories with defined distributions.

```swift
// MARK: - Science Bowl Categories

enum SBCategory: String, Codable, CaseIterable {
    case biology = "BIO"
    case chemistry = "CHEM"
    case physics = "PHY"
    case mathematics = "MATH"
    case earthAndSpace = "EARTH"
    case energy = "ENERGY"

    var fullName: String {
        switch self {
        case .biology: return "Biology"
        case .chemistry: return "Chemistry"
        case .physics: return "Physics"
        case .mathematics: return "Mathematics"
        case .earthAndSpace: return "Earth and Space Science"
        case .energy: return "Energy"
        }
    }

    /// Standard distribution in a Science Bowl round
    var targetDistribution: Double {
        switch self {
        case .biology: return 0.20
        case .chemistry: return 0.20
        case .physics: return 0.20
        case .mathematics: return 0.15
        case .earthAndSpace: return 0.15
        case .energy: return 0.10
        }
    }

    /// Maps to standard domain taxonomy
    var standardDomain: StandardDomain {
        switch self {
        case .biology: return .biology
        case .chemistry: return .chemistry
        case .physics: return .physics
        case .mathematics: return .mathematics
        case .earthAndSpace: return .earthScience
        case .energy: return .physics  // Energy overlaps with physics
        }
    }

    /// Common subtopics within each category
    var subtopics: [String] {
        switch self {
        case .biology:
            return ["Cell Biology", "Genetics", "Ecology", "Anatomy", "Microbiology",
                    "Botany", "Zoology", "Evolution", "Biochemistry"]
        case .chemistry:
            return ["Organic Chemistry", "Inorganic Chemistry", "Physical Chemistry",
                    "Periodic Table", "Chemical Reactions", "Stoichiometry",
                    "Acids and Bases", "Thermochemistry"]
        case .physics:
            return ["Mechanics", "Thermodynamics", "Electromagnetism", "Optics",
                    "Waves", "Modern Physics", "Quantum Mechanics", "Relativity"]
        case .mathematics:
            return ["Algebra", "Geometry", "Trigonometry", "Calculus",
                    "Statistics", "Probability", "Number Theory"]
        case .earthAndSpace:
            return ["Geology", "Meteorology", "Oceanography", "Astronomy",
                    "Planetary Science", "Atmospheric Science"]
        case .energy:
            return ["Renewable Energy", "Nuclear Energy", "Fossil Fuels",
                    "Energy Transfer", "Thermodynamics", "Electricity Generation"]
        }
    }
}
```

### 2.2 Question Types

Science Bowl uses two question types: Multiple Choice and Short Answer.

```swift
// MARK: - Question Types

enum SBQuestionType: String, Codable {
    case multipleChoice = "MC"
    case shortAnswer = "SA"

    var answerTime: TimeInterval {
        switch self {
        case .multipleChoice: return 5.0
        case .shortAnswer: return 5.0
        }
    }

    /// MC uses W, X, Y, Z labels (not A, B, C, D)
    static let mcLabels = ["W", "X", "Y", "Z"]
}

enum SBQuestionRole: String, Codable {
    case tossup     // Individual player answers
    case bonus      // Team collaborates
}
```

### 2.3 Match Format

```swift
// MARK: - Match Configuration

struct SBMatchConfig: Codable {
    /// Division (Middle School or High School)
    let division: SBDivision

    /// Match structure
    let halvesCount: Int = 2
    let questionsPerHalf: Int = 8  // 8 tossups per half
    let minutesPerHalf: Int = 8
    let timeoutPerTeam: Int = 1    // One timeout per team

    /// Scoring
    let scoring: SBScoringRules

    /// Question distribution
    let categoryDistribution: [SBCategory: Double]

    static let standard = SBMatchConfig(
        division: .highSchool,
        scoring: .standard,
        categoryDistribution: [
            .biology: 0.20,
            .chemistry: 0.20,
            .physics: 0.20,
            .mathematics: 0.15,
            .earthAndSpace: 0.15,
            .energy: 0.10
        ]
    )
}

enum SBDivision: String, Codable {
    case middleSchool
    case highSchool

    var gradeRange: String {
        switch self {
        case .middleSchool: return "Grades 6-8"
        case .highSchool: return "Grades 9-12"
        }
    }
}

struct SBScoringRules: Codable {
    /// Points for correct tossup
    let tossupPoints: Int

    /// Total possible bonus points (all 4 parts)
    let maxBonusPoints: Int

    /// Points per bonus part
    let pointsPerBonusPart: Int

    /// Penalty for incorrect tossup (always 0 in Science Bowl)
    let incorrectPenalty: Int = 0

    static let standard = SBScoringRules(
        tossupPoints: 4,
        maxBonusPoints: 10,
        pointsPerBonusPart: 10  // 10 total, not per part
    )
}
```

### 2.4 Buzz Recognition Procedure

**Critical**: Science Bowl has a unique "recognition" requirement before answering.

```swift
// MARK: - Recognition Procedure

/// Science Bowl requires moderator recognition BEFORE player can answer
/// This differs from QB (buzz anytime) and KB (team buzz)

struct SBRecognitionProcedure: Codable {
    /// Player must be recognized by moderator before answering
    let requiresRecognition: Bool = true

    /// Time after buzz to be recognized
    let recognitionWindow: TimeInterval = 2.0

    /// After recognition, time to start answering
    let answerStartWindow: TimeInterval = 5.0

    /// Time to complete answer
    let answerCompletionTime: TimeInterval = 5.0

    /// Interrupt allowed after question is fully read
    let interruptAfterQuestion: Bool = true

    /// Cannot interrupt during question reading
    let interruptDuringQuestion: Bool = false
}

/// The flow:
/// 1. Moderator reads tossup
/// 2. After question ends, first player to signal is recognized
/// 3. Moderator says player's position (e.g., "Player 2")
/// 4. Player has 5 seconds to begin answering
/// 5. If incorrect, other team gets chance (no bounce on bonus)
```

---

## 3. Data Models

### 3.1 Question Models

```swift
// MARK: - Science Bowl Tossup

struct SBTossup: CompetitionQuestion, Codable, Identifiable {
    let id: UUID
    let sourceQuestionId: UUID?  // Link to canonical question

    // Core Content
    let text: String
    let answer: AnswerSpec
    let category: SBCategory
    let questionType: SBQuestionType

    // For Multiple Choice
    let choices: [SBChoice]?  // W, X, Y, Z

    // Classification
    let difficulty: DifficultyTier
    let division: SBDivision

    // Computation Questions
    let requiresCalculation: Bool
    let expectedWorkTime: TimeInterval?

    // Metadata
    let source: String?           // "2024 NSB Regional"
    let yearWritten: Int?
    let usageCount: Int
}

struct SBChoice: Codable {
    let label: String           // "W", "X", "Y", "Z"
    let text: String
    let isCorrect: Bool
}

// MARK: - Science Bowl Bonus

/// Science Bowl bonuses have 4 parts worth 10 points total
/// Unlike QB, parts are NOT individually scored
/// Teams must get all parts for full credit (varies by tournament)

struct SBBonus: Codable, Identifiable {
    let id: UUID
    let sourceQuestionId: UUID?

    let category: SBCategory

    /// Introduction to the bonus
    let leadin: String

    /// Four parts (not separately scored in standard rules)
    let parts: [SBBonusPart]

    let difficulty: DifficultyTier
    let division: SBDivision
}

struct SBBonusPart: Codable, Identifiable {
    let id: UUID
    let index: Int              // 1, 2, 3, 4
    let text: String
    let answer: AnswerSpec
    let questionType: SBQuestionType
}
```

### 3.2 Session Models

```swift
// MARK: - SB Practice Session

struct SBPracticeSession: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let startTime: Date
    var endTime: Date?

    let sessionType: SBSessionType
    let division: SBDivision
    let targetCategories: [SBCategory]?

    // Results
    var tossupAttempts: [SBTossupAttempt]
    var bonusAttempts: [SBBonusAttempt]
    var summary: SBSessionSummary?
}

enum SBSessionType: String, Codable {
    case categoryDrill          // Focus on one category
    case mixedPractice          // All categories
    case mathSpeed              // Math computation focus
    case formulaReview          // Formula/constant memorization
    case multipleChoiceStrategy // MC elimination practice
    case matchSimulation        // Full match format
    case weakCategoryFocus      // Auto-selected weak areas
}

struct SBTossupAttempt: Codable, Identifiable {
    let id: UUID
    let questionId: UUID
    let timestamp: Date

    // Question Info
    let category: SBCategory
    let questionType: SBQuestionType

    // Response
    let userAnswer: String?
    let selectedChoice: String?     // For MC: "W", "X", "Y", "Z"
    let responseTime: TimeInterval
    let wasCorrect: Bool
    let pointsEarned: Int

    // For computation questions
    let calculationTime: TimeInterval?
}

struct SBBonusAttempt: Codable, Identifiable {
    let id: UUID
    let bonusId: UUID
    let timestamp: Date
    let category: SBCategory

    let partResults: [SBBonusPartResult]

    // Science Bowl bonuses are all-or-nothing OR partial
    // This varies by tournament rules
    let totalPoints: Int
    let totalCorrect: Int
}

struct SBBonusPartResult: Codable {
    let partIndex: Int
    let userAnswer: String?
    let wasCorrect: Bool
    let responseTime: TimeInterval
}

// MARK: - Session Summary

struct SBSessionSummary: Codable {
    // Overall
    let totalQuestions: Int
    let totalCorrect: Int
    let overallAccuracy: Double
    let totalPoints: Int

    // By Category
    let categoryPerformance: [SBCategory: SBCategoryStats]

    // By Question Type
    let mcAccuracy: Double
    let saAccuracy: Double

    // Speed Metrics
    let averageResponseTime: TimeInterval
    let mathAverageTime: TimeInterval?  // For math questions specifically

    // Weakest/Strongest
    let strongestCategory: SBCategory?
    let weakestCategory: SBCategory?
}

struct SBCategoryStats: Codable {
    let category: SBCategory
    var questionsAttempted: Int
    var questionsCorrect: Int
    var accuracy: Double { questionsAttempted > 0 ? Double(questionsCorrect) / Double(questionsAttempted) : 0 }
    var averageResponseTime: TimeInterval
    var trend: PerformanceTrend
}
```

### 3.3 Analytics Models

```swift
// MARK: - SB Analytics Profile

struct SBAnalyticsProfile: CompetitionSpecificProfile, Codable {
    let competitionFormat = CompetitionFormat.scienceBowl
    let userId: UUID
    let lastUpdated: Date

    // Overall Performance
    var totalQuestions: Int
    var totalCorrect: Int
    var overallAccuracy: Double

    // Category Breakdown (the core of SB analytics)
    var categoryPerformance: [SBCategory: SBCategoryAnalytics]

    // Question Type Performance
    var multipleChoiceAccuracy: Double
    var shortAnswerAccuracy: Double

    // Speed Metrics
    var averageResponseTime: TimeInterval
    var responseTimeByCategory: [SBCategory: TimeInterval]

    // Math-Specific (important for SB)
    var mathComputationAccuracy: Double
    var averageMathTime: TimeInterval
    var mathSpeedTrend: PerformanceTrend

    // Division-Specific
    var division: SBDivision
    var performanceVsNational: PercentileEstimate?

    // Trends
    var weeklyProgress: [WeeklySnapshot]
}

struct SBCategoryAnalytics: Codable {
    let category: SBCategory

    // Question stats
    var questionsAttempted: Int
    var questionsCorrect: Int
    var accuracy: Double { questionsAttempted > 0 ? Double(questionsCorrect) / Double(questionsAttempted) : 0 }

    // By question type
    var mcAttempted: Int
    var mcCorrect: Int
    var saAttempted: Int
    var saCorrect: Int

    // Speed
    var averageTime: TimeInterval

    // Subtopic breakdown
    var subtopicPerformance: [String: SubtopicStats]

    // Trend
    var trend: PerformanceTrend
    var masteryLevel: MasteryLevel
}

struct SubtopicStats: Codable {
    var attempted: Int
    var correct: Int
    var lastPracticed: Date
}

struct PercentileEstimate: Codable {
    let percentile: Int          // 1-99
    let sampleSize: Int          // How many comparisons
    let confidenceLevel: Double  // Statistical confidence
}
```

---

## 4. Core Services

### 4.1 SB Question Service

```swift
// MARK: - SB Question Service

class SBQuestionService {
    private let questionEngine: QuestionEngine
    private let transformer: SBTransformer

    // ═══════════════════════════════════════════════════════════════════════
    // TOSSUP RETRIEVAL
    // ═══════════════════════════════════════════════════════════════════════

    /// Get tossups with category balance
    func getTossups(
        count: Int,
        categories: [SBCategory]? = nil,
        difficulty: DifficultyTier?,
        division: SBDivision,
        questionTypes: [SBQuestionType]? = nil
    ) -> [SBTossup] {

        // If no categories specified, use standard distribution
        let targetCategories = categories ?? SBCategory.allCases
        var questions: [SBTossup] = []

        if categories == nil {
            // Distribute according to standard percentages
            for category in SBCategory.allCases {
                let categoryCount = Int(Double(count) * category.targetDistribution)
                let categoryQuestions = fetchCategoryQuestions(
                    category: category,
                    count: max(1, categoryCount),
                    difficulty: difficulty,
                    division: division,
                    questionTypes: questionTypes
                )
                questions.append(contentsOf: categoryQuestions)
            }
        } else {
            // Even distribution among specified categories
            let perCategory = count / targetCategories.count
            for category in targetCategories {
                let categoryQuestions = fetchCategoryQuestions(
                    category: category,
                    count: perCategory,
                    difficulty: difficulty,
                    division: division,
                    questionTypes: questionTypes
                )
                questions.append(contentsOf: categoryQuestions)
            }
        }

        return questions.shuffled().prefix(count).map { $0 }
    }

    private func fetchCategoryQuestions(
        category: SBCategory,
        count: Int,
        difficulty: DifficultyTier?,
        division: SBDivision,
        questionTypes: [SBQuestionType]?
    ) -> [SBTossup] {

        var filters = QuestionFilters()
        filters.domains = [PrimaryDomain(from: category.standardDomain)]
        filters.difficulty = difficulty.map { $0...$0 }
        filters.gradeLevels = division == .middleSchool ? [.middleSchool] : [.highSchool]

        let canonicals = questionEngine.query(filters: filters, limit: count * 2)

        return canonicals
            .compactMap { transformer.transform($0, category: category, division: division) }
            .filter { tossup in
                if let types = questionTypes {
                    return types.contains(tossup.questionType)
                }
                return true
            }
            .prefix(count)
            .map { $0 }
    }

    /// Get computation-focused math questions
    func getMathComputationQuestions(
        count: Int,
        difficulty: DifficultyTier?,
        division: SBDivision
    ) -> [SBTossup] {

        return fetchCategoryQuestions(
            category: .mathematics,
            count: count * 2,
            difficulty: difficulty,
            division: division,
            questionTypes: [.shortAnswer]
        ).filter { $0.requiresCalculation }.prefix(count).map { $0 }
    }
}
```

### 4.2 SB Session Manager

```swift
// MARK: - SB Session Manager

class SBSessionManager {
    private let questionService: SBQuestionService
    private let voicePipeline: UniversalVoicePipeline
    private let analyticsService: SBAnalyticsService
    private let proficiencyStore: ProficiencyStore

    private var currentSession: SBPracticeSession?

    // ═══════════════════════════════════════════════════════════════════════
    // SESSION LIFECYCLE
    // ═══════════════════════════════════════════════════════════════════════

    func startSession(
        type: SBSessionType,
        config: SBSessionConfig
    ) async throws -> SBPracticeSession {

        // Configure voice pipeline for SB
        voicePipeline.configure(for: .scienceBowl)

        let session = SBPracticeSession(
            id: UUID(),
            userId: config.userId,
            startTime: Date(),
            sessionType: type,
            division: config.division,
            targetCategories: config.categories,
            tossupAttempts: [],
            bonusAttempts: []
        )

        currentSession = session
        return session
    }

    // ═══════════════════════════════════════════════════════════════════════
    // TOSSUP PROCESSING
    // ═══════════════════════════════════════════════════════════════════════

    func processTossup(
        _ tossup: SBTossup,
        simulateRecognition: Bool = true
    ) async -> SBTossupAttempt {

        // Announce category
        await voicePipeline.speak("\(tossup.category.fullName). \(tossup.questionType.rawValue).")

        // Small pause
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Read the question
        await voicePipeline.speak(tossup.text)

        // For MC, read choices
        if tossup.questionType == .multipleChoice, let choices = tossup.choices {
            for choice in choices {
                await voicePipeline.speak("\(choice.label): \(choice.text)")
            }
        }

        // Simulate recognition (in real match, moderator would recognize)
        if simulateRecognition {
            await voicePipeline.speak("Player 1")
        }

        // Start timer
        let startTime = Date()

        // Get answer
        let result: (answer: String?, isCorrect: Bool)

        if tossup.questionType == .multipleChoice {
            result = await getMultipleChoiceAnswer(choices: tossup.choices!)
        } else {
            result = await getShortAnswer(expected: tossup.answer)
        }

        let responseTime = Date().timeIntervalSince(startTime)

        // Determine points
        let points = result.isCorrect ? 4 : 0

        let attempt = SBTossupAttempt(
            id: UUID(),
            questionId: tossup.id,
            timestamp: Date(),
            category: tossup.category,
            questionType: tossup.questionType,
            userAnswer: result.answer,
            selectedChoice: tossup.questionType == .multipleChoice ? result.answer : nil,
            responseTime: responseTime,
            wasCorrect: result.isCorrect,
            pointsEarned: points,
            calculationTime: tossup.requiresCalculation ? responseTime : nil
        )

        // Record to proficiency
        recordTossupToProficiency(attempt, tossup: tossup)

        // Announce result
        if result.isCorrect {
            await voicePipeline.speak("Correct")
        } else {
            await voicePipeline.speak("Incorrect. The answer is \(tossup.answer.primary)")
        }

        return attempt
    }

    private func getMultipleChoiceAnswer(choices: [SBChoice]) async -> (String?, Bool) {
        // Listen for W, X, Y, or Z
        let result = await voicePipeline.listenForAnswer(timeout: 5.0)

        let normalized = result.transcript.uppercased().trimmingCharacters(in: .whitespaces)

        // Check if it's a valid choice letter
        let validLetters = ["W", "X", "Y", "Z"]
        let selectedLetter = validLetters.first { normalized.contains($0) }

        if let letter = selectedLetter {
            let isCorrect = choices.first { $0.label == letter }?.isCorrect ?? false
            return (letter, isCorrect)
        }

        return (result.transcript, false)
    }

    private func getShortAnswer(expected: AnswerSpec) async -> (String?, Bool) {
        let result = await voicePipeline.listenForAnswer(timeout: 5.0)
        let isCorrect = validateAnswer(result.transcript, against: expected)
        return (result.transcript, isCorrect)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // BONUS PROCESSING
    // ═══════════════════════════════════════════════════════════════════════

    func processBonus(_ bonus: SBBonus) async -> SBBonusAttempt {
        var partResults: [SBBonusPartResult] = []

        // Read lead-in
        await voicePipeline.speak("Bonus. \(bonus.category.fullName).")
        await voicePipeline.speak(bonus.leadin)

        // Process each part
        for part in bonus.parts {
            await voicePipeline.speak("Part \(part.index): \(part.text)")

            if part.questionType == .multipleChoice {
                // Would need choices - simplified here
            }

            let startTime = Date()
            let answerResult = await voicePipeline.listenForAnswer(timeout: 5.0)
            let responseTime = Date().timeIntervalSince(startTime)

            let isCorrect = validateAnswer(answerResult.transcript, against: part.answer)

            partResults.append(SBBonusPartResult(
                partIndex: part.index,
                userAnswer: answerResult.transcript,
                wasCorrect: isCorrect,
                responseTime: responseTime
            ))

            // Brief feedback
            if isCorrect {
                await voicePipeline.speak("Correct")
            } else {
                await voicePipeline.speak("The answer was \(part.answer.primary)")
            }
        }

        // Calculate bonus points (10 total possible)
        let correctCount = partResults.filter { $0.wasCorrect }.count
        // Standard scoring: all 4 correct = 10 pts, else partial
        let totalPoints = calculateBonusPoints(correctCount: correctCount)

        return SBBonusAttempt(
            id: UUID(),
            bonusId: bonus.id,
            timestamp: Date(),
            category: bonus.category,
            partResults: partResults,
            totalPoints: totalPoints,
            totalCorrect: correctCount
        )
    }

    private func calculateBonusPoints(correctCount: Int) -> Int {
        // Standard DOE rules: 10 points for all 4, 0 otherwise
        // Some tournaments use partial scoring
        return correctCount == 4 ? 10 : 0
    }
}

struct SBSessionConfig {
    let userId: UUID
    let division: SBDivision
    let categories: [SBCategory]?
    let difficulty: DifficultyTier?
    let questionCount: Int
    let includeBonuses: Bool
}
```

### 4.3 SB Transformer

```swift
// MARK: - SB Question Transformer

struct SBTransformer: QuestionTransformer {
    typealias Output = SBTossup

    /// Transform canonical question to Science Bowl format
    func transform(
        _ canonical: CanonicalQuestion,
        category: SBCategory? = nil,
        division: SBDivision = .highSchool
    ) -> SBTossup? {

        guard isCompatible(canonical) else { return nil }

        // Determine category from domains
        let sbCategory = category ?? determineSBCategory(from: canonical.domains)
        guard let finalCategory = sbCategory else { return nil }

        // Use short form (SB questions are direct)
        let text = canonical.content.shortForm

        // Determine question type
        let questionType: SBQuestionType = canBeMC(canonical) ? .multipleChoice : .shortAnswer

        // Generate MC choices if applicable
        let choices: [SBChoice]? = questionType == .multipleChoice ?
            generateMCChoices(for: canonical) : nil

        return SBTossup(
            id: UUID(),
            sourceQuestionId: canonical.id,
            text: text,
            answer: canonical.answer,
            category: finalCategory,
            questionType: questionType,
            choices: choices,
            difficulty: canonical.difficulty.competitionRelative[.scienceBowl]?.tier ?? .competent,
            division: division,
            requiresCalculation: requiresCalculation(canonical),
            expectedWorkTime: estimateWorkTime(canonical),
            source: canonical.metadata.source,
            yearWritten: canonical.metadata.yearWritten,
            usageCount: canonical.metadata.usageCount
        )
    }

    func isCompatible(_ canonical: CanonicalQuestion) -> Bool {
        // Must be STEM domain
        let stemDomains: Set<PrimaryDomain> = [
            .biology, .chemistry, .physics, .mathematics,
            .earthScience, .astronomy, .science
        ]
        return canonical.domains.contains { stemDomains.contains($0.primary) }
    }

    func qualityScore(_ canonical: CanonicalQuestion) -> Double {
        var score = 0.5

        // Prefer short-form questions (SB style)
        if canonical.content.shortForm.count < 200 { score += 0.2 }

        // Prefer questions with discrete answers
        let goodAnswerTypes: Set<AnswerType> = [.number, .scientific, .person, .thing]
        if goodAnswerTypes.contains(canonical.answer.answerType) { score += 0.15 }

        // Prefer computation questions for math
        if canonical.domains.contains(where: { $0.primary == .mathematics }) &&
           requiresCalculation(canonical) {
            score += 0.15
        }

        return min(1.0, score)
    }

    private func determineSBCategory(from domains: [DomainTag]) -> SBCategory? {
        for domain in domains {
            switch domain.primary {
            case .biology: return .biology
            case .chemistry: return .chemistry
            case .physics: return .physics
            case .mathematics: return .mathematics
            case .earthScience, .astronomy: return .earthAndSpace
            case .science:
                // Generic science - check subdomain
                if let sub = domain.secondary?.lowercased() {
                    if sub.contains("energy") { return .energy }
                }
                return .physics  // Default
            default: continue
            }
        }
        return nil
    }

    private func canBeMC(_ canonical: CanonicalQuestion) -> Bool {
        // Can be MC if answer has clear alternatives
        let mcFriendlyTypes: Set<AnswerType> = [.person, .place, .thing, .scientific]
        return mcFriendlyTypes.contains(canonical.answer.answerType)
    }

    private func generateMCChoices(for canonical: CanonicalQuestion) -> [SBChoice] {
        // Generate 3 plausible distractors
        let distractors = generateDistractors(for: canonical, count: 3)
        let correctAnswer = canonical.answer.primary

        var choices = distractors.map { SBChoice(label: "", text: $0, isCorrect: false) }
        choices.append(SBChoice(label: "", text: correctAnswer, isCorrect: true))
        choices.shuffle()

        // Assign W, X, Y, Z labels
        let labels = ["W", "X", "Y", "Z"]
        return choices.enumerated().map { index, choice in
            SBChoice(label: labels[index], text: choice.text, isCorrect: choice.isCorrect)
        }
    }

    private func requiresCalculation(_ canonical: CanonicalQuestion) -> Bool {
        // Check if question involves math computation
        let text = canonical.content.shortForm.lowercased()
        let calcKeywords = ["calculate", "compute", "find the value", "what is", "solve",
                           "determine the", "how many", "how much"]
        return calcKeywords.contains { text.contains($0) } &&
               canonical.domains.contains { $0.primary == .mathematics || $0.primary == .physics }
    }

    private func estimateWorkTime(_ canonical: CanonicalQuestion) -> TimeInterval? {
        guard requiresCalculation(canonical) else { return nil }
        // Estimate 15-30 seconds for computation
        return 20.0
    }
}
```

---

## 5. Training Modes

### 5.1 Training Mode Definitions

```swift
// MARK: - SB Training Modes

enum SBTrainingMode {
    /// Focus on one category
    case categoryDrill(CategoryDrillConfig)

    /// Mixed category practice
    case mixedPractice(MixedConfig)

    /// Math computation speed
    case mathSpeed(MathSpeedConfig)

    /// Formula and constant memorization
    case formulaReview(FormulaConfig)

    /// MC elimination strategies
    case mcStrategy(MCStrategyConfig)

    /// Full match simulation
    case matchSimulation(MatchSimConfig)

    /// Auto-focus on weak categories
    case adaptivePractice(AdaptiveConfig)
}

struct CategoryDrillConfig {
    let category: SBCategory
    let questionCount: Int
    let difficulty: DifficultyTier?
    let division: SBDivision
    let questionTypes: [SBQuestionType]
    let focusSubtopics: [String]?
}

struct MathSpeedConfig {
    let questionCount: Int
    let startingTimeLimit: TimeInterval
    let minimumTimeLimit: TimeInterval
    let decrementAmount: TimeInterval
    let problemTypes: [MathProblemType]

    enum MathProblemType: String, Codable {
        case arithmetic
        case algebra
        case geometry
        case trigonometry
        case calculus
        case statistics
        case unitConversion
    }
}

struct FormulaConfig {
    let categories: [SBCategory]
    let includeConstants: Bool
    let includeUnits: Bool
    let flashcardMode: Bool
    let quizMode: Bool
}

struct MCStrategyConfig {
    let questionCount: Int
    let category: SBCategory?
    let showEliminationSteps: Bool
    let trackEliminationAccuracy: Bool
}

struct AdaptiveConfig {
    let totalQuestions: Int
    let targetAccuracy: Double
    let prioritizeWeakCategories: Bool
    let includeReviewQuestions: Bool
}
```

### 5.2 Math Computation Protocol

A key differentiator for Science Bowl training.

```swift
// MARK: - Math Speed Protocol

struct MathSpeedProtocol: TrainingProtocol {
    let id = UUID()
    let name = "Mental Math Mastery"
    let description = "Build speed and accuracy on Science Bowl math computations"
    let applicableCompetitions: Set<CompetitionFormat> = [.scienceBowl]
    let requiredCapabilities: Set<TrainingCapability> = [.voiceInput, .voiceOutput, .timerSystem]

    func createSession(config: TrainingSessionConfig) -> TrainingSession {
        return MathSpeedSession(config: config)
    }
}

class MathSpeedSession: TrainingSession {
    private var currentTimeLimit: TimeInterval
    private let minimumTimeLimit: TimeInterval
    private let decrementAmount: TimeInterval

    /// Essential formulas for Science Bowl math
    static let essentialFormulas: [String: String] = [
        "Quadratic Formula": "x = (-b ± √(b²-4ac)) / 2a",
        "Distance Formula": "d = √((x₂-x₁)² + (y₂-y₁)²)",
        "Pythagorean Theorem": "a² + b² = c²",
        "Area of Circle": "A = πr²",
        "Volume of Sphere": "V = (4/3)πr³",
        "Slope Formula": "m = (y₂-y₁)/(x₂-x₁)",
        "Kinematic Equation": "v² = v₀² + 2aΔx",
        "Ideal Gas Law": "PV = nRT"
    ]

    /// Common constants to memorize
    static let essentialConstants: [String: String] = [
        "Speed of Light": "c ≈ 3×10⁸ m/s",
        "Gravitational Acceleration": "g ≈ 9.8 m/s²",
        "Avogadro's Number": "Nₐ ≈ 6.02×10²³",
        "Planck's Constant": "h ≈ 6.63×10⁻³⁴ J·s",
        "Gas Constant": "R ≈ 8.314 J/(mol·K)",
        "Pi": "π ≈ 3.14159",
        "e (Euler's number)": "e ≈ 2.718"
    ]

    func runProgressiveSpeedDrill(_ questions: [SBTossup]) async -> MathSpeedResult {
        var results: [MathQuestionResult] = []

        for question in questions {
            // Announce time limit
            await voicePipeline.speak("You have \(Int(currentTimeLimit)) seconds")

            // Read question
            await voicePipeline.speak(question.text)

            // Start timer
            let startTime = Date()

            // Get answer with timeout
            let answerTask = Task {
                await voicePipeline.listenForAnswer(timeout: currentTimeLimit)
            }

            let result = await answerTask.value
            let responseTime = Date().timeIntervalSince(startTime)

            let isCorrect = validateAnswer(result.transcript, against: question.answer)
            let madeTime = responseTime <= currentTimeLimit

            results.append(MathQuestionResult(
                wasCorrect: isCorrect,
                madeTime: madeTime,
                responseTime: responseTime,
                timeLimit: currentTimeLimit
            ))

            // Feedback
            if isCorrect && madeTime {
                await voicePipeline.speak("Correct! \(String(format: "%.1f", responseTime)) seconds")
                // Decrease time limit for next question
                currentTimeLimit = max(minimumTimeLimit, currentTimeLimit - decrementAmount)
            } else if isCorrect {
                await voicePipeline.speak("Correct, but over time")
            } else {
                await voicePipeline.speak("Incorrect. The answer was \(question.answer.primary)")
                // Reset time limit on incorrect
                currentTimeLimit = minimumTimeLimit + decrementAmount * 3
            }
        }

        return MathSpeedResult(
            questionResults: results,
            finalTimeLimit: currentTimeLimit,
            averageTime: results.map(\.responseTime).reduce(0, +) / Double(results.count)
        )
    }
}

struct MathQuestionResult {
    let wasCorrect: Bool
    let madeTime: Bool
    let responseTime: TimeInterval
    let timeLimit: TimeInterval
}

struct MathSpeedResult {
    let questionResults: [MathQuestionResult]
    let finalTimeLimit: TimeInterval
    let averageTime: TimeInterval
}
```

### 5.3 Formula Flashcard Protocol

```swift
// MARK: - Formula Flashcard Protocol

struct FormulaFlashcardProtocol: TrainingProtocol {
    let id = UUID()
    let name = "Formula Flash"
    let description = "Rapid recall of essential formulas and physical constants"
    let applicableCompetitions: Set<CompetitionFormat> = [.scienceBowl]
    let requiredCapabilities: Set<TrainingCapability> = [.voiceOutput]

    /// Category-specific formulas
    static let formulasByCategory: [SBCategory: [FormulaCard]] = [
        .physics: [
            FormulaCard(name: "Newton's Second Law", formula: "F = ma", category: .physics),
            FormulaCard(name: "Kinetic Energy", formula: "KE = ½mv²", category: .physics),
            FormulaCard(name: "Gravitational Potential Energy", formula: "PE = mgh", category: .physics),
            FormulaCard(name: "Momentum", formula: "p = mv", category: .physics),
            FormulaCard(name: "Work", formula: "W = Fd cos θ", category: .physics),
            FormulaCard(name: "Power", formula: "P = W/t", category: .physics),
            FormulaCard(name: "Ohm's Law", formula: "V = IR", category: .physics),
            FormulaCard(name: "Wave Speed", formula: "v = fλ", category: .physics)
        ],
        .chemistry: [
            FormulaCard(name: "Ideal Gas Law", formula: "PV = nRT", category: .chemistry),
            FormulaCard(name: "Molarity", formula: "M = mol/L", category: .chemistry),
            FormulaCard(name: "pH", formula: "pH = -log[H⁺]", category: .chemistry),
            FormulaCard(name: "Dilution", formula: "M₁V₁ = M₂V₂", category: .chemistry)
        ],
        .mathematics: [
            FormulaCard(name: "Quadratic Formula", formula: "x = (-b ± √(b²-4ac))/2a", category: .mathematics),
            FormulaCard(name: "Pythagorean Theorem", formula: "a² + b² = c²", category: .mathematics),
            FormulaCard(name: "Distance Formula", formula: "d = √((x₂-x₁)² + (y₂-y₁)²)", category: .mathematics),
            FormulaCard(name: "Slope-Intercept Form", formula: "y = mx + b", category: .mathematics)
        ],
        .biology: [
            FormulaCard(name: "Hardy-Weinberg Equilibrium", formula: "p² + 2pq + q² = 1", category: .biology),
            FormulaCard(name: "Photosynthesis", formula: "6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂", category: .biology),
            FormulaCard(name: "Cellular Respiration", formula: "C₆H₁₂O₆ + 6O₂ → 6CO₂ + 6H₂O + ATP", category: .biology)
        ],
        .earthAndSpace: [
            FormulaCard(name: "Kepler's Third Law", formula: "T² ∝ a³", category: .earthAndSpace),
            FormulaCard(name: "Escape Velocity", formula: "v = √(2GM/r)", category: .earthAndSpace)
        ],
        .energy: [
            FormulaCard(name: "Einstein's Mass-Energy", formula: "E = mc²", category: .energy),
            FormulaCard(name: "Efficiency", formula: "η = (output/input) × 100%", category: .energy)
        ]
    ]

    func createSession(config: TrainingSessionConfig) -> TrainingSession {
        return FormulaFlashcardSession(config: config)
    }
}

struct FormulaCard: Identifiable {
    let id = UUID()
    let name: String
    let formula: String
    let category: SBCategory
}
```

### 5.4 MC Elimination Protocol

```swift
// MARK: - MC Elimination Strategy

struct MCEliminationProtocol: TrainingProtocol {
    let id = UUID()
    let name = "Process of Elimination"
    let description = "Learn to identify wrong answers even when unsure of the right one"
    let applicableCompetitions: Set<CompetitionFormat> = [.scienceBowl]
    let requiredCapabilities: Set<TrainingCapability> = [.voiceOutput]

    func createSession(config: TrainingSessionConfig) -> TrainingSession {
        return MCEliminationSession(config: config)
    }
}

class MCEliminationSession: TrainingSession {

    func runEliminationTraining(_ question: SBTossup) async -> MCEliminationResult {
        guard question.questionType == .multipleChoice,
              let choices = question.choices else {
            return MCEliminationResult(wasSuccessful: false, eliminatedCount: 0)
        }

        // Read question and choices
        await voicePipeline.speak(question.text)
        for choice in choices {
            await voicePipeline.speak("\(choice.label): \(choice.text)")
        }

        // Step 1: Eliminate one choice
        await voicePipeline.speak("Eliminate one choice you're sure is wrong")
        let firstElimination = await getEliminationChoice()

        // Check if they eliminated the correct answer
        if choices.first(where: { $0.label == firstElimination })?.isCorrect == true {
            await voicePipeline.speak("Careful! That was the correct answer. Review why.")
            return MCEliminationResult(wasSuccessful: false, eliminatedCount: 0)
        }

        // Step 2: Eliminate another
        await voicePipeline.speak("Good. Now eliminate another")
        let secondElimination = await getEliminationChoice()

        if choices.first(where: { $0.label == secondElimination })?.isCorrect == true {
            await voicePipeline.speak("That was the correct answer!")
            return MCEliminationResult(wasSuccessful: false, eliminatedCount: 1)
        }

        // Now down to 2 choices - 50/50
        let remaining = choices.filter { $0.label != firstElimination && $0.label != secondElimination }
        await voicePipeline.speak("You're down to \(remaining.map(\.label).joined(separator: " and ")). Make your choice.")

        let finalAnswer = await getFinalAnswer()
        let wasCorrect = choices.first(where: { $0.label == finalAnswer })?.isCorrect == true

        if wasCorrect {
            await voicePipeline.speak("Correct! Good elimination strategy.")
        } else {
            let correctChoice = choices.first(where: { $0.isCorrect })!
            await voicePipeline.speak("The answer was \(correctChoice.label). Review why \(correctChoice.text) is correct.")
        }

        return MCEliminationResult(
            wasSuccessful: wasCorrect,
            eliminatedCount: 2
        )
    }

    private func getEliminationChoice() async -> String {
        let result = await voicePipeline.listenForAnswer(timeout: 10.0)
        let normalized = result.transcript.uppercased()
        return ["W", "X", "Y", "Z"].first { normalized.contains($0) } ?? ""
    }

    private func getFinalAnswer() async -> String {
        return await getEliminationChoice()
    }
}

struct MCEliminationResult {
    let wasSuccessful: Bool
    let eliminatedCount: Int
}
```

---

## 6. Analytics & Metrics

### 6.1 SB Analytics Service

```swift
// MARK: - SB Analytics Service

class SBAnalyticsService {
    private let proficiencyStore: ProficiencyStore
    private let sessionStore: SBSessionStore

    // ═══════════════════════════════════════════════════════════════════════
    // CATEGORY BALANCE ANALYSIS
    // ═══════════════════════════════════════════════════════════════════════

    /// Analyze category balance - key for SB success
    func analyzeCategoryBalance(for userId: UUID) -> CategoryBalanceReport {
        let analytics = getAnalytics(for: userId)

        var categoryScores: [SBCategory: CategoryScore] = [:]

        for category in SBCategory.allCases {
            let stats = analytics.categoryPerformance[category]

            categoryScores[category] = CategoryScore(
                accuracy: stats?.accuracy ?? 0,
                questionsAttempted: stats?.questionsAttempted ?? 0,
                targetPercentage: category.targetDistribution,
                actualPercentage: Double(stats?.questionsAttempted ?? 0) / Double(analytics.totalQuestions),
                trend: stats?.trend ?? .insufficient_data
            )
        }

        let weakest = categoryScores.min(by: { $0.value.accuracy < $1.value.accuracy })?.key
        let strongest = categoryScores.max(by: { $0.value.accuracy < $1.value.accuracy })?.key

        return CategoryBalanceReport(
            categoryScores: categoryScores,
            weakestCategory: weakest,
            strongestCategory: strongest,
            balanceScore: calculateBalanceScore(categoryScores),
            recommendation: generateBalanceRecommendation(categoryScores)
        )
    }

    private func calculateBalanceScore(_ scores: [SBCategory: CategoryScore]) -> Double {
        // Balance score: How close are all categories to target?
        var totalDeviation = 0.0
        for (category, score) in scores {
            let deviation = abs(score.accuracy - 0.7)  // 70% is target
            totalDeviation += deviation
        }
        return max(0, 1.0 - (totalDeviation / Double(SBCategory.allCases.count)))
    }

    // ═══════════════════════════════════════════════════════════════════════
    // INSIGHTS
    // ═══════════════════════════════════════════════════════════════════════

    func generateInsights(for userId: UUID) -> [SBInsight] {
        let analytics = getAnalytics(for: userId)
        var insights: [SBInsight] = []

        // Category weaknesses
        for (category, stats) in analytics.categoryPerformance {
            if stats.questionsAttempted > 10 && stats.accuracy < 0.4 {
                insights.append(SBInsight(
                    type: .categoryWeakness,
                    title: "\(category.fullName) Needs Work",
                    message: "Your accuracy in \(category.fullName) is only \(Int(stats.accuracy * 100))%. Dedicate practice time here.",
                    priority: .high,
                    suggestedAction: .categoryDrill(category)
                ))
            }
        }

        // MC vs SA comparison
        if analytics.multipleChoiceAccuracy > analytics.shortAnswerAccuracy + 0.2 {
            insights.append(SBInsight(
                type: .questionTypeGap,
                title: "Short Answer Needs Practice",
                message: "Your MC accuracy (\(Int(analytics.multipleChoiceAccuracy * 100))%) is much higher than SA (\(Int(analytics.shortAnswerAccuracy * 100))%).",
                priority: .medium,
                suggestedAction: .shortAnswerPractice
            ))
        }

        // Math speed
        if analytics.averageMathTime > 20 {
            insights.append(SBInsight(
                type: .speedImprovement,
                title: "Speed Up Math",
                message: "Your average math time is \(Int(analytics.averageMathTime)) seconds. Competition pace requires ~15s.",
                priority: .medium,
                suggestedAction: .mathSpeedDrill
            ))
        }

        // Category balance
        let balanceReport = analyzeCategoryBalance(for: userId)
        if balanceReport.balanceScore < 0.6 {
            insights.append(SBInsight(
                type: .imbalance,
                title: "Category Imbalance",
                message: "Focus on \(balanceReport.weakestCategory?.fullName ?? "weak categories") to improve overall performance.",
                priority: .high,
                suggestedAction: balanceReport.weakestCategory.map { .categoryDrill($0) } ?? .adaptivePractice
            ))
        }

        return insights.sorted { $0.priority.rawValue < $1.priority.rawValue }
    }
}

struct CategoryBalanceReport {
    let categoryScores: [SBCategory: CategoryScore]
    let weakestCategory: SBCategory?
    let strongestCategory: SBCategory?
    let balanceScore: Double
    let recommendation: String
}

struct CategoryScore {
    let accuracy: Double
    let questionsAttempted: Int
    let targetPercentage: Double
    let actualPercentage: Double
    let trend: PerformanceTrend
}

struct SBInsight {
    let type: InsightType
    let title: String
    let message: String
    let priority: Priority

    let suggestedAction: SuggestedAction

    enum InsightType {
        case categoryWeakness
        case questionTypeGap
        case speedImprovement
        case imbalance
        case improvement
    }

    enum Priority: Int {
        case critical = 0
        case high = 1
        case medium = 2
        case low = 3
    }

    enum SuggestedAction {
        case categoryDrill(SBCategory)
        case shortAnswerPractice
        case mathSpeedDrill
        case adaptivePractice
        case formulaReview
    }
}
```

---

## 7. User Interface

### 7.1 UI Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SB MODULE UI ARCHITECTURE                            │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                          MAIN DASHBOARD                                 ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   ││
│  │  │  Category   │  │  Training   │  │   Stats     │  │  Formula    │   ││
│  │  │  Overview   │  │   Modes     │  │  Dashboard  │  │  Library    │   ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘   ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                    │                                         │
│         ┌──────────────────────────┼──────────────────────────┐             │
│         ▼                          ▼                          ▼             │
│  ┌─────────────┐           ┌─────────────┐           ┌─────────────┐       │
│  │  Category   │           │    Math     │           │   Match     │       │
│  │   Drill     │           │   Speed     │           │ Simulation  │       │
│  │     UI      │           │     UI      │           │     UI      │       │
│  └─────────────┘           └─────────────┘           └─────────────┘       │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                   SB-SPECIFIC COMPONENTS                                ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   ││
│  │  │  Category   │  │   Formula   │  │    Speed    │  │    MC       │   ││
│  │  │   Wheel     │  │ Flashcards  │  │   Meter     │  │ Eliminator  │   ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘   ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Key Views

```swift
// MARK: - SB Dashboard

struct SBDashboardView: View {
    @StateObject private var viewModel: SBDashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Category Wheel (visual representation of balance)
                    CategoryWheelView(categoryScores: viewModel.categoryScores)

                    // Quick Stats
                    SBQuickStatsCard(stats: viewModel.quickStats)

                    // Training Modes
                    Section("Training") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            TrainingModeCard(
                                icon: "graduationcap",
                                title: "Category Drill",
                                subtitle: "Focus practice"
                            ) { viewModel.startCategoryDrill() }

                            TrainingModeCard(
                                icon: "function",
                                title: "Math Speed",
                                subtitle: "Computation practice"
                            ) { viewModel.startMathSpeed() }

                            TrainingModeCard(
                                icon: "list.bullet.rectangle",
                                title: "Formula Review",
                                subtitle: "Flashcards"
                            ) { viewModel.startFormulaReview() }

                            TrainingModeCard(
                                icon: "person.2",
                                title: "Match Sim",
                                subtitle: "Full competition"
                            ) { viewModel.startMatchSim() }
                        }
                    }

                    // Insights
                    if !viewModel.insights.isEmpty {
                        InsightsSection(insights: viewModel.insights)
                    }
                }
                .padding()
            }
            .navigationTitle("Science Bowl")
        }
    }
}

// MARK: - Category Wheel View

struct CategoryWheelView: View {
    let categoryScores: [SBCategory: CategoryScore]

    var body: some View {
        VStack {
            Text("Category Balance")
                .font(.headline)

            // Pie/radar chart showing category performance
            ZStack {
                // Draw segments for each category
                ForEach(SBCategory.allCases, id: \.self) { category in
                    CategorySegment(
                        category: category,
                        score: categoryScores[category]?.accuracy ?? 0
                    )
                }
            }
            .frame(height: 200)

            // Legend
            HStack(spacing: 12) {
                ForEach(SBCategory.allCases, id: \.self) { category in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorForCategory(category))
                            .frame(width: 8, height: 8)
                        Text(category.rawValue)
                            .font(.caption2)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func colorForCategory(_ category: SBCategory) -> Color {
        switch category {
        case .biology: return .green
        case .chemistry: return .purple
        case .physics: return .blue
        case .mathematics: return .orange
        case .earthAndSpace: return .brown
        case .energy: return .yellow
        }
    }
}

// MARK: - Category Drill View

struct SBCategoryDrillView: View {
    let category: SBCategory
    @StateObject private var viewModel: SBCategoryDrillViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Category Header
            HStack {
                Image(systemName: iconForCategory(category))
                    .font(.title2)
                Text(category.fullName)
                    .font(.headline)
                Spacer()
                Text("\(viewModel.currentIndex + 1)/\(viewModel.totalQuestions)")
                    .font(.subheadline)
            }
            .padding()
            .background(colorForCategory(category).opacity(0.1))

            // Question
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Question type badge
                    HStack {
                        Text(viewModel.currentQuestion?.questionType.rawValue ?? "")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                        Spacer()
                    }

                    // Question text
                    Text(viewModel.currentQuestion?.text ?? "")
                        .font(.body)

                    // MC Choices (if applicable)
                    if viewModel.currentQuestion?.questionType == .multipleChoice,
                       let choices = viewModel.currentQuestion?.choices {
                        ForEach(choices, id: \.label) { choice in
                            ChoiceButton(
                                choice: choice,
                                isSelected: viewModel.selectedChoice == choice.label,
                                showCorrect: viewModel.showAnswer
                            ) {
                                viewModel.selectChoice(choice.label)
                            }
                        }
                    }
                }
                .padding()
            }

            Spacer()

            // Voice Input / Submit
            if viewModel.currentQuestion?.questionType == .shortAnswer {
                VoiceAnswerInputView(
                    isListening: viewModel.isListening,
                    transcript: viewModel.currentTranscript,
                    onSubmit: { viewModel.submitAnswer() }
                )
            } else {
                Button("Submit") {
                    viewModel.submitAnswer()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedChoice == nil)
                .padding()
            }

            // Feedback
            if viewModel.showAnswer {
                AnswerFeedbackView(
                    isCorrect: viewModel.lastWasCorrect,
                    correctAnswer: viewModel.currentQuestion?.answer.primary ?? ""
                )
            }
        }
        .onAppear { viewModel.loadQuestions(for: category) }
    }
}
```

---

## 8. watchOS Integration

```swift
// MARK: - watchOS SB Module

struct SBWatchMainView: View {
    @StateObject private var viewModel = SBWatchViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Quick Practice") {
                    ForEach(SBCategory.allCases, id: \.self) { category in
                        NavigationLink {
                            SBWatchCategoryDrillView(category: category)
                        } label: {
                            HStack {
                                Image(systemName: iconForCategory(category))
                                Text(category.rawValue)
                            }
                        }
                    }
                }

                Section("Formula Flash") {
                    NavigationLink("Physics Formulas") {
                        SBWatchFormulaView(category: .physics)
                    }
                    NavigationLink("Chemistry Formulas") {
                        SBWatchFormulaView(category: .chemistry)
                    }
                    NavigationLink("Math Formulas") {
                        SBWatchFormulaView(category: .mathematics)
                    }
                }

                Section("Today") {
                    StatsRow(label: "Questions", value: "\(viewModel.todayQuestions)")
                    StatsRow(label: "Accuracy", value: "\(Int(viewModel.todayAccuracy * 100))%")
                    StatsRow(label: "Weakest", value: viewModel.weakestCategory?.rawValue ?? "-")
                }
            }
            .navigationTitle("Science Bowl")
        }
    }
}

// Watch formula flashcards
struct SBWatchFormulaView: View {
    let category: SBCategory
    @State private var currentIndex = 0
    @State private var showAnswer = false

    private var formulas: [FormulaCard] {
        FormulaFlashcardProtocol.formulasByCategory[category] ?? []
    }

    var body: some View {
        VStack {
            if currentIndex < formulas.count {
                let formula = formulas[currentIndex]

                Text(formula.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if showAnswer {
                    Text(formula.formula)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }

                Button(showAnswer ? "Next" : "Show") {
                    if showAnswer {
                        currentIndex += 1
                        showAnswer = false
                    } else {
                        showAnswer = true
                    }
                }
            } else {
                Text("Done!")
                    .font(.headline)
            }
        }
        .padding()
    }
}
```

---

## 9. Implementation Priorities

### 9.1 Phase 1: Core SB Functionality (Weeks 19-21)

| Week | Task | Priority | Deliverable |
|------|------|----------|-------------|
| 19 | SB data models | P0 | `SBTossup.swift`, `SBBonus.swift` |
| 19 | Category system | P0 | `SBCategory.swift` |
| 19 | SB transformer | P0 | `SBTransformer.swift` |
| 20 | Question service | P0 | `SBQuestionService.swift` |
| 20 | Session manager | P0 | `SBSessionManager.swift` |
| 20 | MC/SA handling | P0 | Question type processing |
| 21 | Category drill mode | P0 | Category training UI |
| 21 | Analytics service | P0 | `SBAnalyticsService.swift` |

### 9.2 Phase 2: Advanced Features (Week 22)

| Task | Priority | Deliverable |
|------|----------|-------------|
| Math speed training | P0 | Speed drill mode |
| Formula flashcards | P1 | Formula library |
| MC elimination | P1 | Strategy training |
| Match simulation | P1 | Full match mode |

### 9.3 Success Criteria

| Metric | Target |
|--------|--------|
| Category detection accuracy | >98% |
| MC answer recognition | >95% |
| SA answer validation | >90% |
| Formula library completeness | 50+ formulas |
| Category balance tracking | 100% |

---

## 10. Testing Requirements

### 10.1 Unit Tests

```swift
class SBCategoryTests: XCTestCase {
    func testCategoryDistribution() {
        let total = SBCategory.allCases.reduce(0.0) { $0 + $1.targetDistribution }
        XCTAssertEqual(total, 1.0, accuracy: 0.01)
    }

    func testCategoryMapping() {
        XCTAssertEqual(SBCategory.biology.standardDomain, .biology)
        XCTAssertEqual(SBCategory.earthAndSpace.standardDomain, .earthScience)
    }
}

class SBTransformerTests: XCTestCase {
    func testSTEMFiltering() {
        let historyQuestion = createCanonicalQuestion(domain: .history)
        let transformer = SBTransformer()

        XCTAssertFalse(transformer.isCompatible(historyQuestion))
    }

    func testPhysicsTransformation() {
        let physicsQuestion = createCanonicalQuestion(domain: .physics)
        let transformer = SBTransformer()

        let sbQuestion = transformer.transform(physicsQuestion)

        XCTAssertNotNil(sbQuestion)
        XCTAssertEqual(sbQuestion?.category, .physics)
    }
}

class SBScoringTests: XCTestCase {
    func testTossupScoring() {
        let rules = SBScoringRules.standard

        XCTAssertEqual(rules.tossupPoints, 4)
        XCTAssertEqual(rules.incorrectPenalty, 0)  // No negs
    }

    func testBonusScoring() {
        let rules = SBScoringRules.standard

        XCTAssertEqual(rules.maxBonusPoints, 10)
    }
}
```

---

## Appendix A: Formula Reference

| Category | Formula | Name |
|----------|---------|------|
| Physics | F = ma | Newton's Second Law |
| Physics | KE = ½mv² | Kinetic Energy |
| Physics | v = fλ | Wave Equation |
| Chemistry | PV = nRT | Ideal Gas Law |
| Chemistry | pH = -log[H⁺] | pH Definition |
| Math | x = (-b ± √(b²-4ac))/2a | Quadratic Formula |
| Earth/Space | T² ∝ a³ | Kepler's Third Law |

---

## Appendix B: Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-17 | Development Team | Initial SB module specification |

---

*This document provides the technical specification for implementing the Science Bowl module. For integration patterns, see [MASTER_TECHNICAL_IMPLEMENTATION.md](MASTER_TECHNICAL_IMPLEMENTATION.md).*
