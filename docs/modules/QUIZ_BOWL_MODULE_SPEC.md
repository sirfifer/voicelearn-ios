# Quiz Bowl Module Technical Specification

**Module ID:** `com.unamentis.quizbowl`
**Version:** 1.0
**Last Updated:** 2026-01-17
**Status:** Implementation Planning

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Competition Rules & Formats](#2-competition-rules--formats)
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
let quizBowlManifest = ModuleManifest(
    moduleId: "com.unamentis.quizbowl",
    displayName: "Quiz Bowl",
    version: "1.0.0",
    competition: .quizBowl,
    minimumCoreVersion: "1.0.0",
    optionalModules: [
        "com.unamentis.knowledgebowl",
        "com.unamentis.sciencebowl"
    ],
    capabilities: ModuleCapabilities(
        providesQuestions: true,
        consumesSharedQuestions: true,
        providesAnalytics: true,
        consumesUnifiedProfile: true,
        supportsVoiceInterface: true,
        supportsWatchOS: true
    ),
    bundledQuestionCount: 8000,
    supportedDomains: StandardDomain.allCases,
    supportedFormats: [.naqt, .acf, .pace]
)
```

### 1.2 Competition Profile

| Attribute | Value |
|-----------|-------|
| **Geographic Scope** | 50 US states + Canada + International |
| **Annual Participants** | ~50,000 students |
| **Grade Levels** | 4th-12th + College |
| **Voice Percentage** | ~95% (almost entirely voice-based) |
| **Match Format** | 2 teams per match |
| **Team Size** | 4 players |
| **Key Organizations** | NAQT, ACF, PACE, HSQB |

### 1.3 Key Differentiators from Knowledge Bowl

| Feature | Quiz Bowl | Knowledge Bowl |
|---------|-----------|----------------|
| Question Structure | **Pyramidal** (clues hard→easy) | Short, direct |
| Buzzing | **Individual** players | Team |
| Negative Scoring | **Yes** (-5 for wrong buzz) | No |
| Power Scoring | **Yes** (15 pts for early buzz) | No |
| Bonus Questions | **Yes** (team collaborative) | No |
| Written Round | No | Yes |
| Teams per Match | 2 | 3 |

### 1.4 Related Documents

| Document | Purpose |
|----------|---------|
| [MASTER_TECHNICAL_IMPLEMENTATION.md](MASTER_TECHNICAL_IMPLEMENTATION.md) | Platform architecture |
| [ACADEMIC_COMPETITION_MODULAR_ARCHITECTURE.md](ACADEMIC_COMPETITION_MODULAR_ARCHITECTURE.md) | Module integration patterns |
| [UNIFIED_PROFICIENCY_SYSTEM.md](UNIFIED_PROFICIENCY_SYSTEM.md) | Cross-module proficiency |
| [KNOWLEDGE_BOWL_MODULE_SPEC.md](KNOWLEDGE_BOWL_MODULE_SPEC.md) | KB module (shared question pool) |

---

## 2. Competition Rules & Formats

### 2.1 Format Configuration

Quiz Bowl has several major formats (NAQT, ACF, PACE) with different rules.

```swift
// MARK: - QB Format Configuration

struct QBFormatConfig: Codable, Identifiable {
    let id: String
    let format: QBFormat
    let displayName: String

    // Match Structure
    let tossupsPerHalf: Int
    let totalTossups: Int
    let bonusesPerMatch: Int

    // Scoring
    let scoringRules: QBScoringRules

    // Timing
    let timePerTossup: TimeInterval?   // nil = no limit
    let timePerBonus: TimeInterval
    let timeBetweenParts: TimeInterval

    // Special Rules
    let allowsInterruption: Bool
    let hasPowerMarks: Bool
    let hasNegativeScoring: Bool
}

enum QBFormat: String, Codable, CaseIterable {
    case naqt       // National Academic Quiz Tournaments
    case acf        // Academic Competition Federation
    case pace       // Partnership for Academic Competition Excellence
    case practice   // Flexible practice format
}

struct QBScoringRules: Codable {
    /// Points for correct answer before power mark
    let powerPoints: Int

    /// Points for correct answer after power mark
    let tenPoints: Int

    /// Points for incorrect buzz (negative)
    let negPoints: Int

    /// Points per correct bonus part
    let bonusPartPoints: Int

    /// Total possible bonus points
    let maxBonusPoints: Int

    // MARK: - Format Presets

    static let naqt = QBScoringRules(
        powerPoints: 15,
        tenPoints: 10,
        negPoints: -5,
        bonusPartPoints: 10,
        maxBonusPoints: 30
    )

    static let acf = QBScoringRules(
        powerPoints: 15,      // ACF typically has powers now
        tenPoints: 10,
        negPoints: 0,         // ACF: No negs (historically)
        bonusPartPoints: 10,
        maxBonusPoints: 30
    )

    static let pace = QBScoringRules(
        powerPoints: 20,      // PACE uses 20-point powers
        tenPoints: 10,
        negPoints: 0,         // PACE: No negs
        bonusPartPoints: 10,
        maxBonusPoints: 30
    )
}

// MARK: - Full Format Configs

extension QBFormatConfig {
    static let naqt = QBFormatConfig(
        id: "naqt",
        format: .naqt,
        displayName: "NAQT",
        tossupsPerHalf: 12,
        totalTossups: 24,
        bonusesPerMatch: 24,
        scoringRules: .naqt,
        timePerTossup: nil,
        timePerBonus: 5.0,
        timeBetweenParts: 3.0,
        allowsInterruption: true,
        hasPowerMarks: true,
        hasNegativeScoring: true
    )

    static let acf = QBFormatConfig(
        id: "acf",
        format: .acf,
        displayName: "ACF",
        tossupsPerHalf: 10,
        totalTossups: 20,
        bonusesPerMatch: 20,
        scoringRules: .acf,
        timePerTossup: nil,
        timePerBonus: 5.0,
        timeBetweenParts: 3.0,
        allowsInterruption: true,
        hasPowerMarks: true,
        hasNegativeScoring: false
    )

    static let pace = QBFormatConfig(
        id: "pace",
        format: .pace,
        displayName: "PACE",
        tossupsPerHalf: 10,
        totalTossups: 20,
        bonusesPerMatch: 20,
        scoringRules: .pace,
        timePerTossup: nil,
        timePerBonus: 5.0,
        timeBetweenParts: 3.0,
        allowsInterruption: true,
        hasPowerMarks: true,
        hasNegativeScoring: false
    )
}
```

### 2.2 Pyramidal Question Structure

The defining characteristic of Quiz Bowl is the **pyramidal** question structure.

```swift
// MARK: - Pyramidal Question Anatomy

/// A pyramidal question has clues arranged from hardest to easiest
/// The "power mark" indicates where 15-point answers become 10-point

struct PyramidalStructure: Codable {
    /// Full question text (all clues concatenated)
    let fullText: String

    /// Individual clues, ordered hard → easy
    let clues: [PyramidalClue]

    /// Character index where power mark occurs
    /// Answers before this index earn 15 points (NAQT)
    let powerMarkIndex: Int

    /// Estimated word position of each difficulty tier
    let difficultyMap: DifficultyMap
}

struct PyramidalClue: Codable, Identifiable {
    let id: UUID
    let text: String
    let difficulty: ClueDifficulty
    let startIndex: Int         // Character position in full text
    let endIndex: Int

    /// Can this clue standalone as a short question?
    let standaloneUsable: Bool

    /// Topic hints this clue provides
    let topicHints: [String]    // e.g., ["author", "novel", "19th century"]
}

enum ClueDifficulty: String, Codable, CaseIterable {
    case leadIn     // Only experts recognize (5%)
    case early      // Strong players recognize (15%)
    case middle     // Good players recognize (35%)
    case late       // Most competitive players recognize (55%)
    case giveaway   // Almost everyone knows (80%+)

    var approximatePercentile: Int {
        switch self {
        case .leadIn: return 5
        case .early: return 15
        case .middle: return 35
        case .late: return 55
        case .giveaway: return 80
        }
    }
}

struct DifficultyMap: Codable {
    /// Approximate word count at each difficulty transition
    let leadInEnds: Int
    let earlyEnds: Int
    let middleEnds: Int
    let lateEnds: Int
    // giveaway runs to the end
}

// MARK: - Example Pyramidal Question

/*
LEAD-IN: "The protagonist of this work visits the Grand Inquisitor..."
EARLY: "...set in Russia, the youngest of three brothers..."
MIDDLE: "...Fyodor Pavlovich is the patriarch of the family..."
LATE: "...Alyosha and Ivan debate faith and reason..."
GIVEAWAY: "Name this Dostoevsky novel about the Karamazov family."

ANSWER: The Brothers Karamazov
*/
```

### 2.3 Bonus Structure

Bonuses are 3-part collaborative team questions.

```swift
// MARK: - Bonus Questions

struct QBBonus: Codable, Identifiable {
    let id: UUID
    let sourceQuestionId: UUID?

    /// The lead-in that introduces all three parts
    let leadin: String          // "Name these European capitals..."

    /// The three parts
    let parts: [BonusPart]

    /// Primary domain
    let domain: DomainTag

    /// Overall difficulty
    let difficulty: DifficultyTier

    /// Set source
    let source: String?
}

struct BonusPart: Codable, Identifiable {
    let id: UUID
    let index: Int              // 0, 1, 2
    let text: String
    let answer: AnswerSpec
    let pointValue: Int         // Usually 10
    let partDifficulty: BonusPartDifficulty
}

enum BonusPartDifficulty: String, Codable {
    case easy       // ~80% of teams get
    case medium     // ~50% of teams get
    case hard       // ~20% of teams get

    /// Standard bonus structure is E/M/H
    static let standardOrder: [BonusPartDifficulty] = [.easy, .medium, .hard]
}
```

---

## 3. Data Models

### 3.1 Question Models

```swift
// MARK: - Quiz Bowl Tossup

struct QBTossup: CompetitionQuestion, Codable, Identifiable {
    let id: UUID
    let sourceQuestionId: UUID?  // Link to canonical question

    // Pyramidal Content
    let text: String
    let pyramidal: PyramidalStructure
    let answer: AnswerSpec

    // Classification
    let domains: [DomainTag]
    let difficulty: DifficultyTier

    // QB-Specific Metadata
    let setSource: String?          // "2024 NAQT SCT"
    let questionNumber: Int?        // Position in packet
    let yearWritten: Int?

    // Analytics
    let usageCount: Int
    let averageBuzzDepth: Double?   // Where players typically buzz (0-1)
    let powerRate: Double?          // % of correct answers that are powers
}

// MARK: - Quiz Bowl Question Set

struct QBPacket: Codable, Identifiable {
    let id: UUID
    let name: String               // "2024 NAQT SCT Round 5"
    let source: String             // "NAQT"
    let format: QBFormat

    let tossups: [QBTossup]
    let bonuses: [QBBonus]

    let difficulty: DifficultyTier
    let dateWritten: Date?
}
```

### 3.2 Session Models

```swift
// MARK: - QB Practice Session

struct QBPracticeSession: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let startTime: Date
    var endTime: Date?

    let sessionType: QBSessionType
    let formatConfig: QBFormat
    let difficulty: DifficultyTier

    // Results
    var tossupAttempts: [QBTossupAttempt]
    var bonusAttempts: [QBBonusAttempt]
    var summary: QBSessionSummary?
}

enum QBSessionType: String, Codable {
    case tossupDrill            // Solo tossup practice
    case bonusPractice          // Bonus-only practice
    case packetPractice         // Full packet (tossups + bonuses)
    case pyramidalTraining      // Learn to buzz earlier
    case negReduction           // Learn when NOT to buzz
    case speedDrill             // Faster recognition
    case domainDrill            // Focus on one domain
    case matchSimulation        // Simulated match vs AI
}

struct QBTossupAttempt: Codable, Identifiable {
    let id: UUID
    let questionId: UUID
    let timestamp: Date

    // Buzz Timing
    let buzzIndex: Int?             // Character position where buzzed (nil = didn't buzz)
    let buzzDepth: Double?          // Percentage through question (0-1)
    let wasPower: Bool              // Buzzed before power mark?
    let responseTime: TimeInterval  // Time to answer after buzz

    // Response
    let userAnswer: String?
    let wasCorrect: Bool

    // Scoring
    let pointsEarned: Int           // 15, 10, 0, or -5

    // Context
    let wasInterruption: Bool       // Buzzed mid-question?
    let questionCompleted: Bool     // Did question finish reading?
}

struct QBBonusAttempt: Codable, Identifiable {
    let id: UUID
    let bonusId: UUID
    let timestamp: Date

    // Part-by-part results
    let partResults: [BonusPartResult]

    // Overall
    let totalPoints: Int            // 0-30
    let totalCorrect: Int           // 0-3
}

struct BonusPartResult: Codable {
    let partIndex: Int
    let userAnswer: String?
    let wasCorrect: Bool
    let responseTime: TimeInterval
    let pointsEarned: Int
}

// MARK: - Session Summary

struct QBSessionSummary: Codable {
    // Tossup Performance
    let tossupsAttempted: Int
    let tossupsCorrect: Int
    let tossupAccuracy: Double

    // Power/Neg Metrics
    let powers: Int
    let tens: Int
    let negs: Int
    let powerRate: Double           // powers / (powers + tens)
    let negRate: Double             // negs / tossupsAttempted

    // Buzz Metrics
    let averageBuzzDepth: Double    // Lower = better
    let celerity: Double            // NAQT celerity score

    // Bonus Performance
    let bonusesHeard: Int
    let totalBonusPoints: Int
    let bonusConversion: Double     // PPB (points per bonus)

    // Domain Breakdown
    let domainPerformance: [StandardDomain: QBDomainSessionStats]

    // Total Points
    let totalPoints: Int
}

struct QBDomainSessionStats: Codable {
    let tossups: Int
    let correct: Int
    let powers: Int
    let negs: Int
    let averageBuzzDepth: Double
}
```

### 3.3 Analytics Models

```swift
// MARK: - QB Analytics Profile

struct QBAnalyticsProfile: CompetitionSpecificProfile, Codable {
    let competitionFormat = CompetitionFormat.quizBowl
    let userId: UUID
    let lastUpdated: Date

    // Overall Performance
    var totalTossups: Int
    var totalCorrect: Int
    var overallAccuracy: Double

    // Power/Neg Tracking
    var totalPowers: Int
    var totalTens: Int
    var totalNegs: Int
    var powerRate: Double           // powers / (powers + tens)
    var negRate: Double             // negs / totalTossups

    // NAQT-Style Celerity
    /// Measures how early you buzz on questions you get right
    /// Lower = better (buzzing earlier in the question)
    var celerity: Double
    var celerityByDomain: [StandardDomain: Double]

    // Bonus Performance
    var bonusesHeard: Int
    var totalBonusPoints: Int
    var bonusConversion: Double     // PPB
    var bonusConversionByDomain: [StandardDomain: Double]

    // Domain Breakdown
    var domainPerformance: [StandardDomain: QBDomainStats]

    // Difficulty Progression
    var performanceByDifficulty: [DifficultyTier: DifficultyStats]

    // Trends
    var weeklyProgress: [WeeklySnapshot]
}

struct QBDomainStats: Codable {
    let domain: StandardDomain

    // Tossups
    var tossups: Int
    var correct: Int
    var powers: Int
    var negs: Int
    var averageBuzzDepth: Double

    // Bonuses
    var bonusParts: Int
    var bonusPartsCorrect: Int

    // Calculated
    var tossupAccuracy: Double {
        tossups > 0 ? Double(correct) / Double(tossups) : 0
    }
    var bonusAccuracy: Double {
        bonusParts > 0 ? Double(bonusPartsCorrect) / Double(bonusParts) : 0
    }

    var trend: PerformanceTrend
}

struct DifficultyStats: Codable {
    var questionsAttempted: Int
    var questionsCorrect: Int
    var powerRate: Double
    var negRate: Double
    var accuracy: Double {
        questionsAttempted > 0 ? Double(questionsCorrect) / Double(questionsAttempted) : 0
    }
}
```

---

## 4. Core Services

### 4.1 QB Question Service

```swift
// MARK: - QB Question Service

class QBQuestionService {
    private let questionEngine: QuestionEngine
    private let transformer: QBTransformer
    private let packetStore: QBPacketStore

    // ═══════════════════════════════════════════════════════════════════════
    // TOSSUP RETRIEVAL
    // ═══════════════════════════════════════════════════════════════════════

    /// Get tossups for practice
    func getTossups(
        count: Int,
        difficulty: DifficultyTier?,
        domains: [StandardDomain]?,
        excludeRecent: Bool = true
    ) -> [QBTossup] {

        var filters = QuestionFilters()
        filters.domains = domains?.map { PrimaryDomain(from: $0) }
        filters.difficulty = difficulty.map { $0...$0 }
        filters.excludeRecentlyUsed = excludeRecent

        // Get from shared question engine
        let canonicals = questionEngine.query(filters: filters, limit: count * 2)

        // Transform to QB format (only questions with pyramidal content)
        return canonicals
            .compactMap { transformer.transform($0) }
            .prefix(count)
            .map { $0 }
    }

    /// Get bonuses for practice
    func getBonuses(
        count: Int,
        difficulty: DifficultyTier?,
        domains: [StandardDomain]?
    ) -> [QBBonus] {
        // Similar pattern, filtering for bonus-appropriate questions
        return packetStore.queryBonuses(
            count: count,
            difficulty: difficulty,
            domains: domains
        )
    }

    /// Get a complete packet
    func getPacket(difficulty: DifficultyTier) -> QBPacket {
        return packetStore.generatePacket(difficulty: difficulty)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PYRAMIDAL ANALYSIS
    // ═══════════════════════════════════════════════════════════════════════

    /// Analyze where a buzz occurred in the pyramidal structure
    func analyzeBuzz(
        buzzIndex: Int,
        in tossup: QBTossup
    ) -> BuzzAnalysis {

        let pyramidal = tossup.pyramidal
        let buzzDepth = Double(buzzIndex) / Double(pyramidal.fullText.count)

        // Find which clue was being read
        let activeClue = pyramidal.clues.first { clue in
            buzzIndex >= clue.startIndex && buzzIndex <= clue.endIndex
        }

        // Was it a power?
        let wasPower = buzzIndex < pyramidal.powerMarkIndex

        // What difficulty level?
        let difficulty = activeClue?.difficulty ?? .giveaway

        // How does this compare to average?
        let averageDepth = tossup.averageBuzzDepth ?? 0.5
        let relativePerformance = buzzDepth < averageDepth ? "early" : "late"

        return BuzzAnalysis(
            buzzDepth: buzzDepth,
            activeClue: activeClue,
            wasPower: wasPower,
            clueDifficulty: difficulty,
            relativePerformance: relativePerformance,
            averageBuzzDepth: averageDepth
        )
    }
}

struct BuzzAnalysis {
    let buzzDepth: Double
    let activeClue: PyramidalClue?
    let wasPower: Bool
    let clueDifficulty: ClueDifficulty
    let relativePerformance: String
    let averageBuzzDepth: Double
}
```

### 4.2 QB Session Manager

```swift
// MARK: - QB Session Manager

class QBSessionManager {
    private let questionService: QBQuestionService
    private let voicePipeline: UniversalVoicePipeline
    private let analyticsService: QBAnalyticsService
    private let proficiencyStore: ProficiencyStore

    private var currentSession: QBPracticeSession?
    private var currentTossupIndex: Int = 0
    private var currentReadPosition: Int = 0
    private var readingTask: Task<Void, Never>?

    // ═══════════════════════════════════════════════════════════════════════
    // SESSION LIFECYCLE
    // ═══════════════════════════════════════════════════════════════════════

    func startSession(
        type: QBSessionType,
        config: QBSessionConfig
    ) async throws -> QBPracticeSession {

        // Configure voice pipeline for QB
        voicePipeline.configure(for: .quizBowl)

        let session = QBPracticeSession(
            id: UUID(),
            userId: config.userId,
            startTime: Date(),
            sessionType: type,
            formatConfig: config.format,
            difficulty: config.difficulty ?? .competent,
            tossupAttempts: [],
            bonusAttempts: []
        )

        currentSession = session
        return session
    }

    // ═══════════════════════════════════════════════════════════════════════
    // TOSSUP PROCESSING
    // ═══════════════════════════════════════════════════════════════════════

    /// Process a tossup with buzz-in capability
    func processTossup(
        _ tossup: QBTossup,
        format: QBFormatConfig
    ) async -> QBTossupAttempt {

        currentReadPosition = 0

        // Start reading the question (interruptible)
        readingTask = Task {
            await readTossupInterruptible(tossup)
        }

        // Wait for buzz or question completion
        let buzzResult = await waitForBuzzOrCompletion(
            tossup: tossup,
            format: format
        )

        // If they buzzed
        if let buzzIndex = buzzResult.buzzIndex {
            // Stop reading
            readingTask?.cancel()

            // Get their answer
            let answerResult = await voicePipeline.listenForAnswer(timeout: 5.0)

            // Validate
            let isCorrect = validateAnswer(answerResult.transcript, against: tossup.answer)

            // Determine points
            let wasPower = buzzIndex < tossup.pyramidal.powerMarkIndex
            let points: Int
            if isCorrect {
                points = wasPower ? format.scoringRules.powerPoints : format.scoringRules.tenPoints
            } else {
                points = format.scoringRules.negPoints
            }

            let attempt = QBTossupAttempt(
                id: UUID(),
                questionId: tossup.id,
                timestamp: Date(),
                buzzIndex: buzzIndex,
                buzzDepth: Double(buzzIndex) / Double(tossup.text.count),
                wasPower: wasPower,
                responseTime: answerResult.duration,
                userAnswer: answerResult.transcript,
                wasCorrect: isCorrect,
                pointsEarned: points,
                wasInterruption: true,
                questionCompleted: false
            )

            // Record to proficiency
            recordTossupToProficiency(attempt, tossup: tossup)

            return attempt
        }

        // Question completed without buzz
        return QBTossupAttempt(
            id: UUID(),
            questionId: tossup.id,
            timestamp: Date(),
            buzzIndex: nil,
            buzzDepth: nil,
            wasPower: false,
            responseTime: 0,
            userAnswer: nil,
            wasCorrect: false,
            pointsEarned: 0,
            wasInterruption: false,
            questionCompleted: true
        )
    }

    private func readTossupInterruptible(_ tossup: QBTossup) async {
        let words = tossup.text.split(separator: " ")

        for (index, word) in words.enumerated() {
            guard !Task.isCancelled else { break }

            // Update read position (character index)
            currentReadPosition = tossup.text.distance(
                from: tossup.text.startIndex,
                to: tossup.text.range(of: String(word))!.lowerBound
            )

            // Speak word
            await voicePipeline.speakWord(String(word))

            // Brief pause between words
            try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
        }
    }

    private func waitForBuzzOrCompletion(
        tossup: QBTossup,
        format: QBFormatConfig
    ) async -> BuzzResult {

        // Listen for buzz signal while reading
        return await withTaskGroup(of: BuzzResult.self) { group in
            // Reading task
            group.addTask {
                await self.readingTask?.value
                return BuzzResult(buzzIndex: nil, buzzTime: nil)
            }

            // Buzz detection task
            group.addTask {
                if let buzz = await self.voicePipeline.detectBuzz() {
                    return BuzzResult(
                        buzzIndex: self.currentReadPosition,
                        buzzTime: buzz.timestamp
                    )
                }
                return BuzzResult(buzzIndex: nil, buzzTime: nil)
            }

            // Return first result (buzz wins if it happens)
            for await result in group {
                if result.buzzIndex != nil {
                    group.cancelAll()
                    return result
                }
            }

            return BuzzResult(buzzIndex: nil, buzzTime: nil)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // BONUS PROCESSING
    // ═══════════════════════════════════════════════════════════════════════

    /// Process a bonus (3 parts)
    func processBonus(
        _ bonus: QBBonus,
        format: QBFormatConfig
    ) async -> QBBonusAttempt {

        var partResults: [BonusPartResult] = []

        // Read lead-in
        await voicePipeline.speak(bonus.leadin)

        // Process each part
        for part in bonus.parts {
            // Read part
            await voicePipeline.speak(part.text)

            // Get answer (timed)
            let startTime = Date()
            let answerResult = await voicePipeline.listenForAnswer(
                timeout: format.timePerBonus
            )
            let responseTime = Date().timeIntervalSince(startTime)

            // Validate
            let isCorrect = validateAnswer(answerResult.transcript, against: part.answer)

            let partResult = BonusPartResult(
                partIndex: part.index,
                userAnswer: answerResult.transcript,
                wasCorrect: isCorrect,
                responseTime: responseTime,
                pointsEarned: isCorrect ? part.pointValue : 0
            )

            partResults.append(partResult)

            // Announce result
            if isCorrect {
                await voicePipeline.speak("Correct")
            } else {
                await voicePipeline.speak("The answer was \(part.answer.primary)")
            }

            // Brief pause between parts
            try? await Task.sleep(nanoseconds: UInt64(format.timeBetweenParts * 1_000_000_000))
        }

        let totalPoints = partResults.reduce(0) { $0 + $1.pointsEarned }
        let totalCorrect = partResults.filter { $0.wasCorrect }.count

        return QBBonusAttempt(
            id: UUID(),
            bonusId: bonus.id,
            timestamp: Date(),
            partResults: partResults,
            totalPoints: totalPoints,
            totalCorrect: totalCorrect
        )
    }
}

struct BuzzResult {
    let buzzIndex: Int?
    let buzzTime: Date?
}

struct QBSessionConfig {
    let userId: UUID
    let format: QBFormat
    let difficulty: DifficultyTier?
    let questionCount: Int
    let domains: [StandardDomain]?
    let includeBonuses: Bool
}
```

### 4.3 QB Transformer

```swift
// MARK: - QB Question Transformer

struct QBTransformer: QuestionTransformer {
    typealias Output = QBTossup

    func transform(_ canonical: CanonicalQuestion) -> QBTossup? {
        guard isCompatible(canonical) else { return nil }

        // Extract pyramidal structure
        let pyramidal = extractPyramidalStructure(from: canonical)

        return QBTossup(
            id: UUID(),
            sourceQuestionId: canonical.id,
            text: canonical.content.pyramidalFull,
            pyramidal: pyramidal,
            answer: canonical.answer,
            domains: canonical.domains,
            difficulty: canonical.difficulty.competitionRelative[.quizBowl]?.tier ?? .competent,
            setSource: canonical.metadata.source,
            questionNumber: nil,
            yearWritten: canonical.metadata.yearWritten,
            usageCount: canonical.metadata.usageCount,
            averageBuzzDepth: nil,
            powerRate: nil
        )
    }

    func isCompatible(_ canonical: CanonicalQuestion) -> Bool {
        // Must have pyramidal content (100+ characters)
        return canonical.content.pyramidalFull.count > 100 ||
               (canonical.content.clues?.count ?? 0) >= 3
    }

    func qualityScore(_ canonical: CanonicalQuestion) -> Double {
        var score = 0.5

        // Prefer questions with explicit clue breakdown
        if let clues = canonical.content.clues, clues.count >= 4 {
            score += 0.2
        }

        // Prefer questions with power mark defined
        if canonical.content.powerMarkIndex != nil {
            score += 0.1
        }

        // Prefer longer pyramidal content
        if canonical.content.pyramidalFull.count > 300 {
            score += 0.1
        }

        // QB-common domains get bonus
        let qbCommonDomains: Set<PrimaryDomain> = [
            .literature, .history, .science, .fineArts, .mythology
        ]
        if canonical.domains.contains(where: { qbCommonDomains.contains($0.primary) }) {
            score += 0.1
        }

        return min(1.0, score)
    }

    func canonicalize(_ tossup: QBTossup) -> CanonicalQuestion {
        return CanonicalQuestion(
            id: tossup.sourceQuestionId ?? UUID(),
            version: 1,
            createdAt: Date(),
            updatedAt: Date(),
            content: QuestionContent(
                pyramidalFull: tossup.text,
                mediumForm: extractMediumForm(from: tossup),
                shortForm: extractGiveaway(from: tossup),
                clues: tossup.pyramidal.clues,
                powerMarkIndex: tossup.pyramidal.powerMarkIndex
            ),
            answer: tossup.answer,
            metadata: QuestionMetadata(/* ... */),
            domains: tossup.domains,
            difficulty: DifficultyRating(/* ... */),
            compatibleFormats: [.quizBowl, .knowledgeBowl],
            transformationHints: TransformationHints()
        )
    }

    private func extractPyramidalStructure(from canonical: CanonicalQuestion) -> PyramidalStructure {
        let text = canonical.content.pyramidalFull
        let clues = canonical.content.clues ?? []

        // Estimate power mark if not defined (typically ~40% through)
        let powerMark = canonical.content.powerMarkIndex ?? Int(Double(text.count) * 0.4)

        return PyramidalStructure(
            fullText: text,
            clues: clues,
            powerMarkIndex: powerMark,
            difficultyMap: estimateDifficultyMap(text: text)
        )
    }

    private func estimateDifficultyMap(text: String) -> DifficultyMap {
        let wordCount = text.split(separator: " ").count

        return DifficultyMap(
            leadInEnds: Int(Double(wordCount) * 0.15),
            earlyEnds: Int(Double(wordCount) * 0.35),
            middleEnds: Int(Double(wordCount) * 0.55),
            lateEnds: Int(Double(wordCount) * 0.80)
        )
    }

    private func extractMediumForm(from tossup: QBTossup) -> String {
        // Use last 3-4 clues for medium form
        let clues = tossup.pyramidal.clues
        let mediumClues = clues.suffix(min(4, clues.count))
        return mediumClues.map { $0.text }.joined(separator: " ")
    }

    private func extractGiveaway(from tossup: QBTossup) -> String {
        // Use last clue as giveaway
        return tossup.pyramidal.clues.last?.text ?? tossup.text.suffix(100).description
    }
}
```

---

## 5. Training Modes

### 5.1 Training Mode Definitions

```swift
// MARK: - QB Training Modes

enum QBTrainingMode {
    /// Solo tossup practice with immediate feedback
    case tossupDrill(TossupDrillConfig)

    /// Bonus practice (team collaboration simulation)
    case bonusPractice(BonusPracticeConfig)

    /// Full packet practice
    case packetPractice(PacketConfig)

    /// Learn to buzz earlier on questions you know
    case pyramidalTraining(PyramidalConfig)

    /// Learn when NOT to buzz (neg reduction)
    case negReduction(NegReductionConfig)

    /// Faster recognition
    case speedDrill(SpeedConfig)

    /// Domain-focused drilling
    case domainDrill(DomainDrillConfig)

    /// Match simulation vs AI opponent
    case matchSimulation(MatchSimConfig)
}

struct TossupDrillConfig {
    let questionCount: Int
    let difficulty: DifficultyTier?
    let domains: [StandardDomain]?
    let format: QBFormat
    let showClueBreakdown: Bool     // Highlight clue transitions
    let allowReplay: Bool           // Replay question after answer
}

struct PyramidalConfig {
    /// Target buzz depth (0.4 = aim to buzz 40% through question)
    let targetBuzzDepth: Double

    /// Show where top players typically buzz
    let showOptimalBuzzPoint: Bool

    /// Show clue difficulty as question is read
    let showDifficultyIndicator: Bool

    /// Track improvement over time
    let trackProgress: Bool

    /// Start easier, get harder
    let difficultyProgression: Bool
}

struct NegReductionConfig {
    /// Require confidence rating before allowing buzz
    let showConfidencePrompt: Bool

    /// Show point cost of potential neg
    let showPenaltyWarning: Bool

    /// Extra study on questions where user negged
    let reviewNeggedQuestions: Bool

    /// Historical neg rate for context
    let showNegRate: Bool
}

struct PacketConfig {
    let format: QBFormat
    let difficulty: DifficultyTier
    let includeBonuses: Bool
    let trackAsMatch: Bool          // Track full match stats
}

struct MatchSimConfig {
    let format: QBFormat
    let opponentStrength: OpponentStrength
    let opponentPersonality: OpponentPersonality

    enum OpponentStrength: String, Codable {
        case beginner       // Buzzes late, low accuracy
        case intermediate   // Average timing and accuracy
        case advanced       // Early buzzer, high accuracy
        case elite          // Buzzes on lead-ins, rarely misses
    }

    enum OpponentPersonality: String, Codable {
        case conservative   // Only buzzes when sure
        case aggressive     // Takes risks
        case balanced       // Mixed strategy
        case specialist     // Strong in specific domains
    }
}
```

### 5.2 Pyramidal Training Protocol

The core differentiating feature of QB training.

```swift
// MARK: - Pyramidal Training Protocol

struct PyramidalTrainingProtocol: TrainingProtocol {
    let id = UUID()
    let name = "Power Hunting"
    let description = "Learn to recognize answers from earlier clues and earn more power points"
    let applicableCompetitions: Set<CompetitionFormat> = [.quizBowl]
    let requiredCapabilities: Set<TrainingCapability> = [.voiceInput, .voiceOutput, .buzzerSimulation]

    func createSession(config: TrainingSessionConfig) -> TrainingSession {
        return PyramidalTrainingSession(config: config)
    }
}

class PyramidalTrainingSession: TrainingSession {
    private let config: PyramidalConfig
    private var currentQuestion: QBTossup?
    private var buzzHistory: [BuzzHistoryEntry] = []

    struct BuzzHistoryEntry {
        let questionId: UUID
        let buzzDepth: Double
        let wasCorrect: Bool
        let clueDifficulty: ClueDifficulty
    }

    /// Run training with progressive clue reveal
    func runProgressiveClueTraining(_ tossup: QBTossup) async -> PyramidalTrainingResult {
        let pyramidal = tossup.pyramidal
        var revealedClues: [PyramidalClue] = []

        for clue in pyramidal.clues {
            // Reveal next clue
            revealedClues.append(clue)

            // Speak the clue
            await voicePipeline.speak(clue.text)

            // Show difficulty indicator
            updateUI(revealedClues: revealedClues, currentDifficulty: clue.difficulty)

            // Check for buzz
            if let buzz = await voicePipeline.detectBuzz(timeout: 0.5) {
                // They buzzed!
                let result = await processEarlyBuzz(
                    at: clue,
                    in: tossup,
                    revealedClues: revealedClues
                )
                return result
            }
        }

        // Question finished without buzz
        return PyramidalTrainingResult(
            buzzed: false,
            buzzDepth: 1.0,
            clueDifficulty: .giveaway,
            wasCorrect: false,
            feedback: "You let this one go. Review the earlier clues to find recognition points."
        )
    }

    private func processEarlyBuzz(
        at clue: PyramidalClue,
        in tossup: QBTossup,
        revealedClues: [PyramidalClue]
    ) async -> PyramidalTrainingResult {

        let answerResult = await voicePipeline.listenForAnswer(timeout: 5.0)
        let isCorrect = validateAnswer(answerResult.transcript, against: tossup.answer)

        let buzzDepth = Double(revealedClues.count) / Double(tossup.pyramidal.clues.count)

        // Generate feedback
        let feedback: String
        if isCorrect {
            if clue.difficulty == .leadIn || clue.difficulty == .early {
                feedback = "Excellent! You recognized this from an early clue. Keep building that pattern recognition."
            } else if clue.difficulty == .middle {
                feedback = "Good buzz! You're getting earlier. Look for the clues that tipped you off."
            } else {
                feedback = "Correct, but you could have buzzed earlier. Review the earlier clues."
            }
        } else {
            feedback = "Incorrect. The answer was \(tossup.answer.primary). Be more careful at this depth."
        }

        return PyramidalTrainingResult(
            buzzed: true,
            buzzDepth: buzzDepth,
            clueDifficulty: clue.difficulty,
            wasCorrect: isCorrect,
            feedback: feedback
        )
    }
}

struct PyramidalTrainingResult {
    let buzzed: Bool
    let buzzDepth: Double
    let clueDifficulty: ClueDifficulty
    let wasCorrect: Bool
    let feedback: String
}
```

### 5.3 Neg Reduction Protocol

```swift
// MARK: - Neg Reduction Protocol

struct NegReductionProtocol: TrainingProtocol {
    let id = UUID()
    let name = "Confidence Calibration"
    let description = "Learn to recognize the difference between 'I know this' and 'I might know this'"
    let applicableCompetitions: Set<CompetitionFormat> = [.quizBowl]
    let requiredCapabilities: Set<TrainingCapability> = [.voiceInput, .voiceOutput, .buzzerSimulation]

    func createSession(config: TrainingSessionConfig) -> TrainingSession {
        return NegReductionSession(config: config)
    }
}

class NegReductionSession: TrainingSession {
    private var confidenceHistory: [ConfidenceCalibrationEntry] = []

    struct ConfidenceCalibrationEntry {
        let statedConfidence: ConfidenceLevel
        let wasCorrect: Bool
    }

    enum ConfidenceLevel: Int, CaseIterable {
        case certain = 3      // "I definitely know this"
        case likely = 2       // "I think I know this"
        case maybe = 1        // "I might know this"
        case guess = 0        // "This is a guess"

        var expectedAccuracy: Double {
            switch self {
            case .certain: return 0.95
            case .likely: return 0.75
            case .maybe: return 0.50
            case .guess: return 0.25
            }
        }
    }

    /// Run confidence-calibrated practice
    func runCalibrationTraining(_ tossup: QBTossup) async -> ConfidenceCalibrationResult {

        // Read question
        await readTossupFull(tossup)

        // Check if they want to buzz
        guard await userWantsToBuzz() else {
            return ConfidenceCalibrationResult(
                buzzed: false,
                confidence: nil,
                wasCorrect: false,
                calibrationFeedback: "You correctly held off on a question you weren't sure about."
            )
        }

        // Get confidence rating BEFORE answer
        let confidence = await promptForConfidence()

        // Now get their answer
        let answerResult = await voicePipeline.listenForAnswer(timeout: 5.0)
        let isCorrect = validateAnswer(answerResult.transcript, against: tossup.answer)

        // Track calibration
        confidenceHistory.append(ConfidenceCalibrationEntry(
            statedConfidence: confidence,
            wasCorrect: isCorrect
        ))

        // Generate calibration feedback
        let feedback = generateCalibrationFeedback(
            confidence: confidence,
            wasCorrect: isCorrect
        )

        return ConfidenceCalibrationResult(
            buzzed: true,
            confidence: confidence,
            wasCorrect: isCorrect,
            calibrationFeedback: feedback
        )
    }

    private func promptForConfidence() async -> ConfidenceLevel {
        // UI prompt: "How confident are you?"
        // Options: Certain / Likely / Maybe / Guess
        // Returns user selection
        return .likely  // Placeholder
    }

    private func generateCalibrationFeedback(
        confidence: ConfidenceLevel,
        wasCorrect: Bool
    ) -> String {

        // Analyze historical calibration
        let sameConfidenceEntries = confidenceHistory.filter { $0.statedConfidence == confidence }
        let actualAccuracy = sameConfidenceEntries.isEmpty ? nil :
            Double(sameConfidenceEntries.filter { $0.wasCorrect }.count) / Double(sameConfidenceEntries.count)

        if let actual = actualAccuracy {
            let expected = confidence.expectedAccuracy
            let calibrationDiff = actual - expected

            if abs(calibrationDiff) < 0.1 {
                return "Your confidence is well-calibrated at this level!"
            } else if calibrationDiff > 0.1 {
                return "You're underconfident! When you say '\(confidence)', you're actually right \(Int(actual * 100))% of the time."
            } else {
                return "You're overconfident at '\(confidence)'. Your actual accuracy is \(Int(actual * 100))%, not \(Int(expected * 100))%."
            }
        }

        // Not enough data yet
        if wasCorrect {
            return "Correct! Keep tracking your confidence to calibrate."
        } else {
            return "Incorrect. Was your confidence rating accurate?"
        }
    }
}

struct ConfidenceCalibrationResult {
    let buzzed: Bool
    let confidence: NegReductionSession.ConfidenceLevel?
    let wasCorrect: Bool
    let calibrationFeedback: String
}
```

---

## 6. Analytics & Metrics

### 6.1 QB Analytics Service

```swift
// MARK: - QB Analytics Service

class QBAnalyticsService {
    private let proficiencyStore: ProficiencyStore
    private let sessionStore: QBSessionStore

    // ═══════════════════════════════════════════════════════════════════════
    // CELERITY CALCULATION
    // ═══════════════════════════════════════════════════════════════════════

    /// Calculate NAQT-style celerity score
    /// Celerity = average (1 - buzz_depth) for correct answers
    /// Higher = better (buzzing earlier)
    func calculateCelerity(for userId: UUID, period: DateInterval? = nil) -> Double {
        let attempts = sessionStore.getTossupAttempts(for: userId, in: period)

        let correctAttempts = attempts.filter { $0.wasCorrect && $0.buzzDepth != nil }

        guard !correctAttempts.isEmpty else { return 0 }

        let celeritySum = correctAttempts.reduce(0.0) { sum, attempt in
            sum + (1.0 - (attempt.buzzDepth ?? 1.0))
        }

        return celeritySum / Double(correctAttempts.count)
    }

    /// Calculate celerity by domain
    func calculateCelerityByDomain(for userId: UUID) -> [StandardDomain: Double] {
        let attempts = sessionStore.getTossupAttempts(for: userId)

        var domainCelerity: [StandardDomain: (sum: Double, count: Int)] = [:]

        for attempt in attempts where attempt.wasCorrect && attempt.buzzDepth != nil {
            let domain = attempt.domain  // Need to lookup from question
            let celerity = 1.0 - (attempt.buzzDepth ?? 1.0)

            if var existing = domainCelerity[domain] {
                existing.sum += celerity
                existing.count += 1
                domainCelerity[domain] = existing
            } else {
                domainCelerity[domain] = (celerity, 1)
            }
        }

        return domainCelerity.mapValues { $0.sum / Double($0.count) }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PPB (POINTS PER BONUS)
    // ═══════════════════════════════════════════════════════════════════════

    /// Calculate bonus conversion rate (PPB)
    func calculatePPB(for userId: UUID, period: DateInterval? = nil) -> Double {
        let bonusAttempts = sessionStore.getBonusAttempts(for: userId, in: period)

        guard !bonusAttempts.isEmpty else { return 0 }

        let totalPoints = bonusAttempts.reduce(0) { $0 + $1.totalPoints }
        return Double(totalPoints) / Double(bonusAttempts.count)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // INSIGHTS
    // ═══════════════════════════════════════════════════════════════════════

    func generateInsights(for userId: UUID) -> [QBInsight] {
        let analytics = getAnalytics(for: userId)
        var insights: [QBInsight] = []

        // Neg rate analysis
        if analytics.negRate > 0.15 {
            insights.append(QBInsight(
                type: .negWarning,
                title: "High Neg Rate",
                message: "Your neg rate is \(Int(analytics.negRate * 100))%. Focus on confidence calibration before buzzing.",
                priority: .high,
                suggestedAction: .negReductionTraining
            ))
        }

        // Power rate analysis
        if analytics.powerRate < 0.30 && analytics.totalTossups > 50 {
            insights.append(QBInsight(
                type: .powerOpportunity,
                title: "Power Opportunity",
                message: "Only \(Int(analytics.powerRate * 100))% of your correct answers are powers. Try pyramidal training to buzz earlier.",
                priority: .medium,
                suggestedAction: .pyramidalTraining
            ))
        }

        // Bonus conversion
        if analytics.bonusConversion < 15 && analytics.bonusesHeard > 20 {
            insights.append(QBInsight(
                type: .bonusWeakness,
                title: "Bonus Conversion Low",
                message: "Your PPB is \(String(format: "%.1f", analytics.bonusConversion)). Strong teams average 20+. Practice bonuses.",
                priority: .medium,
                suggestedAction: .bonusPractice
            ))
        }

        // Domain weaknesses
        for (domain, stats) in analytics.domainPerformance {
            if stats.tossups > 10 && stats.tossupAccuracy < 0.3 {
                insights.append(QBInsight(
                    type: .domainWeakness,
                    title: "\(domain.rawValue.capitalized) Needs Work",
                    message: "You're at \(Int(stats.tossupAccuracy * 100))% in \(domain.rawValue). Dedicated practice recommended.",
                    priority: .high,
                    suggestedAction: .domainDrill(domain)
                ))
            }
        }

        // Celerity improvement opportunities
        for (domain, celerity) in analytics.celerityByDomain {
            if celerity > 0.5 && analytics.domainPerformance[domain]?.tossupAccuracy ?? 0 > 0.7 {
                insights.append(QBInsight(
                    type: .celerityOpportunity,
                    title: "Buzz Earlier on \(domain.rawValue.capitalized)",
                    message: "You know \(domain.rawValue) well but buzz late. Practice recognizing earlier clues.",
                    priority: .low,
                    suggestedAction: .pyramidalTraining
                ))
            }
        }

        return insights.sorted { $0.priority.rawValue < $1.priority.rawValue }
    }
}

struct QBInsight {
    let type: InsightType
    let title: String
    let message: String
    let priority: Priority

    let suggestedAction: SuggestedAction

    enum InsightType {
        case negWarning
        case powerOpportunity
        case bonusWeakness
        case domainWeakness
        case celerityOpportunity
        case improvement
        case milestone
    }

    enum Priority: Int {
        case critical = 0
        case high = 1
        case medium = 2
        case low = 3
    }

    enum SuggestedAction {
        case negReductionTraining
        case pyramidalTraining
        case bonusPractice
        case domainDrill(StandardDomain)
        case speedTraining
    }
}
```

---

## 7. User Interface

### 7.1 UI Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         QB MODULE UI ARCHITECTURE                            │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                          MAIN DASHBOARD                                 ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   ││
│  │  │   Quick     │  │  Training   │  │   Stats     │  │  Packets    │   ││
│  │  │   Start     │  │   Modes     │  │  Dashboard  │  │  Library    │   ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘   ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                    │                                         │
│         ┌──────────────────────────┼──────────────────────────┐             │
│         ▼                          ▼                          ▼             │
│  ┌─────────────┐           ┌─────────────┐           ┌─────────────┐       │
│  │   Tossup    │           │   Bonus     │           │   Match     │       │
│  │   Session   │           │  Session    │           │ Simulation  │       │
│  │     UI      │           │     UI      │           │     UI      │       │
│  └─────────────┘           └─────────────┘           └─────────────┘       │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                   QB-SPECIFIC COMPONENTS                                ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   ││
│  │  │ Pyramidal   │  │   Power     │  │   Buzz      │  │  Celerity   │   ││
│  │  │ Visualizer  │  │  Indicator  │  │  Analyzer   │  │   Chart     │   ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘   ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Key Views

```swift
// MARK: - Tossup Session View

struct QBTossupSessionView: View {
    @StateObject private var viewModel: QBTossupSessionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Progress + Score
            HStack {
                ProgressView(value: viewModel.progress)
                    .frame(maxWidth: .infinity)

                Text("\(viewModel.currentScore) pts")
                    .font(.headline)
                    .monospacedDigit()
            }
            .padding(.horizontal)

            // Question Display with Pyramidal Highlighting
            PyramidalQuestionView(
                text: viewModel.currentQuestion?.text ?? "",
                readPosition: viewModel.currentReadPosition,
                powerMarkIndex: viewModel.currentQuestion?.pyramidal.powerMarkIndex ?? 0,
                showDifficultyIndicator: viewModel.showDifficultyIndicator
            )

            Spacer()

            // Buzz Button
            BuzzButton(
                isEnabled: viewModel.canBuzz,
                isPower: viewModel.isInPowerZone,
                onBuzz: { viewModel.buzz() }
            )
            .padding()

            // Answer Input (after buzz)
            if viewModel.showAnswerInput {
                VoiceAnswerInputView(
                    isListening: viewModel.isListening,
                    transcript: viewModel.currentTranscript,
                    onSubmit: { viewModel.submitAnswer() }
                )
            }

            // Feedback
            if let feedback = viewModel.currentFeedback {
                TossupFeedbackView(feedback: feedback)
            }
        }
    }
}

// MARK: - Pyramidal Question View

struct PyramidalQuestionView: View {
    let text: String
    let readPosition: Int
    let powerMarkIndex: Int
    let showDifficultyIndicator: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(attributedText)
                    .font(.body)
                    .lineSpacing(4)
                    .padding()
            }
        }
    }

    private var attributedText: AttributedString {
        var attributed = AttributedString(text)

        // Highlight read portion
        if readPosition > 0 {
            let readRange = attributed.startIndex..<attributed.index(attributed.startIndex, offsetByCharacters: min(readPosition, text.count))
            attributed[readRange].foregroundColor = .primary
        }

        // Dim unread portion
        if readPosition < text.count {
            let unreadStart = attributed.index(attributed.startIndex, offsetByCharacters: readPosition)
            attributed[unreadStart...].foregroundColor = .secondary
        }

        // Power zone indicator
        if showDifficultyIndicator && readPosition < powerMarkIndex {
            // Show "POWER ZONE" indicator in UI
        }

        return attributed
    }
}

// MARK: - Buzz Button

struct BuzzButton: View {
    let isEnabled: Bool
    let isPower: Bool
    let onBuzz: () -> Void

    var body: some View {
        Button(action: onBuzz) {
            VStack {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 50))
                Text(isPower ? "BUZZ (15)" : "BUZZ (10)")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .frame(width: 120, height: 120)
            .background(isPower ? Color.yellow : Color.blue)
            .foregroundColor(isPower ? .black : .white)
            .clipShape(Circle())
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Celerity Chart

struct CelerityChartView: View {
    let data: [CelerityDataPoint]
    let domainBreakdown: [StandardDomain: Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Overall celerity trend
            Text("Celerity Over Time")
                .font(.headline)

            Chart(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Celerity", point.celerity)
                )
            }
            .frame(height: 150)

            // By domain
            Text("Celerity by Domain")
                .font(.headline)

            ForEach(domainBreakdown.sorted(by: { $0.value > $1.value }), id: \.key) { domain, celerity in
                HStack {
                    Text(domain.rawValue.capitalized)
                    Spacer()
                    CelerityBar(value: celerity)
                    Text(String(format: "%.2f", celerity))
                        .monospacedDigit()
                }
            }
        }
        .padding()
    }
}

struct CelerityDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let celerity: Double
}

struct CelerityBar: View {
    let value: Double  // 0-1, higher = better

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                Rectangle()
                    .fill(colorForCelerity(value))
                    .frame(width: geometry.size.width * value)
            }
        }
        .frame(width: 100, height: 12)
        .clipShape(Capsule())
    }

    private func colorForCelerity(_ value: Double) -> Color {
        if value > 0.6 { return .green }
        if value > 0.4 { return .yellow }
        return .orange
    }
}
```

---

## 8. watchOS Integration

```swift
// MARK: - watchOS QB Module

/// Watch app focuses on:
/// - Quick tossup practice (no bonus on watch)
/// - Speed drills
/// - Flash cards for clue recognition

struct QBWatchMainView: View {
    @StateObject private var viewModel = QBWatchViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Quick Practice") {
                    NavigationLink("10 Tossups") {
                        QBWatchTossupSessionView(count: 10)
                    }
                    NavigationLink("Speed Drill") {
                        QBWatchSpeedDrillView()
                    }
                }

                Section("Clue Recognition") {
                    NavigationLink("Lead-in Training") {
                        QBWatchClueRecognitionView(difficulty: .leadIn)
                    }
                    NavigationLink("Early Clues") {
                        QBWatchClueRecognitionView(difficulty: .early)
                    }
                }

                Section("Today's Stats") {
                    StatsRow(label: "Tossups", value: "\(viewModel.todayTossups)")
                    StatsRow(label: "Powers", value: "\(viewModel.todayPowers)")
                    StatsRow(label: "Negs", value: "\(viewModel.todayNegs)")
                    StatsRow(label: "Celerity", value: String(format: "%.2f", viewModel.todayCelerity))
                }
            }
            .navigationTitle("Quiz Bowl")
        }
    }
}
```

---

## 9. Implementation Priorities

### 9.1 Phase 1: Core QB Functionality (Weeks 15-17)

| Week | Task | Priority | Deliverable |
|------|------|----------|-------------|
| 15 | QB data models | P0 | `QBTossup.swift`, `QBBonus.swift` |
| 15 | Pyramidal structure | P0 | `PyramidalStructure.swift` |
| 15 | QB transformer | P0 | `QBTransformer.swift` |
| 16 | Question service | P0 | `QBQuestionService.swift` |
| 16 | Session manager | P0 | `QBSessionManager.swift` |
| 16 | Buzz processing | P0 | Interrupt handling |
| 17 | Tossup training | P0 | Tossup mode UI + logic |
| 17 | Bonus training | P0 | Bonus mode UI + logic |

### 9.2 Phase 2: Advanced Features (Week 18)

| Task | Priority | Deliverable |
|------|----------|-------------|
| Pyramidal training mode | P0 | Power hunting |
| Neg reduction mode | P1 | Confidence calibration |
| Celerity calculation | P0 | Analytics |
| Match simulation | P1 | AI opponent |

### 9.3 Success Criteria

| Metric | Target |
|--------|--------|
| Pyramidal parsing accuracy | >95% |
| Buzz detection latency | <100ms |
| Celerity calculation accuracy | 100% |
| Voice recognition accuracy | >90% |
| Power/neg tracking | 100% |

---

## 10. Testing Requirements

### 10.1 Unit Tests

```swift
class QBPyramidalTests: XCTestCase {
    func testPyramidalStructure_clueExtraction() {
        let tossup = createTestTossup()

        XCTAssertGreaterThanOrEqual(tossup.pyramidal.clues.count, 3)
        XCTAssertTrue(tossup.pyramidal.clues.first?.difficulty == .leadIn ||
                      tossup.pyramidal.clues.first?.difficulty == .early)
        XCTAssertEqual(tossup.pyramidal.clues.last?.difficulty, .giveaway)
    }

    func testBuzzAnalysis_powerDetection() {
        let tossup = createTestTossup(powerMarkIndex: 100)

        let earlyBuzz = BuzzAnalysis.analyze(buzzIndex: 50, in: tossup)
        XCTAssertTrue(earlyBuzz.wasPower)

        let lateBuzz = BuzzAnalysis.analyze(buzzIndex: 150, in: tossup)
        XCTAssertFalse(lateBuzz.wasPower)
    }
}

class QBScoringTests: XCTestCase {
    func testNAQTScoring() {
        let rules = QBScoringRules.naqt

        XCTAssertEqual(rules.powerPoints, 15)
        XCTAssertEqual(rules.tenPoints, 10)
        XCTAssertEqual(rules.negPoints, -5)
    }

    func testCelerityCalculation() {
        let attempts = [
            QBTossupAttempt(buzzDepth: 0.3, wasCorrect: true),
            QBTossupAttempt(buzzDepth: 0.5, wasCorrect: true),
            QBTossupAttempt(buzzDepth: 0.2, wasCorrect: false)  // Should be excluded
        ]

        let celerity = calculateCelerity(from: attempts)

        // (1 - 0.3) + (1 - 0.5) / 2 = 0.6
        XCTAssertEqual(celerity, 0.6, accuracy: 0.01)
    }
}
```

---

## Appendix A: Format Comparison

| Feature | NAQT | ACF | PACE |
|---------|------|-----|------|
| Tossups | 24 | 20 | 20 |
| Power points | 15 | 15 | 20 |
| Regular points | 10 | 10 | 10 |
| Neg points | -5 | 0 | 0 |
| Bonus structure | 3x10 | 3x10 | 3x10 |
| Answer time | 5s | 5s | 5s |

---

## Appendix B: Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-17 | Development Team | Initial QB module specification |

---

*This document provides the technical specification for implementing the Quiz Bowl module. For integration patterns, see [MASTER_TECHNICAL_IMPLEMENTATION.md](MASTER_TECHNICAL_IMPLEMENTATION.md).*
