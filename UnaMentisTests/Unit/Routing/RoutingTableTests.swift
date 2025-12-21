// UnaMentis - Routing Table Tests
// Tests for routing configuration and rule management
//
// Part of Patch Panel routing system

import XCTest
@testable import UnaMentis

/// Tests for RoutingTable configuration
final class RoutingTableTests: XCTestCase {

    // MARK: - Default Routes Tests

    func testDefaultRoutingTableHasRouteForAllTaskTypes() {
        let table = RoutingTable.default

        for taskType in LLMTaskType.allCases {
            let routes = table.defaultRoutes[taskType]
            XCTAssertNotNil(routes, "Missing default route for \(taskType)")
            XCTAssertFalse(routes?.isEmpty ?? true, "Empty route chain for \(taskType)")
        }
    }

    func testDefaultRoutesForFrontierTasks() {
        let table = RoutingTable.default

        // Frontier tasks should prefer cloud endpoints
        let tutoringRoutes = table.defaultRoutes[.tutoringResponse]!
        XCTAssertTrue(
            tutoringRoutes.first == "gpt-4o" || tutoringRoutes.first == "claude-3.5-sonnet",
            "Tutoring should prefer frontier model"
        )

        let understandingRoutes = table.defaultRoutes[.understandingCheck]!
        XCTAssertTrue(
            understandingRoutes.first == "gpt-4o" || understandingRoutes.first == "claude-3.5-sonnet"
        )
    }

    func testDefaultRoutesForSimpleTasks() {
        let table = RoutingTable.default

        // Simple tasks should prefer on-device
        let ackRoutes = table.defaultRoutes[.acknowledgment]!
        XCTAssertEqual(ackRoutes.first, "llama-1b-device")

        let fillerRoutes = table.defaultRoutes[.fillerResponse]!
        XCTAssertEqual(fillerRoutes.first, "llama-1b-device")
    }

    func testDefaultRoutesForMediumTasks() {
        let table = RoutingTable.default

        // Medium tasks should prefer self-hosted
        let explanationRoutes = table.defaultRoutes[.explanationGeneration]!
        XCTAssertTrue(
            explanationRoutes.contains("llama-70b-server") || explanationRoutes.contains("llama-8b-server"),
            "Explanation should have self-hosted option"
        )
    }

    // MARK: - Manual Override Tests

    func testManualOverrideInitiallyEmpty() {
        let table = RoutingTable.default
        XCTAssertTrue(table.manualOverrides.isEmpty)
    }

    func testSetManualOverride() {
        var table = RoutingTable.default

        table.manualOverrides[.tutoringResponse] = "claude-3.5-sonnet"

        XCTAssertEqual(table.manualOverrides[.tutoringResponse], "claude-3.5-sonnet")
    }

    func testRemoveManualOverride() {
        var table = RoutingTable.default

        table.manualOverrides[.tutoringResponse] = "claude-3.5-sonnet"
        table.manualOverrides[.tutoringResponse] = nil

        XCTAssertNil(table.manualOverrides[.tutoringResponse])
    }

    // MARK: - Global Override Tests

    func testGlobalOverrideInitiallyNil() {
        let table = RoutingTable.default
        XCTAssertNil(table.globalOverride)
    }

    func testSetGlobalOverride() {
        var table = RoutingTable.default

        table.globalOverride = "gpt-4o-mini"

        XCTAssertEqual(table.globalOverride, "gpt-4o-mini")
    }

    // MARK: - Auto-Routing Rules Tests

    func testDefaultRulesExist() {
        let table = RoutingTable.default

        XCTAssertFalse(table.autoRoutingRules.isEmpty)
    }

    func testDefaultRulesHaveThermalThrottle() {
        let table = RoutingTable.default

        let thermalRule = table.autoRoutingRules.first { $0.name == "Thermal Throttle" }
        XCTAssertNotNil(thermalRule)
        XCTAssertTrue(thermalRule?.isEnabled ?? false)
    }

    func testDefaultRulesHaveOfflineMode() {
        let table = RoutingTable.default

        let offlineRule = table.autoRoutingRules.first { $0.name == "Offline Mode" }
        XCTAssertNotNil(offlineRule)
        XCTAssertTrue(offlineRule?.isEnabled ?? false)
    }

    func testDefaultRulesHaveBudgetConservation() {
        let table = RoutingTable.default

        let budgetRule = table.autoRoutingRules.first { $0.name == "Budget Conservation" }
        XCTAssertNotNil(budgetRule)
    }

    // MARK: - Fallback Chain Tests

    func testFallbackChainNotEmpty() {
        let table = RoutingTable.default

        XCTAssertFalse(table.fallbackChain.isEmpty)
    }

    func testFallbackChainIncludesReliableEndpoints() {
        let table = RoutingTable.default

        // Should include at least one cloud endpoint (reliable)
        XCTAssertTrue(
            table.fallbackChain.contains("gpt-4o-mini") ||
            table.fallbackChain.contains("claude-3.5-haiku"),
            "Fallback should include reliable cloud endpoint"
        )

        // Should include on-device as last resort
        XCTAssertTrue(
            table.fallbackChain.contains("llama-1b-device") ||
            table.fallbackChain.contains("llama-3b-device"),
            "Fallback should include on-device endpoint"
        )
    }

    // MARK: - Codable Tests

    func testRoutingTableCodable() throws {
        var table = RoutingTable.default
        table.globalOverride = "test-endpoint"
        table.manualOverrides[.acknowledgment] = "llama-3b-device"

        let encoder = JSONEncoder()
        let data = try encoder.encode(table)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RoutingTable.self, from: data)

        XCTAssertEqual(decoded.globalOverride, "test-endpoint")
        XCTAssertEqual(decoded.manualOverrides[.acknowledgment], "llama-3b-device")
        XCTAssertFalse(decoded.defaultRoutes.isEmpty)
        XCTAssertFalse(decoded.autoRoutingRules.isEmpty)
        XCTAssertFalse(decoded.fallbackChain.isEmpty)
    }
}

/// Tests for AutoRoutingRule
final class AutoRoutingRuleTests: XCTestCase {

    func testAutoRoutingRuleCreation() {
        let rule = AutoRoutingRule(
            id: UUID(),
            name: "Test Rule",
            isEnabled: true,
            priority: 100,
            conditions: [.thermalState(.atLeast_serious)],
            conditionLogic: .all,
            targetEndpointId: "gpt-4o-mini",
            applyToTaskTypes: [.acknowledgment, .fillerResponse]
        )

        XCTAssertEqual(rule.name, "Test Rule")
        XCTAssertTrue(rule.isEnabled)
        XCTAssertEqual(rule.priority, 100)
        XCTAssertEqual(rule.conditions.count, 1)
        XCTAssertEqual(rule.conditionLogic, .all)
        XCTAssertEqual(rule.targetEndpointId, "gpt-4o-mini")
        XCTAssertEqual(rule.applyToTaskTypes?.count, 2)
    }

    func testAutoRoutingRuleAppliesTo() {
        let specificRule = AutoRoutingRule(
            id: UUID(),
            name: "Specific Rule",
            isEnabled: true,
            priority: 100,
            conditions: [],
            conditionLogic: .all,
            targetEndpointId: "test",
            applyToTaskTypes: [.acknowledgment]
        )

        XCTAssertTrue(specificRule.appliesTo(.acknowledgment))
        XCTAssertFalse(specificRule.appliesTo(.tutoringResponse))

        let universalRule = AutoRoutingRule(
            id: UUID(),
            name: "Universal Rule",
            isEnabled: true,
            priority: 100,
            conditions: [],
            conditionLogic: .all,
            targetEndpointId: "test",
            applyToTaskTypes: nil  // nil = applies to all
        )

        XCTAssertTrue(universalRule.appliesTo(.acknowledgment))
        XCTAssertTrue(universalRule.appliesTo(.tutoringResponse))
    }

    func testAutoRoutingRuleConditionLogicAll() {
        let rule = AutoRoutingRule(
            id: UUID(),
            name: "All Conditions",
            isEnabled: true,
            priority: 100,
            conditions: [
                .thermalState(.atLeast_serious),
                .batteryLevel(ComparisonCondition(comparison: .lessThan, value: 0.2))
            ],
            conditionLogic: .all,
            targetEndpointId: "test",
            applyToTaskTypes: nil
        )

        // Only thermal serious - should NOT match (need both)
        let thermalOnly = RoutingContext(thermalState: .serious, batteryLevel: 0.8)
        XCTAssertFalse(rule.matches(context: thermalOnly))

        // Only low battery - should NOT match
        let batteryOnly = RoutingContext(thermalState: .nominal, batteryLevel: 0.1)
        XCTAssertFalse(rule.matches(context: batteryOnly))

        // Both conditions met - should match
        let bothMet = RoutingContext(thermalState: .serious, batteryLevel: 0.1)
        XCTAssertTrue(rule.matches(context: bothMet))
    }

    func testAutoRoutingRuleConditionLogicAny() {
        let rule = AutoRoutingRule(
            id: UUID(),
            name: "Any Condition",
            isEnabled: true,
            priority: 100,
            conditions: [
                .thermalState(.atLeast_serious),
                .batteryLevel(ComparisonCondition(comparison: .lessThan, value: 0.2))
            ],
            conditionLogic: .any,
            targetEndpointId: "test",
            applyToTaskTypes: nil
        )

        // Only thermal serious - should match
        let thermalOnly = RoutingContext(thermalState: .serious, batteryLevel: 0.8)
        XCTAssertTrue(rule.matches(context: thermalOnly))

        // Only low battery - should match
        let batteryOnly = RoutingContext(thermalState: .nominal, batteryLevel: 0.1)
        XCTAssertTrue(rule.matches(context: batteryOnly))

        // Neither - should NOT match
        let neitherMet = RoutingContext(thermalState: .nominal, batteryLevel: 0.8)
        XCTAssertFalse(rule.matches(context: neitherMet))
    }

    func testAutoRoutingRuleDisabled() {
        let rule = AutoRoutingRule(
            id: UUID(),
            name: "Disabled Rule",
            isEnabled: false,
            priority: 100,
            conditions: [],  // Would match any context
            conditionLogic: .all,
            targetEndpointId: "test",
            applyToTaskTypes: nil
        )

        // Disabled rules should never match
        XCTAssertFalse(rule.shouldTrigger(for: .acknowledgment, context: RoutingContext()))
    }

    func testAutoRoutingRuleCodable() throws {
        let rule = AutoRoutingRule(
            id: UUID(),
            name: "Test Rule",
            isEnabled: true,
            priority: 50,
            conditions: [.thermalState(.atLeast_fair)],
            conditionLogic: .all,
            targetEndpointId: "gpt-4o-mini",
            applyToTaskTypes: [.acknowledgment]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(rule)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AutoRoutingRule.self, from: data)

        XCTAssertEqual(decoded.name, rule.name)
        XCTAssertEqual(decoded.isEnabled, rule.isEnabled)
        XCTAssertEqual(decoded.priority, rule.priority)
        XCTAssertEqual(decoded.targetEndpointId, rule.targetEndpointId)
        XCTAssertEqual(decoded.conditionLogic, rule.conditionLogic)
    }
}

/// Tests for ConditionLogic
final class ConditionLogicTests: XCTestCase {

    func testConditionLogicRawValues() {
        XCTAssertEqual(ConditionLogic.all.rawValue, "all")
        XCTAssertEqual(ConditionLogic.any.rawValue, "any")
    }

    func testConditionLogicCodable() throws {
        let logics: [ConditionLogic] = [.all, .any]

        let encoder = JSONEncoder()
        let data = try encoder.encode(logics)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([ConditionLogic].self, from: data)

        XCTAssertEqual(decoded, logics)
    }
}
