// UnaMentis - Knowledge Bowl Module
// Specialized training module for Knowledge Bowl competition preparation
//
// Knowledge Bowl is an academic competition where teams answer questions
// across 12+ subject domains with emphasis on speed and breadth.
// This module provides:
// - Directed study across all domains
// - Speed training with sub-3-second response targets
// - Competition simulation with buzzer mechanics
// - Team collaboration mode

import SwiftUI
import Logging

/// Knowledge Bowl training module
///
/// Implements the ModuleProtocol to provide Knowledge Bowl-specific
/// training features within the UnaMentis app.
public struct KnowledgeBowlModule: ModuleProtocol {
    public let id = "knowledge-bowl"
    public let name = "Knowledge Bowl"
    public let shortDescription = "Academic competition prep across 12 subject domains"
    public let longDescription = """
        Prepare for Knowledge Bowl competitions with directed study, \
        speed training, and realistic competition simulation. \
        Track your mastery across Science, Math, Literature, History, \
        and 8 other domains. Practice solo or with your team.
        """
    public let iconName = "brain.head.profile"
    public let themeColor = Color.purple
    public let supportsTeamMode = true
    public let supportsSpeedTraining = true
    public let supportsCompetitionSim = true
    public let version = "1.0.0"

    private static let logger = Logger(label: "com.unamentis.modules.knowledgebowl")

    public init() {
        Self.logger.info("Knowledge Bowl module initialized")
    }

    @MainActor
    public func makeRootView() -> AnyView {
        AnyView(KBDashboardView())
    }

    @MainActor
    public func makeDashboardView() -> AnyView {
        AnyView(KBDashboardSummary())
    }
}

// MARK: - Domain Definitions

/// Knowledge Bowl subject domains with their competition weights
public enum KBDomain: String, CaseIterable, Identifiable {
    case science = "Science"
    case mathematics = "Mathematics"
    case literature = "Literature"
    case history = "History"
    case socialStudies = "Social Studies"
    case arts = "Arts"
    case currentEvents = "Current Events"
    case language = "Language"
    case technology = "Technology"
    case popCulture = "Pop Culture"
    case religionPhilosophy = "Religion & Philosophy"
    case miscellaneous = "Miscellaneous"

    public var id: String { rawValue }

    /// Competition weight (percentage of questions)
    public var weight: Double {
        switch self {
        case .science: return 0.20
        case .mathematics: return 0.15
        case .literature: return 0.12
        case .history: return 0.12
        case .socialStudies: return 0.10
        case .arts: return 0.08
        case .currentEvents: return 0.08
        case .language: return 0.05
        case .technology: return 0.04
        case .popCulture: return 0.03
        case .religionPhilosophy: return 0.02
        case .miscellaneous: return 0.01
        }
    }

    /// SF Symbol for the domain
    public var iconName: String {
        switch self {
        case .science: return "atom"
        case .mathematics: return "function"
        case .literature: return "book.closed"
        case .history: return "clock.arrow.circlepath"
        case .socialStudies: return "globe.americas"
        case .arts: return "paintpalette"
        case .currentEvents: return "newspaper"
        case .language: return "character.book.closed"
        case .technology: return "cpu"
        case .popCulture: return "star"
        case .religionPhilosophy: return "sparkles"
        case .miscellaneous: return "puzzlepiece"
        }
    }

    /// Theme color for the domain
    public var color: Color {
        switch self {
        case .science: return .blue
        case .mathematics: return .orange
        case .literature: return .brown
        case .history: return .red
        case .socialStudies: return .green
        case .arts: return .pink
        case .currentEvents: return .cyan
        case .language: return .indigo
        case .technology: return .gray
        case .popCulture: return .yellow
        case .religionPhilosophy: return .purple
        case .miscellaneous: return .mint
        }
    }

    /// Subcategories within the domain
    public var subcategories: [String] {
        switch self {
        case .science:
            return ["Biology", "Chemistry", "Physics", "Earth Science", "Astronomy"]
        case .mathematics:
            return ["Arithmetic", "Algebra", "Geometry", "Calculus", "Statistics"]
        case .literature:
            return ["American", "British", "World", "Poetry", "Drama"]
        case .history:
            return ["US", "World", "Ancient", "Modern", "Military"]
        case .socialStudies:
            return ["Geography", "Government", "Economics", "Sociology"]
        case .arts:
            return ["Visual Arts", "Music", "Theater", "Architecture"]
        case .currentEvents:
            return ["Politics", "Science", "Culture", "Sports", "Technology"]
        case .language:
            return ["Grammar", "Vocabulary", "Etymology", "Foreign Languages"]
        case .technology:
            return ["Computer Science", "Engineering", "Inventions"]
        case .popCulture:
            return ["Entertainment", "Media", "Sports", "Games"]
        case .religionPhilosophy:
            return ["World Religions", "Ethics", "Philosophy"]
        case .miscellaneous:
            return ["Trivia", "Cross-domain", "Puzzles"]
        }
    }
}

// MARK: - Question Model

/// A Knowledge Bowl practice question
struct KBQuestion: Codable, Identifiable, Hashable {
    let id: String
    let domainId: String
    let subcategory: String
    let questionText: String
    let answerText: String
    let acceptableAnswers: [String]
    let difficulty: Int
    let speedTargetSeconds: Double
    let questionType: String
    let hints: [String]
    let explanation: String

    enum CodingKeys: String, CodingKey {
        case id
        case domainId = "domain_id"
        case subcategory
        case questionText = "question_text"
        case answerText = "answer_text"
        case acceptableAnswers = "acceptable_answers"
        case difficulty
        case speedTargetSeconds = "speed_target_seconds"
        case questionType = "question_type"
        case hints
        case explanation
    }

    func isCorrect(answer: String) -> Bool {
        let normalizedAnswer = answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return acceptableAnswers.contains { $0.lowercased() == normalizedAnswer }
    }
}

/// Result of answering a question
struct KBQuestionResult: Identifiable {
    let id = UUID()
    let question: KBQuestion
    let userAnswer: String
    let isCorrect: Bool
    let responseTimeSeconds: Double
    let wasWithinSpeedTarget: Bool

    init(question: KBQuestion, userAnswer: String, responseTimeSeconds: Double) {
        self.question = question
        self.userAnswer = userAnswer
        self.isCorrect = question.isCorrect(answer: userAnswer)
        self.responseTimeSeconds = responseTimeSeconds
        self.wasWithinSpeedTarget = responseTimeSeconds <= question.speedTargetSeconds
    }
}

/// Summary of a practice session
struct KBSessionSummary {
    let totalQuestions: Int
    let correctAnswers: Int
    let averageResponseTime: Double
    let questionsWithinSpeedTarget: Int
    let domainBreakdown: [String: DomainScore]
    let duration: TimeInterval

    var accuracy: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(correctAnswers) / Double(totalQuestions)
    }

    var speedTargetRate: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(questionsWithinSpeedTarget) / Double(totalQuestions)
    }

    struct DomainScore {
        let total: Int
        let correct: Int
        var accuracy: Double {
            guard total > 0 else { return 0 }
            return Double(correct) / Double(total)
        }
    }
}

// MARK: - Practice Engine

/// Manages a Knowledge Bowl practice session
@MainActor
final class KBPracticeEngine: ObservableObject {
    @Published private(set) var currentQuestion: KBQuestion?
    @Published private(set) var questionIndex: Int = 0
    @Published private(set) var totalQuestions: Int = 0
    @Published private(set) var results: [KBQuestionResult] = []
    @Published private(set) var sessionState: SessionState = .notStarted
    @Published private(set) var timeRemaining: TimeInterval = 0
    @Published private(set) var questionStartTime: Date?

    private var questions: [KBQuestion] = []
    private var mode: KBStudyMode = .diagnostic
    private var sessionStartTime: Date?
    private var timer: Timer?

    private static let logger = Logger(label: "com.unamentis.kb.practice.engine")

    enum SessionState: Equatable {
        case notStarted
        case inProgress
        case showingAnswer(isCorrect: Bool)
        case completed
    }

    init() {}

    func startSession(questions: [KBQuestion], mode: KBStudyMode) {
        self.questions = mode == .diagnostic ? questions : questions.shuffled()
        self.mode = mode
        self.totalQuestions = min(questions.count, questionCountForMode(mode))
        self.questionIndex = 0
        self.results = []
        self.sessionStartTime = Date()
        self.sessionState = .inProgress

        if mode == .speed {
            timeRemaining = 300
            startTimer()
        }

        presentNextQuestion()
        Self.logger.info("Started \(mode.rawValue) session with \(totalQuestions) questions")
    }

    func submitAnswer(_ answer: String) {
        guard let question = currentQuestion,
              let startTime = questionStartTime,
              sessionState == .inProgress else { return }

        let responseTime = Date().timeIntervalSince(startTime)
        let result = KBQuestionResult(question: question, userAnswer: answer, responseTimeSeconds: responseTime)
        results.append(result)
        sessionState = .showingAnswer(isCorrect: result.isCorrect)
    }

    func skipQuestion() {
        guard let question = currentQuestion, sessionState == .inProgress else { return }
        let result = KBQuestionResult(question: question, userAnswer: "", responseTimeSeconds: 0)
        results.append(result)
        sessionState = .showingAnswer(isCorrect: false)
    }

    func nextQuestion() {
        questionIndex += 1
        if questionIndex >= totalQuestions || (mode == .speed && timeRemaining <= 0) {
            endSession()
        } else {
            sessionState = .inProgress
            presentNextQuestion()
        }
    }

    func endSessionEarly() { endSession() }

    func generateSummary() -> KBSessionSummary {
        let correctCount = results.filter { $0.isCorrect }.count
        let avgTime = results.isEmpty ? 0 : results.map { $0.responseTimeSeconds }.reduce(0, +) / Double(results.count)
        let speedTargetCount = results.filter { $0.wasWithinSpeedTarget }.count

        var domainBreakdown: [String: KBSessionSummary.DomainScore] = [:]
        for result in results {
            let domainId = result.question.domainId
            var score = domainBreakdown[domainId] ?? KBSessionSummary.DomainScore(total: 0, correct: 0)
            score = KBSessionSummary.DomainScore(total: score.total + 1, correct: score.correct + (result.isCorrect ? 1 : 0))
            domainBreakdown[domainId] = score
        }

        return KBSessionSummary(
            totalQuestions: results.count,
            correctAnswers: correctCount,
            averageResponseTime: avgTime,
            questionsWithinSpeedTarget: speedTargetCount,
            domainBreakdown: domainBreakdown,
            duration: sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0
        )
    }

    private func questionCountForMode(_ mode: KBStudyMode) -> Int {
        switch mode {
        case .diagnostic: return 50
        case .targeted: return 25
        case .breadth: return 36
        case .speed: return 20
        case .competition, .team: return 45
        }
    }

    private func presentNextQuestion() {
        guard questionIndex < questions.count && questionIndex < totalQuestions else {
            endSession()
            return
        }
        currentQuestion = questions[questionIndex]
        questionStartTime = Date()
    }

    private func endSession() {
        stopTimer()
        sessionState = .completed
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickTimer() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tickTimer() {
        guard timeRemaining > 0 else { endSession(); return }
        timeRemaining -= 1
    }
}

// MARK: - Question Service

/// Service for loading and managing Knowledge Bowl questions
@MainActor
final class KBQuestionService: ObservableObject {
    static let shared = KBQuestionService()

    @Published private(set) var allQuestions: [KBQuestion] = []
    @Published private(set) var isLoaded = false

    private static let logger = Logger(label: "com.unamentis.kb.questions")

    private init() {}

    func loadQuestions() async {
        do {
            let questions = try await fetchQuestionsFromServer()
            allQuestions = questions
            isLoaded = true
            Self.logger.info("Loaded \(questions.count) questions from server")
        } catch {
            Self.logger.error("Failed to load questions: \(error)")
            loadSampleQuestions()
        }
    }

    private func fetchQuestionsFromServer() async throws -> [KBQuestion] {
        let serverIP = UserDefaults.standard.string(forKey: "primaryServerIP") ?? ""
        let host = serverIP.isEmpty ? "localhost" : serverIP

        guard let url = URL(string: "http://\(host):8766/api/modules/knowledge-bowl/download") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let moduleContent = try JSONDecoder().decode(ModuleContent.self, from: data)
        return moduleContent.domains.flatMap { $0.questions }
    }

    private func loadSampleQuestions() {
        allQuestions = Self.sampleQuestions
        isLoaded = true
    }

    func questions(forMode mode: KBStudyMode, weakDomains: [String] = []) -> [KBQuestion] {
        switch mode {
        case .diagnostic: return balancedSelection(count: 50)
        case .targeted:
            if weakDomains.isEmpty { return Array(allQuestions.shuffled().prefix(25)) }
            return Array(allQuestions.filter { weakDomains.contains($0.domainId) }.shuffled().prefix(25))
        case .breadth: return balancedSelection(count: 36)
        case .speed: return Array(allQuestions.filter { $0.difficulty <= 2 }.shuffled().prefix(20))
        case .competition, .team: return balancedSelection(count: 45)
        }
    }

    private func balancedSelection(count: Int) -> [KBQuestion] {
        var selected: [KBQuestion] = []
        let domains = Set(allQuestions.map { $0.domainId })
        let questionsPerDomain = max(1, count / max(1, domains.count))

        for domain in domains {
            let domainQuestions = allQuestions.filter { $0.domainId == domain }.shuffled()
            selected.append(contentsOf: domainQuestions.prefix(questionsPerDomain))
        }

        let remaining = count - selected.count
        if remaining > 0 {
            let unused = allQuestions.filter { q in !selected.contains(where: { $0.id == q.id }) }
            selected.append(contentsOf: unused.shuffled().prefix(remaining))
        }

        return Array(selected.shuffled().prefix(count))
    }

    static let sampleQuestions: [KBQuestion] = [
        KBQuestion(id: "sci-phys-001", domainId: "science", subcategory: "Physics",
                   questionText: "What is the SI unit of electric current?", answerText: "Ampere",
                   acceptableAnswers: ["Ampere", "Amp", "A"], difficulty: 2, speedTargetSeconds: 5.0,
                   questionType: "toss-up", hints: ["Named after a French physicist"],
                   explanation: "The ampere (A) is the SI base unit of electric current."),
        KBQuestion(id: "sci-chem-001", domainId: "science", subcategory: "Chemistry",
                   questionText: "What is the chemical symbol for gold?", answerText: "Au",
                   acceptableAnswers: ["Au"], difficulty: 1, speedTargetSeconds: 3.0,
                   questionType: "toss-up", hints: ["From the Latin word 'aurum'"],
                   explanation: "Gold's symbol Au comes from the Latin 'aurum'."),
        KBQuestion(id: "math-geo-001", domainId: "mathematics", subcategory: "Geometry",
                   questionText: "What is the sum of interior angles in a triangle?", answerText: "180 degrees",
                   acceptableAnswers: ["180", "180 degrees"], difficulty: 1, speedTargetSeconds: 3.0,
                   questionType: "toss-up", hints: ["Think of a straight line"],
                   explanation: "The interior angles of any triangle always sum to 180 degrees."),
        KBQuestion(id: "hist-us-001", domainId: "history", subcategory: "US History",
                   questionText: "In what year was the Declaration of Independence signed?", answerText: "1776",
                   acceptableAnswers: ["1776"], difficulty: 1, speedTargetSeconds: 3.0,
                   questionType: "toss-up", hints: ["Think July 4th"],
                   explanation: "The Declaration of Independence was adopted on July 4, 1776."),
        KBQuestion(id: "lit-am-001", domainId: "literature", subcategory: "American Literature",
                   questionText: "Who wrote 'The Great Gatsby'?", answerText: "F. Scott Fitzgerald",
                   acceptableAnswers: ["F. Scott Fitzgerald", "Fitzgerald"], difficulty: 1, speedTargetSeconds: 4.0,
                   questionType: "toss-up", hints: ["Associated with the Jazz Age"],
                   explanation: "F. Scott Fitzgerald wrote The Great Gatsby in 1925.")
    ]
}

private struct ModuleContent: Decodable {
    let domains: [DomainContent]
    struct DomainContent: Decodable {
        let id: String
        let name: String
        let questions: [KBQuestion]
    }
}
