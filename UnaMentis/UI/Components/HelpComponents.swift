// UnaMentis - Help Components
// Reusable UI components for in-app help, tooltips, and documentation
//
// Provides accessible, native help throughout the application

import SwiftUI

// MARK: - Info Button with Popover

/// A small info button that shows a help popover when tapped
/// Usage: InfoButton(title: "Temperature", help: HelpContent.Settings.temperature)
struct InfoButton: View {
    let title: String
    let content: String
    var learnMoreURL: URL?

    @State private var showingPopover = false

    var body: some View {
        Button {
            showingPopover = true
        } label: {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Help for \(title)")
        .accessibilityHint("Double-tap to learn more about \(title)")
        .popover(isPresented: $showingPopover) {
            HelpPopoverContent(
                title: title,
                content: content,
                learnMoreURL: learnMoreURL
            )
            .presentationCompactAdaptation(.popover)
        }
    }
}

/// Content view for help popovers
struct HelpPopoverContent: View {
    let title: String
    let content: String
    var learnMoreURL: URL?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close help")
            }

            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let url = learnMoreURL {
                Link(destination: url) {
                    HStack {
                        Text("Learn More")
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding()
        .frame(minWidth: 250, maxWidth: 320)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(content)")
    }
}

// MARK: - Inline Help Text

/// Subtle inline help text that appears below a control
struct InlineHelp: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityLabel(text)
    }
}

// MARK: - Help Section Header

/// A section header with an info button
struct HelpSectionHeader: View {
    let title: String
    let helpTitle: String
    let helpContent: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            InfoButton(title: helpTitle, content: helpContent)
        }
    }
}

// MARK: - Setting Row with Help

/// A setting row that includes an info button for context
struct SettingRowWithHelp<Content: View>: View {
    let title: String
    let helpContent: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            Text(title)
            InfoButton(title: title, content: helpContent)
            Spacer()
            content()
        }
    }
}

// MARK: - Slider with Help

/// A slider control with title, value display, and help button
struct SliderWithHelp: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let helpContent: String
    var valueFormatter: ((Double) -> String)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                InfoButton(title: title, content: helpContent)
                Spacer()
                Text(formattedValue)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(formattedValue)
                .accessibilityHint(helpContent)
        }
    }

    private var formattedValue: String {
        if let formatter = valueFormatter {
            return formatter(value)
        }
        return String(format: "%.2f", value)
    }
}

// MARK: - Feature Tooltip

/// A tooltip that can be attached to any view to explain a feature
struct FeatureTooltip: ViewModifier {
    let title: String
    let message: String
    let showOnFirstAppear: Bool

    @State private var showingTooltip = false
    @AppStorage private var hasShownTooltip: Bool

    init(title: String, message: String, showOnFirstAppear: Bool = false, storageKey: String) {
        self.title = title
        self.message = message
        self.showOnFirstAppear = showOnFirstAppear
        self._hasShownTooltip = AppStorage(wrappedValue: false, "tooltip_shown_\(storageKey)")
    }

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0.5) {
                showingTooltip = true
            }
            .popover(isPresented: $showingTooltip) {
                TooltipContent(title: title, message: message)
                    .presentationCompactAdaptation(.popover)
            }
            .onAppear {
                if showOnFirstAppear && !hasShownTooltip {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showingTooltip = true
                        hasShownTooltip = true
                    }
                }
            }
    }
}

struct TooltipContent: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "lightbulb.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.yellow)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: 280)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tip: \(title). \(message)")
    }
}

extension View {
    /// Adds a tooltip that shows on long press
    func featureTooltip(title: String, message: String, showOnFirstAppear: Bool = false, storageKey: String) -> some View {
        modifier(FeatureTooltip(title: title, message: message, showOnFirstAppear: showOnFirstAppear, storageKey: storageKey))
    }
}

// MARK: - Quick Help Card

/// A card that displays help information prominently
struct QuickHelpCard: View {
    let icon: String
    let title: String
    let description: String
    var action: (() -> Void)?
    var actionLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
    }
}

// MARK: - Contextual Help Banner

/// A dismissible banner that provides contextual help at the top of a screen
struct ContextualHelpBanner: View {
    let message: String
    let storageKey: String

    @AppStorage private var isDismissed: Bool

    init(message: String, storageKey: String) {
        self.message = message
        self.storageKey = storageKey
        self._isDismissed = AppStorage(wrappedValue: false, "help_banner_dismissed_\(storageKey)")
    }

    var body: some View {
        if !isDismissed {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    withAnimation {
                        isDismissed = true
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss tip")
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.1))
            }
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Tip: \(message)")
        }
    }
}

// MARK: - Help Content Storage

/// Centralized storage for all help text content
/// Organized by screen and feature for easy maintenance
enum HelpContent {

    // MARK: - Session View Help
    enum Session {
        static let overview = """
        This is your voice conversation interface. Speak naturally and the AI will respond.
        """

        static let statusIndicator = """
        The status indicator shows the current state of your conversation:

        • Gray (Idle): Ready to start
        • Green (Listening): Hearing your voice
        • Orange (Thinking): Processing your request
        • Blue (Speaking): AI is responding
        • Yellow (Interrupted): You interrupted the AI
        """

        static let progressBar = """
        Shows your progress through the current lesson. Each segment represents a topic or concept being covered.
        """

        static let vuMeter = """
        The audio level meter shows:
        • Blue: AI is speaking
        • Green: Your voice is detected

        Higher levels indicate louder audio.
        """

        static let interrupt = """
        You can interrupt the AI at any time by simply speaking. The AI will pause and listen to your question or comment.
        """

        static let visualAssets = """
        Visual aids appear when they help explain a concept. They sync with the audio narration automatically.
        """

        static let pauseResume = """
        Pause to take a break without ending the session. Resume to continue where you left off.
        """

        static let latencyMetric = """
        Response latency shows how quickly the system responds. Lower is better. Target: under 500ms.
        """

        static let costMetric = """
        Estimated cost for this session based on API usage. On-device and self-hosted options are free.
        """
    }

    // MARK: - Curriculum View Help
    enum Curriculum {
        static let overview = """
        Browse and select structured learning content. Each curriculum contains multiple topics organized for progressive learning.
        """

        static let curriculumVsTopic = """
        A Curriculum is a complete course containing multiple Topics. Each Topic is a focused lesson on a specific concept.
        """

        static let mastery = """
        Mastery percentage shows how well you understand a topic based on:
        • Time spent studying
        • Questions answered correctly
        • Content covered

        Higher mastery means better retention.
        """

        static let topicStatus = """
        • Not Started: Haven't begun this topic
        • In Progress: Currently studying
        • Completed: Finished at least once
        • Reviewing: Revisiting for reinforcement
        """

        static let importing = """
        Import curricula from:
        • Server: Download from the management console
        • Sample: Load built-in sample content for testing
        """

        static let startLesson = """
        Tap "Start Lesson" to begin a voice-guided session. The AI will speak first, introducing the topic.
        """
    }

    // MARK: - History View Help
    enum History {
        static let overview = """
        Review your past learning sessions. Each entry shows duration, turn count, and cost.
        """

        static let turns = """
        A "turn" is one exchange: you speak, then the AI responds. More turns indicate a longer, more interactive conversation.
        """

        static let avgLatency = """
        Average response time for this session. Lower latency means faster, more natural conversations.
        """

        static let totalCost = """
        Total API costs for this session. Includes speech recognition, language model, and text-to-speech fees.
        """

        static let export = """
        Export your session history as JSON for backup or analysis.
        """
    }

    // MARK: - Analytics View Help
    enum Analytics {
        static let overview = """
        Track your learning progress and system performance metrics. Use this data to optimize your experience.
        """

        static let sttLatency = """
        Speech-to-Text (STT) latency measures how long it takes to convert your speech to text. Target: under 150ms.
        """

        static let llmTTFT = """
        Time-To-First-Token (TTFT) measures how quickly the language model starts generating a response. Target: under 200ms.
        """

        static let ttsTTFB = """
        Time-To-First-Byte (TTFB) measures how quickly text-to-speech audio starts playing. Target: under 100ms.
        """

        static let e2eLatency = """
        End-to-End latency is the total time from when you stop speaking to when you hear a response. Target: under 500ms (median), under 1000ms (P99).
        """

        static let medianVsP99 = """
        Median: The typical (50th percentile) response time.
        P99: The worst-case (99th percentile) response time. 99% of responses are faster than this.
        """

        static let costPerHour = """
        Estimated hourly cost based on your usage patterns. Use on-device or self-hosted providers to reduce costs.
        """

        static let interruptions = """
        Times you interrupted the AI while it was speaking. Interruptions are normal and show active engagement.
        """

        static let throttleEvents = """
        Times the device reduced performance due to heat. High counts may indicate the device needs to cool down.
        """
    }

    // MARK: - Settings Help
    enum Settings {
        // Audio Section
        static let sampleRate = """
        Audio quality setting:
        • 16 kHz: Lower quality, less data
        • 24 kHz: Balanced (recommended)
        • 48 kHz: Highest quality, more data

        Higher rates use more bandwidth but sound better.
        """

        static let voiceProcessing = """
        Enhances voice clarity using Apple's audio processing. Keep enabled unless troubleshooting.
        """

        static let echoCancellation = """
        Prevents the microphone from picking up the AI's voice playing through speakers. Essential when not using headphones.
        """

        static let noiseSuppression = """
        Filters background noise like fans, traffic, or keyboard sounds. Keep enabled in noisy environments.
        """

        // VAD Section
        static let vadThreshold = """
        How sensitive voice detection is:
        • Lower (0.3): Detects quieter speech, may pick up noise
        • Higher (0.9): Requires clearer speech, ignores noise

        Start at 0.5 and adjust based on your environment.
        """

        static let interruptionThreshold = """
        How loud you need to speak to interrupt the AI:
        • Lower: Easier to interrupt
        • Higher: Requires deliberate speech to interrupt

        Higher values prevent accidental interruptions.
        """

        static let enableInterruptions = """
        When enabled, speaking while the AI talks will pause the AI so it can listen to you. Disable for lecture-style sessions where you prefer not to interrupt.
        """

        // STT Section
        static let sttProvider = """
        Speech recognition service:
        • GLM-ASR (On-Device): Free, private, works offline
        • Deepgram Nova-3: Cloud, fast, accurate
        • AssemblyAI: Cloud, good accuracy
        • Apple Speech: On-device, good for iOS
        """

        // LLM Section
        static let llmProvider = """
        Language model for AI responses:
        • On-Device: Free, private, works offline (slower)
        • Anthropic Claude: High quality, paid
        • OpenAI: Fast, versatile, paid
        • Self-Hosted: Free with your own server
        """

        static let llmModel = """
        Specific model to use. Larger models are smarter but slower and more expensive. Smaller models are faster and cheaper.
        """

        static let temperature = """
        Controls response creativity:
        • 0.0: Factual, deterministic
        • 0.5: Balanced (recommended)
        • 1.0: Creative, varied

        Lower for factual topics, higher for creative discussions.
        """

        static let maxTokens = """
        Maximum response length. One token is roughly 4 characters.
        • 256: Short answers
        • 1024: Detailed explanations (recommended)
        • 4096: Very long responses

        Longer responses cost more and take more time.
        """

        // TTS Section
        static let ttsProvider = """
        Text-to-speech voice:
        • Apple TTS: Free, on-device, robotic
        • Piper: Free with self-hosted server, natural
        • VibeVoice: Free with self-hosted server, high quality
        • ElevenLabs: Paid, very natural
        • Deepgram Aura: Paid, fast
        """

        static let ttsVoice = """
        Choose the AI's voice. Different voices have different characteristics and personalities.
        """

        static let speakingRate = """
        How fast the AI speaks:
        • 0.5x: Half speed (for complex topics)
        • 1.0x: Normal speed
        • 2.0x: Double speed (for review)
        """

        // Presets Section
        static let presets = """
        Quick configurations for different use cases:
        • Balanced: Good quality and speed
        • Low Latency: Fastest responses
        • High Quality: Best audio and AI
        • Cost Optimized: Minimize API costs
        • Self-Hosted: Use your own servers
        """

        // Self-Hosted Section
        static let selfHosted = """
        Run AI services on your own Mac for free, unlimited usage with full privacy. Requires setting up Ollama and optionally Piper/VibeVoice on your computer.
        """

        static let serverIP = """
        Enter your Mac's IP address or hostname (e.g., 192.168.1.100 or macbook.local). The app will connect to Ollama on port 11434.
        """
    }

    // MARK: - General Help
    enum General {
        static let onboarding = """
        Welcome to UnaMentis! This app lets you learn through voice conversations with AI.

        Get started:
        1. Go to Settings to configure your AI providers
        2. Import or download a curriculum
        3. Start a lesson or free conversation

        Say "Hey Siri, talk to UnaMentis" for hands-free learning.
        """

        static let accessibility = """
        UnaMentis supports VoiceOver and other accessibility features. All controls have descriptive labels and hints.
        """
    }
}

// MARK: - Previews

#Preview("Info Button") {
    VStack(spacing: 20) {
        HStack {
            Text("Temperature")
            InfoButton(title: "Temperature", content: HelpContent.Settings.temperature)
        }

        SliderWithHelp(
            title: "Speaking Rate",
            value: .constant(1.0),
            range: 0.5...2.0,
            step: 0.1,
            helpContent: HelpContent.Settings.speakingRate,
            valueFormatter: { String(format: "%.1fx", $0) }
        )
    }
    .padding()
}

#Preview("Quick Help Card") {
    QuickHelpCard(
        icon: "waveform.circle.fill",
        title: "Voice Commands",
        description: "Use Siri to start learning sessions hands-free.",
        action: {},
        actionLabel: "Learn More"
    )
    .padding()
}

#Preview("Contextual Help Banner") {
    VStack {
        ContextualHelpBanner(
            message: "Tip: Long press any setting to see a helpful explanation.",
            storageKey: "preview_banner"
        )
        Spacer()
    }
}
