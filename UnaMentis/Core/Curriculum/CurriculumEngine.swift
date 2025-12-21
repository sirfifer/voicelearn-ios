// UnaMentis - Curriculum Engine
// Central engine for curriculum management, context generation, and topic navigation
//
// Part of Curriculum Layer (TDD Section 4)

import Foundation
import CoreData
import Logging

/// Actor responsible for managing curriculum state and generating LLM context
///
/// Responsibilities:
/// - Load and manage curriculum from Core Data
/// - Generate context for LLM based on topic materials
/// - Track progress across topics
/// - Provide semantic search across documents
public actor CurriculumEngine: ObservableObject {

    // MARK: - Properties

    private let persistenceController: PersistenceController
    private let embeddingService: (any EmbeddingService)?
    private let telemetry: TelemetryEngine?
    private let logger = Logger(label: "com.unamentis.curriculumengine")

    /// Currently loaded curriculum
    @MainActor @Published public private(set) var activeCurriculum: Curriculum?

    /// Current topic being studied
    @MainActor @Published public private(set) var currentTopic: Topic?

    // MARK: - Initialization

    /// Initialize curriculum engine with required dependencies
    /// - Parameters:
    ///   - persistenceController: Core Data persistence controller
    ///   - embeddingService: Optional embedding service for semantic search
    ///   - telemetry: Optional telemetry engine for event tracking
    public init(
        persistenceController: PersistenceController,
        embeddingService: (any EmbeddingService)? = nil,
        telemetry: TelemetryEngine? = nil
    ) {
        self.persistenceController = persistenceController
        self.embeddingService = embeddingService
        self.telemetry = telemetry
        logger.info("CurriculumEngine initialized")
    }

    // MARK: - Curriculum Loading

    /// Load a curriculum by ID
    /// - Parameter id: UUID of curriculum to load
    @MainActor
    public func loadCurriculum(_ id: UUID) throws {
        let request = Curriculum.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        let results = try persistenceController.viewContext.fetch(request)

        guard let curriculum = results.first else {
            throw CurriculumError.curriculumNotFound(id)
        }

        activeCurriculum = curriculum
        currentTopic = nil

        logger.info("Loaded curriculum: \(curriculum.name ?? "Unknown")")
    }

    /// Get all topics for the active curriculum, sorted by order
    @MainActor
    public func getTopics() -> [Topic] {
        guard let curriculum = activeCurriculum else { return [] }

        let topics = curriculum.topics?.array as? [Topic] ?? []
        return topics.sorted { $0.orderIndex < $1.orderIndex }
    }

    // MARK: - Topic Management

    /// Start studying a topic
    /// - Parameter topic: Topic to start
    @MainActor
    public func startTopic(_ topic: Topic) throws {
        // Create progress if needed
        if topic.progress == nil {
            let context = persistenceController.viewContext
            let progress = TopicProgress(context: context)
            progress.id = UUID()
            progress.topic = topic
            progress.timeSpent = 0
            progress.lastAccessed = Date()
            topic.progress = progress
            try persistenceController.save()
        }

        currentTopic = topic

        // Record telemetry
        if let telemetry = telemetry {
            Task {
                await telemetry.recordEvent(.topicStarted(topic: topic.title ?? "Unknown"))
            }
        }

        logger.info("Started topic: \(topic.title ?? "Unknown")")
    }

    /// Get the next topic in order
    @MainActor
    public func getNextTopic() -> Topic? {
        guard let current = currentTopic else { return nil }

        let topics = getTopics()
        guard let currentIndex = topics.firstIndex(where: { $0.id == current.id }) else {
            return nil
        }

        let nextIndex = currentIndex + 1
        guard nextIndex < topics.count else { return nil }

        return topics[nextIndex]
    }

    /// Get the previous topic in order
    @MainActor
    public func getPreviousTopic() -> Topic? {
        guard let current = currentTopic else { return nil }

        let topics = getTopics()
        guard let currentIndex = topics.firstIndex(where: { $0.id == current.id }) else {
            return nil
        }

        let prevIndex = currentIndex - 1
        guard prevIndex >= 0 else { return nil }

        return topics[prevIndex]
    }

    // MARK: - Context Generation

    /// Generate system context for LLM based on topic and materials
    /// - Parameter topic: Topic to generate context for
    /// - Returns: Context string for LLM system prompt
    @MainActor
    public func generateContext(for topic: Topic) -> String {
        var context = """
        You are an expert tutor conducting an extended voice-based educational session.

        CURRENT TOPIC: \(topic.title ?? "Unknown Topic")
        """

        // Add outline if available
        if let outline = topic.outline, !outline.isEmpty {
            context += "\n\nTOPIC OUTLINE:\n\(outline)"
        }

        // Add learning objectives
        let objectives = topic.learningObjectives
        if !objectives.isEmpty {
            context += "\n\nLEARNING OBJECTIVES:\n"
            for objective in objectives {
                context += "- \(objective)\n"
            }
        }

        // Add reference material excerpts from documents
        let documents = topic.documentSet
        let documentsWithSummaries = documents.filter { $0.summary != nil }
        for document in documentsWithSummaries.prefix(3) {
            if let summary = document.summary {
                context += "\n\nREFERENCE: \(document.title ?? "Document")\n\(summary)"
            }
        }

        context += """


        TEACHING APPROACH:
        - Use Socratic questioning to guide learning
        - Encourage critical thinking and exploration
        - Adapt explanations to student's demonstrated understanding
        - Use concrete examples and analogies
        - Check for understanding regularly
        - This is a voice conversation, so be conversational and natural
        - Keep individual responses concise but comprehensive
        - Be prepared for interruptions and clarification questions
        """

        return context
    }

    /// Generate dynamic context for a specific user query within a topic
    /// - Parameters:
    ///   - query: User's query
    ///   - topic: Current topic
    ///   - maxTokens: Maximum tokens for context (default 2000)
    /// - Returns: Context string with relevant material
    @MainActor
    public func generateContextForQuery(
        query: String,
        topic: Topic,
        maxTokens: Int = 2000
    ) async -> String {
        // If embeddings available, do semantic search
        guard embeddingService != nil else {
            return ""
        }

        // Extract all chunks on MainActor to avoid data race
        var allChunks: [DocumentChunk] = []
        for document in topic.documentSet {
            if let chunks = document.decodedChunks() {
                allChunks.append(contentsOf: chunks)
            }
        }

        let relevantChunks = await semanticSearchChunks(
            query: query,
            chunks: allChunks,
            maxTokens: maxTokens
        )

        if relevantChunks.isEmpty {
            return ""
        }

        var context = "RELEVANT REFERENCE MATERIAL:\n\n"
        for chunk in relevantChunks {
            context += "\(chunk.text)\n\n"
        }

        return context
    }

    // MARK: - Semantic Search

    /// Search document chunks using embeddings for semantic similarity
    /// - Parameters:
    ///   - query: Search query
    ///   - chunks: Document chunks to search (Sendable)
    ///   - maxTokens: Maximum tokens to return
    /// - Returns: Relevant document chunks
    public func semanticSearchChunks(
        query: String,
        chunks: [DocumentChunk],
        maxTokens: Int
    ) async -> [DocumentChunk] {
        guard let embeddingService = embeddingService else { return [] }
        guard !chunks.isEmpty else { return [] }

        // Generate query embedding
        let queryEmbedding = await embeddingService.embed(text: query)

        // Compare with chunk embeddings
        var rankedChunks: [(chunk: DocumentChunk, similarity: Float)] = []

        for chunk in chunks {
            let similarity = cosineSimilarity(queryEmbedding, chunk.embedding)
            rankedChunks.append((chunk, similarity))
        }

        // Sort by similarity and take top chunks within token budget
        rankedChunks.sort { $0.similarity > $1.similarity }

        var selectedChunks: [DocumentChunk] = []
        var tokenCount = 0

        for (chunk, _) in rankedChunks {
            let chunkTokens = chunk.text.count / 4 // Rough estimate
            if tokenCount + chunkTokens <= maxTokens {
                selectedChunks.append(chunk)
                tokenCount += chunkTokens
            } else {
                break
            }
        }

        return selectedChunks
    }

    /// Search documents using embeddings for semantic similarity
    /// - Parameters:
    ///   - query: Search query
    ///   - documents: Documents to search
    ///   - maxTokens: Maximum tokens to return
    /// - Returns: Relevant document chunks
    @MainActor
    public func semanticSearch(
        query: String,
        documents: [Document],
        maxTokens: Int
    ) async -> [DocumentChunk] {
        // Extract all chunks from documents on MainActor
        var allChunks: [DocumentChunk] = []
        for document in documents {
            if let chunks = document.decodedChunks() {
                allChunks.append(contentsOf: chunks)
            }
        }

        return await semanticSearchChunks(
            query: query,
            chunks: allChunks,
            maxTokens: maxTokens
        )
    }

    // MARK: - Progress Tracking

    /// Update progress for a topic
    /// - Parameters:
    ///   - topic: Topic to update
    ///   - timeSpent: Additional time spent in seconds
    ///   - conceptsCovered: New concepts covered
    @MainActor
    public func updateProgress(
        topic: Topic,
        timeSpent: TimeInterval,
        conceptsCovered: [String]
    ) throws {
        guard let progress = topic.progress else {
            throw CurriculumError.progressNotFound(topic.id ?? UUID())
        }

        progress.timeSpent += timeSpent
        progress.lastAccessed = Date()

        try persistenceController.save()
    }

    /// Mark a topic as completed
    /// - Parameters:
    ///   - topic: Topic to complete
    ///   - masteryLevel: Final mastery level (0.0 - 1.0)
    @MainActor
    public func completeTopic(_ topic: Topic, masteryLevel: Float = 0.8) throws {
        // Ensure mastery meets completion threshold
        let finalMastery = max(masteryLevel, 0.8)
        topic.mastery = finalMastery

        if let progress = topic.progress {
            progress.lastAccessed = Date()
        }

        try persistenceController.save()

        // Record telemetry
        let timeSpent = topic.progress?.timeSpent ?? 0
        if let telemetry = telemetry {
            Task {
                await telemetry.recordEvent(.topicCompleted(
                    topic: topic.title ?? "Unknown",
                    timeSpent: timeSpent,
                    mastery: finalMastery
                ))
            }
        }

        logger.info("Completed topic: \(topic.title ?? "Unknown") with mastery \(finalMastery)")
    }

    /// Get overall curriculum progress
    @MainActor
    public func getCurriculumProgress() -> CurriculumProgress {
        let topics = getTopics()

        let completedTopics = topics.filter { $0.status == .completed }.count
        let totalTimeSpent = topics.compactMap { $0.progress?.timeSpent }.reduce(0, +)
        let averageMastery = topics.isEmpty ? 0 : topics.map { $0.mastery }.reduce(0, +) / Float(topics.count)

        // Find next suggested topic (first incomplete)
        let suggestedNext = topics.first { $0.status != .completed }

        return CurriculumProgress(
            totalTopics: topics.count,
            completedTopics: completedTopics,
            totalTimeSpent: totalTimeSpent,
            averageMastery: averageMastery,
            suggestedNextTopicId: suggestedNext?.id,
            suggestedNextTopicOrderIndex: suggestedNext?.orderIndex
        )
    }
}

// MARK: - Curriculum Progress

/// Overall progress for a curriculum
public struct CurriculumProgress: Sendable {
    /// Total number of topics
    public let totalTopics: Int

    /// Number of completed topics
    public let completedTopics: Int

    /// Total time spent across all topics in seconds
    public let totalTimeSpent: TimeInterval

    /// Average mastery across all topics
    public let averageMastery: Float

    /// ID of suggested next topic to study
    public let suggestedNextTopicId: UUID?

    /// Order index of suggested next topic
    public let suggestedNextTopicOrderIndex: Int32?

    /// Completion percentage
    public var completionPercentage: Float {
        guard totalTopics > 0 else { return 0 }
        return Float(completedTopics) / Float(totalTopics)
    }

    /// Formatted total time spent
    public var formattedTimeSpent: String {
        let hours = Int(totalTimeSpent) / 3600
        let minutes = (Int(totalTimeSpent) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - CurriculumEngine Factory

/// Factory for creating CurriculumEngine instances
public struct CurriculumEngineFactory {
    /// Create a curriculum engine with given dependencies
    public static func create(
        persistenceController: PersistenceController = .shared,
        embeddingService: (any EmbeddingService)? = nil,
        telemetry: TelemetryEngine? = nil
    ) -> CurriculumEngine {
        return CurriculumEngine(
            persistenceController: persistenceController,
            embeddingService: embeddingService,
            telemetry: telemetry
        )
    }
}
