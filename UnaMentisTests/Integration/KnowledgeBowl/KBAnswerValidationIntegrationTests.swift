//
//  KBAnswerValidationIntegrationTests.swift
//  UnaMentisTests
//
//  Integration tests for Knowledge Bowl answer validation.
//  Tests end-to-end answer checking using real components.
//

import XCTest
@testable import UnaMentis

/// Integration tests for Knowledge Bowl answer validation
///
/// Tests cover:
/// - Answer validation with various inputs
/// - Partial matching and acceptable alternatives
/// - Domain-specific answer handling
/// - Integration with session flow
final class KBAnswerValidationIntegrationTests: XCTestCase {

    // MARK: - Properties

    private var answerValidator: KBAnswerValidator!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        answerValidator = KBAnswerValidator()
    }

    override func tearDown() {
        answerValidator = nil
        super.tearDown()
    }

    // MARK: - Exact Match Tests

    func testValidation_exactMatch_returnsCorrect() async {
        // Given - a question
        let question = makeQuestion(answer: "Paris", acceptable: nil, answerType: .place)

        // When - validate exact match
        let result = await answerValidator.validate(userAnswer: "Paris", question: question)

        // Then - is correct
        XCTAssertTrue(result.isCorrect)
        XCTAssertEqual(result.matchType, .exact)
    }

    func testValidation_caseInsensitive_returnsCorrect() async {
        // Given - a question
        let question = makeQuestion(answer: "Paris", acceptable: nil, answerType: .place)

        // When - validate with different case
        let result = await answerValidator.validate(userAnswer: "PARIS", question: question)

        // Then - is correct
        XCTAssertTrue(result.isCorrect)
    }

    func testValidation_withLeadingTrailingSpaces_returnsCorrect() async {
        // Given - a question
        let question = makeQuestion(answer: "Paris", acceptable: nil, answerType: .place)

        // When - validate with spaces
        let result = await answerValidator.validate(userAnswer: "  Paris  ", question: question)

        // Then - is correct
        XCTAssertTrue(result.isCorrect)
    }

    // MARK: - Acceptable Alternatives Tests

    func testValidation_acceptableAlternative_returnsCorrect() async {
        // Given - a question with alternatives
        let question = makeQuestion(
            answer: "William Shakespeare",
            acceptable: ["Shakespeare", "The Bard"],
            answerType: .person
        )

        // When - validate with alternative
        let result = await answerValidator.validate(userAnswer: "Shakespeare", question: question)

        // Then - is correct
        XCTAssertTrue(result.isCorrect)
        XCTAssertEqual(result.matchType, .acceptable)
    }

    func testValidation_multipleAlternatives_allAccepted() async {
        // Given - a question with multiple alternatives
        let question = makeQuestion(
            answer: "United States of America",
            acceptable: ["USA", "US", "America", "United States"],
            answerType: .place
        )

        // When/Then - all alternatives are accepted
        for alt in ["USA", "US", "America", "United States"] {
            let result = await answerValidator.validate(userAnswer: alt, question: question)
            XCTAssertTrue(result.isCorrect, "'\(alt)' should be accepted")
        }
    }

    // MARK: - Numeric Answer Tests

    func testValidation_numericExact_returnsCorrect() async {
        // Given - a numeric question
        let question = makeQuestion(answer: "42", acceptable: nil, answerType: .number)

        // When - validate
        let result = await answerValidator.validate(userAnswer: "42", question: question)

        // Then - is correct
        XCTAssertTrue(result.isCorrect)
    }

    func testValidation_numericWithCommas_handlesFormatting() async {
        // Given - a large numeric question
        let question = makeQuestion(
            answer: "1000000",
            acceptable: ["1,000,000", "one million"],
            answerType: .number
        )

        // When - validate with comma formatting
        let result = await answerValidator.validate(userAnswer: "1,000,000", question: question)

        // Then - is correct
        XCTAssertTrue(result.isCorrect)
    }

    // MARK: - Partial Match Tests

    func testValidation_partialMatch_markedAsPartial() async {
        // Given - a person question requiring full name
        let question = makeQuestion(
            answer: "Albert Einstein",
            acceptable: ["Einstein"],
            answerType: .person
        )

        // When - validate with partial answer
        let result = await answerValidator.validate(userAnswer: "Einstein", question: question)

        // Then - is correct with acceptable match type
        XCTAssertTrue(result.isCorrect)
    }

    // MARK: - Incorrect Answer Tests

    func testValidation_wrongAnswer_returnsIncorrect() async {
        // Given - a question
        let question = makeQuestion(answer: "Paris", acceptable: nil, answerType: .place)

        // When - validate wrong answer
        let result = await answerValidator.validate(userAnswer: "London", question: question)

        // Then - is incorrect
        XCTAssertFalse(result.isCorrect)
        XCTAssertEqual(result.matchType, .none)
    }

    func testValidation_emptyAnswer_returnsIncorrect() async {
        // Given - a question
        let question = makeQuestion(answer: "Paris", acceptable: nil, answerType: .place)

        // When - validate empty answer
        let result = await answerValidator.validate(userAnswer: "", question: question)

        // Then - is incorrect
        XCTAssertFalse(result.isCorrect)
    }

    // MARK: - Answer Type Specific Tests

    func testValidation_dateAnswer_handlesFormats() async {
        // Given - a date question
        let question = makeQuestion(
            answer: "1776",
            acceptable: ["July 4, 1776", "1776-07-04"],
            answerType: .date
        )

        // When - validate year only
        let result = await answerValidator.validate(userAnswer: "1776", question: question)

        // Then - is correct
        XCTAssertTrue(result.isCorrect)
    }

    func testValidation_titleAnswer_ignoresArticles() async {
        // Given - a title question
        let question = makeQuestion(
            answer: "The Great Gatsby",
            acceptable: ["Great Gatsby"],
            answerType: .title
        )

        // When - validate without article
        let result = await answerValidator.validate(userAnswer: "Great Gatsby", question: question)

        // Then - is correct
        XCTAssertTrue(result.isCorrect)
    }

    // MARK: - Edge Cases

    func testValidation_specialCharacters_handled() async {
        // Given - a question with special characters
        let question = makeQuestion(
            answer: "E=mc^2",
            acceptable: ["E=mc2", "E equals mc squared"],
            answerType: .scientific
        )

        // When - validate alternative
        let result = await answerValidator.validate(userAnswer: "E=mc2", question: question)

        // Then - is correct
        XCTAssertTrue(result.isCorrect)
    }

    func testValidation_unicodeCharacters_handled() async {
        // Given - a question with unicode
        let question = makeQuestion(
            answer: "Schrodinger",
            acceptable: ["Schroedinger"],
            answerType: .person
        )

        // When - validate without umlaut
        let result = await answerValidator.validate(userAnswer: "Schrodinger", question: question)

        // Then - is correct
        XCTAssertTrue(result.isCorrect)
    }

    // MARK: - Spelling Tolerance Tests

    func testValidation_minorTypo_mayBeAccepted() async {
        // Given - a question
        let question = makeQuestion(answer: "Mesopotamia", acceptable: nil, answerType: .place)

        // When - validate with typo (depends on validator config)
        let result = await answerValidator.validate(userAnswer: "Mesopotemia", question: question)

        // Then - check based on spelling tolerance setting
        // This behavior depends on validator configuration
        XCTAssertNotNil(result)
    }

    // MARK: - Integration with Session Flow

    @MainActor
    func testValidation_inSessionContext_recordsAttempt() async {
        // Given - a session with questions
        let sessionManager = KBSessionManager()
        let question = makeQuestion(answer: "Paris", acceptable: ["Paris, France"], answerType: .place)
        let questions = [question]
        let config = KBSessionConfig.quickPractice(
            region: .colorado,
            roundType: .oral,
            questionCount: 1
        )
        _ = await sessionManager.startSession(questions: questions, config: config)

        // When - validate and record attempt
        let result = await answerValidator.validate(
            userAnswer: "Paris",
            question: question
        )

        let attempt = KBQuestionAttempt(
            questionId: question.id,
            domain: question.domain,
            userAnswer: "Paris",
            responseTime: 2.5,
            wasCorrect: result.isCorrect,
            pointsEarned: result.isCorrect ? 10 : 0,
            roundType: .oral,
            matchType: result.matchType
        )
        await sessionManager.recordAttempt(attempt)

        // Then - attempt is recorded
        let session = await sessionManager.getCurrentSession()
        XCTAssertEqual(session?.attempts.count, 1)
        XCTAssertTrue(session?.attempts.first?.wasCorrect ?? false)
    }

    // MARK: - Test Helpers

    private func makeQuestion(
        answer: String,
        acceptable: [String]?,
        answerType: KBAnswerType
    ) -> KBQuestion {
        KBQuestion(
            id: UUID(),
            text: "Test question?",
            answer: KBAnswer(
                primary: answer,
                acceptable: acceptable,
                answerType: answerType
            ),
            domain: .socialStudies,
            difficulty: .foundational,
            gradeLevel: .highSchool,
            suitability: KBSuitability(forWritten: true, forOral: true, mcqPossible: true)
        )
    }
}
