// UnaMentis - Knowledge Bowl Question Model
// Represents a Knowledge Bowl practice question
//
// Questions are fetched from the server as part of module content
// and stored locally for offline practice.

import Foundation

/// A Knowledge Bowl practice question
struct KBQuestion: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let domainId: String
    let subcategory: String
    let questionText: String
    let answerText: String
    let acceptableAnswers: [String]
    let difficulty: Int  // 1-5 scale
    let speedTargetSeconds: Double
    let questionType: String  // "toss-up", "bonus", etc.
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

    /// Check if the given answer is correct
    func isCorrect(answer: String) -> Bool {
        let normalizedAnswer = answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return acceptableAnswers.contains { acceptable in
            acceptable.lowercased() == normalizedAnswer
        }
    }
}

/// Result of answering a question
struct KBQuestionResult: Identifiable, Sendable {
    let id = UUID()
    let question: KBQuestion
    let userAnswer: String
    let isCorrect: Bool
    let responseTimeSeconds: Double
    let wasWithinSpeedTarget: Bool
    let wasSkipped: Bool

    init(question: KBQuestion, userAnswer: String, responseTimeSeconds: Double, wasSkipped: Bool = false) {
        self.question = question
        self.userAnswer = userAnswer
        self.isCorrect = wasSkipped ? false : question.isCorrect(answer: userAnswer)
        self.responseTimeSeconds = responseTimeSeconds
        self.wasWithinSpeedTarget = wasSkipped ? false : responseTimeSeconds <= question.speedTargetSeconds
        self.wasSkipped = wasSkipped
    }
}

/// Summary of a practice session
struct KBSessionSummary: Sendable {
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

    struct DomainScore: Sendable {
        let total: Int
        let correct: Int
        var accuracy: Double {
            guard total > 0 else { return 0 }
            return Double(correct) / Double(total)
        }
    }
}
