// UnaMentis - Metrics Upload Queue
// Persistent queue for offline metrics storage
//
// Part of the Analytics Pipeline

import Foundation
import Logging

/// Persistent queue for metrics that couldn't be uploaded
public actor MetricsUploadQueue {

    // MARK: - Types

    public struct QueuedMetrics: Codable, Sendable {
        public let id: UUID
        public let payload: [String: AnyCodable]
        public let queuedAt: Date
        public let retryCount: Int

        public init(id: UUID = UUID(), payload: [String: Any], queuedAt: Date = Date(), retryCount: Int = 0) {
            self.id = id
            self.payload = payload.mapValues { AnyCodable($0) }
            self.queuedAt = queuedAt
            self.retryCount = retryCount
        }
    }

    // MARK: - Properties

    private let logger = Logger(label: "com.unamentis.metrics.queue")
    private var queue: [QueuedMetrics] = []
    private let maxQueueSize = 100
    private let maxRetries = 5
    private let storageKey = "MetricsUploadQueue"

    // MARK: - Initialization

    public init() {
        // Load from storage synchronously in init
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let loaded = try? JSONDecoder().decode([QueuedMetrics].self, from: data) {
            self.queue = loaded
            logger.info("Loaded \(loaded.count) queued metrics from storage")
        }
    }

    // MARK: - Queue Operations

    /// Add metrics to the queue
    public func enqueue(_ snapshot: MetricsSnapshot, sessionDuration: TimeInterval) async {
        let payload = transformToPayload(snapshot, sessionDuration: sessionDuration)
        let item = QueuedMetrics(payload: payload)

        queue.append(item)

        // Trim if over capacity
        if queue.count > maxQueueSize {
            queue.removeFirst(queue.count - maxQueueSize)
            logger.warning("Queue exceeded max size, trimmed to \(maxQueueSize)")
        }

        saveToStorage()
        logger.info("Enqueued metrics, queue size: \(queue.count)")
    }

    /// Get all pending items
    public func getPending() -> [QueuedMetrics] {
        return queue.filter { $0.retryCount < maxRetries }
    }

    /// Mark an item as completed (remove from queue)
    public func markCompleted(_ id: UUID) {
        queue.removeAll { $0.id == id }
        saveToStorage()
    }

    /// Increment retry count for an item
    public func incrementRetry(_ id: UUID) {
        if let index = queue.firstIndex(where: { $0.id == id }) {
            let item = queue[index]
            queue[index] = QueuedMetrics(
                id: item.id,
                payload: item.payload.mapValues { $0.value },
                queuedAt: item.queuedAt,
                retryCount: item.retryCount + 1
            )
            saveToStorage()
        }
    }

    /// Get queue size
    public var count: Int {
        queue.count
    }

    /// Clear the queue
    public func clear() {
        queue.removeAll()
        saveToStorage()
    }

    // MARK: - Persistence

    private func saveToStorage() {
        do {
            let data = try JSONEncoder().encode(queue)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            logger.error("Failed to save queued metrics: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func transformToPayload(_ snapshot: MetricsSnapshot, sessionDuration: TimeInterval) -> [String: Any] {
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
            "llmInputTokens": snapshot.costs.llmInputTokens,
            "llmOutputTokens": snapshot.costs.llmOutputTokens,
            "interruptionSuccessRate": snapshot.quality.interruptionSuccessRate
        ]
    }
}

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for heterogeneous dictionary values
/// Uses @unchecked Sendable since we only store primitive types (Int, Double, String, Bool) and their collections
public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
