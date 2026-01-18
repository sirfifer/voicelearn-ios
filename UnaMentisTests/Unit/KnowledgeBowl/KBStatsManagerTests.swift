// UnaMentis - Knowledge Bowl Stats Manager Tests
// Tests for KBStatsManager, DomainStats, and SessionRecord
//
// Part of Knowledge Bowl Module Testing

@preconcurrency import XCTest
@testable import UnaMentis

final class KBStatsManagerTests: XCTestCase {

    private nonisolated(unsafe) var testDefaults: UserDefaults!
    private nonisolated(unsafe) var statsManager: KBStatsManager!
    private let testSuiteName = "com.unamentis.tests.kbstats"

    override func setUpWithError() throws {
        try super.setUpWithError()
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removePersistentDomain(forName: testSuiteName)
        let defaults = testDefaults!
        statsManager = MainActor.assumeIsolated {
            KBStatsManager(defaults: defaults)
        }
    }

    override func tearDownWithError() throws {
        testDefaults?.removePersistentDomain(forName: testSuiteName)
        testDefaults = nil
        statsManager = nil
        try super.tearDownWithError()
    }

    // MARK: - Initial State Tests

    @MainActor
    func testInitialState_hasZeroValues() {
        XCTAssertEqual(statsManager.totalQuestionsAnswered, 0)
        XCTAssertEqual(statsManager.totalCorrectAnswers, 0)
        XCTAssertEqual(statsManager.averageResponseTime, 0)
        XCTAssertTrue(statsManager.domainStats.isEmpty)
        XCTAssertTrue(statsManager.recentSessions.isEmpty)
    }

    @MainActor
    func testOverallAccuracy_returnsZeroWithNoQuestions() {
        XCTAssertEqual(statsManager.overallAccuracy, 0)
    }

    @MainActor
    func testCompetitionReadiness_returnsZeroWithNoQuestions() {
        XCTAssertEqual(statsManager.competitionReadiness, 0)
    }

    // MARK: - Record Session Tests

    @MainActor
    func testRecordSession_updatesTotalQuestions() {
        let summary = makeSessionSummary(totalQuestions: 10, correctAnswers: 7)

        statsManager.recordSession(summary, mode: .diagnostic)

        XCTAssertEqual(statsManager.totalQuestionsAnswered, 10)
        XCTAssertEqual(statsManager.totalCorrectAnswers, 7)
    }

    @MainActor
    func testRecordSession_accumulatesMultipleSessions() {
        let summary1 = makeSessionSummary(totalQuestions: 10, correctAnswers: 7)
        let summary2 = makeSessionSummary(totalQuestions: 5, correctAnswers: 4)

        statsManager.recordSession(summary1, mode: .diagnostic)
        statsManager.recordSession(summary2, mode: .targeted)

        XCTAssertEqual(statsManager.totalQuestionsAnswered, 15)
        XCTAssertEqual(statsManager.totalCorrectAnswers, 11)
    }

    @MainActor
    func testRecordSession_calculatesAverageResponseTime() {
        let summary = makeSessionSummary(
            totalQuestions: 10,
            correctAnswers: 7,
            averageResponseTime: 3.5
        )

        statsManager.recordSession(summary, mode: .diagnostic)

        XCTAssertEqual(statsManager.averageResponseTime, 3.5, accuracy: 0.001)
    }

    @MainActor
    func testRecordSession_updatesRunningAverageResponseTime() {
        // First session: 10 questions at 4.0s average
        let summary1 = makeSessionSummary(
            totalQuestions: 10,
            correctAnswers: 5,
            averageResponseTime: 4.0
        )
        statsManager.recordSession(summary1, mode: .diagnostic)

        // Second session: 10 questions at 2.0s average
        let summary2 = makeSessionSummary(
            totalQuestions: 10,
            correctAnswers: 5,
            averageResponseTime: 2.0
        )
        statsManager.recordSession(summary2, mode: .speed)

        // Running average should be (10*4 + 10*2) / 20 = 3.0
        XCTAssertEqual(statsManager.averageResponseTime, 3.0, accuracy: 0.001)
    }

    @MainActor
    func testRecordSession_addsSessionRecord() {
        let summary = makeSessionSummary(totalQuestions: 10, correctAnswers: 7)

        statsManager.recordSession(summary, mode: .diagnostic)

        XCTAssertEqual(statsManager.recentSessions.count, 1)
        XCTAssertEqual(statsManager.recentSessions.first?.questionsAnswered, 10)
        XCTAssertEqual(statsManager.recentSessions.first?.correctAnswers, 7)
        XCTAssertEqual(statsManager.recentSessions.first?.mode, "Diagnostic")
    }

    @MainActor
    func testRecordSession_keepsOnly20RecentSessions() {
        for i in 0..<25 {
            let summary = makeSessionSummary(totalQuestions: i + 1, correctAnswers: i)
            statsManager.recordSession(summary, mode: .diagnostic)
        }

        XCTAssertEqual(statsManager.recentSessions.count, 20)
        // Most recent should be first
        XCTAssertEqual(statsManager.recentSessions.first?.questionsAnswered, 25)
    }

    @MainActor
    func testRecordSession_updatesDomainStats() {
        let domainBreakdown: [String: KBSessionSummary.DomainScore] = [
            "Science": KBSessionSummary.DomainScore(total: 5, correct: 4),
            "Mathematics": KBSessionSummary.DomainScore(total: 3, correct: 2)
        ]
        let summary = makeSessionSummary(domainBreakdown: domainBreakdown)

        statsManager.recordSession(summary, mode: .diagnostic)

        // Domain IDs are normalized to lowercase with dashes
        XCTAssertEqual(statsManager.domainStats["science"]?.totalAnswered, 5)
        XCTAssertEqual(statsManager.domainStats["science"]?.totalCorrect, 4)
        XCTAssertEqual(statsManager.domainStats["mathematics"]?.totalAnswered, 3)
        XCTAssertEqual(statsManager.domainStats["mathematics"]?.totalCorrect, 2)
    }

    // MARK: - Overall Accuracy Tests

    @MainActor
    func testOverallAccuracy_calculatesCorrectly() {
        let summary = makeSessionSummary(totalQuestions: 10, correctAnswers: 7)
        statsManager.recordSession(summary, mode: .diagnostic)

        XCTAssertEqual(statsManager.overallAccuracy, 0.7, accuracy: 0.001)
    }

    // MARK: - Competition Readiness Tests

    @MainActor
    func testCompetitionReadiness_calculatesWeightedAverage() {
        // Setup: Answer 200 questions across 12 domains with 80% accuracy
        for domain in KBDomain.allCases {
            let domainBreakdown = [domain.rawValue: KBSessionSummary.DomainScore(total: 17, correct: 14)]
            let summary = makeSessionSummary(
                totalQuestions: 17,
                correctAnswers: 14,
                domainBreakdown: domainBreakdown
            )
            statsManager.recordSession(summary, mode: .diagnostic)
        }

        // With 200+ questions, 80%+ accuracy, and all 12 domains covered
        // Readiness should be high (around 0.7-0.8)
        XCTAssertGreaterThan(statsManager.competitionReadiness, 0.6)
    }

    // MARK: - Mastery Tests

    @MainActor
    func testMastery_returnsZeroForUnknownDomain() {
        XCTAssertEqual(statsManager.mastery(for: "unknown-domain"), 0)
    }

    @MainActor
    func testMastery_calculatesCorrectlyForDomain() {
        let domainBreakdown = ["Science": KBSessionSummary.DomainScore(total: 10, correct: 8)]
        let summary = makeSessionSummary(domainBreakdown: domainBreakdown)
        statsManager.recordSession(summary, mode: .diagnostic)

        XCTAssertEqual(statsManager.mastery(for: "Science"), 0.8, accuracy: 0.001)
    }

    @MainActor
    func testMastery_worksWithKBDomainEnum() {
        let domainBreakdown = [KBDomain.science.rawValue: KBSessionSummary.DomainScore(total: 10, correct: 9)]
        let summary = makeSessionSummary(domainBreakdown: domainBreakdown)
        statsManager.recordSession(summary, mode: .diagnostic)

        XCTAssertEqual(statsManager.mastery(for: .science), 0.9, accuracy: 0.001)
    }

    // MARK: - Reset Stats Tests

    @MainActor
    func testResetStats_clearsAllData() {
        // First add some data
        let summary = makeSessionSummary(totalQuestions: 10, correctAnswers: 7)
        statsManager.recordSession(summary, mode: .diagnostic)

        // Then reset
        statsManager.resetStats()

        XCTAssertEqual(statsManager.totalQuestionsAnswered, 0)
        XCTAssertEqual(statsManager.totalCorrectAnswers, 0)
        XCTAssertEqual(statsManager.averageResponseTime, 0)
        XCTAssertTrue(statsManager.domainStats.isEmpty)
        XCTAssertTrue(statsManager.recentSessions.isEmpty)
    }

    // MARK: - Domain ID Normalization Tests

    @MainActor
    func testNormalizeDomainId_lowercases() {
        XCTAssertEqual(statsManager.normalizeDomainId("Science"), "science")
        XCTAssertEqual(statsManager.normalizeDomainId("MATH"), "math")
    }

    @MainActor
    func testNormalizeDomainId_replacesSpacesWithDashes() {
        XCTAssertEqual(statsManager.normalizeDomainId("Social Studies"), "social-studies")
        XCTAssertEqual(statsManager.normalizeDomainId("Pop Culture"), "pop-culture")
    }

    @MainActor
    func testNormalizeDomainId_removesAmpersands() {
        XCTAssertEqual(statsManager.normalizeDomainId("Religion & Philosophy"), "religion-philosophy")
    }

    @MainActor
    func testNormalizeDomainId_collapsesDoubleDashes() {
        XCTAssertEqual(statsManager.normalizeDomainId("A--B"), "a-b")
    }

    // MARK: - DomainStats Tests

    func testDomainStats_accuracy_calculatesCorrectly() {
        let stats = DomainStats(totalAnswered: 10, totalCorrect: 8)
        XCTAssertEqual(stats.accuracy, 0.8, accuracy: 0.001)
    }

    func testDomainStats_accuracy_returnsZeroForNoAnswers() {
        let stats = DomainStats(totalAnswered: 0, totalCorrect: 0)
        XCTAssertEqual(stats.accuracy, 0)
    }

    func testDomainStats_codable() throws {
        let stats = DomainStats(totalAnswered: 10, totalCorrect: 7)

        let encoded = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(DomainStats.self, from: encoded)

        XCTAssertEqual(decoded.totalAnswered, 10)
        XCTAssertEqual(decoded.totalCorrect, 7)
    }

    // MARK: - SessionRecord Tests

    func testSessionRecord_accuracy_calculatesCorrectly() {
        let record = SessionRecord(
            id: UUID(),
            date: Date(),
            mode: "Diagnostic",
            questionsAnswered: 10,
            correctAnswers: 7,
            averageTime: 3.5
        )

        XCTAssertEqual(record.accuracy, 0.7, accuracy: 0.001)
    }

    func testSessionRecord_accuracy_returnsZeroForNoQuestions() {
        let record = SessionRecord(
            id: UUID(),
            date: Date(),
            mode: "Diagnostic",
            questionsAnswered: 0,
            correctAnswers: 0,
            averageTime: 0
        )

        XCTAssertEqual(record.accuracy, 0)
    }

    func testSessionRecord_codable() throws {
        let id = UUID()
        let date = Date()
        let record = SessionRecord(
            id: id,
            date: date,
            mode: "Speed Drill",
            questionsAnswered: 20,
            correctAnswers: 15,
            averageTime: 2.5
        )

        let encoded = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(SessionRecord.self, from: encoded)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.mode, "Speed Drill")
        XCTAssertEqual(decoded.questionsAnswered, 20)
        XCTAssertEqual(decoded.correctAnswers, 15)
        XCTAssertEqual(decoded.averageTime, 2.5)
    }

    // MARK: - Helpers

    private func makeSessionSummary(
        totalQuestions: Int = 10,
        correctAnswers: Int = 5,
        averageResponseTime: Double = 3.0,
        questionsWithinSpeedTarget: Int = 5,
        domainBreakdown: [String: KBSessionSummary.DomainScore] = [:],
        duration: TimeInterval = 120
    ) -> KBSessionSummary {
        KBSessionSummary(
            totalQuestions: totalQuestions,
            correctAnswers: correctAnswers,
            averageResponseTime: averageResponseTime,
            questionsWithinSpeedTarget: questionsWithinSpeedTarget,
            domainBreakdown: domainBreakdown,
            duration: duration
        )
    }
}
