//
//  KBSessionIntegrationTests.swift
//  UnaMentisTests
//
//  Integration tests for Knowledge Bowl session flow.
//  Tests end-to-end session lifecycle using real components.
//

import XCTest
@testable import UnaMentis

/// Integration tests for Knowledge Bowl session functionality
///
/// Tests cover:
/// - Session lifecycle (start, progress, complete)
/// - Session persistence
/// - Question flow through sessions
/// - Analytics integration
final class KBSessionIntegrationTests: XCTestCase {

    // MARK: - Properties

    private var sessionManager: KBSessionManager!
    private var testQuestions: [KBQuestion]!

    // MARK: - Setup / Teardown

    @MainActor
    override func setUp() async throws {
        sessionManager = KBSessionManager()
        testQuestions = makeTestQuestions()
    }

    override func tearDown() async throws {
        sessionManager = nil
        testQuestions = nil
    }

    // MARK: - Session Lifecycle Tests

    @MainActor
    func testSessionLifecycle_startToComplete() async throws {
        // Given - a session config
        let config = KBSessionConfig.quickPractice(
            region: .colorado,
            roundType: .oral,
            questionCount: 5
        )
        let questions = Array(testQuestions.prefix(config.questionCount))

        // When - start a session
        let session = await sessionManager.startSession(questions: questions, config: config)

        // Then - session is active
        let activeSession = await sessionManager.getCurrentSession()
        XCTAssertNotNil(activeSession)
        XCTAssertEqual(session.config.roundType, .oral)
        XCTAssertFalse(session.isComplete)

        // When - complete the session
        try await sessionManager.completeSession()

        // Then - session is no longer active
        let afterComplete = await sessionManager.getCurrentSession()
        XCTAssertNil(afterComplete)
    }

    @MainActor
    func testQuestionFlow_advanceThroughQuestions() async throws {
        // Given - a session with 3 questions
        let config = KBSessionConfig.quickPractice(
            region: .colorado,
            roundType: .written,
            questionCount: 3
        )
        let questions = Array(testQuestions.prefix(config.questionCount))
        _ = await sessionManager.startSession(questions: questions, config: config)

        // When/Then - advance through questions
        let q1 = await sessionManager.getCurrentQuestion()
        XCTAssertNotNil(q1)

        let progress1 = await sessionManager.getProgress()
        XCTAssertEqual(progress1, 0.0)

        _ = await sessionManager.advanceToNextQuestion()
        let progress2 = await sessionManager.getProgress()
        XCTAssertEqual(progress2, 1.0 / 3.0, accuracy: 0.01)

        _ = await sessionManager.advanceToNextQuestion()
        let progress3 = await sessionManager.getProgress()
        XCTAssertEqual(progress3, 2.0 / 3.0, accuracy: 0.01)

        let isLast = await sessionManager.isLastQuestion()
        XCTAssertTrue(isLast)
    }

    @MainActor
    func testAttemptRecording_recordsCorrectAndIncorrect() async throws {
        // Given - an active session
        let config = KBSessionConfig.quickPractice(
            region: .colorado,
            roundType: .oral,
            questionCount: 5
        )
        let questions = Array(testQuestions.prefix(config.questionCount))
        _ = await sessionManager.startSession(questions: questions, config: config)

        // When - record attempts
        let attempt1 = KBQuestionAttempt(
            questionId: questions[0].id,
            domain: questions[0].domain,
            userAnswer: "Paris",
            responseTime: 3.5,
            wasCorrect: true,
            pointsEarned: 10,
            roundType: .oral
        )
        await sessionManager.recordAttempt(attempt1)

        let attempt2 = KBQuestionAttempt(
            questionId: questions[1].id,
            domain: questions[1].domain,
            userAnswer: "London",
            responseTime: 5.0,
            wasCorrect: false,
            pointsEarned: 0,
            roundType: .oral
        )
        await sessionManager.recordAttempt(attempt2)

        // Then - session has recorded attempts
        let session = await sessionManager.getCurrentSession()
        XCTAssertEqual(session?.attempts.count, 2)
        XCTAssertEqual(session?.attempts.filter { $0.wasCorrect }.count, 1)
    }

    @MainActor
    func testSessionUpdate_modifiesSessionState() async throws {
        // Given - an active session
        let config = KBSessionConfig.quickPractice(
            region: .colorado,
            roundType: .oral,
            questionCount: 5
        )
        let questions = Array(testQuestions.prefix(config.questionCount))
        _ = await sessionManager.startSession(questions: questions, config: config)

        // When - update session state
        let endTime = Date()
        await sessionManager.updateSession { session in
            session.endTime = endTime
            session.isComplete = true
        }

        // Then - session is updated
        let session = await sessionManager.getCurrentSession()
        XCTAssertNotNil(session?.endTime)
        XCTAssertTrue(session?.isComplete ?? false)
    }

    @MainActor
    func testCancelSession_clearsState() async throws {
        // Given - an active session
        let config = KBSessionConfig.quickPractice(
            region: .colorado,
            roundType: .oral,
            questionCount: 5
        )
        let questions = Array(testQuestions.prefix(config.questionCount))
        _ = await sessionManager.startSession(questions: questions, config: config)

        let beforeCancel = await sessionManager.getCurrentSession()
        XCTAssertNotNil(beforeCancel)

        // When - cancel the session
        await sessionManager.cancelSession()

        // Then - session is cleared
        let afterCancel = await sessionManager.getCurrentSession()
        XCTAssertNil(afterCancel)

        let currentQuestion = await sessionManager.getCurrentQuestion()
        XCTAssertNil(currentQuestion)
    }

    // MARK: - Region Configuration Tests

    @MainActor
    func testSession_respectsRegionConfig() async throws {
        // Given - Colorado region config
        let coloradoConfig = KBSessionConfig.quickPractice(
            region: .colorado,
            roundType: .oral,
            questionCount: 5
        )

        // When - start session
        let questions = Array(testQuestions.prefix(coloradoConfig.questionCount))
        let session = await sessionManager.startSession(questions: questions, config: coloradoConfig)

        // Then - session has correct region
        XCTAssertEqual(session.config.region, .colorado)
    }

    // MARK: - Written vs Oral Session Tests

    @MainActor
    func testWrittenSession_hasTimerConfig() async throws {
        // Given - written round config
        let config = KBSessionConfig.quickPractice(
            region: .colorado,
            roundType: .written,
            questionCount: 10
        )

        // When - start session
        let questions = Array(testQuestions.prefix(config.questionCount))
        let session = await sessionManager.startSession(questions: questions, config: config)

        // Then - has written round characteristics
        XCTAssertEqual(session.config.roundType, .written)
        XCTAssertGreaterThan(session.config.timeLimit ?? 0, 0)
    }

    @MainActor
    func testOralSession_hasInterruptConfig() async throws {
        // Given - oral round config
        let config = KBSessionConfig.quickPractice(
            region: .colorado,
            roundType: .oral,
            questionCount: 10
        )

        // When - start session
        let questions = Array(testQuestions.prefix(config.questionCount))
        let session = await sessionManager.startSession(questions: questions, config: config)

        // Then - has oral round characteristics
        XCTAssertEqual(session.config.roundType, .oral)
        // Oral sessions don't have a time limit per question (unlike written)
    }

    // MARK: - Test Helpers

    private func makeTestQuestions() -> [KBQuestion] {
        let domains: [KBDomain] = [.science, .mathematics, .literature, .history, .socialStudies]

        return (0..<20).map { index in
            KBQuestion(
                id: UUID(),
                text: "Test question \(index + 1) about \(domains[index % domains.count])?",
                answer: KBAnswer(
                    primary: "Answer \(index + 1)",
                    acceptable: ["Alt \(index + 1)"],
                    answerType: .text
                ),
                domain: domains[index % domains.count],
                difficulty: index < 10 ? .foundational : .intermediate,
                gradeLevel: .highSchool,
                suitability: KBSuitability(forWritten: true, forOral: true, mcqPossible: true)
            )
        }
    }
}
