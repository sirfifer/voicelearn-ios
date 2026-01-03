# LLM Tool Call Infrastructure

This document describes the LLM tool call system that enables voice-triggered actions during learning sessions.

## Overview

The tool call infrastructure allows the LLM to execute actions on behalf of the user during voice sessions. For example, users can say "add that to my to-do list" and the LLM will invoke the appropriate tool to create a todo item.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        LLM Service                               │
│  (AnthropicLLMService, OpenAILLMService, etc.)                  │
│                                                                  │
│  1. Sends tool definitions with request                         │
│  2. Receives tool_use blocks in response                        │
│  3. Calls ToolCallProcessor.process()                           │
│  4. Sends tool_result back to LLM                               │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ToolCallProcessor (Actor)                     │
│                                                                  │
│  - Routes tool calls to registered handlers                     │
│  - Manages handler registration                                  │
│  - Provides tool definitions for API requests                   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ TodoTool │ │ Future   │ │ Future   │
        │ Handler  │ │ Handler  │ │ Handler  │
        └──────────┘ └──────────┘ └──────────┘
```

## File Locations

| File | Purpose |
|------|---------|
| `UnaMentis/Core/Tools/LLMToolService.swift` | Core types and protocols |
| `UnaMentis/Core/Tools/ToolCallProcessor.swift` | Central routing actor |
| `UnaMentis/Core/Tools/TodoToolHandler.swift` | Todo-specific handler |

## Core Types

### LLMToolDefinition

Defines a tool that can be called by the LLM.

```swift
public struct LLMToolDefinition: Sendable {
    public let name: String
    public let description: String
    public let inputSchema: ToolInputSchema
}

public struct ToolInputSchema: Sendable {
    public let type: String  // Always "object"
    public let properties: [String: ToolProperty]
    public let required: [String]
}

public struct ToolProperty: Sendable {
    public let type: String       // "string", "number", "boolean", etc.
    public let description: String
    public let enumValues: [String]?  // Optional enum constraint
}
```

### LLMToolCall

Represents a tool call from the LLM response.

```swift
public struct LLMToolCall: Sendable {
    public let id: String        // Unique identifier for this call
    public let name: String      // Tool name
    public let arguments: Data   // JSON-encoded arguments

    // Parse arguments to a Codable type
    public func parseArguments<T: Codable>() throws -> T
}
```

### LLMToolResult

Result returned after executing a tool call.

```swift
public enum LLMToolResult: Sendable {
    case success(toolCallId: String, content: String)
    case error(toolCallId: String, error: String)
}
```

### ToolHandler Protocol

Protocol that all tool handlers must implement.

```swift
public protocol ToolHandler: Actor, Sendable {
    /// Tool definitions this handler provides
    nonisolated var toolDefinitions: [LLMToolDefinition] { get }

    /// Handle a tool call and return the result
    func handle(_ toolCall: LLMToolCall) async throws -> LLMToolResult
}
```

## Creating a New Tool Handler

### Step 1: Define Tool Arguments

Create Codable structs for your tool's arguments:

```swift
public struct MyToolArguments: Codable, Sendable {
    public let param1: String
    public let param2: Int?

    public init(param1: String, param2: Int? = nil) {
        self.param1 = param1
        self.param2 = param2
    }
}
```

### Step 2: Define Tools

Create tool definitions with proper schemas:

```swift
enum MyTools {
    static let myTool = LLMToolDefinition(
        name: "my_tool",
        description: "Does something useful",
        inputSchema: ToolInputSchema(
            type: "object",
            properties: [
                "param1": ToolProperty(
                    type: "string",
                    description: "Required parameter"
                ),
                "param2": ToolProperty(
                    type: "number",
                    description: "Optional parameter"
                )
            ],
            required: ["param1"]
        )
    )

    static var all: [LLMToolDefinition] {
        [myTool]
    }
}
```

### Step 3: Implement Handler

Create an actor that conforms to `ToolHandler`:

```swift
public actor MyToolHandler: ToolHandler {
    private let logger = Logger(label: "com.unamentis.tools.mytool")

    public nonisolated var toolDefinitions: [LLMToolDefinition] {
        MyTools.all
    }

    public init() {}

    public func handle(_ toolCall: LLMToolCall) async throws -> LLMToolResult {
        switch toolCall.name {
        case "my_tool":
            return try await handleMyTool(toolCall)
        default:
            throw ToolCallError.unknownTool(toolCall.name)
        }
    }

    private func handleMyTool(_ toolCall: LLMToolCall) async throws -> LLMToolResult {
        let args: MyToolArguments = try toolCall.parseArguments()

        // Perform the action
        do {
            // Your logic here...
            return .success(
                toolCallId: toolCall.id,
                content: "Action completed successfully"
            )
        } catch {
            return .error(
                toolCallId: toolCall.id,
                error: error.localizedDescription
            )
        }
    }
}
```

### Step 4: Register Handler

Register your handler with the ToolCallProcessor:

```swift
// In ToolCallProcessor.registerDefaultHandlers():
private func registerDefaultHandlers() {
    register(TodoToolHandler.shared)
    register(MyToolHandler.shared)  // Add your handler
    logger.info("Registered default tool handlers")
}
```

## Swift 6.0 Concurrency Considerations

### Actor Isolation

Tool handlers are actors, meaning all their state is isolated. When accessing actor-isolated properties from within a `MainActor.run` block, you must capture values first:

```swift
// WRONG - will cause compiler error
public func handle(_ toolCall: LLMToolCall) async throws -> LLMToolResult {
    await MainActor.run {
        // Cannot access self.someProperty here
        doSomething(with: self.someProperty)  // Error!
    }
}

// CORRECT - capture values before MainActor.run
public func handle(_ toolCall: LLMToolCall) async throws -> LLMToolResult {
    let value = self.someProperty  // Capture outside

    await MainActor.run {
        doSomething(with: value)  // Use captured value
    }
}
```

### Lazy Registration

The ToolCallProcessor uses lazy registration to avoid calling actor-isolated methods from its synchronous initializer:

```swift
public actor ToolCallProcessor {
    private var hasRegisteredDefaults = false

    public init() {
        // Cannot call registerDefaultHandlers() here
    }

    private func ensureDefaultHandlers() {
        guard !hasRegisteredDefaults else { return }
        hasRegisteredDefaults = true
        registerDefaultHandlers()
    }

    public func process(_ toolCall: LLMToolCall) async -> LLMToolResult {
        ensureDefaultHandlers()  // Lazy init
        // ...
    }
}
```

## API Format Helpers

The ToolCallProcessor provides helpers for formatting tool definitions for different LLM APIs:

```swift
// For Anthropic API
let anthropicTools = await ToolCallProcessor.shared.anthropicToolDefinitions()
// Returns: [["name": "add_todo", "description": "...", "input_schema": {...}], ...]

// For OpenAI API
let openaiTools = await ToolCallProcessor.shared.openAIToolDefinitions()
// Returns: [["type": "function", "function": {"name": "add_todo", ...}], ...]
```

## Available Tools

### add_todo

Creates a new todo item for later study.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | string | Yes | Brief title of the learning item |
| `type` | string | Yes | Either "learning_target" or "reinforcement" |
| `notes` | string | No | Additional context |

**Example LLM Response:**
```json
{
  "type": "tool_use",
  "id": "toolu_123",
  "name": "add_todo",
  "input": {
    "title": "Learn about quantum entanglement",
    "type": "learning_target",
    "notes": "User expressed interest during physics discussion"
  }
}
```

### mark_for_review

Marks the current topic for future review.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `reason` | string | No | Why this needs review |

**Example LLM Response:**
```json
{
  "type": "tool_use",
  "id": "toolu_456",
  "name": "mark_for_review",
  "input": {
    "reason": "User struggled with derivative concepts"
  }
}
```

## Integration with LLM Services

When making LLM requests that should support tool calls:

1. Get tool definitions from ToolCallProcessor
2. Include them in the API request
3. Check response for tool_use blocks
4. Process each tool call
5. Send results back to LLM

```swift
// 1. Get tool definitions
let tools = await ToolCallProcessor.shared.anthropicToolDefinitions()

// 2. Include in request
var request = AnthropicRequest(...)
request.tools = tools

// 3-4. Process tool calls from response
if let toolUseBlocks = response.content.filter({ $0.type == "tool_use" }) {
    let calls = toolUseBlocks.map { LLMToolCall(from: $0) }
    let results = await ToolCallProcessor.shared.processAll(calls)

    // 5. Send results back
    for result in results {
        // Add tool_result to conversation and continue
    }
}
```

## Testing

Tool handlers can be tested by creating mock tool calls:

```swift
func testAddTodoTool() async throws {
    let handler = TodoToolHandler()

    let toolCall = LLMToolCall(
        id: "test-123",
        name: "add_todo",
        arguments: try JSONEncoder().encode([
            "title": "Test item",
            "type": "learning_target"
        ])
    )

    let result = try await handler.handle(toolCall)

    switch result {
    case .success(let id, let content):
        XCTAssertEqual(id, "test-123")
        XCTAssertTrue(content.contains("Test item"))
    case .error(_, let error):
        XCTFail("Expected success, got error: \(error)")
    }
}
```

## Error Handling

The system defines standard error types:

```swift
public enum ToolCallError: Error, LocalizedError {
    case unknownTool(String)
    case invalidArguments(String)
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unknownTool(let name):
            return "Unknown tool: \(name)"
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        }
    }
}
```

Errors are caught by the ToolCallProcessor and converted to error results:

```swift
public func process(_ toolCall: LLMToolCall) async -> LLMToolResult {
    do {
        return try await handler.handle(toolCall)
    } catch {
        return .error(
            toolCallId: toolCall.id,
            error: error.localizedDescription
        )
    }
}
```
