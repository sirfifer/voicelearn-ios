//
//  KBLocalTeamSyncTests.swift
//  UnaMentisTests
//
//  Tests for KBLocalTeamSync - local sync implementation for team data.
//

import XCTest
@testable import UnaMentis

@MainActor
final class KBLocalTeamSyncTests: XCTestCase {

    private var store: KBTeamStore!
    private var sync: KBLocalTeamSync!

    override func setUp() async throws {
        store = KBTeamStore()
        sync = KBLocalTeamSync(store: store)
        try await store.deleteAllData()
    }

    override func tearDown() async throws {
        try await store.deleteAllData()
    }

    // MARK: - Protocol Properties Tests

    func testSyncMode_isLocal() async {
        let mode = await sync.syncMode
        XCTAssertEqual(mode, .local)
    }

    func testIsConnected_alwaysTrue() async {
        let connected = await sync.isConnected
        XCTAssertTrue(connected)
    }

    func testStatus_initialValues() async {
        let status = await sync.status
        // Initial status uses .offline mode from KBTeamSyncStatus.initial
        // The syncMode property returns .local separately
        XCTAssertEqual(status.mode, .offline)
        XCTAssertFalse(status.isSyncing)
    }

    // MARK: - Team Operations Tests

    func testFetchTeam_returnsNilWhenNoTeam() async throws {
        let team = try await sync.fetchTeam()
        XCTAssertNil(team)
    }

    func testSaveTeam_persistsTeam() async throws {
        let team = createTestTeam()
        try await sync.saveTeam(team)

        let fetched = try await sync.fetchTeam()
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, team.name)
    }

    func testSaveTeam_updatesLastUpdatedAt() async throws {
        // Create a team with a known past date
        var team = createTestTeam()
        let pastDate = Date(timeIntervalSince1970: 1000) // Jan 1, 1970 + 1000 seconds
        team.lastUpdatedAt = pastDate

        try await sync.saveTeam(team)

        let fetched = try await sync.fetchTeam()
        XCTAssertNotNil(fetched)
        // saveTeam sets lastUpdatedAt to Date() which should be way after our past date
        XCTAssertGreaterThan(
            fetched?.lastUpdatedAt ?? Date.distantPast,
            pastDate
        )
    }

    func testDeleteTeam_removesTeam() async throws {
        let team = createTestTeam()
        try await sync.saveTeam(team)

        let teamBefore = try await sync.fetchTeam()
        XCTAssertNotNil(teamBefore)

        try await sync.deleteTeam()

        let teamAfter = try await sync.fetchTeam()
        XCTAssertNil(teamAfter)
    }

    // MARK: - Member Operations Tests

    func testFetchMembers_returnsEmptyWhenNoTeam() async throws {
        let members = try await sync.fetchMembers()
        XCTAssertTrue(members.isEmpty)
    }

    func testAddMember_addsToTeam() async throws {
        let team = createTestTeam()
        try await sync.saveTeam(team)

        let member = KBTeamMember(name: "New Member")
        try await sync.addMember(member)

        let members = try await sync.fetchMembers()
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members.first?.name, "New Member")
    }

    func testAddMember_throwsWhenNoTeam() async throws {
        let member = KBTeamMember(name: "New Member")

        do {
            try await sync.addMember(member)
            XCTFail("Expected error to be thrown")
        } catch let error as KBTeamSyncError {
            switch error {
            case .noTeam:
                break // Expected
            default:
                XCTFail("Expected noTeam error")
            }
        }
    }

    func testUpdateMember_updatesExistingMember() async throws {
        let team = createTestTeam()
        try await sync.saveTeam(team)

        var member = KBTeamMember(name: "Original Name")
        try await sync.addMember(member)

        member.name = "Updated Name"
        member.primaryDomain = .science
        try await sync.updateMember(member)

        let members = try await sync.fetchMembers()
        XCTAssertEqual(members.first?.name, "Updated Name")
        XCTAssertEqual(members.first?.primaryDomain, .science)
    }

    func testDeleteMember_removesMember() async throws {
        let team = createTestTeam()
        try await sync.saveTeam(team)

        let member = KBTeamMember(name: "To Delete")
        try await sync.addMember(member)

        let membersBefore = try await sync.fetchMembers()
        XCTAssertEqual(membersBefore.count, 1)

        try await sync.deleteMember(id: member.id)

        let membersAfter = try await sync.fetchMembers()
        XCTAssertTrue(membersAfter.isEmpty)
    }

    func testDeleteMember_alsoDeletesStats() async throws {
        let team = createTestTeam()
        try await sync.saveTeam(team)

        let member = KBTeamMember(name: "Member with Stats")
        try await sync.addMember(member)

        let stats = createTestStats(memberId: member.id)
        try await sync.pushStats(stats)

        let statsBefore = try await sync.fetchStats(memberId: member.id)
        XCTAssertNotNil(statsBefore)

        try await sync.deleteMember(id: member.id)

        let statsAfter = try await sync.fetchStats(memberId: member.id)
        XCTAssertNil(statsAfter)
    }

    // MARK: - Stats Operations Tests

    func testFetchStats_returnsNilForNonexistent() async throws {
        let stats = try await sync.fetchStats(memberId: UUID())
        XCTAssertNil(stats)
    }

    func testPushStats_savesNewStats() async throws {
        let memberId = UUID()
        let stats = createTestStats(memberId: memberId)

        try await sync.pushStats(stats)

        let fetched = try await sync.fetchStats(memberId: memberId)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.totalSessions, stats.totalSessions)
    }

    func testPushStats_mergesWithExistingStats() async throws {
        let memberId = UUID()

        // Push initial stats
        var stats1 = createTestStats(memberId: memberId)
        stats1.totalSessions = 5
        stats1.domainStats["science"] = KBDomainStats(
            accuracy: 0.8,
            avgResponseTime: 2.0,
            questionCount: 20,
            masteryLevel: .intermediate
        )
        try await sync.pushStats(stats1)

        // Push updated stats
        var stats2 = KBMemberStats(memberId: memberId)
        stats2.totalSessions = 8
        stats2.domainStats["science"] = KBDomainStats(
            accuracy: 0.9,
            avgResponseTime: 1.5,
            questionCount: 30,
            masteryLevel: .proficient
        )
        try await sync.pushStats(stats2)

        // Should have merged stats
        let fetched = try await sync.fetchStats(memberId: memberId)
        XCTAssertNotNil(fetched)
        // Higher question count wins in merge
        XCTAssertEqual(fetched?.domainStats["science"]?.questionCount, 30)
    }

    func testFetchAllStats_returnsAllStats() async throws {
        let stats1 = createTestStats(memberId: UUID())
        let stats2 = createTestStats(memberId: UUID())

        try await sync.pushStats(stats1)
        try await sync.pushStats(stats2)

        let allStats = try await sync.fetchAllStats()
        XCTAssertEqual(allStats.count, 2)
    }

    // MARK: - Assignment Operations Tests

    func testFetchAssignments_returnsEmptyWhenNoTeam() async throws {
        let assignments = try await sync.fetchAssignments()
        XCTAssertTrue(assignments.isEmpty)
    }

    func testFetchAssignments_returnsTeamAssignments() async throws {
        var team = createTestTeam()
        let member = KBTeamMember(name: "Assigned Member")
        team.addMember(member)
        team.setAssignment(KBDomainAssignment.primary(memberId: member.id, domain: .science))
        try await sync.saveTeam(team)

        let assignments = try await sync.fetchAssignments()
        XCTAssertEqual(assignments.count, 1)
        XCTAssertEqual(assignments.first?.domain, .science)
    }

    func testUpdateAssignments_replacesAllAssignments() async throws {
        var team = createTestTeam()
        let member = KBTeamMember(name: "Member")
        team.addMember(member)
        try await sync.saveTeam(team)

        let newAssignments = [
            KBDomainAssignment.primary(memberId: member.id, domain: .mathematics),
            KBDomainAssignment.secondary(memberId: member.id, domain: .history)
        ]
        try await sync.updateAssignments(newAssignments)

        let fetched = try await sync.fetchAssignments()
        XCTAssertEqual(fetched.count, 2)
    }

    func testFetchSuggestions_returnsEmptyWhenNoTeam() async throws {
        let suggestions = try await sync.fetchSuggestions()
        XCTAssertTrue(suggestions.isEmpty)
    }

    func testFetchSuggestions_generatesSuggestionsBasedOnStats() async throws {
        var team = createTestTeam()
        let member = KBTeamMember(name: "Strong Science")
        team.addMember(member)
        try await sync.saveTeam(team)

        // Create stats with strong science performance
        var stats = KBMemberStats(memberId: member.id)
        stats.domainStats["science"] = KBDomainStats(
            accuracy: 0.85,
            avgResponseTime: 2.0,
            questionCount: 25,
            masteryLevel: .proficient
        )
        try await sync.pushStats(stats)

        let suggestions = try await sync.fetchSuggestions()
        // Should suggest science as primary since accuracy > 70%
        let scienceSuggestion = suggestions.first { $0.domain == .science }
        XCTAssertNotNil(scienceSuggestion)
        XCTAssertEqual(scienceSuggestion?.suggestedType, .primary)
    }

    // MARK: - Sync Control Tests

    func testSyncNow_updatesStatus() async throws {
        let team = createTestTeam()
        try await sync.saveTeam(team)

        try await sync.syncNow()

        let status = await sync.status
        XCTAssertNotNil(status.lastSyncTime)
        XCTAssertFalse(status.isSyncing)
    }

    func testStartAutoSync_doesNotCrash() async throws {
        // Just verify it doesn't crash/throw
        await sync.startAutoSync(interval: 60)
        await sync.stopAutoSync()
    }

    // MARK: - Event Handler Tests

    func testAddEventHandler_canReceiveEvents() async throws {
        let handler = MockEventHandler()
        await sync.addEventHandler(handler)

        let team = createTestTeam()
        try await sync.saveTeam(team)

        // Small delay for event propagation
        try await Task.sleep(for: .milliseconds(50))

        let count = await handler.eventCount
        XCTAssertGreaterThan(count, 0)
    }

    func testRemoveEventHandler_stopsReceivingEvents() async throws {
        let handler = MockEventHandler()
        await sync.addEventHandler(handler)
        await sync.removeEventHandler(handler)

        let team = createTestTeam()
        try await sync.saveTeam(team)

        try await Task.sleep(for: .milliseconds(50))

        // Handler should have been removed and not receive events
        let count = await handler.eventCount
        XCTAssertLessThanOrEqual(count, 1)
    }

    // MARK: - Helper Methods

    private func createTestTeam(name: String = "Test Team") -> KBTeamProfile {
        KBTeamProfile(
            name: name,
            region: .colorado,
            isCaptain: true
        )
    }

    private func createTestStats(
        memberId: UUID,
        sessions: Int = 5
    ) -> KBMemberStats {
        var stats = KBMemberStats(memberId: memberId)
        stats.totalSessions = sessions
        stats.totalQuestions = sessions * 10
        stats.lastPracticeDate = Date()
        return stats
    }
}

// MARK: - Mock Event Handler

private actor MockEventHandler: KBTeamSyncEventHandler {
    private(set) var receivedEvents: [KBTeamSyncEvent] = []

    var eventCount: Int {
        receivedEvents.count
    }

    func handleSyncEvent(_ event: KBTeamSyncEvent) async {
        receivedEvents.append(event)
    }
}

// MARK: - Error Tests

final class KBTeamSyncErrorTests: XCTestCase {

    func testNoTeam_errorDescription() {
        let error = KBTeamSyncError.noTeam
        XCTAssertEqual(error.errorDescription, "No team exists. Create a team first.")
    }

    func testMemberNotFound_errorDescription() {
        let id = UUID()
        let error = KBTeamSyncError.memberNotFound(id)
        XCTAssertEqual(error.errorDescription, "Member with ID \(id) not found")
    }

    func testSyncFailed_errorDescription() {
        let error = KBTeamSyncError.syncFailed(reason: "Network error")
        XCTAssertEqual(error.errorDescription, "Sync failed: Network error")
    }

    func testError_isLocalizedError() {
        let error: LocalizedError = KBTeamSyncError.noTeam
        XCTAssertNotNil(error.errorDescription)
    }
}

// MARK: - KBTeamSyncMode Tests

final class KBTeamSyncModeTests: XCTestCase {

    func testDisplayName_server() {
        let mode = KBTeamSyncMode.server(baseURL: URL(string: "https://example.com")!)
        XCTAssertEqual(mode.displayName, "Server")
    }

    func testDisplayName_local() {
        XCTAssertEqual(KBTeamSyncMode.local.displayName, "Local")
    }

    func testDisplayName_offline() {
        XCTAssertEqual(KBTeamSyncMode.offline.displayName, "Offline")
    }

    func testIsConnected_serverIsTrue() {
        let mode = KBTeamSyncMode.server(baseURL: URL(string: "https://example.com")!)
        XCTAssertTrue(mode.isConnected)
    }

    func testIsConnected_localIsTrue() {
        XCTAssertTrue(KBTeamSyncMode.local.isConnected)
    }

    func testIsConnected_offlineIsFalse() {
        XCTAssertFalse(KBTeamSyncMode.offline.isConnected)
    }
}

// MARK: - KBTeamSyncStatus Tests

final class KBTeamSyncStatusTests: XCTestCase {

    func testInitial_hasCorrectDefaults() {
        let status = KBTeamSyncStatus.initial
        XCTAssertEqual(status.mode, .offline)
        XCTAssertFalse(status.isSyncing)
        XCTAssertNil(status.lastSyncTime)
        XCTAssertEqual(status.pendingChanges, 0)
        XCTAssertNil(status.lastError)
    }
}
