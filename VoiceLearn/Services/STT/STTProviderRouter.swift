// VoiceLearn - STT Provider Router
// Routes STT requests to appropriate provider with automatic failover
//
// Features:
// - Routes to GLM-ASR when healthy
// - Automatic failover to Deepgram when unhealthy
// - Health monitoring integration
//
// Related: docs/GLM_ASR_SERVER_TRD.md

import Foundation
@preconcurrency import AVFoundation
import Logging

/// Routes STT requests to appropriate provider with automatic failover
///
/// This router implements the STTService protocol and transparently
/// routes requests to either GLM-ASR (primary) or Deepgram (fallback)
/// based on health status.
public actor STTProviderRouter: STTService {

    // MARK: - Properties

    private let logger = Logger(label: "com.voicelearn.stt.router")

    private let glmASRService: any STTService
    private let deepgramService: any STTService
    private let healthMonitor: GLMASRHealthMonitor

    private var activeProvider: any STTService
    private var healthStatus: GLMASRHealthMonitor.HealthStatus = .healthy
    private var healthMonitorTask: Task<Void, Never>?

    // MARK: - Cached Protocol Properties
    // These are cached to satisfy the non-async protocol requirements

    private var _metrics: STTMetrics = STTMetrics(medianLatency: 0, p99Latency: 0, wordEmissionRate: 0)
    private var _costPerHour: Decimal = 0
    private var _isStreaming: Bool = false

    /// Current provider identifier for debugging/telemetry
    public var currentProviderIdentifier: String {
        if healthStatus == .unhealthy {
            return "deepgram"
        }
        return "glm-asr"
    }

    // MARK: - STTService Protocol Properties

    /// Performance metrics from active provider
    public var metrics: STTMetrics {
        _metrics
    }

    /// Cost per hour from active provider
    public var costPerHour: Decimal {
        _costPerHour
    }

    /// Whether currently streaming
    public var isStreaming: Bool {
        _isStreaming
    }

    /// Update cached metrics from active provider
    private func updateCachedMetrics() async {
        _metrics = await activeProvider.metrics
        _costPerHour = await activeProvider.costPerHour
        _isStreaming = await activeProvider.isStreaming
    }

    // MARK: - Initialization

    /// Initialize STT provider router
    /// - Parameters:
    ///   - glmASRService: Primary GLM-ASR service
    ///   - deepgramService: Fallback Deepgram service
    ///   - healthMonitor: Health monitor for GLM-ASR
    public init(
        glmASRService: any STTService,
        deepgramService: any STTService,
        healthMonitor: GLMASRHealthMonitor
    ) {
        self.glmASRService = glmASRService
        self.deepgramService = deepgramService
        self.healthMonitor = healthMonitor
        self.activeProvider = glmASRService

        logger.info("STTProviderRouter initialized")

        // Start health monitoring
        Task {
            await self.startHealthMonitoring()
        }
    }

    deinit {
        healthMonitorTask?.cancel()
    }

    // MARK: - STTService Protocol Methods

    /// Start streaming transcription
    /// - Parameter audioFormat: Audio format
    /// - Returns: AsyncStream of STT results
    public func startStreaming(audioFormat: AVAudioFormat) async throws -> AsyncStream<STTResult> {
        // Select provider based on health
        activeProvider = selectProvider()
        _isStreaming = true

        let providerName = currentProviderIdentifier
        logger.info("Starting streaming with provider: \(providerName)")

        let stream = try await activeProvider.startStreaming(audioFormat: audioFormat)
        await updateCachedMetrics()
        return stream
    }

    /// Send audio buffer for transcription
    /// - Parameter buffer: Audio buffer to transcribe
    public func sendAudio(_ buffer: AVAudioPCMBuffer) async throws {
        try await activeProvider.sendAudio(buffer)
    }

    /// Stop streaming and get final result
    public func stopStreaming() async throws {
        try await activeProvider.stopStreaming()
        _isStreaming = false
        await updateCachedMetrics()
    }

    /// Cancel streaming without finalizing
    public func cancelStreaming() async {
        await activeProvider.cancelStreaming()
        _isStreaming = false
        await updateCachedMetrics()
    }

    // MARK: - Private Methods

    private func startHealthMonitoring() async {
        let healthStream = await healthMonitor.startMonitoring()

        healthMonitorTask = Task {
            for await status in healthStream {
                await self.handleHealthStatusChange(status)
            }
        }
    }

    private func handleHealthStatusChange(_ status: GLMASRHealthMonitor.HealthStatus) async {
        let previousStatus = healthStatus
        healthStatus = status

        if previousStatus != status {
            logger.info("Health status changed: \(previousStatus) → \(status)")

            // If currently streaming and provider changed, log but don't interrupt
            // Next streaming session will use new provider
            let isCurrentlyStreaming = await activeProvider.isStreaming
            if status == .unhealthy && isCurrentlyStreaming {
                logger.warning("GLM-ASR became unhealthy during streaming - will switch on next session")
            }
        }
    }

    private func selectProvider() -> any STTService {
        switch healthStatus {
        case .healthy, .degraded:
            logger.debug("Selecting GLM-ASR (status: \(healthStatus))")
            return glmASRService
        case .unhealthy:
            logger.debug("Selecting Deepgram (GLM-ASR unhealthy)")
            return deepgramService
        }
    }
}

// MARK: - Protocol for Mock Health Monitor (Testing)

/// Protocol for mock health monitor in tests
public protocol HealthMonitorProtocol: Actor {
    var currentStatus: GLMASRHealthMonitor.HealthStatus { get async }
    func startMonitoring() async -> AsyncStream<GLMASRHealthMonitor.HealthStatus>
    func stopMonitoring() async
}

// Make GLMASRHealthMonitor conform
extension GLMASRHealthMonitor: HealthMonitorProtocol {}
