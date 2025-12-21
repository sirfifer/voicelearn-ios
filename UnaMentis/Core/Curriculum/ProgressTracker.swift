// UnaMentis - Progress Tracker
// Tracks learning progress for topics including mastery, time spent, and quiz scores
//
// Part of Curriculum Layer (TDD Section 4)

import Foundation
import CoreData
import Logging

/// Actor responsible for tracking and managing topic learning progress
///
/// Responsibilities:
/// - Create and manage TopicProgress entities
/// - Track time spent on topics
/// - Update mastery levels
/// - Record quiz scores
/// - Manage concepts covered
public actor ProgressTracker {

    // MARK: - Properties

    private let persistenceController: PersistenceController
    private let logger = Logger(label: "com.unamentis.progresstracker")

    // MARK: - Initialization

    /// Initialize progress tracker with persistence controller
    /// - Parameter persistenceController: Core Data persistence controller
    public init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        logger.info("ProgressTracker initialized")
    }

    // MARK: - Progress Creation

    /// Create new progress record for a topic
    /// - Parameter topic: Topic to create progress for
    /// - Returns: Created TopicProgress entity
    @MainActor
    public func createProgress(for topic: Topic) throws -> TopicProgress {
        let context = persistenceController.viewContext

        let progress = TopicProgress(context: context)
        progress.id = UUID()
        progress.topic = topic
        progress.timeSpent = 0
        progress.lastAccessed = Date()
        progress.quizScores = nil

        // Link topic to progress
        topic.progress = progress

        try persistenceController.save()
        logger.debug("Created progress for topic: \(topic.title ?? "Unknown")")

        return progress
    }

    // MARK: - Time Tracking

    /// Update time spent on a topic
    /// - Parameters:
    ///   - progress: Progress record to update
    ///   - additionalTime: Additional time to add in seconds
    @MainActor
    public func updateTimeSpent(progress: TopicProgress, additionalTime: TimeInterval) throws {
        progress.timeSpent += additionalTime
        progress.lastAccessed = Date()

        try persistenceController.save()
        logger.debug("Updated time spent: +\(additionalTime)s, total: \(progress.timeSpent)s")
    }

    // MARK: - Mastery Updates

    /// Update mastery level for a topic
    /// - Parameters:
    ///   - topic: Topic to update
    ///   - level: New mastery level (0.0 - 1.0)
    @MainActor
    public func updateMastery(topic: Topic, level: Float) throws {
        // Clamp to valid range
        let clampedLevel = max(0.0, min(1.0, level))
        topic.mastery = clampedLevel

        if let progress = topic.progress {
            progress.lastAccessed = Date()
        }

        try persistenceController.save()
        logger.debug("Updated mastery for \(topic.title ?? "Unknown"): \(clampedLevel)")
    }

    /// Mark a topic as completed with final mastery level
    /// - Parameters:
    ///   - topic: Topic to mark complete
    ///   - masteryLevel: Final mastery level (defaults to 0.8)
    @MainActor
    public func markCompleted(topic: Topic, masteryLevel: Float = 0.8) throws {
        // Ensure mastery meets completion threshold
        let finalMastery = max(masteryLevel, 0.8)
        topic.mastery = finalMastery

        if let progress = topic.progress {
            progress.lastAccessed = Date()
        }

        try persistenceController.save()
        logger.info("Marked topic completed: \(topic.title ?? "Unknown") with mastery \(finalMastery)")
    }

    // MARK: - Concepts Tracking

    /// Add concepts covered during learning
    /// - Parameters:
    ///   - progress: Progress record to update
    ///   - concepts: Array of concept identifiers/names
    @MainActor
    public func addConceptsCovered(progress: TopicProgress, concepts: [String]) throws {
        // Get existing concepts or empty array
        var existingConcepts = getConceptsCoveredSync(for: progress)

        // Add new concepts, deduplicating
        for concept in concepts {
            if !existingConcepts.contains(concept) {
                existingConcepts.append(concept)
            }
        }

        // Store as transformable [String]
        // Note: TopicProgress doesn't have conceptsCovered in current schema
        // We'll store in user info or as JSON in a field
        // For now, we'll use the topic's objectives as a proxy
        progress.lastAccessed = Date()

        try persistenceController.save()
        logger.debug("Added \(concepts.count) concepts, total: \(existingConcepts.count)")
    }

    /// Get concepts covered for a progress record
    /// - Parameter progress: Progress record to query
    /// - Returns: Array of concept identifiers
    @MainActor
    public func getConceptsCovered(for progress: TopicProgress) -> [String] {
        return getConceptsCoveredSync(for: progress)
    }

    @MainActor
    private func getConceptsCoveredSync(for progress: TopicProgress) -> [String] {
        // For now return empty - would need schema update for conceptsCovered field
        // In production, this would read from progress.conceptsCovered
        return []
    }

    // MARK: - Quiz Score Tracking

    /// Record a quiz score for the topic
    /// - Parameters:
    ///   - progress: Progress record to update
    ///   - score: Quiz score (0.0 - 1.0)
    @MainActor
    public func recordQuizScore(progress: TopicProgress, score: Float) throws {
        var scores = progress.quizScores ?? []
        scores.append(score)
        progress.quizScores = scores
        progress.lastAccessed = Date()

        try persistenceController.save()
        logger.debug("Recorded quiz score: \(score), total scores: \(scores.count)")
    }

    /// Calculate average quiz score for a progress record
    /// - Parameter progress: Progress record to calculate for
    /// - Returns: Average score (0.0 - 1.0) or 0 if no scores
    @MainActor
    public func averageQuizScore(for progress: TopicProgress) -> Float {
        guard let scores = progress.quizScores, !scores.isEmpty else {
            return 0.0
        }
        let sum = scores.reduce(0, +)
        return sum / Float(scores.count)
    }

    // MARK: - Progress Queries

    /// Get progress statistics for a topic
    /// - Parameter topic: Topic to get statistics for
    /// - Returns: Progress statistics or nil if no progress
    @MainActor
    public func getProgressStatistics(for topic: Topic) -> ProgressStatistics? {
        guard let progress = topic.progress else { return nil }

        let avgQuizScore: Float
        if let scores = progress.quizScores, !scores.isEmpty {
            avgQuizScore = scores.reduce(0, +) / Float(scores.count)
        } else {
            avgQuizScore = 0
        }

        return ProgressStatistics(
            timeSpent: progress.timeSpent,
            masteryLevel: topic.mastery,
            averageQuizScore: avgQuizScore,
            quizCount: progress.quizScores?.count ?? 0,
            lastAccessed: progress.lastAccessed,
            status: topic.status
        )
    }

    /// Check if topic meets completion criteria
    /// - Parameter topic: Topic to check
    /// - Returns: True if topic meets completion criteria
    @MainActor
    public func isCompleted(topic: Topic) -> Bool {
        return topic.status == .completed
    }
}

// MARK: - Progress Statistics

/// Statistics about topic progress
public struct ProgressStatistics: Sendable {
    /// Total time spent in seconds
    public let timeSpent: TimeInterval

    /// Current mastery level (0.0 - 1.0)
    public let masteryLevel: Float

    /// Average quiz score (0.0 - 1.0)
    public let averageQuizScore: Float

    /// Number of quizzes taken
    public let quizCount: Int

    /// Last time topic was accessed
    public let lastAccessed: Date?

    /// Current status
    public let status: TopicStatus

    /// Formatted time spent string
    public var formattedTimeSpent: String {
        let hours = Int(timeSpent) / 3600
        let minutes = (Int(timeSpent) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Mastery percentage string
    public var masteryPercentage: String {
        return "\(Int(masteryLevel * 100))%"
    }
}
