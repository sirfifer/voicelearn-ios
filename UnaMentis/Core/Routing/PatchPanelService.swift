// UnaMentis - Patch Panel Service
// Main routing service for LLM task routing
//
// Part of Core/Routing (Patch Panel Architecture)
//
// The PatchPanelService is the central routing hub that:
// - Maintains the endpoint registry (all available LLM endpoints)
// - Maintains the routing table (how to route tasks to endpoints)
// - Resolves routing decisions based on task type, conditions, and rules
// - Tracks routing history for debugging and analytics
// - Provides developer mode controls for manual overrides

import Foundation
import Logging

// MARK: - Patch Panel Service

/// Central service for routing LLM tasks to appropriate endpoints
///
/// The Patch Panel acts as a switchboard between task requests and LLM endpoints.
/// It makes intelligent routing decisions based on:
/// - Task type and capability requirements
/// - Current device conditions (thermal, memory, battery)
/// - Network status and latency
/// - Cost budget constraints
/// - Manual overrides (in developer mode)
/// - Auto-routing rules
///
/// ## Usage
/// ```swift
/// let patchPanel = PatchPanelService(telemetry: telemetry)
///
/// let decision = await patchPanel.resolveRouting(
///     taskType: .tutoringResponse,
///     context: currentContext
/// )
/// // decision.endpointChain = ["gpt-4o", "gpt-4o-mini", ...]
/// ```
public actor PatchPanelService {

    // MARK: - Properties

    private let logger = Logger(label: "com.unamentis.patchpanel")

    /// Registry of all available LLM endpoints
    public private(set) var endpointRegistry: [String: LLMEndpoint]

    /// Current routing configuration
    public private(set) var routingTable: RoutingTable

    /// History of routing decisions (for debugging/analytics)
    private var routingHistory: [RoutingRecord] = []

    /// Maximum routing history entries to keep
    private let maxHistoryEntries = 1000

    /// Telemetry engine for metrics
    private let telemetry: TelemetryEngine

    /// Whether developer mode is enabled (allows manual overrides)
    public private(set) var isDeveloperModeEnabled: Bool = false

    // MARK: - Initialization

    /// Initialize the patch panel with dependencies
    /// - Parameters:
    ///   - telemetry: Telemetry engine for recording metrics
    ///   - customRegistry: Optional custom endpoint registry (defaults to standard endpoints)
    ///   - customTable: Optional custom routing table (defaults to standard routing)
    public init(
        telemetry: TelemetryEngine,
        customRegistry: [String: LLMEndpoint]? = nil,
        customTable: RoutingTable? = nil
    ) {
        self.telemetry = telemetry
        self.endpointRegistry = customRegistry ?? LLMEndpoint.defaultRegistry
        self.routingTable = customTable ?? RoutingTable.default

        let count = endpointRegistry.count
        logger.info("PatchPanelService initialized with \(count) endpoints")
    }

    // MARK: - Routing Resolution

    /// Resolve the routing for a task type with current context
    ///
    /// This is the main routing function that determines which endpoint(s)
    /// should handle a task request. It checks in priority order:
    /// 1. Global override (if set)
    /// 2. Manual override for task type (if set)
    /// 3. Auto-routing rules (if conditions match)
    /// 4. Default route for task type
    /// 5. Fallback chain
    ///
    /// - Parameters:
    ///   - taskType: The type of task to route
    ///   - context: Current runtime context for condition evaluation
    /// - Returns: A routing decision with endpoint chain and reason
    public func resolveRouting(
        taskType: LLMTaskType,
        context: RoutingContext
    ) -> RoutingDecision {
        logger.debug("Resolving routing for \(taskType.rawValue)")

        // Priority 1: Global override (for debugging)
        if let globalOverride = routingTable.globalOverride {
            if let endpoint = endpointRegistry[globalOverride],
               endpoint.status.isUsable {
                logger.debug("Using global override: \(globalOverride)")
                let decision = RoutingDecision(
                    endpointChain: [globalOverride] + routingTable.fallbackChain.filter { $0 != globalOverride },
                    reason: .globalOverride
                )
                recordRoutingDecision(taskType: taskType, decision: decision)
                return decision
            }
        }

        // Priority 2: Manual override for this task type
        if let manualOverride = routingTable.manualOverrides[taskType] {
            if let endpoint = endpointRegistry[manualOverride],
               endpoint.status.isUsable {
                logger.debug("Using manual override for \(taskType.rawValue): \(manualOverride)")
                let decision = RoutingDecision(
                    endpointChain: [manualOverride] + routingTable.fallbackChain.filter { $0 != manualOverride },
                    reason: .manualOverride
                )
                recordRoutingDecision(taskType: taskType, decision: decision)
                return decision
            }
        }

        // Priority 3: Auto-routing rules (sorted by priority, highest first)
        let applicableRules = routingTable.autoRoutingRules
            .filter { $0.shouldTrigger(for: taskType, context: context) }
            .sorted { $0.priority > $1.priority }

        for rule in applicableRules {
            if let endpoint = endpointRegistry[rule.targetEndpointId],
               endpoint.status.isUsable {
                logger.debug("Auto-rule '\(rule.name)' triggered, routing to \(rule.targetEndpointId)")
                let decision = RoutingDecision(
                    endpointChain: [rule.targetEndpointId] + routingTable.fallbackChain.filter { $0 != rule.targetEndpointId },
                    reason: .autoRule(rule.name)
                )
                recordRoutingDecision(taskType: taskType, decision: decision)
                return decision
            }
        }

        // Priority 4: Default route for task type
        if let defaultChain = routingTable.defaultRoutes[taskType] {
            let availableChain = defaultChain.filter { id in
                endpointRegistry[id]?.status.isUsable ?? false
            }
            if !availableChain.isEmpty {
                logger.debug("Using default route for \(taskType.rawValue): \(availableChain.first ?? "?")")
                let fullChain = availableChain + routingTable.fallbackChain.filter { !availableChain.contains($0) }
                let decision = RoutingDecision(
                    endpointChain: fullChain,
                    reason: .defaultRoute
                )
                recordRoutingDecision(taskType: taskType, decision: decision)
                return decision
            }
        }

        // Priority 5: Fallback chain
        logger.warning("No primary route available for \(taskType.rawValue), using fallback chain")
        let availableFallback = routingTable.fallbackChain.filter { id in
            endpointRegistry[id]?.status.isUsable ?? false
        }
        let decision = RoutingDecision(
            endpointChain: availableFallback.isEmpty ? routingTable.fallbackChain : availableFallback,
            reason: .fallback
        )
        recordRoutingDecision(taskType: taskType, decision: decision)
        return decision
    }

    // MARK: - History Recording

    private func recordRoutingDecision(taskType: LLMTaskType, decision: RoutingDecision) {
        let record = RoutingRecord(
            timestamp: Date(),
            taskType: taskType,
            decision: decision
        )
        routingHistory.append(record)

        // Trim history if needed
        if routingHistory.count > maxHistoryEntries {
            routingHistory.removeFirst(routingHistory.count - maxHistoryEntries)
        }
    }

    /// Number of entries in routing history
    public var routingHistoryCount: Int {
        routingHistory.count
    }

    // MARK: - Developer Mode Controls

    /// Enable developer mode (required for manual overrides)
    public func enableDeveloperMode() {
        isDeveloperModeEnabled = true
        logger.info("Developer mode enabled")
    }

    /// Disable developer mode
    public func disableDeveloperMode() {
        isDeveloperModeEnabled = false
        logger.info("Developer mode disabled")
    }

    /// Set a global override (routes ALL tasks to one endpoint)
    /// - Parameter endpointId: Endpoint ID to route to, or nil to clear
    public func setGlobalOverride(_ endpointId: String?) {
        guard isDeveloperModeEnabled else {
            logger.warning("Cannot set global override: developer mode not enabled")
            return
        }

        routingTable.globalOverride = endpointId
        if let id = endpointId {
            logger.info("Global override set to: \(id)")
        } else {
            logger.info("Global override cleared")
        }
    }

    /// Set a manual override for a specific task type
    /// - Parameters:
    ///   - taskType: Task type to override
    ///   - endpointId: Endpoint ID to route to, or nil to clear
    public func setManualOverride(for taskType: LLMTaskType, endpointId: String?) {
        guard isDeveloperModeEnabled else {
            logger.warning("Cannot set manual override: developer mode not enabled")
            return
        }

        if let id = endpointId {
            routingTable.manualOverrides[taskType] = id
            logger.info("Manual override for \(taskType.rawValue) set to: \(id)")
        } else {
            routingTable.manualOverrides.removeValue(forKey: taskType)
            logger.info("Manual override for \(taskType.rawValue) cleared")
        }
    }

    /// Enable or disable an auto-routing rule
    /// - Parameters:
    ///   - ruleId: ID of the rule to modify
    ///   - enabled: Whether the rule should be enabled
    public func setRuleEnabled(_ ruleId: UUID, enabled: Bool) {
        guard isDeveloperModeEnabled else {
            logger.warning("Cannot modify rule: developer mode not enabled")
            return
        }

        if let index = routingTable.autoRoutingRules.firstIndex(where: { $0.id == ruleId }) {
            routingTable.autoRoutingRules[index].isEnabled = enabled
            let ruleName = routingTable.autoRoutingRules[index].name
            logger.info("Rule '\(ruleName)' \(enabled ? "enabled" : "disabled")")
        }
    }

    // MARK: - Endpoint Management

    /// Update the status of an endpoint
    /// - Parameters:
    ///   - endpointId: ID of the endpoint
    ///   - status: New status
    public func setEndpointStatus(_ endpointId: String, status: EndpointStatus) {
        guard var endpoint = endpointRegistry[endpointId] else {
            logger.warning("Cannot update status: endpoint '\(endpointId)' not found")
            return
        }

        endpoint.status = status
        endpoint.lastHealthCheck = Date()
        endpointRegistry[endpointId] = endpoint

        logger.debug("Endpoint '\(endpointId)' status updated to: \(status.rawValue)")
    }

    /// Register a new endpoint or update an existing one
    /// - Parameter endpoint: The endpoint to register
    public func registerEndpoint(_ endpoint: LLMEndpoint) {
        endpointRegistry[endpoint.id] = endpoint
        logger.info("Endpoint registered: \(endpoint.id) (\(endpoint.displayName))")
    }

    /// Remove an endpoint from the registry
    /// - Parameter endpointId: ID of the endpoint to remove
    public func removeEndpoint(_ endpointId: String) {
        guard isDeveloperModeEnabled else {
            logger.warning("Cannot remove endpoint: developer mode not enabled")
            return
        }

        endpointRegistry.removeValue(forKey: endpointId)
        logger.info("Endpoint removed: \(endpointId)")
    }

    // MARK: - Statistics

    /// Get routing statistics from recent history
    public func getRoutingStats() -> RoutingStats {
        let recentRecords = routingHistory.suffix(100)

        // Count by endpoint
        var byEndpoint: [String: Int] = [:]
        for record in recentRecords {
            if let endpoint = record.decision.endpointChain.first {
                byEndpoint[endpoint, default: 0] += 1
            }
        }

        // Count by task type
        var byTaskType: [LLMTaskType: Int] = [:]
        for record in recentRecords {
            byTaskType[record.taskType, default: 0] += 1
        }

        // Count by reason
        var byReason: [String: Int] = [:]
        for record in recentRecords {
            byReason[record.decision.reason.description, default: 0] += 1
        }

        // Calculate average latency by endpoint
        var latencySums: [String: (total: Double, count: Int)] = [:]
        for record in recentRecords {
            if let endpoint = record.endpointUsed,
               let latency = record.latencyMs {
                let current = latencySums[endpoint] ?? (0, 0)
                latencySums[endpoint] = (current.total + Double(latency), current.count + 1)
            }
        }
        let avgLatency = latencySums.mapValues { $0.total / Double($0.count) }

        // Count failures by endpoint
        var failures: [String: Int] = [:]
        for record in recentRecords where !record.success {
            if let endpoint = record.decision.endpointChain.first {
                failures[endpoint, default: 0] += 1
            }
        }

        return RoutingStats(
            totalRequests: routingHistory.count,
            byEndpoint: byEndpoint,
            byTaskType: byTaskType,
            byReason: byReason,
            avgLatencyByEndpoint: avgLatency,
            failuresByEndpoint: failures
        )
    }

    /// Get the full routing history (for debugging)
    public func getRoutingHistory() -> [RoutingRecord] {
        routingHistory
    }

    /// Clear routing history
    public func clearHistory() {
        routingHistory.removeAll()
        logger.info("Routing history cleared")
    }

    // MARK: - Configuration

    /// Update the routing table
    /// - Parameter table: New routing table
    public func updateRoutingTable(_ table: RoutingTable) {
        guard isDeveloperModeEnabled else {
            logger.warning("Cannot update routing table: developer mode not enabled")
            return
        }

        routingTable = table
        logger.info("Routing table updated")
    }

    /// Reset to default configuration
    public func resetToDefaults() {
        endpointRegistry = LLMEndpoint.defaultRegistry
        routingTable = RoutingTable.default
        logger.info("Reset to default configuration")
    }

    // MARK: - Context Capture

    /// Capture the current routing context from system state
    /// This would be called to get real-time device/network conditions
    public func captureCurrentContext() -> RoutingContext {
        // In a real implementation, this would query:
        // - ProcessInfo.processInfo.thermalState
        // - os_proc_available_memory()
        // - UIDevice.current.batteryLevel
        // - Network.currentPath
        // etc.

        // For now, return a default context
        // TODO: Implement real system state capture
        return RoutingContext()
    }
}

// MARK: - Routing Error

/// Errors that can occur during routing
public enum RoutingError: Error, LocalizedError {
    /// All endpoints in the chain failed
    case allEndpointsFailed(Error?)

    /// No valid route could be determined
    case noValidRoute(LLMTaskType)

    /// Endpoint not found in registry
    case endpointNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .allEndpointsFailed(let underlying):
            if let error = underlying {
                return "All endpoints failed. Last error: \(error.localizedDescription)"
            }
            return "All endpoints in routing chain failed"
        case .noValidRoute(let taskType):
            return "No valid route for task type: \(taskType.rawValue)"
        case .endpointNotFound(let id):
            return "Endpoint not found: \(id)"
        }
    }
}
