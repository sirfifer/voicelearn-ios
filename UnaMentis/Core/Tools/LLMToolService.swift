// UnaMentis - LLM Tool Service
// Protocol and types for LLM tool/function calling
//
// Part of Todo System - Voice-Triggered Actions

import Foundation

// MARK: - Tool Definition

/// Definition of a tool that can be called by the LLM
public struct LLMToolDefinition: Codable, Sendable {
    /// Name of the tool
    public let name: String

    /// Description of what the tool does
    public let description: String

    /// JSON Schema for input parameters
    public let inputSchema: ToolInputSchema

    public init(name: String, description: String, inputSchema: ToolInputSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

/// JSON Schema for tool input
public struct ToolInputSchema: Codable, Sendable {
    public let type: String
    public let properties: [String: ToolProperty]
    public let required: [String]

    public init(
        type: String = "object",
        properties: [String: ToolProperty],
        required: [String]
    ) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

/// Property definition in tool schema
public struct ToolProperty: Codable, Sendable {
    public let type: String
    public let description: String
    public let enumValues: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enumValues = "enum"
    }

    public init(type: String, description: String, enumValues: [String]? = nil) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
    }
}

// MARK: - Tool Call

/// A tool call made by the LLM
public struct LLMToolCall: Sendable {
    /// Unique ID for this tool call
    public let id: String

    /// Name of the tool being called
    public let name: String

    /// Arguments as JSON string
    public let arguments: String

    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }

    /// Parse arguments as a specific type
    public func parseArguments<T: Decodable>() throws -> T {
        guard let data = arguments.data(using: .utf8) else {
            throw ToolCallError.invalidArguments("Arguments are not valid UTF-8")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Tool Result

/// Result of executing a tool
public struct LLMToolResult: Sendable {
    /// ID of the tool call this is responding to
    public let toolCallId: String

    /// Result content
    public let content: String

    /// Whether the tool execution was successful
    public let isSuccess: Bool

    public init(toolCallId: String, content: String, isSuccess: Bool = true) {
        self.toolCallId = toolCallId
        self.content = content
        self.isSuccess = isSuccess
    }

    /// Create a success result
    public static func success(toolCallId: String, content: String) -> LLMToolResult {
        LLMToolResult(toolCallId: toolCallId, content: content, isSuccess: true)
    }

    /// Create an error result
    public static func error(toolCallId: String, error: String) -> LLMToolResult {
        LLMToolResult(toolCallId: toolCallId, content: "Error: \(error)", isSuccess: false)
    }
}

// MARK: - LLM Token Extension

/// Extended token that may include tool calls
public struct LLMToolToken: Sendable {
    /// Text content (if any)
    public let textContent: String?

    /// Tool calls (if any)
    public let toolCalls: [LLMToolCall]?

    /// Whether this is the final token
    public let isDone: Bool

    /// Stop reason if done
    public let stopReason: ToolStopReason?

    public init(
        textContent: String? = nil,
        toolCalls: [LLMToolCall]? = nil,
        isDone: Bool = false,
        stopReason: ToolStopReason? = nil
    ) {
        self.textContent = textContent
        self.toolCalls = toolCalls
        self.isDone = isDone
        self.stopReason = stopReason
    }
}

/// Extended stop reasons including tool use
public enum ToolStopReason: String, Codable, Sendable {
    case endTurn = "end_turn"
    case maxTokens = "max_tokens"
    case stopSequence = "stop_sequence"
    case toolUse = "tool_use"
}

// MARK: - Tool Handler Protocol

/// Protocol for handling specific tool calls
public protocol ToolHandler: Sendable {
    /// Tool definitions this handler provides
    var toolDefinitions: [LLMToolDefinition] { get }

    /// Handle a tool call
    /// - Parameter toolCall: The tool call to handle
    /// - Returns: The result of the tool execution
    func handle(_ toolCall: LLMToolCall) async throws -> LLMToolResult
}

// MARK: - Tool Call Errors

/// Errors that can occur during tool call processing
public enum ToolCallError: Error, Sendable {
    case unknownTool(String)
    case invalidArguments(String)
    case executionFailed(String)
    case toolDisabled(String)
}

extension ToolCallError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unknownTool(let name):
            return "Unknown tool: \(name)"
        case .invalidArguments(let message):
            return "Invalid tool arguments: \(message)"
        case .executionFailed(let message):
            return "Tool execution failed: \(message)"
        case .toolDisabled(let name):
            return "Tool is disabled: \(name)"
        }
    }
}

// MARK: - Todo Tool Definitions

/// Standard tool definitions for todo functionality
public enum TodoTools {
    /// Tool for adding items to the todo list
    public static let addTodo = LLMToolDefinition(
        name: "add_todo",
        description: "Add a new item to the user's to-do list for later study. Use this when the user expresses interest in learning something that isn't currently being covered, or when they want to remember to study something later.",
        inputSchema: ToolInputSchema(
            properties: [
                "title": ToolProperty(
                    type: "string",
                    description: "Brief title of the learning item (e.g., 'Review quadratic equations', 'Practice Spanish verb conjugations')"
                ),
                "type": ToolProperty(
                    type: "string",
                    description: "Type of todo item",
                    enumValues: ["learning_target", "reinforcement"]
                ),
                "notes": ToolProperty(
                    type: "string",
                    description: "Additional context or details about what to study"
                )
            ],
            required: ["title", "type"]
        )
    )

    /// Tool for marking current topic for review
    public static let markForReview = LLMToolDefinition(
        name: "mark_for_review",
        description: "Mark the current topic for future review. Use this when the user is struggling with the material or explicitly asks to revisit it later.",
        inputSchema: ToolInputSchema(
            properties: [
                "reason": ToolProperty(
                    type: "string",
                    description: "Why this topic needs review (e.g., 'User struggled with derivation steps')"
                )
            ],
            required: []
        )
    )

    /// All todo-related tools
    public static let all: [LLMToolDefinition] = [addTodo, markForReview]
}
