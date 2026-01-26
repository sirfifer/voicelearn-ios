// UnaMentis - Knowledge Bowl Question Service
// Manages loading and filtering questions for practice sessions
//
// Questions are loaded from the bundled file first for immediate availability,
// then optionally synced from the server in the background.

import Foundation
import Logging

/// Service for loading and managing Knowledge Bowl questions
@MainActor
final class KBQuestionService: ObservableObject {
    static let shared = KBQuestionService()

    @Published private(set) var allQuestions: [KBQuestion] = []
    @Published private(set) var isLoaded = false
    @Published private(set) var isServerConnected = false
    @Published private(set) var serverSyncError: String?

    private static let logger = Logger(label: "com.unamentis.kb.questions")

    private init() {}

    // MARK: - Loading

    /// Load questions - loads bundled first for immediate availability, then optionally syncs from server
    func loadQuestions() async {
        // Always load bundled questions first for immediate availability
        await loadBundledQuestions()

        // Then try to sync from server in background (non-blocking)
        Task {
            await syncFromServerIfAvailable()
        }
    }

    /// Load questions from the bundled JSON file (same source as KBQuestionEngine)
    private func loadBundledQuestions() async {
        guard let url = Bundle.main.url(forResource: "kb-sample-questions", withExtension: "json") else {
            Self.logger.warning("Bundled questions file not found, using sample questions")
            loadSampleQuestions()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // The bundled file uses Core/KBQuestion format, convert to Modules/KBQuestion format
            let bundle = try decoder.decode(CoreQuestionBundle.self, from: data)
            allQuestions = bundle.questions.map { coreQuestion in
                convertCoreQuestion(coreQuestion)
            }
            isLoaded = true
            Self.logger.info("Loaded \(allQuestions.count) questions from bundled file")
        } catch {
            Self.logger.error("Failed to load bundled questions: \(error.localizedDescription)")
            loadSampleQuestions()
        }
    }

    /// Convert Core/KBQuestion format to Modules/KBQuestion format
    private func convertCoreQuestion(_ core: CoreQuestion) -> KBQuestion {
        KBQuestion(
            id: core.id.uuidString,
            domainId: core.domain,
            subcategory: core.subdomain ?? "",
            questionText: core.text,
            answerText: core.answer.primary,
            acceptableAnswers: [core.answer.primary] + (core.answer.acceptable ?? []),
            difficulty: convertDifficulty(core.difficulty),
            speedTargetSeconds: core.estimatedReadTime ?? 5.0,
            questionType: core.tags?.contains("bonus") == true ? "bonus" : "toss-up",
            hints: [],
            explanation: ""
        )
    }

    /// Convert difficulty string to numeric value
    private func convertDifficulty(_ difficulty: String) -> Int {
        switch difficulty {
        case "overview": return 1
        case "foundational": return 2
        case "intermediate": return 3
        case "varsity": return 4
        case "championship": return 5
        case "research": return 6
        default: return 3
        }
    }

    /// Sync from server if available (non-blocking background operation)
    private func syncFromServerIfAvailable() async {
        do {
            let questions = try await fetchQuestionsFromServer()
            // Only update if we got more questions than bundled
            if questions.count > allQuestions.count {
                allQuestions = questions
                Self.logger.info("Updated to \(questions.count) questions from server")
            }
            isServerConnected = true
            serverSyncError = nil
        } catch {
            isServerConnected = false
            serverSyncError = error.localizedDescription
            Self.logger.info("Server sync unavailable (offline mode): \(error.localizedDescription)")
        }
    }

    /// Fetch questions from the Management API
    private func fetchQuestionsFromServer() async throws -> [KBQuestion] {
        let serverIP = UserDefaults.standard.string(forKey: "primaryServerIP") ?? ""
        let host = serverIP.isEmpty ? "localhost" : serverIP
        let port = 8766

        guard let url = URL(string: "http://\(host):\(port)/api/modules/knowledge-bowl/download") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5  // Reduced timeout since we have bundled fallback

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let moduleContent = try JSONDecoder().decode(ModuleContent.self, from: data)

        // Extract all questions from all domains
        var questions: [KBQuestion] = []
        for domain in moduleContent.domains {
            questions.append(contentsOf: domain.questions)
        }

        return questions
    }

    /// Load sample questions for offline/testing (fallback only)
    private func loadSampleQuestions() {
        allQuestions = Self.sampleQuestions
        isLoaded = true
        Self.logger.info("Loaded \(allQuestions.count) sample questions (fallback)")
    }

    // MARK: - Filtering

    /// Get questions filtered by domain
    func questions(forDomain domainId: String) -> [KBQuestion] {
        allQuestions.filter { $0.domainId == domainId }
    }

    /// Get questions for a specific study mode
    func questions(forMode mode: KBStudyMode, weakDomains: [String] = []) -> [KBQuestion] {
        switch mode {
        case .diagnostic:
            // Balanced across all domains
            return balancedSelection(count: 50)
        case .targeted:
            // Focus on weak domains
            if weakDomains.isEmpty {
                return Array(allQuestions.shuffled().prefix(25))
            }
            let weakQuestions = allQuestions.filter { weakDomains.contains($0.domainId) }
            return Array(weakQuestions.shuffled().prefix(25))
        case .breadth:
            // Cover all domains evenly
            return balancedSelection(count: 36)
        case .speed:
            // Quick questions (lower difficulty)
            let easyQuestions = allQuestions.filter { $0.difficulty <= 2 }
            return Array(easyQuestions.shuffled().prefix(20))
        case .competition, .team:
            // Full competition simulation
            return balancedSelection(count: 45)
        }
    }

    /// Select questions balanced across domains
    private func balancedSelection(count: Int) -> [KBQuestion] {
        var selected: [KBQuestion] = []
        let domains = Set(allQuestions.map { $0.domainId })
        let questionsPerDomain = max(1, count / max(1, domains.count))

        for domain in domains {
            let domainQuestions = questions(forDomain: domain).shuffled()
            selected.append(contentsOf: domainQuestions.prefix(questionsPerDomain))
        }

        // Fill remaining slots randomly
        let remaining = count - selected.count
        if remaining > 0 {
            let unused = allQuestions.filter { q in !selected.contains(where: { $0.id == q.id }) }
            selected.append(contentsOf: unused.shuffled().prefix(remaining))
        }

        return Array(selected.shuffled().prefix(count))
    }

    // MARK: - Sample Data

    static let sampleQuestions: [KBQuestion] = [
        KBQuestion(
            id: "sci-phys-001",
            domainId: "science",
            subcategory: "Physics",
            questionText: "What is the SI unit of electric current?",
            answerText: "Ampere",
            acceptableAnswers: ["Ampere", "Amp", "A"],
            difficulty: 2,
            speedTargetSeconds: 5.0,
            questionType: "toss-up",
            hints: ["Named after a French physicist"],
            explanation: "The ampere (A) is the SI base unit of electric current, named after Andre-Marie Ampere."
        ),
        KBQuestion(
            id: "sci-chem-001",
            domainId: "science",
            subcategory: "Chemistry",
            questionText: "What is the chemical symbol for gold?",
            answerText: "Au",
            acceptableAnswers: ["Au"],
            difficulty: 1,
            speedTargetSeconds: 3.0,
            questionType: "toss-up",
            hints: ["From the Latin word 'aurum'"],
            explanation: "Gold's symbol Au comes from the Latin 'aurum' meaning 'shining dawn'."
        ),
        KBQuestion(
            id: "math-geo-001",
            domainId: "mathematics",
            subcategory: "Geometry",
            questionText: "What is the sum of interior angles in a triangle?",
            answerText: "180 degrees",
            acceptableAnswers: ["180", "180 degrees", "one hundred eighty"],
            difficulty: 1,
            speedTargetSeconds: 3.0,
            questionType: "toss-up",
            hints: ["Think of a straight line"],
            explanation: "The interior angles of any triangle always sum to 180 degrees."
        ),
        KBQuestion(
            id: "hist-us-001",
            domainId: "history",
            subcategory: "US History",
            questionText: "In what year was the Declaration of Independence signed?",
            answerText: "1776",
            acceptableAnswers: ["1776", "seventeen seventy-six"],
            difficulty: 1,
            speedTargetSeconds: 3.0,
            questionType: "toss-up",
            hints: ["Think July 4th"],
            explanation: "The Declaration of Independence was adopted on July 4, 1776."
        ),
        KBQuestion(
            id: "lit-am-001",
            domainId: "literature",
            subcategory: "American Literature",
            questionText: "Who wrote 'The Great Gatsby'?",
            answerText: "F. Scott Fitzgerald",
            acceptableAnswers: ["F. Scott Fitzgerald", "Fitzgerald", "Scott Fitzgerald"],
            difficulty: 1,
            speedTargetSeconds: 4.0,
            questionType: "toss-up",
            hints: ["Associated with the Jazz Age"],
            explanation: "F. Scott Fitzgerald wrote The Great Gatsby in 1925, capturing the Jazz Age."
        )
    ]
}

// MARK: - Module Content Decoding

private struct ModuleContent: Decodable {
    let domains: [DomainContent]

    struct DomainContent: Decodable {
        let id: String
        let name: String
        let questions: [KBQuestion]
    }
}

// MARK: - Core Question Bundle Decoding (for bundled JSON file)

/// Bundle format used in kb-sample-questions.json
private struct CoreQuestionBundle: Decodable {
    let version: String
    let questions: [CoreQuestion]
}

/// Core question format from bundled JSON
private struct CoreQuestion: Decodable {
    let id: UUID
    let text: String
    let answer: CoreAnswer
    let domain: String
    let subdomain: String?
    let difficulty: String
    let gradeLevel: String
    let suitability: CoreSuitability
    let estimatedReadTime: Double?
    let mcqOptions: [String]?
    let source: String?
    let sourceAttribution: String?
    let tags: [String]?

    struct CoreAnswer: Decodable {
        let primary: String
        let acceptable: [String]?
        let answerType: String
    }

    struct CoreSuitability: Decodable {
        let forWritten: Bool
        let forOral: Bool
        let mcqPossible: Bool
        let requiresVisual: Bool
    }
}
