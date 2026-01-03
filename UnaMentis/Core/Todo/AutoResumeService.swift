// UnaMentis - Auto Resume Service
// Detects and creates auto-resume to-do items when sessions are stopped mid-curriculum
//
// Part of Todo System

import Foundation
import CoreData
import Logging

/// Context needed for auto-resume item creation
public struct AutoResumeContext: Sendable {
    public let topicId: UUID
    public let topicTitle: String
    public let curriculumId: UUID?
    public let segmentIndex: Int32
    public let totalSegments: Int32
    public let sessionDuration: TimeInterval
    public let conversationMessages: [ResumeConversationMessage]

    public init(
        topicId: UUID,
        topicTitle: String,
        curriculumId: UUID?,
        segmentIndex: Int32,
        totalSegments: Int32,
        sessionDuration: TimeInterval,
        conversationMessages: [ResumeConversationMessage]
    ) {
        self.topicId = topicId
        self.topicTitle = topicTitle
        self.curriculumId = curriculumId
        self.segmentIndex = segmentIndex
        self.totalSegments = totalSegments
        self.sessionDuration = sessionDuration
        self.conversationMessages = conversationMessages
    }
}

/// Simplified conversation message for serialization in auto-resume context
public struct ResumeConversationMessage: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// Service for detecting and creating auto-resume to-do items
public actor AutoResumeService {
    // MARK: - Singleton

    public static let shared = AutoResumeService()

    // MARK: - Properties

    private let logger = Logger(label: "com.unamentis.todo.autoresume")

    /// Minimum session duration (in seconds) to consider for auto-resume
    private let minimumSessionDuration: TimeInterval = 120 // 2 minutes

    /// Maximum number of conversation messages to store for context
    private let maxConversationContext: Int = 10

    // MARK: - Auto Resume Detection

    /// Check if an auto-resume item should be created and create it if conditions are met
    /// - Parameter context: The context from the stopped session
    /// - Returns: True if an auto-resume item was created or updated
    @discardableResult
    public func handleSessionStop(context: AutoResumeContext) async -> Bool {
        logger.info("Evaluating auto-resume for topic: \(context.topicTitle)")

        // Check conditions for auto-resume
        guard shouldCreateAutoResume(context: context) else {
            logger.info("Auto-resume not needed: conditions not met")
            return false
        }

        // Create or update the auto-resume item
        do {
            try await createAutoResumeItem(context: context)
            logger.info("Auto-resume item created/updated for topic: \(context.topicTitle)")
            return true
        } catch {
            logger.error("Failed to create auto-resume item: \(error)")
            return false
        }
    }

    /// Determine if auto-resume item should be created
    private func shouldCreateAutoResume(context: AutoResumeContext) -> Bool {
        // Condition 1: Session was substantive (> minimum duration)
        guard context.sessionDuration >= minimumSessionDuration else {
            logger.debug("Session too short for auto-resume: \(context.sessionDuration)s < \(minimumSessionDuration)s")
            return false
        }

        // Condition 2: Not at the beginning (segmentIndex > 0)
        guard context.segmentIndex > 0 else {
            logger.debug("At beginning of topic, no auto-resume needed")
            return false
        }

        // Condition 3: Not at the end (not completed)
        guard context.segmentIndex < context.totalSegments - 1 else {
            logger.debug("Topic appears complete, no auto-resume needed")
            return false
        }

        logger.debug("Auto-resume conditions met: segment \(context.segmentIndex)/\(context.totalSegments), duration \(context.sessionDuration)s")
        return true
    }

    /// Create or update the auto-resume to-do item
    private func createAutoResumeItem(context: AutoResumeContext) async throws {
        // Encode conversation context
        let contextData = try encodeConversationContext(context.conversationMessages)

        // Create title
        let title = "Continue: \(context.topicTitle)"

        // Use TodoManager to create/update the item
        await MainActor.run {
            guard let manager = TodoManager.shared else {
                logger.error("TodoManager.shared is nil, cannot create auto-resume item")
                return
            }

            do {
                _ = try manager.createAutoResumeItem(
                    title: title,
                    topicId: context.topicId,
                    segmentIndex: context.segmentIndex,
                    conversationContext: contextData
                )
            } catch {
                logger.error("Failed to create auto-resume item via TodoManager: \(error)")
            }
        }
    }

    /// Encode conversation messages to Data for storage
    private func encodeConversationContext(_ messages: [ResumeConversationMessage]) throws -> Data {
        // Take only the last N messages (excluding system prompt)
        let recentMessages = messages
            .filter { $0.role != "system" }
            .suffix(maxConversationContext)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(Array(recentMessages))
    }

    // MARK: - Resume Context Retrieval

    /// Get decoded conversation context for a topic
    /// - Parameter topicId: The topic ID to get context for
    /// - Returns: Array of conversation messages or nil if not found
    public func getConversationContext(for topicId: UUID) async -> [ResumeConversationMessage]? {
        do {
            guard let manager = await TodoManager.shared else {
                return nil
            }

            guard let resumeData = try await manager.getResumeContext(for: topicId) else {
                return nil
            }

            guard let contextData = resumeData.context else {
                return nil
            }

            let decoder = JSONDecoder()
            return try decoder.decode([ResumeConversationMessage].self, from: contextData)
        } catch {
            logger.error("Failed to decode conversation context: \(error)")
            return nil
        }
    }

    /// Get the segment index for a topic resume
    /// - Parameter topicId: The topic ID to get resume point for
    /// - Returns: Segment index or nil if not found
    public func getResumeSegmentIndex(for topicId: UUID) async -> Int32? {
        do {
            guard let manager = await TodoManager.shared else {
                return nil
            }

            guard let resumeData = try await manager.getResumeContext(for: topicId) else {
                return nil
            }

            return resumeData.segmentIndex
        } catch {
            logger.error("Failed to get resume segment index: \(error)")
            return nil
        }
    }

    // MARK: - Clear Auto Resume

    /// Clear auto-resume for a topic (call when topic is completed normally)
    /// - Parameter topicId: The topic ID to clear
    public func clearAutoResume(for topicId: UUID) async {
        do {
            guard let manager = await TodoManager.shared else {
                logger.error("TodoManager.shared is nil, cannot clear auto-resume")
                return
            }

            try await manager.clearAutoResume(for: topicId)
            logger.info("Cleared auto-resume for topic: \(topicId)")
        } catch {
            logger.error("Failed to clear auto-resume: \(error)")
        }
    }
}
