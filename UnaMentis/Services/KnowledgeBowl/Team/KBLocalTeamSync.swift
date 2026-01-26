//
//  KBLocalTeamSync.swift
//  UnaMentis
//
//  Local sync implementation for Knowledge Bowl teams
//  Captain's device is source of truth, supports P2P when together
//

import Foundation

// MARK: - Local Team Sync

/// Local sync provider for teams without server access
/// Captain's device serves as the source of truth
actor KBLocalTeamSync: KBTeamSyncProvider {
    // MARK: - Dependencies

    private let store: KBTeamStore
    private var eventHandlers: [WeakEventHandler] = []
    private var autoSyncTask: Task<Void, Never>?

    // MARK: - State

    private var _status: KBTeamSyncStatus = .initial
    private var cachedTeam: KBTeamProfile?

    // MARK: - Initialization

    init(store: KBTeamStore) {
        self.store = store
    }

    // MARK: - Protocol Properties

    var status: KBTeamSyncStatus {
        _status
    }

    var syncMode: KBTeamSyncMode {
        .local
    }

    var isConnected: Bool {
        true  // Local sync is always "connected"
    }

    // MARK: - Team Operations

    func fetchTeam() async throws -> KBTeamProfile? {
        let team = try await store.loadProfile()
        cachedTeam = team
        return team
    }

    func saveTeam(_ team: KBTeamProfile) async throws {
        var updatedTeam = team
        updatedTeam.lastUpdatedAt = Date()

        try await store.saveProfile(updatedTeam)
        cachedTeam = updatedTeam

        await notifyHandlers(.teamUpdated(updatedTeam))
        await updateStatus(lastSyncTime: Date())
    }

    func deleteTeam() async throws {
        try await store.deleteProfile()
        cachedTeam = nil

        await updateStatus(lastSyncTime: Date())
    }

    // MARK: - Member Operations

    func fetchMembers() async throws -> [KBTeamMember] {
        guard let team = try await fetchTeam() else {
            return []
        }
        return team.members
    }

    func addMember(_ member: KBTeamMember) async throws {
        guard var team = try await fetchTeam() else {
            throw KBTeamSyncError.noTeam
        }

        team.addMember(member)
        try await saveTeam(team)

        await notifyHandlers(.memberUpdated(member))
    }

    func updateMember(_ member: KBTeamMember) async throws {
        guard var team = try await fetchTeam() else {
            throw KBTeamSyncError.noTeam
        }

        team.updateMember(member)
        try await saveTeam(team)

        await notifyHandlers(.memberUpdated(member))
    }

    func deleteMember(id: UUID) async throws {
        guard var team = try await fetchTeam() else {
            throw KBTeamSyncError.noTeam
        }

        team.removeMember(id: id)
        try await saveTeam(team)

        // Also delete the member's stats
        try await store.deleteStats(memberId: id)

        await notifyHandlers(.memberRemoved(id))
    }

    // MARK: - Stats Operations

    func fetchStats(memberId: UUID) async throws -> KBMemberStats? {
        try await store.loadStats(memberId: memberId)
    }

    func fetchAllStats() async throws -> [KBMemberStats] {
        try await store.loadAllStats()
    }

    func pushStats(_ stats: KBMemberStats) async throws {
        // Check if we have existing stats to merge
        if let existingStats = try await store.loadStats(memberId: stats.memberId) {
            var merged = existingStats
            merged.merge(with: stats)
            try await store.saveStats(merged)
            await notifyHandlers(.statsUpdated(merged))
        } else {
            try await store.saveStats(stats)
            await notifyHandlers(.statsUpdated(stats))
        }

        await updateStatus(lastSyncTime: Date())
    }

    // MARK: - Assignment Operations

    func fetchAssignments() async throws -> [KBDomainAssignment] {
        guard let team = try await fetchTeam() else {
            return []
        }
        return team.domainAssignments
    }

    func updateAssignments(_ assignments: [KBDomainAssignment]) async throws {
        guard var team = try await fetchTeam() else {
            throw KBTeamSyncError.noTeam
        }

        // Replace all assignments
        team.domainAssignments = assignments
        team.lastUpdatedAt = Date()

        try await saveTeam(team)

        await notifyHandlers(.assignmentsUpdated(assignments))
    }

    func fetchSuggestions() async throws -> [KBAssignmentSuggestion] {
        guard let team = try await fetchTeam() else {
            return []
        }

        let allStats = try await fetchAllStats()
        return generateSuggestions(team: team, stats: allStats)
    }

    // MARK: - Sync Control

    func syncNow() async throws {
        // In local mode, just ensure data is persisted
        await updateStatus(isSyncing: true)

        // Re-save to ensure persistence
        if let team = cachedTeam {
            try await store.saveProfile(team)
        }

        await updateStatus(isSyncing: false, lastSyncTime: Date())
    }

    func startAutoSync(interval: TimeInterval) async {
        stopAutoSyncInternal()

        autoSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                try? await self?.syncNow()
            }
        }
    }

    func stopAutoSync() async {
        stopAutoSyncInternal()
    }

    private func stopAutoSyncInternal() {
        autoSyncTask?.cancel()
        autoSyncTask = nil
    }

    // MARK: - Event Handling

    func addEventHandler(_ handler: KBTeamSyncEventHandler) {
        eventHandlers.append(WeakEventHandler(handler))
        cleanupHandlers()
    }

    func removeEventHandler(_ handler: KBTeamSyncEventHandler) {
        eventHandlers.removeAll { $0.handler === handler }
    }

    private func notifyHandlers(_ event: KBTeamSyncEvent) async {
        cleanupHandlers()
        for weak in eventHandlers {
            await weak.handler?.handleSyncEvent(event)
        }
    }

    private func cleanupHandlers() {
        eventHandlers.removeAll { $0.handler == nil }
    }

    // MARK: - Status Updates

    private func updateStatus(
        isSyncing: Bool? = nil,
        lastSyncTime: Date? = nil,
        pendingChanges: Int? = nil,
        lastError: String? = nil
    ) async {
        _status = KBTeamSyncStatus(
            mode: .local,
            isSyncing: isSyncing ?? _status.isSyncing,
            lastSyncTime: lastSyncTime ?? _status.lastSyncTime,
            pendingChanges: pendingChanges ?? _status.pendingChanges,
            lastError: lastError
        )

        await notifyHandlers(.statusChanged(_status))
    }

    // MARK: - Suggestion Generation

    private func generateSuggestions(
        team: KBTeamProfile,
        stats: [KBMemberStats]
    ) -> [KBAssignmentSuggestion] {
        var suggestions: [KBAssignmentSuggestion] = []
        let statsById = Dictionary(uniqueKeysWithValues: stats.map { ($0.memberId, $0) })

        for member in team.activeMembers {
            guard let memberStats = statsById[member.id] else { continue }

            // Get strongest domains for this member
            let strongDomains = memberStats.strongestDomains

            // Suggest primary assignment for strongest domain
            if let (strongestDomain, domainStats) = strongDomains.first {
                // Only suggest if not already assigned
                let isAlreadyPrimary = team.primaryAssignee(for: strongestDomain)?.id == member.id
                if !isAlreadyPrimary && domainStats.accuracy >= 0.7 {
                    suggestions.append(KBAssignmentSuggestion(
                        memberId: member.id,
                        memberName: member.name,
                        domain: strongestDomain,
                        suggestedType: .primary,
                        confidence: domainStats.accuracy,
                        reasoning: "Highest accuracy (\(Int(domainStats.accuracy * 100))%) among practiced domains"
                    ))
                }
            }

            // Suggest secondary for second strongest
            if strongDomains.count >= 2 {
                let (secondDomain, secondStats) = strongDomains[1]
                let isAlreadyAssigned = member.primaryDomain == secondDomain ||
                    member.secondaryDomain == secondDomain
                if !isAlreadyAssigned && secondStats.accuracy >= 0.6 {
                    suggestions.append(KBAssignmentSuggestion(
                        memberId: member.id,
                        memberName: member.name,
                        domain: secondDomain,
                        suggestedType: .secondary,
                        confidence: secondStats.accuracy,
                        reasoning: "Second highest accuracy (\(Int(secondStats.accuracy * 100))%)"
                    ))
                }
            }
        }

        // Also suggest coverage for uncovered domains
        let uncoveredDomains = team.uncoveredDomains
        for domain in uncoveredDomains {
            // Find the member with best performance in this domain
            var bestMember: (member: KBTeamMember, accuracy: Double)?

            for member in team.activeMembers {
                if let memberStats = statsById[member.id],
                   let domainStats = memberStats.stats(for: domain) {
                    if bestMember == nil || domainStats.accuracy > bestMember!.accuracy {
                        bestMember = (member, domainStats.accuracy)
                    }
                }
            }

            if let (member, accuracy) = bestMember, accuracy >= 0.5 {
                suggestions.append(KBAssignmentSuggestion(
                    memberId: member.id,
                    memberName: member.name,
                    domain: domain,
                    suggestedType: .primary,
                    confidence: accuracy,
                    reasoning: "\(domain.displayName) needs coverage, \(member.name) has \(Int(accuracy * 100))% accuracy"
                ))
            }
        }

        return suggestions
    }
}

// MARK: - Weak Event Handler Wrapper

private final class WeakEventHandler: @unchecked Sendable {
    weak var handler: (any KBTeamSyncEventHandler)?

    init(_ handler: KBTeamSyncEventHandler) {
        self.handler = handler
    }
}

// MARK: - Errors

enum KBTeamSyncError: LocalizedError {
    case noTeam
    case memberNotFound(UUID)
    case syncFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .noTeam:
            return "No team exists. Create a team first."
        case .memberNotFound(let id):
            return "Member with ID \(id) not found"
        case .syncFailed(let reason):
            return "Sync failed: \(reason)"
        }
    }
}
