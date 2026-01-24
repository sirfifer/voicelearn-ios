//
//  KBConferenceManager.swift
//  UnaMentis
//
//  Manages conference training sessions for Knowledge Bowl.
//  Trains team conferring efficiency within time limits.
//

import Foundation
import os

// MARK: - Conference Training Configuration

/// Configuration for conference training sessions
struct KBConferenceConfig: Codable, Sendable {
    let region: KBRegion
    let baseTimeLimit: TimeInterval
    let progressiveDifficulty: Bool
    let handSignalsOnly: Bool
    let questionCount: Int

    /// Time limits for progressive difficulty levels
    static let progressiveLevels: [TimeInterval] = [15, 12, 10, 8]

    /// Default config for a region
    static func forRegion(_ region: KBRegion) -> KBConferenceConfig {
        let config = region.config
        return KBConferenceConfig(
            region: region,
            baseTimeLimit: config.conferenceTime,
            progressiveDifficulty: true,
            handSignalsOnly: !config.verbalConferringAllowed,
            questionCount: 15
        )
    }

    /// Current time limit based on difficulty level (0-indexed)
    func timeLimit(forLevel level: Int) -> TimeInterval {
        guard progressiveDifficulty else { return baseTimeLimit }
        let clampedLevel = min(level, Self.progressiveLevels.count - 1)
        return Self.progressiveLevels[clampedLevel]
    }
}

// MARK: - Conference Attempt

/// Records a single conference attempt during training
struct KBConferenceAttempt: Codable, Identifiable, Sendable {
    let id: UUID
    let questionId: UUID
    let domain: KBDomain
    let conferenceTime: TimeInterval
    let timeLimitUsed: TimeInterval
    let wasCorrect: Bool
    let usedFullTime: Bool
    let signalUsed: KBHandSignal?
    let timestamp: Date

    init(
        id: UUID = UUID(),
        questionId: UUID,
        domain: KBDomain,
        conferenceTime: TimeInterval,
        timeLimitUsed: TimeInterval,
        wasCorrect: Bool,
        signalUsed: KBHandSignal? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.questionId = questionId
        self.domain = domain
        self.conferenceTime = conferenceTime
        self.timeLimitUsed = timeLimitUsed
        self.wasCorrect = wasCorrect
        self.usedFullTime = conferenceTime >= timeLimitUsed * 0.95
        self.signalUsed = signalUsed
        self.timestamp = timestamp
    }

    /// Efficiency ratio (0-1, higher is better, meaning faster decisions)
    var efficiency: Double {
        guard timeLimitUsed > 0 else { return 0 }
        return max(0, 1.0 - (conferenceTime / timeLimitUsed))
    }
}

// MARK: - Hand Signals

/// Standard Knowledge Bowl hand signals for non-verbal conferring
enum KBHandSignal: String, Codable, CaseIterable, Sendable {
    case confident = "confident"        // Thumbs up - "I know this"
    case unsure = "unsure"              // Flat hand wobble - "Not sure"
    case pass = "pass"                  // Wave off - "Skip this"
    case wait = "wait"                  // Raised finger - "Wait, thinking"
    case answer = "answer"              // Point - "I have the answer"
    case agree = "agree"                // Nod/thumbs sideways - "Agree with that"
    case disagree = "disagree"          // Shake head - "Don't think so"

    var displayName: String {
        switch self {
        case .confident: return "Confident"
        case .unsure: return "Unsure"
        case .pass: return "Pass"
        case .wait: return "Wait"
        case .answer: return "Have Answer"
        case .agree: return "Agree"
        case .disagree: return "Disagree"
        }
    }

    var gestureDescription: String {
        switch self {
        case .confident: return "Thumbs up"
        case .unsure: return "Flat hand wobble"
        case .pass: return "Wave off"
        case .wait: return "Raised finger"
        case .answer: return "Point to self"
        case .agree: return "Nod or thumbs sideways"
        case .disagree: return "Subtle head shake"
        }
    }

    var emoji: String {
        switch self {
        case .confident: return "👍"
        case .unsure: return "🤔"
        case .pass: return "👋"
        case .wait: return "☝️"
        case .answer: return "👆"
        case .agree: return "👌"
        case .disagree: return "🙅"
        }
    }
}

// MARK: - Conference Session Statistics

/// Statistics for a conference training session
struct KBConferenceStats: Codable, Sendable {
    let totalAttempts: Int
    let correctCount: Int
    let averageConferenceTime: TimeInterval
    let fastestTime: TimeInterval
    let slowestTime: TimeInterval
    let timeoutsCount: Int
    let currentDifficultyLevel: Int
    let signalDistribution: [KBHandSignal: Int]

    var accuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(correctCount) / Double(totalAttempts)
    }

    var averageEfficiency: Double {
        // Placeholder calculation - would need actual data
        guard totalAttempts > 0, averageConferenceTime > 0 else { return 0 }
        let baseTime = KBConferenceConfig.progressiveLevels[currentDifficultyLevel]
        return max(0, 1.0 - (averageConferenceTime / baseTime))
    }

    var timeoutRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(timeoutsCount) / Double(totalAttempts)
    }
}

// MARK: - Conference Manager

/// Manages conference training sessions
actor KBConferenceManager {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.unamentis", category: "KBConferenceManager")
    private var config: KBConferenceConfig
    private var attempts: [KBConferenceAttempt] = []
    private var currentDifficultyLevel: Int = 0
    private var consecutiveCorrect: Int = 0
    private var sessionStartTime: Date?
    private var isActive: Bool = false

    // Thresholds for difficulty progression
    private let promotionThreshold = 3  // Correct answers to advance
    private let demotionThreshold = 2   // Timeouts to go back

    // MARK: - Initialization

    init(config: KBConferenceConfig) {
        self.config = config
    }

    init(region: KBRegion) {
        self.config = .forRegion(region)
    }

    // MARK: - Session Lifecycle

    /// Start a new conference training session
    func startSession() {
        attempts = []
        currentDifficultyLevel = 0
        consecutiveCorrect = 0
        sessionStartTime = Date()
        isActive = true
        logger.info("Conference training session started for \(self.config.region.displayName)")
    }

    /// End the current session and return statistics
    func endSession() -> KBConferenceStats {
        isActive = false
        let stats = calculateStats()
        logger.info("Conference session ended: \(stats.totalAttempts) attempts, \(stats.accuracy * 100, format: .fixed(precision: 1))% accuracy")
        return stats
    }

    /// Check if session is active
    func isSessionActive() -> Bool {
        isActive
    }

    // MARK: - Training Flow

    /// Get current time limit for this round
    func getCurrentTimeLimit() -> TimeInterval {
        config.timeLimit(forLevel: currentDifficultyLevel)
    }

    /// Get current difficulty level (0-indexed)
    func getCurrentDifficultyLevel() -> Int {
        currentDifficultyLevel
    }

    /// Record a conference attempt
    func recordAttempt(
        questionId: UUID,
        domain: KBDomain,
        conferenceTime: TimeInterval,
        wasCorrect: Bool,
        signalUsed: KBHandSignal? = nil
    ) {
        let attempt = KBConferenceAttempt(
            questionId: questionId,
            domain: domain,
            conferenceTime: conferenceTime,
            timeLimitUsed: getCurrentTimeLimit(),
            wasCorrect: wasCorrect,
            signalUsed: signalUsed
        )

        attempts.append(attempt)
        updateDifficulty(wasCorrect: wasCorrect, timedOut: attempt.usedFullTime)

        logger.debug("Conference attempt: \(conferenceTime, format: .fixed(precision: 1))s, correct: \(wasCorrect), level: \(self.currentDifficultyLevel)")
    }

    // MARK: - Difficulty Progression

    private func updateDifficulty(wasCorrect: Bool, timedOut: Bool) {
        guard config.progressiveDifficulty else { return }

        if wasCorrect && !timedOut {
            consecutiveCorrect += 1

            // Promote to harder difficulty
            if consecutiveCorrect >= promotionThreshold {
                let maxLevel = KBConferenceConfig.progressiveLevels.count - 1
                if currentDifficultyLevel < maxLevel {
                    currentDifficultyLevel += 1
                    consecutiveCorrect = 0
                    logger.info("Advanced to difficulty level \(self.currentDifficultyLevel)")
                }
            }
        } else if timedOut {
            // Demote on timeouts
            if currentDifficultyLevel > 0 {
                currentDifficultyLevel -= 1
                consecutiveCorrect = 0
                logger.info("Dropped to difficulty level \(self.currentDifficultyLevel)")
            }
        } else {
            // Wrong answer resets consecutive counter
            consecutiveCorrect = max(0, consecutiveCorrect - 1)
        }
    }

    // MARK: - Statistics

    /// Calculate current session statistics
    func calculateStats() -> KBConferenceStats {
        guard !attempts.isEmpty else {
            return KBConferenceStats(
                totalAttempts: 0,
                correctCount: 0,
                averageConferenceTime: 0,
                fastestTime: 0,
                slowestTime: 0,
                timeoutsCount: 0,
                currentDifficultyLevel: currentDifficultyLevel,
                signalDistribution: [:]
            )
        }

        let times = attempts.map { $0.conferenceTime }
        let avgTime = times.reduce(0, +) / Double(times.count)

        var signalDist: [KBHandSignal: Int] = [:]
        for attempt in attempts {
            if let signal = attempt.signalUsed {
                signalDist[signal, default: 0] += 1
            }
        }

        return KBConferenceStats(
            totalAttempts: attempts.count,
            correctCount: attempts.filter { $0.wasCorrect }.count,
            averageConferenceTime: avgTime,
            fastestTime: times.min() ?? 0,
            slowestTime: times.max() ?? 0,
            timeoutsCount: attempts.filter { $0.usedFullTime }.count,
            currentDifficultyLevel: currentDifficultyLevel,
            signalDistribution: signalDist
        )
    }

    /// Get attempts for a specific domain
    func getAttempts(for domain: KBDomain) -> [KBConferenceAttempt] {
        attempts.filter { $0.domain == domain }
    }

    /// Get all attempts
    func getAllAttempts() -> [KBConferenceAttempt] {
        attempts
    }

    // MARK: - Hand Signal Training

    /// Get a random hand signal prompt for training
    static func randomSignalPrompt() -> (signal: KBHandSignal, scenario: String) {
        let scenarios: [(KBHandSignal, String)] = [
            (.confident, "You know the answer is 'Paris' for certain"),
            (.unsure, "You think it might be 'Rome' but aren't sure"),
            (.pass, "You have no idea and want to skip"),
            (.wait, "You're still processing the question"),
            (.answer, "You want to be the one to buzz in"),
            (.agree, "Your teammate suggests 'London' and you agree"),
            (.disagree, "Your teammate suggests 'Berlin' but you think it's wrong")
        ]
        return scenarios.randomElement() ?? (.confident, "You know the answer")
    }

    /// Validate a hand signal response
    static func validateSignal(expected: KBHandSignal, given: KBHandSignal) -> Bool {
        expected == given
    }
}

// MARK: - Conference Training Result

/// Result of a complete conference training session
struct KBConferenceTrainingResult: Codable, Sendable {
    let sessionId: UUID
    let region: KBRegion
    let startTime: Date
    let endTime: Date
    let stats: KBConferenceStats
    let finalDifficultyLevel: Int
    let recommendation: String

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    /// Generate training recommendation based on results
    static func generateRecommendation(from stats: KBConferenceStats) -> String {
        if stats.timeoutRate > 0.3 {
            return "Focus on faster decision-making. Try to identify which teammate has domain expertise quickly."
        } else if stats.accuracy < 0.6 {
            return "Conference time is good, but accuracy needs work. Practice question analysis before conferring."
        } else if stats.averageEfficiency > 0.7 && stats.accuracy > 0.8 {
            return "Excellent conferring! Ready to practice at faster time limits."
        } else {
            return "Good progress! Continue practicing to build faster conference habits."
        }
    }
}
