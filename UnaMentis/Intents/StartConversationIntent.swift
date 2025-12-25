// UnaMentis - Start Conversation Intent
// Enables "Hey Siri, start a conversation with UnaMentis" voice commands
// for freeform voice chat without requiring a specific topic
//
// Part of Apple Intelligence Integration (iOS 16+)

import AppIntents

/// App Intent for starting a freeform voice conversation
///
/// This intent enables hands-free access to the voice chat without
/// requiring a specific topic or curriculum. Perfect for:
/// - Spontaneous learning when walking or doing other activities
/// - Quick questions without navigating through the app
/// - General knowledge exploration
///
/// Enables voice commands like:
/// - "Hey Siri, start a conversation with UnaMentis"
/// - "Hey Siri, talk to UnaMentis"
/// - "Hey Siri, open UnaMentis chat"
/// - "Hey Siri, I want to learn something"
public struct StartConversationIntent: AppIntent {
    public static let title: LocalizedStringResource = "Start Conversation"

    public static let description = IntentDescription(
        "Start a freeform voice conversation for spontaneous learning",
        categoryName: "Learning",
        searchKeywords: ["talk", "chat", "conversation", "voice", "ask", "learn", "question"]
    )

    /// Optional prompt to seed the conversation
    @Parameter(
        title: "Question",
        description: "An optional question or topic to start with",
        requestValueDialog: IntentDialog("What would you like to learn about?")
    )
    public var initialPrompt: String?

    public init() {}

    /// Perform the intent
    public func perform() async throws -> some IntentResult & OpensIntent {
        // Build deep link URL - simple chat URL with optional prompt
        var urlString = "unamentis://chat"

        if let prompt = initialPrompt, !prompt.isEmpty {
            // URL encode the prompt
            let encoded = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            urlString += "?prompt=\(encoded)"
        }

        guard let url = URL(string: urlString) else {
            throw StartConversationError.invalidConfiguration
        }

        // Return result that opens the app
        let responseText: String
        if let prompt = initialPrompt, !prompt.isEmpty {
            responseText = "Starting conversation about \(prompt)"
        } else {
            responseText = "Starting voice conversation"
        }

        return .result(
            value: responseText,
            opensIntent: OpenURLIntent(url)
        )
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Start a voice conversation") {
            \.$initialPrompt
        }
    }
}

// MARK: - Errors

/// Errors for StartConversationIntent
public enum StartConversationError: Error, CustomLocalizedStringResourceConvertible {
    case invalidConfiguration
    case appNotReady

    public var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidConfiguration:
            return "Unable to start conversation. Please try again."
        case .appNotReady:
            return "UnaMentis is not ready. Please open the app first."
        }
    }
}
