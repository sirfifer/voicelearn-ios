//
//  KBDomain.swift
//  UnaMentis
//
//  Knowledge Bowl domain enumeration - shared between iOS and watchOS targets.
//

import Foundation
import SwiftUI

/// The 12 academic domains used in Knowledge Bowl competitions.
/// This is defined in Shared/ so both iOS and watchOS targets can access it.
public enum KBDomain: String, CaseIterable, Codable, Identifiable, Sendable {
    case science
    case mathematics
    case literature
    case history
    case socialStudies
    case arts
    case currentEvents
    case language
    case technology
    case popCulture
    case religionPhilosophy
    case miscellaneous

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .science: return "Science"
        case .mathematics: return "Mathematics"
        case .literature: return "Literature"
        case .history: return "History"
        case .socialStudies: return "Social Studies"
        case .arts: return "Arts"
        case .currentEvents: return "Current Events"
        case .language: return "Language"
        case .technology: return "Technology"
        case .popCulture: return "Pop Culture"
        case .religionPhilosophy: return "Religion/Philosophy"
        case .miscellaneous: return "Miscellaneous"
        }
    }

    public var icon: String {
        switch self {
        case .science: return "atom"
        case .mathematics: return "function"
        case .literature: return "book.closed"
        case .history: return "clock.arrow.circlepath"
        case .socialStudies: return "globe.americas"
        case .arts: return "paintpalette"
        case .currentEvents: return "newspaper"
        case .language: return "textformat"
        case .technology: return "cpu"
        case .popCulture: return "star"
        case .religionPhilosophy: return "sparkles"
        case .miscellaneous: return "questionmark.circle"
        }
    }

    /// Weight in typical Knowledge Bowl question distribution
    public var weight: Double {
        switch self {
        case .science: return 0.20
        case .mathematics: return 0.15
        case .literature: return 0.12
        case .history: return 0.12
        case .socialStudies: return 0.10
        case .arts: return 0.08
        case .currentEvents: return 0.08
        case .language: return 0.05
        case .technology: return 0.04
        case .popCulture: return 0.03
        case .religionPhilosophy: return 0.02
        case .miscellaneous: return 0.01
        }
    }

    /// Alias for icon (backward compatibility with Modules/KnowledgeBowl views)
    public var iconName: String { icon }

    /// Subcategories within the domain
    public var subcategories: [String] {
        switch self {
        case .science:
            return ["Biology", "Chemistry", "Physics", "Earth Science", "Astronomy"]
        case .mathematics:
            return ["Arithmetic", "Algebra", "Geometry", "Calculus", "Statistics"]
        case .literature:
            return ["American", "British", "World", "Poetry", "Drama"]
        case .history:
            return ["US", "World", "Ancient", "Modern", "Military"]
        case .socialStudies:
            return ["Geography", "Government", "Economics", "Sociology"]
        case .arts:
            return ["Visual Arts", "Music", "Theater", "Architecture"]
        case .currentEvents:
            return ["Politics", "Science", "Culture", "Sports", "Technology"]
        case .language:
            return ["Grammar", "Vocabulary", "Etymology", "Foreign Languages"]
        case .technology:
            return ["Computer Science", "Engineering", "Inventions"]
        case .popCulture:
            return ["Entertainment", "Media", "Sports", "Games"]
        case .religionPhilosophy:
            return ["World Religions", "Ethics", "Philosophy"]
        case .miscellaneous:
            return ["Trivia", "Cross-domain", "Puzzles"]
        }
    }

    /// Theme color for the domain (uses system colors for cross-platform support)
    public var color: Color {
        switch self {
        case .science: return .blue
        case .mathematics: return .purple
        case .literature: return .brown
        case .history: return .orange
        case .socialStudies: return .teal
        case .arts: return .pink
        case .currentEvents: return .yellow
        case .language: return .gray
        case .technology: return .cyan
        case .popCulture: return .red
        case .religionPhilosophy: return .indigo
        case .miscellaneous: return .mint
        }
    }
}
