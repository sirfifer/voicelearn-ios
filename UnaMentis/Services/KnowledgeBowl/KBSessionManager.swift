//
//  KBSessionManager.swift
//  UnaMentis
//
//  Session lifecycle management for Knowledge Bowl
//  Extracted from view models for better separation of concerns
//

import Foundation

// MARK: - Session Manager

/// Manages Knowledge Bowl session lifecycle, persistence, and question flow
actor KBSessionManager {
    // MARK: - Properties

    private let store = KBSessionStore()
    private var activeSession: KBSession?
    private var questions: [KBQuestion] = []
    private var currentQuestionIndex = 0

    // MARK: - Session Lifecycle

    /// Start a new practice session
    func startSession(questions: [KBQuestion], config: KBSessionConfig) -> KBSession {
        let session = KBSession(config: config)
        self.activeSession = session
        self.questions = questions
        self.currentQuestionIndex = 0
        return session
    }

    /// Get the current active session
    func getCurrentSession() -> KBSession? {
        activeSession
    }

    /// Complete the current session and save it
    func completeSession() async throws {
        guard var session = activeSession else {
            throw KBSessionError.noActiveSession
        }

        session.endTime = Date()
        session.isComplete = true

        // Save to persistent storage
        try await store.save(session)
        print("[KB] Session completed and saved: \(session.id)")

        activeSession = nil
    }

    /// Cancel the current session without saving
    func cancelSession() {
        activeSession = nil
        questions = []
        currentQuestionIndex = 0
    }

    // MARK: - Question Flow

    /// Get the current question in the session
    func getCurrentQuestion() -> KBQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    /// Move to the next question
    /// - Returns: The next question, or nil if no more questions
    func advanceToNextQuestion() -> KBQuestion? {
        currentQuestionIndex += 1
        return getCurrentQuestion()
    }

    /// Check if this is the last question
    func isLastQuestion() -> Bool {
        currentQuestionIndex >= questions.count - 1
    }

    /// Get current progress (0.0 to 1.0)
    func getProgress() -> Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentQuestionIndex) / Double(questions.count)
    }

    // MARK: - Answer Recording

    /// Record a question attempt
    func recordAttempt(_ attempt: KBQuestionAttempt) async {
        guard var session = activeSession else { return }
        session.attempts.append(attempt)
        session.currentQuestionIndex = currentQuestionIndex
        activeSession = session
    }

    /// Update session state
    func updateSession(_ updater: @Sendable (inout KBSession) -> Void) async {
        guard var session = activeSession else { return }
        updater(&session)
        activeSession = session
    }

    // MARK: - Session Queries

    /// Load recent sessions from storage
    func loadRecentSessions(limit: Int = 10) async throws -> [KBSession] {
        try await store.loadRecent(limit: limit)
    }

    /// Calculate aggregate statistics
    func calculateStatistics() async throws -> KBStatistics {
        try await store.calculateStatistics()
    }

    /// Load sessions for a specific region
    func loadSessions(for region: KBRegion) async throws -> [KBSession] {
        try await store.loadSessions(for: region)
    }

    /// Load sessions for a specific round type
    func loadSessions(for roundType: KBRoundType) async throws -> [KBSession] {
        try await store.loadSessions(for: roundType)
    }

    // MARK: - Session Data Management

    /// Delete old sessions
    func deleteOldSessions(olderThanDays days: Int) async throws -> Int {
        try await store.deleteOlderThan(days: days)
    }

    /// Delete all sessions (use with caution)
    func deleteAllSessions() async throws {
        try await store.deleteAll()
    }
}

// MARK: - KB Session Error

enum KBSessionError: Error, LocalizedError {
    case noActiveSession
    case sessionAlreadyComplete
    case invalidQuestionIndex

    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active session"
        case .sessionAlreadyComplete:
            return "Session is already complete"
        case .invalidQuestionIndex:
            return "Invalid question index"
        }
    }
}

// MARK: - Session Manager Extensions

extension KBSessionManager {
    /// Create a quick practice session with default settings
    @MainActor
    static func createQuickPractice(
        engine: KBQuestionEngine,
        region: KBRegion,
        roundType: KBRoundType,
        questionCount: Int
    ) async -> (manager: KBSessionManager, session: KBSession, questions: [KBQuestion]) {
        let config = KBSessionConfig.quickPractice(
            region: region,
            roundType: roundType,
            questionCount: questionCount
        )
        let questions = engine.selectForSession(config: config)
        let manager = KBSessionManager()
        let session = await manager.startSession(questions: questions, config: config)
        return (manager, session, questions)
    }
}
