// UnaMentis - Knowledge Bowl Stats Manager
// Persists and tracks practice session statistics
//
// Stores domain mastery, session history, and aggregate stats
// using UserDefaults for simplicity.

import Foundation
import Logging

/// Manages persistent statistics for Knowledge Bowl practice
@MainActor
final class KBStatsManager: ObservableObject {
    static let shared = KBStatsManager()

    // MARK: - Published Stats

    @Published private(set) var totalQuestionsAnswered: Int = 0
    @Published private(set) var totalCorrectAnswers: Int = 0
    @Published private(set) var averageResponseTime: Double = 0
    @Published private(set) var domainStats: [String: DomainStats] = [:]
    @Published private(set) var recentSessions: [SessionRecord] = []

    // MARK: - Computed Properties

    var overallAccuracy: Double {
        guard totalQuestionsAnswered > 0 else { return 0 }
        return Double(totalCorrectAnswers) / Double(totalQuestionsAnswered)
    }

    /// Competition readiness based on domain coverage and accuracy
    var competitionReadiness: Double {
        guard totalQuestionsAnswered > 0 else { return 0 }

        // Factors: accuracy, domain coverage, volume
        let accuracyScore = overallAccuracy
        let coveredDomains = domainStats.filter { $0.value.totalAnswered >= 5 }.count
        let coverageScore = Double(coveredDomains) / 12.0  // 12 domains
        let volumeScore = min(1.0, Double(totalQuestionsAnswered) / 200.0)  // Target: 200 questions

        // Weighted average
        return (accuracyScore * 0.5 + coverageScore * 0.3 + volumeScore * 0.2)
    }

    // MARK: - Private

    private static let logger = Logger(label: "com.unamentis.kb.stats")
    private let defaults: UserDefaults

    private enum Keys {
        static let totalQuestions = "kb_total_questions"
        static let totalCorrect = "kb_total_correct"
        static let totalResponseTime = "kb_total_response_time"
        static let domainStats = "kb_domain_stats"
        static let recentSessions = "kb_recent_sessions"
    }

    /// Normalize a domain ID for consistent storage and lookup
    func normalizeDomainId(_ domainId: String) -> String {
        domainId.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "&", with: "")
            .replacingOccurrences(of: "--", with: "-")
    }

    private init() {
        self.defaults = UserDefaults.standard
        loadStats()
    }

    /// Testing initializer with injectable UserDefaults
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // MARK: - Public Methods

    /// Record results from a completed practice session
    func recordSession(_ summary: KBSessionSummary, mode: KBStudyMode) {
        // Update totals
        totalQuestionsAnswered += summary.totalQuestions
        totalCorrectAnswers += summary.correctAnswers

        // Update average response time (running average)
        let totalTime = averageResponseTime * Double(totalQuestionsAnswered - summary.totalQuestions)
        let newTotalTime = totalTime + (summary.averageResponseTime * Double(summary.totalQuestions))
        if totalQuestionsAnswered > 0 {
            averageResponseTime = newTotalTime / Double(totalQuestionsAnswered)
        }

        // Update domain stats (normalize IDs for consistent storage)
        for (domainId, score) in summary.domainBreakdown {
            let normalizedId = normalizeDomainId(domainId)
            var stats = domainStats[normalizedId] ?? DomainStats()
            stats.totalAnswered += score.total
            stats.totalCorrect += score.correct
            domainStats[normalizedId] = stats
        }

        // Add session record
        let record = SessionRecord(
            id: UUID(),
            date: Date(),
            mode: mode.rawValue,
            questionsAnswered: summary.totalQuestions,
            correctAnswers: summary.correctAnswers,
            averageTime: summary.averageResponseTime
        )
        recentSessions.insert(record, at: 0)

        // Keep only last 20 sessions
        if recentSessions.count > 20 {
            recentSessions = Array(recentSessions.prefix(20))
        }

        // Persist
        saveStats()

        Self.logger.info("Recorded session: \(summary.correctAnswers)/\(summary.totalQuestions) correct")
    }

    /// Get mastery percentage for a specific domain
    func mastery(for domainId: String) -> Double {
        let normalizedId = normalizeDomainId(domainId)
        guard let stats = domainStats[normalizedId], stats.totalAnswered > 0 else {
            return 0
        }
        return Double(stats.totalCorrect) / Double(stats.totalAnswered)
    }

    /// Get mastery for a KBDomain
    func mastery(for domain: KBDomain) -> Double {
        mastery(for: domain.rawValue)
    }

    /// Reset all statistics
    func resetStats() {
        totalQuestionsAnswered = 0
        totalCorrectAnswers = 0
        averageResponseTime = 0
        domainStats = [:]
        recentSessions = []
        saveStats()

        Self.logger.info("Stats reset")
    }

    // MARK: - Persistence

    private func loadStats() {
        totalQuestionsAnswered = defaults.integer(forKey: Keys.totalQuestions)
        totalCorrectAnswers = defaults.integer(forKey: Keys.totalCorrect)
        averageResponseTime = defaults.double(forKey: Keys.totalResponseTime)

        // Load domain stats
        if let data = defaults.data(forKey: Keys.domainStats),
           let decoded = try? JSONDecoder().decode([String: DomainStats].self, from: data) {
            domainStats = decoded
        }

        // Load recent sessions
        if let data = defaults.data(forKey: Keys.recentSessions),
           let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data) {
            recentSessions = decoded
        }

        Self.logger.info("Loaded stats: \(totalQuestionsAnswered) questions, \(totalCorrectAnswers) correct")
    }

    private func saveStats() {
        defaults.set(totalQuestionsAnswered, forKey: Keys.totalQuestions)
        defaults.set(totalCorrectAnswers, forKey: Keys.totalCorrect)
        defaults.set(averageResponseTime, forKey: Keys.totalResponseTime)

        // Save domain stats
        if let encoded = try? JSONEncoder().encode(domainStats) {
            defaults.set(encoded, forKey: Keys.domainStats)
        }

        // Save recent sessions
        if let encoded = try? JSONEncoder().encode(recentSessions) {
            defaults.set(encoded, forKey: Keys.recentSessions)
        }
    }
}

// MARK: - Supporting Types

struct DomainStats: Codable, Sendable {
    var totalAnswered: Int = 0
    var totalCorrect: Int = 0

    var accuracy: Double {
        guard totalAnswered > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAnswered)
    }
}

struct SessionRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let mode: String
    let questionsAnswered: Int
    let correctAnswers: Int
    let averageTime: Double

    var accuracy: Double {
        guard questionsAnswered > 0 else { return 0 }
        return Double(correctAnswers) / Double(questionsAnswered)
    }
}
