// VoiceLearn - Patch Panel Service Tests
// Tests for the main routing service actor
//
// Part of Patch Panel routing system

import XCTest
@testable import VoiceLearn

/// Tests for PatchPanelService routing logic
final class PatchPanelServiceTests: XCTestCase {

    var patchPanel: PatchPanelService!
    var telemetry: TelemetryEngine!

    override func setUp() async throws {
        telemetry = TelemetryEngine()
        patchPanel = PatchPanelService(telemetry: telemetry)
    }

    override func tearDown() async throws {
        patchPanel = nil
        telemetry = nil
    }

    // MARK: - Initialization Tests

    func testPatchPanelInitialization() async {
        let registry = await patchPanel.endpointRegistry
        let table = await patchPanel.routingTable

        XCTAssertFalse(registry.isEmpty, "Registry should be populated")
        XCTAssertFalse(table.defaultRoutes.isEmpty, "Routing table should have defaults")
    }

    func testPatchPanelDeveloperModeDisabledByDefault() async {
        let devMode = await patchPanel.isDeveloperModeEnabled
        XCTAssertFalse(devMode)
    }

    // MARK: - Routing Resolution Tests

    func testRouteUsesDefaultForSimpleTask() async {
        let decision = await patchPanel.resolveRouting(
            taskType: .acknowledgment,
            context: RoutingContext()
        )

        // Acknowledgment should route to on-device by default
        XCTAssertEqual(decision.endpointChain.first, "llama-1b-device")
        XCTAssertEqual(decision.reason, .defaultRoute)
    }

    func testRouteUsesDefaultForFrontierTask() async {
        let decision = await patchPanel.resolveRouting(
            taskType: .tutoringResponse,
            context: RoutingContext()
        )

        // Tutoring should route to frontier model by default
        XCTAssertTrue(
            decision.endpointChain.first == "gpt-4o" ||
            decision.endpointChain.first == "claude-3.5-sonnet"
        )
        XCTAssertEqual(decision.reason, .defaultRoute)
    }

    // MARK: - Global Override Tests

    func testGlobalOverrideTakesPrecedence() async {
        await patchPanel.enableDeveloperMode()
        await patchPanel.setGlobalOverride("gpt-4o-mini")

        let decision = await patchPanel.resolveRouting(
            taskType: .tutoringResponse,
            context: RoutingContext()
        )

        XCTAssertEqual(decision.endpointChain.first, "gpt-4o-mini")
        XCTAssertEqual(decision.reason, .globalOverride)
    }

    func testGlobalOverrideRequiresDeveloperMode() async {
        // Developer mode is disabled by default
        await patchPanel.setGlobalOverride("gpt-4o-mini")

        let globalOverride = await patchPanel.routingTable.globalOverride
        XCTAssertNil(globalOverride, "Global override should not be set without dev mode")
    }

    func testClearGlobalOverride() async {
        await patchPanel.enableDeveloperMode()
        await patchPanel.setGlobalOverride("gpt-4o-mini")
        await patchPanel.setGlobalOverride(nil)

        let decision = await patchPanel.resolveRouting(
            taskType: .acknowledgment,
            context: RoutingContext()
        )

        // Should fall back to default after clearing override
        XCTAssertNotEqual(decision.reason, .globalOverride)
    }

    // MARK: - Manual Override Tests

    func testManualOverrideTakesPrecedenceOverDefault() async {
        await patchPanel.enableDeveloperMode()
        await patchPanel.setManualOverride(for: .tutoringResponse, endpointId: "claude-3.5-haiku")

        let decision = await patchPanel.resolveRouting(
            taskType: .tutoringResponse,
            context: RoutingContext()
        )

        XCTAssertEqual(decision.endpointChain.first, "claude-3.5-haiku")
        XCTAssertEqual(decision.reason, .manualOverride)
    }

    func testManualOverrideRequiresDeveloperMode() async {
        await patchPanel.setManualOverride(for: .tutoringResponse, endpointId: "claude-3.5-haiku")

        let override = await patchPanel.routingTable.manualOverrides[.tutoringResponse]
        XCTAssertNil(override, "Manual override should not be set without dev mode")
    }

    func testManualOverrideOnlyAffectsSpecificTask() async {
        await patchPanel.enableDeveloperMode()
        await patchPanel.setManualOverride(for: .tutoringResponse, endpointId: "claude-3.5-haiku")

        // Tutoring should use override
        let tutoringDecision = await patchPanel.resolveRouting(
            taskType: .tutoringResponse,
            context: RoutingContext()
        )
        XCTAssertEqual(tutoringDecision.endpointChain.first, "claude-3.5-haiku")

        // Other tasks should use default
        let ackDecision = await patchPanel.resolveRouting(
            taskType: .acknowledgment,
            context: RoutingContext()
        )
        XCTAssertNotEqual(ackDecision.endpointChain.first, "claude-3.5-haiku")
    }

    // MARK: - Auto-Routing Rule Tests

    func testThermalThrottleRuleTriggersOnSerious() async {
        let hotContext = RoutingContext(thermalState: .serious)

        let decision = await patchPanel.resolveRouting(
            taskType: .acknowledgment,
            context: hotContext
        )

        // Should route to cloud instead of on-device
        XCTAssertTrue(
            decision.endpointChain.first == "gpt-4o-mini",
            "Thermal throttle should route to cloud"
        )
        XCTAssertEqual(decision.reason, .autoRule("Thermal Throttle"))
    }

    func testThermalThrottleDoesNotTriggerOnNominal() async {
        let coolContext = RoutingContext(thermalState: .nominal)

        let decision = await patchPanel.resolveRouting(
            taskType: .acknowledgment,
            context: coolContext
        )

        // Should use default on-device route
        XCTAssertEqual(decision.endpointChain.first, "llama-1b-device")
        XCTAssertEqual(decision.reason, .defaultRoute)
    }

    func testOfflineModeRuleTriggersWhenNoNetwork() async {
        let offlineContext = RoutingContext(networkType: .none)

        let decision = await patchPanel.resolveRouting(
            taskType: .tutoringResponse,
            context: offlineContext
        )

        // Should route to on-device even for frontier task
        XCTAssertTrue(
            decision.endpointChain.first?.contains("device") ?? false,
            "Offline mode should route to on-device"
        )
        XCTAssertEqual(decision.reason, .autoRule("Offline Mode"))
    }

    func testBudgetConservationRuleTriggersOnLowBudget() async {
        let lowBudgetContext = RoutingContext(remainingBudget: 0.05)

        let decision = await patchPanel.resolveRouting(
            taskType: .tutoringResponse,
            context: lowBudgetContext
        )

        // Should route to cheaper model
        XCTAssertTrue(
            decision.endpointChain.first == "gpt-4o-mini",
            "Low budget should route to cheaper model"
        )
    }

    func testRulePriorityOrdering() async {
        // Create context that matches multiple rules
        let complexContext = RoutingContext(
            thermalState: .serious,
            networkType: .none
        )

        // Offline mode has higher priority (200) than thermal throttle (100)
        let decision = await patchPanel.resolveRouting(
            taskType: .acknowledgment,
            context: complexContext
        )

        // Should use offline rule (higher priority)
        XCTAssertEqual(decision.reason, .autoRule("Offline Mode"))
    }

    func testDisabledRuleDoesNotTrigger() async {
        await patchPanel.enableDeveloperMode()

        // Find and disable thermal throttle rule
        let rules = await patchPanel.routingTable.autoRoutingRules
        if let thermalRule = rules.first(where: { $0.name == "Thermal Throttle" }) {
            await patchPanel.setRuleEnabled(thermalRule.id, enabled: false)
        }

        let hotContext = RoutingContext(thermalState: .serious)

        let decision = await patchPanel.resolveRouting(
            taskType: .acknowledgment,
            context: hotContext
        )

        // Should NOT trigger thermal throttle
        XCTAssertNotEqual(decision.reason, .autoRule("Thermal Throttle"))
    }

    // MARK: - Fallback Chain Tests

    func testFallbackChainUsedWhenDefaultUnavailable() async {
        // Mark all default endpoints for acknowledgment as unavailable
        await patchPanel.setEndpointStatus("llama-1b-device", status: .unavailable)

        let decision = await patchPanel.resolveRouting(
            taskType: .acknowledgment,
            context: RoutingContext()
        )

        // Should fall back to fallback chain
        XCTAssertEqual(decision.reason, .fallback)
        XCTAssertFalse(decision.endpointChain.isEmpty)
    }

    func testEndpointChainIncludesFallbacks() async {
        let decision = await patchPanel.resolveRouting(
            taskType: .acknowledgment,
            context: RoutingContext()
        )

        // Chain should have more than just the primary endpoint
        XCTAssertGreaterThan(decision.endpointChain.count, 1)
    }

    // MARK: - Routing History Tests

    func testRoutingHistoryRecorded() async {
        _ = await patchPanel.resolveRouting(
            taskType: .acknowledgment,
            context: RoutingContext()
        )

        let stats = await patchPanel.getRoutingStats()
        XCTAssertGreaterThan(stats.totalRequests, 0)
    }

    func testRoutingHistoryLimitedTo1000() async {
        // Make 1100 routing decisions
        for _ in 0..<1100 {
            _ = await patchPanel.resolveRouting(
                taskType: .acknowledgment,
                context: RoutingContext()
            )
        }

        let historyCount = await patchPanel.routingHistoryCount
        XCTAssertLessThanOrEqual(historyCount, 1000)
    }

    // MARK: - Endpoint Status Tests

    func testSetEndpointStatus() async {
        await patchPanel.setEndpointStatus("gpt-4o", status: .degraded)

        let registry = await patchPanel.endpointRegistry
        XCTAssertEqual(registry["gpt-4o"]?.status, .degraded)
    }

    func testUnavailableEndpointSkippedInRouting() async {
        await patchPanel.setEndpointStatus("llama-1b-device", status: .unavailable)

        let decision = await patchPanel.resolveRouting(
            taskType: .acknowledgment,
            context: RoutingContext()
        )

        // Unavailable endpoint should not be first choice
        XCTAssertNotEqual(decision.endpointChain.first, "llama-1b-device")
    }

    // MARK: - Stats Tests

    func testGetRoutingStats() async {
        // Make some routing decisions
        for taskType in [LLMTaskType.acknowledgment, .tutoringResponse, .intentClassification] {
            _ = await patchPanel.resolveRouting(taskType: taskType, context: RoutingContext())
        }

        let stats = await patchPanel.getRoutingStats()

        XCTAssertEqual(stats.totalRequests, 3)
        XCTAssertFalse(stats.byTaskType.isEmpty)
        XCTAssertFalse(stats.byEndpoint.isEmpty)
    }

    // MARK: - Task Request Tests

    func testCreateTaskRequest() {
        let request = LLMTaskRequest(
            taskType: .tutoringResponse,
            prompt: "Explain quantum entanglement",
            context: ["topic": "quantum physics"],
            maxTokens: 500
        )

        XCTAssertEqual(request.taskType, .tutoringResponse)
        XCTAssertEqual(request.prompt, "Explain quantum entanglement")
        XCTAssertEqual(request.context?["topic"], "quantum physics")
        XCTAssertEqual(request.maxTokens, 500)
    }
}

/// Tests for RoutingDecision
final class RoutingDecisionTests: XCTestCase {

    func testRoutingDecisionCreation() {
        let decision = RoutingDecision(
            endpointChain: ["gpt-4o", "gpt-4o-mini", "llama-3b-device"],
            reason: .defaultRoute
        )

        XCTAssertEqual(decision.endpointChain.count, 3)
        XCTAssertEqual(decision.endpointChain.first, "gpt-4o")
        XCTAssertEqual(decision.reason, .defaultRoute)
    }

    func testRoutingReasonDescription() {
        XCTAssertEqual(RoutingReason.globalOverride.description, "Global Override")
        XCTAssertEqual(RoutingReason.manualOverride.description, "Manual Override")
        XCTAssertEqual(RoutingReason.autoRule("Test").description, "Auto Rule: Test")
        XCTAssertEqual(RoutingReason.defaultRoute.description, "Default Route")
        XCTAssertEqual(RoutingReason.fallback.description, "Fallback")
    }

    func testRoutingReasonEquatable() {
        XCTAssertEqual(RoutingReason.globalOverride, RoutingReason.globalOverride)
        XCTAssertEqual(RoutingReason.autoRule("Test"), RoutingReason.autoRule("Test"))
        XCTAssertNotEqual(RoutingReason.autoRule("Test1"), RoutingReason.autoRule("Test2"))
        XCTAssertNotEqual(RoutingReason.globalOverride, RoutingReason.manualOverride)
    }
}

/// Tests for LLMTaskRequest
final class LLMTaskRequestTests: XCTestCase {

    func testTaskRequestWithMinimalParams() {
        let request = LLMTaskRequest(
            taskType: .acknowledgment,
            prompt: "okay"
        )

        XCTAssertEqual(request.taskType, .acknowledgment)
        XCTAssertEqual(request.prompt, "okay")
        XCTAssertNil(request.context)
        XCTAssertNil(request.maxTokens)
        XCTAssertNil(request.systemPrompt)
    }

    func testTaskRequestWithAllParams() {
        let request = LLMTaskRequest(
            taskType: .tutoringResponse,
            prompt: "Explain X",
            systemPrompt: "You are a tutor",
            context: ["key": "value"],
            maxTokens: 1000,
            temperature: 0.7,
            conversationHistory: [
                LLMMessage(role: .user, content: "Hello"),
                LLMMessage(role: .assistant, content: "Hi!")
            ]
        )

        XCTAssertEqual(request.taskType, .tutoringResponse)
        XCTAssertEqual(request.prompt, "Explain X")
        XCTAssertEqual(request.systemPrompt, "You are a tutor")
        XCTAssertEqual(request.context?["key"], "value")
        XCTAssertEqual(request.maxTokens, 1000)
        XCTAssertEqual(request.temperature, 0.7)
        XCTAssertEqual(request.conversationHistory?.count, 2)
    }

    func testTaskRequestEstimatedTokenCount() {
        let request = LLMTaskRequest(
            taskType: .tutoringResponse,
            prompt: String(repeating: "word ", count: 100)  // ~500 chars
        )

        // Rough estimate: chars / 4
        let estimate = request.estimatedPromptTokens
        XCTAssertGreaterThan(estimate, 100)
        XCTAssertLessThan(estimate, 200)
    }
}

/// Tests for RoutingStats
final class RoutingStatsTests: XCTestCase {

    func testRoutingStatsCreation() {
        let stats = RoutingStats(
            totalRequests: 100,
            byEndpoint: ["gpt-4o": 50, "llama-1b-device": 50],
            byTaskType: [.tutoringResponse: 30, .acknowledgment: 70],
            byReason: ["Default Route": 80, "Auto Rule: Thermal Throttle": 20],
            avgLatencyByEndpoint: ["gpt-4o": 300.0],
            failuresByEndpoint: ["gpt-4o": 2]
        )

        XCTAssertEqual(stats.totalRequests, 100)
        XCTAssertEqual(stats.byEndpoint["gpt-4o"], 50)
        XCTAssertEqual(stats.byTaskType[.tutoringResponse], 30)
        XCTAssertEqual(stats.failuresByEndpoint["gpt-4o"], 2)
    }
}
