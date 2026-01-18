// UnaMentis - Knowledge Bowl Question Tests
// Tests for KBQuestion model, KBQuestionResult, and KBSessionSummary
//
// Part of Knowledge Bowl Module Testing

import XCTest
@testable import UnaMentis

final class KBQuestionTests: XCTestCase {

    // MARK: - Test Data

    private func makeQuestion(
        id: String = "test-1",
        domainId: String = "science",
        questionText: String = "What is the speed of light?",
        answerText: String = "299,792,458 m/s",
        acceptableAnswers: [String] = ["299792458", "300000000", "speed of light"],
        difficulty: Int = 3,
        speedTargetSeconds: Double = 5.0
    ) -> KBQuestion {
        KBQuestion(
            id: id,
            domainId: domainId,
            subcategory: "Physics",
            questionText: questionText,
            answerText: answerText,
            acceptableAnswers: acceptableAnswers,
            difficulty: difficulty,
            speedTargetSeconds: speedTargetSeconds,
            questionType: "toss-up",
            hints: ["Think about relativity"],
            explanation: "The speed of light is a fundamental constant."
        )
    }

    // MARK: - KBQuestion Tests

    func testQuestion_isCorrect_withExactMatch() {
        let question = makeQuestion(acceptableAnswers: ["paris", "Paris"])

        XCTAssertTrue(question.isCorrect(answer: "paris"))
        XCTAssertTrue(question.isCorrect(answer: "Paris"))
    }

    func testQuestion_isCorrect_withCaseInsensitivity() {
        let question = makeQuestion(acceptableAnswers: ["Paris"])

        XCTAssertTrue(question.isCorrect(answer: "paris"))
        XCTAssertTrue(question.isCorrect(answer: "PARIS"))
        XCTAssertTrue(question.isCorrect(answer: "PaRiS"))
    }

    func testQuestion_isCorrect_trimsWhitespace() {
        let question = makeQuestion(acceptableAnswers: ["Paris"])

        XCTAssertTrue(question.isCorrect(answer: "  Paris  "))
        XCTAssertTrue(question.isCorrect(answer: "\nParis\n"))
        XCTAssertTrue(question.isCorrect(answer: "Paris "))
    }

    func testQuestion_isCorrect_returnsFalseForIncorrectAnswer() {
        let question = makeQuestion(acceptableAnswers: ["Paris"])

        XCTAssertFalse(question.isCorrect(answer: "London"))
        XCTAssertFalse(question.isCorrect(answer: ""))
        XCTAssertFalse(question.isCorrect(answer: "Par"))
    }

    func testQuestion_isCorrect_matchesAnyAcceptableAnswer() {
        let question = makeQuestion(acceptableAnswers: ["George Washington", "Washington", "G. Washington"])

        XCTAssertTrue(question.isCorrect(answer: "George Washington"))
        XCTAssertTrue(question.isCorrect(answer: "Washington"))
        XCTAssertTrue(question.isCorrect(answer: "G. Washington"))
    }

    func testQuestion_identifiable_hasUniqueId() {
        let question1 = makeQuestion(id: "q1")
        let question2 = makeQuestion(id: "q2")

        XCTAssertEqual(question1.id, "q1")
        XCTAssertEqual(question2.id, "q2")
        XCTAssertNotEqual(question1.id, question2.id)
    }

    func testQuestion_hashable_equalQuestionsHaveSameHash() {
        let question1 = makeQuestion(id: "q1", domainId: "science")
        let question2 = makeQuestion(id: "q1", domainId: "science")

        XCTAssertEqual(question1.hashValue, question2.hashValue)
    }

    func testQuestion_codable_encodeAndDecode() throws {
        let question = makeQuestion()

        let encoder = JSONEncoder()
        let data = try encoder.encode(question)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(KBQuestion.self, from: data)

        XCTAssertEqual(decoded.id, question.id)
        XCTAssertEqual(decoded.domainId, question.domainId)
        XCTAssertEqual(decoded.questionText, question.questionText)
        XCTAssertEqual(decoded.acceptableAnswers, question.acceptableAnswers)
    }

    func testQuestion_codable_decodesSnakeCaseKeys() throws {
        let json = """
        {
            "id": "test-123",
            "domain_id": "mathematics",
            "subcategory": "Algebra",
            "question_text": "What is 2+2?",
            "answer_text": "4",
            "acceptable_answers": ["4", "four"],
            "difficulty": 1,
            "speed_target_seconds": 3.0,
            "question_type": "toss-up",
            "hints": [],
            "explanation": "Basic arithmetic"
        }
        """

        let decoder = JSONDecoder()
        let question = try decoder.decode(KBQuestion.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(question.id, "test-123")
        XCTAssertEqual(question.domainId, "mathematics")
        XCTAssertEqual(question.questionText, "What is 2+2?")
        XCTAssertEqual(question.speedTargetSeconds, 3.0)
    }

    // MARK: - KBQuestionResult Tests

    func testQuestionResult_correctAnswer_setsIsCorrectTrue() {
        let question = makeQuestion(acceptableAnswers: ["Paris"])
        let result = KBQuestionResult(
            question: question,
            userAnswer: "Paris",
            responseTimeSeconds: 2.0
        )

        XCTAssertTrue(result.isCorrect)
        XCTAssertFalse(result.wasSkipped)
    }

    func testQuestionResult_incorrectAnswer_setsIsCorrectFalse() {
        let question = makeQuestion(acceptableAnswers: ["Paris"])
        let result = KBQuestionResult(
            question: question,
            userAnswer: "London",
            responseTimeSeconds: 2.0
        )

        XCTAssertFalse(result.isCorrect)
    }

    func testQuestionResult_withinSpeedTarget_setsWasWithinSpeedTargetTrue() {
        let question = makeQuestion(acceptableAnswers: ["Paris"], speedTargetSeconds: 5.0)
        let result = KBQuestionResult(
            question: question,
            userAnswer: "Paris",
            responseTimeSeconds: 3.0
        )

        XCTAssertTrue(result.wasWithinSpeedTarget)
    }

    func testQuestionResult_exceedsSpeedTarget_setsWasWithinSpeedTargetFalse() {
        let question = makeQuestion(acceptableAnswers: ["Paris"], speedTargetSeconds: 5.0)
        let result = KBQuestionResult(
            question: question,
            userAnswer: "Paris",
            responseTimeSeconds: 7.0
        )

        XCTAssertFalse(result.wasWithinSpeedTarget)
    }

    func testQuestionResult_skipped_setsCorrectAndSpeedTargetFalse() {
        let question = makeQuestion(acceptableAnswers: ["Paris"])
        let result = KBQuestionResult(
            question: question,
            userAnswer: "",
            responseTimeSeconds: 0,
            wasSkipped: true
        )

        XCTAssertTrue(result.wasSkipped)
        XCTAssertFalse(result.isCorrect)
        XCTAssertFalse(result.wasWithinSpeedTarget)
    }

    func testQuestionResult_hasUniqueId() {
        let question = makeQuestion()
        let result1 = KBQuestionResult(question: question, userAnswer: "test", responseTimeSeconds: 1.0)
        let result2 = KBQuestionResult(question: question, userAnswer: "test", responseTimeSeconds: 1.0)

        XCTAssertNotEqual(result1.id, result2.id)
    }

    // MARK: - KBSessionSummary Tests

    func testSessionSummary_accuracy_calculatesCorrectly() {
        let summary = KBSessionSummary(
            totalQuestions: 10,
            correctAnswers: 7,
            averageResponseTime: 3.5,
            questionsWithinSpeedTarget: 8,
            domainBreakdown: [:],
            duration: 120
        )

        XCTAssertEqual(summary.accuracy, 0.7, accuracy: 0.001)
    }

    func testSessionSummary_accuracy_returnsZeroForNoQuestions() {
        let summary = KBSessionSummary(
            totalQuestions: 0,
            correctAnswers: 0,
            averageResponseTime: 0,
            questionsWithinSpeedTarget: 0,
            domainBreakdown: [:],
            duration: 0
        )

        XCTAssertEqual(summary.accuracy, 0)
    }

    func testSessionSummary_speedTargetRate_calculatesCorrectly() {
        let summary = KBSessionSummary(
            totalQuestions: 10,
            correctAnswers: 5,
            averageResponseTime: 4.0,
            questionsWithinSpeedTarget: 6,
            domainBreakdown: [:],
            duration: 180
        )

        XCTAssertEqual(summary.speedTargetRate, 0.6, accuracy: 0.001)
    }

    func testSessionSummary_speedTargetRate_returnsZeroForNoQuestions() {
        let summary = KBSessionSummary(
            totalQuestions: 0,
            correctAnswers: 0,
            averageResponseTime: 0,
            questionsWithinSpeedTarget: 0,
            domainBreakdown: [:],
            duration: 0
        )

        XCTAssertEqual(summary.speedTargetRate, 0)
    }

    func testSessionSummary_domainScore_accuracy() {
        let domainScore = KBSessionSummary.DomainScore(total: 5, correct: 4)

        XCTAssertEqual(domainScore.accuracy, 0.8, accuracy: 0.001)
    }

    func testSessionSummary_domainScore_accuracyZeroForNoQuestions() {
        let domainScore = KBSessionSummary.DomainScore(total: 0, correct: 0)

        XCTAssertEqual(domainScore.accuracy, 0)
    }
}
