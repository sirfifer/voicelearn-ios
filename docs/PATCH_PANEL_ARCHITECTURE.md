# LLM Patch Panel Architecture

**Purpose:** A switchboard system for routing any LLM call to any endpoint, with manual and automatic modes, enabling real-world tuning and graceful degradation.

---

## Core Principle

```
┌─────────────────────────────────────────────────────────────────────┐
│  EVERY LLM CALL IS A DISCRETE, PREDICTABLE HANDOFF                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Business Logic                    Patch Panel                      │
│        │                                │                            │
│        │  TaskRequest                   │                            │
│        │  ┌─────────────────┐          │                            │
│        └─►│ • taskType      │──────────►│  Routing Decision          │
│           │ • prompt        │          │  ┌─────────────────────┐   │
│           │ • context       │          │  │ Which endpoint?     │   │
│           │ • constraints   │          │  │ • Manual override?  │   │
│           └─────────────────┘          │  │ • Auto-route rules? │   │
│                                        │  │ • Default mapping?  │   │
│                                        │  └──────────┬──────────┘   │
│                                        │             │              │
│                                        │             ▼              │
│                                        │  ┌─────────────────────┐   │
│                                        │  │ Endpoint Registry   │   │
│                                        │  │ ┌─────┐ ┌─────┐    │   │
│                                        │  │ │GPT4o│ │Llama│... │   │
│                                        │  │ └─────┘ └─────┘    │   │
│                                        │  └──────────┬──────────┘   │
│                                        │             │              │
│   Business Logic                       │             ▼              │
│        ▲                               │      Execute & Return      │
│        │  TaskResponse                 │                            │
│        │  ┌─────────────────┐          │                            │
│        └──│ • content       │◄─────────┘                            │
│           │ • metadata      │                                        │
│           │ • routingInfo   │  ◄── Which endpoint actually handled  │
│           └─────────────────┘                                        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 1. Endpoint Registry

Every LLM endpoint is registered with its capabilities and configuration:

```swift
// MARK: - Endpoint Definition

struct LLMEndpoint: Identifiable, Codable {
    let id: String                      // "gpt-4o", "llama-3b-local", etc.
    let displayName: String             // "GPT-4o (OpenAI)"
    let provider: EndpointProvider
    let location: EndpointLocation

    // Capabilities
    let maxContextTokens: Int           // 128K, 8K, etc.
    let maxOutputTokens: Int
    let supportsStreaming: Bool
    let supportsSystemPrompt: Bool
    let supportsFunctionCalling: Bool

    // Performance characteristics
    let expectedTTFTMs: Int             // Time to first token
    let expectedTokensPerSec: Int       // Generation speed
    let reliabilityScore: Float         // 0-1, based on historical uptime

    // Cost (per 1M tokens)
    let costPerInputToken: Decimal      // $0 for local
    let costPerOutputToken: Decimal

    // Connection details
    let connectionConfig: EndpointConnectionConfig

    // Current status
    var status: EndpointStatus          // .available, .degraded, .unavailable
    var lastHealthCheck: Date
}

enum EndpointProvider: String, Codable, CaseIterable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case selfHosted = "Self-Hosted"
    case onDevice = "On-Device"
}

enum EndpointLocation: String, Codable {
    case cloud              // Remote API
    case localServer        // Your Mac server
    case onDevice           // iPhone Neural Engine / MLX
}

struct EndpointConnectionConfig: Codable {
    // For cloud APIs
    var apiKeyReference: String?        // Key name in secure storage
    var baseURL: URL?
    var apiVersion: String?

    // For local server
    var serverHost: String?             // "192.168.1.100"
    var serverPort: Int?                // 11434 for Ollama

    // For on-device
    var modelPath: String?              // Path to .mlmodelc
    var computeUnits: ComputeUnits?     // .cpuAndNeuralEngine, etc.
}

enum EndpointStatus: String, Codable {
    case available          // Ready to use
    case degraded           // Working but slow/unreliable
    case unavailable        // Cannot connect
    case disabled           // Manually disabled
    case loading            // Model loading (on-device)
}
```

### Default Endpoint Registry

```swift
extension LLMEndpoint {
    static let defaultRegistry: [LLMEndpoint] = [
        // Cloud - OpenAI
        LLMEndpoint(
            id: "gpt-4o",
            displayName: "GPT-4o (OpenAI)",
            provider: .openAI,
            location: .cloud,
            maxContextTokens: 128_000,
            maxOutputTokens: 4_096,
            supportsStreaming: true,
            supportsSystemPrompt: true,
            supportsFunctionCalling: true,
            expectedTTFTMs: 300,
            expectedTokensPerSec: 80,
            reliabilityScore: 0.99,
            costPerInputToken: 0.0000025,   // $2.50/1M
            costPerOutputToken: 0.00001,    // $10/1M
            connectionConfig: .init(apiKeyReference: "openai_api_key"),
            status: .available,
            lastHealthCheck: Date()
        ),

        LLMEndpoint(
            id: "gpt-4o-mini",
            displayName: "GPT-4o Mini (OpenAI)",
            provider: .openAI,
            location: .cloud,
            maxContextTokens: 128_000,
            maxOutputTokens: 4_096,
            supportsStreaming: true,
            supportsSystemPrompt: true,
            supportsFunctionCalling: true,
            expectedTTFTMs: 200,
            expectedTokensPerSec: 100,
            reliabilityScore: 0.99,
            costPerInputToken: 0.00000015,  // $0.15/1M
            costPerOutputToken: 0.0000006,  // $0.60/1M
            connectionConfig: .init(apiKeyReference: "openai_api_key"),
            status: .available,
            lastHealthCheck: Date()
        ),

        // Cloud - Anthropic
        LLMEndpoint(
            id: "claude-3.5-sonnet",
            displayName: "Claude 3.5 Sonnet",
            provider: .anthropic,
            location: .cloud,
            maxContextTokens: 200_000,
            maxOutputTokens: 8_192,
            supportsStreaming: true,
            supportsSystemPrompt: true,
            supportsFunctionCalling: true,
            expectedTTFTMs: 500,
            expectedTokensPerSec: 60,
            reliabilityScore: 0.98,
            costPerInputToken: 0.000003,    // $3/1M
            costPerOutputToken: 0.000015,   // $15/1M
            connectionConfig: .init(apiKeyReference: "anthropic_api_key"),
            status: .available,
            lastHealthCheck: Date()
        ),

        LLMEndpoint(
            id: "claude-3.5-haiku",
            displayName: "Claude 3.5 Haiku",
            provider: .anthropic,
            location: .cloud,
            maxContextTokens: 200_000,
            maxOutputTokens: 8_192,
            supportsStreaming: true,
            supportsSystemPrompt: true,
            supportsFunctionCalling: true,
            expectedTTFTMs: 300,
            expectedTokensPerSec: 100,
            reliabilityScore: 0.98,
            costPerInputToken: 0.0000008,   // $0.80/1M
            costPerOutputToken: 0.000004,   // $4/1M
            connectionConfig: .init(apiKeyReference: "anthropic_api_key"),
            status: .available,
            lastHealthCheck: Date()
        ),

        // Self-Hosted (Mac Server)
        LLMEndpoint(
            id: "llama-70b-server",
            displayName: "Llama 3.1 70B (Server)",
            provider: .selfHosted,
            location: .localServer,
            maxContextTokens: 8_192,
            maxOutputTokens: 2_048,
            supportsStreaming: true,
            supportsSystemPrompt: true,
            supportsFunctionCalling: false,
            expectedTTFTMs: 800,
            expectedTokensPerSec: 20,
            reliabilityScore: 0.90,         // Depends on your server
            costPerInputToken: 0,
            costPerOutputToken: 0,
            connectionConfig: .init(serverHost: "192.168.1.100", serverPort: 11434),
            status: .unavailable,           // Until configured
            lastHealthCheck: Date()
        ),

        LLMEndpoint(
            id: "llama-8b-server",
            displayName: "Llama 3.1 8B (Server)",
            provider: .selfHosted,
            location: .localServer,
            maxContextTokens: 8_192,
            maxOutputTokens: 2_048,
            supportsStreaming: true,
            supportsSystemPrompt: true,
            supportsFunctionCalling: false,
            expectedTTFTMs: 300,
            expectedTokensPerSec: 100,
            reliabilityScore: 0.90,
            costPerInputToken: 0,
            costPerOutputToken: 0,
            connectionConfig: .init(serverHost: "192.168.1.100", serverPort: 11434),
            status: .unavailable,
            lastHealthCheck: Date()
        ),

        // On-Device
        LLMEndpoint(
            id: "llama-3b-device",
            displayName: "Llama 3.2 3B (On-Device)",
            provider: .onDevice,
            location: .onDevice,
            maxContextTokens: 4_096,
            maxOutputTokens: 512,
            supportsStreaming: true,
            supportsSystemPrompt: true,
            supportsFunctionCalling: false,
            expectedTTFTMs: 200,
            expectedTokensPerSec: 15,
            reliabilityScore: 0.95,         // Device-dependent
            costPerInputToken: 0,
            costPerOutputToken: 0,
            connectionConfig: .init(modelPath: "llama-3.2-3b.mlmodelc", computeUnits: .cpuAndNeuralEngine),
            status: .unavailable,           // Until model loaded
            lastHealthCheck: Date()
        ),

        LLMEndpoint(
            id: "llama-1b-device",
            displayName: "Llama 3.2 1B (On-Device)",
            provider: .onDevice,
            location: .onDevice,
            maxContextTokens: 4_096,
            maxOutputTokens: 512,
            supportsStreaming: true,
            supportsSystemPrompt: true,
            supportsFunctionCalling: false,
            expectedTTFTMs: 100,
            expectedTokensPerSec: 30,
            reliabilityScore: 0.95,
            costPerInputToken: 0,
            costPerOutputToken: 0,
            connectionConfig: .init(modelPath: "llama-3.2-1b.mlmodelc", computeUnits: .cpuAndNeuralEngine),
            status: .unavailable,
            lastHealthCheck: Date()
        )
    ]
}
```

---

## 2. Task Types

Every LLM call has a task type that describes what it's trying to do:

```swift
// MARK: - Task Type Definition

enum LLMTaskType: String, Codable, CaseIterable {
    // Tutoring - Core
    case tutoringResponse           // Main tutoring dialogue
    case understandingCheck         // "Do you understand?"
    case socraticQuestion           // Probing questions
    case misconceptionCorrection    // Fixing wrong understanding

    // Tutoring - Content
    case explanationGeneration      // "Explain X"
    case exampleGeneration          // "Give me an example"
    case analogyGeneration          // "What's this like?"
    case rephrasing                 // "Say that differently"
    case simplification             // "Explain simpler"

    // Tutoring - Navigation
    case tangentExploration         // Off-topic but related
    case topicTransition            // Moving to next topic
    case sessionSummary             // "What did we cover?"

    // Content Processing
    case documentSummarization      // Summarize curriculum docs
    case transcriptGeneration       // Generate lesson transcript
    case glossaryExtraction         // Extract terms from content

    // Classification (typically small models)
    case intentClassification       // What does user want?
    case sentimentAnalysis          // Is user confused/frustrated?
    case topicClassification        // What topic is this about?

    // Simple Responses
    case acknowledgment             // "Okay, continuing..."
    case fillerResponse             // "I see, tell me more"
    case navigationConfirmation     // "Going back to..."

    // System
    case healthCheck                // Test endpoint availability
    case embeddingGeneration        // Vector embeddings
}

// Capability requirements for each task type
extension LLMTaskType {
    var minimumCapabilityTier: CapabilityTier {
        switch self {
        // Needs frontier model
        case .tutoringResponse, .understandingCheck, .socraticQuestion,
             .misconceptionCorrection, .tangentExploration:
            return .frontier

        // Medium model sufficient
        case .explanationGeneration, .exampleGeneration, .analogyGeneration,
             .rephrasing, .simplification, .documentSummarization,
             .transcriptGeneration, .sessionSummary:
            return .medium

        // Small model sufficient
        case .intentClassification, .sentimentAnalysis, .topicClassification,
             .glossaryExtraction, .topicTransition:
            return .small

        // Tiny model or templates
        case .acknowledgment, .fillerResponse, .navigationConfirmation:
            return .tiny

        // Special
        case .healthCheck:
            return .any
        case .embeddingGeneration:
            return .embedding
        }
    }

    var acceptsTranscriptAnswer: Bool {
        // These can be answered from transcript if available
        switch self {
        case .exampleGeneration, .rephrasing, .simplification,
             .glossaryExtraction, .topicTransition:
            return true
        default:
            return false
        }
    }
}

enum CapabilityTier: Int, Comparable {
    case any = 0
    case tiny = 1           // 1B params, on-device
    case small = 2          // 1-3B params
    case medium = 3         // 7-13B params
    case frontier = 4       // GPT-4o, Claude 3.5
    case embedding = 5      // Specialized embedding models

    static func < (lhs: CapabilityTier, rhs: CapabilityTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
```

---

## 3. Routing Table

The routing table maps task types to endpoints, with support for manual overrides and automatic rules:

```swift
// MARK: - Routing Table

struct RoutingTable: Codable {
    // Default mappings (task type → preferred endpoint chain)
    var defaultRoutes: [LLMTaskType: [String]]  // Ordered list of endpoint IDs

    // Manual overrides (highest priority)
    var manualOverrides: [LLMTaskType: String]  // Force specific endpoint

    // Global override (for debugging - route EVERYTHING to one endpoint)
    var globalOverride: String?

    // Auto-routing rules
    var autoRoutingRules: [AutoRoutingRule]

    // Fallback chain (if preferred endpoint unavailable)
    var fallbackChain: [String]                 // Ordered list of fallback endpoints
}

struct AutoRoutingRule: Codable, Identifiable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    var priority: Int                           // Higher = checked first

    // Conditions
    var conditions: [RoutingCondition]
    var conditionLogic: ConditionLogic          // .all or .any

    // Action
    var targetEndpointId: String
    var applyToTaskTypes: Set<LLMTaskType>?     // nil = all task types
}

enum ConditionLogic: String, Codable {
    case all    // All conditions must match
    case any    // Any condition matches
}

enum RoutingCondition: Codable {
    // Device conditions
    case thermalState(ThermalStateCondition)
    case memoryPressure(MemoryPressureCondition)
    case batteryLevel(ComparisonCondition)
    case deviceTier(DeviceCapabilityTier)

    // Network conditions
    case networkType(NetworkTypeCondition)      // wifi, cellular, none
    case networkLatency(ComparisonCondition)    // ms threshold

    // Endpoint conditions
    case endpointStatus(String, EndpointStatus) // endpoint ID, required status
    case endpointLatency(String, ComparisonCondition)

    // Cost conditions
    case sessionCostBudget(ComparisonCondition) // Remaining budget
    case taskCostEstimate(ComparisonCondition)

    // Time conditions
    case timeOfDay(TimeRange)                   // e.g., peak hours
    case sessionDuration(ComparisonCondition)   // How long session has been running

    // Task conditions
    case promptLength(ComparisonCondition)      // Token count
    case contextLength(ComparisonCondition)
}

enum ThermalStateCondition: String, Codable {
    case nominal, fair, serious, critical
    case atLeast_fair       // fair or worse
    case atLeast_serious    // serious or worse
}

enum MemoryPressureCondition: String, Codable {
    case normal, warning, critical
    case atLeast_warning
}

struct ComparisonCondition: Codable {
    var comparison: Comparison
    var value: Double

    enum Comparison: String, Codable {
        case lessThan, lessThanOrEqual
        case greaterThan, greaterThanOrEqual
        case equals
    }
}

enum NetworkTypeCondition: String, Codable {
    case wifi, cellular, none, any
}

struct TimeRange: Codable {
    var startHour: Int  // 0-23
    var endHour: Int
}
```

### Default Routing Configuration

```swift
extension RoutingTable {
    static let `default` = RoutingTable(
        defaultRoutes: [
            // Frontier tasks - prefer cloud, fallback to server
            .tutoringResponse: ["gpt-4o", "claude-3.5-sonnet", "llama-70b-server"],
            .understandingCheck: ["gpt-4o", "claude-3.5-sonnet", "llama-70b-server"],
            .socraticQuestion: ["gpt-4o", "claude-3.5-sonnet", "llama-70b-server"],
            .misconceptionCorrection: ["claude-3.5-sonnet", "gpt-4o", "llama-70b-server"],
            .tangentExploration: ["gpt-4o", "claude-3.5-sonnet"],

            // Medium tasks - prefer server, fallback to cloud
            .explanationGeneration: ["llama-70b-server", "llama-8b-server", "gpt-4o-mini"],
            .exampleGeneration: ["llama-70b-server", "gpt-4o-mini", "llama-8b-server"],
            .analogyGeneration: ["gpt-4o-mini", "llama-70b-server"],
            .rephrasing: ["llama-8b-server", "gpt-4o-mini", "llama-70b-server"],
            .simplification: ["llama-8b-server", "gpt-4o-mini"],
            .documentSummarization: ["llama-70b-server", "gpt-4o-mini"],
            .sessionSummary: ["llama-8b-server", "gpt-4o-mini"],

            // Small tasks - prefer on-device
            .intentClassification: ["llama-1b-device", "llama-3b-device", "gpt-4o-mini"],
            .sentimentAnalysis: ["llama-1b-device", "gpt-4o-mini"],
            .topicClassification: ["llama-1b-device", "llama-3b-device"],
            .glossaryExtraction: ["llama-3b-device", "llama-8b-server"],
            .topicTransition: ["llama-1b-device", "llama-3b-device"],

            // Tiny tasks - on-device only
            .acknowledgment: ["llama-1b-device"],
            .fillerResponse: ["llama-1b-device"],
            .navigationConfirmation: ["llama-1b-device"],

            // Special
            .healthCheck: ["gpt-4o-mini"],  // Cheap ping
            .embeddingGeneration: ["gpt-4o-mini"]  // Uses embedding endpoint
        ],
        manualOverrides: [:],
        globalOverride: nil,
        autoRoutingRules: [
            // Rule: When device is hot, avoid on-device LLM
            AutoRoutingRule(
                id: UUID(),
                name: "Thermal Throttle",
                isEnabled: true,
                priority: 100,
                conditions: [.thermalState(.atLeast_serious)],
                conditionLogic: .all,
                targetEndpointId: "gpt-4o-mini",
                applyToTaskTypes: [.acknowledgment, .fillerResponse, .intentClassification]
            ),

            // Rule: When offline, use on-device for everything possible
            AutoRoutingRule(
                id: UUID(),
                name: "Offline Mode",
                isEnabled: true,
                priority: 200,
                conditions: [.networkType(.none)],
                conditionLogic: .all,
                targetEndpointId: "llama-3b-device",
                applyToTaskTypes: nil  // All tasks
            ),

            // Rule: When on cellular, prefer cost-effective options
            AutoRoutingRule(
                id: UUID(),
                name: "Cellular Cost Saving",
                isEnabled: true,
                priority: 50,
                conditions: [.networkType(.cellular)],
                conditionLogic: .all,
                targetEndpointId: "gpt-4o-mini",
                applyToTaskTypes: [.explanationGeneration, .exampleGeneration]
            ),

            // Rule: When budget is low, use cheaper models
            AutoRoutingRule(
                id: UUID(),
                name: "Budget Conservation",
                isEnabled: true,
                priority: 75,
                conditions: [.sessionCostBudget(.init(comparison: .lessThan, value: 0.10))],
                conditionLogic: .all,
                targetEndpointId: "gpt-4o-mini",
                applyToTaskTypes: [.tutoringResponse, .understandingCheck]
            )
        ],
        fallbackChain: ["gpt-4o-mini", "llama-3b-device", "llama-1b-device"]
    )
}
```

---

## 4. Patch Panel Service

The main actor that handles all routing:

```swift
// MARK: - Patch Panel Service

@Observable
actor PatchPanelService {
    // Configuration
    private(set) var endpointRegistry: [String: LLMEndpoint]
    private(set) var routingTable: RoutingTable

    // Runtime state
    private(set) var endpointHealth: [String: EndpointHealth]
    private(set) var routingHistory: [RoutingRecord]

    // Dependencies
    private let deviceCapability: DeviceCapabilityManager
    private let networkMonitor: NetworkMonitor
    private let telemetry: TelemetryEngine

    // Developer mode
    var isDeveloperModeEnabled: Bool = false

    // MARK: - Main Routing Function

    func route(_ request: LLMTaskRequest) async throws -> LLMTaskResponse {
        let routingDecision = resolveRouting(for: request)

        // Record the decision (for debugging/learning)
        let record = RoutingRecord(
            timestamp: Date(),
            taskType: request.taskType,
            decision: routingDecision,
            context: captureRoutingContext()
        )
        routingHistory.append(record)

        // Trim history to last 1000 records
        if routingHistory.count > 1000 {
            routingHistory.removeFirst(routingHistory.count - 1000)
        }

        // Execute through the selected endpoint
        return try await executeWithFallback(
            request: request,
            endpointChain: routingDecision.endpointChain
        )
    }

    // MARK: - Routing Resolution

    private func resolveRouting(for request: LLMTaskRequest) -> RoutingDecision {
        // Priority 1: Global override (for debugging)
        if let globalOverride = routingTable.globalOverride,
           let endpoint = endpointRegistry[globalOverride],
           endpoint.status == .available {
            return RoutingDecision(
                endpointChain: [globalOverride],
                reason: .globalOverride
            )
        }

        // Priority 2: Manual override for this task type
        if let manualOverride = routingTable.manualOverrides[request.taskType],
           let endpoint = endpointRegistry[manualOverride],
           endpoint.status == .available {
            return RoutingDecision(
                endpointChain: [manualOverride],
                reason: .manualOverride
            )
        }

        // Priority 3: Auto-routing rules (sorted by priority)
        let context = captureRoutingContext()
        let applicableRules = routingTable.autoRoutingRules
            .filter { $0.isEnabled }
            .filter { $0.applyToTaskTypes == nil || $0.applyToTaskTypes!.contains(request.taskType) }
            .sorted { $0.priority > $1.priority }

        for rule in applicableRules {
            if evaluateRule(rule, context: context) {
                if let endpoint = endpointRegistry[rule.targetEndpointId],
                   endpoint.status == .available {
                    return RoutingDecision(
                        endpointChain: [rule.targetEndpointId] + routingTable.fallbackChain,
                        reason: .autoRule(rule.name)
                    )
                }
            }
        }

        // Priority 4: Default route for task type
        if let defaultChain = routingTable.defaultRoutes[request.taskType] {
            let availableChain = defaultChain.filter { id in
                endpointRegistry[id]?.status == .available
            }
            if !availableChain.isEmpty {
                return RoutingDecision(
                    endpointChain: availableChain + routingTable.fallbackChain,
                    reason: .defaultRoute
                )
            }
        }

        // Priority 5: Fallback chain
        return RoutingDecision(
            endpointChain: routingTable.fallbackChain,
            reason: .fallback
        )
    }

    private func evaluateRule(_ rule: AutoRoutingRule, context: RoutingContext) -> Bool {
        let results = rule.conditions.map { evaluateCondition($0, context: context) }

        switch rule.conditionLogic {
        case .all:
            return results.allSatisfy { $0 }
        case .any:
            return results.contains { $0 }
        }
    }

    private func evaluateCondition(_ condition: RoutingCondition, context: RoutingContext) -> Bool {
        switch condition {
        case .thermalState(let required):
            return matchesThermalState(context.thermalState, requirement: required)
        case .memoryPressure(let required):
            return matchesMemoryPressure(context.memoryPressure, requirement: required)
        case .batteryLevel(let comparison):
            return evaluate(comparison, against: Double(context.batteryLevel))
        case .networkType(let required):
            return context.networkType == required || required == .any
        case .networkLatency(let comparison):
            return evaluate(comparison, against: context.networkLatencyMs)
        case .sessionCostBudget(let comparison):
            return evaluate(comparison, against: context.remainingBudget)
        // ... other conditions
        default:
            return false
        }
    }

    // MARK: - Execution with Fallback

    private func executeWithFallback(
        request: LLMTaskRequest,
        endpointChain: [String]
    ) async throws -> LLMTaskResponse {
        var lastError: Error?

        for endpointId in endpointChain {
            guard let endpoint = endpointRegistry[endpointId],
                  endpoint.status == .available else {
                continue
            }

            do {
                let startTime = Date()
                let response = try await executeOnEndpoint(request, endpoint: endpoint)
                let latency = Date().timeIntervalSince(startTime)

                // Record success
                await telemetry.recordLatency(.llmExecution(endpointId), latency)

                return LLMTaskResponse(
                    content: response,
                    endpointUsed: endpointId,
                    latencyMs: Int(latency * 1000),
                    tokensUsed: estimateTokens(response),
                    cost: calculateCost(request, response, endpoint)
                )
            } catch {
                lastError = error

                // Record failure and mark endpoint as potentially degraded
                await telemetry.recordEvent(.endpointFailure(endpointId, error.localizedDescription))
                await updateEndpointHealth(endpointId, error: error)

                // Continue to next in chain
                continue
            }
        }

        throw RoutingError.allEndpointsFailed(lastError)
    }

    // MARK: - Manual Controls (Developer Mode)

    func setGlobalOverride(_ endpointId: String?) async {
        guard isDeveloperModeEnabled else { return }
        routingTable.globalOverride = endpointId
    }

    func setManualOverride(for taskType: LLMTaskType, endpointId: String?) async {
        guard isDeveloperModeEnabled else { return }
        if let id = endpointId {
            routingTable.manualOverrides[taskType] = id
        } else {
            routingTable.manualOverrides.removeValue(forKey: taskType)
        }
    }

    func setRuleEnabled(_ ruleId: UUID, enabled: Bool) async {
        guard isDeveloperModeEnabled else { return }
        if let index = routingTable.autoRoutingRules.firstIndex(where: { $0.id == ruleId }) {
            routingTable.autoRoutingRules[index].isEnabled = enabled
        }
    }

    // MARK: - Observability

    func getRoutingStats() -> RoutingStats {
        let recentRecords = routingHistory.suffix(100)

        return RoutingStats(
            totalRequests: routingHistory.count,
            byEndpoint: Dictionary(grouping: recentRecords, by: { $0.decision.endpointChain.first ?? "unknown" })
                .mapValues { $0.count },
            byTaskType: Dictionary(grouping: recentRecords, by: { $0.taskType })
                .mapValues { $0.count },
            byReason: Dictionary(grouping: recentRecords, by: { $0.decision.reason.description })
                .mapValues { $0.count },
            avgLatencyByEndpoint: calculateAvgLatencies(),
            failuresByEndpoint: calculateFailures()
        )
    }
}
```

---

## 5. Developer UI

A debug panel accessible via developer mode:

```swift
// MARK: - Developer Patch Panel View

struct PatchPanelDebugView: View {
    @Environment(PatchPanelService.self) var patchPanel
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // Tab 1: Endpoint Status
                EndpointStatusView()
                    .tabItem { Label("Endpoints", systemImage: "server.rack") }
                    .tag(0)

                // Tab 2: Routing Table
                RoutingTableView()
                    .tabItem { Label("Routing", systemImage: "arrow.triangle.branch") }
                    .tag(1)

                // Tab 3: Live Traffic
                LiveTrafficView()
                    .tabItem { Label("Live", systemImage: "waveform") }
                    .tag(2)

                // Tab 4: Stats
                RoutingStatsView()
                    .tabItem { Label("Stats", systemImage: "chart.bar") }
                    .tag(3)
            }
            .navigationTitle("Patch Panel")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    GlobalOverrideMenu()
                }
            }
        }
    }
}

struct EndpointStatusView: View {
    @Environment(PatchPanelService.self) var patchPanel

    var body: some View {
        List {
            Section("Cloud") {
                ForEach(cloudEndpoints) { endpoint in
                    EndpointRow(endpoint: endpoint)
                }
            }

            Section("Self-Hosted") {
                ForEach(serverEndpoints) { endpoint in
                    EndpointRow(endpoint: endpoint)
                }
            }

            Section("On-Device") {
                ForEach(deviceEndpoints) { endpoint in
                    EndpointRow(endpoint: endpoint)
                }
            }
        }
    }
}

struct EndpointRow: View {
    let endpoint: LLMEndpoint

    var body: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading) {
                Text(endpoint.displayName)
                    .font(.headline)
                Text("\(endpoint.expectedTTFTMs)ms TTFT • \(endpoint.expectedTokensPerSec) tok/s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Cost indicator
            if endpoint.costPerOutputToken > 0 {
                Text(formatCost(endpoint.costPerOutputToken))
                    .font(.caption)
                    .padding(4)
                    .background(.yellow.opacity(0.2))
                    .clipShape(Capsule())
            } else {
                Text("FREE")
                    .font(.caption)
                    .padding(4)
                    .background(.green.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
    }

    var statusColor: Color {
        switch endpoint.status {
        case .available: return .green
        case .degraded: return .yellow
        case .unavailable: return .red
        case .disabled: return .gray
        case .loading: return .blue
        }
    }
}

struct RoutingTableView: View {
    @Environment(PatchPanelService.self) var patchPanel

    var body: some View {
        List {
            // Manual overrides section
            Section {
                ForEach(LLMTaskType.allCases, id: \.self) { taskType in
                    TaskTypeRoutingRow(taskType: taskType)
                }
            } header: {
                Text("Task Routing")
            } footer: {
                Text("Tap to override routing for specific task types")
            }

            // Auto rules section
            Section("Auto-Routing Rules") {
                ForEach(patchPanel.routingTable.autoRoutingRules) { rule in
                    AutoRuleRow(rule: rule)
                }
            }
        }
    }
}

struct TaskTypeRoutingRow: View {
    let taskType: LLMTaskType
    @Environment(PatchPanelService.self) var patchPanel
    @State private var showingPicker = false

    var currentEndpoint: String {
        patchPanel.routingTable.manualOverrides[taskType]
            ?? patchPanel.routingTable.defaultRoutes[taskType]?.first
            ?? "auto"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(taskType.rawValue)
                    .font(.headline)
                Text(taskType.minimumCapabilityTier.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(currentEndpoint) {
                showingPicker = true
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $showingPicker) {
            EndpointPickerView(
                taskType: taskType,
                currentEndpoint: currentEndpoint
            )
        }
    }
}

struct LiveTrafficView: View {
    @Environment(PatchPanelService.self) var patchPanel

    var body: some View {
        List {
            ForEach(patchPanel.routingHistory.suffix(50).reversed()) { record in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(record.taskType.rawValue)
                            .font(.headline)
                        Spacer()
                        Text(record.timestamp, style: .time)
                            .font(.caption)
                    }

                    HStack {
                        Image(systemName: "arrow.right")
                        Text(record.decision.endpointChain.first ?? "?")
                            .foregroundStyle(.blue)

                        Spacer()

                        Text(record.decision.reason.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .refreshable {
            // Refresh view
        }
    }
}
```

---

## 6. Accessing Developer Mode

```swift
// Access via secret gesture or settings
struct DeveloperModeGate {
    @AppStorage("developerModeEnabled") private var isEnabled = false

    // Enable via 5-tap on version number in settings
    static func enableWithGesture() {
        // Implementation
    }

    // Or via URL scheme: voicelearn://developer
    static func handleURL(_ url: URL) {
        if url.host == "developer" {
            // Enable developer mode
        }
    }

    // Or via hidden setting
    static func enableWithSecret(_ secret: String) {
        if secret == "correct-secret-hash" {
            // Enable developer mode
        }
    }
}
```

---

## 7. Learning from the System

The routing history enables learning:

```swift
// MARK: - Analytics

struct RoutingAnalytics {
    // Which endpoints perform best for which tasks?
    func analyzePerformance() -> [LLMTaskType: EndpointPerformance] {
        // Group by task type
        // Calculate avg latency, failure rate per endpoint
        // Identify optimal routing
    }

    // Are auto-rules triggering appropriately?
    func analyzeRuleEffectiveness() -> [UUID: RuleEffectiveness] {
        // How often does each rule trigger?
        // What's the outcome when it triggers?
        // Is it helping or hurting?
    }

    // Cost optimization opportunities
    func analyzeCostSavings() -> CostAnalysis {
        // What did we spend on each endpoint?
        // What could we have saved with different routing?
        // Where are we over-using expensive endpoints?
    }

    // Export for external analysis
    func exportHistory(format: ExportFormat) -> Data {
        // JSON or CSV export of routing decisions
        // For offline analysis / ML training
    }
}
```

---

## Summary

```
┌─────────────────────────────────────────────────────────────────────┐
│  PATCH PANEL ARCHITECTURE                                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Core Components:                                                    │
│  ├── Endpoint Registry    - All LLM endpoints with configs          │
│  ├── Task Types           - Every type of LLM call                  │
│  ├── Routing Table        - Maps tasks → endpoints                  │
│  ├── Auto-Routing Rules   - Condition-based routing                 │
│  └── Routing History      - Full observability                      │
│                                                                      │
│  Routing Priority:                                                   │
│  1. Global Override       - Debug: send everything to one place    │
│  2. Manual Override       - Per-task-type forced routing           │
│  3. Auto-Routing Rules    - Condition-based (thermal, network...)  │
│  4. Default Routes        - Pre-configured task→endpoint mapping   │
│  5. Fallback Chain        - If all else fails                      │
│                                                                      │
│  Developer Mode:                                                     │
│  ├── Live traffic view    - See every routing decision             │
│  ├── Endpoint status      - Health, latency, availability          │
│  ├── Manual patching      - Override any routing                   │
│  ├── Rule toggling        - Enable/disable auto-rules              │
│  └── Stats & analytics    - Learn from real usage                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

*This architecture provides complete control and visibility while keeping the default path simple and automatic.*
