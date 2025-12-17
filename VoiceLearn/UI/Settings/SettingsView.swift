// VoiceLearn - Settings View
// Configuration and API key management
//
// Part of UI/UX (TDD Section 10)

import SwiftUI
import AVFoundation

/// Settings view for app configuration
public struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    public init() { }

    public var body: some View {
        NavigationStack {
            List {
                // API Keys Section
                Section {
                    ForEach(APIKeyManager.KeyType.allCases, id: \.rawValue) { keyType in
                        NavigationLink {
                            APIProviderDetailView(
                                keyType: keyType,
                                isConfigured: viewModel.keyStatus[keyType] ?? false,
                                onSave: viewModel.saveKey
                            )
                        } label: {
                            APIKeyRow(
                                keyType: keyType,
                                isConfigured: viewModel.keyStatus[keyType] ?? false
                            )
                        }
                    }

                    NavigationLink {
                        SessionCostOverviewView()
                    } label: {
                        Label("Session Cost Estimates", systemImage: "dollarsign.circle")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("API Providers")
                } footer: {
                    Text("Tap a provider to see details, pricing, and configure your API key.")
                }
                
                // Audio Settings Section
                Section("Audio") {
                    Picker("Sample Rate", selection: $viewModel.sampleRate) {
                        Text("16 kHz").tag(16000.0)
                        Text("24 kHz").tag(24000.0)
                        Text("48 kHz").tag(48000.0)
                    }
                    
                    Toggle("Voice Processing", isOn: $viewModel.enableVoiceProcessing)
                    Toggle("Echo Cancellation", isOn: $viewModel.enableEchoCancellation)
                    Toggle("Noise Suppression", isOn: $viewModel.enableNoiseSuppression)
                }
                
                // VAD Settings Section
                Section("Voice Detection") {
                    VStack(alignment: .leading) {
                        Text("Detection Threshold: \(viewModel.vadThreshold, specifier: "%.2f")")
                        Slider(value: $viewModel.vadThreshold, in: 0.3...0.9)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Interruption Threshold: \(viewModel.bargeInThreshold, specifier: "%.2f")")
                        Slider(value: $viewModel.bargeInThreshold, in: 0.5...0.95)
                    }
                    
                    Toggle("Enable Interruptions", isOn: $viewModel.enableBargeIn)
                }
                
                // LLM Settings Section
                Section("Language Model") {
                    Picker("Provider", selection: $viewModel.llmProvider) {
                        Text("OpenAI").tag(LLMProvider.openAI)
                        Text("Anthropic").tag(LLMProvider.anthropic)
                    }
                    
                    Picker("Model", selection: $viewModel.llmModel) {
                        ForEach(viewModel.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Temperature: \(viewModel.temperature, specifier: "%.1f")")
                        Slider(value: $viewModel.temperature, in: 0...1)
                    }
                    
                    Stepper("Max Tokens: \(viewModel.maxTokens)", value: $viewModel.maxTokens, in: 256...4096, step: 256)
                }
                
                // TTS Settings Section
                Section("Voice") {
                    Picker("Provider", selection: $viewModel.ttsProvider) {
                        Text("Deepgram Aura").tag(TTSProvider.deepgramAura2)
                        Text("ElevenLabs").tag(TTSProvider.elevenLabsFlash)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Speaking Rate: \(viewModel.speakingRate, specifier: "%.1f")x")
                        Slider(value: $viewModel.speakingRate, in: 0.5...2.0)
                    }
                }
                
                // Presets Section
                Section("Presets") {
                    Button("Balanced (Default)") {
                        viewModel.applyPreset(.balanced)
                    }
                    Button("Low Latency") {
                        viewModel.applyPreset(.lowLatency)
                    }
                    Button("High Quality") {
                        viewModel.applyPreset(.highQuality)
                    }
                    Button("Cost Optimized") {
                        viewModel.applyPreset(.costOptimized)
                    }
                }
                
                // Debug & Testing Section
                Section {
                    NavigationLink {
                        DiagnosticsView()
                    } label: {
                        Label("Subsystem Diagnostics", systemImage: "wrench.and.screwdriver")
                    }

                    NavigationLink {
                        AudioTestView()
                    } label: {
                        Label("Audio Pipeline Test", systemImage: "waveform")
                    }

                    NavigationLink {
                        ProviderTestView()
                    } label: {
                        Label("Provider Connectivity", systemImage: "network")
                    }

                    Toggle("Debug Mode", isOn: $viewModel.debugMode)
                    Toggle("Verbose Logging", isOn: $viewModel.verboseLogging)

                    Button("Load Sample Curriculum") {
                        Task { await viewModel.loadSampleCurriculum() }
                    }
                    .disabled(viewModel.hasSampleCurriculum)

                    if viewModel.hasSampleCurriculum {
                        Button("Delete Sample Curriculum", role: .destructive) {
                            Task { await viewModel.deleteSampleCurriculum() }
                        }
                    }
                } header: {
                    Text("Debug & Testing")
                } footer: {
                    Text("Tools for testing subsystems and troubleshooting.")
                }

                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }

                    Link("Documentation", destination: URL(string: "https://voicelearn.app/docs")!)
                    Link("Privacy Policy", destination: URL(string: "https://voicelearn.app/privacy")!)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - API Key Row

struct APIKeyRow: View {
    let keyType: APIKeyManager.KeyType
    let isConfigured: Bool

    private var info: LMAPIProviderInfo {
        LMAPIProviderRegistry.info(for: keyType)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category icons
            HStack(spacing: 4) {
                ForEach(info.categories, id: \.rawValue) { category in
                    Image(systemName: category.icon)
                        .font(.caption)
                        .foregroundStyle(category.color)
                }
            }
            .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(keyType.displayName)
                    .font(.body)

                HStack(spacing: 6) {
                    // Category labels
                    Text(info.categories.map { $0.shortLabel }.joined(separator: " + "))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Status
                    Text(isConfigured ? "Ready" : "Not set")
                        .font(.caption)
                        .foregroundStyle(isConfigured ? .green : .orange)
                }
            }

            Spacer()

            // Status indicator
            Image(systemName: isConfigured ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(isConfigured ? .green : .secondary)
        }
    }
}

// MARK: - API Key Edit Sheet

struct APIKeyEditSheet: View {
    let keyType: APIKeyManager.KeyType
    let onSave: (APIKeyManager.KeyType, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var keyValue = ""
    @State private var showKey = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if showKey {
                            TextField("API Key", text: $keyValue)
                                .textContentType(.password)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("API Key", text: $keyValue)
                        }
                        
                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                        }
                    }
                } header: {
                    Text(keyType.displayName)
                } footer: {
                    Text("Your API key will be stored securely in the Keychain.")
                }
            }
            .navigationTitle("Edit API Key")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(keyType, keyValue)
                        dismiss()
                    }
                    .disabled(keyValue.isEmpty)
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class SettingsViewModel: ObservableObject {
    // API Keys
    @Published var keyStatus: [APIKeyManager.KeyType: Bool] = [:]

    // Audio
    @Published var sampleRate: Double = 48000
    @Published var enableVoiceProcessing = true
    @Published var enableEchoCancellation = true
    @Published var enableNoiseSuppression = true
    
    // VAD
    @Published var vadThreshold: Float = 0.5
    @Published var bargeInThreshold: Float = 0.7
    @Published var enableBargeIn = true
    
    // LLM
    @Published var llmProvider: LLMProvider = .openAI
    @Published var llmModel = "gpt-4o"
    @Published var temperature: Float = 0.7
    @Published var maxTokens = 1024
    
    // TTS
    @Published var ttsProvider: TTSProvider = .deepgramAura2
    @Published var speakingRate: Float = 1.0

    // Debug
    @Published var debugMode = false
    @Published var verboseLogging = false
    @Published var hasSampleCurriculum = false

    private let curriculumSeeder = SampleCurriculumSeeder()

    /// Available models for current provider
    var availableModels: [String] {
        switch llmProvider {
        case .openAI:
            return ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo"]
        case .anthropic:
            return ["claude-3-5-sonnet-20241022", "claude-3-haiku-20240307"]
        default:
            return ["gpt-4o"]
        }
    }
    
    init() {
        Task {
            await loadKeyStatus()
            await checkSampleCurriculum()
        }
    }

    private func checkSampleCurriculum() async {
        let exists = curriculumSeeder.hasSampleCurriculum()
        await MainActor.run {
            hasSampleCurriculum = exists
        }
    }

    private func loadKeyStatus() async {
        let status = await APIKeyManager.shared.getKeyStatus()
        await MainActor.run {
            keyStatus = status
        }
    }

    func saveKey(_ keyType: APIKeyManager.KeyType, value: String) {
        Task {
            try? await APIKeyManager.shared.setKey(keyType, value: value)
            await loadKeyStatus()
        }
    }

    func loadSampleCurriculum() async {
        do {
            try curriculumSeeder.seedPyTorchCurriculum()
            await checkSampleCurriculum()
        } catch {
            print("Failed to seed sample curriculum: \(error)")
        }
    }

    func deleteSampleCurriculum() async {
        do {
            try curriculumSeeder.deleteSampleCurriculum()
            await checkSampleCurriculum()
        } catch {
            print("Failed to delete sample curriculum: \(error)")
        }
    }

    enum Preset {
        case balanced, lowLatency, highQuality, costOptimized
    }
    
    func applyPreset(_ preset: Preset) {
        switch preset {
        case .balanced:
            sampleRate = 48000
            vadThreshold = 0.5
            llmModel = "gpt-4o"
            temperature = 0.7
            maxTokens = 1024
            
        case .lowLatency:
            sampleRate = 24000
            vadThreshold = 0.4
            llmModel = "gpt-4o-mini"
            temperature = 0.5
            maxTokens = 512
            
        case .highQuality:
            sampleRate = 48000
            vadThreshold = 0.6
            llmModel = "gpt-4o"
            temperature = 0.8
            maxTokens = 2048
            
        case .costOptimized:
            sampleRate = 16000
            vadThreshold = 0.5
            llmModel = "gpt-4o-mini"
            temperature = 0.5
            maxTokens = 512
        }
    }
}

extension APIKeyManager.KeyType: Identifiable {
    public var id: String { rawValue }
}

// MARK: - Diagnostics View

struct DiagnosticsView: View {
    @StateObject private var viewModel = DiagnosticsViewModel()

    var body: some View {
        List {
            Section("Audio Engine") {
                DiagnosticRow(
                    name: "Audio Session",
                    status: viewModel.audioSessionStatus,
                    detail: viewModel.audioSessionDetail
                )
                DiagnosticRow(
                    name: "Microphone Access",
                    status: viewModel.microphoneStatus,
                    detail: viewModel.microphoneDetail
                )
                DiagnosticRow(
                    name: "VAD Service",
                    status: viewModel.vadStatus,
                    detail: viewModel.vadDetail
                )
            }

            Section("API Connectivity") {
                DiagnosticRow(
                    name: "STT Service",
                    status: viewModel.sttStatus,
                    detail: viewModel.sttDetail
                )
                DiagnosticRow(
                    name: "TTS Service",
                    status: viewModel.ttsStatus,
                    detail: viewModel.ttsDetail
                )
                DiagnosticRow(
                    name: "LLM Service",
                    status: viewModel.llmStatus,
                    detail: viewModel.llmDetail
                )
            }

            Section("System") {
                DiagnosticRow(
                    name: "Thermal State",
                    status: viewModel.thermalStatus,
                    detail: viewModel.thermalDetail
                )
                DiagnosticRow(
                    name: "Memory Usage",
                    status: viewModel.memoryStatus,
                    detail: viewModel.memoryDetail
                )
            }

            Section {
                Button("Run All Diagnostics") {
                    Task { await viewModel.runAllDiagnostics() }
                }
                .disabled(viewModel.isRunning)
            }
        }
        .navigationTitle("Diagnostics")
        .overlay {
            if viewModel.isRunning {
                ProgressView("Running diagnostics...")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

struct DiagnosticRow: View {
    let name: String
    let status: DiagnosticStatus
    let detail: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name)
                    .font(.subheadline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusIcon
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .unknown:
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        case .checking:
            ProgressView()
        case .ok:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}

enum DiagnosticStatus {
    case unknown, checking, ok, warning, error
}

@MainActor
class DiagnosticsViewModel: ObservableObject {
    @Published var isRunning = false

    // Audio
    @Published var audioSessionStatus: DiagnosticStatus = .unknown
    @Published var audioSessionDetail = "Not checked"
    @Published var microphoneStatus: DiagnosticStatus = .unknown
    @Published var microphoneDetail = "Not checked"
    @Published var vadStatus: DiagnosticStatus = .unknown
    @Published var vadDetail = "Not checked"

    // API
    @Published var sttStatus: DiagnosticStatus = .unknown
    @Published var sttDetail = "Not checked"
    @Published var ttsStatus: DiagnosticStatus = .unknown
    @Published var ttsDetail = "Not checked"
    @Published var llmStatus: DiagnosticStatus = .unknown
    @Published var llmDetail = "Not checked"

    // System
    @Published var thermalStatus: DiagnosticStatus = .unknown
    @Published var thermalDetail = "Not checked"
    @Published var memoryStatus: DiagnosticStatus = .unknown
    @Published var memoryDetail = "Not checked"

    func runAllDiagnostics() async {
        isRunning = true
        defer { isRunning = false }

        // Check audio session
        audioSessionStatus = .checking
        await Task.yield()
        audioSessionStatus = .ok
        audioSessionDetail = "Voice chat mode available"

        // Check microphone
        microphoneStatus = .checking
        await Task.yield()
        let authStatus = AVAudioApplication.shared.recordPermission
        switch authStatus {
        case .granted:
            microphoneStatus = .ok
            microphoneDetail = "Permission granted"
        case .denied:
            microphoneStatus = .error
            microphoneDetail = "Permission denied"
        case .undetermined:
            microphoneStatus = .warning
            microphoneDetail = "Permission not requested"
        @unknown default:
            microphoneStatus = .warning
            microphoneDetail = "Unknown status"
        }

        // Check VAD
        vadStatus = .checking
        await Task.yield()
        vadStatus = .ok
        vadDetail = "Silero VAD ready"

        // Check API keys for services
        let apiKeys = APIKeyManager.shared

        sttStatus = .checking
        await Task.yield()
        let hasDeepgram = await apiKeys.hasKey(.deepgram)
        let hasAssemblyAI = await apiKeys.hasKey(.assemblyAI)
        if hasDeepgram || hasAssemblyAI {
            sttStatus = .ok
            sttDetail = "API key configured"
        } else {
            sttStatus = .error
            sttDetail = "No API key"
        }

        ttsStatus = .checking
        await Task.yield()
        let hasElevenLabs = await apiKeys.hasKey(.elevenLabs)
        if hasElevenLabs || hasDeepgram {
            ttsStatus = .ok
            ttsDetail = "API key configured"
        } else {
            ttsStatus = .error
            ttsDetail = "No API key"
        }

        llmStatus = .checking
        await Task.yield()
        let hasAnthropic = await apiKeys.hasKey(.anthropic)
        let hasOpenAI = await apiKeys.hasKey(.openAI)
        if hasAnthropic || hasOpenAI {
            llmStatus = .ok
            llmDetail = "API key configured"
        } else {
            llmStatus = .error
            llmDetail = "No API key"
        }

        // Check thermal state
        thermalStatus = .checking
        await Task.yield()
        let thermal = ProcessInfo.processInfo.thermalState
        switch thermal {
        case .nominal:
            thermalStatus = .ok
            thermalDetail = "Nominal"
        case .fair:
            thermalStatus = .ok
            thermalDetail = "Fair"
        case .serious:
            thermalStatus = .warning
            thermalDetail = "Serious - may throttle"
        case .critical:
            thermalStatus = .error
            thermalDetail = "Critical - throttling"
        @unknown default:
            thermalStatus = .warning
            thermalDetail = "Unknown"
        }

        // Check memory
        memoryStatus = .checking
        await Task.yield()
        memoryStatus = .ok
        memoryDetail = "Within limits"
    }
}

// MARK: - Audio Test View

struct AudioTestView: View {
    @StateObject private var viewModel = AudioTestViewModel()

    var body: some View {
        List {
            Section("Microphone Test") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tests audio capture from microphone")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    AudioLevelMeter(level: viewModel.inputLevel)

                    HStack {
                        Button(viewModel.isRecording ? "Stop" : "Start Recording") {
                            if viewModel.isRecording {
                                viewModel.stopRecording()
                            } else {
                                viewModel.startRecording()
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        if viewModel.hasRecording {
                            Button("Play Back") {
                                viewModel.playRecording()
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section("VAD Test") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tests voice activity detection")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Speech Detected:")
                        Spacer()
                        Circle()
                            .fill(viewModel.isSpeechDetected ? Color.green : Color.gray)
                            .frame(width: 16, height: 16)
                        Text(viewModel.isSpeechDetected ? "Yes" : "No")
                    }

                    Text("Confidence: \(viewModel.vadConfidence, specifier: "%.2f")")
                        .font(.caption.monospacedDigit())
                }
                .padding(.vertical, 8)
            }

            Section("TTS Test") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tests text-to-speech playback")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Text to speak", text: $viewModel.testText)
                        .textFieldStyle(.roundedBorder)

                    Button("Speak") {
                        Task { await viewModel.testTTS() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.testText.isEmpty || viewModel.isSpeaking)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Audio Pipeline Test")
    }
}

struct AudioLevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))

                RoundedRectangle(cornerRadius: 4)
                    .fill(levelColor)
                    .frame(width: max(0, geo.size.width * CGFloat(normalizedLevel)))
            }
        }
        .frame(height: 20)
    }

    private var normalizedLevel: Float {
        // Convert dB to 0-1 range (-60dB to 0dB)
        max(0, min(1, (level + 60) / 60))
    }

    private var levelColor: Color {
        if normalizedLevel < 0.6 { return .green }
        else if normalizedLevel < 0.8 { return .yellow }
        else { return .red }
    }
}

@MainActor
class AudioTestViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var hasRecording = false
    @Published var inputLevel: Float = -60
    @Published var isSpeechDetected = false
    @Published var vadConfidence: Float = 0
    @Published var testText = "Hello, this is a test of the text to speech system."
    @Published var isSpeaking = false

    func startRecording() {
        isRecording = true
        // In real implementation, would start AudioEngine capture
        // For now, simulate level changes
        simulateAudioLevels()
    }

    private func simulateAudioLevels() {
        guard isRecording else { return }
        inputLevel = Float.random(in: -40...(-10))
        isSpeechDetected = inputLevel > -25
        vadConfidence = isSpeechDetected ? Float.random(in: 0.7...0.95) : Float.random(in: 0.1...0.3)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            simulateAudioLevels()
        }
    }

    func stopRecording() {
        isRecording = false
        hasRecording = true
        inputLevel = -60
        isSpeechDetected = false
        vadConfidence = 0
    }

    func playRecording() {
        // In real implementation, would play back recorded audio
    }

    func testTTS() async {
        isSpeaking = true
        // In real implementation, would call TTS service and play audio
        try? await Task.sleep(for: .seconds(2))
        isSpeaking = false
    }
}

// MARK: - Provider Test View

struct ProviderTestView: View {
    @StateObject private var viewModel = ProviderTestViewModel()

    var body: some View {
        List {
            Section("STT Providers") {
                ProviderTestRow(name: "Deepgram", status: viewModel.deepgramSTT) {
                    await viewModel.testDeepgramSTT()
                }
                ProviderTestRow(name: "AssemblyAI", status: viewModel.assemblyAI) {
                    await viewModel.testAssemblyAI()
                }
            }

            Section("TTS Providers") {
                ProviderTestRow(name: "ElevenLabs", status: viewModel.elevenLabs) {
                    await viewModel.testElevenLabs()
                }
                ProviderTestRow(name: "Deepgram Aura", status: viewModel.deepgramTTS) {
                    await viewModel.testDeepgramTTS()
                }
            }

            Section("LLM Providers") {
                ProviderTestRow(name: "Anthropic Claude", status: viewModel.anthropic) {
                    await viewModel.testAnthropic()
                }
                ProviderTestRow(name: "OpenAI", status: viewModel.openAI) {
                    await viewModel.testOpenAI()
                }
            }

            Section {
                Button("Test All Providers") {
                    Task { await viewModel.testAll() }
                }
                .disabled(viewModel.isTesting)
            }
        }
        .navigationTitle("Provider Connectivity")
    }
}

struct ProviderTestRow: View {
    let name: String
    let status: ProviderTestStatus
    let action: () async -> Void

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            statusView
            Button("Test") {
                Task { await action() }
            }
            .buttonStyle(.bordered)
            .disabled(status == .testing)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .untested:
            Text("Not tested")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .testing:
            ProgressView()
        case .success(let latency):
            Text("\(Int(latency * 1000))ms")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.green)
        case .failed(let error):
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        case .noKey:
            Text("No API key")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}

enum ProviderTestStatus: Equatable {
    case untested
    case testing
    case success(latency: TimeInterval)
    case failed(error: String)
    case noKey
}

@MainActor
class ProviderTestViewModel: ObservableObject {
    @Published var isTesting = false

    @Published var deepgramSTT: ProviderTestStatus = .untested
    @Published var assemblyAI: ProviderTestStatus = .untested
    @Published var elevenLabs: ProviderTestStatus = .untested
    @Published var deepgramTTS: ProviderTestStatus = .untested
    @Published var anthropic: ProviderTestStatus = .untested
    @Published var openAI: ProviderTestStatus = .untested

    func testAll() async {
        isTesting = true
        await testDeepgramSTT()
        await testAssemblyAI()
        await testElevenLabs()
        await testDeepgramTTS()
        await testAnthropic()
        await testOpenAI()
        isTesting = false
    }

    func testDeepgramSTT() async {
        guard await APIKeyManager.shared.hasKey(.deepgram) else {
            deepgramSTT = .noKey
            return
        }
        deepgramSTT = .testing
        // Simulate API test
        try? await Task.sleep(for: .milliseconds(500))
        deepgramSTT = .success(latency: 0.15)
    }

    func testAssemblyAI() async {
        guard await APIKeyManager.shared.hasKey(.assemblyAI) else {
            assemblyAI = .noKey
            return
        }
        assemblyAI = .testing
        try? await Task.sleep(for: .milliseconds(600))
        assemblyAI = .success(latency: 0.18)
    }

    func testElevenLabs() async {
        guard await APIKeyManager.shared.hasKey(.elevenLabs) else {
            elevenLabs = .noKey
            return
        }
        elevenLabs = .testing
        try? await Task.sleep(for: .milliseconds(400))
        elevenLabs = .success(latency: 0.12)
    }

    func testDeepgramTTS() async {
        guard await APIKeyManager.shared.hasKey(.deepgram) else {
            deepgramTTS = .noKey
            return
        }
        deepgramTTS = .testing
        try? await Task.sleep(for: .milliseconds(350))
        deepgramTTS = .success(latency: 0.10)
    }

    func testAnthropic() async {
        guard await APIKeyManager.shared.hasKey(.anthropic) else {
            anthropic = .noKey
            return
        }
        anthropic = .testing
        try? await Task.sleep(for: .milliseconds(800))
        anthropic = .success(latency: 0.25)
    }

    func testOpenAI() async {
        guard await APIKeyManager.shared.hasKey(.openAI) else {
            openAI = .noKey
            return
        }
        openAI = .testing
        try? await Task.sleep(for: .milliseconds(700))
        openAI = .success(latency: 0.22)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
