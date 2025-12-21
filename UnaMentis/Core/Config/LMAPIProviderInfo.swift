// UnaMentis - LM API Provider Information
// Comprehensive metadata for all supported API providers
//
// Part of Configuration (TDD Section 7)

import Foundation
import SwiftUI

// MARK: - Provider Category

/// Categories of API providers based on their function
public enum LMAPIProviderCategory: String, CaseIterable, Sendable {
    case speechToText = "STT"
    case textToSpeech = "TTS"
    case languageModel = "LLM"
    case realtime = "RT"

    public var displayName: String {
        switch self {
        case .speechToText: return "Speech-to-Text"
        case .textToSpeech: return "Text-to-Speech"
        case .languageModel: return "Language Model"
        case .realtime: return "Real-time Infrastructure"
        }
    }

    public var shortLabel: String {
        switch self {
        case .speechToText: return "STT"
        case .textToSpeech: return "TTS"
        case .languageModel: return "LLM"
        case .realtime: return "RT"
        }
    }

    public var icon: String {
        switch self {
        case .speechToText: return "waveform.and.mic"
        case .textToSpeech: return "speaker.wave.3"
        case .languageModel: return "brain"
        case .realtime: return "bolt.horizontal"
        }
    }

    public var color: Color {
        switch self {
        case .speechToText: return .blue
        case .textToSpeech: return .purple
        case .languageModel: return .orange
        case .realtime: return .green
        }
    }

    public var description: String {
        switch self {
        case .speechToText:
            return "Converts your voice into text that the AI can understand"
        case .textToSpeech:
            return "Converts AI responses into natural-sounding speech"
        case .languageModel:
            return "Powers the AI tutor's intelligence and understanding"
        case .realtime:
            return "Enables low-latency real-time audio streaming"
        }
    }
}

// MARK: - Pricing Model

/// Represents pricing for an API provider
public struct LMAPIPricing: Sendable {
    /// Unit of measurement for pricing
    public enum Unit: String, Sendable {
        case perMillionInputTokens = "per 1M input tokens"
        case perMillionOutputTokens = "per 1M output tokens"
        case perMinute = "per minute"
        case perHour = "per hour"
        case perCharacter = "per character"
        case perThousandCharacters = "per 1K characters"
        case free = "free"
        case flatMonthly = "per month"
    }

    public let inputCost: Double?
    public let outputCost: Double?
    public let inputUnit: Unit
    public let outputUnit: Unit?
    public let notes: String?

    public init(
        inputCost: Double?,
        outputCost: Double? = nil,
        inputUnit: Unit,
        outputUnit: Unit? = nil,
        notes: String? = nil
    ) {
        self.inputCost = inputCost
        self.outputCost = outputCost
        self.inputUnit = inputUnit
        self.outputUnit = outputUnit
        self.notes = notes
    }

    /// Free tier or on-device
    public static var free: LMAPIPricing {
        LMAPIPricing(inputCost: nil, inputUnit: .free)
    }

    public var formattedCost: String {
        guard let inputCost = inputCost else { return "Free" }

        if let outputCost = outputCost, let outputUnit = outputUnit {
            return "$\(formatNumber(inputCost)) \(inputUnit.rawValue) / $\(formatNumber(outputCost)) \(outputUnit.rawValue)"
        }
        return "$\(formatNumber(inputCost)) \(inputUnit.rawValue)"
    }

    private func formatNumber(_ value: Double) -> String {
        if value < 0.01 {
            return String(format: "%.6f", value)
        } else if value < 1 {
            return String(format: "%.3f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - Conversation Cost Estimates

/// Estimated costs for typical conversation durations
public struct ConversationCostEstimate: Sendable {
    public let tenMinuteCost: Double
    public let sixtyMinuteCost: Double
    public let assumptions: String

    public init(tenMinuteCost: Double, sixtyMinuteCost: Double, assumptions: String) {
        self.tenMinuteCost = tenMinuteCost
        self.sixtyMinuteCost = sixtyMinuteCost
        self.assumptions = assumptions
    }

    public var formattedTenMinute: String {
        formatCost(tenMinuteCost)
    }

    public var formattedSixtyMinute: String {
        formatCost(sixtyMinuteCost)
    }

    private func formatCost(_ cost: Double) -> String {
        if cost == 0 { return "Free" }
        if cost < 0.01 { return "<$0.01" }
        if cost < 1 { return String(format: "$%.2f", cost) }
        return String(format: "$%.2f", cost)
    }
}

// MARK: - Provider Info

/// Complete information about an API provider
public struct LMAPIProviderInfo: Identifiable, Sendable {
    public let id: APIKeyManager.KeyType
    public let name: String
    public let categories: [LMAPIProviderCategory]
    public let shortDescription: String
    public let fullDescription: String
    public let usageInApp: String
    public let pricing: LMAPIPricing
    public let conversationEstimate: ConversationCostEstimate?
    public let models: [ModelInfo]
    public let websiteURL: URL?
    public let apiDocsURL: URL?
    public let tips: [String]

    /// Information about a specific model from this provider
    public struct ModelInfo: Identifiable, Sendable {
        public let id: String
        public let name: String
        public let description: String
        public let pricing: LMAPIPricing?
        public let isRecommended: Bool

        public init(
            id: String,
            name: String,
            description: String,
            pricing: LMAPIPricing? = nil,
            isRecommended: Bool = false
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.pricing = pricing
            self.isRecommended = isRecommended
        }
    }
}

// MARK: - Provider Registry

/// Registry of all supported API providers with their information
public enum LMAPIProviderRegistry {

    /// Get provider info for a given key type
    public static func info(for keyType: APIKeyManager.KeyType) -> LMAPIProviderInfo {
        switch keyType {
        case .assemblyAI:
            return assemblyAIInfo
        case .deepgram:
            return deepgramInfo
        case .openAI:
            return openAIInfo
        case .anthropic:
            return anthropicInfo
        case .elevenLabs:
            return elevenLabsInfo
        case .liveKit:
            return liveKitInfo
        case .liveKitSecret:
            return liveKitSecretInfo
        }
    }

    // MARK: - AssemblyAI

    private static var assemblyAIInfo: LMAPIProviderInfo {
        LMAPIProviderInfo(
            id: .assemblyAI,
            name: "AssemblyAI",
            categories: [.speechToText],
            shortDescription: "Speech recognition",
            fullDescription: """
                AssemblyAI provides state-of-the-art speech recognition with real-time streaming \
                capabilities. Their Universal-2 model offers excellent accuracy across accents \
                and handles background noise well.
                """,
            usageInApp: """
                UnaMentis uses AssemblyAI to transcribe your voice in real-time during tutoring \
                sessions. This allows the AI tutor to understand your questions and responses \
                as you speak naturally.

                When enabled, audio is streamed to AssemblyAI's servers, transcribed, and the \
                text is sent to the language model for processing.
                """,
            pricing: LMAPIPricing(
                inputCost: 0.37,
                inputUnit: .perMinute,
                notes: "Real-time streaming. Billed per second of audio."
            ),
            conversationEstimate: ConversationCostEstimate(
                tenMinuteCost: 0.19, // ~5 min of actual speech
                sixtyMinuteCost: 1.11, // ~30 min of actual speech
                assumptions: "Assumes ~50% of session is active speech. Pauses and AI responses not billed."
            ),
            models: [
                LMAPIProviderInfo.ModelInfo(
                    id: "universal-2",
                    name: "Universal-2",
                    description: "Best accuracy, handles accents and noise well",
                    isRecommended: true
                ),
                LMAPIProviderInfo.ModelInfo(
                    id: "nano",
                    name: "Nano",
                    description: "Faster but less accurate, good for simple speech"
                )
            ],
            websiteURL: URL(string: "https://www.assemblyai.com"),
            apiDocsURL: URL(string: "https://www.assemblyai.com/docs"),
            tips: [
                "AssemblyAI charges only for actual speech detected",
                "Silence and pauses are not billed",
                "Consider using on-device alternatives for cost savings on long sessions"
            ]
        )
    }

    // MARK: - Deepgram

    private static var deepgramInfo: LMAPIProviderInfo {
        LMAPIProviderInfo(
            id: .deepgram,
            name: "Deepgram",
            categories: [.speechToText, .textToSpeech],
            shortDescription: "Speech recognition + voice synthesis",
            fullDescription: """
                Deepgram offers both speech-to-text (Nova-3) and text-to-speech (Aura-2) services. \
                Nova-3 is one of the fastest real-time transcription engines available, while \
                Aura-2 produces natural-sounding voice output with low latency.
                """,
            usageInApp: """
                UnaMentis uses Deepgram in two ways:

                1. **Speech-to-Text (Nova-3)**: Transcribes your voice with very low latency, \
                enabling natural conversational flow with the AI tutor.

                2. **Text-to-Speech (Aura-2)**: Converts the AI tutor's responses into spoken \
                audio, providing a natural voice learning experience.

                A single Deepgram API key enables both features.
                """,
            pricing: LMAPIPricing(
                inputCost: 0.0043,
                inputUnit: .perMinute,
                notes: "Nova-3 STT: $0.0043/min. Aura-2 TTS: $0.0135/1K characters."
            ),
            conversationEstimate: ConversationCostEstimate(
                tenMinuteCost: 0.05, // STT + TTS combined
                sixtyMinuteCost: 0.30,
                assumptions: "Includes both transcription and voice synthesis. Very cost-effective."
            ),
            models: [
                LMAPIProviderInfo.ModelInfo(
                    id: "nova-3",
                    name: "Nova-3 (STT)",
                    description: "Latest transcription model, fastest latency",
                    pricing: LMAPIPricing(inputCost: 0.0043, inputUnit: .perMinute),
                    isRecommended: true
                ),
                LMAPIProviderInfo.ModelInfo(
                    id: "nova-2",
                    name: "Nova-2 (STT)",
                    description: "Previous generation, still excellent accuracy"
                ),
                LMAPIProviderInfo.ModelInfo(
                    id: "aura-2",
                    name: "Aura-2 (TTS)",
                    description: "Natural voice synthesis with streaming",
                    pricing: LMAPIPricing(inputCost: 0.0135, inputUnit: .perThousandCharacters),
                    isRecommended: true
                )
            ],
            websiteURL: URL(string: "https://deepgram.com"),
            apiDocsURL: URL(string: "https://developers.deepgram.com"),
            tips: [
                "Deepgram is the most cost-effective option for most users",
                "One API key covers both STT and TTS features",
                "Nova-3 has the lowest latency of any cloud STT provider"
            ]
        )
    }

    // MARK: - OpenAI

    private static var openAIInfo: LMAPIProviderInfo {
        LMAPIProviderInfo(
            id: .openAI,
            name: "OpenAI",
            categories: [.languageModel],
            shortDescription: "GPT AI tutor intelligence",
            fullDescription: """
                OpenAI's GPT models power the AI tutor's understanding and responses. GPT-4o \
                offers the best quality for complex explanations and nuanced tutoring, while \
                GPT-4o-mini provides a good balance of quality and cost for simpler interactions.
                """,
            usageInApp: """
                UnaMentis uses OpenAI's GPT models as the "brain" of the AI tutor:

                • **Understanding your questions**: Comprehends complex technical topics
                • **Generating explanations**: Creates clear, tailored explanations
                • **Adaptive teaching**: Adjusts responses based on your level
                • **Conversation memory**: Maintains context throughout sessions

                Different task types may use different models based on complexity—simple \
                acknowledgments use GPT-4o-mini, while complex explanations use GPT-4o.
                """,
            pricing: LMAPIPricing(
                inputCost: 2.50,
                outputCost: 10.00,
                inputUnit: .perMillionInputTokens,
                outputUnit: .perMillionOutputTokens,
                notes: "GPT-4o pricing. GPT-4o-mini is ~15x cheaper."
            ),
            conversationEstimate: ConversationCostEstimate(
                tenMinuteCost: 0.15, // ~3K input, ~2K output tokens
                sixtyMinuteCost: 0.90, // Scales with conversation length
                assumptions: "Using GPT-4o primarily. GPT-4o-mini would be ~$0.01-0.06 for same usage."
            ),
            models: [
                LMAPIProviderInfo.ModelInfo(
                    id: "gpt-4o",
                    name: "GPT-4o",
                    description: "Best quality, multimodal, great for complex topics",
                    pricing: LMAPIPricing(
                        inputCost: 2.50,
                        outputCost: 10.00,
                        inputUnit: .perMillionInputTokens,
                        outputUnit: .perMillionOutputTokens
                    ),
                    isRecommended: true
                ),
                LMAPIProviderInfo.ModelInfo(
                    id: "gpt-4o-mini",
                    name: "GPT-4o Mini",
                    description: "Fast and cost-effective, good for simple tasks",
                    pricing: LMAPIPricing(
                        inputCost: 0.15,
                        outputCost: 0.60,
                        inputUnit: .perMillionInputTokens,
                        outputUnit: .perMillionOutputTokens
                    )
                ),
                LMAPIProviderInfo.ModelInfo(
                    id: "gpt-4-turbo",
                    name: "GPT-4 Turbo",
                    description: "Previous generation, 128K context"
                )
            ],
            websiteURL: URL(string: "https://openai.com"),
            apiDocsURL: URL(string: "https://platform.openai.com/docs"),
            tips: [
                "For cost savings, the app uses GPT-4o-mini for simple acknowledgments",
                "Complex explanations automatically use GPT-4o for better quality",
                "~750 words ≈ 1,000 tokens for rough cost estimation",
                "You can set the 'Cost Optimized' preset to use mini models more"
            ]
        )
    }

    // MARK: - Anthropic

    private static var anthropicInfo: LMAPIProviderInfo {
        LMAPIProviderInfo(
            id: .anthropic,
            name: "Anthropic",
            categories: [.languageModel],
            shortDescription: "Claude AI tutor intelligence",
            fullDescription: """
                Anthropic's Claude models are known for nuanced understanding, following \
                complex instructions, and producing well-structured educational content. \
                Claude 3.5 Sonnet offers excellent tutoring capabilities with strong \
                reasoning abilities.
                """,
            usageInApp: """
                UnaMentis can use Claude as an alternative AI tutor brain:

                • **Thoughtful explanations**: Known for clear, well-organized responses
                • **Strong reasoning**: Excellent at breaking down complex concepts
                • **Context awareness**: Maintains nuanced conversation context
                • **Safe responses**: Built-in guardrails for appropriate content

                Claude is particularly strong at explaining "why" things work, making it \
                ideal for deep technical learning.
                """,
            pricing: LMAPIPricing(
                inputCost: 3.00,
                outputCost: 15.00,
                inputUnit: .perMillionInputTokens,
                outputUnit: .perMillionOutputTokens,
                notes: "Claude 3.5 Sonnet pricing. Haiku is ~10x cheaper."
            ),
            conversationEstimate: ConversationCostEstimate(
                tenMinuteCost: 0.18, // Similar token usage to GPT-4o
                sixtyMinuteCost: 1.08,
                assumptions: "Using Claude 3.5 Sonnet. Haiku would be ~$0.02-0.10 for same usage."
            ),
            models: [
                LMAPIProviderInfo.ModelInfo(
                    id: "claude-3-5-sonnet-20241022",
                    name: "Claude 3.5 Sonnet",
                    description: "Best balance of capability and speed",
                    pricing: LMAPIPricing(
                        inputCost: 3.00,
                        outputCost: 15.00,
                        inputUnit: .perMillionInputTokens,
                        outputUnit: .perMillionOutputTokens
                    ),
                    isRecommended: true
                ),
                LMAPIProviderInfo.ModelInfo(
                    id: "claude-3-5-haiku-20241022",
                    name: "Claude 3.5 Haiku",
                    description: "Fast and affordable, good for quick responses",
                    pricing: LMAPIPricing(
                        inputCost: 0.25,
                        outputCost: 1.25,
                        inputUnit: .perMillionInputTokens,
                        outputUnit: .perMillionOutputTokens
                    )
                ),
                LMAPIProviderInfo.ModelInfo(
                    id: "claude-3-opus-20240229",
                    name: "Claude 3 Opus",
                    description: "Most capable, best for complex reasoning"
                )
            ],
            websiteURL: URL(string: "https://anthropic.com"),
            apiDocsURL: URL(string: "https://docs.anthropic.com"),
            tips: [
                "Claude excels at explaining complex concepts step-by-step",
                "Claude 3.5 Haiku offers great value for simpler interactions",
                "You can switch between OpenAI and Anthropic in Language Model settings"
            ]
        )
    }

    // MARK: - ElevenLabs

    private static var elevenLabsInfo: LMAPIProviderInfo {
        LMAPIProviderInfo(
            id: .elevenLabs,
            name: "ElevenLabs",
            categories: [.textToSpeech],
            shortDescription: "Premium voice synthesis",
            fullDescription: """
                ElevenLabs produces the most natural and expressive AI voices available. \
                Their models can convey emotion, emphasis, and natural speech patterns \
                that make learning more engaging. Flash offers low latency; Turbo offers \
                highest quality.
                """,
            usageInApp: """
                UnaMentis uses ElevenLabs to give the AI tutor a natural, engaging voice:

                • **Expressive delivery**: Natural intonation makes listening easier
                • **Clear pronunciation**: Technical terms are spoken correctly
                • **Low latency streaming**: Responses start playing quickly
                • **Multiple voices**: Choose from various voice options

                The premium voice quality can reduce listening fatigue during long study \
                sessions and make the learning experience more pleasant.
                """,
            pricing: LMAPIPricing(
                inputCost: 0.18,
                inputUnit: .perThousandCharacters,
                notes: "~$0.000018 per character. Free tier: 10K characters/month."
            ),
            conversationEstimate: ConversationCostEstimate(
                tenMinuteCost: 0.09, // ~500 chars per minute of speech
                sixtyMinuteCost: 0.54,
                assumptions: "Assumes AI speaks ~50% of session time. ~500 characters per minute of speech."
            ),
            models: [
                LMAPIProviderInfo.ModelInfo(
                    id: "eleven_flash_v2_5",
                    name: "Flash v2.5",
                    description: "Low latency, good for real-time conversations",
                    isRecommended: true
                ),
                LMAPIProviderInfo.ModelInfo(
                    id: "eleven_turbo_v2_5",
                    name: "Turbo v2.5",
                    description: "Highest quality, slightly more latency"
                ),
                LMAPIProviderInfo.ModelInfo(
                    id: "eleven_multilingual_v2",
                    name: "Multilingual v2",
                    description: "Best for non-English content"
                )
            ],
            websiteURL: URL(string: "https://elevenlabs.io"),
            apiDocsURL: URL(string: "https://elevenlabs.io/docs"),
            tips: [
                "ElevenLabs offers a free tier with 10K characters/month",
                "Deepgram Aura is a more cost-effective alternative",
                "Premium voices can reduce listening fatigue in long sessions"
            ]
        )
    }

    // MARK: - LiveKit

    private static var liveKitInfo: LMAPIProviderInfo {
        LMAPIProviderInfo(
            id: .liveKit,
            name: "LiveKit (API Key)",
            categories: [.realtime],
            shortDescription: "Real-time audio infrastructure",
            fullDescription: """
                LiveKit provides real-time communication infrastructure for ultra-low-latency \
                audio streaming. It handles the complex networking required for seamless \
                voice conversations with minimal delay.
                """,
            usageInApp: """
                LiveKit enables real-time voice streaming features:

                • **Low-latency audio**: Sub-100ms round-trip latency
                • **Reliable delivery**: Handles network fluctuations gracefully
                • **Concurrent streams**: Supports multiple audio channels

                **Note:** LiveKit is optional. UnaMentis works without it using direct \
                API streaming, but LiveKit provides the best real-time experience.
                """,
            pricing: LMAPIPricing(
                inputCost: 0.0,
                inputUnit: .free,
                notes: "Free tier available. Usage-based pricing for high volume."
            ),
            conversationEstimate: ConversationCostEstimate(
                tenMinuteCost: 0.00,
                sixtyMinuteCost: 0.00,
                assumptions: "Free tier covers most individual learning use cases."
            ),
            models: [],
            websiteURL: URL(string: "https://livekit.io"),
            apiDocsURL: URL(string: "https://docs.livekit.io"),
            tips: [
                "LiveKit is optional but provides the best real-time experience",
                "Free tier is sufficient for personal learning use",
                "Both API Key and Secret are required if using LiveKit"
            ]
        )
    }

    // MARK: - LiveKit Secret

    private static var liveKitSecretInfo: LMAPIProviderInfo {
        LMAPIProviderInfo(
            id: .liveKitSecret,
            name: "LiveKit (Secret)",
            categories: [.realtime],
            shortDescription: "LiveKit authentication secret",
            fullDescription: """
                The LiveKit API Secret is used together with the API Key to authenticate \
                your application with LiveKit's servers. Both are required for LiveKit \
                integration.
                """,
            usageInApp: """
                The LiveKit Secret works together with the LiveKit API Key:

                • **Authentication**: Proves your app is authorized to use LiveKit
                • **Token generation**: Creates secure session tokens
                • **Server verification**: Validates connections are legitimate

                **Security Note:** Keep this secret secure. Never share it or commit it \
                to version control.
                """,
            pricing: LMAPIPricing.free,
            conversationEstimate: nil,
            models: [],
            websiteURL: URL(string: "https://livekit.io"),
            apiDocsURL: URL(string: "https://docs.livekit.io"),
            tips: [
                "Required only if you're using the LiveKit API Key",
                "Keep this value secret and secure",
                "Obtain from your LiveKit Cloud dashboard"
            ]
        )
    }
}

// MARK: - Combined Cost Estimation

public struct CombinedCostEstimator {

    /// Estimated total cost for a tutoring session using typical provider combination
    public struct SessionCostEstimate: Sendable {
        public let sttCost: Double
        public let llmCost: Double
        public let ttsCost: Double
        public let totalCost: Double
        public let sttProvider: String
        public let llmProvider: String
        public let ttsProvider: String
        public let duration: Int // minutes

        public var formattedTotal: String {
            if totalCost < 0.01 { return "<$0.01" }
            return String(format: "$%.2f", totalCost)
        }

        public var breakdown: String {
            """
            STT (\(sttProvider)): $\(String(format: "%.2f", sttCost))
            LLM (\(llmProvider)): $\(String(format: "%.2f", llmCost))
            TTS (\(ttsProvider)): $\(String(format: "%.2f", ttsCost))
            """
        }
    }

    /// Estimate costs for a session with given providers
    public static func estimate(
        durationMinutes: Int,
        sttProvider: APIKeyManager.KeyType = .deepgram,
        llmProvider: APIKeyManager.KeyType = .openAI,
        ttsProvider: APIKeyManager.KeyType = .deepgram
    ) -> SessionCostEstimate {
        // Assumptions:
        // - 50% of session is user speaking (STT)
        // - ~200 tokens/minute of LLM input (user + context)
        // - ~150 tokens/minute of LLM output (responses)
        // - 50% of session is AI speaking (TTS)
        // - ~500 characters per minute of TTS

        let speechMinutes = Double(durationMinutes) * 0.5
        let tokensInput = Double(durationMinutes) * 200
        let tokensOutput = Double(durationMinutes) * 150
        let ttsCharacters = Double(durationMinutes) * 250 // AI speaks half, 500 chars/min

        let sttCost: Double
        let sttName: String
        switch sttProvider {
        case .assemblyAI:
            sttCost = speechMinutes * 0.0062 // $0.37/hour = $0.0062/min
            sttName = "AssemblyAI"
        case .deepgram:
            sttCost = speechMinutes * 0.0043
            sttName = "Deepgram"
        default:
            sttCost = 0
            sttName = "On-Device"
        }

        let llmCost: Double
        let llmName: String
        switch llmProvider {
        case .openAI:
            // GPT-4o: $2.50/1M input, $10/1M output
            llmCost = (tokensInput * 2.50 / 1_000_000) + (tokensOutput * 10.0 / 1_000_000)
            llmName = "OpenAI GPT-4o"
        case .anthropic:
            // Claude 3.5 Sonnet: $3/1M input, $15/1M output
            llmCost = (tokensInput * 3.0 / 1_000_000) + (tokensOutput * 15.0 / 1_000_000)
            llmName = "Claude 3.5 Sonnet"
        default:
            llmCost = 0
            llmName = "On-Device"
        }

        let ttsCost: Double
        let ttsName: String
        switch ttsProvider {
        case .deepgram:
            ttsCost = ttsCharacters * 0.0135 / 1000 // $0.0135/1K chars
            ttsName = "Deepgram Aura"
        case .elevenLabs:
            ttsCost = ttsCharacters * 0.00018 // $0.18/1K chars = $0.00018/char
            ttsName = "ElevenLabs"
        default:
            ttsCost = 0
            ttsName = "Apple TTS"
        }

        return SessionCostEstimate(
            sttCost: sttCost,
            llmCost: llmCost,
            ttsCost: ttsCost,
            totalCost: sttCost + llmCost + ttsCost,
            sttProvider: sttName,
            llmProvider: llmName,
            ttsProvider: ttsName,
            duration: durationMinutes
        )
    }

    /// Pre-computed estimates for common configurations
    public static var costOptimizedEstimate10Min: SessionCostEstimate {
        // Deepgram STT + GPT-4o-mini + Deepgram TTS
        SessionCostEstimate(
            sttCost: 0.02,
            llmCost: 0.01,
            ttsCost: 0.01,
            totalCost: 0.04,
            sttProvider: "Deepgram Nova-3",
            llmProvider: "GPT-4o Mini",
            ttsProvider: "Deepgram Aura",
            duration: 10
        )
    }

    public static var balancedEstimate10Min: SessionCostEstimate {
        estimate(durationMinutes: 10)
    }

    public static var balancedEstimate60Min: SessionCostEstimate {
        estimate(durationMinutes: 60)
    }
}
