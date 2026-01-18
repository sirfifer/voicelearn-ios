# Unified Proficiency System Specification

## Executive Summary

This document defines the **competition-agnostic proficiency tracking system** that persists user learning data independently of any specific module. The core principle: **the data belongs to the user and survives module installation/uninstallation**.

---

## Design Principles

### 1. Data Sovereignty
- Proficiency data is **owned by the user**, not by any module
- Data persists on the user's device regardless of module status
- User can export their complete proficiency profile at any time

### 2. Module Independence
- Modules are **consumers and contributors** to the proficiency system
- No module "owns" the proficiency data
- Uninstalling a module does NOT delete proficiency data
- Installing a new module automatically sees existing proficiency data

### 3. Standardized Schema
- All modules use the **same data structures** for proficiency tracking
- Enables seamless skill transfer recognition between competitions
- New modules can immediately leverage existing proficiency data

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         USER'S DEVICE                                    │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │              UNIFIED PROFICIENCY STORE (Persistent)                 │ │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                │ │
│  │  │   Domain     │ │   Speed      │ │   History    │                │ │
│  │  │   Mastery    │ │   Metrics    │ │   Log        │                │ │
│  │  └──────────────┘ └──────────────┘ └──────────────┘                │ │
│  │                                                                     │ │
│  │  This data NEVER gets deleted when modules are removed              │ │
│  └─────────────────────────────────┬──────────────────────────────────┘ │
│                                    │                                     │
│                     ┌──────────────┴──────────────┐                     │
│                     │   Proficiency Access API    │                     │
│                     │   (Read/Write Interface)    │                     │
│                     └──────────────┬──────────────┘                     │
│                                    │                                     │
│         ┌──────────────────────────┼──────────────────────────┐         │
│         │                          │                          │         │
│         ▼                          ▼                          ▼         │
│  ┌─────────────┐           ┌─────────────┐           ┌─────────────┐   │
│  │ Knowledge   │           │ Quiz Bowl   │           │ Science     │   │
│  │ Bowl Module │           │ Module      │           │ Bowl Module │   │
│  │ (installed) │           │ (installed) │           │ (disabled)  │   │
│  └─────────────┘           └─────────────┘           └─────────────┘   │
│                                                                          │
│  Even if Science Bowl module is disabled/uninstalled, its proficiency   │
│  contributions remain in the Unified Store and benefit other modules    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Core Data Structures

### 1. Unified Proficiency Profile

This is the **single source of truth** for a user's academic knowledge.

```swift
// MARK: - Core Proficiency Store
// This data structure is SHARED by all modules and persists independently

struct UnifiedProficiencyProfile: Codable {
    let userId: UUID
    let createdAt: Date
    var lastUpdated: Date

    // ═══════════════════════════════════════════════════════════════
    // DOMAIN MASTERY - The heart of cross-module transfer
    // ═══════════════════════════════════════════════════════════════
    var domainMastery: [DomainMasteryRecord]

    // ═══════════════════════════════════════════════════════════════
    // RESPONSE CHARACTERISTICS - Speed, patterns, tendencies
    // ═══════════════════════════════════════════════════════════════
    var responseProfile: ResponseProfile

    // ═══════════════════════════════════════════════════════════════
    // LEARNING HISTORY - Complete audit trail
    // ═══════════════════════════════════════════════════════════════
    var learningHistory: LearningHistory

    // ═══════════════════════════════════════════════════════════════
    // MODULE CONTRIBUTIONS - Track which modules added data
    // ═══════════════════════════════════════════════════════════════
    var moduleContributions: [ModuleContribution]
}
```

### 2. Domain Mastery Record

The **transferable knowledge** that works across all competitions.

```swift
struct DomainMasteryRecord: Codable, Identifiable {
    let id: UUID
    let domain: StandardDomain
    var lastUpdated: Date

    // ═══════════════════════════════════════════════════════════════
    // MASTERY METRICS
    // ═══════════════════════════════════════════════════════════════

    /// Overall mastery score (0-100)
    /// Computed from accuracy, speed, and consistency
    var masteryScore: Double

    /// Statistical confidence in the mastery score
    /// Higher sample size = higher confidence
    var confidence: Double

    /// Number of questions attempted in this domain
    var questionsAttempted: Int

    /// Number of questions answered correctly
    var questionsCorrect: Int

    /// Simple accuracy rate
    var accuracy: Double {
        questionsAttempted > 0 ? Double(questionsCorrect) / Double(questionsAttempted) : 0
    }

    // ═══════════════════════════════════════════════════════════════
    // SUBDOMAIN BREAKDOWN
    // ═══════════════════════════════════════════════════════════════

    /// Detailed breakdown by subdomain
    /// e.g., Science -> Biology, Chemistry, Physics
    var subdomains: [String: SubdomainMastery]

    // ═══════════════════════════════════════════════════════════════
    // DIFFICULTY PROFILING
    // ═══════════════════════════════════════════════════════════════

    /// Performance at different difficulty levels
    var performanceByDifficulty: [DifficultyTier: DifficultyPerformance]

    // ═══════════════════════════════════════════════════════════════
    // TREND TRACKING
    // ═══════════════════════════════════════════════════════════════

    /// Recent performance trend
    var trend: PerformanceTrend

    /// Historical snapshots for trend visualization
    var weeklySnapshots: [WeeklySnapshot]
}

struct SubdomainMastery: Codable {
    var masteryScore: Double
    var questionsAttempted: Int
    var questionsCorrect: Int
    var lastPracticed: Date
}

struct DifficultyPerformance: Codable {
    var questionsAttempted: Int
    var questionsCorrect: Int
    var averageResponseTime: TimeInterval
}

enum PerformanceTrend: String, Codable {
    case improving
    case stable
    case declining
    case insufficient_data
}

struct WeeklySnapshot: Codable {
    let weekStarting: Date
    let masteryScore: Double
    let questionsAttempted: Int
    let accuracy: Double
}
```

### 3. Standard Domain Taxonomy

**Critical**: All modules MUST use this exact taxonomy for domains.

```swift
// MARK: - Standard Domain Taxonomy
// ALL modules must map their questions to these domains
// This enables cross-module proficiency transfer

enum StandardDomain: String, Codable, CaseIterable {
    // ═══════════════════════════════════════════════════════════════
    // CORE ACADEMIC DOMAINS
    // Used by: Quiz Bowl, Knowledge Bowl, Academic Decathlon
    // ═══════════════════════════════════════════════════════════════
    case literature
    case history
    case geography
    case socialScience
    case fineArts
    case music

    // ═══════════════════════════════════════════════════════════════
    // STEM DOMAINS
    // Used by: All competitions, especially Science Bowl
    // ═══════════════════════════════════════════════════════════════
    case biology
    case chemistry
    case physics
    case earthScience
    case astronomy
    case mathematics
    case computerScience
    case engineering

    // ═══════════════════════════════════════════════════════════════
    // SPECIALIZED DOMAINS
    // Used by: Quiz Bowl, Knowledge Bowl
    // ═══════════════════════════════════════════════════════════════
    case religion
    case mythology
    case philosophy

    // ═══════════════════════════════════════════════════════════════
    // GENERAL DOMAINS
    // ═══════════════════════════════════════════════════════════════
    case currentEvents
    case popularCulture
    case general

    // ═══════════════════════════════════════════════════════════════
    // DOMAIN METADATA
    // ═══════════════════════════════════════════════════════════════

    /// Which competitions use this domain significantly
    var relevantCompetitions: [CompetitionType] {
        switch self {
        case .literature, .history, .geography, .fineArts, .music:
            return [.quizBowl, .knowledgeBowl, .academicDecathlon]
        case .biology, .chemistry, .physics, .earthScience, .astronomy, .mathematics:
            return [.quizBowl, .knowledgeBowl, .scienceBowl, .academicDecathlon]
        case .socialScience:
            return [.quizBowl, .knowledgeBowl, .academicDecathlon]
        case .religion, .mythology, .philosophy:
            return [.quizBowl, .knowledgeBowl]
        case .currentEvents, .popularCulture:
            return [.knowledgeBowl]
        case .computerScience, .engineering:
            return [.scienceBowl]
        case .general:
            return CompetitionType.allCases
        }
    }

    /// Typical subdomains within this domain
    var commonSubdomains: [String] {
        switch self {
        case .literature:
            return ["American Literature", "British Literature", "World Literature",
                    "Poetry", "Drama", "Novel", "Short Story", "Classical Literature"]
        case .history:
            return ["American History", "European History", "World History",
                    "Ancient History", "Medieval History", "Modern History",
                    "Military History", "Political History"]
        case .biology:
            return ["Cell Biology", "Genetics", "Ecology", "Anatomy",
                    "Microbiology", "Botany", "Zoology", "Evolution"]
        case .chemistry:
            return ["Organic Chemistry", "Inorganic Chemistry", "Physical Chemistry",
                    "Biochemistry", "Periodic Table", "Chemical Reactions"]
        case .physics:
            return ["Mechanics", "Thermodynamics", "Electromagnetism",
                    "Optics", "Quantum Physics", "Relativity", "Waves"]
        case .mathematics:
            return ["Algebra", "Geometry", "Calculus", "Statistics",
                    "Number Theory", "Trigonometry", "Probability"]
        // ... etc for other domains
        default:
            return []
        }
    }
}

enum CompetitionType: String, Codable, CaseIterable {
    case quizBowl
    case knowledgeBowl
    case scienceBowl
    case historyBowl
    case academicDecathlon
    case other
}
```

### 4. Response Profile

**Speed and behavioral patterns** that transfer across competitions.

```swift
struct ResponseProfile: Codable {
    var lastUpdated: Date

    // ═══════════════════════════════════════════════════════════════
    // SPEED METRICS
    // ═══════════════════════════════════════════════════════════════

    /// Overall average response time
    var averageResponseTime: TimeInterval

    /// Median response time (less affected by outliers)
    var medianResponseTime: TimeInterval

    /// Fastest 10% of responses
    var fastestDecile: TimeInterval

    /// Response speed by domain
    var speedByDomain: [StandardDomain: TimeInterval]

    /// Response speed by difficulty
    var speedByDifficulty: [DifficultyTier: TimeInterval]

    // ═══════════════════════════════════════════════════════════════
    // BEHAVIORAL PATTERNS
    // ═══════════════════════════════════════════════════════════════

    /// Tendency to answer quickly vs. carefully
    var speedAccuracyTradeoff: SpeedAccuracyStyle

    /// Consistency of response times (lower = more consistent)
    var responseTimeVariance: Double

    /// Performance under time pressure
    var pressurePerformance: PressureResponse
}

enum SpeedAccuracyStyle: String, Codable {
    case speedFocused       // Fast answers, accepts some errors
    case balanced           // Moderate speed and accuracy
    case accuracyFocused    // Careful, thorough, slower
    case adaptive           // Changes based on context
}

struct PressureResponse: Codable {
    /// Accuracy when under time pressure vs. relaxed
    var pressureAccuracyDelta: Double  // Negative = worse under pressure

    /// Speed change under pressure
    var pressureSpeedDelta: Double     // Positive = faster under pressure
}

enum DifficultyTier: String, Codable, CaseIterable {
    case novice
    case developing
    case competent
    case advanced
    case expert
}
```

### 5. Learning History

**Complete audit trail** of all learning activities.

```swift
struct LearningHistory: Codable {
    /// Total questions ever attempted across all modules
    var totalQuestionsAttempted: Int

    /// Total time spent practicing (all modules)
    var totalPracticeTime: TimeInterval

    /// First activity date
    var firstActivityDate: Date

    /// Recent activity log (last 1000 entries, for trend analysis)
    var recentActivity: [ActivityLogEntry]

    /// Aggregated statistics by time period
    var periodStats: [PeriodStats]
}

struct ActivityLogEntry: Codable {
    let timestamp: Date
    let sourceModule: String        // Module that recorded this activity
    let domain: StandardDomain
    let subdomain: String?
    let difficulty: DifficultyTier
    let wasCorrect: Bool
    let responseTime: TimeInterval
    let questionId: UUID?           // Optional link to specific question
}

struct PeriodStats: Codable {
    let periodStart: Date
    let periodEnd: Date
    let questionsAttempted: Int
    let questionsCorrect: Int
    let practiceTime: TimeInterval
    let domainsActive: [StandardDomain]
}
```

### 6. Module Contributions

**Track which modules contributed what data**.

```swift
struct ModuleContribution: Codable {
    let moduleId: String            // e.g., "com.unamentis.knowledgebowl"
    let moduleName: String          // e.g., "Knowledge Bowl"

    /// When this module first contributed data
    var firstContribution: Date

    /// Most recent contribution
    var lastContribution: Date

    /// Total questions contributed by this module
    var questionsContributed: Int

    /// Practice time attributed to this module
    var practiceTimeContributed: TimeInterval

    /// Whether this module is currently installed
    /// Note: Even if false, the contributions remain!
    var moduleCurrentlyInstalled: Bool

    /// Domains this module primarily contributed to
    var primaryDomains: [StandardDomain]
}
```

---

## Proficiency Access API

### Core Interface

All modules interact with proficiency data through this API.

```swift
// MARK: - Proficiency Access Protocol
// Every module must use this interface - no direct data access

protocol ProficiencyStore {
    // ═══════════════════════════════════════════════════════════════
    // READ OPERATIONS
    // ═══════════════════════════════════════════════════════════════

    /// Get the complete proficiency profile
    func getProfile() -> UnifiedProficiencyProfile

    /// Get mastery for a specific domain
    func getMastery(for domain: StandardDomain) -> DomainMasteryRecord?

    /// Get mastery across multiple domains
    func getMastery(for domains: [StandardDomain]) -> [DomainMasteryRecord]

    /// Get overall proficiency level (computed from all domains)
    func getOverallProficiency() -> OverallProficiency

    /// Check if user has any prior experience (from any module)
    func hasExistingProficiency() -> Bool

    // ═══════════════════════════════════════════════════════════════
    // WRITE OPERATIONS
    // ═══════════════════════════════════════════════════════════════

    /// Record a question attempt
    func recordAttempt(_ attempt: QuestionAttempt)

    /// Record a practice session
    func recordSession(_ session: PracticeSession)

    /// Update response profile metrics
    func updateResponseMetrics(_ metrics: ResponseMetrics)

    // ═══════════════════════════════════════════════════════════════
    // MODULE LIFECYCLE
    // ═══════════════════════════════════════════════════════════════

    /// Register a module as a contributor
    func registerModule(_ moduleId: String, name: String)

    /// Mark a module as uninstalled (data persists!)
    func markModuleUninstalled(_ moduleId: String)

    /// Mark a module as reinstalled
    func markModuleReinstalled(_ moduleId: String)
}

// MARK: - Data Types for Write Operations

struct QuestionAttempt: Codable {
    let timestamp: Date
    let moduleId: String
    let questionId: UUID?

    let domain: StandardDomain
    let subdomain: String?
    let difficulty: DifficultyTier

    let wasCorrect: Bool
    let responseTime: TimeInterval

    /// Optional: Competition-specific metadata
    let competitionMetadata: [String: AnyCodable]?
}

struct PracticeSession: Codable {
    let sessionId: UUID
    let moduleId: String
    let startTime: Date
    let endTime: Date
    let attempts: [QuestionAttempt]
}

struct ResponseMetrics: Codable {
    let moduleId: String
    let responseTime: TimeInterval
    let wasUnderPressure: Bool
    let domain: StandardDomain
}

struct OverallProficiency: Codable {
    /// Computed overall level (1-100)
    let overallScore: Double

    /// Confidence in the score
    let confidence: Double

    /// Grade level equivalent
    let gradeEquivalent: String  // e.g., "High School - Advanced"

    /// Strongest domains
    let strengths: [StandardDomain]

    /// Weakest domains
    let weaknesses: [StandardDomain]

    /// Summary suitable for display
    let summary: String
}
```

---

## Cross-Module Transfer Logic

### Proficiency Recognition on Module Install

When a new module is installed, it immediately recognizes existing proficiency.

```swift
class ModuleOnboardingService {
    private let proficiencyStore: ProficiencyStore

    /// Called when a new module is installed
    func onboardNewModule(moduleId: String) -> ModuleOnboardingResult {

        // Check for existing proficiency
        guard proficiencyStore.hasExistingProficiency() else {
            return ModuleOnboardingResult(
                status: .newUser,
                message: "Welcome! Let's get started.",
                suggestedStartingLevel: .novice,
                skipAssessment: false
            )
        }

        // Get existing profile
        let profile = proficiencyStore.getProfile()

        // Analyze which domains are relevant to this module
        let relevantDomains = getRelevantDomains(for: moduleId)
        let relevantMastery = proficiencyStore.getMastery(for: relevantDomains)

        // Calculate transfer proficiency
        let transferredProficiency = calculateTransferProficiency(
            from: relevantMastery,
            to: moduleId
        )

        // Identify data sources
        let sources = profile.moduleContributions
            .filter { $0.questionsContributed > 0 }
            .map { $0.moduleName }

        return ModuleOnboardingResult(
            status: .existingUser,
            message: buildWelcomeMessage(transferredProficiency, sources: sources),
            suggestedStartingLevel: transferredProficiency.suggestedLevel,
            skipAssessment: transferredProficiency.confidence > 0.7,
            recognizedStrengths: transferredProficiency.strengths,
            recognizedWeaknesses: transferredProficiency.weaknesses
        )
    }

    private func calculateTransferProficiency(
        from mastery: [DomainMasteryRecord],
        to moduleId: String
    ) -> TransferProficiency {

        // Weight domains by relevance to target module
        let weights = getDomainWeights(for: moduleId)

        var weightedScore = 0.0
        var totalWeight = 0.0
        var strengths: [StandardDomain] = []
        var weaknesses: [StandardDomain] = []

        for record in mastery {
            let weight = weights[record.domain] ?? 0.5
            weightedScore += record.masteryScore * weight
            totalWeight += weight

            if record.masteryScore > 70 {
                strengths.append(record.domain)
            } else if record.masteryScore < 40 && record.questionsAttempted > 10 {
                weaknesses.append(record.domain)
            }
        }

        let averageScore = totalWeight > 0 ? weightedScore / totalWeight : 50.0
        let suggestedLevel = determineSuggestedLevel(score: averageScore)

        // Confidence based on sample size
        let totalQuestions = mastery.reduce(0) { $0 + $1.questionsAttempted }
        let confidence = min(1.0, Double(totalQuestions) / 500.0)

        return TransferProficiency(
            overallScore: averageScore,
            confidence: confidence,
            suggestedLevel: suggestedLevel,
            strengths: strengths,
            weaknesses: weaknesses
        )
    }

    private func buildWelcomeMessage(
        _ proficiency: TransferProficiency,
        sources: [String]
    ) -> String {
        let sourceText = sources.joined(separator: " and ")

        if proficiency.confidence > 0.7 {
            return """
            Welcome! Based on your \(sourceText) experience, we've recognized \
            your proficiency. You're starting at \(proficiency.suggestedLevel.rawValue) level.
            """
        } else {
            return """
            Welcome! We see you have some experience from \(sourceText). \
            We'll start you at \(proficiency.suggestedLevel.rawValue) level, \
            but we'll adjust as we learn more about your abilities.
            """
        }
    }
}

struct ModuleOnboardingResult {
    let status: OnboardingStatus
    let message: String
    let suggestedStartingLevel: DifficultyTier
    let skipAssessment: Bool
    var recognizedStrengths: [StandardDomain] = []
    var recognizedWeaknesses: [StandardDomain] = []

    enum OnboardingStatus {
        case newUser
        case existingUser
    }
}

struct TransferProficiency {
    let overallScore: Double
    let confidence: Double
    let suggestedLevel: DifficultyTier
    let strengths: [StandardDomain]
    let weaknesses: [StandardDomain]
}
```

### Transfer Weight Matrix

How much proficiency transfers between competitions:

```swift
struct TransferWeightMatrix {

    /// Domain weights when transferring FROM Knowledge Bowl TO other modules
    static let fromKnowledgeBowl: [String: [StandardDomain: Double]] = [
        "com.unamentis.quizbowl": [
            .literature: 0.85,    // High transfer - same content
            .history: 0.85,
            .geography: 0.85,
            .biology: 0.80,
            .chemistry: 0.80,
            .physics: 0.80,
            .mathematics: 0.75,
            .fineArts: 0.80,
            .currentEvents: 0.50, // QB has less current events
            .popularCulture: 0.30 // QB rarely covers pop culture
        ],
        "com.unamentis.sciencebowl": [
            .biology: 0.70,       // KB science is less deep than SB
            .chemistry: 0.70,
            .physics: 0.70,
            .mathematics: 0.65,
            .earthScience: 0.65,
            .astronomy: 0.60
            // Other domains: 0 (not relevant to Science Bowl)
        ]
    ]

    /// Domain weights when transferring FROM Quiz Bowl TO other modules
    static let fromQuizBowl: [String: [StandardDomain: Double]] = [
        "com.unamentis.knowledgebowl": [
            .literature: 0.90,    // Very high transfer
            .history: 0.90,
            .geography: 0.90,
            .biology: 0.85,
            .chemistry: 0.85,
            .physics: 0.85,
            .mathematics: 0.80,
            .fineArts: 0.85,
            .religion: 0.80,
            .mythology: 0.85,
            .philosophy: 0.80
        ],
        "com.unamentis.sciencebowl": [
            .biology: 0.75,
            .chemistry: 0.75,
            .physics: 0.75,
            .mathematics: 0.70,
            .earthScience: 0.70,
            .astronomy: 0.70
        ]
    ]

    /// Domain weights when transferring FROM Science Bowl TO other modules
    static let fromScienceBowl: [String: [StandardDomain: Double]] = [
        "com.unamentis.quizbowl": [
            .biology: 0.95,       // SB science is elite for QB
            .chemistry: 0.95,
            .physics: 0.95,
            .mathematics: 0.80,
            .earthScience: 0.90,
            .astronomy: 0.90
        ],
        "com.unamentis.knowledgebowl": [
            .biology: 0.90,
            .chemistry: 0.90,
            .physics: 0.90,
            .mathematics: 0.75,
            .earthScience: 0.85,
            .astronomy: 0.85
        ]
    ]
}
```

---

## Data Persistence Guarantees

### Persistence Rules

```swift
// MARK: - Data Persistence Policy

struct PersistencePolicy {

    /// Core rule: Proficiency data NEVER gets deleted automatically
    static let neverAutoDelete = true

    /// Data can only be deleted by explicit user action
    static let requiresExplicitUserDeletion = true

    /// Minimum retention period (even after user requests deletion)
    /// Allows for "undo" and prevents accidental data loss
    static let minimumRetentionDays = 30

    /// Backup frequency
    static let autoBackupInterval: TimeInterval = 86400 // Daily

    /// Export format
    static let exportFormat = ExportFormat.json
}

// MARK: - Module Lifecycle and Data Persistence

class ProficiencyPersistenceManager {

    /// Called when a module is about to be uninstalled
    func onModuleWillUninstall(moduleId: String) {
        // DO NOT delete any data
        // Simply mark the module as uninstalled
        proficiencyStore.markModuleUninstalled(moduleId)

        // Log the event for transparency
        logEvent(.moduleUninstalled(moduleId))
    }

    /// Called when a module is reinstalled
    func onModuleReinstalled(moduleId: String) {
        // Reactivate the module's association
        proficiencyStore.markModuleReinstalled(moduleId)

        // The module immediately has access to all existing data
        logEvent(.moduleReinstalled(moduleId))
    }

    /// Called when user explicitly requests data deletion
    func onUserRequestsDataDeletion(scope: DeletionScope) {
        switch scope {
        case .allData:
            // Schedule deletion after retention period
            scheduleDeleteAfterRetention(allData: true)

        case .moduleSpecific(let moduleId):
            // Only delete data TAGGED to this module
            // Shared domain mastery remains (other modules contributed too)
            scheduleDeleteModuleContributions(moduleId)

        case .domainSpecific(let domain):
            // Delete mastery for specific domain
            scheduleDeleteDomainMastery(domain)
        }
    }

    enum DeletionScope {
        case allData
        case moduleSpecific(String)
        case domainSpecific(StandardDomain)
    }
}
```

### Storage Implementation

```swift
// MARK: - Storage Layer

class ProficiencyStorage {

    /// Primary storage location (user's device)
    private let primaryStore: UserDefaults

    /// Backup storage (for resilience)
    private let backupStore: FileManager

    /// File path for proficiency data
    private var proficiencyFilePath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UnifiedProficiency")
            .appendingPathExtension("json")
    }

    /// Backup file path
    private var backupFilePath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UnifiedProficiency.backup")
            .appendingPathExtension("json")
    }

    // ═══════════════════════════════════════════════════════════════
    // SAVE OPERATIONS
    // ═══════════════════════════════════════════════════════════════

    func save(_ profile: UnifiedProficiencyProfile) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(profile)

        // Write to primary storage
        try data.write(to: proficiencyFilePath)

        // Create backup
        try data.write(to: backupFilePath)

        // Also store in UserDefaults as additional backup
        primaryStore.set(data, forKey: "UnifiedProficiency")
    }

    // ═══════════════════════════════════════════════════════════════
    // LOAD OPERATIONS
    // ═══════════════════════════════════════════════════════════════

    func load() throws -> UnifiedProficiencyProfile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try primary storage first
        if let data = try? Data(contentsOf: proficiencyFilePath) {
            return try decoder.decode(UnifiedProficiencyProfile.self, from: data)
        }

        // Try backup
        if let data = try? Data(contentsOf: backupFilePath) {
            return try decoder.decode(UnifiedProficiencyProfile.self, from: data)
        }

        // Try UserDefaults
        if let data = primaryStore.data(forKey: "UnifiedProficiency") {
            return try decoder.decode(UnifiedProficiencyProfile.self, from: data)
        }

        // No existing data - create new profile
        throw PersistenceError.noDataFound
    }

    // ═══════════════════════════════════════════════════════════════
    // EXPORT OPERATIONS
    // ═══════════════════════════════════════════════════════════════

    func export() throws -> Data {
        let profile = try load()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(profile)
    }

    enum PersistenceError: Error {
        case noDataFound
        case corruptedData
        case writeFailure
    }
}
```

---

## Unified Dashboard (Optional)

For users participating in multiple competitions:

```swift
struct UnifiedDashboard {

    /// Show proficiency across all domains
    var domainOverview: [DomainSummary]

    /// Active modules and their status
    var moduleStatus: [ModuleStatus]

    /// Cross-module insights
    var insights: [CrossModuleInsight]

    /// Recommended focus areas (considering all competitions)
    var recommendations: [Recommendation]
}

struct DomainSummary {
    let domain: StandardDomain
    let masteryScore: Double
    let relevantCompetitions: [CompetitionType]
    let contributingModules: [String]
    let trend: PerformanceTrend
}

struct ModuleStatus {
    let moduleId: String
    let moduleName: String
    let isInstalled: Bool
    let lastActive: Date?
    let questionsContributed: Int
    let primaryDomains: [StandardDomain]
}

struct CrossModuleInsight {
    let type: InsightType
    let message: String
    let relatedDomains: [StandardDomain]
    let relatedModules: [String]

    enum InsightType {
        case skillTransfer      // "Your QB science helps your SB!"
        case sharedWeakness     // "Geography is weak across all competitions"
        case balanceRecommendation // "Try Science Bowl to deepen STEM"
    }
}
```

---

## Summary: Key Guarantees

| Guarantee | Implementation |
|-----------|----------------|
| **Data persists after uninstall** | Module uninstall only marks module inactive; data remains |
| **New module sees existing data** | Onboarding checks proficiency store first |
| **Shared data structures** | All modules use StandardDomain and common schemas |
| **Transfer recognition** | Weight matrix determines how proficiency transfers |
| **User owns data** | Stored on device, exportable, deletable only by user |
| **No cold start for returning users** | Even years later, proficiency is recognized |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-17 | UnaMentis Team | Initial unified proficiency specification |

---

*This document defines the data layer that enables seamless user experience across all competition modules. All module developers MUST use these interfaces and schemas.*
