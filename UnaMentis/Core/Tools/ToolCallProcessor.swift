// UnaMentis - Tool Call Processor
// Processes and routes tool calls from LLM responses
//
// Part of Todo System - Voice-Triggered Actions

import Foundation
import Logging

// MARK: - Tool Call Processor

/// Processor for handling tool calls from LLM responses
public actor ToolCallProcessor {
    // MARK: - Properties

    private let logger = Logger(label: "com.unamentis.tools.processor")

    /// Registered tool handlers
    private var handlers: [String: any ToolHandler] = [:]

    /// All available tool definitions
    public var availableTools: [LLMToolDefinition] {
        get async {
            ensureDefaultHandlers()
            return handlers.values.flatMap { $0.toolDefinitions }
        }
    }

    // MARK: - Initialization

    /// Track if default handlers have been registered
    private var hasRegisteredDefaults = false

    public init() {
        // Handlers will be registered lazily on first use
    }

    /// Ensure default handlers are registered
    private func ensureDefaultHandlers() {
        guard !hasRegisteredDefaults else { return }
        hasRegisteredDefaults = true
        registerDefaultHandlers()
    }

    // MARK: - Handler Registration

    /// Register a tool handler
    /// - Parameter handler: The handler to register
    public func register(_ handler: any ToolHandler) {
        for tool in handler.toolDefinitions {
            handlers[tool.name] = handler
            logger.debug("Registered handler for tool: \(tool.name)")
        }
    }

    /// Unregister handlers for specific tools
    /// - Parameter toolNames: Names of tools to unregister
    public func unregister(toolNames: [String]) {
        for name in toolNames {
            handlers.removeValue(forKey: name)
            logger.debug("Unregistered handler for tool: \(name)")
        }
    }

    private func registerDefaultHandlers() {
        // Register the todo tool handler
        register(TodoToolHandler.shared)
        logger.info("Registered default tool handlers")
    }

    // MARK: - Tool Call Processing

    /// Process a single tool call
    /// - Parameter toolCall: The tool call to process
    /// - Returns: The result of the tool execution
    public func process(_ toolCall: LLMToolCall) async -> LLMToolResult {
        ensureDefaultHandlers()
        logger.info("Processing tool call: \(toolCall.name)")

        guard let handler = handlers[toolCall.name] else {
            logger.warning("No handler found for tool: \(toolCall.name)")
            return .error(
                toolCallId: toolCall.id,
                error: "Unknown tool: \(toolCall.name)"
            )
        }

        do {
            let result = try await handler.handle(toolCall)
            logger.info("Tool call \(toolCall.name) completed successfully")
            return result
        } catch {
            logger.error("Tool call \(toolCall.name) failed: \(error)")
            return .error(
                toolCallId: toolCall.id,
                error: error.localizedDescription
            )
        }
    }

    /// Process multiple tool calls in parallel
    /// - Parameter toolCalls: The tool calls to process
    /// - Returns: Results for each tool call
    public func processAll(_ toolCalls: [LLMToolCall]) async -> [LLMToolResult] {
        await withTaskGroup(of: LLMToolResult.self) { group in
            for toolCall in toolCalls {
                group.addTask {
                    await self.process(toolCall)
                }
            }

            var results: [LLMToolResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    // MARK: - Context Management

    /// Configure context for all handlers
    /// - Parameters:
    ///   - sessionId: Current session ID
    ///   - topicId: Current topic ID (if any)
    ///   - topicTitle: Current topic title (if any)
    public func configureContext(
        sessionId: UUID?,
        topicId: UUID?,
        topicTitle: String?
    ) async {
        // Configure the todo handler specifically
        await TodoToolHandler.shared.configureContext(
            sessionId: sessionId,
            topicId: topicId,
            topicTitle: topicTitle
        )
        logger.debug("Configured context for tool handlers")
    }

    /// Clear context for all handlers
    public func clearContext() async {
        await TodoToolHandler.shared.clearContext()
        logger.debug("Cleared context for tool handlers")
    }
}

// MARK: - Shared Instance

extension ToolCallProcessor {
    /// Shared processor instance
    public static let shared = ToolCallProcessor()
}

// MARK: - Tool Definition Helpers

extension ToolCallProcessor {
    /// Get tool definitions formatted for Anthropic API
    public func anthropicToolDefinitions() async -> [[String: Any]] {
        let tools = await availableTools
        return tools.map { tool in
            [
                "name": tool.name,
                "description": tool.description,
                "input_schema": [
                    "type": tool.inputSchema.type,
                    "properties": tool.inputSchema.properties.reduce(into: [String: [String: Any]]()) { result, property in
                        var prop: [String: Any] = [
                            "type": property.value.type,
                            "description": property.value.description
                        ]
                        if let enumValues = property.value.enumValues {
                            prop["enum"] = enumValues
                        }
                        result[property.key] = prop
                    },
                    "required": tool.inputSchema.required
                ] as [String: Any]
            ]
        }
    }

    /// Get tool definitions formatted for OpenAI API
    public func openAIToolDefinitions() async -> [[String: Any]] {
        let tools = await availableTools
        return tools.map { tool in
            [
                "type": "function",
                "function": [
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": [
                        "type": tool.inputSchema.type,
                        "properties": tool.inputSchema.properties.reduce(into: [String: [String: Any]]()) { result, property in
                            var prop: [String: Any] = [
                                "type": property.value.type,
                                "description": property.value.description
                            ]
                            if let enumValues = property.value.enumValues {
                                prop["enum"] = enumValues
                            }
                            result[property.key] = prop
                        },
                        "required": tool.inputSchema.required
                    ] as [String: Any]
                ] as [String: Any]
            ]
        }
    }
}
