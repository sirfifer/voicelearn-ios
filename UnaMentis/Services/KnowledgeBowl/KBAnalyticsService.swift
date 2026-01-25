//
//  KBAnalyticsService.swift
//  UnaMentis
//
//  Analytics and insights generation for Knowledge Bowl
//  Provides proficiency tracking and actionable recommendations
//

import Foundation

// MARK: - KB Analytics Service

/// Provides analytics, insights, and proficiency tracking for Knowledge Bowl
actor KBAnalyticsService {
    // MARK: - Properties

    private let sessionStore: KBSessionStore

    // MARK: - Initialization

    init(sessionStore: KBSessionStore = KBSessionStore()) {
        self.sessionStore = sessionStore
    }

    // MARK: - Domain Performance

    /// Get performance breakdown by domain
    func getDomainPerformance() async throws -> [KBDomain: DomainAnalytics] {
        let sessions = try await sessionStore.loadAll()
        var domainStats: [KBDomain: DomainAnalytics] = [:]

        for session in sessions where session.isComplete {
            let performanceByDomain = session.performanceByDomain

            for (domain, performance) in performanceByDomain {
                var current = domainStats[domain] ?? DomainAnalytics(domain: domain)
                current.totalQuestions += performance.total
                current.correctAnswers += performance.correct
                current.totalResponseTime += performance.averageTime * Double(performance.total)
                domainStats[domain] = current
            }
        }

        // Calculate averages
        for (domain, var stats) in domainStats {
            if stats.totalQuestions > 0 {
                stats.averageResponseTime = stats.totalResponseTime / Double(stats.totalQuestions)
            }
            domainStats[domain] = stats
        }

        return domainStats
    }

    /// Identify weak domains (accuracy < 50% with at least 10 questions)
    func getWeakDomains() async throws -> [KBDomain] {
        let domainPerformance = try await getDomainPerformance()
        return domainPerformance
            .filter { _, analytics in
                analytics.totalQuestions >= 10 && analytics.accuracy < 0.5
            }
            .map { $0.key }
            .sorted { $0.displayName < $1.displayName }
    }

    /// Identify strong domains (accuracy >= 80% with at least 10 questions)
    func getStrongDomains() async throws -> [KBDomain] {
        let domainPerformance = try await getDomainPerformance()
        return domainPerformance
            .filter { _, analytics in
                analytics.totalQuestions >= 10 && analytics.accuracy >= 0.8
            }
            .map { $0.key }
            .sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Round Type Performance

    /// Compare written vs oral performance
    func getRoundTypeComparison() async throws -> RoundTypeComparison {
        let sessions = try await sessionStore.loadAll()

        let writtenSessions = sessions.filter { $0.config.roundType == .written && $0.isComplete }
        let oralSessions = sessions.filter { $0.config.roundType == .oral && $0.isComplete }

        let writtenQuestions = writtenSessions.reduce(0) { $0 + $1.attempts.count }
        let writtenCorrect = writtenSessions.reduce(0) { $0 + $1.correctCount }
        let writtenAccuracy = writtenQuestions > 0 ? Double(writtenCorrect) / Double(writtenQuestions) : 0

        let oralQuestions = oralSessions.reduce(0) { $0 + $1.attempts.count }
        let oralCorrect = oralSessions.reduce(0) { $0 + $1.correctCount }
        let oralAccuracy = oralQuestions > 0 ? Double(oralCorrect) / Double(oralQuestions) : 0

        return RoundTypeComparison(
            writtenAccuracy: writtenAccuracy,
            oralAccuracy: oralAccuracy,
            writtenQuestions: writtenQuestions,
            oralQuestions: oralQuestions
        )
    }

    // MARK: - Progress Trends

    /// Get accuracy trend over time
    func getAccuracyTrend(days: Int = 30) async throws -> [DateAccuracy] {
        let sessions = try await sessionStore.loadAll()
            .filter { $0.isComplete }
            .sorted { ($0.endTime ?? .distantPast) < ($1.endTime ?? .distantPast) }

        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date())!

        // Group sessions by day
        var sessionsByDay: [Date: [KBSession]] = [:]
        for session in sessions {
            guard let endTime = session.endTime, endTime >= cutoffDate else { continue }
            let day = calendar.startOfDay(for: endTime)
            sessionsByDay[day, default: []].append(session)
        }

        // Calculate daily accuracy
        let trend = sessionsByDay.map { date, sessions in
            let totalQuestions = sessions.reduce(0) { $0 + $1.attempts.count }
            let totalCorrect = sessions.reduce(0) { $0 + $1.correctCount }
            let accuracy = totalQuestions > 0 ? Double(totalCorrect) / Double(totalQuestions) : 0
            return DateAccuracy(date: date, accuracy: accuracy, questionsAnswered: totalQuestions)
        }.sorted { $0.date < $1.date }

        return trend
    }

    /// Calculate streak (consecutive days with practice)
    func calculateStreak() async throws -> Int {
        let statistics = try await sessionStore.calculateStatistics()
        return statistics.currentStreak
    }

    // MARK: - Insights Generation

    /// Generate actionable insights based on performance
    func generateInsights() async throws -> [KBInsight] {
        var insights: [KBInsight] = []

        let statistics = try await sessionStore.calculateStatistics()
        let comparison = try await getRoundTypeComparison()
        let weakDomains = try await getWeakDomains()
        let strongDomains = try await getStrongDomains()
        let domainPerformance = try await getDomainPerformance()
        let trend = try await getAccuracyTrend(days: 14)

        // Insight: Written vs Oral gap
        if comparison.writtenAccuracy > comparison.oralAccuracy + 0.15 {
            insights.append(KBInsight(
                type: .performanceGap,
                title: "Oral Practice Needed",
                message: "Your written accuracy (\(Int(comparison.writtenAccuracy * 100))%) is much higher than oral (\(Int(comparison.oralAccuracy * 100))%). Focus on oral round practice.",
                priority: .high,
                recommendedAction: "Practice 5 oral sessions this week",
                navigationDestination: .oralPractice
            ))
        } else if comparison.oralAccuracy > comparison.writtenAccuracy + 0.15 {
            insights.append(KBInsight(
                type: .performanceGap,
                title: "Written Practice Needed",
                message: "Your oral accuracy (\(Int(comparison.oralAccuracy * 100))%) is much higher than written (\(Int(comparison.writtenAccuracy * 100))%). Focus on written round practice.",
                priority: .high,
                recommendedAction: "Practice 10 written sessions this week",
                navigationDestination: .writtenPractice
            ))
        }

        // Insight: Weak domains with navigation
        if let weakestDomain = weakDomains.first {
            let domainNames = weakDomains.prefix(3).map { $0.displayName }.joined(separator: ", ")
            insights.append(KBInsight(
                type: .domainWeakness,
                title: "Domain Weaknesses Identified",
                message: "You're struggling with: \(domainNames). Dedicate practice time to these domains.",
                priority: .high,
                recommendedAction: "Drill \(weakestDomain.displayName) questions",
                navigationDestination: .domainDrill(domain: weakestDomain)
            ))
        }

        // Insight: Low practice volume
        if statistics.totalSessions < 5 {
            insights.append(KBInsight(
                type: .lowActivity,
                title: "Build Practice Habit",
                message: "You've completed only \(statistics.totalSessions) sessions. Build consistency with daily practice.",
                priority: .medium,
                recommendedAction: "Set a goal of 1 session per day"
            ))
        }

        // Insight: Streak broken
        if statistics.currentStreak == 0 && statistics.totalSessions > 0 {
            insights.append(KBInsight(
                type: .streakBroken,
                title: "Practice Streak Broken",
                message: "Your practice streak ended. Start a new streak today!",
                priority: .low,
                recommendedAction: "Complete a quick 5-question session",
                navigationDestination: .writtenPractice
            ))
        }

        // Insight: Strong performance
        if statistics.overallAccuracy >= 0.8 && statistics.totalQuestions >= 50 {
            insights.append(KBInsight(
                type: .achievement,
                title: "Excellent Performance!",
                message: "You're maintaining \(Int(statistics.overallAccuracy * 100))% accuracy. Consider practicing harder difficulty levels.",
                priority: .low,
                recommendedAction: "Try a match simulation",
                navigationDestination: .matchSimulation
            ))
        }

        // Insight: Response time improvement needed
        let slowDomains = domainPerformance.filter { $0.value.averageResponseTime > 8.0 && $0.value.totalQuestions >= 10 }
        if let slowestDomain = slowDomains.max(by: { $0.value.averageResponseTime < $1.value.averageResponseTime }) {
            insights.append(KBInsight(
                type: .responseTime,
                title: "Speed Up Your Responses",
                message: "Your average response time for \(slowestDomain.key.displayName) is \(String(format: "%.1f", slowestDomain.value.averageResponseTime))s. Practice to improve reaction time.",
                priority: .medium,
                recommendedAction: "Practice \(slowestDomain.key.displayName) under time pressure",
                navigationDestination: .domainDrill(domain: slowestDomain.key)
            ))
        }

        // Insight: Improvement trend
        if trend.count >= 7 {
            let firstHalf = trend.prefix(trend.count / 2)
            let secondHalf = trend.suffix(trend.count / 2)

            let firstAvg = firstHalf.reduce(0.0) { $0 + $1.accuracy } / Double(firstHalf.count)
            let secondAvg = secondHalf.reduce(0.0) { $0 + $1.accuracy } / Double(secondHalf.count)

            if secondAvg > firstAvg + 0.1 {
                insights.append(KBInsight(
                    type: .improvementTrend,
                    title: "You're Improving!",
                    message: "Your accuracy has improved by \(Int((secondAvg - firstAvg) * 100))% over the past two weeks. Keep up the great work!",
                    priority: .low,
                    recommendedAction: "View your progress details",
                    navigationDestination: .progress
                ))
            } else if firstAvg > secondAvg + 0.1 {
                insights.append(KBInsight(
                    type: .improvementTrend,
                    title: "Performance Dip Detected",
                    message: "Your recent accuracy has dropped \(Int((firstAvg - secondAvg) * 100))%. Consider reviewing fundamentals.",
                    priority: .high,
                    recommendedAction: "Focus on your domain weaknesses",
                    navigationDestination: .domainMastery
                ))
            }
        }

        // Insight: Competition readiness
        if statistics.overallAccuracy >= 0.75 && statistics.totalQuestions >= 100 && strongDomains.count >= 4 {
            insights.append(KBInsight(
                type: .competitionReady,
                title: "Ready for Competition!",
                message: "You've mastered \(strongDomains.count) domains with \(Int(statistics.overallAccuracy * 100))% overall accuracy. You're competition-ready!",
                priority: .medium,
                recommendedAction: "Test yourself in a match simulation",
                navigationDestination: .matchSimulation
            ))
        }

        // Insight: Rebound practice suggestion
        if comparison.oralQuestions >= 20 && comparison.oralAccuracy < 0.65 {
            insights.append(KBInsight(
                type: .reboundSkill,
                title: "Practice Rebound Strategy",
                message: "Improve your oral round performance by practicing rebound scenarios when opponents miss.",
                priority: .medium,
                recommendedAction: "Start rebound training",
                navigationDestination: .reboundPractice
            ))
        }

        // Insight: Conference practice suggestion
        if statistics.totalSessions >= 10 && comparison.oralQuestions < comparison.writtenQuestions / 2 {
            insights.append(KBInsight(
                type: .conferenceSkill,
                title: "Team Conference Skills",
                message: "Practice conferring with teammates efficiently within the 15-second window.",
                priority: .medium,
                recommendedAction: "Start conference training",
                navigationDestination: .conferencePractice
            ))
        }

        // Insight: Difficulty progression
        if statistics.overallAccuracy >= 0.85 && statistics.totalQuestions >= 50 {
            insights.append(KBInsight(
                type: .difficultyProgression,
                title: "Increase the Challenge",
                message: "With \(Int(statistics.overallAccuracy * 100))% accuracy, you're ready for harder questions. Try varsity-level difficulty.",
                priority: .low,
                recommendedAction: "Adjust difficulty settings"
            ))
        }

        return insights.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }

    // MARK: - Mastery Levels

    /// Calculate mastery level for each domain
    func getDomainMastery() async throws -> [KBDomain: MasteryLevel] {
        let domainPerformance = try await getDomainPerformance()
        var mastery: [KBDomain: MasteryLevel] = [:]

        for (domain, analytics) in domainPerformance {
            mastery[domain] = MasteryLevel.from(
                accuracy: analytics.accuracy,
                questionsAttempted: analytics.totalQuestions
            )
        }

        return mastery
    }
}

// MARK: - Domain Analytics

struct DomainAnalytics {
    let domain: KBDomain
    var totalQuestions: Int = 0
    var correctAnswers: Int = 0
    var totalResponseTime: TimeInterval = 0
    var averageResponseTime: TimeInterval = 0

    var accuracy: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(correctAnswers) / Double(totalQuestions)
    }
}

// MARK: - Round Type Comparison

struct RoundTypeComparison {
    let writtenAccuracy: Double
    let oralAccuracy: Double
    let writtenQuestions: Int
    let oralQuestions: Int

    var gap: Double {
        abs(writtenAccuracy - oralAccuracy)
    }

    var hasSignificantGap: Bool {
        gap > 0.15
    }
}

// MARK: - Date Accuracy

struct DateAccuracy: Identifiable {
    let date: Date
    let accuracy: Double
    let questionsAnswered: Int

    var id: Date { date }
}

// MARK: - Insights

struct KBInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let message: String
    let priority: InsightPriority
    let recommendedAction: String
    let navigationDestination: InsightDestination?

    init(
        type: InsightType,
        title: String,
        message: String,
        priority: InsightPriority,
        recommendedAction: String,
        navigationDestination: InsightDestination? = nil
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.priority = priority
        self.recommendedAction = recommendedAction
        self.navigationDestination = navigationDestination
    }

    var icon: String { type.icon }
}

enum InsightDestination {
    case oralPractice
    case writtenPractice
    case domainDrill(domain: KBDomain)
    case conferencePractice
    case reboundPractice
    case matchSimulation
    case domainMastery
    case progress
}

enum InsightType: String {
    case performanceGap = "performance_gap"
    case domainWeakness = "domain_weakness"
    case lowActivity = "low_activity"
    case streakBroken = "streak_broken"
    case achievement = "achievement"
    case responseTime = "response_time"
    case improvementTrend = "improvement_trend"
    case competitionReady = "competition_ready"
    case reboundSkill = "rebound_skill"
    case conferenceSkill = "conference_skill"
    case difficultyProgression = "difficulty_progression"
    case timePatterns = "time_patterns"
    case matchPerformance = "match_performance"

    var icon: String {
        switch self {
        case .performanceGap: return "chart.bar.xaxis"
        case .domainWeakness: return "exclamationmark.triangle"
        case .lowActivity: return "calendar.badge.exclamationmark"
        case .streakBroken: return "flame.fill"
        case .achievement: return "star.fill"
        case .responseTime: return "timer"
        case .improvementTrend: return "arrow.up.right"
        case .competitionReady: return "trophy"
        case .reboundSkill: return "arrow.uturn.backward"
        case .conferenceSkill: return "person.3"
        case .difficultyProgression: return "gauge.with.needle"
        case .timePatterns: return "clock"
        case .matchPerformance: return "flag.2.crossed"
        }
    }
}

enum InsightPriority: Int {
    case high = 3
    case medium = 2
    case low = 1
}

// MARK: - Mastery Level

enum MasteryLevel: String, CaseIterable {
    case notStarted = "Not Started"
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case mastered = "Mastered"

    static func from(accuracy: Double, questionsAttempted: Int) -> MasteryLevel {
        if questionsAttempted == 0 {
            return .notStarted
        } else if questionsAttempted < 5 {
            return .beginner
        } else if accuracy < 0.5 {
            return .beginner
        } else if accuracy < 0.7 {
            return .intermediate
        } else if accuracy < 0.85 {
            return .advanced
        } else {
            return .mastered
        }
    }

    var color: String {
        switch self {
        case .notStarted: return "kbNotStarted"
        case .beginner: return "kbBeginner"
        case .intermediate: return "kbIntermediate"
        case .advanced: return "kbAdvanced"
        case .mastered: return "kbMastered"
        }
    }
}
