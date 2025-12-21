// UnaMentis - Telemetry Engine
// Comprehensive telemetry for latency, cost, and performance tracking
//
// Part of Core Components (TDD Section 3)

import Foundation
import Logging

// MARK: - Telemetry Event Types

/// Events tracked by telemetry
public enum TelemetryEvent: Sendable {
    // Session events
    case sessionStarted
    case sessionEnded(duration: TimeInterval)
    
    // Audio engine events
    case audioEngineConfigured(AudioEngineConfig)
    case audioEngineStarted
    case audioEngineStopped
    case thermalStateChanged(ProcessInfo.ThermalState)
    case adaptiveQualityAdjusted(reason: String)
    
    // VAD events
    case vadSpeechDetected(confidence: Float)
    case vadSilenceDetected(duration: TimeInterval)
    
    // STT events  
    case sttPartialReceived(transcript: String, isFinal: Bool)
    case sttStreamFailed(Error)
    
    // User interaction events
    case userStartedSpeaking
    case userFinishedSpeaking(transcript: String)
    case userInterrupted
    
    // AI events
    case aiStartedSpeaking
    case aiFinishedSpeaking
    case llmFirstTokenReceived
    case llmStreamFailed(Error)
    
    // TTS events
    case ttsChunkCompleted(text: String, duration: TimeInterval)
    case ttsStreamFailed(Error)
    case ttsPlaybackStarted
    case ttsPlaybackCompleted
    case ttsPlaybackInterrupted
    case ttsPlaybackPaused
    case ttsPlaybackResumed
    
    // Curriculum events
    case topicStarted(topic: String)
    case topicCompleted(topic: String, timeSpent: TimeInterval, mastery: Float)
    
    // Context management
    case contextCompressed(from: Int, to: Int)
}

/// Categories for latency tracking
public enum LatencyType: String, Sendable {
    case audioProcessing = "audio_processing"
    case sttEmission = "stt_emission"
    case llmFirstToken = "llm_first_token"
    case ttsTTFB = "tts_ttfb"
    case ttsTimeToFirstByte = "tts_time_to_first_byte"
    case endToEndTurn = "e2e_turn"
}

/// Categories for cost tracking
public enum CostType: String, Sendable {
    case stt = "stt"
    case tts = "tts"
    case llmInput = "llm_input"
    case llmOutput = "llm_output"
}

// MARK: - Recorded Event

/// A recorded telemetry event with timestamp
public struct RecordedEvent: Sendable {
    public let timestamp: Date
    public let event: TelemetryEvent
    
    public init(timestamp: Date = Date(), event: TelemetryEvent) {
        self.timestamp = timestamp
        self.event = event
    }
}

// MARK: - Session Metrics

/// Aggregated metrics for a session
public struct SessionMetrics: Sendable {
    // Duration
    public var duration: TimeInterval
    
    // Latency arrays
    public var sttLatencies: [TimeInterval]
    public var llmLatencies: [TimeInterval]
    public var ttsLatencies: [TimeInterval]
    public var e2eLatencies: [TimeInterval]
    
    // Costs
    public var sttCost: Decimal
    public var ttsCost: Decimal
    public var llmCost: Decimal
    
    // Counts
    public var turnsTotal: Int
    public var interruptions: Int
    public var thermalThrottleEvents: Int
    public var networkDegradations: Int
    
    /// Total cost across all categories
    public var totalCost: Decimal {
        sttCost + ttsCost + llmCost
    }
    
    /// Cost per hour based on session duration
    public var costPerHour: Double {
        guard duration > 0 else { return 0 }
        let costDouble = NSDecimalNumber(decimal: totalCost).doubleValue
        return costDouble * (3600.0 / duration)
    }
    
    public init() {
        duration = 0
        sttLatencies = []
        llmLatencies = []
        ttsLatencies = []
        e2eLatencies = []
        sttCost = 0
        ttsCost = 0
        llmCost = 0
        turnsTotal = 0
        interruptions = 0
        thermalThrottleEvents = 0
        networkDegradations = 0
    }
}

// MARK: - Telemetry Engine

/// Central telemetry engine for tracking all metrics
///
/// Tracks:
/// - Latency metrics (STT, LLM, TTS, E2E)
/// - Cost metrics (by provider type)
/// - Events (for debugging and analysis)
/// - Session metrics (duration, turns, interruptions)
public actor TelemetryEngine: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(label: "com.unamentis.telemetry")
    
    /// Current session metrics
    private var metrics = SessionMetrics()
    
    /// Session start time
    private var sessionStartTime: Date?
    
    /// Recent events (limited buffer)
    private var events: [RecordedEvent] = []
    private let maxEventBuffer = 1000
    
    /// Published metrics for UI observation
    @MainActor @Published public private(set) var currentMetricsPublished = SessionMetrics()

    /// Published device metrics for UI observation
    @MainActor @Published public private(set) var deviceMetrics = DeviceMetrics()

    /// Device metrics sampling task
    private var deviceMetricsSamplingTask: Task<Void, Never>?

    /// Device metrics history (for averaging)
    private var deviceMetricsHistory: [DeviceMetrics] = []
    private let maxMetricsHistory = 60 // Keep 1 minute of samples at 1/sec

    // MARK: - Initialization

    public init() {
        logger.info("TelemetryEngine initialized")
    }
    
    // MARK: - Public API
    
    /// Get current metrics
    public var currentMetrics: SessionMetrics {
        var current = metrics
        if let startTime = sessionStartTime {
            current.duration = Date().timeIntervalSince(startTime)
        }
        return current
    }
    
    /// Get recent events
    public var recentEvents: [RecordedEvent] {
        events
    }
    
    /// Start a new session
    public func startSession() {
        sessionStartTime = Date()
        metrics = SessionMetrics()
        events.removeAll()
        logger.info("Session started")
        recordEvent(.sessionStarted)
    }
    
    /// End the current session
    public func endSession() {
        guard let startTime = sessionStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        recordEvent(.sessionEnded(duration: duration))
        logger.info("Session ended", metadata: [
            "duration": .stringConvertible(duration),
            "total_cost": .stringConvertible(metrics.totalCost)
        ])
    }
    
    /// Record a telemetry event
    public func recordEvent(_ event: TelemetryEvent) {
        // Add to buffer
        events.append(RecordedEvent(event: event))
        if events.count > maxEventBuffer {
            events.removeFirst(events.count - maxEventBuffer)
        }
        
        // Track specific metrics
        switch event {
        case .userFinishedSpeaking:
            metrics.turnsTotal += 1
        case .userInterrupted:
            metrics.interruptions += 1
        case .thermalStateChanged:
            metrics.thermalThrottleEvents += 1
        default:
            break
        }
        
        // Log event
        logger.debug("Event: \(String(describing: event))")
        
        // Update published metrics - capture values first
        let currentMetrics = metrics
        let startTime = sessionStartTime
        Task { @MainActor in
            var current = currentMetrics
            if let time = startTime {
                current.duration = Date().timeIntervalSince(time)
            }
            currentMetricsPublished = current
        }
    }
    
    /// Record an error
    public func recordError(_ error: Error) {
        logger.error("Error: \(error.localizedDescription)")
    }
    
    /// Record a latency measurement
    public func recordLatency(_ type: LatencyType, _ value: TimeInterval) {
        switch type {
        case .sttEmission:
            metrics.sttLatencies.append(value)
        case .llmFirstToken:
            metrics.llmLatencies.append(value)
        case .ttsTTFB, .ttsTimeToFirstByte:
            metrics.ttsLatencies.append(value)
        case .endToEndTurn:
            metrics.e2eLatencies.append(value)
        case .audioProcessing:
            // Not stored in session metrics, just logged
            break
        }
        
        logger.debug("Latency \(type.rawValue): \(value * 1000)ms")
    }
    
    /// Record a cost
    public func recordCost(_ type: CostType, amount: Decimal, description: String) {
        switch type {
        case .stt:
            metrics.sttCost += amount
        case .tts:
            metrics.ttsCost += amount
        case .llmInput, .llmOutput:
            metrics.llmCost += amount
        }
        
        logger.debug("Cost \(type.rawValue): $\(amount) - \(description)")
    }
    
    /// Reset all metrics
    public func reset() {
        metrics = SessionMetrics()
        events.removeAll()
        sessionStartTime = nil
        deviceMetricsHistory.removeAll()
        logger.info("TelemetryEngine reset")
    }

    // MARK: - Device Metrics

    /// Start sampling device metrics periodically
    public func startDeviceMetricsSampling(interval: TimeInterval = 1.0) {
        stopDeviceMetricsSampling()

        logger.info("Starting device metrics sampling at \(interval)s interval")

        deviceMetricsSamplingTask = Task {
            while !Task.isCancelled {
                let sample = DeviceMetricsCollector.sample()

                // Store in history
                deviceMetricsHistory.append(sample)
                if deviceMetricsHistory.count > maxMetricsHistory {
                    deviceMetricsHistory.removeFirst()
                }

                // Log if under stress
                if sample.isUnderStress {
                    logger.warning("Device under stress: CPU=\(String(format: "%.1f", sample.cpuUsage))%, Memory=\(sample.memoryUsedString), Thermal=\(sample.thermalStateString)")
                }

                // Publish to UI
                await MainActor.run {
                    deviceMetrics = sample
                }

                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    /// Stop sampling device metrics
    public func stopDeviceMetricsSampling() {
        deviceMetricsSamplingTask?.cancel()
        deviceMetricsSamplingTask = nil
    }

    /// Get average device metrics over recent history
    public func getAverageDeviceMetrics() -> DeviceMetrics {
        guard !deviceMetricsHistory.isEmpty else {
            return DeviceMetrics()
        }

        let avgCPU = deviceMetricsHistory.map { $0.cpuUsage }.reduce(0, +) / Double(deviceMetricsHistory.count)
        let avgMemory = deviceMetricsHistory.map { $0.memoryUsed }.reduce(0, +) / UInt64(deviceMetricsHistory.count)
        let worstThermal = deviceMetricsHistory.map { $0.thermalState.rawValue }.max() ?? 0

        return DeviceMetrics(
            cpuUsage: avgCPU,
            memoryUsed: avgMemory,
            memoryTotal: deviceMetricsHistory.first?.memoryTotal ?? 0,
            thermalState: ProcessInfo.ThermalState(rawValue: worstThermal) ?? .nominal,
            timestamp: Date()
        )
    }

    /// Get peak device metrics over recent history
    public func getPeakDeviceMetrics() -> DeviceMetrics {
        guard !deviceMetricsHistory.isEmpty else {
            return DeviceMetrics()
        }

        let peakCPU = deviceMetricsHistory.map { $0.cpuUsage }.max() ?? 0
        let peakMemory = deviceMetricsHistory.map { $0.memoryUsed }.max() ?? 0
        let worstThermal = deviceMetricsHistory.map { $0.thermalState.rawValue }.max() ?? 0

        return DeviceMetrics(
            cpuUsage: peakCPU,
            memoryUsed: peakMemory,
            memoryTotal: deviceMetricsHistory.first?.memoryTotal ?? 0,
            thermalState: ProcessInfo.ThermalState(rawValue: worstThermal) ?? .nominal,
            timestamp: Date()
        )
    }
    
    /// Export metrics as a snapshot for persistence/analysis
    public func exportMetrics() -> MetricsSnapshot {
        let latencies = LatencyMetrics(
            sttMedianMs: Int(metrics.sttLatencies.median * 1000),
            sttP99Ms: Int(metrics.sttLatencies.percentile(99) * 1000),
            llmMedianMs: Int(metrics.llmLatencies.median * 1000),
            llmP99Ms: Int(metrics.llmLatencies.percentile(99) * 1000),
            ttsMedianMs: Int(metrics.ttsLatencies.median * 1000),
            ttsP99Ms: Int(metrics.ttsLatencies.percentile(99) * 1000),
            e2eMedianMs: Int(metrics.e2eLatencies.median * 1000),
            e2eP99Ms: Int(metrics.e2eLatencies.percentile(99) * 1000)
        )
        
        let costs = CostMetrics(
            sttTotal: metrics.sttCost,
            ttsTotal: metrics.ttsCost,
            llmInputTokens: 0, // Would need token tracking
            llmOutputTokens: 0,
            llmTotal: metrics.llmCost,
            totalSession: metrics.totalCost
        )
        
        let quality = QualityMetrics(
            turnsTotal: metrics.turnsTotal,
            interruptions: metrics.interruptions,
            interruptionSuccessRate: metrics.turnsTotal > 0 ? Float(metrics.interruptions) / Float(metrics.turnsTotal) : 0,
            thermalThrottleEvents: metrics.thermalThrottleEvents,
            networkDegradations: metrics.networkDegradations
        )
        
        return MetricsSnapshot(
            latencies: latencies,
            costs: costs,
            quality: quality
        )
    }
}

// MARK: - Metrics Snapshot Types (for export)

public struct MetricsSnapshot: Codable, Sendable {
    public let latencies: LatencyMetrics
    public let costs: CostMetrics
    public let quality: QualityMetrics
}

public struct LatencyMetrics: Codable, Sendable {
    public let sttMedianMs: Int
    public let sttP99Ms: Int
    public let llmMedianMs: Int
    public let llmP99Ms: Int
    public let ttsMedianMs: Int
    public let ttsP99Ms: Int
    public let e2eMedianMs: Int
    public let e2eP99Ms: Int
}

public struct CostMetrics: Codable, Sendable {
    public let sttTotal: Decimal
    public let ttsTotal: Decimal
    public let llmInputTokens: Int
    public let llmOutputTokens: Int
    public let llmTotal: Decimal
    public let totalSession: Decimal
}

public struct QualityMetrics: Codable, Sendable {
    public let turnsTotal: Int
    public let interruptions: Int
    public let interruptionSuccessRate: Float
    public let thermalThrottleEvents: Int
    public let networkDegradations: Int
}

// MARK: - Device Metrics

/// Real-time device health metrics
public struct DeviceMetrics: Sendable {
    /// CPU usage percentage (0-100)
    public let cpuUsage: Double

    /// Memory usage in bytes
    public let memoryUsed: UInt64

    /// Total memory in bytes
    public let memoryTotal: UInt64

    /// Memory usage percentage (0-100)
    public var memoryUsagePercent: Double {
        memoryTotal > 0 ? Double(memoryUsed) / Double(memoryTotal) * 100 : 0
    }

    /// Thermal state
    public let thermalState: ProcessInfo.ThermalState

    /// Timestamp of sample
    public let timestamp: Date

    public init(
        cpuUsage: Double = 0,
        memoryUsed: UInt64 = 0,
        memoryTotal: UInt64 = 0,
        thermalState: ProcessInfo.ThermalState = .nominal,
        timestamp: Date = Date()
    ) {
        self.cpuUsage = cpuUsage
        self.memoryUsed = memoryUsed
        self.memoryTotal = memoryTotal
        self.thermalState = thermalState
        self.timestamp = timestamp
    }

    /// Thermal state as human-readable string
    public var thermalStateString: String {
        switch thermalState {
        case .nominal: return "Normal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    /// Memory used as human-readable string
    public var memoryUsedString: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryUsed), countStyle: .memory)
    }

    /// Whether device is under stress
    public var isUnderStress: Bool {
        cpuUsage > 80 || memoryUsagePercent > 85 || thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    }
}

// MARK: - Device Metrics Collector

/// Collects device health metrics using system APIs
public struct DeviceMetricsCollector: Sendable {

    /// Sample current device metrics
    public static func sample() -> DeviceMetrics {
        return DeviceMetrics(
            cpuUsage: getCPUUsage(),
            memoryUsed: getMemoryUsage(),
            memoryTotal: getMemoryTotal(),
            thermalState: ProcessInfo.processInfo.thermalState,
            timestamp: Date()
        )
    }

    /// Get CPU usage percentage (0-100)
    private static func getCPUUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadsList = UnsafeMutablePointer(mutating: [thread_act_t]())
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }

        guard threadsResult == KERN_SUCCESS else {
            return 0
        }

        for index in 0..<threadsCount {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(threadInfoCount)) {
                    thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }

            guard infoResult == KERN_SUCCESS else { continue }

            let threadBasicInfo = threadInfo
            if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                totalUsageOfCPU += Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threadsList), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))

        return min(totalUsageOfCPU, 100.0)
    }

    /// Get memory used by this process in bytes
    private static func getMemoryUsage() -> UInt64 {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0
        }

        return taskInfo.phys_footprint
    }

    /// Get total physical memory
    private static func getMemoryTotal() -> UInt64 {
        return ProcessInfo.processInfo.physicalMemory
    }
}

// MARK: - Array Extensions for Statistics

extension Array where Element == TimeInterval {
    /// Calculate median of array
    public var median: TimeInterval {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[mid] + sorted[mid - 1]) / 2
            : sorted[mid]
    }

    /// Calculate percentile (0-100)
    public func percentile(_ p: Int) -> TimeInterval {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let index = Int(Double(sorted.count) * Double(p) / 100.0)
        let clampedIndex = Swift.min(index, sorted.count - 1)
        return sorted[clampedIndex]
    }
}
