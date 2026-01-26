//
//  KBPackService.swift
//  UnaMentis
//
//  Service for fetching Knowledge Bowl packs from the management API.
//

import Foundation
import Logging
import SwiftUI

/// Service for fetching and managing Knowledge Bowl question packs.
@MainActor
@Observable
final class KBPackService {
    private(set) var packs: [KBPack] = []
    private(set) var isLoading = false
    private(set) var error: Error?

    private let baseURL: URL
    private let session: URLSession
    private static let logger = Logger(label: "com.unamentis.kb.packservice")

    init(baseURL: URL? = nil) {
        // Default to localhost management API
        self.baseURL = baseURL ?? URL(string: "http://localhost:8766")!
        self.session = URLSession.shared
    }

    // MARK: - Public Methods

    /// Fetch all available packs from the server
    func fetchPacks() async {
        isLoading = true
        error = nil

        do {
            packs = try await fetchPacksFromServer()
            Self.logger.info("Fetched \(self.packs.count) packs from server")
        } catch {
            self.error = error
            Self.logger.error("Failed to fetch packs: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Fetch a specific pack by ID
    func fetchPack(id: String) async throws -> KBPack {
        let url = baseURL.appendingPathComponent("api/kb/packs/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KBPackServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw KBPackServiceError.serverError(statusCode: httpResponse.statusCode)
        }

        let dto = try JSONDecoder().decode(KBPackDTO.self, from: data)
        return dto.toPack()
    }

    /// Fetch questions for a specific pack
    func fetchPackQuestions(packId: String) async throws -> [KBQuestion] {
        let url = baseURL.appendingPathComponent("api/kb/packs/\(packId)/questions")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KBPackServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw KBPackServiceError.serverError(statusCode: httpResponse.statusCode)
        }

        // Parse questions response
        let questionsResponse = try JSONDecoder().decode(KBQuestionsResponse.self, from: data)
        return questionsResponse.questions.map { $0.toQuestion() }
    }

    // MARK: - Private Methods

    private func fetchPacksFromServer() async throws -> [KBPack] {
        let url = baseURL.appendingPathComponent("api/kb/packs")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KBPackServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw KBPackServiceError.serverError(statusCode: httpResponse.statusCode)
        }

        let packsResponse = try JSONDecoder().decode(KBPacksResponse.self, from: data)
        return packsResponse.packs.map { $0.toPack() }
    }
}

// MARK: - Error Types

enum KBPackServiceError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int)
    case networkError(underlying: Error)
    case decodingError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode):
            return "Server error (status code: \(statusCode))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        }
    }
}

// MARK: - Question Response Models

/// Response from questions endpoint
private struct KBQuestionsResponse: Codable {
    let questions: [KBQuestionDTO]
    let total: Int?
}

/// Question DTO from server
private struct KBQuestionDTO: Codable {
    let id: String
    let questionText: String
    let answerText: String
    let domainId: String
    let subcategory: String?
    let difficulty: Int
    let source: String?
    let acceptableAnswers: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case questionText = "question_text"
        case answerText = "answer_text"
        case domainId = "domain_id"
        case subcategory
        case difficulty
        case source
        case acceptableAnswers = "acceptable_answers"
    }

    func toQuestion() -> KBQuestion {
        KBQuestion(
            id: UUID(uuidString: id) ?? UUID(),
            text: questionText,
            answer: KBAnswer(
                primary: answerText,
                acceptable: acceptableAnswers,
                answerType: .text
            ),
            domain: KBDomain(rawValue: domainId) ?? .miscellaneous,
            subdomain: subcategory,
            difficulty: KBDifficulty.from(level: difficulty),
            source: source
        )
    }
}
