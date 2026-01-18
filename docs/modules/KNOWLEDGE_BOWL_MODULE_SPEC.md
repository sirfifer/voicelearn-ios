# Knowledge Bowl Module Technical Specification

**Module ID:** `com.unamentis.knowledgebowl`
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
let knowledgeBowlManifest = ModuleManifest(
    moduleId: "com.unamentis.knowledgebowl",
    displayName: "Knowledge Bowl",
    version: "1.0.0",
    competition: .knowledgeBowl,
    minimumCoreVersion: "1.0.0",
    optionalModules: [
        "com.unamentis.quizbowl",
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
    bundledQuestionCount: 5000,
    supportedDomains: StandardDomain.allCases,
    supportedRegions: [.colorado, .minnesota, .washington]
)
```

### 1.2 Competition Profile

| Attribute | Value |
|-----------|-------|
| **Geographic Scope** | Colorado, Minnesota, Washington (+ limited elsewhere) |
| **Annual Participants** | ~15,000 students |
| **Grade Levels** | 7th-12th (Junior High + High School divisions) |
| **Voice Percentage** | ~60-70% (oral rounds are voice; written rounds are not) |
| **Match Format** | 3 teams per match |
| **Team Size** | 1-4 active players (varies by state) |
| **Key Organizations** | Colorado KB Foundation, MN Service Cooperatives, WA ESDs |

### 1.3 Related Documents

| Document | Purpose |
|----------|---------|
| [KNOWLEDGE_BOWL_CHAMPIONSHIP_SYSTEM.md](KNOWLEDGE_BOWL_CHAMPIONSHIP_SYSTEM.md) | Complete domain knowledge, training philosophy, pedagogy |
| [MASTER_TECHNICAL_IMPLEMENTATION.md](MASTER_TECHNICAL_IMPLEMENTATION.md) | Platform architecture, shared services |
| [UNIFIED_PROFICIENCY_SYSTEM.md](UNIFIED_PROFICIENCY_SYSTEM.md) | Cross-module proficiency tracking |
| [ACADEMIC_COMPETITION_MODULAR_ARCHITECTURE.md](ACADEMIC_COMPETITION_MODULAR_ARCHITECTURE.md) | Module integration patterns |

---

## 2. Competition Rules & Formats

### 2.1 Regional Configuration

Knowledge Bowl has significant rule variations between states. The module must support all variants.

```swift
// MARK: - Regional Configuration

struct KBRegionalConfig: Codable, Identifiable {
    let id: String
    let region: KBRegion
    let displayName: String

    // Match Format
    let teamsPerMatch: Int
    let teamSize: TeamSizeConfig
    let matchStructure: MatchStructure

    // Oral Round Rules
    let oralRoundConfig: OralRoundConfig

    // Written Round Rules
    let writtenRoundConfig: WrittenRoundConfig

    // Scoring
    let scoringConfig: ScoringConfig
}

enum KBRegion: String, Codable, CaseIterable {
    case colorado
    case coloradoSprings  // Special sub-region with stricter conferring rules
    case minnesota
    case washington
}

struct TeamSizeConfig: Codable {
    let minPlayers: Int
    let maxPlayers: Int
    let activeInWritten: Int      // Usually all
    let activeInOral: Int         // Usually 4

    static let colorado = TeamSizeConfig(
        minPlayers: 1,
        maxPlayers: 4,
        activeInWritten: 4,
        activeInOral: 4
    )

    static let minnesota = TeamSizeConfig(
        minPlayers: 3,
        maxPlayers: 6,
        activeInWritten: 6,
        activeInOral: 4
    )

    static let washington = TeamSizeConfig(
        minPlayers: 3,
        maxPlayers: 5,
        activeInWritten: 5,
        activeInOral: 4
    )
}
```

### 2.2 Conferring Rules

**Critical**: Conferring rules vary significantly between regions.

```swift
struct ConferringConfig: Codable {
    /// Time allowed for team discussion (0 = no time limit)
    let conferenceTimeSeconds: Int

    /// Whether verbal discussion about the answer is allowed
    let verbalConferringAllowed: Bool

    /// Whether hand signals are allowed
    let handSignalsAllowed: Bool

    /// Whether conferring is required (some formats)
    let conferringRequired: Bool

    // MARK: - Regional Presets

    static let colorado = ConferringConfig(
        conferenceTimeSeconds: 15,
        verbalConferringAllowed: false,  // NO discussion about the answer
        handSignalsAllowed: true,
        conferringRequired: false
    )

    static let coloradoSprings = ConferringConfig(
        conferenceTimeSeconds: 15,
        verbalConferringAllowed: false,  // Strictly no verbal
        handSignalsAllowed: true,        // Hand signals REQUIRED
        conferringRequired: false
    )

    static let minnesota = ConferringConfig(
        conferenceTimeSeconds: 15,
        verbalConferringAllowed: true,   // Can discuss
        handSignalsAllowed: true,
        conferringRequired: false
    )

    static let washington = ConferringConfig(
        conferenceTimeSeconds: 15,
        verbalConferringAllowed: true,
        handSignalsAllowed: true,
        conferringRequired: false
    )
}
```

### 2.3 Match Structure

```swift
struct MatchStructure: Codable {
    let teamsPerMatch: Int
    let rounds: [RoundDefinition]
}

struct RoundDefinition: Codable {
    let type: RoundType
    let questionCount: Int
    let timeLimit: TimeInterval?
    let pointsPerQuestion: Int
}

enum RoundType: String, Codable {
    case written       // MCQ, team works together
    case oral          // Buzzer-based, verbal answers
    case tieredOral    // MN: Different difficulty tiers
    case bonus         // Some formats have bonus rounds
}

// MARK: - Regional Match Structures

extension MatchStructure {
    static let coloradoStandard = MatchStructure(
        teamsPerMatch: 3,
        rounds: [
            RoundDefinition(type: .written, questionCount: 60, timeLimit: 900, pointsPerQuestion: 1),
            RoundDefinition(type: .oral, questionCount: 50, timeLimit: nil, pointsPerQuestion: 5)
        ]
    )

    static let minnesotaStandard = MatchStructure(
        teamsPerMatch: 3,
        rounds: [
            RoundDefinition(type: .written, questionCount: 60, timeLimit: 900, pointsPerQuestion: 2),
            RoundDefinition(type: .oral, questionCount: 50, timeLimit: nil, pointsPerQuestion: 5)
        ]
    )

    static let washingtonStandard = MatchStructure(
        teamsPerMatch: 3,
        rounds: [
            RoundDefinition(type: .written, questionCount: 50, timeLimit: 2700, pointsPerQuestion: 2),  // 45 minutes
            RoundDefinition(type: .oral, questionCount: 50, timeLimit: nil, pointsPerQuestion: 5)
        ]
    )
}
```

### 2.4 Scoring System

```swift
struct ScoringConfig: Codable {
    /// Points for correct written answer
    let writtenCorrect: Int

    /// Points for correct oral answer (first team)
    let oralCorrect: Int

    /// Points for correct oral answer (rebound)
    let oralRebound: Int

    /// Penalty for incorrect oral answer (NO penalties in KB)
    let oralIncorrect: Int = 0  // Always 0 - KB has no negs

    /// Minnesota SOS Bonus system
    let sosBonus: SOSBonusConfig?
}

struct SOSBonusConfig: Codable {
    /// Bonus multiplier based on opponent strength
    let enabled: Bool
    let maxMultiplier: Double
}

// MARK: - Regional Scoring

extension ScoringConfig {
    static let colorado = ScoringConfig(
        writtenCorrect: 1,
        oralCorrect: 5,
        oralRebound: 5,
        sosBonus: nil
    )

    static let minnesota = ScoringConfig(
        writtenCorrect: 2,
        oralCorrect: 5,
        oralRebound: 5,
        sosBonus: SOSBonusConfig(enabled: true, maxMultiplier: 1.5)
    )

    static let washington = ScoringConfig(
        writtenCorrect: 2,
        oralCorrect: 5,
        oralRebound: 5,
        sosBonus: nil
    )
}
```

---

## 3. Data Models

### 3.1 Question Models

```swift
// MARK: - Knowledge Bowl Question

struct KBQuestion: CompetitionQuestion, Codable, Identifiable {
    let id: UUID
    let sourceQuestionId: UUID?  // Link to canonical question

    // Content
    let text: String
    let answer: AnswerSpec

    // Classification
    let domains: [DomainTag]
    let difficulty: DifficultyTier

    // KB-Specific
    let suitability: KBQuestionSuitability
    let estimatedReadTime: TimeInterval

    // Metadata
    let source: String?
    let yearWritten: Int?
    let usageCount: Int
}

struct KBQuestionSuitability: Codable {
    /// Suitable for written round (MCQ possible)
    let forWritten: Bool

    /// Suitable for oral round
    let forOral: Bool

    /// Can be made into multiple choice
    let mcqPossible: Bool

    /// Requires visual aid (equations, diagrams)
    let requiresVisual: Bool
}

// MARK: - Multiple Choice for Written Round

struct KBWrittenQuestion: Codable, Identifiable {
    let id: UUID
    let sourceQuestion: KBQuestion

    let choices: [MCQChoice]
    let correctChoiceIndex: Int

    struct MCQChoice: Codable {
        let label: String       // "A", "B", "C", "D"
        let text: String
        let isCorrect: Bool
    }
}
```

### 3.2 Session Models

```swift
// MARK: - Practice Session

struct KBPracticeSession: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let startTime: Date
    var endTime: Date?

    let sessionType: KBSessionType
    let regionalConfig: KBRegion
    let difficulty: DifficultyTier

    // Results
    var attempts: [KBQuestionAttempt]
    var summary: KBSessionSummary?
}

enum KBSessionType: String, Codable {
    case writtenPractice
    case oralPractice
    case fullMatchSimulation
    case domainDrill
    case speedDrill
    case conferencePractice      // Team conferring training
    case reboundPractice         // Rebound opportunity training
    case mixedReview
}

struct KBQuestionAttempt: Codable, Identifiable {
    let id: UUID
    let questionId: UUID
    let timestamp: Date

    // Response
    let userAnswer: String?
    let selectedChoice: Int?     // For MCQ
    let responseTime: TimeInterval
    let usedConference: Bool     // Did they use conference time?
    let conferenceTime: TimeInterval?

    // Result
    let wasCorrect: Bool
    let pointsEarned: Int

    // Context
    let roundType: RoundType
    let wasRebound: Bool         // Was this a rebound opportunity?
}

struct KBSessionSummary: Codable {
    // Overall
    let totalQuestions: Int
    let totalCorrect: Int
    let totalPoints: Int

    // By Round Type
    let writtenAccuracy: Double?
    let oralAccuracy: Double?

    // Speed Metrics
    let averageResponseTime: TimeInterval
    let averageConferenceTime: TimeInterval?

    // Domain Breakdown
    let domainPerformance: [StandardDomain: DomainSessionStats]
}

struct DomainSessionStats: Codable {
    let attempted: Int
    let correct: Int
    let averageTime: TimeInterval
}
```

### 3.3 Analytics Models

```swift
// MARK: - KB-Specific Analytics

struct KBAnalyticsProfile: CompetitionSpecificProfile, Codable {
    let competitionFormat = CompetitionFormat.knowledgeBowl
    let userId: UUID
    let lastUpdated: Date

    // Overall Performance
    var overallAccuracy: Double
    var totalQuestionsAttempted: Int
    var totalPracticeTime: TimeInterval

    // Round-Specific
    var writtenRoundStats: RoundStats
    var oralRoundStats: RoundStats

    // Conference Efficiency (for regions that allow conferring)
    var conferenceStats: ConferenceStats

    // Rebound Performance
    var reboundStats: ReboundStats

    // Domain Mastery (links to unified proficiency)
    var domainPerformance: [StandardDomain: KBDomainStats]

    // Difficulty Progression
    var performanceByDifficulty: [DifficultyTier: Double]

    // Trends
    var weeklyProgress: [WeeklySnapshot]
}

struct RoundStats: Codable {
    var questionsAttempted: Int
    var questionsCorrect: Int
    var accuracy: Double { questionsAttempted > 0 ? Double(questionsCorrect) / Double(questionsAttempted) : 0 }
    var averageResponseTime: TimeInterval
}

struct ConferenceStats: Codable {
    /// How often conferring leads to correct answer
    var conferenceSuccessRate: Double

    /// Average time used when conferring
    var averageConferenceTime: TimeInterval

    /// Accuracy when conferring vs not conferring
    var accuracyWithConference: Double
    var accuracyWithoutConference: Double

    /// Efficiency: Did conferring help?
    var conferenceEfficiency: Double {
        accuracyWithConference - accuracyWithoutConference
    }
}

struct ReboundStats: Codable {
    /// Success rate on rebound opportunities
    var reboundSuccessRate: Double

    /// How many rebound opportunities seen
    var reboundOpportunities: Int

    /// How many converted
    var reboundsConverted: Int

    /// Strategic holds: When user intentionally didn't buzz to let opponents miss
    var strategicHoldsAttempted: Int
    var strategicHoldsSuccessful: Int
}

struct KBDomainStats: Codable {
    let domain: StandardDomain
    var questionsAttempted: Int
    var questionsCorrect: Int
    var writtenAccuracy: Double
    var oralAccuracy: Double
    var averageResponseTime: TimeInterval
    var trend: PerformanceTrend
}
```

---

## 4. Core Services

### 4.1 KB Question Service

```swift
// MARK: - KB Question Service

class KBQuestionService {
    private let questionEngine: QuestionEngine
    private let transformer: KBTransformer

    // ═══════════════════════════════════════════════════════════════════════
    // QUESTION RETRIEVAL
    // ═══════════════════════════════════════════════════════════════════════

    /// Get questions for a practice session
    func getQuestions(
        count: Int,
        for sessionType: KBSessionType,
        difficulty: DifficultyTier?,
        domains: [StandardDomain]?,
        region: KBRegion
    ) -> [KBQuestion] {

        var filters = QuestionFilters()
        filters.domains = domains?.map { PrimaryDomain(from: $0) }
        filters.difficulty = difficulty.map { $0...$0 }

        // Get from shared question engine
        let canonicals = questionEngine.query(filters: filters, limit: count * 2)

        // Transform to KB format
        return canonicals
            .compactMap { transformer.transform($0) }
            .filter { question in
                switch sessionType {
                case .writtenPractice:
                    return question.suitability.forWritten
                case .oralPractice, .fullMatchSimulation:
                    return question.suitability.forOral
                default:
                    return true
                }
            }
            .prefix(count)
            .map { $0 }
    }

    /// Get questions for written round (with MCQ conversion)
    func getWrittenQuestions(
        count: Int,
        difficulty: DifficultyTier?,
        domains: [StandardDomain]?
    ) -> [KBWrittenQuestion] {

        let baseQuestions = getQuestions(
            count: count,
            for: .writtenPractice,
            difficulty: difficulty,
            domains: domains,
            region: .colorado  // Written format is similar across regions
        )

        return baseQuestions.compactMap { convertToMCQ($0) }
    }

    private func convertToMCQ(_ question: KBQuestion) -> KBWrittenQuestion? {
        guard question.suitability.mcqPossible else { return nil }

        // Generate distractors
        let distractors = generateDistractors(for: question, count: 3)

        var choices = distractors.map { MCQChoice(label: "", text: $0, isCorrect: false) }
        choices.append(MCQChoice(label: "", text: question.answer.primary, isCorrect: true))
        choices.shuffle()

        // Assign labels
        let labels = ["A", "B", "C", "D"]
        for i in 0..<choices.count {
            choices[i] = MCQChoice(
                label: labels[i],
                text: choices[i].text,
                isCorrect: choices[i].isCorrect
            )
        }

        let correctIndex = choices.firstIndex { $0.isCorrect } ?? 0

        return KBWrittenQuestion(
            id: UUID(),
            sourceQuestion: question,
            choices: choices,
            correctChoiceIndex: correctIndex
        )
    }
}
```

### 4.2 KB Session Manager

```swift
// MARK: - KB Session Manager

class KBSessionManager {
    private let questionService: KBQuestionService
    private let voicePipeline: UniversalVoicePipeline
    private let analyticsService: KBAnalyticsService
    private let proficiencyStore: ProficiencyStore

    private var currentSession: KBPracticeSession?

    // ═══════════════════════════════════════════════════════════════════════
    // SESSION LIFECYCLE
    // ═══════════════════════════════════════════════════════════════════════

    /// Start a new practice session
    func startSession(
        type: KBSessionType,
        config: KBSessionConfig
    ) async throws -> KBPracticeSession {

        // Configure voice pipeline for KB
        voicePipeline.configure(for: .knowledgeBowl)

        // Get questions
        let questions = questionService.getQuestions(
            count: config.questionCount,
            for: type,
            difficulty: config.difficulty,
            domains: config.domains,
            region: config.region
        )

        let session = KBPracticeSession(
            id: UUID(),
            userId: config.userId,
            startTime: Date(),
            sessionType: type,
            regionalConfig: config.region,
            difficulty: config.difficulty ?? .competent,
            attempts: []
        )

        currentSession = session
        return session
    }

    /// Process a question in the session
    func processQuestion(
        _ question: KBQuestion,
        in session: inout KBPracticeSession,
        config: KBRegionalConfig
    ) async -> KBQuestionAttempt {

        // Speak the question (for oral rounds)
        if session.sessionType != .writtenPractice {
            await voicePipeline.speak(question.text)
        }

        // Start listening/timing
        let startTime = Date()

        // Handle conference period if applicable
        var conferenceTime: TimeInterval? = nil
        if config.oralRoundConfig.conferring.conferenceTimeSeconds > 0 {
            conferenceTime = await handleConferencePeriod(config: config.oralRoundConfig.conferring)
        }

        // Get answer
        let result = await voicePipeline.listenForAnswer(timeout: 5.0)
        let responseTime = Date().timeIntervalSince(startTime)

        // Validate answer
        let isCorrect = validateAnswer(result.transcript, against: question.answer)

        let attempt = KBQuestionAttempt(
            id: UUID(),
            questionId: question.id,
            timestamp: Date(),
            userAnswer: result.transcript,
            selectedChoice: nil,
            responseTime: responseTime,
            usedConference: conferenceTime != nil,
            conferenceTime: conferenceTime,
            wasCorrect: isCorrect,
            pointsEarned: isCorrect ? config.scoringConfig.oralCorrect : 0,
            roundType: .oral,
            wasRebound: false
        )

        // Record to proficiency store
        recordAttemptToProficiency(attempt, question: question)

        return attempt
    }

    private func handleConferencePeriod(config: ConferringConfig) async -> TimeInterval {
        let startTime = Date()

        // Announce conference (if verbal allowed)
        if config.verbalConferringAllowed {
            await voicePipeline.speak("Conference")
        }

        // Wait for conference time or early answer signal
        // ... implementation

        return Date().timeIntervalSince(startTime)
    }

    /// End the current session
    func endSession() async -> KBSessionSummary {
        guard var session = currentSession else {
            fatalError("No active session")
        }

        session.endTime = Date()

        // Generate summary
        let summary = generateSummary(for: session)
        session.summary = summary

        // Update analytics
        await analyticsService.recordSession(session)

        // Clear current session
        currentSession = nil

        return summary
    }
}

struct KBSessionConfig {
    let userId: UUID
    let questionCount: Int
    let difficulty: DifficultyTier?
    let domains: [StandardDomain]?
    let region: KBRegion
}
```

### 4.3 KB Transformer

```swift
// MARK: - KB Question Transformer

struct KBTransformer: QuestionTransformer {
    typealias Output = KBQuestion

    func transform(_ canonical: CanonicalQuestion) -> KBQuestion? {
        guard isCompatible(canonical) else { return nil }

        // Use medium or short form (KB questions are short)
        let text = canonical.content.mediumForm.isEmpty
            ? canonical.content.shortForm
            : canonical.content.mediumForm

        // Determine suitability
        let suitability = KBQuestionSuitability(
            forWritten: true,  // Most KB questions work for written
            forOral: !canonical.metadata.requiresCalculation,
            mcqPossible: canGenerateMCQ(canonical),
            requiresVisual: canonical.metadata.hasFormula
        )

        // Estimate read time (~150 words per minute for competition reading)
        let wordCount = text.split(separator: " ").count
        let readTime = Double(wordCount) / 150.0 * 60.0  // seconds

        return KBQuestion(
            id: UUID(),
            sourceQuestionId: canonical.id,
            text: text,
            answer: canonical.answer,
            domains: canonical.domains,
            difficulty: canonical.difficulty.competitionRelative[.knowledgeBowl]?.tier ?? .competent,
            suitability: suitability,
            estimatedReadTime: readTime,
            source: canonical.metadata.source,
            yearWritten: canonical.metadata.yearWritten,
            usageCount: canonical.metadata.usageCount
        )
    }

    func isCompatible(_ canonical: CanonicalQuestion) -> Bool {
        // KB can use almost any question
        return !canonical.content.shortForm.isEmpty ||
               !canonical.content.mediumForm.isEmpty
    }

    func qualityScore(_ canonical: CanonicalQuestion) -> Double {
        var score = 0.5

        // Prefer questions with medium form (ideal length for KB)
        if !canonical.content.mediumForm.isEmpty { score += 0.2 }

        // Prefer questions that can be MCQ
        if canGenerateMCQ(canonical) { score += 0.1 }

        // Prefer questions without complex formulas (voice-friendly)
        if !canonical.metadata.hasFormula { score += 0.1 }

        // Domain weighting (some domains more common in KB)
        let kbCommonDomains: Set<PrimaryDomain> = [
            .literature, .history, .geography, .science, .currentEvents
        ]
        if canonical.domains.contains(where: { kbCommonDomains.contains($0.primary) }) {
            score += 0.1
        }

        return min(1.0, score)
    }

    func canonicalize(_ question: KBQuestion) -> CanonicalQuestion {
        // Reverse transformation
        return CanonicalQuestion(
            id: question.sourceQuestionId ?? UUID(),
            version: 1,
            createdAt: Date(),
            updatedAt: Date(),
            content: QuestionContent(
                pyramidalFull: "",  // KB doesn't have pyramidal
                mediumForm: question.text,
                shortForm: question.text,
                clues: nil,
                powerMarkIndex: nil
            ),
            answer: question.answer,
            metadata: QuestionMetadata(/* ... */),
            domains: question.domains,
            difficulty: DifficultyRating(/* ... */),
            compatibleFormats: [.knowledgeBowl],
            transformationHints: TransformationHints()
        )
    }

    private func canGenerateMCQ(_ canonical: CanonicalQuestion) -> Bool {
        // Can generate MCQ if answer is a discrete entity (person, place, thing)
        let mcqFriendlyTypes: Set<AnswerType> = [
            .person, .place, .thing, .title, .scientific
        ]
        return mcqFriendlyTypes.contains(canonical.answer.answerType)
    }
}
```

---

## 5. Training Modes

### 5.1 Training Mode Definitions

```swift
// MARK: - KB Training Modes

enum KBTrainingMode {
    /// Practice written round (MCQ format)
    case writtenRound(WrittenConfig)

    /// Practice oral round (voice interface)
    case oralRound(OralConfig)

    /// Full match simulation (written + oral)
    case matchSimulation(MatchSimConfig)

    /// Focus on specific domain
    case domainDrill(DomainDrillConfig)

    /// Speed training for faster recall
    case speedDrill(SpeedConfig)

    /// Team conferring practice
    case conferencePractice(ConferenceConfig)

    /// Rebound opportunity practice
    case reboundPractice(ReboundConfig)

    /// Mixed review (spaced repetition)
    case spacedRepetition(SRConfig)
}

struct WrittenConfig {
    let questionCount: Int
    let timeLimit: TimeInterval
    let difficulty: DifficultyTier?
    let domains: [StandardDomain]?
    let showCorrectAfterEach: Bool  // Show answer after each question
}

struct OralConfig {
    let questionCount: Int
    let difficulty: DifficultyTier?
    let domains: [StandardDomain]?
    let simulateConference: Bool
    let conferenceTime: TimeInterval
    let speakingRate: Float
    let includeRebounds: Bool
}

struct MatchSimConfig {
    let region: KBRegion
    let difficulty: DifficultyTier
    let simulateOpponents: Bool
    let opponentStrength: OpponentStrength

    enum OpponentStrength: String, Codable {
        case weak       // New teams
        case average    // Regional level
        case strong     // State level
        case elite      // Championship level
    }
}

struct DomainDrillConfig {
    let targetDomain: StandardDomain
    let questionCount: Int
    let difficulty: DifficultyTier?
    let mixedSubdomains: Bool
}

struct SpeedConfig {
    let startingTimeLimit: TimeInterval
    let minimumTimeLimit: TimeInterval
    let decrementPerQuestion: TimeInterval
    let questionCount: Int
}

struct ConferenceConfig {
    let region: KBRegion  // Determines if verbal allowed
    let startingConferenceTime: TimeInterval
    let targetConferenceTime: TimeInterval  // Goal to reduce to
    let progressiveReduction: Bool
}

struct ReboundConfig {
    let reboundProbability: Double  // How often to simulate rebound opportunity
    let questionCount: Int
    let strategicHoldTraining: Bool  // Practice intentionally not buzzing
}
```

### 5.2 Training Protocol Implementations

```swift
// MARK: - KB-Specific Training Protocols

struct KBWrittenRoundProtocol: TrainingProtocol {
    let id = UUID()
    let name = "Written Round Practice"
    let description = "Practice multiple-choice questions under time pressure"
    let applicableCompetitions: Set<CompetitionFormat> = [.knowledgeBowl]
    let requiredCapabilities: Set<TrainingCapability> = [.writtenInterface, .timerSystem]

    func createSession(config: TrainingSessionConfig) -> TrainingSession {
        return KBWrittenSession(config: config)
    }
}

struct KBOralRoundProtocol: TrainingProtocol {
    let id = UUID()
    let name = "Oral Round Practice"
    let description = "Practice buzzer-based questions with voice answers"
    let applicableCompetitions: Set<CompetitionFormat> = [.knowledgeBowl]
    let requiredCapabilities: Set<TrainingCapability> = [.voiceInput, .voiceOutput, .buzzerSimulation]

    func createSession(config: TrainingSessionConfig) -> TrainingSession {
        return KBOralSession(config: config)
    }
}

struct KBConferenceProtocol: TrainingProtocol {
    let id = UUID()
    let name = "Conference Efficiency Training"
    let description = "Optimize the 15-second team discussion window"
    let applicableCompetitions: Set<CompetitionFormat> = [.knowledgeBowl]
    let requiredCapabilities: Set<TrainingCapability> = [.voiceInput, .voiceOutput, .timerSystem]

    /// For solo practice: Focus on decision speed
    /// For team practice: Focus on communication efficiency
    let soloMode: Bool

    func createSession(config: TrainingSessionConfig) -> TrainingSession {
        return KBConferenceSession(config: config, soloMode: soloMode)
    }
}

struct KBReboundProtocol: TrainingProtocol {
    let id = UUID()
    let name = "Rebound Opportunity Training"
    let description = "Capitalize on opponents' mistakes"
    let applicableCompetitions: Set<CompetitionFormat> = [.knowledgeBowl]
    let requiredCapabilities: Set<TrainingCapability> = [.voiceInput, .voiceOutput]

    func createSession(config: TrainingSessionConfig) -> TrainingSession {
        return KBReboundSession(config: config)
    }
}

struct KBHandSignalProtocol: TrainingProtocol {
    let id = UUID()
    let name = "Hand Signal Communication"
    let description = "Practice non-verbal team communication for Colorado Springs teams"
    let applicableCompetitions: Set<CompetitionFormat> = [.knowledgeBowl]
    let requiredCapabilities: Set<TrainingCapability> = [.voiceOutput]

    /// Recommended signal system
    let signalSystem: HandSignalSystem

    struct HandSignalSystem {
        static let standard = HandSignalSystem()

        let signals: [String: String] = [
            "Closed fist": "I know the answer",
            "Flat hand": "Not sure",
            "Point to teammate": "They should answer",
            "Thumbs up": "Agree with current answer",
            "Thumbs down": "Disagree",
            "Raised fingers (1-5)": "Confidence level"
        ]
    }
}
```

---

## 6. Analytics & Metrics

### 6.1 KB Analytics Service

```swift
// MARK: - KB Analytics Service

class KBAnalyticsService {
    private let proficiencyStore: ProficiencyStore
    private let sessionStore: KBSessionStore

    // ═══════════════════════════════════════════════════════════════════════
    // RECORD OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// Record a completed session
    func recordSession(_ session: KBPracticeSession) async {
        // Update session store
        sessionStore.save(session)

        // Update unified proficiency
        for attempt in session.attempts {
            let proficiencyAttempt = QuestionAttempt(
                timestamp: attempt.timestamp,
                moduleId: "com.unamentis.knowledgebowl",
                questionId: attempt.questionId,
                domain: /* lookup domain */,
                subdomain: nil,
                difficulty: session.difficulty,
                wasCorrect: attempt.wasCorrect,
                responseTime: attempt.responseTime,
                competitionMetadata: [
                    "roundType": attempt.roundType.rawValue,
                    "usedConference": attempt.usedConference,
                    "wasRebound": attempt.wasRebound
                ]
            )
            proficiencyStore.recordAttempt(proficiencyAttempt)
        }

        // Update KB-specific analytics
        await updateKBAnalytics(from: session)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // QUERY OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// Get KB analytics profile for user
    func getAnalytics(for userId: UUID) -> KBAnalyticsProfile {
        return sessionStore.getAnalyticsProfile(for: userId)
    }

    /// Get performance by domain
    func getDomainPerformance(for userId: UUID) -> [StandardDomain: KBDomainStats] {
        return sessionStore.getDomainStats(for: userId)
    }

    /// Get conference efficiency metrics
    func getConferenceEfficiency(for userId: UUID) -> ConferenceStats {
        return sessionStore.getConferenceStats(for: userId)
    }

    /// Get rebound performance
    func getReboundPerformance(for userId: UUID) -> ReboundStats {
        return sessionStore.getReboundStats(for: userId)
    }

    /// Get trend data for visualization
    func getTrends(for userId: UUID, period: DateInterval) -> [WeeklySnapshot] {
        return sessionStore.getTrends(for: userId, in: period)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // INSIGHTS
    // ═══════════════════════════════════════════════════════════════════════

    /// Generate actionable insights
    func generateInsights(for userId: UUID) -> [KBInsight] {
        let analytics = getAnalytics(for: userId)
        var insights: [KBInsight] = []

        // Written vs Oral comparison
        if analytics.writtenRoundStats.accuracy > analytics.oralRoundStats.accuracy + 0.15 {
            insights.append(KBInsight(
                type: .performanceGap,
                title: "Oral Round Needs Work",
                message: "Your written accuracy (\(Int(analytics.writtenRoundStats.accuracy * 100))%) is much higher than oral (\(Int(analytics.oralRoundStats.accuracy * 100))%). Focus on oral round practice.",
                priority: .high,
                suggestedAction: .practiceOralRound
            ))
        }

        // Conference efficiency
        if analytics.conferenceStats.conferenceEfficiency < 0.05 {
            insights.append(KBInsight(
                type: .inefficiency,
                title: "Conference Time Not Helping",
                message: "Using conference time isn't improving your accuracy. Practice quicker decision-making.",
                priority: .medium,
                suggestedAction: .practiceConference
            ))
        }

        // Rebound opportunities
        if analytics.reboundStats.reboundSuccessRate < 0.3 && analytics.reboundStats.reboundOpportunities > 20 {
            insights.append(KBInsight(
                type: .missedOpportunity,
                title: "Missing Rebound Opportunities",
                message: "You're converting only \(Int(analytics.reboundStats.reboundSuccessRate * 100))% of rebound opportunities. Practice rebound scenarios.",
                priority: .medium,
                suggestedAction: .practiceRebounds
            ))
        }

        // Domain weaknesses
        let weakDomains = analytics.domainPerformance.filter { $0.value.questionsAttempted > 10 && ($0.value.writtenAccuracy + $0.value.oralAccuracy) / 2 < 0.4 }
        for (domain, stats) in weakDomains {
            insights.append(KBInsight(
                type: .domainWeakness,
                title: "\(domain.rawValue.capitalized) Needs Attention",
                message: "Your accuracy in \(domain.rawValue) is below 40%. Dedicate practice time to this domain.",
                priority: .high,
                suggestedAction: .domainDrill(domain)
            ))
        }

        return insights.sorted { $0.priority.rawValue < $1.priority.rawValue }
    }
}

struct KBInsight {
    let type: InsightType
    let title: String
    let message: String
    let priority: Priority

    let suggestedAction: SuggestedAction

    enum InsightType {
        case performanceGap
        case inefficiency
        case missedOpportunity
        case domainWeakness
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
        case practiceOralRound
        case practiceWrittenRound
        case practiceConference
        case practiceRebounds
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
│                         KB MODULE UI ARCHITECTURE                            │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                          MAIN DASHBOARD                                 ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   ││
│  │  │   Quick     │  │  Training   │  │  Progress   │  │  Settings   │   ││
│  │  │   Start     │  │   Modes     │  │  Analytics  │  │  Regional   │   ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘   ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                    │                                         │
│         ┌──────────────────────────┼──────────────────────────┐             │
│         ▼                          ▼                          ▼             │
│  ┌─────────────┐           ┌─────────────┐           ┌─────────────┐       │
│  │   Written   │           │    Oral     │           │   Match     │       │
│  │   Session   │           │   Session   │           │ Simulation  │       │
│  │     UI      │           │     UI      │           │     UI      │       │
│  └─────────────┘           └─────────────┘           └─────────────┘       │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                       SHARED COMPONENTS                                 ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   ││
│  │  │  Question   │  │   Answer    │  │   Timer     │  │   Results   │   ││
│  │  │   Card      │  │   Input     │  │  Display    │  │   Summary   │   ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘   ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Key Views

```swift
// MARK: - Main Dashboard

struct KBDashboardView: View {
    @StateObject private var viewModel: KBDashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Quick Stats Card
                    QuickStatsCard(stats: viewModel.quickStats)

                    // Quick Start
                    QuickStartSection(
                        onWrittenTap: { viewModel.startQuickWritten() },
                        onOralTap: { viewModel.startQuickOral() }
                    )

                    // Recent Progress
                    RecentProgressSection(sessions: viewModel.recentSessions)

                    // Insights
                    if !viewModel.insights.isEmpty {
                        InsightsSection(insights: viewModel.insights)
                    }

                    // Training Modes
                    TrainingModesGrid(modes: viewModel.availableModes)
                }
                .padding()
            }
            .navigationTitle("Knowledge Bowl")
        }
    }
}

// MARK: - Oral Session View

struct KBOralSessionView: View {
    @StateObject private var viewModel: KBOralSessionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Progress Bar
            ProgressView(value: viewModel.progress)
                .padding(.horizontal)

            // Question Display
            QuestionDisplayView(
                question: viewModel.currentQuestion,
                isReading: viewModel.isReading
            )

            Spacer()

            // Conference Timer (if applicable)
            if viewModel.showConferenceTimer {
                ConferenceTimerView(
                    timeRemaining: viewModel.conferenceTimeRemaining,
                    onSkip: { viewModel.skipConference() }
                )
            }

            // Answer Input
            VoiceAnswerInputView(
                isListening: viewModel.isListening,
                transcript: viewModel.currentTranscript,
                onSubmit: { viewModel.submitAnswer() }
            )

            // Feedback (after answer)
            if let feedback = viewModel.currentFeedback {
                AnswerFeedbackView(feedback: feedback)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("End Session") {
                    viewModel.endSession()
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Written Session View

struct KBWrittenSessionView: View {
    @StateObject private var viewModel: KBWrittenSessionViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Timer
            TimerDisplayView(
                timeRemaining: viewModel.timeRemaining,
                isWarning: viewModel.timeRemaining < 60
            )

            // Question + Choices
            ScrollView {
                VStack(spacing: 20) {
                    Text(viewModel.currentQuestion.text)
                        .font(.title3)
                        .padding()

                    ForEach(viewModel.currentQuestion.choices, id: \.label) { choice in
                        ChoiceButton(
                            choice: choice,
                            isSelected: viewModel.selectedChoice == choice.label,
                            isDisabled: viewModel.hasAnswered
                        ) {
                            viewModel.selectChoice(choice.label)
                        }
                    }
                }
                .padding()
            }

            // Submit Button
            Button(action: { viewModel.submitAnswer() }) {
                Text("Submit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedChoice == nil)
            .padding()
        }
    }
}
```

### 7.3 View Models

```swift
// MARK: - Dashboard View Model

@MainActor
class KBDashboardViewModel: ObservableObject {
    @Published var quickStats: KBQuickStats
    @Published var recentSessions: [KBSessionSummary]
    @Published var insights: [KBInsight]
    @Published var availableModes: [KBTrainingModeInfo]

    private let analyticsService: KBAnalyticsService
    private let sessionManager: KBSessionManager

    init(analyticsService: KBAnalyticsService, sessionManager: KBSessionManager) {
        self.analyticsService = analyticsService
        self.sessionManager = sessionManager
        self.quickStats = KBQuickStats()
        self.recentSessions = []
        self.insights = []
        self.availableModes = KBTrainingModeInfo.allModes
    }

    func loadData() async {
        let userId = getCurrentUserId()

        // Load analytics
        let analytics = analyticsService.getAnalytics(for: userId)

        // Update quick stats
        quickStats = KBQuickStats(
            overallAccuracy: analytics.overallAccuracy,
            writtenAccuracy: analytics.writtenRoundStats.accuracy,
            oralAccuracy: analytics.oralRoundStats.accuracy,
            totalQuestions: analytics.totalQuestionsAttempted,
            streak: calculateStreak()
        )

        // Load recent sessions
        recentSessions = sessionManager.getRecentSessions(for: userId, limit: 5)

        // Generate insights
        insights = analyticsService.generateInsights(for: userId)
    }

    func startQuickWritten() {
        // Navigate to written session with default config
    }

    func startQuickOral() {
        // Navigate to oral session with default config
    }
}

struct KBQuickStats {
    var overallAccuracy: Double = 0
    var writtenAccuracy: Double = 0
    var oralAccuracy: Double = 0
    var totalQuestions: Int = 0
    var streak: Int = 0
}
```

---

## 8. watchOS Integration

### 8.1 Watch App Architecture

```swift
// MARK: - watchOS KB Module

/// Standalone watch training for Knowledge Bowl
/// Focus on: Quick oral practice, flash cards, speed drills

struct KBWatchApp: App {
    var body: some Scene {
        WindowGroup {
            KBWatchMainView()
        }
    }
}

struct KBWatchMainView: View {
    @StateObject private var viewModel = KBWatchViewModel()

    var body: some View {
        NavigationStack {
            List {
                // Quick Practice
                Section("Quick Practice") {
                    NavigationLink("10 Questions") {
                        KBWatchQuickSessionView(questionCount: 10)
                    }
                    NavigationLink("25 Questions") {
                        KBWatchQuickSessionView(questionCount: 25)
                    }
                }

                // Domain Focus
                Section("Domain Drill") {
                    ForEach(viewModel.topDomains, id: \.self) { domain in
                        NavigationLink(domain.rawValue.capitalized) {
                            KBWatchDomainDrillView(domain: domain)
                        }
                    }
                }

                // Flash Cards
                Section("Flash Cards") {
                    NavigationLink("Review Missed") {
                        KBWatchFlashCardsView(mode: .missedQuestions)
                    }
                    NavigationLink("All Topics") {
                        KBWatchFlashCardsView(mode: .allTopics)
                    }
                }

                // Today's Stats
                Section("Today") {
                    StatsRowView(label: "Questions", value: "\(viewModel.todayStats.questionsAnswered)")
                    StatsRowView(label: "Accuracy", value: "\(Int(viewModel.todayStats.accuracy * 100))%")
                }
            }
            .navigationTitle("KB Training")
        }
    }
}
```

### 8.2 Watch-Optimized Training

```swift
// MARK: - Watch Quick Session

struct KBWatchQuickSessionView: View {
    let questionCount: Int
    @StateObject private var viewModel: KBWatchSessionViewModel
    @Environment(\.dismiss) private var dismiss

    init(questionCount: Int) {
        self.questionCount = questionCount
        _viewModel = StateObject(wrappedValue: KBWatchSessionViewModel(questionCount: questionCount))
    }

    var body: some View {
        VStack {
            // Progress
            Text("\(viewModel.currentIndex + 1)/\(questionCount)")
                .font(.caption)

            // Question (scrollable for longer questions)
            ScrollView {
                Text(viewModel.currentQuestion?.text ?? "")
                    .font(.body)
            }
            .frame(maxHeight: 100)

            // Voice Input Button
            Button(action: { viewModel.startListening() }) {
                Image(systemName: viewModel.isListening ? "mic.fill" : "mic")
                    .font(.title)
            }
            .buttonStyle(.bordered)

            // Feedback
            if let result = viewModel.lastResult {
                HStack {
                    Image(systemName: result.wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.wasCorrect ? .green : .red)
                    Text(result.wasCorrect ? "Correct!" : viewModel.currentQuestion?.answer.primary ?? "")
                        .font(.caption)
                }
            }
        }
        .padding()
        .onAppear { viewModel.start() }
    }
}

@MainActor
class KBWatchSessionViewModel: ObservableObject {
    @Published var currentIndex = 0
    @Published var currentQuestion: KBQuestion?
    @Published var isListening = false
    @Published var lastResult: QuestionResult?

    private let questionCount: Int
    private var questions: [KBQuestion] = []
    private let voicePipeline: UniversalVoicePipeline

    init(questionCount: Int) {
        self.questionCount = questionCount
        self.voicePipeline = UniversalVoicePipeline.shared
    }

    func start() {
        // Load questions optimized for watch (shorter questions)
        questions = loadWatchOptimizedQuestions(count: questionCount)
        currentQuestion = questions.first
    }

    func startListening() {
        isListening = true
        Task {
            let result = await voicePipeline.listenForAnswer(timeout: 5.0)
            await processAnswer(result.transcript)
        }
    }

    private func processAnswer(_ answer: String) async {
        guard let question = currentQuestion else { return }

        let wasCorrect = validateAnswer(answer, against: question.answer)
        lastResult = QuestionResult(wasCorrect: wasCorrect)

        isListening = false

        // Brief delay then next question
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        advanceToNext()
    }

    private func advanceToNext() {
        currentIndex += 1
        if currentIndex < questions.count {
            currentQuestion = questions[currentIndex]
            lastResult = nil
        }
    }
}

struct QuestionResult {
    let wasCorrect: Bool
}
```

---

## 9. Implementation Priorities

### 9.1 Phase 1: Core KB Functionality (Weeks 7-10)

| Week | Task | Priority | Deliverable |
|------|------|----------|-------------|
| 7 | KB data models | P0 | `KBQuestion.swift`, `KBSession.swift` |
| 7 | Regional configs | P0 | `KBRegionalConfig.swift` |
| 7 | KB transformer | P0 | `KBTransformer.swift` |
| 8 | Question service | P0 | `KBQuestionService.swift` |
| 8 | Session manager | P0 | `KBSessionManager.swift` |
| 8 | Unit tests | P0 | Test coverage |
| 9 | Written round training | P0 | Written mode UI + logic |
| 9 | Oral round training | P0 | Oral mode UI + logic |
| 10 | Analytics service | P0 | `KBAnalyticsService.swift` |
| 10 | Integration tests | P0 | Integration coverage |

### 9.2 Phase 2: Advanced Features (Weeks 11-12)

| Week | Task | Priority | Deliverable |
|------|------|----------|-------------|
| 11 | Conference training | P1 | Conference mode |
| 11 | Rebound training | P1 | Rebound mode |
| 11 | Match simulation | P1 | Full match mode |
| 12 | Analytics UI | P0 | Progress views |
| 12 | Insights generation | P1 | Insight engine |
| 12 | Domain drill mode | P1 | Domain focus UI |

### 9.3 Phase 3: Polish (Weeks 13-14)

| Week | Task | Priority | Deliverable |
|------|------|----------|-------------|
| 13 | Dashboard UI | P0 | Main dashboard |
| 13 | Settings UI | P0 | Regional config UI |
| 13 | watchOS app | P1 | Watch companion |
| 14 | User testing | P0 | Feedback integration |
| 14 | Performance optimization | P0 | Optimized builds |
| 14 | Documentation | P1 | User guide |

### 9.4 Success Criteria

| Metric | Target | Measurement |
|--------|--------|-------------|
| Written round accuracy tracking | 100% | All answers recorded |
| Oral round accuracy tracking | 100% | All answers recorded |
| Voice recognition accuracy | >90% | Correct transcript rate |
| Question retrieval latency | <200ms | P95 latency |
| Session save reliability | 100% | No data loss |
| Analytics accuracy | 100% | Verified calculations |
| Regional rule compliance | 100% | Manual verification |

---

## 10. Testing Requirements

### 10.1 Unit Tests

```swift
// MARK: - KB Unit Tests

class KBQuestionTests: XCTestCase {

    func testTransformation_canonicalToKB() {
        let canonical = createTestCanonicalQuestion()
        let transformer = KBTransformer()

        let kbQuestion = transformer.transform(canonical)

        XCTAssertNotNil(kbQuestion)
        XCTAssertFalse(kbQuestion!.text.isEmpty)
        XCTAssertEqual(kbQuestion!.answer.primary, canonical.answer.primary)
    }

    func testSuitability_writtenRound() {
        let question = createKBQuestion(forWritten: true, forOral: true)

        XCTAssertTrue(question.suitability.forWritten)
        XCTAssertTrue(question.suitability.forOral)
    }

    func testMCQConversion_validQuestion() {
        let question = createKBQuestion(mcqPossible: true)
        let service = KBQuestionService()

        let mcq = service.convertToMCQ(question)

        XCTAssertNotNil(mcq)
        XCTAssertEqual(mcq!.choices.count, 4)
        XCTAssertTrue(mcq!.choices.contains { $0.isCorrect })
    }
}

class KBRegionalConfigTests: XCTestCase {

    func testColoradoConfig_noVerbalConferring() {
        let config = ConferringConfig.colorado

        XCTAssertFalse(config.verbalConferringAllowed)
        XCTAssertTrue(config.handSignalsAllowed)
        XCTAssertEqual(config.conferenceTimeSeconds, 15)
    }

    func testMinnesotaConfig_verbalConferringAllowed() {
        let config = ConferringConfig.minnesota

        XCTAssertTrue(config.verbalConferringAllowed)
        XCTAssertEqual(config.conferenceTimeSeconds, 15)
    }

    func testWashingtonWrittenTime_45Minutes() {
        let structure = MatchStructure.washingtonStandard
        let writtenRound = structure.rounds.first { $0.type == .written }

        XCTAssertEqual(writtenRound?.timeLimit, 2700)  // 45 minutes
    }
}

class KBAnalyticsTests: XCTestCase {

    func testConferenceEfficiency_calculation() {
        let stats = ConferenceStats(
            conferenceSuccessRate: 0.7,
            averageConferenceTime: 10.0,
            accuracyWithConference: 0.75,
            accuracyWithoutConference: 0.65
        )

        XCTAssertEqual(stats.conferenceEfficiency, 0.10, accuracy: 0.01)
    }

    func testInsightGeneration_oralWeakness() {
        let analytics = createAnalyticsProfile(
            writtenAccuracy: 0.85,
            oralAccuracy: 0.55
        )
        let service = KBAnalyticsService()

        let insights = service.generateInsights(for: analytics.userId)

        XCTAssertTrue(insights.contains { $0.type == .performanceGap })
    }
}
```

### 10.2 Integration Tests

```swift
// MARK: - KB Integration Tests

class KBSessionIntegrationTests: XCTestCase {

    func testOralSession_fullFlow() async throws {
        let sessionManager = KBSessionManager()
        let config = KBSessionConfig(
            userId: UUID(),
            questionCount: 5,
            difficulty: .competent,
            domains: nil,
            region: .colorado
        )

        // Start session
        var session = try await sessionManager.startSession(type: .oralPractice, config: config)
        XCTAssertNotNil(session)

        // Process questions (mocked voice input)
        for _ in 0..<5 {
            // ... process with mock
        }

        // End session
        let summary = await sessionManager.endSession()
        XCTAssertEqual(summary.totalQuestions, 5)
    }

    func testProficiencyUpdate_afterSession() async throws {
        let proficiencyStore = ProficiencyStore.shared
        let initialProfile = proficiencyStore.getProfile()

        // Run a session
        // ...

        let updatedProfile = proficiencyStore.getProfile()
        XCTAssertGreaterThan(
            updatedProfile.totalQuestionsAttempted,
            initialProfile.totalQuestionsAttempted
        )
    }
}
```

---

## Appendix A: Regional Rule Summary

| Rule | Colorado | Minnesota | Washington |
|------|----------|-----------|------------|
| Teams per match | 3 | 3 | 3 |
| Team size | 1-4 | 3-6 | 3-5 |
| Active in oral | 4 | 4 | 4 |
| Written questions | 60 | 60 | 50 |
| Written time | 15 min | 15 min | 45 min |
| Written points | 1 | 2 | 2 |
| Oral questions | 50 | 50 | 50 |
| Oral points | 5 | 5 | 5 |
| Conference time | 15 sec | 15 sec | 15 sec |
| Verbal conferring | **NO** | Yes | Yes |
| Hand signals | Yes | Yes | Yes |
| Negative scoring | No | No | No |
| SOS Bonus | No | Yes | No |

---

## Appendix B: Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-17 | Development Team | Initial KB module specification |

---

*This document provides the technical specification for implementing the Knowledge Bowl module. For detailed domain knowledge, training philosophy, and pedagogical approaches, see [KNOWLEDGE_BOWL_CHAMPIONSHIP_SYSTEM.md](KNOWLEDGE_BOWL_CHAMPIONSHIP_SYSTEM.md).*
