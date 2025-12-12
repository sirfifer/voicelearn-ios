// VoiceLearn iOS
// Real-Time Bidirectional Voice AI Platform for Extended Educational Conversations
//
// Entry point for the VoiceLearn application.

import SwiftUI
import Logging

/// Main application entry point
@main
struct VoiceLearnApp: App {
    /// Application state container
    @StateObject private var appState = AppState()
    
    /// Configure logging on app launch
    init() {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .debug
            return handler
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

/// Root content view with tab navigation
struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        TabView {
            SessionView()
                .tabItem {
                    Label("Session", systemImage: "waveform")
                }
            
            CurriculumView()
                .tabItem {
                    Label("Curriculum", systemImage: "book")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            
            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}



// MARK: - App State

/// Central application state container
/// Manages all core services and shared state
///
/// AppState is the central hub that:
/// - Initializes and holds references to all core services
/// - Manages application configuration state
/// - Provides factory methods for creating session managers
/// - Coordinates between subsystems (Telemetry, PatchPanel, Curriculum, etc.)
@MainActor
public class AppState: ObservableObject {

    // MARK: - Core Services

    /// Telemetry engine for metrics tracking
    public let telemetry = TelemetryEngine()

    /// API key manager
    public let apiKeys = APIKeyManager.shared

    /// Patch panel for LLM routing decisions
    /// This is the central routing hub that determines which LLM endpoint
    /// handles each task based on task type, device conditions, and rules.
    public private(set) var patchPanel: PatchPanelService!

    /// Curriculum engine for content management
    @Published public var curriculum: CurriculumEngine?

    /// Session manager (created when session starts)
    @Published public var sessionManager: SessionManager?

    // MARK: - State

    /// Whether the app has all required configuration
    @Published public var isConfigured: Bool = false

    /// Current device capability tier
    @Published public var deviceTier: DeviceCapabilityTier = .proMax

    // MARK: - Initialization

    public init() {
        // Initialize patch panel with telemetry
        self.patchPanel = PatchPanelService(telemetry: telemetry)

        // Detect device capability tier
        self.deviceTier = Self.detectDeviceTier()

        Task {
            await checkConfiguration()
            await initializePatchPanel()
        }
    }

    // MARK: - Configuration

    /// Check if all required API keys are configured
    private func checkConfiguration() async {
        let missingKeys = await apiKeys.validateRequiredKeys()
        await MainActor.run {
            isConfigured = missingKeys.isEmpty
        }

        if isConfigured {
            await initializeCurriculum()
        }
    }

    /// Initialize the patch panel with current endpoint availability
    private func initializePatchPanel() async {
        // Update endpoint availability based on API key presence
        let hasOpenAI = await apiKeys.getKey(.openAI) != nil
        let hasAnthropic = await apiKeys.getKey(.anthropic) != nil

        // Mark cloud endpoints as available/unavailable based on keys
        if hasOpenAI {
            await patchPanel.setEndpointStatus("gpt-4o", status: .available)
            await patchPanel.setEndpointStatus("gpt-4o-mini", status: .available)
        } else {
            await patchPanel.setEndpointStatus("gpt-4o", status: .unavailable)
            await patchPanel.setEndpointStatus("gpt-4o-mini", status: .unavailable)
        }

        if hasAnthropic {
            await patchPanel.setEndpointStatus("claude-3.5-sonnet", status: .available)
            await patchPanel.setEndpointStatus("claude-3.5-haiku", status: .available)
        } else {
            await patchPanel.setEndpointStatus("claude-3.5-sonnet", status: .unavailable)
            await patchPanel.setEndpointStatus("claude-3.5-haiku", status: .unavailable)
        }

        // Self-hosted endpoints start as unavailable until configured
        await patchPanel.setEndpointStatus("llama-70b-server", status: .unavailable)
        await patchPanel.setEndpointStatus("llama-8b-server", status: .unavailable)

        // On-device endpoints start as unavailable until models are loaded
        // In a real implementation, we'd check if models exist on device
        await patchPanel.setEndpointStatus("llama-3b-device", status: .unavailable)
        await patchPanel.setEndpointStatus("llama-1b-device", status: .unavailable)
    }

    private func initializeCurriculum() async {
        guard let openAIKey = await apiKeys.getKey(.openAI) else { return }

        let embeddingService = OpenAIEmbeddingService(apiKey: openAIKey)
        let engine = CurriculumEngineFactory.create(
            persistenceController: .shared,
            embeddingService: embeddingService,
            telemetry: telemetry
        )

        await MainActor.run {
            self.curriculum = engine
        }
    }

    // MARK: - Session Management

    /// Create a new session manager with configured services
    public func createSessionManager() async throws -> SessionManager {
        guard isConfigured else {
            throw SessionError.servicesNotConfigured
        }

        let manager = SessionManager(
            telemetry: telemetry,
            curriculum: curriculum
        )
        sessionManager = manager
        return manager
    }

    // MARK: - Device Tier Detection

    /// Detect the current device's capability tier
    private static func detectDeviceTier() -> DeviceCapabilityTier {
        // Get device identifier
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }

        // Get RAM in GB
        let ramGB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)

        // Tier 1: Pro Max devices with 8GB+ RAM
        let tier1Identifiers: Set<String> = [
            "iPhone15,3",  // iPhone 14 Pro Max
            "iPhone16,2",  // iPhone 15 Pro Max
            "iPhone17,2",  // iPhone 16 Pro Max
            // Simulator
            "x86_64", "arm64"
        ]

        if tier1Identifiers.contains(identifier) && ramGB >= 8 {
            return .proMax
        }

        // Tier 2: Pro devices with 6GB+ RAM
        let tier2Identifiers: Set<String> = [
            "iPhone14,2",  // iPhone 13 Pro
            "iPhone14,3",  // iPhone 13 Pro Max
            "iPhone15,2",  // iPhone 14 Pro
            "iPhone15,3",  // iPhone 14 Pro Max
            "iPhone16,1",  // iPhone 15 Pro
            "iPhone16,2",  // iPhone 15 Pro Max
            "iPhone17,1",  // iPhone 16 Pro
            "iPhone17,2",  // iPhone 16 Pro Max
            // Simulator (treat as tier 2 for testing)
            "x86_64", "arm64"
        ]

        if tier2Identifiers.contains(identifier) && ramGB >= 6 {
            return .proStandard
        }

        // For simulator, default to proStandard for testing
        if identifier == "x86_64" || identifier == "arm64" {
            return .proStandard
        }

        return .unsupported
    }

    // MARK: - Routing Context

    /// Create a routing context with current device/system state
    public func createRoutingContext() -> RoutingContext {
        // In a full implementation, this would query real system state
        // For now, we provide reasonable defaults

        let thermalState: ThermalState
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalState = .nominal
        case .fair: thermalState = .fair
        case .serious: thermalState = .serious
        case .critical: thermalState = .critical
        @unknown default: thermalState = .nominal
        }

        return RoutingContext(
            thermalState: thermalState,
            memoryPressure: .normal,  // Would need to query os_proc_available_memory
            availableMemoryMB: 4000,
            batteryLevel: 1.0,  // Would query UIDevice.current.batteryLevel
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            deviceTier: deviceTier,
            networkType: .wifi,  // Would query NWPathMonitor
            networkLatencyMs: 50.0,
            endpointStatuses: [:],
            endpointLatencies: [:],
            remainingBudget: 1.0,
            estimatedTaskCost: 0.01,
            sessionDurationSeconds: 0,
            promptTokenCount: 0,
            contextTokenCount: 0
        )
    }

    // MARK: - Developer Mode

    /// Enable developer mode for patch panel access
    public func enableDeveloperMode() async {
        await patchPanel.enableDeveloperMode()
    }

    /// Disable developer mode
    public func disableDeveloperMode() async {
        await patchPanel.disableDeveloperMode()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
