//
//  KBSessionStore.swift
//  UnaMentis
//
//  Local session persistence for Knowledge Bowl
//  On-device storage using JSON files
//

import Foundation

// MARK: - Session Store

/// On-device storage for Knowledge Bowl practice sessions
actor KBSessionStore {
    // MARK: - Storage Location

    private let fileManager = FileManager.default
    private var sessionsDirectory: URL {
        get throws {
            let documents = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let kbDir = documents.appendingPathComponent("KnowledgeBowl/Sessions", isDirectory: true)

            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: kbDir.path) {
                try fileManager.createDirectory(at: kbDir, withIntermediateDirectories: true)
            }

            return kbDir
        }
    }

    // MARK: - Save Operations

    /// Save a completed session
    func save(_ session: KBSession) async throws {
        let directory = try sessionsDirectory
        let filename = "\(session.id.uuidString).json"
        let fileURL = directory.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(session)
        try data.write(to: fileURL, options: [.atomic])
    }

    /// Save multiple sessions
    func saveBatch(_ sessions: [KBSession]) async throws {
        for session in sessions {
            try await save(session)
        }
    }

    // MARK: - Load Operations

    /// Load a specific session by ID
    func load(id: UUID) async throws -> KBSession? {
        let directory = try sessionsDirectory
        let filename = "\(id.uuidString).json"
        let fileURL = directory.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(KBSession.self, from: data)
    }

    /// Load all sessions
    func loadAll() async throws -> [KBSession] {
        let directory = try sessionsDirectory
        let files = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var sessions: [KBSession] = []
        for fileURL in files where fileURL.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: fileURL)
                let session = try decoder.decode(KBSession.self, from: data)
                sessions.append(session)
            } catch {
                print("[KBSessionStore] Failed to load session from \(fileURL.lastPathComponent): \(error)")
                // Continue loading other sessions
            }
        }

        return sessions
    }

    /// Load recent sessions (sorted by completion date)
    func loadRecent(limit: Int = 10) async throws -> [KBSession] {
        let allSessions = try await loadAll()
        return allSessions
            .filter { $0.isComplete }
            .sorted { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    /// Load sessions for a specific region
    func loadSessions(for region: KBRegion) async throws -> [KBSession] {
        let allSessions = try await loadAll()
        return allSessions.filter { $0.config.region == region }
    }

    /// Load sessions for a specific round type
    func loadSessions(for roundType: KBRoundType) async throws -> [KBSession] {
        let allSessions = try await loadAll()
        return allSessions.filter { $0.config.roundType == roundType }
    }

    // MARK: - Delete Operations

    /// Delete a specific session
    func delete(id: UUID) async throws {
        let directory = try sessionsDirectory
        let filename = "\(id.uuidString).json"
        let fileURL = directory.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    /// Delete sessions older than specified days
    func deleteOlderThan(days: Int) async throws -> Int {
        let allSessions = try await loadAll()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        var deletedCount = 0
        for session in allSessions {
            guard let endTime = session.endTime else { continue }
            if endTime < cutoffDate {
                try await delete(id: session.id)
                deletedCount += 1
            }
        }

        return deletedCount
    }

    /// Delete all sessions (use with caution)
    func deleteAll() async throws {
        let allSessions = try await loadAll()
        for session in allSessions {
            try await delete(id: session.id)
        }
    }

    // MARK: - Statistics

    /// Calculate aggregate statistics across all sessions
    func calculateStatistics() async throws -> KBStatistics {
        let sessions = try await loadAll().filter { $0.isComplete }

        guard !sessions.isEmpty else {
            return KBStatistics()
        }

        let totalSessions = sessions.count
        let totalQuestions = sessions.reduce(0) { $0 + $1.attempts.count }
        let totalCorrect = sessions.reduce(0) { $0 + $1.correctCount }
        let totalIncorrect = sessions.reduce(0) { $0 + $1.incorrectCount }
        let overallAccuracy = totalQuestions > 0 ? Double(totalCorrect) / Double(totalQuestions) : 0

        // Breakdown by round type
        let writtenSessions = sessions.filter { $0.config.roundType == .written }
        let oralSessions = sessions.filter { $0.config.roundType == .oral }

        let writtenQuestions = writtenSessions.reduce(0) { $0 + $1.attempts.count }
        let writtenCorrect = writtenSessions.reduce(0) { $0 + $1.correctCount }
        let writtenAccuracy = writtenQuestions > 0 ? Double(writtenCorrect) / Double(writtenQuestions) : 0

        let oralQuestions = oralSessions.reduce(0) { $0 + $1.attempts.count }
        let oralCorrect = oralSessions.reduce(0) { $0 + $1.correctCount }
        let oralAccuracy = oralQuestions > 0 ? Double(oralCorrect) / Double(oralQuestions) : 0

        // Most recent session
        let mostRecentSession = sessions
            .sorted { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) }
            .first

        return KBStatistics(
            totalSessions: totalSessions,
            totalQuestions: totalQuestions,
            totalCorrect: totalCorrect,
            totalIncorrect: totalIncorrect,
            overallAccuracy: overallAccuracy,
            writtenAccuracy: writtenAccuracy,
            oralAccuracy: oralAccuracy,
            mostRecentSessionDate: mostRecentSession?.endTime,
            currentStreak: calculateStreak(sessions: sessions)
        )
    }

    /// Calculate current streak (consecutive days with at least one session)
    private func calculateStreak(sessions: [KBSession]) -> Int {
        guard !sessions.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get unique days with sessions
        let sessionDays = Set(sessions.compactMap { session -> Date? in
            guard let endTime = session.endTime else { return nil }
            return calendar.startOfDay(for: endTime)
        }).sorted(by: >)  // Most recent first

        guard let mostRecent = sessionDays.first else { return 0 }

        // Check if streak is still active (session today or yesterday)
        let daysSinceLastSession = calendar.dateComponents([.day], from: mostRecent, to: today).day ?? 0
        if daysSinceLastSession > 1 {
            return 0  // Streak broken
        }

        // Count consecutive days
        var streak = 0
        var currentDate = mostRecent

        for sessionDay in sessionDays {
            let daysDiff = calendar.dateComponents([.day], from: sessionDay, to: currentDate).day ?? 0
            if daysDiff <= 1 {  // Same day or next consecutive day
                streak += 1
                currentDate = sessionDay
            } else {
                break  // Streak broken
            }
        }

        return streak
    }
}

// MARK: - Statistics Model

/// Aggregate statistics across all Knowledge Bowl sessions
struct KBStatistics: Codable {
    var totalSessions: Int = 0
    var totalQuestions: Int = 0
    var totalCorrect: Int = 0
    var totalIncorrect: Int = 0
    var overallAccuracy: Double = 0
    var writtenAccuracy: Double = 0
    var oralAccuracy: Double = 0
    var mostRecentSessionDate: Date?
    var currentStreak: Int = 0
}
