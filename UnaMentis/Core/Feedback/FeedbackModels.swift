// UnaMentis - Feedback Models
// Types and enums for beta tester feedback system
//
// Follows industry best practices for beta testing feedback collection

import Foundation
import SwiftUI

/// Feedback category types following industry beta testing standards
public enum FeedbackCategory: String, CaseIterable, Sendable {
    case bug = "Bug Report"
    case feature = "Feature Request"
    case content = "Curriculum Content"
    case performance = "Performance Issue"
    case audio = "Audio Quality"
    case ui = "UI/UX"
    case other = "Other"

    /// SF Symbol icon for each category
    public var systemImage: String {
        switch self {
        case .bug: return "ladybug.fill"
        case .feature: return "lightbulb.fill"
        case .content: return "book.fill"
        case .performance: return "gauge.with.dots.needle.67percent"
        case .audio: return "waveform"
        case .ui: return "paintbrush.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    /// Category-specific prompt following TestFlight best practices
    /// Provides context-appropriate guidance for each feedback type
    public var messagePrompt: LocalizedStringKey {
        switch self {
        case .bug:
            return "feedback.prompt.bug"
        case .feature:
            return "feedback.prompt.feature"
        case .performance:
            return "feedback.prompt.performance"
        case .audio:
            return "feedback.prompt.audio"
        case .content:
            return "feedback.prompt.content"
        case .ui:
            return "feedback.prompt.ui"
        case .other:
            return "feedback.prompt.other"
        }
    }
}

/// Context captured when feedback is triggered
/// Auto-populated from app state to provide debugging context
public struct FeedbackContext: Sendable {
    public let currentScreen: String
    public let navigationPath: [String]
    public let sessionActive: Bool
    public let sessionDuration: TimeInterval?
    public let sessionState: String?
    public let turnCount: Int?
    public let topicId: UUID?

    public init(
        currentScreen: String,
        navigationPath: [String],
        sessionActive: Bool = false,
        sessionDuration: TimeInterval? = nil,
        sessionState: String? = nil,
        turnCount: Int? = nil,
        topicId: UUID? = nil
    ) {
        self.currentScreen = currentScreen
        self.navigationPath = navigationPath
        self.sessionActive = sessionActive
        self.sessionDuration = sessionDuration
        self.sessionState = sessionState
        self.turnCount = turnCount
        self.topicId = topicId
    }
}

/// Device diagnostics (requires user opt-in per GDPR/CCPA)
/// Collected only when user explicitly consents via privacy toggle
public struct DeviceDiagnostics: Sendable {
    public let memoryUsageMB: Int
    public let batteryLevel: Float
    public let networkType: String
    public let lowPowerMode: Bool

    public init(
        memoryUsageMB: Int,
        batteryLevel: Float,
        networkType: String,
        lowPowerMode: Bool
    ) {
        self.memoryUsageMB = memoryUsageMB
        self.batteryLevel = batteryLevel
        self.networkType = networkType
        self.lowPowerMode = lowPowerMode
    }
}
