// VoiceLearn - Session View
// Main voice conversation UI
//
// Part of UI/UX (TDD Section 10)

import SwiftUI
import Combine

#if os(macOS)
import AppKit
#endif

/// Main session view for voice conversations
public struct SessionView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SessionViewModel()

    #if os(iOS)
    private static let backgroundGradientColors: [Color] = [Color(.systemBackground), Color(.systemGray6)]
    #else
    private static let backgroundGradientColors: [Color] = [Color(NSColor.windowBackgroundColor), Color(NSColor.controlBackgroundColor)]
    #endif

    public init() { }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: Self.backgroundGradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Status indicator
                    SessionStatusView(state: viewModel.state)
                        .padding(.top, 20)
                    
                    Spacer()
                    
                    // Transcript display
                    TranscriptView(
                        userTranscript: viewModel.userTranscript,
                        aiResponse: viewModel.aiResponse
                    )
                    .frame(maxHeight: 300)
                    
                    Spacer()
                    
                    // Audio level visualizer
                    AudioLevelView(level: viewModel.audioLevel)
                        .frame(height: 60)
                    
                    // Main control button
                    SessionControlButton(
                        isActive: viewModel.isSessionActive,
                        isLoading: viewModel.isLoading,
                        action: {
                            await viewModel.toggleSession(appState: appState)
                        }
                    )
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Voice Session")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.isSessionActive {
                        MetricsBadge(
                            latency: viewModel.lastLatency,
                            cost: viewModel.sessionCost
                        )
                    }
                }
            }
            #endif
            .sheet(isPresented: $viewModel.showSettings) {
                SessionSettingsView()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { viewModel.showError = false }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

// MARK: - Session Status View

struct SessionStatusView: View {
    let state: SessionState
    
    var body: some View {
        HStack(spacing: 12) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .overlay {
                    if state.isActive {
                        Circle()
                            .stroke(statusColor.opacity(0.5), lineWidth: 2)
                            .scaleEffect(1.5)
                            .opacity(0.7)
                    }
                }
            
            Text(state.rawValue)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
        }
    }
    
    private var statusColor: Color {
        switch state {
        case .idle: return .gray
        case .userSpeaking: return .green
        case .aiThinking: return .orange
        case .aiSpeaking: return .blue
        case .interrupted: return .yellow
        case .processingUserUtterance: return .purple
        case .error: return .red
        }
    }
}

// MARK: - Transcript View

struct TranscriptView: View {
    let userTranscript: String
    let aiResponse: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !userTranscript.isEmpty {
                    TranscriptBubble(
                        text: userTranscript,
                        isUser: true
                    )
                }
                
                if !aiResponse.isEmpty {
                    TranscriptBubble(
                        text: aiResponse,
                        isUser: false
                    )
                }
            }
            .padding()
        }
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
}

struct TranscriptBubble: View {
    let text: String
    let isUser: Bool
    
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            
            Text(text)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        #if os(iOS)
                        .fill(isUser ? Color.blue : Color(.systemGray5))
                        #else
                        .fill(isUser ? Color.blue : Color(NSColor.controlBackgroundColor))
                        #endif
                }
                .foregroundStyle(isUser ? .white : .primary)
            
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Audio Level View

struct AudioLevelView: View {
    let level: Float
    
    private let barCount = 20
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 8)
                    .scaleEffect(y: barScale(for: index), anchor: .bottom)
                    .animation(.easeOut(duration: 0.1), value: level)
            }
        }
        .frame(height: 40)
    }
    
    private func barScale(for index: Int) -> CGFloat {
        // Convert dB to 0-1 range (-60dB to 0dB)
        let normalizedLevel = max(0, min(1, (level + 60) / 60))
        let threshold = Float(index) / Float(barCount)
        return normalizedLevel > threshold ? 1.0 : 0.2
    }
    
    private func barColor(for index: Int) -> Color {
        let ratio = Float(index) / Float(barCount)
        if ratio < 0.6 {
            return .green
        } else if ratio < 0.8 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Session Control Button

struct SessionControlButton: View {
    let isActive: Bool
    let isLoading: Bool
    let action: () async -> Void
    
    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isActive ? Color.red : Color.blue)
                    .frame(width: 80, height: 80)
                    .shadow(color: (isActive ? Color.red : Color.blue).opacity(0.4), radius: 10)
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: isActive ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                }
            }
        }
        .disabled(isLoading)
        .scaleEffect(isActive ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isActive)
    }
}

// MARK: - Metrics Badge

struct MetricsBadge: View {
    let latency: TimeInterval
    let cost: Decimal
    
    var body: some View {
        HStack(spacing: 8) {
            // Latency
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.caption2)
                Text(String(format: "%.0fms", latency * 1000))
                    .font(.caption.monospacedDigit())
            }
            
            // Cost
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle")
                    .font(.caption2)
                Text(String(format: "$%.3f", NSDecimalNumber(decimal: cost).doubleValue))
                    .font(.caption.monospacedDigit())
            }
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Session Settings View

struct SessionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = SessionSettingsModel()

    var body: some View {
        NavigationStack {
            List {
                // MARK: Audio Settings
                Section("Audio") {
                    Picker("Sample Rate", selection: $settings.sampleRate) {
                        Text("16 kHz").tag(16000.0)
                        Text("24 kHz").tag(24000.0)
                        Text("48 kHz").tag(48000.0)
                    }

                    Picker("Buffer Size", selection: $settings.bufferSize) {
                        Text("256 (Low Latency)").tag(UInt32(256))
                        Text("512").tag(UInt32(512))
                        Text("1024 (Default)").tag(UInt32(1024))
                        Text("2048 (Stable)").tag(UInt32(2048))
                    }

                    Toggle("Voice Processing", isOn: $settings.enableVoiceProcessing)
                    Toggle("Echo Cancellation", isOn: $settings.enableEchoCancellation)
                    Toggle("Noise Suppression", isOn: $settings.enableNoiseSuppression)
                }

                // MARK: VAD Settings
                Section("Voice Activity Detection") {
                    Picker("VAD Provider", selection: $settings.vadProvider) {
                        ForEach(VADProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("VAD Threshold: \(settings.vadThreshold, specifier: "%.2f")")
                        Slider(value: $settings.vadThreshold, in: 0.1...0.9, step: 0.05)
                    }

                    Toggle("Enable Barge-In", isOn: $settings.enableBargeIn)

                    if settings.enableBargeIn {
                        VStack(alignment: .leading) {
                            Text("Barge-In Threshold: \(settings.bargeInThreshold, specifier: "%.2f")")
                            Slider(value: $settings.bargeInThreshold, in: 0.3...0.9, step: 0.05)
                        }
                    }
                }

                // MARK: Voice Settings
                Section("Voice (TTS)") {
                    Picker("Provider", selection: $settings.ttsProvider) {
                        ForEach(TTSProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Speaking Rate: \(settings.speakingRate, specifier: "%.1f")x")
                        Slider(value: $settings.speakingRate, in: 0.5...2.0, step: 0.1)
                    }

                    VStack(alignment: .leading) {
                        Text("Volume: \(Int(settings.volume * 100))%")
                        Slider(value: $settings.volume, in: 0.0...1.0, step: 0.1)
                    }
                }

                // MARK: LLM Settings
                Section("AI Model") {
                    Picker("Provider", selection: $settings.llmProvider) {
                        ForEach(LLMProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }

                    Picker("Model", selection: $settings.llmModel) {
                        ForEach(settings.llmProvider.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Temperature: \(settings.temperature, specifier: "%.1f")")
                        Slider(value: $settings.temperature, in: 0.0...2.0, step: 0.1)
                    }

                    Stepper("Max Tokens: \(settings.maxTokens)", value: $settings.maxTokens, in: 256...4096, step: 256)
                }

                // MARK: Session Settings
                Section("Session") {
                    Toggle("Cost Tracking", isOn: $settings.enableCostTracking)
                    Toggle("Auto-Save Transcript", isOn: $settings.autoSaveTranscript)

                    Picker("Max Duration", selection: $settings.maxDuration) {
                        Text("30 minutes").tag(TimeInterval(1800))
                        Text("60 minutes").tag(TimeInterval(3600))
                        Text("90 minutes").tag(TimeInterval(5400))
                        Text("Unlimited").tag(TimeInterval(0))
                    }
                }
            }
            .navigationTitle("Session Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        settings.resetToDefaults()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Session Settings Model

@MainActor
class SessionSettingsModel: ObservableObject {
    // Audio
    @Published var sampleRate: Double = 48000
    @Published var bufferSize: UInt32 = 1024
    @Published var enableVoiceProcessing = true
    @Published var enableEchoCancellation = true
    @Published var enableNoiseSuppression = true

    // VAD
    @Published var vadProvider: VADProvider = .silero
    @Published var vadThreshold: Float = 0.5
    @Published var enableBargeIn = true
    @Published var bargeInThreshold: Float = 0.7

    // TTS
    @Published var ttsProvider: TTSProvider = .elevenLabsFlash
    @Published var speakingRate: Float = 1.0
    @Published var volume: Float = 1.0

    // LLM
    @Published var llmProvider: LLMProvider = .anthropic {
        didSet {
            // Update model when provider changes
            if !llmProvider.availableModels.contains(llmModel) {
                llmModel = llmProvider.availableModels.first ?? ""
            }
        }
    }
    @Published var llmModel: String = "claude-3-5-sonnet-20241022"
    @Published var temperature: Float = 0.7
    @Published var maxTokens: Int = 1024

    // Session
    @Published var enableCostTracking = true
    @Published var autoSaveTranscript = true
    @Published var maxDuration: TimeInterval = 5400

    func resetToDefaults() {
        sampleRate = 48000
        bufferSize = 1024
        enableVoiceProcessing = true
        enableEchoCancellation = true
        enableNoiseSuppression = true
        vadProvider = .silero
        vadThreshold = 0.5
        enableBargeIn = true
        bargeInThreshold = 0.7
        ttsProvider = .elevenLabsFlash
        speakingRate = 1.0
        volume = 1.0
        llmProvider = .anthropic
        llmModel = "claude-3-5-sonnet-20241022"
        temperature = 0.7
        maxTokens = 1024
        enableCostTracking = true
        autoSaveTranscript = true
        maxDuration = 5400
    }
}

// MARK: - Session View Model

// MARK: - Session View Model

@MainActor
class SessionViewModel: ObservableObject {
    @Published var state: SessionState = .idle
    @Published var userTranscript: String = ""
    @Published var aiResponse: String = ""
    @Published var audioLevel: Float = -60
    @Published var isLoading: Bool = false
    @Published var showSettings: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var lastLatency: TimeInterval = 0
    @Published var sessionCost: Decimal = 0
    
    private var sessionManager: SessionManager?
    private var subscribers = Set<AnyCancellable>()
    
    var isSessionActive: Bool {
        state.isActive
    }
    
    func toggleSession(appState: AppState) async {
        if isSessionActive {
            await stopSession()
        } else {
            await startSession(appState: appState)
        }
    }
    
    private func startSession(appState: AppState) async {
        isLoading = true
        defer { isLoading = false }

        // Read user settings from UserDefaults
        let sttProviderSetting = UserDefaults.standard.string(forKey: "sttProvider")
            .flatMap { STTProvider(rawValue: $0) } ?? .glmASROnDevice
        let llmProviderSetting = UserDefaults.standard.string(forKey: "llmProvider")
            .flatMap { LLMProvider(rawValue: $0) } ?? .localMLX
        let ttsProviderSetting = UserDefaults.standard.string(forKey: "ttsProvider")
            .flatMap { TTSProvider(rawValue: $0) } ?? .appleTTS

        let sttService: any STTService
        let ttsService: any TTSService
        let llmService: any LLMService
        let vadService: any VADService = SileroVADService()

        // Configure STT based on settings
        switch sttProviderSetting {
        case .glmASROnDevice, .appleSpeech:
            if GLMASROnDeviceSTTService.isDeviceSupported {
                sttService = GLMASROnDeviceSTTService()
            } else {
                errorMessage = "On-device STT not available on this device. Please select a cloud provider in Settings."
                showError = true
                return
            }
        case .deepgramNova3:
            guard let apiKey = await appState.apiKeys.getKey(.deepgram) else {
                errorMessage = "Deepgram API key not configured. Please add it in Settings or switch to on-device mode."
                showError = true
                return
            }
            sttService = DeepgramSTTService(apiKey: apiKey)
        case .assemblyAI:
            guard let apiKey = await appState.apiKeys.getKey(.assemblyAI) else {
                errorMessage = "AssemblyAI API key not configured. Please add it in Settings or switch to on-device mode."
                showError = true
                return
            }
            sttService = AssemblyAISTTService(apiKey: apiKey)
        default:
            // Fallback to on-device if available
            if GLMASROnDeviceSTTService.isDeviceSupported {
                sttService = GLMASROnDeviceSTTService()
            } else {
                errorMessage = "No STT provider available. Please configure API keys in Settings."
                showError = true
                return
            }
        }

        // Configure TTS based on settings
        switch ttsProviderSetting {
        case .appleTTS:
            ttsService = AppleTTSService()
        case .elevenLabsFlash, .elevenLabsTurbo:
            guard let apiKey = await appState.apiKeys.getKey(.elevenLabs) else {
                errorMessage = "ElevenLabs API key not configured. Please add it in Settings or switch to Apple TTS."
                showError = true
                return
            }
            ttsService = ElevenLabsTTSService(apiKey: apiKey)
        case .deepgramAura2:
            guard let apiKey = await appState.apiKeys.getKey(.deepgram) else {
                errorMessage = "Deepgram API key not configured. Please add it in Settings or switch to Apple TTS."
                showError = true
                return
            }
            ttsService = DeepgramTTSService(apiKey: apiKey)
        default:
            ttsService = AppleTTSService()
        }

        // Configure LLM based on settings
        switch llmProviderSetting {
        case .localMLX:
            if OnDeviceLLMService.areModelsAvailable {
                llmService = OnDeviceLLMService()
            } else {
                errorMessage = "On-device LLM models not found. Please add models to the app bundle or select a cloud provider in Settings."
                showError = true
                return
            }
        case .anthropic:
            guard let apiKey = await appState.apiKeys.getKey(.anthropic) else {
                errorMessage = "Anthropic API key not configured. Please add it in Settings or switch to on-device mode."
                showError = true
                return
            }
            llmService = AnthropicLLMService(apiKey: apiKey)
        case .openAI:
            guard let apiKey = await appState.apiKeys.getKey(.openAI) else {
                errorMessage = "OpenAI API key not configured. Please add it in Settings or switch to on-device mode."
                showError = true
                return
            }
            llmService = OpenAILLMService(apiKey: apiKey)
        }

        do {
            // Create SessionManager
            let manager = try await appState.createSessionManager()
            self.sessionManager = manager

            // Bind State
            bindToSessionManager(manager)

            // Start Session
            try await manager.startSession(
                sttService: sttService,
                ttsService: ttsService,
                llmService: llmService,
                vadService: vadService
            )

        } catch {
            errorMessage = "Failed to start session: \(error.localizedDescription)"
            showError = true
            await stopSession()
        }
    }
    
    private func stopSession() async {
        isLoading = true
        defer { isLoading = false }
        
        if let manager = sessionManager {
            await manager.stopSession()
        }
        
        sessionManager = nil
        subscribers.removeAll()
        state = .idle
    }
    
    private func bindToSessionManager(_ manager: SessionManager) {
        // Since SessionManager properties are @MainActor, we can access them safely here
        
        manager.$state
            .receive(on: DispatchQueue.main)
            .assign(to: &$state)
            
        manager.$userTranscript
            .receive(on: DispatchQueue.main)
            .assign(to: &$userTranscript)
            
        manager.$aiResponse
            .receive(on: DispatchQueue.main)
            .assign(to: &$aiResponse)
            
        // Note: Audio level isn't currently published by SessionManager in this simplified version
        // We would need to hook into AudioEngine for that, but for now we'll leave it as is.
    }
}


// MARK: - Preview

#Preview {
    SessionView()
        .environmentObject(AppState())
}
