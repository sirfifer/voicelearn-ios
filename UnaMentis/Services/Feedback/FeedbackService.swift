// UnaMentis - Feedback Service
// Actor-based service for submitting feedback to management console
//
// Follows UnaMentis pattern: actor-based services with Sendable types
// Part of Beta Testing infrastructure

import Foundation
import UIKit

/// Actor-based service for submitting feedback to management console
/// Thread-safe with Swift 6 strict concurrency compliance
public actor FeedbackService {
    public static let shared = FeedbackService()

    private var session: URLSession
    private var baseURL: URL?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpAdditionalHeaders = ["Content-Type": "application/json"]
        self.session = URLSession(configuration: config)
    }

    /// Configure the service with management console endpoint
    /// - Parameters:
    ///   - host: Server IP/hostname
    ///   - port: Management console port (default 8766)
    /// - Throws: `FeedbackServiceError.invalidURL` if URL is malformed
    public func configure(host: String, port: Int = 8766) throws {
        guard let url = URL(string: "http://\(host):\(port)/api") else {
            throw FeedbackServiceError.invalidURL
        }
        self.baseURL = url
    }

    /// Submit feedback to management console
    /// - Parameters:
    ///   - feedback: Feedback entity from Core Data
    ///   - context: Captured app context
    ///   - diagnostics: Optional device diagnostics (requires user consent)
    /// - Returns: Server response with confirmation
    /// - Throws: Various `FeedbackServiceError` cases for different failure modes
    public func submitFeedback(
        _ feedback: Feedback,
        context: FeedbackContext,
        diagnostics: DeviceDiagnostics?
    ) async throws -> FeedbackResponse {
        guard let baseURL = baseURL else {
            throw FeedbackServiceError.notConfigured
        }

        let url = baseURL.appendingPathComponent("feedback")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Device identification headers (anonymized per GDPR/CCPA)
        let deviceId = await UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let deviceName = await UIDevice.current.name
        request.setValue(deviceId, forHTTPHeaderField: "X-Client-ID")
        request.setValue(deviceName, forHTTPHeaderField: "X-Client-Name")

        let payload = FeedbackPayload(
            id: feedback.id!.uuidString,
            timestamp: ISO8601DateFormatter().string(from: feedback.timestamp!),
            category: feedback.category ?? "other",
            rating: feedback.rating > 0 ? Int(feedback.rating) : nil,
            message: feedback.message ?? "",
            currentScreen: context.currentScreen,
            navigationPath: context.navigationPath,
            sessionId: feedback.session?.id?.uuidString,
            topicId: feedback.topic?.id?.uuidString,
            sessionDurationSeconds: context.sessionDuration.map { Int($0) },
            sessionState: context.sessionState,
            turnCount: context.turnCount,
            deviceModel: await UIDevice.current.model,
            iOSVersion: await UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            includedDiagnostics: diagnostics != nil,
            memoryUsageMB: diagnostics?.memoryUsageMB,
            batteryLevel: diagnostics?.batteryLevel,
            networkType: diagnostics?.networkType,
            lowPowerMode: diagnostics?.lowPowerMode
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedbackServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8)
            throw FeedbackServiceError.serverError(httpResponse.statusCode, errorBody ?? "Unknown error")
        }

        let result = try JSONDecoder().decode(FeedbackResponse.self, from: data)
        return result
    }
}

// MARK: - Data Types (Sendable for actor isolation)

/// Payload sent to management console
public struct FeedbackPayload: Codable, Sendable {
    let id: String
    let timestamp: String
    let category: String
    let rating: Int?
    let message: String
    let currentScreen: String
    let navigationPath: [String]
    let sessionId: String?
    let topicId: String?
    let sessionDurationSeconds: Int?
    let sessionState: String?
    let turnCount: Int?
    let deviceModel: String
    let iOSVersion: String
    let appVersion: String
    let includedDiagnostics: Bool
    let memoryUsageMB: Int?
    let batteryLevel: Float?
    let networkType: String?
    let lowPowerMode: Bool?
}

/// Response from management console
public struct FeedbackResponse: Codable, Sendable {
    let status: String
    let id: String?
}

/// Errors that can occur during feedback submission
public enum FeedbackServiceError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return String(localized: "feedback.error.not.configured")
        case .invalidURL:
            return String(localized: "feedback.error.invalid.url")
        case .invalidResponse:
            return String(localized: "feedback.error.invalid.response")
        case .serverError(let code, let message):
            return String(format: String(localized: "feedback.error.server %d %@"), code, message)
        case .networkError(let message):
            return String(format: String(localized: "feedback.error.network %@"), message)
        }
    }
}
