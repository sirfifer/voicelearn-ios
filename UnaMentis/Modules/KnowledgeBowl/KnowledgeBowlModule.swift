// UnaMentis - Knowledge Bowl Module
// Specialized training module for Knowledge Bowl competition preparation
//
// Knowledge Bowl is an academic competition where teams answer questions
// across 12+ subject domains with emphasis on speed and breadth.
// This module provides:
// - Directed study across all domains
// - Speed training with sub-3-second response targets
// - Competition simulation with buzzer mechanics
// - Team collaboration mode

import SwiftUI
import Logging

/// Knowledge Bowl training module
///
/// Implements the ModuleProtocol to provide Knowledge Bowl-specific
/// training features within the UnaMentis app.
public struct KnowledgeBowlModule: ModuleProtocol {
    public let id = "knowledge-bowl"
    public let name = "Knowledge Bowl"
    public let shortDescription = "Academic competition prep across 12 subject domains"
    public let longDescription = """
        Prepare for Knowledge Bowl competitions with directed study, \
        speed training, and realistic competition simulation. \
        Track your mastery across Science, Math, Literature, History, \
        and 8 other domains. Practice solo or with your team.
        """
    public let iconName = "brain.head.profile"
    public let themeColor = Color.purple
    public let supportsTeamMode = true
    public let supportsSpeedTraining = true
    public let supportsCompetitionSim = true
    public let version = "1.0.0"

    private static let logger = Logger(label: "com.unamentis.modules.knowledgebowl")

    public init() {
        Self.logger.info("Knowledge Bowl module initialized")
    }

    @MainActor
    public func makeRootView() -> AnyView {
        AnyView(KBDashboardView())
    }

    @MainActor
    public func makeDashboardView() -> AnyView {
        AnyView(KBDashboardSummary())
    }
}

// MARK: - Domain Reference
// Note: KBDomain is defined in Shared/KnowledgeBowl/KBDomain.swift
// for cross-target access (iOS and watchOS)

// MARK: - Dashboard Summary

/// Compact summary view shown in the modules list
struct KBDashboardSummary: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Knowledge Bowl")
                    .font(.headline)
                Text("12 domains to explore")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Models and Engine
// Models are defined in Models/KBQuestion.swift with Sendable conformance
// Practice Engine is defined in Engine/KBPracticeEngine.swift
