// UnaMentis - Chatterbox Settings ViewModel
// ViewModel for managing Chatterbox TTS settings with persistence
//
// Part of UI/Settings

import SwiftUI
import Combine

/// ViewModel for Chatterbox TTS settings
///
/// Provides @AppStorage-backed properties for all Chatterbox configuration options.
/// Changes are automatically persisted to UserDefaults.
@MainActor
final class ChatterboxSettingsViewModel: ObservableObject {

    // MARK: - Preset Selection

    /// Selected preset
    @AppStorage("chatterbox_preset") var selectedPresetRaw: String = ChatterboxPreset.default.rawValue

    var selectedPreset: ChatterboxPreset {
        get { ChatterboxPreset(rawValue: selectedPresetRaw) ?? .default }
        set {
            selectedPresetRaw = newValue.rawValue
            if newValue != .custom {
                applyPreset(newValue)
            }
        }
    }

    // MARK: - Emotion Control

    /// Exaggeration level (0.0 to 1.5)
    @AppStorage("chatterbox_exaggeration") var exaggeration: Double = 0.5

    /// CFG weight (0.0 to 1.0)
    @AppStorage("chatterbox_cfg_weight") var cfgWeight: Double = 0.5

    // MARK: - Speed Control

    /// Speaking speed (0.5 to 2.0)
    @AppStorage("chatterbox_speed") var speed: Double = 1.0

    // MARK: - Paralinguistic Tags

    /// Enable paralinguistic tag processing
    @AppStorage("chatterbox_paralinguistic_tags") var enableParalinguisticTags: Bool = false

    // MARK: - Multilingual Support

    /// Use multilingual model
    @AppStorage("chatterbox_use_multilingual") var useMultilingual: Bool = false

    /// Selected language code
    @AppStorage("chatterbox_language") var languageCode: String = "en"

    var selectedLanguage: ChatterboxLanguage {
        get { ChatterboxLanguage(rawValue: languageCode) ?? .english }
        set { languageCode = newValue.rawValue }
    }

    // MARK: - Performance

    /// Use streaming mode
    @AppStorage("chatterbox_streaming") var useStreaming: Bool = true

    // MARK: - Advanced

    /// Use fixed seed for reproducibility
    @AppStorage("chatterbox_use_fixed_seed") var useFixedSeed: Bool = false

    /// Seed value (only used when useFixedSeed is true)
    @AppStorage("chatterbox_seed") var seed: Int = 42

    // MARK: - Voice Cloning (DEFERRED)

    /// Reference audio path (deferred feature)
    @AppStorage("chatterbox_reference_audio") var referenceAudioPath: String = ""

    // MARK: - Server Connection

    /// Whether server is reachable
    @Published var isServerReachable: Bool = false

    /// Whether multilingual model is available
    @Published var isMultilingualAvailable: Bool = false

    /// Last health check time
    @Published var lastHealthCheck: Date?

    // MARK: - Test Synthesis

    /// Whether test synthesis is in progress
    @Published var isTesting: Bool = false

    /// Test result message
    @Published var testResult: String?

    /// Test sample text
    var testText: String = "Hello! This is a test of the Chatterbox text-to-speech system."

    // MARK: - Computed Properties

    /// Current configuration as ChatterboxConfig
    var currentConfig: ChatterboxConfig {
        ChatterboxConfig(
            exaggeration: Float(exaggeration),
            cfgWeight: Float(cfgWeight),
            speed: Float(speed),
            enableParalinguisticTags: enableParalinguisticTags,
            useMultilingual: useMultilingual,
            language: languageCode,
            useStreaming: useStreaming,
            seed: useFixedSeed ? seed : nil,
            referenceAudioPath: referenceAudioPath.isEmpty ? nil : referenceAudioPath
        )
    }

    /// Preset display name
    var presetDisplayName: String {
        selectedPreset.displayName
    }

    /// All available languages
    var availableLanguages: [ChatterboxLanguage] {
        ChatterboxLanguage.allCases
    }

    /// All available presets
    var availablePresets: [ChatterboxPreset] {
        ChatterboxPreset.allCases
    }

    /// Exaggeration description based on current value
    var exaggerationDescription: String {
        switch exaggeration {
        case 0..<0.2:
            return "Monotone"
        case 0.2..<0.4:
            return "Subdued"
        case 0.4..<0.6:
            return "Balanced"
        case 0.6..<0.8:
            return "Expressive"
        case 0.8..<1.0:
            return "Dramatic"
        default:
            return "Very Dramatic"
        }
    }

    /// CFG weight description based on current value
    var cfgWeightDescription: String {
        switch cfgWeight {
        case 0..<0.3:
            return "Creative"
        case 0.3..<0.5:
            return "Natural"
        case 0.5..<0.7:
            return "Balanced"
        default:
            return "Controlled"
        }
    }

    /// Speed description based on current value
    var speedDescription: String {
        switch speed {
        case 0.5..<0.8:
            return "Slow"
        case 0.8..<1.1:
            return "Normal"
        case 1.1..<1.5:
            return "Fast"
        default:
            return "Very Fast"
        }
    }

    // MARK: - Initialization

    init() {
        // Check server health on init
        Task {
            await checkServerHealth()
        }
    }

    // MARK: - Preset Application

    /// Apply a preset configuration
    func applyPreset(_ preset: ChatterboxPreset) {
        guard preset != .custom else { return }

        let config = preset.config
        exaggeration = Double(config.exaggeration)
        cfgWeight = Double(config.cfgWeight)
        speed = Double(config.speed)
        enableParalinguisticTags = config.enableParalinguisticTags
        useStreaming = config.useStreaming
    }

    /// Mark current settings as custom
    func markAsCustom() {
        if selectedPreset != .custom {
            selectedPresetRaw = ChatterboxPreset.custom.rawValue
        }
    }

    // MARK: - Server Health

    /// Check if Chatterbox server is reachable
    func checkServerHealth() async {
        // Get server IP from settings
        let serverIP = UserDefaults.standard.string(forKey: "selfHostedServerIP") ?? "localhost"
        let port = TTSProvider.chatterbox.defaultPort

        let healthURL = URL(string: "http://\(serverIP):\(port)/health")!

        do {
            var request = URLRequest(url: healthURL)
            request.timeoutInterval = 5

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                isServerReachable = httpResponse.statusCode == 200
            }

            // Check for multilingual model
            await checkMultilingualAvailability(serverIP: serverIP, port: port)

        } catch {
            isServerReachable = false
        }

        lastHealthCheck = Date()
    }

    /// Check if multilingual model is available
    private func checkMultilingualAvailability(serverIP: String, port: Int) async {
        let modelsURL = URL(string: "http://\(serverIP):\(port)/v1/models")!

        do {
            let (data, response) = try await URLSession.shared.data(from: modelsURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                isMultilingualAvailable = false
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [String] {
                isMultilingualAvailable = models.contains { $0.lowercased().contains("multilingual") }
            }
        } catch {
            isMultilingualAvailable = false
        }
    }

    // MARK: - Test Synthesis

    /// Run a test synthesis
    func testSynthesis() async {
        isTesting = true
        testResult = nil

        let serverIP = UserDefaults.standard.string(forKey: "selfHostedServerIP") ?? "localhost"
        let service = ChatterboxTTSService.chatterbox(
            host: serverIP,
            config: currentConfig
        )

        do {
            let startTime = Date()
            let stream = try await service.synthesize(text: testText)

            var totalBytes = 0
            var chunkCount = 0

            for await chunk in stream {
                totalBytes += chunk.audioData.count
                chunkCount += 1
            }

            let elapsed = Date().timeIntervalSince(startTime)
            testResult = "Success: \(totalBytes) bytes in \(chunkCount) chunks, \(String(format: "%.2f", elapsed))s"

        } catch {
            testResult = "Error: \(error.localizedDescription)"
        }

        isTesting = false
    }

    // MARK: - Reset

    /// Reset all settings to defaults
    func resetToDefaults() {
        selectedPresetRaw = ChatterboxPreset.default.rawValue
        exaggeration = 0.5
        cfgWeight = 0.5
        speed = 1.0
        enableParalinguisticTags = false
        useMultilingual = false
        languageCode = "en"
        useStreaming = true
        useFixedSeed = false
        seed = 42
        referenceAudioPath = ""
    }
}

// MARK: - Slider Value Change Detection

extension ChatterboxSettingsViewModel {

    /// Called when any slider value changes
    func onSliderValueChanged() {
        // Mark as custom preset when user adjusts sliders
        markAsCustom()
    }
}
