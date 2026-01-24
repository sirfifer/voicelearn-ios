//
//  KBReboundSimulator.swift
//  UnaMentis
//
//  Rebound training simulator for Knowledge Bowl.
//  Simulates opponent buzzing and missing, training students
//  to capitalize on rebound opportunities.
//

import Foundation

// MARK: - Rebound Config

/// Configuration for rebound training
struct KBReboundConfig: Sendable {
    let region: KBRegion
    let reboundProbability: Double
    let opponentAccuracy: Double
    let questionCount: Int
    let showOpponentAnswer: Bool
    let useProgressiveDifficulty: Bool

    /// Default configuration for a region
    static func forRegion(_ region: KBRegion) -> KBReboundConfig {
        KBReboundConfig(
            region: region,
            reboundProbability: 0.5,
            opponentAccuracy: 0.6,
            questionCount: 15,
            showOpponentAnswer: true,
            useProgressiveDifficulty: true
        )
    }

    /// Custom configuration
    init(
        region: KBRegion,
        reboundProbability: Double = 0.5,
        opponentAccuracy: Double = 0.6,
        questionCount: Int = 15,
        showOpponentAnswer: Bool = true,
        useProgressiveDifficulty: Bool = true
    ) {
        self.region = region
        self.reboundProbability = reboundProbability.clamped(to: 0.3...0.8)
        self.opponentAccuracy = opponentAccuracy.clamped(to: 0.3...0.9)
        self.questionCount = questionCount
        self.showOpponentAnswer = showOpponentAnswer
        self.useProgressiveDifficulty = useProgressiveDifficulty
    }
}

// MARK: - Rebound Scenario

/// Represents a rebound scenario in training
struct KBReboundScenario: Sendable, Identifiable {
    let id: UUID
    let question: KBQuestion
    let opponentBuzzed: Bool
    let opponentAnswer: String?
    let opponentWasCorrect: Bool
    let isReboundOpportunity: Bool
    let timeAfterOpponentAnswer: TimeInterval
}

// MARK: - Rebound Attempt

/// Records a rebound attempt
struct KBReboundAttempt: Sendable, Identifiable {
    let id = UUID()
    let scenarioId: UUID
    let questionId: UUID
    let domain: KBDomain
    let wasReboundOpportunity: Bool
    let userBuzzedOnRebound: Bool
    let userAnswer: String?
    let wasCorrect: Bool
    let responseTime: TimeInterval
    let pointsEarned: Int
    let strategicDecision: ReboundDecision
    let timestamp: Date

    init(
        scenarioId: UUID,
        questionId: UUID,
        domain: KBDomain,
        wasReboundOpportunity: Bool,
        userBuzzedOnRebound: Bool,
        userAnswer: String? = nil,
        wasCorrect: Bool,
        responseTime: TimeInterval,
        pointsEarned: Int = 0,
        strategicDecision: ReboundDecision
    ) {
        self.scenarioId = scenarioId
        self.questionId = questionId
        self.domain = domain
        self.wasReboundOpportunity = wasReboundOpportunity
        self.userBuzzedOnRebound = userBuzzedOnRebound
        self.userAnswer = userAnswer
        self.wasCorrect = wasCorrect
        self.responseTime = responseTime
        self.pointsEarned = pointsEarned
        self.strategicDecision = strategicDecision
        self.timestamp = Date()
    }
}

/// Strategic decision on a rebound
enum ReboundDecision: String, Sendable, CaseIterable {
    case buzzedCorrectly
    case buzzedIncorrectly
    case strategicHold
    case missedOpportunity
    case correctlyIgnored

    var displayName: String {
        switch self {
        case .buzzedCorrectly: return "Buzzed & Correct"
        case .buzzedIncorrectly: return "Buzzed & Wrong"
        case .strategicHold: return "Strategic Hold"
        case .missedOpportunity: return "Missed Opportunity"
        case .correctlyIgnored: return "Correctly Ignored"
        }
    }

    var isPositive: Bool {
        switch self {
        case .buzzedCorrectly, .strategicHold, .correctlyIgnored:
            return true
        case .buzzedIncorrectly, .missedOpportunity:
            return false
        }
    }
}

// MARK: - Rebound Stats

/// Statistics from a rebound training session
struct KBReboundStats: Sendable {
    let totalScenarios: Int
    let reboundOpportunities: Int
    let reboundsTaken: Int
    let reboundsCorrect: Int
    let strategicHolds: Int
    let missedOpportunities: Int
    let averageResponseTime: TimeInterval
    let totalPoints: Int
    let reboundAccuracy: Double
    let opportunityCapture: Double

    init(attempts: [KBReboundAttempt]) {
        self.totalScenarios = attempts.count
        self.reboundOpportunities = attempts.filter { $0.wasReboundOpportunity }.count
        self.reboundsTaken = attempts.filter { $0.wasReboundOpportunity && $0.userBuzzedOnRebound }.count
        self.reboundsCorrect = attempts.filter {
            $0.wasReboundOpportunity && $0.userBuzzedOnRebound && $0.wasCorrect
        }.count
        self.strategicHolds = attempts.filter { $0.strategicDecision == .strategicHold }.count
        self.missedOpportunities = attempts.filter { $0.strategicDecision == .missedOpportunity }.count

        let responseTimes = attempts.map { $0.responseTime }
        self.averageResponseTime = responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count)

        self.totalPoints = attempts.reduce(0) { $0 + $1.pointsEarned }

        self.reboundAccuracy = reboundsTaken > 0 ? Double(reboundsCorrect) / Double(reboundsTaken) : 0
        self.opportunityCapture = reboundOpportunities > 0 ? Double(reboundsTaken) / Double(reboundOpportunities) : 0
    }
}

// MARK: - Rebound Simulator

/// Simulates opponent behavior and manages rebound training sessions
actor KBReboundSimulator {
    // MARK: - Properties

    private let config: KBReboundConfig
    private var attempts: [KBReboundAttempt] = []
    private var currentScenario: KBReboundScenario?
    private var sessionStartTime: Date?
    private var isActive = false
    private var currentDifficultyModifier: Double = 1.0

    // Opponent simulation state
    private var opponentNames = ["Team Alpha", "Team Beta", "Team Gamma"]
    private var currentOpponentIndex = 0

    // MARK: - Initialization

    init(config: KBReboundConfig) {
        self.config = config
    }

    init(region: KBRegion) {
        self.config = .forRegion(region)
    }

    // MARK: - Session Lifecycle

    /// Start a new rebound training session
    func startSession() {
        attempts = []
        currentScenario = nil
        sessionStartTime = Date()
        isActive = true
        currentDifficultyModifier = 1.0
        currentOpponentIndex = Int.random(in: 0..<opponentNames.count)
    }

    /// End the session and return statistics
    func endSession() -> KBReboundStats {
        isActive = false
        return KBReboundStats(attempts: attempts)
    }

    // MARK: - Scenario Generation

    /// Generate a rebound scenario for a question
    func generateScenario(for question: KBQuestion) -> KBReboundScenario {
        let effectiveProbability = config.useProgressiveDifficulty
            ? config.reboundProbability * currentDifficultyModifier
            : config.reboundProbability

        let opponentBuzzed = Double.random(in: 0...1) < effectiveProbability
        var opponentAnswer: String?
        var opponentWasCorrect = false
        var isReboundOpportunity = false
        var timeAfterAnswer: TimeInterval = 0

        if opponentBuzzed {
            opponentWasCorrect = Double.random(in: 0...1) < config.opponentAccuracy
            isReboundOpportunity = !opponentWasCorrect

            if opponentWasCorrect {
                opponentAnswer = question.answer.primary
            } else {
                opponentAnswer = generateWrongAnswer(for: question)
            }

            timeAfterAnswer = Double.random(in: 1.0...3.0)
        }

        let scenario = KBReboundScenario(
            id: UUID(),
            question: question,
            opponentBuzzed: opponentBuzzed,
            opponentAnswer: opponentAnswer,
            opponentWasCorrect: opponentWasCorrect,
            isReboundOpportunity: isReboundOpportunity,
            timeAfterOpponentAnswer: timeAfterAnswer
        )

        currentScenario = scenario
        return scenario
    }

    /// Record a user's rebound decision
    func recordAttempt(
        buzzedOnRebound: Bool,
        userAnswer: String?,
        wasCorrect: Bool,
        responseTime: TimeInterval,
        knewAnswer: Bool
    ) {
        guard let scenario = currentScenario else { return }

        let decision = determineDecision(
            scenario: scenario,
            buzzed: buzzedOnRebound,
            wasCorrect: wasCorrect,
            knewAnswer: knewAnswer
        )

        let points = calculatePoints(
            scenario: scenario,
            decision: decision,
            wasCorrect: wasCorrect
        )

        let attempt = KBReboundAttempt(
            scenarioId: scenario.id,
            questionId: scenario.question.id,
            domain: scenario.question.domain,
            wasReboundOpportunity: scenario.isReboundOpportunity,
            userBuzzedOnRebound: buzzedOnRebound,
            userAnswer: userAnswer,
            wasCorrect: wasCorrect,
            responseTime: responseTime,
            pointsEarned: points,
            strategicDecision: decision
        )

        attempts.append(attempt)
        updateDifficulty(decision: decision)
    }

    // MARK: - Opponent Simulation

    /// Get current opponent team name
    func getCurrentOpponent() -> String {
        opponentNames[currentOpponentIndex]
    }

    /// Rotate to next opponent
    func rotateOpponent() {
        currentOpponentIndex = (currentOpponentIndex + 1) % opponentNames.count
    }

    // MARK: - Private Helpers

    private func generateWrongAnswer(for question: KBQuestion) -> String {
        let wrongAnswers: [KBDomain: [String]] = [
            .science: ["Carbon dioxide", "Nitrogen", "Helium", "The sun"],
            .mathematics: ["42", "π", "Zero", "Infinity"],
            .literature: ["Shakespeare", "Dickens", "Hemingway", "Twain"],
            .history: ["1776", "1492", "1066", "1945"],
            .socialStudies: ["Washington D.C.", "Paris", "London", "Beijing"],
            .arts: ["Picasso", "Van Gogh", "Da Vinci", "Monet"],
            .currentEvents: ["United Nations", "NATO", "EU", "WHO"],
            .language: ["Latin", "Greek", "Sanskrit", "Hebrew"],
            .technology: ["Silicon", "Binary", "Algorithm", "Protocol"],
            .popCulture: ["The Beatles", "Elvis", "Michael Jackson", "Madonna"],
            .religionPhilosophy: ["Aristotle", "Plato", "Socrates", "Confucius"],
            .miscellaneous: ["Blue", "Seven", "Tuesday", "North"]
        ]

        let domainAnswers = wrongAnswers[question.domain] ?? ["Unknown"]
        return domainAnswers.filter { $0 != question.answer.primary }.randomElement() ?? "Unknown"
    }

    private func determineDecision(
        scenario: KBReboundScenario,
        buzzed: Bool,
        wasCorrect: Bool,
        knewAnswer: Bool
    ) -> ReboundDecision {
        if scenario.isReboundOpportunity {
            if buzzed {
                return wasCorrect ? .buzzedCorrectly : .buzzedIncorrectly
            } else {
                return knewAnswer ? .strategicHold : .missedOpportunity
            }
        } else {
            return .correctlyIgnored
        }
    }

    private func calculatePoints(
        scenario: KBReboundScenario,
        decision: ReboundDecision,
        wasCorrect: Bool
    ) -> Int {
        switch decision {
        case .buzzedCorrectly:
            return 10
        case .buzzedIncorrectly:
            return -5
        case .strategicHold:
            return 2
        case .missedOpportunity:
            return -2
        case .correctlyIgnored:
            return 1
        }
    }

    private func updateDifficulty(decision: ReboundDecision) {
        guard config.useProgressiveDifficulty else { return }

        switch decision {
        case .buzzedCorrectly:
            currentDifficultyModifier = min(1.5, currentDifficultyModifier + 0.1)
        case .buzzedIncorrectly, .missedOpportunity:
            currentDifficultyModifier = max(0.5, currentDifficultyModifier - 0.05)
        default:
            break
        }
    }
}

// MARK: - Static Helpers

extension KBReboundSimulator {
    /// Generate practice scenarios for demonstration
    static func generatePracticeScenarios() -> [(scenario: String, tip: String)] {
        [
            (
                scenario: "Opponent buzzed and answered 'The Great Gatsby' but the question was about a Hemingway novel.",
                tip: "This is a clear rebound opportunity. The opponent's answer reveals the category (American literature), which can help you narrow down the correct answer."
            ),
            (
                scenario: "Opponent buzzed immediately and got it correct.",
                tip: "No rebound opportunity here. Use this time to process the question for future reference."
            ),
            (
                scenario: "Question about state capitals. Opponent answered 'Sacramento' but the question asked about Nevada.",
                tip: "Strong rebound opportunity. Geography mix-ups are common. If you know the answer, buzz quickly!"
            ),
            (
                scenario: "Math question. Opponent answered '12' but you calculated '16'.",
                tip: "Be confident in your calculation. If you're sure, take the rebound. Mathematical questions have definitive answers."
            ),
            (
                scenario: "Opponent hesitated before answering incorrectly.",
                tip: "Hesitation often signals uncertainty. This can be a good rebound opportunity if you have a confident answer."
            )
        ]
    }
}

// MARK: - Double Extension

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
