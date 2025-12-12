// VoiceLearn - Routing Table
// Defines the routing configuration for the Patch Panel
//
// Part of Core/Routing (Patch Panel Architecture)
//
// The routing table contains:
// - Default routes: Task type → preferred endpoint chain
// - Manual overrides: Force specific task types to specific endpoints
// - Global override: Route ALL tasks to one endpoint (debug mode)
// - Auto-routing rules: Condition-based dynamic routing
// - Fallback chain: Last resort endpoints when all else fails

import Foundation

// MARK: - Routing Table

/// Configuration for LLM task routing
///
/// The routing table defines how tasks are routed to endpoints.
/// Routes are resolved in priority order:
/// 1. Global override (if set)
/// 2. Manual override for task type (if set)
/// 3. Auto-routing rules (if conditions match)
/// 4. Default route for task type
/// 5. Fallback chain
public struct RoutingTable: Codable, Sendable {

    // MARK: - Routes

    /// Default routes for each task type
    /// Maps task type to an ordered list of preferred endpoint IDs
    public var defaultRoutes: [LLMTaskType: [String]]

    /// Manual overrides for specific task types (highest priority after global)
    /// Maps task type to a forced endpoint ID
    public var manualOverrides: [LLMTaskType: String]

    /// Global override - routes ALL tasks to this endpoint (for debugging)
    public var globalOverride: String?

    /// Auto-routing rules that can override default routes based on conditions
    public var autoRoutingRules: [AutoRoutingRule]

    /// Fallback chain - used when no other routing succeeds
    /// Ordered list of endpoint IDs to try as last resort
    public var fallbackChain: [String]

    // MARK: - Initialization

    public init(
        defaultRoutes: [LLMTaskType: [String]] = [:],
        manualOverrides: [LLMTaskType: String] = [:],
        globalOverride: String? = nil,
        autoRoutingRules: [AutoRoutingRule] = [],
        fallbackChain: [String] = []
    ) {
        self.defaultRoutes = defaultRoutes
        self.manualOverrides = manualOverrides
        self.globalOverride = globalOverride
        self.autoRoutingRules = autoRoutingRules
        self.fallbackChain = fallbackChain
    }
}

// MARK: - Default Routing Table

extension RoutingTable {

    /// Default routing configuration
    ///
    /// This provides sensible defaults for routing:
    /// - Frontier tasks → Cloud APIs (GPT-4o, Claude)
    /// - Medium tasks → Self-hosted or cheaper cloud
    /// - Small/tiny tasks → On-device models
    public static let `default` = RoutingTable(
        defaultRoutes: [
            // MARK: Frontier Tasks - Prefer cloud APIs

            .tutoringResponse: ["gpt-4o", "claude-3.5-sonnet", "llama-70b-server", "gpt-4o-mini"],
            .understandingCheck: ["gpt-4o", "claude-3.5-sonnet", "llama-70b-server", "gpt-4o-mini"],
            .socraticQuestion: ["gpt-4o", "claude-3.5-sonnet", "llama-70b-server"],
            .misconceptionCorrection: ["claude-3.5-sonnet", "gpt-4o", "llama-70b-server"],
            .tangentExploration: ["gpt-4o", "claude-3.5-sonnet", "gpt-4o-mini"],

            // MARK: Medium Tasks - Prefer self-hosted

            .explanationGeneration: ["llama-70b-server", "llama-8b-server", "gpt-4o-mini"],
            .exampleGeneration: ["llama-70b-server", "gpt-4o-mini", "llama-8b-server"],
            .analogyGeneration: ["gpt-4o-mini", "llama-70b-server", "claude-3.5-haiku"],
            .rephrasing: ["llama-8b-server", "gpt-4o-mini", "llama-70b-server"],
            .simplification: ["llama-8b-server", "gpt-4o-mini", "llama-3b-device"],
            .documentSummarization: ["llama-70b-server", "gpt-4o-mini", "claude-3.5-haiku"],
            .transcriptGeneration: ["llama-70b-server", "gpt-4o-mini"],
            .sessionSummary: ["llama-8b-server", "gpt-4o-mini", "llama-70b-server"],

            // MARK: Small Tasks - Prefer on-device

            .intentClassification: ["llama-1b-device", "llama-3b-device", "gpt-4o-mini"],
            .sentimentAnalysis: ["llama-1b-device", "llama-3b-device", "gpt-4o-mini"],
            .topicClassification: ["llama-1b-device", "llama-3b-device", "gpt-4o-mini"],
            .glossaryExtraction: ["llama-3b-device", "llama-8b-server", "gpt-4o-mini"],
            .topicTransition: ["llama-1b-device", "llama-3b-device", "gpt-4o-mini"],

            // MARK: Tiny Tasks - On-device only

            .acknowledgment: ["llama-1b-device", "llama-3b-device", "gpt-4o-mini"],
            .fillerResponse: ["llama-1b-device", "llama-3b-device", "gpt-4o-mini"],
            .navigationConfirmation: ["llama-1b-device", "llama-3b-device", "gpt-4o-mini"],

            // MARK: System Tasks

            .healthCheck: ["gpt-4o-mini", "llama-1b-device"],
            .embeddingGeneration: ["gpt-4o-mini"]  // Uses embedding endpoint
        ],
        manualOverrides: [:],
        globalOverride: nil,
        autoRoutingRules: [
            // Rule 1: Thermal throttle - avoid on-device when hot
            AutoRoutingRule(
                id: UUID(),
                name: "Thermal Throttle",
                isEnabled: true,
                priority: 100,
                conditions: [.thermalState(.atLeast_serious)],
                conditionLogic: .all,
                targetEndpointId: "gpt-4o-mini",
                applyToTaskTypes: [
                    .acknowledgment,
                    .fillerResponse,
                    .navigationConfirmation,
                    .intentClassification,
                    .sentimentAnalysis,
                    .topicClassification
                ]
            ),

            // Rule 2: Offline mode - use on-device for everything
            AutoRoutingRule(
                id: UUID(),
                name: "Offline Mode",
                isEnabled: true,
                priority: 200,  // Higher priority than thermal
                conditions: [.networkType(.none)],
                conditionLogic: .all,
                targetEndpointId: "llama-3b-device",
                applyToTaskTypes: nil  // Applies to all tasks
            ),

            // Rule 3: Cellular cost saving - prefer cheaper options
            AutoRoutingRule(
                id: UUID(),
                name: "Cellular Cost Saving",
                isEnabled: true,
                priority: 50,
                conditions: [.networkType(.cellular)],
                conditionLogic: .all,
                targetEndpointId: "gpt-4o-mini",
                applyToTaskTypes: [
                    .explanationGeneration,
                    .exampleGeneration,
                    .analogyGeneration,
                    .rephrasing
                ]
            ),

            // Rule 4: Budget conservation - use cheaper models when budget low
            AutoRoutingRule(
                id: UUID(),
                name: "Budget Conservation",
                isEnabled: true,
                priority: 75,
                conditions: [
                    .sessionCostBudget(ComparisonCondition(comparison: .lessThan, value: 0.10))
                ],
                conditionLogic: .all,
                targetEndpointId: "gpt-4o-mini",
                applyToTaskTypes: [
                    .tutoringResponse,
                    .understandingCheck,
                    .socraticQuestion
                ]
            ),

            // Rule 5: Low battery - avoid on-device LLM
            AutoRoutingRule(
                id: UUID(),
                name: "Low Battery Mode",
                isEnabled: true,
                priority: 90,
                conditions: [
                    .batteryLevel(ComparisonCondition(comparison: .lessThan, value: 0.15))
                ],
                conditionLogic: .all,
                targetEndpointId: "gpt-4o-mini",
                applyToTaskTypes: [
                    .acknowledgment,
                    .fillerResponse,
                    .intentClassification
                ]
            )
        ],
        fallbackChain: [
            "gpt-4o-mini",      // Reliable, cheap cloud
            "claude-3.5-haiku", // Alternative cloud
            "llama-3b-device",  // On-device backup
            "llama-1b-device"   // Smallest on-device
        ]
    )
}

// MARK: - Auto-Routing Rule

/// A rule that automatically routes tasks based on conditions
///
/// Rules are evaluated in priority order (highest first).
/// When a rule's conditions match, it overrides the default route.
public struct AutoRoutingRule: Identifiable, Codable, Sendable {

    /// Unique identifier for this rule
    public let id: UUID

    /// Human-readable name for this rule
    public var name: String

    /// Whether this rule is currently enabled
    public var isEnabled: Bool

    /// Priority (higher = checked first)
    public var priority: Int

    /// Conditions that must be met for this rule to trigger
    public var conditions: [RoutingCondition]

    /// How to combine conditions (all must match, or any can match)
    public var conditionLogic: ConditionLogic

    /// The endpoint to route to when this rule triggers
    public var targetEndpointId: String

    /// Task types this rule applies to (nil = all tasks)
    public var applyToTaskTypes: Set<LLMTaskType>?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool,
        priority: Int,
        conditions: [RoutingCondition],
        conditionLogic: ConditionLogic,
        targetEndpointId: String,
        applyToTaskTypes: Set<LLMTaskType>?
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.priority = priority
        self.conditions = conditions
        self.conditionLogic = conditionLogic
        self.targetEndpointId = targetEndpointId
        self.applyToTaskTypes = applyToTaskTypes
    }

    // MARK: - Evaluation

    /// Check if this rule applies to a given task type
    public func appliesTo(_ taskType: LLMTaskType) -> Bool {
        // nil means applies to all
        guard let allowedTypes = applyToTaskTypes else {
            return true
        }
        return allowedTypes.contains(taskType)
    }

    /// Check if this rule's conditions match the current context
    public func matches(context: RoutingContext) -> Bool {
        // Empty conditions always match
        if conditions.isEmpty {
            return true
        }

        let results = conditions.map { $0.evaluate(with: context) }

        switch conditionLogic {
        case .all:
            return results.allSatisfy { $0 }
        case .any:
            return results.contains { $0 }
        }
    }

    /// Check if this rule should trigger for a task type and context
    public func shouldTrigger(for taskType: LLMTaskType, context: RoutingContext) -> Bool {
        guard isEnabled else { return false }
        guard appliesTo(taskType) else { return false }
        return matches(context: context)
    }
}

// MARK: - Condition Logic

/// How to combine multiple conditions in a rule
public enum ConditionLogic: String, Codable, Sendable {
    /// All conditions must be true
    case all

    /// Any condition can be true
    case any
}

// MARK: - Routing Decision

/// The result of resolving a routing decision
public struct RoutingDecision: Sendable {
    /// Ordered list of endpoint IDs to try
    public let endpointChain: [String]

    /// Why this routing was chosen
    public let reason: RoutingReason

    public init(endpointChain: [String], reason: RoutingReason) {
        self.endpointChain = endpointChain
        self.reason = reason
    }
}

// MARK: - Routing Reason

/// The reason a particular routing decision was made
public enum RoutingReason: Sendable, Equatable {
    /// Global override was active
    case globalOverride

    /// Manual override for this task type
    case manualOverride

    /// An auto-routing rule triggered
    case autoRule(String)

    /// Used the default route for this task type
    case defaultRoute

    /// All other routes failed, using fallback
    case fallback

    /// Human-readable description
    public var description: String {
        switch self {
        case .globalOverride:
            return "Global Override"
        case .manualOverride:
            return "Manual Override"
        case .autoRule(let name):
            return "Auto Rule: \(name)"
        case .defaultRoute:
            return "Default Route"
        case .fallback:
            return "Fallback"
        }
    }
}

// MARK: - Task Request

/// A request to route a task to an LLM endpoint
public struct LLMTaskRequest: Sendable {
    /// Type of task to perform
    public let taskType: LLMTaskType

    /// The prompt to send to the LLM
    public let prompt: String

    /// Optional system prompt
    public let systemPrompt: String?

    /// Optional context dictionary
    public let context: [String: String]?

    /// Maximum tokens to generate
    public let maxTokens: Int?

    /// Temperature for generation
    public let temperature: Float?

    /// Conversation history (if applicable)
    public let conversationHistory: [LLMMessage]?

    public init(
        taskType: LLMTaskType,
        prompt: String,
        systemPrompt: String? = nil,
        context: [String: String]? = nil,
        maxTokens: Int? = nil,
        temperature: Float? = nil,
        conversationHistory: [LLMMessage]? = nil
    ) {
        self.taskType = taskType
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.context = context
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.conversationHistory = conversationHistory
    }

    /// Estimate the prompt token count (rough approximation)
    public var estimatedPromptTokens: Int {
        // Rough estimate: ~4 characters per token
        let promptTokens = prompt.count / 4
        let systemTokens = (systemPrompt?.count ?? 0) / 4
        let historyTokens = conversationHistory?.reduce(0) { $0 + $1.content.count / 4 } ?? 0
        return promptTokens + systemTokens + historyTokens
    }
}

// MARK: - Routing Stats

/// Statistics about routing decisions
public struct RoutingStats: Sendable {
    /// Total number of routing requests
    public let totalRequests: Int

    /// Requests by endpoint
    public let byEndpoint: [String: Int]

    /// Requests by task type
    public let byTaskType: [LLMTaskType: Int]

    /// Requests by routing reason
    public let byReason: [String: Int]

    /// Average latency by endpoint (milliseconds)
    public let avgLatencyByEndpoint: [String: Double]

    /// Failure count by endpoint
    public let failuresByEndpoint: [String: Int]

    public init(
        totalRequests: Int = 0,
        byEndpoint: [String: Int] = [:],
        byTaskType: [LLMTaskType: Int] = [:],
        byReason: [String: Int] = [:],
        avgLatencyByEndpoint: [String: Double] = [:],
        failuresByEndpoint: [String: Int] = [:]
    ) {
        self.totalRequests = totalRequests
        self.byEndpoint = byEndpoint
        self.byTaskType = byTaskType
        self.byReason = byReason
        self.avgLatencyByEndpoint = avgLatencyByEndpoint
        self.failuresByEndpoint = failuresByEndpoint
    }
}

// MARK: - Routing Record

/// A record of a single routing decision (for history/debugging)
public struct RoutingRecord: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let taskType: LLMTaskType
    public let decision: RoutingDecision
    public let endpointUsed: String?
    public let latencyMs: Int?
    public let success: Bool

    public init(
        timestamp: Date,
        taskType: LLMTaskType,
        decision: RoutingDecision,
        endpointUsed: String? = nil,
        latencyMs: Int? = nil,
        success: Bool = true
    ) {
        self.timestamp = timestamp
        self.taskType = taskType
        self.decision = decision
        self.endpointUsed = endpointUsed
        self.latencyMs = latencyMs
        self.success = success
    }
}
