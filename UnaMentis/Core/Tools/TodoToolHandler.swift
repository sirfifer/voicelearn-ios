// UnaMentis - Todo Tool Handler
// Handles LLM tool calls for todo operations
//
// Part of Todo System - Voice-Triggered Actions

import Foundation
import Logging

// MARK: - Add Todo Arguments

/// Arguments for the add_todo tool
public struct AddTodoArguments: Codable, Sendable {
    public let title: String
    public let type: String
    public let notes: String?

    public init(title: String, type: String, notes: String? = nil) {
        self.title = title
        self.type = type
        self.notes = notes
    }
}

// MARK: - Mark for Review Arguments

/// Arguments for the mark_for_review tool
public struct MarkForReviewArguments: Codable, Sendable {
    public let reason: String?

    public init(reason: String? = nil) {
        self.reason = reason
    }
}

// MARK: - Todo Tool Handler

/// Handler for todo-related tool calls from LLM
public actor TodoToolHandler: ToolHandler {
    // MARK: - Properties

    private let logger = Logger(label: "com.unamentis.tools.todo")

    /// Current session ID for tracking source
    private var currentSessionId: UUID?

    /// Current topic ID for mark_for_review
    private var currentTopicId: UUID?

    /// Current topic title for creating review items
    private var currentTopicTitle: String?

    // MARK: - ToolHandler Conformance

    public nonisolated var toolDefinitions: [LLMToolDefinition] {
        TodoTools.all
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Context Configuration

    /// Configure the handler with current session context
    /// - Parameters:
    ///   - sessionId: ID of the current session
    ///   - topicId: ID of the current topic (if any)
    ///   - topicTitle: Title of the current topic (if any)
    public func configureContext(
        sessionId: UUID?,
        topicId: UUID?,
        topicTitle: String?
    ) {
        self.currentSessionId = sessionId
        self.currentTopicId = topicId
        self.currentTopicTitle = topicTitle
        logger.debug("Context configured: session=\(sessionId?.uuidString ?? "nil"), topic=\(topicId?.uuidString ?? "nil")")
    }

    /// Clear the current context
    public func clearContext() {
        currentSessionId = nil
        currentTopicId = nil
        currentTopicTitle = nil
        logger.debug("Context cleared")
    }

    // MARK: - Tool Handling

    public func handle(_ toolCall: LLMToolCall) async throws -> LLMToolResult {
        logger.info("Handling tool call: \(toolCall.name)")

        switch toolCall.name {
        case "add_todo":
            return try await handleAddTodo(toolCall)
        case "mark_for_review":
            return try await handleMarkForReview(toolCall)
        default:
            throw ToolCallError.unknownTool(toolCall.name)
        }
    }

    // MARK: - Private Handlers

    private func handleAddTodo(_ toolCall: LLMToolCall) async throws -> LLMToolResult {
        let args: AddTodoArguments = try toolCall.parseArguments()

        logger.info("Creating todo item: '\(args.title)' of type '\(args.type)'")

        // Determine the item type
        let itemType: TodoItemType
        switch args.type.lowercased() {
        case "learning_target":
            itemType = .learningTarget
        case "reinforcement":
            itemType = .reinforcement
        default:
            itemType = .learningTarget
        }

        // Capture actor-isolated values before entering MainActor.run
        let sessionId = currentSessionId

        // Create the todo item on the main actor
        do {
            try await MainActor.run {
                guard let todoManager = TodoManager.shared else {
                    throw ToolCallError.executionFailed("TodoManager not initialized")
                }

                if itemType == .reinforcement {
                    // Use reinforcement-specific creation
                    _ = try todoManager.createReinforcementItem(
                        title: args.title,
                        notes: args.notes,
                        sessionId: sessionId
                    )
                } else {
                    // Use regular creation for learning targets
                    _ = try todoManager.createItem(
                        title: args.title,
                        type: itemType,
                        source: .voice,
                        notes: args.notes
                    )
                }
            }

            logger.info("Successfully created todo item: '\(args.title)'")
            return .success(
                toolCallId: toolCall.id,
                content: "Added '\(args.title)' to your to-do list."
            )
        } catch {
            logger.error("Failed to create todo item: \(error)")
            return .error(
                toolCallId: toolCall.id,
                error: "Failed to add item to to-do list: \(error.localizedDescription)"
            )
        }
    }

    private func handleMarkForReview(_ toolCall: LLMToolCall) async throws -> LLMToolResult {
        let args: MarkForReviewArguments = try toolCall.parseArguments()

        // Capture actor-isolated values before entering MainActor.run
        let topicTitle = currentTopicTitle
        let topicId = currentTopicId
        let sessionId = currentSessionId

        // Build the title based on context
        let title: String
        if let topicTitle = topicTitle {
            title = "Review: \(topicTitle)"
        } else {
            title = "Review: Current topic"
        }

        logger.info("Creating review item: '\(title)', reason: \(args.reason ?? "none")")

        // Create notes with reason if provided
        var notes = args.reason
        if let topicId = topicId {
            let topicRef = "Topic ID: \(topicId.uuidString)"
            notes = notes.map { "\($0)\n\n\(topicRef)" } ?? topicRef
        }

        do {
            try await MainActor.run {
                guard let todoManager = TodoManager.shared else {
                    throw ToolCallError.executionFailed("TodoManager not initialized")
                }

                _ = try todoManager.createReinforcementItem(
                    title: title,
                    notes: notes,
                    sessionId: sessionId
                )
            }

            logger.info("Successfully created review item: '\(title)'")
            return .success(
                toolCallId: toolCall.id,
                content: "Marked '\(topicTitle ?? "this topic")' for later review."
            )
        } catch {
            logger.error("Failed to create review item: \(error)")
            return .error(
                toolCallId: toolCall.id,
                error: "Failed to mark for review: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - Shared Instance

extension TodoToolHandler {
    /// Shared instance for use across the app
    public static let shared = TodoToolHandler()
}
