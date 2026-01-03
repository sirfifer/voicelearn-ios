// UnaMentis - Metrics Upload Service
// Uploads session metrics to the management server
//
// Part of the Analytics Pipeline

import Foundation
import Logging
import UIKit

/// Service for uploading metrics to the management server
public actor MetricsUploadService {

    // MARK: - Properties

    private let logger = Logger(label: "com.unamentis.metrics.upload")
    private let queue: MetricsUploadQueue
    private var serverURL: URL?
    private var isUploading = false

    /// Device ID for client identification (set from MainActor context)
    private var clientId: String

    /// Device name for display (set from MainActor context)
    private var clientName: String

    // MARK: - Initialization

    public init() {
        self.queue = MetricsUploadQueue()

        // Use stored device ID or generate new one
        // Real device info will be set via configureDeviceInfo() from MainActor
        if let storedId = UserDefaults.standard.string(forKey: "MetricsClientId") {
            self.clientId = storedId
        } else {
            self.clientId = UUID().uuidString
            UserDefaults.standard.set(self.clientId, forKey: "MetricsClientId")
        }
        self.clientName = UserDefaults.standard.string(forKey: "MetricsClientName") ?? "UnaMentis Client"

        // Capture value for logging to avoid autoclosure isolation issue
        let logClientId = self.clientId
        logger.info("MetricsUploadService initialized with clientId: \(logClientId)")
    }

    /// Configure device identification from MainActor context
    @MainActor
    public func configureDeviceInfo() async {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let deviceName = UIDevice.current.name

        // Store for persistence
        UserDefaults.standard.set(deviceId, forKey: "MetricsClientId")
        UserDefaults.standard.set(deviceName, forKey: "MetricsClientName")

        await updateDeviceInfo(id: deviceId, name: deviceName)
    }

    private func updateDeviceInfo(id: String, name: String) {
        self.clientId = id
        self.clientName = name
        logger.info("Device info updated: \(id) - \(name)")
    }

    // MARK: - Configuration

    /// Configure the server URL for uploads
    public func configure(serverHost: String, port: Int = 8766) {
        self.serverURL = URL(string: "http://\(serverHost):\(port)/api/metrics")
        logger.info("Configured server URL: \(serverURL?.absoluteString ?? "nil")")
    }

    // MARK: - Upload Methods

    /// Upload a metrics snapshot to the server
    /// - Parameters:
    ///   - snapshot: The metrics snapshot to upload
    ///   - sessionDuration: Duration of the session in seconds
    public func upload(_ snapshot: MetricsSnapshot, sessionDuration: TimeInterval) async {
        guard let serverURL = serverURL else {
            logger.warning("Server URL not configured, queuing metrics for later")
            await queue.enqueue(snapshot, sessionDuration: sessionDuration)
            return
        }

        // Transform to server format
        let payload = transformToServerFormat(snapshot, sessionDuration: sessionDuration)

        do {
            try await sendToServer(payload, to: serverURL)
            logger.info("Successfully uploaded metrics to server")
        } catch {
            logger.warning("Failed to upload metrics: \(error.localizedDescription), queuing for retry")
            await queue.enqueue(snapshot, sessionDuration: sessionDuration)
        }
    }

    /// Attempt to drain the offline queue
    public func drainQueue() async {
        guard let serverURL = serverURL else {
            logger.debug("Cannot drain queue: server URL not configured")
            return
        }

        guard !isUploading else {
            logger.debug("Already uploading, skipping queue drain")
            return
        }

        isUploading = true
        defer { isUploading = false }

        let pending = await queue.getPending()
        logger.info("Draining queue with \(pending.count) pending uploads")

        for item in pending {
            do {
                try await sendToServer(item.payload, to: serverURL)
                await queue.markCompleted(item.id)
                logger.info("Successfully uploaded queued metrics \(item.id)")
            } catch {
                logger.warning("Failed to upload queued metrics \(item.id): \(error.localizedDescription)")
                // Stop on first failure - will retry later
                break
            }
        }
    }

    // MARK: - Private Methods

    private func transformToServerFormat(_ snapshot: MetricsSnapshot, sessionDuration: TimeInterval) -> [String: Any] {
        // Transform nested iOS format to flat server format
        return [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "sessionDuration": sessionDuration,
            "turnsTotal": snapshot.quality.turnsTotal,
            "interruptions": snapshot.quality.interruptions,
            "sttLatencyMedian": snapshot.latencies.sttMedianMs,
            "sttLatencyP99": snapshot.latencies.sttP99Ms,
            "llmTTFTMedian": snapshot.latencies.llmMedianMs,
            "llmTTFTP99": snapshot.latencies.llmP99Ms,
            "ttsTTFBMedian": snapshot.latencies.ttsMedianMs,
            "ttsTTFBP99": snapshot.latencies.ttsP99Ms,
            "e2eLatencyMedian": snapshot.latencies.e2eMedianMs,
            "e2eLatencyP99": snapshot.latencies.e2eP99Ms,
            "sttCost": NSDecimalNumber(decimal: snapshot.costs.sttTotal).doubleValue,
            "ttsCost": NSDecimalNumber(decimal: snapshot.costs.ttsTotal).doubleValue,
            "llmCost": NSDecimalNumber(decimal: snapshot.costs.llmTotal).doubleValue,
            "totalCost": NSDecimalNumber(decimal: snapshot.costs.totalSession).doubleValue,
            "thermalThrottleEvents": snapshot.quality.thermalThrottleEvents,
            "networkDegradations": snapshot.quality.networkDegradations,
            // Additional iOS-specific fields
            "llmInputTokens": snapshot.costs.llmInputTokens,
            "llmOutputTokens": snapshot.costs.llmOutputTokens,
            "interruptionSuccessRate": snapshot.quality.interruptionSuccessRate
        ]
    }

    private func sendToServer(_ payload: [String: Any], to url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(clientId, forHTTPHeaderField: "X-Client-ID")
        request.setValue(clientName, forHTTPHeaderField: "X-Client-Name")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 10

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MetricsUploadError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw MetricsUploadError.serverError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Upload Errors

public enum MetricsUploadError: Error, LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int)
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode):
            return "Server error: HTTP \(statusCode)"
        case .networkUnavailable:
            return "Network unavailable"
        }
    }
}
