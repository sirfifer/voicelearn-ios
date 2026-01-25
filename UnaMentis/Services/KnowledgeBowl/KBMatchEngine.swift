//
//  KBMatchEngine.swift
//  UnaMentis
//
//  Match simulation engine for Knowledge Bowl.
//  Manages full match flow with simulated opponents.
//

import Foundation

// MARK: - Match Config

/// Configuration for a simulated match
struct KBMatchConfig: Sendable {
    let region: KBRegion
    let matchFormat: MatchFormat
    let opponentStrengths: [OpponentStrength]
    let enablePracticeMode: Bool

    enum MatchFormat: String, Sendable, CaseIterable {
        case quickMatch
        case halfMatch
        case fullMatch

        var writtenQuestions: Int {
            switch self {
            case .quickMatch: return 10
            case .halfMatch: return 20
            case .fullMatch: return 40
            }
        }

        var oralRounds: Int {
            switch self {
            case .quickMatch: return 2
            case .halfMatch: return 4
            case .fullMatch: return 8
            }
        }

        var questionsPerOralRound: Int {
            10
        }

        var displayName: String {
            switch self {
            case .quickMatch: return "Quick Match"
            case .halfMatch: return "Half Match"
            case .fullMatch: return "Full Match"
            }
        }
    }

    enum OpponentStrength: String, Sendable, CaseIterable {
        case beginner
        case intermediate
        case advanced
        case expert

        var buzzProbability: Double {
            switch self {
            case .beginner: return 0.3
            case .intermediate: return 0.5
            case .advanced: return 0.7
            case .expert: return 0.85
            }
        }

        var accuracy: Double {
            switch self {
            case .beginner: return 0.4
            case .intermediate: return 0.6
            case .advanced: return 0.75
            case .expert: return 0.9
            }
        }

        var displayName: String {
            switch self {
            case .beginner: return "Beginner"
            case .intermediate: return "Intermediate"
            case .advanced: return "Advanced"
            case .expert: return "Expert"
            }
        }
    }

    /// Default configuration
    static func forRegion(_ region: KBRegion) -> KBMatchConfig {
        KBMatchConfig(
            region: region,
            matchFormat: .quickMatch,
            opponentStrengths: [.intermediate, .intermediate],
            enablePracticeMode: true
        )
    }
}

// MARK: - Match State

/// Current state of the match
enum MatchPhase: Sendable {
    case notStarted
    case writtenRound
    case writtenReview
    case oralRound(roundNumber: Int)
    case oralReview(roundNumber: Int)
    case finalResults
}

// MARK: - Team

/// Represents a team in the match
struct KBTeam: Sendable, Identifiable {
    let id: UUID
    let name: String
    let isPlayer: Bool
    let strength: KBMatchConfig.OpponentStrength?
    var writtenScore: Int
    var oralScore: Int

    var totalScore: Int {
        writtenScore + oralScore
    }

    init(
        id: UUID = UUID(),
        name: String,
        isPlayer: Bool = false,
        strength: KBMatchConfig.OpponentStrength? = nil
    ) {
        self.id = id
        self.name = name
        self.isPlayer = isPlayer
        self.strength = strength
        self.writtenScore = 0
        self.oralScore = 0
    }
}

// MARK: - Match Question Result

/// Result of a question in the match
struct KBMatchQuestionResult: Sendable, Identifiable {
    let id = UUID()
    let question: KBQuestion
    let phase: MatchPhase
    let answeringTeam: UUID?
    let wasCorrect: Bool
    let pointsAwarded: Int
    let responseTime: TimeInterval
    let timestamp: Date

    init(
        question: KBQuestion,
        phase: MatchPhase,
        answeringTeam: UUID?,
        wasCorrect: Bool,
        pointsAwarded: Int,
        responseTime: TimeInterval
    ) {
        self.question = question
        self.phase = phase
        self.answeringTeam = answeringTeam
        self.wasCorrect = wasCorrect
        self.pointsAwarded = pointsAwarded
        self.responseTime = responseTime
        self.timestamp = Date()
    }
}

// MARK: - Match Summary

/// Summary of a completed match
struct KBMatchSummary: Sendable {
    let matchId: UUID
    let config: KBMatchConfig
    let teams: [KBTeam]
    let results: [KBMatchQuestionResult]
    let startTime: Date
    let endTime: Date
    let playerRank: Int
    let playerStats: PlayerMatchStats

    struct PlayerMatchStats: Sendable {
        let writtenCorrect: Int
        let writtenTotal: Int
        let oralCorrect: Int
        let oralTotal: Int
        let averageResponseTime: TimeInterval
        let domainsStrength: [KBDomain: Double]

        var writtenAccuracy: Double {
            writtenTotal > 0 ? Double(writtenCorrect) / Double(writtenTotal) : 0
        }

        var oralAccuracy: Double {
            oralTotal > 0 ? Double(oralCorrect) / Double(oralTotal) : 0
        }

        var overallAccuracy: Double {
            let total = writtenTotal + oralTotal
            let correct = writtenCorrect + oralCorrect
            return total > 0 ? Double(correct) / Double(total) : 0
        }
    }
}

// MARK: - Match Engine

/// Manages full match simulation
actor KBMatchEngine {
    // MARK: - Properties

    private let config: KBMatchConfig
    private var teams: [KBTeam] = []
    private var results: [KBMatchQuestionResult] = []
    private var currentPhase: MatchPhase = .notStarted
    private var startTime: Date?

    // Question pools
    private var writtenQuestions: [KBQuestion] = []
    private var oralQuestions: [[KBQuestion]] = []
    private var currentQuestionIndex: Int = 0
    private var currentOralRound: Int = 0

    // Opponent simulators
    private var opponentSimulators: [KBOpponentSimulator] = []

    // MARK: - Initialization

    init(config: KBMatchConfig) {
        self.config = config
    }

    // MARK: - Match Setup

    /// Initialize match with questions and teams
    func setupMatch(
        questions: [KBQuestion],
        playerTeamName: String
    ) {
        // Create teams
        teams = [
            KBTeam(name: playerTeamName, isPlayer: true)
        ]

        // Add opponent teams
        let opponentNames = ["Alpha Academy", "Beta School", "Gamma Institute"]
        for (index, strength) in config.opponentStrengths.enumerated() {
            let name = opponentNames[index % opponentNames.count]
            teams.append(KBTeam(name: name, strength: strength))

            opponentSimulators.append(KBOpponentSimulator(
                teamId: teams.last!.id,
                strength: strength
            ))
        }

        // Shuffle and distribute questions
        let shuffled = questions.shuffled()

        // Written questions
        let writtenCount = config.matchFormat.writtenQuestions
        writtenQuestions = Array(shuffled.prefix(writtenCount))

        // Oral questions (distributed by rounds)
        let oralPerRound = config.matchFormat.questionsPerOralRound
        let totalOral = config.matchFormat.oralRounds * oralPerRound
        let oralPool = Array(shuffled.dropFirst(writtenCount).prefix(totalOral))

        oralQuestions = []
        for round in 0..<config.matchFormat.oralRounds {
            let start = round * oralPerRound
            let end = min(start + oralPerRound, oralPool.count)
            if start < oralPool.count {
                oralQuestions.append(Array(oralPool[start..<end]))
            }
        }

        currentPhase = .notStarted
        currentQuestionIndex = 0
        currentOralRound = 0
        results = []
    }

    // MARK: - Match Flow

    /// Start the match
    func startMatch() {
        startTime = Date()
        currentPhase = .writtenRound
        currentQuestionIndex = 0
    }

    /// Get current phase
    func getCurrentPhase() -> MatchPhase {
        currentPhase
    }

    /// Get teams with current scores
    func getTeams() -> [KBTeam] {
        teams
    }

    /// Get current written question
    func getCurrentWrittenQuestion() -> KBQuestion? {
        guard case .writtenRound = currentPhase,
              currentQuestionIndex < writtenQuestions.count else {
            return nil
        }
        return writtenQuestions[currentQuestionIndex]
    }

    /// Submit written answer
    func submitWrittenAnswer(isCorrect: Bool, responseTime: TimeInterval) {
        guard case .writtenRound = currentPhase,
              let question = getCurrentWrittenQuestion(),
              let playerIndex = teams.firstIndex(where: { $0.isPlayer }) else {
            return
        }

        let points = isCorrect ? config.region.writtenPointValue : 0

        let result = KBMatchQuestionResult(
            question: question,
            phase: currentPhase,
            answeringTeam: teams[playerIndex].id,
            wasCorrect: isCorrect,
            pointsAwarded: points,
            responseTime: responseTime
        )
        results.append(result)

        if isCorrect {
            teams[playerIndex].writtenScore += points
        }

        // Simulate opponent answers
        simulateOpponentWrittenAnswers(for: question)

        currentQuestionIndex += 1

        if currentQuestionIndex >= writtenQuestions.count {
            currentPhase = .writtenReview
        }
    }

    /// Start oral rounds after written review
    func startOralRounds() {
        currentOralRound = 0
        currentQuestionIndex = 0
        currentPhase = .oralRound(roundNumber: 1)
    }

    /// Get current oral question
    func getCurrentOralQuestion() -> KBQuestion? {
        guard case .oralRound = currentPhase,
              currentOralRound < oralQuestions.count,
              currentQuestionIndex < oralQuestions[currentOralRound].count else {
            return nil
        }
        return oralQuestions[currentOralRound][currentQuestionIndex]
    }

    /// Simulate who buzzes first for an oral question
    func simulateBuzz() async -> (teamId: UUID, buzzTime: TimeInterval)? {
        guard let question = getCurrentOralQuestion() else { return nil }

        // Player's potential buzz time (simulated)
        let playerBuzzTime = Double.random(in: 1.0...4.0)

        // Opponent buzz times
        var buzzAttempts: [(teamId: UUID, buzzTime: TimeInterval)] = []

        for simulator in opponentSimulators {
            if let buzzTime = await simulator.attemptBuzz(for: question) {
                buzzAttempts.append((simulator.teamId, buzzTime))
            }
        }

        // Add player's potential buzz
        if let playerTeam = teams.first(where: { $0.isPlayer }) {
            buzzAttempts.append((playerTeam.id, playerBuzzTime))
        }

        // Return fastest buzz
        return buzzAttempts.min { $0.buzzTime < $1.buzzTime }
    }

    /// Record oral question result
    func recordOralResult(
        answeringTeamId: UUID?,
        wasCorrect: Bool,
        responseTime: TimeInterval
    ) {
        guard case .oralRound(let roundNumber) = currentPhase,
              let question = getCurrentOralQuestion() else {
            return
        }

        let points: Int
        if wasCorrect {
            points = config.region.oralPointValue
        } else {
            points = config.region.incorrectOralPenalty
        }

        let result = KBMatchQuestionResult(
            question: question,
            phase: currentPhase,
            answeringTeam: answeringTeamId,
            wasCorrect: wasCorrect,
            pointsAwarded: wasCorrect ? points : 0,
            responseTime: responseTime
        )
        results.append(result)

        // Update team score
        if let teamId = answeringTeamId,
           let teamIndex = teams.firstIndex(where: { $0.id == teamId }) {
            if wasCorrect {
                teams[teamIndex].oralScore += points
            } else {
                teams[teamIndex].oralScore += points // Penalty is negative
            }
        }

        currentQuestionIndex += 1

        if currentQuestionIndex >= oralQuestions[currentOralRound].count {
            // Round complete
            currentPhase = .oralReview(roundNumber: roundNumber)
        }
    }

    /// Start next oral round
    func startNextOralRound() {
        currentOralRound += 1
        currentQuestionIndex = 0

        if currentOralRound >= oralQuestions.count {
            currentPhase = .finalResults
        } else {
            currentPhase = .oralRound(roundNumber: currentOralRound + 1)
        }
    }

    /// Get match summary
    func getMatchSummary() -> KBMatchSummary? {
        guard case .finalResults = currentPhase,
              let start = startTime else {
            return nil
        }

        let sortedTeams = teams.sorted { $0.totalScore > $1.totalScore }
        let playerRank = sortedTeams.firstIndex(where: { $0.isPlayer }).map { $0 + 1 } ?? 0

        let playerResults = results.filter { result in
            guard let teamId = result.answeringTeam,
                  let team = teams.first(where: { $0.id == teamId }) else {
                return false
            }
            return team.isPlayer
        }

        let writtenResults = playerResults.filter {
            if case .writtenRound = $0.phase { return true }
            return false
        }

        let oralResults = playerResults.filter {
            if case .oralRound = $0.phase { return true }
            return false
        }

        // Calculate domain strengths
        var domainCorrect: [KBDomain: Int] = [:]
        var domainTotal: [KBDomain: Int] = [:]

        for result in playerResults {
            let domain = result.question.domain
            domainTotal[domain, default: 0] += 1
            if result.wasCorrect {
                domainCorrect[domain, default: 0] += 1
            }
        }

        var domainStrengths: [KBDomain: Double] = [:]
        for domain in KBDomain.allCases {
            if let total = domainTotal[domain], total > 0 {
                let correct = domainCorrect[domain] ?? 0
                domainStrengths[domain] = Double(correct) / Double(total)
            }
        }

        let stats = KBMatchSummary.PlayerMatchStats(
            writtenCorrect: writtenResults.filter { $0.wasCorrect }.count,
            writtenTotal: writtenResults.count,
            oralCorrect: oralResults.filter { $0.wasCorrect }.count,
            oralTotal: oralResults.count,
            averageResponseTime: playerResults.isEmpty ? 0 :
                playerResults.map { $0.responseTime }.reduce(0, +) / Double(playerResults.count),
            domainsStrength: domainStrengths
        )

        return KBMatchSummary(
            matchId: UUID(),
            config: config,
            teams: sortedTeams,
            results: results,
            startTime: start,
            endTime: Date(),
            playerRank: playerRank,
            playerStats: stats
        )
    }

    // MARK: - Progress

    /// Get written round progress
    func getWrittenProgress() -> (current: Int, total: Int) {
        (currentQuestionIndex, writtenQuestions.count)
    }

    /// Get oral round progress
    func getOralProgress() -> (round: Int, totalRounds: Int, question: Int, questionsPerRound: Int) {
        (
            currentOralRound + 1,
            oralQuestions.count,
            currentQuestionIndex,
            oralQuestions.first?.count ?? 0
        )
    }

    // MARK: - Private Helpers

    private func simulateOpponentWrittenAnswers(for question: KBQuestion) {
        for (index, simulator) in opponentSimulators.enumerated() {
            let teamIndex = index + 1 // Player is at index 0
            guard teamIndex < teams.count else { continue }

            Task {
                let isCorrect = await simulator.answerWrittenQuestion(question)
                if isCorrect {
                    teams[teamIndex].writtenScore += config.region.writtenPointValue
                }
            }
        }
    }
}

// MARK: - Opponent Simulator

/// Simulates an opponent team's behavior
actor KBOpponentSimulator {
    let teamId: UUID
    let strength: KBMatchConfig.OpponentStrength

    init(teamId: UUID, strength: KBMatchConfig.OpponentStrength) {
        self.teamId = teamId
        self.strength = strength
    }

    /// Attempt to buzz on a question
    /// Returns buzz time if team would buzz, nil if they wouldn't
    func attemptBuzz(for question: KBQuestion) -> TimeInterval? {
        // Higher strength = more likely to buzz
        let shouldBuzz = Double.random(in: 0...1) < strength.buzzProbability

        guard shouldBuzz else { return nil }

        // Buzz time based on strength (faster for stronger teams)
        let baseTime: Double
        switch strength {
        case .beginner: baseTime = 3.0
        case .intermediate: baseTime = 2.5
        case .advanced: baseTime = 2.0
        case .expert: baseTime = 1.5
        }

        return baseTime + Double.random(in: -0.5...0.5)
    }

    /// Answer a written question
    func answerWrittenQuestion(_ question: KBQuestion) -> Bool {
        Double.random(in: 0...1) < strength.accuracy
    }

    /// Answer an oral question after buzzing
    func answerOralQuestion(_ question: KBQuestion) -> Bool {
        Double.random(in: 0...1) < strength.accuracy
    }
}

// MARK: - Region Extensions

extension KBRegion {
    var writtenPointValue: Int {
        switch self {
        case .colorado, .coloradoSprings:
            return 1
        case .minnesota, .washington:
            return 1
        }
    }

    var oralPointValue: Int {
        switch self {
        case .colorado, .coloradoSprings:
            return 10
        case .minnesota, .washington:
            return 10
        }
    }

    var incorrectOralPenalty: Int {
        switch self {
        case .colorado, .coloradoSprings:
            return -5
        case .minnesota, .washington:
            return 0
        }
    }
}
