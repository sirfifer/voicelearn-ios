// UnaMentis - Routing Condition Tests
// Tests for condition types and evaluation logic
//
// Part of Patch Panel routing system

import XCTest
@testable import UnaMentis

/// Tests for RoutingCondition types
final class RoutingConditionTests: XCTestCase {

    // MARK: - Comparison Condition Tests

    func testComparisonConditionLessThan() {
        let condition = ComparisonCondition(comparison: .lessThan, value: 10.0)

        XCTAssertTrue(condition.evaluate(against: 5.0))
        XCTAssertTrue(condition.evaluate(against: 9.99))
        XCTAssertFalse(condition.evaluate(against: 10.0))
        XCTAssertFalse(condition.evaluate(against: 15.0))
    }

    func testComparisonConditionLessThanOrEqual() {
        let condition = ComparisonCondition(comparison: .lessThanOrEqual, value: 10.0)

        XCTAssertTrue(condition.evaluate(against: 5.0))
        XCTAssertTrue(condition.evaluate(against: 10.0))
        XCTAssertFalse(condition.evaluate(against: 10.01))
        XCTAssertFalse(condition.evaluate(against: 15.0))
    }

    func testComparisonConditionGreaterThan() {
        let condition = ComparisonCondition(comparison: .greaterThan, value: 10.0)

        XCTAssertFalse(condition.evaluate(against: 5.0))
        XCTAssertFalse(condition.evaluate(against: 10.0))
        XCTAssertTrue(condition.evaluate(against: 10.01))
        XCTAssertTrue(condition.evaluate(against: 15.0))
    }

    func testComparisonConditionGreaterThanOrEqual() {
        let condition = ComparisonCondition(comparison: .greaterThanOrEqual, value: 10.0)

        XCTAssertFalse(condition.evaluate(against: 5.0))
        XCTAssertTrue(condition.evaluate(against: 10.0))
        XCTAssertTrue(condition.evaluate(against: 15.0))
    }

    func testComparisonConditionEquals() {
        let condition = ComparisonCondition(comparison: .equals, value: 10.0)

        XCTAssertFalse(condition.evaluate(against: 9.99))
        XCTAssertTrue(condition.evaluate(against: 10.0))
        XCTAssertFalse(condition.evaluate(against: 10.01))
    }

    // MARK: - Thermal State Condition Tests

    func testThermalStateConditionExact() {
        let context = RoutingContext(thermalState: .fair)

        XCTAssertTrue(ThermalStateCondition.fair.matches(context.thermalState))
        XCTAssertFalse(ThermalStateCondition.nominal.matches(context.thermalState))
        XCTAssertFalse(ThermalStateCondition.serious.matches(context.thermalState))
    }

    func testThermalStateConditionAtLeastFair() {
        XCTAssertFalse(ThermalStateCondition.atLeast_fair.matches(.nominal))
        XCTAssertTrue(ThermalStateCondition.atLeast_fair.matches(.fair))
        XCTAssertTrue(ThermalStateCondition.atLeast_fair.matches(.serious))
        XCTAssertTrue(ThermalStateCondition.atLeast_fair.matches(.critical))
    }

    func testThermalStateConditionAtLeastSerious() {
        XCTAssertFalse(ThermalStateCondition.atLeast_serious.matches(.nominal))
        XCTAssertFalse(ThermalStateCondition.atLeast_serious.matches(.fair))
        XCTAssertTrue(ThermalStateCondition.atLeast_serious.matches(.serious))
        XCTAssertTrue(ThermalStateCondition.atLeast_serious.matches(.critical))
    }

    // MARK: - Memory Pressure Condition Tests

    func testMemoryPressureConditionExact() {
        XCTAssertTrue(MemoryPressureCondition.normal.matches(.normal))
        XCTAssertFalse(MemoryPressureCondition.normal.matches(.warning))
        XCTAssertFalse(MemoryPressureCondition.normal.matches(.critical))
    }

    func testMemoryPressureConditionAtLeastWarning() {
        XCTAssertFalse(MemoryPressureCondition.atLeast_warning.matches(.normal))
        XCTAssertTrue(MemoryPressureCondition.atLeast_warning.matches(.warning))
        XCTAssertTrue(MemoryPressureCondition.atLeast_warning.matches(.critical))
    }

    // MARK: - Network Type Condition Tests

    func testNetworkTypeConditionMatches() {
        XCTAssertTrue(NetworkTypeCondition.wifi.matches(.wifi))
        XCTAssertFalse(NetworkTypeCondition.wifi.matches(.cellular))
        XCTAssertFalse(NetworkTypeCondition.wifi.matches(.none))

        XCTAssertTrue(NetworkTypeCondition.cellular.matches(.cellular))
        XCTAssertFalse(NetworkTypeCondition.cellular.matches(.wifi))

        XCTAssertTrue(NetworkTypeCondition.none.matches(.none))
        XCTAssertFalse(NetworkTypeCondition.none.matches(.wifi))
    }

    func testNetworkTypeConditionAny() {
        XCTAssertTrue(NetworkTypeCondition.any.matches(.wifi))
        XCTAssertTrue(NetworkTypeCondition.any.matches(.cellular))
        XCTAssertTrue(NetworkTypeCondition.any.matches(.none))
    }

    // MARK: - Time Range Condition Tests

    func testTimeRangeContains() {
        let businessHours = TimeRange(startHour: 9, endHour: 17)

        XCTAssertFalse(businessHours.contains(hour: 8))
        XCTAssertTrue(businessHours.contains(hour: 9))
        XCTAssertTrue(businessHours.contains(hour: 12))
        XCTAssertTrue(businessHours.contains(hour: 16))
        XCTAssertFalse(businessHours.contains(hour: 17))
        XCTAssertFalse(businessHours.contains(hour: 20))
    }

    func testTimeRangeWrapsAroundMidnight() {
        let nightShift = TimeRange(startHour: 22, endHour: 6)

        XCTAssertFalse(nightShift.contains(hour: 12))
        XCTAssertFalse(nightShift.contains(hour: 21))
        XCTAssertTrue(nightShift.contains(hour: 22))
        XCTAssertTrue(nightShift.contains(hour: 23))
        XCTAssertTrue(nightShift.contains(hour: 0))
        XCTAssertTrue(nightShift.contains(hour: 3))
        XCTAssertTrue(nightShift.contains(hour: 5))
        XCTAssertFalse(nightShift.contains(hour: 6))
    }

    // MARK: - Routing Condition Evaluation Tests

    func testRoutingConditionThermalState() {
        let condition = RoutingCondition.thermalState(.atLeast_serious)

        let nominalContext = RoutingContext(thermalState: .nominal)
        let seriousContext = RoutingContext(thermalState: .serious)

        XCTAssertFalse(condition.evaluate(with: nominalContext))
        XCTAssertTrue(condition.evaluate(with: seriousContext))
    }

    func testRoutingConditionMemoryPressure() {
        let condition = RoutingCondition.memoryPressure(.atLeast_warning)

        let normalContext = RoutingContext(memoryPressure: .normal)
        let warningContext = RoutingContext(memoryPressure: .warning)

        XCTAssertFalse(condition.evaluate(with: normalContext))
        XCTAssertTrue(condition.evaluate(with: warningContext))
    }

    func testRoutingConditionBatteryLevel() {
        let condition = RoutingCondition.batteryLevel(
            ComparisonCondition(comparison: .lessThan, value: 0.2)
        )

        let highBattery = RoutingContext(batteryLevel: 0.8)
        let lowBattery = RoutingContext(batteryLevel: 0.15)

        XCTAssertFalse(condition.evaluate(with: highBattery))
        XCTAssertTrue(condition.evaluate(with: lowBattery))
    }

    func testRoutingConditionNetworkType() {
        let condition = RoutingCondition.networkType(.none)

        let wifiContext = RoutingContext(networkType: .wifi)
        let offlineContext = RoutingContext(networkType: .none)

        XCTAssertFalse(condition.evaluate(with: wifiContext))
        XCTAssertTrue(condition.evaluate(with: offlineContext))
    }

    func testRoutingConditionSessionCostBudget() {
        let condition = RoutingCondition.sessionCostBudget(
            ComparisonCondition(comparison: .lessThan, value: 0.10)
        )

        let highBudget = RoutingContext(remainingBudget: 0.50)
        let lowBudget = RoutingContext(remainingBudget: 0.05)

        XCTAssertFalse(condition.evaluate(with: highBudget))
        XCTAssertTrue(condition.evaluate(with: lowBudget))
    }

    func testRoutingConditionPromptLength() {
        let condition = RoutingCondition.promptLength(
            ComparisonCondition(comparison: .greaterThan, value: 1000)
        )

        let shortPrompt = RoutingContext(promptTokenCount: 500)
        let longPrompt = RoutingContext(promptTokenCount: 2000)

        XCTAssertFalse(condition.evaluate(with: shortPrompt))
        XCTAssertTrue(condition.evaluate(with: longPrompt))
    }

    // MARK: - Codable Tests

    func testComparisonConditionCodable() throws {
        let condition = ComparisonCondition(comparison: .lessThan, value: 10.0)

        let encoder = JSONEncoder()
        let data = try encoder.encode(condition)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ComparisonCondition.self, from: data)

        XCTAssertEqual(decoded.comparison, condition.comparison)
        XCTAssertEqual(decoded.value, condition.value)
    }

    func testRoutingConditionCodable() throws {
        let conditions: [RoutingCondition] = [
            .thermalState(.atLeast_serious),
            .memoryPressure(.warning),
            .batteryLevel(ComparisonCondition(comparison: .lessThan, value: 0.2)),
            .networkType(.wifi)
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(conditions)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([RoutingCondition].self, from: data)

        XCTAssertEqual(decoded.count, conditions.count)
    }

    func testTimeRangeCodable() throws {
        let range = TimeRange(startHour: 9, endHour: 17)

        let encoder = JSONEncoder()
        let data = try encoder.encode(range)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TimeRange.self, from: data)

        XCTAssertEqual(decoded.startHour, range.startHour)
        XCTAssertEqual(decoded.endHour, range.endHour)
    }
}

/// Tests for RoutingContext
final class RoutingContextTests: XCTestCase {

    func testRoutingContextCreation() {
        let context = RoutingContext(
            thermalState: .fair,
            memoryPressure: .normal,
            availableMemoryMB: 4000,
            batteryLevel: 0.8,
            isLowPowerMode: false,
            networkType: .wifi,
            networkLatencyMs: 50.0,
            remainingBudget: 1.0,
            sessionDurationSeconds: 300,
            promptTokenCount: 500,
            contextTokenCount: 2000
        )

        XCTAssertEqual(context.thermalState, .fair)
        XCTAssertEqual(context.memoryPressure, .normal)
        XCTAssertEqual(context.availableMemoryMB, 4000)
        XCTAssertEqual(context.batteryLevel, 0.8)
        XCTAssertFalse(context.isLowPowerMode)
        XCTAssertEqual(context.networkType, .wifi)
        XCTAssertEqual(context.networkLatencyMs, 50.0)
        XCTAssertEqual(context.remainingBudget, 1.0)
        XCTAssertEqual(context.sessionDurationSeconds, 300)
        XCTAssertEqual(context.promptTokenCount, 500)
        XCTAssertEqual(context.contextTokenCount, 2000)
    }

    func testRoutingContextDefaults() {
        let context = RoutingContext()

        XCTAssertEqual(context.thermalState, .nominal)
        XCTAssertEqual(context.memoryPressure, .normal)
        XCTAssertEqual(context.batteryLevel, 1.0)
        XCTAssertFalse(context.isLowPowerMode)
        XCTAssertEqual(context.networkType, .wifi)
    }
}
