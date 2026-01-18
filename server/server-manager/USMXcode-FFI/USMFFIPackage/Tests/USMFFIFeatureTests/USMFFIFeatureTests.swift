import Foundation
import Testing
@testable import USMFFIFeature

// MARK: - ServiceStatus Tests

@Test func serviceStatusFromString() async throws {
    // Test all status string conversions
    #expect(ServiceStatus.from(string: "running") == .running)
    #expect(ServiceStatus.from(string: "stopped") == .stopped)
    #expect(ServiceStatus.from(string: "starting") == .starting)
    #expect(ServiceStatus.from(string: "stopping") == .stopping)
    #expect(ServiceStatus.from(string: "error") == .error)
    #expect(ServiceStatus.from(string: "unknown") == .unknown)

    // Test case insensitivity
    #expect(ServiceStatus.from(string: "RUNNING") == .running)
    #expect(ServiceStatus.from(string: "Running") == .running)

    // Test unknown values
    #expect(ServiceStatus.from(string: "invalid") == .unknown)
    #expect(ServiceStatus.from(string: "") == .unknown)
}

@Test func serviceStatusDisplayNames() async throws {
    #expect(ServiceStatus.running.displayName == "Running")
    #expect(ServiceStatus.stopped.displayName == "Stopped")
    #expect(ServiceStatus.starting.displayName == "Starting")
    #expect(ServiceStatus.stopping.displayName == "Stopping")
    #expect(ServiceStatus.error.displayName == "Error")
    #expect(ServiceStatus.unknown.displayName == "Unknown")
}

@Test func serviceStatusRawValues() async throws {
    // Verify raw values match expected integers
    #expect(ServiceStatus.stopped.rawValue == 0)
    #expect(ServiceStatus.running.rawValue == 1)
    #expect(ServiceStatus.error.rawValue == 2)
    #expect(ServiceStatus.starting.rawValue == 3)
    #expect(ServiceStatus.stopping.rawValue == 4)
    #expect(ServiceStatus.unknown.rawValue == 5)
}

// MARK: - ServiceInfo Tests

@Test func serviceInfoFormattedName() async throws {
    // Test formatted name when display name is empty
    let service1 = ServiceInfo(
        id: "management-api",
        templateId: "management-api",
        displayName: "",
        port: 8766,
        status: .running,
        cpuPercent: 0,
        memoryMB: 0
    )
    #expect(service1.formattedName == "Management Api")

    // Test formatted name when display name equals id
    let service2 = ServiceInfo(
        id: "log-server",
        templateId: "log-server",
        displayName: "log-server",
        port: 8765,
        status: .running,
        cpuPercent: 0,
        memoryMB: 0
    )
    #expect(service2.formattedName == "Log Server")

    // Test when display name is provided
    let service3 = ServiceInfo(
        id: "web-server-primary",
        templateId: "web-server",
        displayName: "Operations Console",
        port: 3000,
        status: .running,
        cpuPercent: 0,
        memoryMB: 0
    )
    #expect(service3.formattedName == "Operations Console")
}

@Test func serviceInfoCategoryInference() async throws {
    // Test development category (only feature-flags)
    let featureFlags = ServiceInfo(
        id: "feature-flags",
        templateId: "feature-flags",
        displayName: "Feature Flags",
        port: 3063,
        status: .stopped,
        cpuPercent: 0,
        memoryMB: 0
    )
    #expect(featureFlags.category == .development)

    // Test that log-server is NOT development (it's core)
    let logServer = ServiceInfo(
        id: "log-server",
        templateId: "log-server",
        displayName: "Log Server",
        port: 8765,
        status: .running,
        cpuPercent: 0,
        memoryMB: 0
    )
    #expect(logServer.category == .core)

    // Test database category
    let postgresql = ServiceInfo(
        id: "postgresql",
        templateId: "postgresql",
        displayName: "PostgreSQL",
        port: 5432,
        status: .running,
        cpuPercent: 0,
        memoryMB: 0
    )
    #expect(postgresql.category == .database)

    // Test core category (default)
    let managementApi = ServiceInfo(
        id: "management-api",
        templateId: "management-api",
        displayName: "Management API",
        port: 8766,
        status: .running,
        cpuPercent: 0,
        memoryMB: 0
    )
    #expect(managementApi.category == .core)
}

@Test func serviceInfoEquality() async throws {
    let service1 = ServiceInfo(
        id: "test",
        templateId: "test",
        displayName: "Test",
        port: 8000,
        status: .running,
        cpuPercent: 1.5,
        memoryMB: 100
    )

    let service2 = ServiceInfo(
        id: "test",
        templateId: "test",
        displayName: "Test",
        port: 8000,
        status: .running,
        cpuPercent: 1.5,
        memoryMB: 100
    )

    let service3 = ServiceInfo(
        id: "test",
        templateId: "test",
        displayName: "Test",
        port: 8000,
        status: .stopped,  // Different status
        cpuPercent: 1.5,
        memoryMB: 100
    )

    #expect(service1 == service2)
    #expect(service1 != service3)
}

// MARK: - ServiceCategory Tests

@Test func serviceCategoryDisplayNames() async throws {
    #expect(ServiceCategory.core.displayName == "Core")
    #expect(ServiceCategory.development.displayName == "Development")
    #expect(ServiceCategory.database.displayName == "Database")
    #expect(ServiceCategory.infrastructure.displayName == "Infrastructure")
    #expect(ServiceCategory.custom.displayName == "Custom")
}

// MARK: - ServiceEvent Decoding Tests

@Test func serviceEventStatusChangedDecoding() async throws {
    let json = """
    {
        "type": "status_changed",
        "instance_id": "management-api-primary",
        "status": "running",
        "pid": 12345
    }
    """

    let data = json.data(using: .utf8)!
    let event = try JSONDecoder().decode(ServiceEvent.self, from: data)

    if case .statusChanged(let instanceId, let status, let pid) = event {
        #expect(instanceId == "management-api-primary")
        #expect(status == .running)
        #expect(pid == 12345)
    } else {
        Issue.record("Expected statusChanged event")
    }
}

@Test func serviceEventMetricsUpdatedDecoding() async throws {
    let json = """
    {
        "type": "metrics_updated",
        "instance_id": "log-server",
        "cpu_percent": 2.5,
        "memory_mb": 64
    }
    """

    let data = json.data(using: .utf8)!
    let event = try JSONDecoder().decode(ServiceEvent.self, from: data)

    if case .metricsUpdated(let instanceId, let cpu, let mem) = event {
        #expect(instanceId == "log-server")
        #expect(cpu == 2.5)
        #expect(mem == 64)
    } else {
        Issue.record("Expected metricsUpdated event")
    }
}

@Test func serviceEventHealthChangedDecoding() async throws {
    let json = """
    {
        "type": "health_changed",
        "instance_id": "web-server",
        "healthy": true,
        "message": "Health check passed"
    }
    """

    let data = json.data(using: .utf8)!
    let event = try JSONDecoder().decode(ServiceEvent.self, from: data)

    if case .healthChanged(let instanceId, let healthy, let message) = event {
        #expect(instanceId == "web-server")
        #expect(healthy == true)
        #expect(message == "Health check passed")
    } else {
        Issue.record("Expected healthChanged event")
    }
}

@Test func serviceEventInstanceCreatedDecoding() async throws {
    let json = """
    {
        "type": "instance_created",
        "instance_id": "new-service",
        "template_id": "custom-template"
    }
    """

    let data = json.data(using: .utf8)!
    let event = try JSONDecoder().decode(ServiceEvent.self, from: data)

    if case .instanceCreated(let instanceId, let templateId) = event {
        #expect(instanceId == "new-service")
        #expect(templateId == "custom-template")
    } else {
        Issue.record("Expected instanceCreated event")
    }
}

@Test func serviceEventInstanceRemovedDecoding() async throws {
    let json = """
    {
        "type": "instance_removed",
        "instance_id": "removed-service"
    }
    """

    let data = json.data(using: .utf8)!
    let event = try JSONDecoder().decode(ServiceEvent.self, from: data)

    if case .instanceRemoved(let instanceId) = event {
        #expect(instanceId == "removed-service")
    } else {
        Issue.record("Expected instanceRemoved event")
    }
}

@Test func serviceEventErrorDecoding() async throws {
    let json = """
    {
        "type": "error",
        "instance_id": "failed-service",
        "message": "Failed to start service"
    }
    """

    let data = json.data(using: .utf8)!
    let event = try JSONDecoder().decode(ServiceEvent.self, from: data)

    if case .error(let instanceId, let message) = event {
        #expect(instanceId == "failed-service")
        #expect(message == "Failed to start service")
    } else {
        Issue.record("Expected error event")
    }
}

@Test func serviceEventConfigReloadedDecoding() async throws {
    let json = """
    {
        "type": "config_reloaded"
    }
    """

    let data = json.data(using: .utf8)!
    let event = try JSONDecoder().decode(ServiceEvent.self, from: data)

    if case .configReloaded = event {
        // Success
    } else {
        Issue.record("Expected configReloaded event")
    }
}

@Test func serviceEventUnknownTypeThrows() async throws {
    let json = """
    {
        "type": "unknown_event_type",
        "instance_id": "test"
    }
    """

    let data = json.data(using: .utf8)!

    do {
        _ = try JSONDecoder().decode(ServiceEvent.self, from: data)
        Issue.record("Expected decoding to fail for unknown event type")
    } catch {
        // Expected to throw
    }
}
