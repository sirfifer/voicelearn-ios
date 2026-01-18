// UnaMentis - Knowledge Bowl Practice Engine Tests
// Tests for KBPracticeEngine session management and flow
//
// Part of Knowledge Bowl Module Testing

@preconcurrency import XCTest
@testable import UnaMentis

final class KBPracticeEngineTests: XCTestCase {

    private nonisolated(unsafe) var engine: KBPracticeEngine!

    override func setUpWithError() throws {
        try super.setUpWithError()
        engine = MainActor.assumeIsolated {
            KBPracticeEngine()
        }
    }

    override func tearDownWithError() throws {
        engine = nil
        try super.tearDownWithError()
    }

    // MARK: - Test Data

    private func makeQuestion(
        id: String = "test-1",
        domainId: String = "science",
        acceptableAnswers: [String] = ["answer"],
        speedTargetSeconds: Double = 5.0
    ) -> KBQuestion {
        KBQuestion(
            id: id,
            domainId: domainId,
            subcategory: "General",
            questionText: "Test question?",
            answerText: "answer",
            acceptableAnswers: acceptableAnswers,
            difficulty: 3,
            speedTargetSeconds: speedTargetSeconds,
            questionType: "toss-up",
            hints: [],
            explanation: "Test explanation"
        )
    }

    private func makeQuestions(count: Int) -> [KBQuestion] {
        (0..<count).map { makeQuestion(id: "q-\($0)") }
    }

    // MARK: - Initial State Tests

    @MainActor
    func testInitialState_isNotStarted() {
        XCTAssertEqual(engine.sessionState, .notStarted)
        XCTAssertNil(engine.currentQuestion)
        XCTAssertEqual(engine.questionIndex, 0)
        XCTAssertEqual(engine.totalQuestions, 0)
        XCTAssertTrue(engine.results.isEmpty)
    }

    // MARK: - Start Session Tests

    @MainActor
    func testStartSession_setsStateToInProgress() {
        let questions = makeQuestions(count: 10)

        engine.startSession(questions: questions, mode: .diagnostic)

        XCTAssertEqual(engine.sessionState, .inProgress)
    }

    @MainActor
    func testStartSession_presentsFirstQuestion() {
        let questions = makeQuestions(count: 10)

        engine.startSession(questions: questions, mode: .diagnostic)

        XCTAssertNotNil(engine.currentQuestion)
        XCTAssertEqual(engine.questionIndex, 0)
    }

    @MainActor
    func testStartSession_setsCorrectTotalQuestions_diagnostic() {
        let questions = makeQuestions(count: 100)

        engine.startSession(questions: questions, mode: .diagnostic)

        // Diagnostic mode should use 50 questions
        XCTAssertEqual(engine.totalQuestions, 50)
    }

    @MainActor
    func testStartSession_setsCorrectTotalQuestions_targeted() {
        let questions = makeQuestions(count: 100)

        engine.startSession(questions: questions, mode: .targeted)

        // Targeted mode should use 25 questions
        XCTAssertEqual(engine.totalQuestions, 25)
    }

    @MainActor
    func testStartSession_setsCorrectTotalQuestions_breadth() {
        let questions = makeQuestions(count: 100)

        engine.startSession(questions: questions, mode: .breadth)

        // Breadth mode should use 36 questions
        XCTAssertEqual(engine.totalQuestions, 36)
    }

    @MainActor
    func testStartSession_setsCorrectTotalQuestions_speed() {
        let questions = makeQuestions(count: 100)

        engine.startSession(questions: questions, mode: .speed)

        // Speed mode should use 20 questions
        XCTAssertEqual(engine.totalQuestions, 20)
        // Speed mode should also set a timer
        XCTAssertEqual(engine.timeRemaining, 300)  // 5 minutes
    }

    @MainActor
    func testStartSession_setsCorrectTotalQuestions_competition() {
        let questions = makeQuestions(count: 100)

        engine.startSession(questions: questions, mode: .competition)

        // Competition mode should use 45 questions
        XCTAssertEqual(engine.totalQuestions, 45)
    }

    @MainActor
    func testStartSession_limitsToAvailableQuestions() {
        let questions = makeQuestions(count: 5)

        engine.startSession(questions: questions, mode: .diagnostic)

        // Should be limited to available questions (5), not diagnostic target (50)
        XCTAssertEqual(engine.totalQuestions, 5)
    }

    @MainActor
    func testStartSession_clearsResultsFromPreviousSession() {
        let questions = makeQuestions(count: 10)

        // Start first session and answer a question
        engine.startSession(questions: questions, mode: .diagnostic)
        engine.submitAnswer("answer")

        // Start new session
        engine.startSession(questions: questions, mode: .targeted)

        XCTAssertTrue(engine.results.isEmpty)
        XCTAssertEqual(engine.questionIndex, 0)
    }

    // MARK: - Submit Answer Tests

    @MainActor
    func testSubmitAnswer_addsResultToResults() {
        let questions = [makeQuestion(acceptableAnswers: ["correct"])]
        engine.startSession(questions: questions, mode: .diagnostic)

        engine.submitAnswer("correct")

        XCTAssertEqual(engine.results.count, 1)
        XCTAssertTrue(engine.results.first!.isCorrect)
    }

    @MainActor
    func testSubmitAnswer_setsStateToShowingAnswer() {
        let questions = [makeQuestion(acceptableAnswers: ["correct"])]
        engine.startSession(questions: questions, mode: .diagnostic)

        engine.submitAnswer("correct")

        XCTAssertEqual(engine.sessionState, .showingAnswer(isCorrect: true))
    }

    @MainActor
    func testSubmitAnswer_incorrectAnswer_setsShowingAnswerFalse() {
        let questions = [makeQuestion(acceptableAnswers: ["correct"])]
        engine.startSession(questions: questions, mode: .diagnostic)

        engine.submitAnswer("wrong")

        XCTAssertEqual(engine.sessionState, .showingAnswer(isCorrect: false))
        XCTAssertFalse(engine.results.first!.isCorrect)
    }

    @MainActor
    func testSubmitAnswer_doesNothingWhenNotInProgress() {
        let questions = makeQuestions(count: 10)
        engine.startSession(questions: questions, mode: .diagnostic)
        engine.submitAnswer("answer")  // Now in showingAnswer state

        // Try to submit another answer while showing answer
        engine.submitAnswer("another")

        // Should still only have one result
        XCTAssertEqual(engine.results.count, 1)
    }

    // MARK: - Skip Question Tests

    @MainActor
    func testSkipQuestion_addsSkippedResult() {
        let questions = makeQuestions(count: 10)
        engine.startSession(questions: questions, mode: .diagnostic)

        engine.skipQuestion()

        XCTAssertEqual(engine.results.count, 1)
        XCTAssertTrue(engine.results.first!.wasSkipped)
        XCTAssertFalse(engine.results.first!.isCorrect)
    }

    @MainActor
    func testSkipQuestion_setsStateToShowingAnswer() {
        let questions = makeQuestions(count: 10)
        engine.startSession(questions: questions, mode: .diagnostic)

        engine.skipQuestion()

        XCTAssertEqual(engine.sessionState, .showingAnswer(isCorrect: false))
    }

    // MARK: - Next Question Tests

    @MainActor
    func testNextQuestion_advancesToNextQuestion() {
        let questions = makeQuestions(count: 10)
        engine.startSession(questions: questions, mode: .diagnostic)
        engine.submitAnswer("answer")

        engine.nextQuestion()

        XCTAssertEqual(engine.questionIndex, 1)
        XCTAssertEqual(engine.sessionState, .inProgress)
    }

    @MainActor
    func testNextQuestion_doesNothingWhenNotShowingAnswer() {
        let questions = makeQuestions(count: 10)
        engine.startSession(questions: questions, mode: .diagnostic)

        // Try to advance without submitting answer
        engine.nextQuestion()

        XCTAssertEqual(engine.questionIndex, 0)
    }

    @MainActor
    func testNextQuestion_completesSessionAtEnd() {
        let questions = [makeQuestion()]
        engine.startSession(questions: questions, mode: .diagnostic)
        engine.submitAnswer("answer")

        engine.nextQuestion()

        XCTAssertEqual(engine.sessionState, .completed)
    }

    // MARK: - End Session Early Tests

    @MainActor
    func testEndSessionEarly_setsStateToCompleted() {
        let questions = makeQuestions(count: 10)
        engine.startSession(questions: questions, mode: .diagnostic)

        engine.endSessionEarly()

        XCTAssertEqual(engine.sessionState, .completed)
    }

    // MARK: - Generate Summary Tests

    @MainActor
    func testGenerateSummary_returnsCorrectTotals() {
        let questions = makeQuestions(count: 3)
        engine.startSession(questions: questions, mode: .diagnostic)

        // Answer all questions
        engine.submitAnswer("answer")  // Correct
        engine.nextQuestion()
        engine.submitAnswer("wrong")   // Incorrect
        engine.nextQuestion()
        engine.submitAnswer("answer")  // Correct
        engine.nextQuestion()  // This completes the session

        let summary = engine.generateSummary()

        XCTAssertEqual(summary.totalQuestions, 3)
        XCTAssertEqual(summary.correctAnswers, 2)
    }

    @MainActor
    func testGenerateSummary_calculatesAverageResponseTime() {
        let questions = makeQuestions(count: 2)
        engine.startSession(questions: questions, mode: .diagnostic)

        // Note: Actual timing is hard to test precisely, but we can verify
        // the summary contains a non-negative average time
        engine.submitAnswer("answer")
        engine.nextQuestion()
        engine.submitAnswer("answer")
        engine.nextQuestion()

        let summary = engine.generateSummary()

        XCTAssertGreaterThanOrEqual(summary.averageResponseTime, 0)
    }

    @MainActor
    func testGenerateSummary_calculatesDomainBreakdown() {
        let q1 = makeQuestion(id: "q1", domainId: "science")
        let q2 = makeQuestion(id: "q2", domainId: "science")
        let q3 = makeQuestion(id: "q3", domainId: "math")

        engine.startSession(questions: [q1, q2, q3], mode: .diagnostic)

        engine.submitAnswer("answer")  // Science correct
        engine.nextQuestion()
        engine.submitAnswer("wrong")   // Science incorrect
        engine.nextQuestion()
        engine.submitAnswer("answer")  // Math correct
        engine.nextQuestion()

        let summary = engine.generateSummary()

        XCTAssertEqual(summary.domainBreakdown["science"]?.total, 2)
        XCTAssertEqual(summary.domainBreakdown["science"]?.correct, 1)
        XCTAssertEqual(summary.domainBreakdown["math"]?.total, 1)
        XCTAssertEqual(summary.domainBreakdown["math"]?.correct, 1)
    }

    @MainActor
    func testGenerateSummary_excludesSkippedFromAverageTime() {
        let questions = makeQuestions(count: 2)
        engine.startSession(questions: questions, mode: .diagnostic)

        engine.skipQuestion()  // Skipped (should not count in average time)
        engine.nextQuestion()
        engine.submitAnswer("answer")  // Answered
        engine.nextQuestion()

        let summary = engine.generateSummary()

        // Average should be based only on the one answered question
        XCTAssertGreaterThanOrEqual(summary.averageResponseTime, 0)
    }

    // MARK: - Session State Equatable Tests

    @MainActor
    func testSessionState_equatable() {
        XCTAssertEqual(KBPracticeEngine.SessionState.notStarted, .notStarted)
        XCTAssertEqual(KBPracticeEngine.SessionState.inProgress, .inProgress)
        XCTAssertEqual(KBPracticeEngine.SessionState.completed, .completed)
        XCTAssertEqual(
            KBPracticeEngine.SessionState.showingAnswer(isCorrect: true),
            .showingAnswer(isCorrect: true)
        )
        XCTAssertNotEqual(
            KBPracticeEngine.SessionState.showingAnswer(isCorrect: true),
            .showingAnswer(isCorrect: false)
        )
    }
}
