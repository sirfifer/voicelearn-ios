# Claude Code Module Implementation Prompt

**Purpose:** This prompt provides context for Claude Code when working on the Academic Competition Training Platform iOS project. It synthesizes architectural decisions, module specifications, and implementation priorities from extensive planning documentation.

---

## PART 1: ARCHITECTURAL CONTEXT

### Core Architecture Principles

You are working on an iOS application with a **modular architecture** supporting multiple academic competition formats. The critical design principles are:

1. **Module Independence**: Each competition module (Knowledge Bowl, Quiz Bowl, Science Bowl) MUST function completely standalone. A user with only the KB module installed should have a fully functional app.

2. **Data Sovereignty**: User proficiency data belongs to the USER, not any module. This data:
   - Persists on the device regardless of which modules are installed
   - Survives module installation/uninstallation
   - Is accessible to any installed module
   - Can be exported by the user at any time

3. **Shared Core Layer**: All modules consume shared services:
   - **Question Engine**: Canonical question storage with per-module transformations
   - **Voice Pipeline**: Universal speech recognition/synthesis configured per competition
   - **Proficiency Store**: Cross-module skill tracking with transfer recognition
   - **Analytics Engine**: Unified performance tracking with module-specific extensions
   - **Training Protocol Library**: Shared training patterns adapted per competition

4. **Graceful Enhancement**: When multiple modules are present, they enhance each other through:
   - Shared question pools (questions usable by multiple formats)
   - Proficiency transfer recognition (KB skills recognized when user installs QB)
   - Cross-training recommendations

### Layer Architecture

```
LAYER 5: Competition Module UIs (KB, QB, SB specific views)
LAYER 4: Competition Modules (module-specific logic, transformers, analytics)
LAYER 3: Shared Services (QuestionEngine, VoicePipeline, AnalyticsEngine, TrainingLibrary)
LAYER 2: Data Layer (UnifiedProficiencyStore, CanonicalQuestionDB, SessionStore)
LAYER 1: Platform Foundation (iOS APIs, Speech Framework, Storage)
```

### Module Communication

Modules NEVER communicate directly. All inter-module communication flows through:

```swift
protocol ModuleCommunicationHub {
    func register(module: CompetitionModule)
    func post(event: ModuleEvent)
    func subscribe(to eventType: ModuleEventType, handler: @escaping (ModuleEvent) -> Void)
}

enum ModuleEventType {
    case questionCompleted
    case sessionCompleted
    case proficiencyUpdated
    case moduleInstalled
    case moduleUninstalled
    case crossTrainingAvailable
}
```

---

## PART 2: UNIFIED PROFICIENCY SYSTEM

### Critical: Data Persistence Rules

The proficiency system is the SINGLE SOURCE OF TRUTH for user knowledge across all modules.

```swift
struct UnifiedProficiencyProfile: Codable {
    let userId: UUID
    var lastUpdated: Date

    // Domain mastery - shared across ALL modules
    var domainMastery: [DomainMasteryRecord]

    // Response characteristics - speed, patterns
    var responseProfile: ResponseProfile

    // Learning history - complete audit trail
    var learningHistory: LearningHistory

    // Which modules contributed what data
    var moduleContributions: [ModuleContribution]
}
```

### Standard Domain Taxonomy

ALL modules MUST use this exact taxonomy. This enables cross-module proficiency transfer.

```swift
enum StandardDomain: String, Codable, CaseIterable {
    // Core Academic
    case literature, history, geography, socialScience, fineArts, music

    // STEM (used heavily by Science Bowl)
    case biology, chemistry, physics, earthScience, astronomy
    case mathematics, computerScience, engineering

    // Specialized
    case religion, mythology, philosophy

    // General
    case currentEvents, popularCulture, general
}
```

### Proficiency Transfer on Module Install

When a user installs a new module, recognize their existing proficiency:

```swift
class ModuleOnboardingService {
    func onboardNewModule(moduleId: String) -> ModuleOnboardingResult {
        guard proficiencyStore.hasExistingProficiency() else {
            return .newUser(startingLevel: .novice)
        }

        let profile = proficiencyStore.getProfile()
        let relevantDomains = getRelevantDomains(for: moduleId)
        let transferredProficiency = calculateTransferProficiency(
            from: profile.domainMastery,
            to: moduleId
        )

        return .existingUser(
            suggestedLevel: transferredProficiency.suggestedLevel,
            recognizedStrengths: transferredProficiency.strengths,
            skipAssessment: transferredProficiency.confidence > 0.7
        )
    }
}
```

### Transfer Weight Matrix

How proficiency transfers between competitions:

| From → To | Literature | History | Biology | Chemistry | Physics | Math |
|-----------|------------|---------|---------|-----------|---------|------|
| KB → QB   | 85%        | 85%     | 80%     | 80%       | 80%     | 75%  |
| KB → SB   | -          | -       | 70%     | 70%       | 70%     | 65%  |
| QB → KB   | 90%        | 90%     | 85%     | 85%       | 85%     | 80%  |
| QB → SB   | -          | -       | 75%     | 75%       | 75%     | 70%  |
| SB → QB   | -          | -       | 95%     | 95%       | 95%     | 80%  |
| SB → KB   | -          | -       | 90%     | 90%       | 90%     | 75%  |

---

## PART 3: CANONICAL QUESTION SYSTEM

### Question Storage Philosophy

Questions are stored in a **canonical, competition-agnostic format**. Each module transforms canonical questions to its specific format.

```swift
struct CanonicalQuestion: Codable, Identifiable {
    let id: UUID

    // Multiple content forms for different competitions
    let content: QuestionContent
    let answer: AnswerSpec
    let domains: [DomainTag]
    let difficulty: DifficultyRating

    // Which competitions can use this question
    let compatibleFormats: [CompetitionFormat]
}

struct QuestionContent: Codable {
    /// Full pyramidal version (QB uses this)
    let pyramidalFull: String

    /// Medium length (3-4 sentences)
    let mediumForm: String

    /// Short form (1-2 sentences, KB/SB use this)
    let shortForm: String

    /// Individual clues for pyramidal questions
    let clues: [PyramidalClue]?

    /// Power mark position for QB
    let powerMarkIndex: Int?
}
```

### Question Transformation

Each module has a transformer that converts canonical questions:

```swift
protocol QuestionTransformer {
    associatedtype Output: CompetitionQuestion

    func transform(_ canonical: CanonicalQuestion) -> Output?
    func isCompatible(_ canonical: CanonicalQuestion) -> Bool
    func qualityScore(_ canonical: CanonicalQuestion) -> Double
    func canonicalize(_ question: Output) -> CanonicalQuestion
}
```

**KB Transformer**: Uses `mediumForm` or `shortForm`, converts to MCQ for written rounds
**QB Transformer**: Uses `pyramidalFull`, extracts clue structure, identifies power mark
**SB Transformer**: Uses `shortForm`, filters STEM-only, assigns category (BIO/CHEM/PHY/MATH/EARTH/ENERGY)

---

## PART 4: KNOWLEDGE BOWL MODULE SPECIFICS

### Regional Configuration - CRITICAL

Knowledge Bowl has significant rule variations between states. The module MUST support all variants correctly.

#### Colorado Rules (VERIFIED FROM OFFICIAL HANDBOOK)
```swift
static let colorado = ConferringConfig(
    conferenceTimeSeconds: 15,
    verbalConferringAllowed: false,  // NO discussion about the answer
    handSignalsAllowed: true,
    conferringRequired: false
)

static let coloradoTeamSize = TeamSizeConfig(
    minPlayers: 1,
    maxPlayers: 4,  // NOT 5-6
    activeInWritten: 4,
    activeInOral: 4
)
```

**IMPORTANT**: Colorado does NOT allow verbal discussion about the answer. Teams may only use hand signals. This was incorrectly documented previously.

#### Minnesota Rules
```swift
static let minnesota = ConferringConfig(
    conferenceTimeSeconds: 15,
    verbalConferringAllowed: true,  // CAN discuss
    handSignalsAllowed: true,
    conferringRequired: false
)
// NO negative scoring - KB never has negs
```

#### Washington Rules
```swift
static let washington = WrittenRoundConfig(
    timeLimit: 2700,  // 45 minutes (NOT 35)
    questionCount: 50,
    pointsPerQuestion: 2
)
```

### KB Match Structure

| Element | Colorado | Minnesota | Washington |
|---------|----------|-----------|------------|
| Teams per match | 3 | 3 | 3 |
| Team size | 1-4 | 3-6 | 3-5 |
| Written questions | 60 | 60 | 50 |
| Written time | 15 min | 15 min | **45 min** |
| Written points | 1 | 2 | 2 |
| Oral questions | 50 | 50 | 50 |
| Oral points | 5 | 5 | 5 |
| Verbal conferring | **NO** | Yes | Yes |
| Negative scoring | **NO** | **NO** | **NO** |

### KB-Specific Analytics

```swift
struct KBAnalyticsProfile: CompetitionSpecificProfile {
    // Round-specific performance
    var writtenRoundStats: RoundStats
    var oralRoundStats: RoundStats

    // Conference efficiency (for regions allowing conferring)
    var conferenceStats: ConferenceStats

    // Rebound performance (unique to KB's 3-team format)
    var reboundStats: ReboundStats

    // Domain breakdown (links to unified proficiency)
    var domainPerformance: [StandardDomain: KBDomainStats]
}

struct ConferenceStats: Codable {
    var conferenceSuccessRate: Double
    var averageConferenceTime: TimeInterval
    var accuracyWithConference: Double
    var accuracyWithoutConference: Double

    var conferenceEfficiency: Double {
        accuracyWithConference - accuracyWithoutConference
    }
}
```

### KB Training Modes (Priority Order)

1. **Written Round Practice** (P0) - MCQ format, timed, all domains
2. **Oral Round Practice** (P0) - Voice interface, buzzer simulation
3. **Domain Drill** (P0) - Focus on specific subject areas
4. **Conference Training** (P1) - Optimize 15-second discussion window
5. **Rebound Practice** (P1) - Capitalize on opponent mistakes
6. **Match Simulation** (P1) - Full 3-team format simulation
7. **Hand Signal Practice** (P2) - For Colorado teams specifically

### KB Voice Pipeline Configuration

```swift
voicePipeline.configure(for: .knowledgeBowl)
// Results in:
VoicePipelineConfig(
    buzzMode: .team,           // Team buzzer, not individual
    answerTimeout: 5.0,        // After conference
    speakingRate: 1.0,         // Normal pace
    allowInterruption: true,   // Can buzz mid-question
    conferenceTime: 15.0       // 15-second conference period
)
```

---

## PART 5: IMPLEMENTATION PRIORITIES FOR KB MODULE

### Phase 1: Core Infrastructure Alignment (FIRST)

Before any new KB features, ensure the codebase aligns with the modular architecture:

1. **Extract shared services** from any KB-specific code:
   - Question storage → CanonicalQuestionStore
   - Voice handling → UniversalVoicePipeline
   - Analytics → shared AnalyticsEngine with KB extension
   - Proficiency tracking → UnifiedProficiencyStore

2. **Implement module manifest**:
```swift
let kbManifest = ModuleManifest(
    moduleId: "com.unamentis.knowledgebowl",
    displayName: "Knowledge Bowl",
    version: "1.0.0",
    competition: .knowledgeBowl,
    minimumCoreVersion: "1.0.0",
    capabilities: ModuleCapabilities(
        providesQuestions: true,
        consumesSharedQuestions: true,
        providesAnalytics: true,
        consumesUnifiedProfile: true,
        supportsVoiceInterface: true,
        supportsWatchOS: true
    )
)
```

3. **Implement KB transformer**:
   - Canonical → KBQuestion
   - KBQuestion → Canonical (for ingestion)
   - MCQ generation for written round

### Phase 2: Regional Configuration System

Implement robust regional rule handling:

```swift
struct KBRegionalConfig: Codable, Identifiable {
    let id: String
    let region: KBRegion
    let teamSize: TeamSizeConfig
    let oralRoundConfig: OralRoundConfig
    let writtenRoundConfig: WrittenRoundConfig
    let scoringConfig: ScoringConfig
    let conferringConfig: ConferringConfig
}

// User selects their region; app adapts all rules accordingly
class KBRegionManager {
    @Published var currentRegion: KBRegion = .colorado

    var activeConfig: KBRegionalConfig {
        KBRegionalConfig.config(for: currentRegion)
    }
}
```

### Phase 3: Training Modes (Priority Order)

| Priority | Mode | Description | Key Files |
|----------|------|-------------|-----------|
| P0 | Written Practice | MCQ training under time pressure | `KBWrittenSession.swift` |
| P0 | Oral Practice | Voice-based with conference simulation | `KBOralSession.swift` |
| P0 | Domain Drill | Focused practice on weak domains | `KBDomainDrill.swift` |
| P1 | Conference Training | Optimize 15-second window | `KBConferenceTraining.swift` |
| P1 | Rebound Practice | Capitalize on opponent errors | `KBReboundTraining.swift` |
| P1 | Match Simulation | Full 3-team format | `KBMatchSimulation.swift` |

### Phase 4: Analytics Integration

Ensure KB analytics flow to unified proficiency:

```swift
class KBAnalyticsService {
    private let proficiencyStore: ProficiencyStore

    func recordAttempt(_ attempt: KBQuestionAttempt, question: KBQuestion) {
        // Record to KB-specific analytics
        kbSessionStore.addAttempt(attempt)

        // ALSO record to unified proficiency (CRITICAL)
        let unifiedAttempt = QuestionAttempt(
            timestamp: attempt.timestamp,
            moduleId: "com.unamentis.knowledgebowl",
            domain: question.domains.first?.primary.toStandardDomain(),
            difficulty: question.difficulty,
            wasCorrect: attempt.wasCorrect,
            responseTime: attempt.responseTime
        )
        proficiencyStore.recordAttempt(unifiedAttempt)
    }
}
```

---

## PART 6: CROSS-MODULE CONSIDERATIONS

### When Adding QB or SB Later

The KB module should be built to enable future cross-module features:

1. **Question Sharing Readiness**:
   - Store questions in canonical format
   - Tag questions with `compatibleFormats`
   - KB questions (short form) can easily transform to SB
   - Some KB questions can provide giveaway clues for QB pyramids

2. **Proficiency Portability**:
   - All domain mastery stored via StandardDomain enum
   - Response times tracked in universal format
   - When QB is installed, user's KB literature/history skills are recognized

3. **Cross-Training Hooks**:
   - Leave extension points for cross-training suggestions
   - "Your KB science skills would help in Science Bowl" recommendations

### Module Lifecycle

```swift
class ModuleLifecycleManager {
    func onModuleInstalled(_ moduleId: String) {
        // Register with communication hub
        communicationHub.register(module: module)

        // Check for existing proficiency to transfer
        let onboarding = onboardingService.onboardNewModule(moduleId)

        // Notify other modules
        communicationHub.post(event: .moduleInstalled(moduleId))
    }

    func onModuleUninstalled(_ moduleId: String) {
        // Mark module inactive in proficiency store
        // DO NOT DELETE proficiency data
        proficiencyStore.markModuleUninstalled(moduleId)

        // Unregister from hub
        communicationHub.unregister(moduleId: moduleId)
    }
}
```

---

## PART 7: TECHNICAL REQUIREMENTS

### iOS/watchOS Requirements
- iOS 16.0 minimum, 17.0+ recommended
- watchOS 9.0 minimum
- Swift 5.9+
- SwiftUI for all new UI

### Key Frameworks
```swift
import Speech          // SFSpeechRecognizer
import AVFoundation   // AVSpeechSynthesizer
import SwiftData      // Primary persistence (iOS 17+)
import WatchConnectivity
```

### Performance Targets
| Metric | Target |
|--------|--------|
| Question retrieval | <200ms |
| Voice recognition start | <500ms |
| Proficiency update | <50ms |
| App launch | <1s |

---

## SUMMARY: Key Implementation Rules

1. **Never delete proficiency data** when a module is uninstalled
2. **Always record to unified proficiency** when recording module-specific analytics
3. **Use StandardDomain taxonomy** for all domain classifications
4. **Store questions in canonical format** with competition-specific transformations
5. **Respect regional rule variations** - Colorado conferring rules are DIFFERENT
6. **Configure voice pipeline per competition** - KB uses team buzz, 15s conference
7. **Design for module independence** - KB must work fully without QB/SB installed
8. **Prepare for cross-module enhancement** - leave hooks for future integration

---

## Reference Documentation

For detailed specifications, see:
- `KNOWLEDGE_BOWL_CHAMPIONSHIP_SYSTEM.md` - Complete KB domain knowledge and training philosophy
- `KNOWLEDGE_BOWL_MODULE_SPEC.md` - Technical implementation specification
- `MASTER_TECHNICAL_IMPLEMENTATION.md` - Platform architecture and roadmap
- `UNIFIED_PROFICIENCY_SYSTEM.md` - Cross-module proficiency tracking
- `ACADEMIC_COMPETITION_MODULAR_ARCHITECTURE.md` - Module integration patterns

---

*This prompt should be provided to Claude Code when starting work on the module codebase. It ensures alignment with architectural decisions made during the planning phase.*
