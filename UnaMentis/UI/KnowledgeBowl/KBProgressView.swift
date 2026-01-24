//
//  KBProgressView.swift
//  UnaMentis
//
//  Progress tracking view for Knowledge Bowl.
//  Shows overall progress, accuracy trends, and practice history.
//

import SwiftUI

// MARK: - Progress View

/// Main progress view showing overall Knowledge Bowl statistics
struct KBProgressView: View {
    @State private var viewModel = KBProgressViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                progressHeader

                // Quick Stats
                quickStatsCards

                // Accuracy Trend
                accuracyTrendCard

                // Domain Progress
                domainProgressCard

                // Recent Sessions
                recentSessionsCard
            }
            .padding()
        }
        .navigationTitle("Progress")
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
    }

    // MARK: - Header

    private var progressHeader: some View {
        VStack(spacing: 12) {
            // Level Badge
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(viewModel.levelColor.opacity(0.2))
                        .frame(width: 80, height: 80)

                    VStack(spacing: 2) {
                        Text("\(viewModel.currentLevel)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Level")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.levelTitle)
                        .font(.title3.bold())

                    ProgressView(value: viewModel.levelProgress)
                        .tint(viewModel.levelColor)

                    Text("\(viewModel.xpToNextLevel) XP to next level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Quick Stats

    private var quickStatsCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            quickStatCard(
                title: "Total Sessions",
                value: "\(viewModel.totalSessions)",
                icon: "list.bullet.clipboard",
                color: Color.kbStrong
            )

            quickStatCard(
                title: "Questions Answered",
                value: "\(viewModel.totalQuestions)",
                icon: "questionmark.circle",
                color: Color.kbExcellent
            )

            quickStatCard(
                title: "Overall Accuracy",
                value: "\(Int(viewModel.overallAccuracy * 100))%",
                icon: "target",
                color: accuracyColor(viewModel.overallAccuracy)
            )

            quickStatCard(
                title: "Practice Time",
                value: formatDuration(viewModel.totalPracticeTime),
                icon: "clock",
                color: .orange
            )
        }
    }

    private func quickStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Accuracy Trend

    private var accuracyTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accuracy Trend")
                    .font(.headline)

                Spacer()

                Picker("Period", selection: $viewModel.selectedPeriod) {
                    Text("Week").tag(KBProgressViewModel.TimePeriod.week)
                    Text("Month").tag(KBProgressViewModel.TimePeriod.month)
                    Text("All").tag(KBProgressViewModel.TimePeriod.all)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            // Simple bar chart
            if viewModel.accuracyHistory.isEmpty {
                ContentUnavailableView(
                    "No Data Yet",
                    systemImage: "chart.bar",
                    description: Text("Complete some practice sessions to see your trends")
                )
                .frame(height: 150)
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(viewModel.accuracyHistory.enumerated()), id: \.offset) { index, dataPoint in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(accuracyColor(dataPoint.accuracy))
                                .frame(width: 24, height: max(20, CGFloat(dataPoint.accuracy) * 100))

                            Text(dataPoint.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Domain Progress

    private var domainProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                KBDomainMasteryView()
            } label: {
                HStack {
                    Text("Domain Mastery")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }

            // Top 3 domains
            ForEach(viewModel.topDomains.prefix(3)) { domain in
                HStack {
                    Image(systemName: domain.domain.icon)
                        .foregroundStyle(domain.domain.color)
                        .frame(width: 24)

                    Text(domain.domain.displayName)
                        .font(.subheadline)

                    Spacer()

                    Text("\(Int(domain.mastery * 100))%")
                        .font(.subheadline.bold())
                        .foregroundStyle(masteryColor(domain.mastery))
                }
            }

            if viewModel.topDomains.isEmpty {
                Text("No domain data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recent Sessions

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)

            if viewModel.recentSessions.isEmpty {
                Text("No sessions yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.recentSessions) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.type)
                                .font(.subheadline.bold())
                            Text(session.date, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(session.correct)/\(session.total)")
                                .font(.subheadline.bold())
                            Text("\(Int(session.accuracy * 100))%")
                                .font(.caption)
                                .foregroundStyle(accuracyColor(session.accuracy))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func accuracyColor(_ accuracy: Double) -> Color {
        if accuracy >= 0.8 { return .green }
        if accuracy >= 0.6 { return .orange }
        return .red
    }

    private func masteryColor(_ mastery: Double) -> Color {
        if mastery >= 0.8 { return Color.kbExcellent }
        if mastery >= 0.6 { return Color.kbStrong }
        if mastery >= 0.4 { return .orange }
        return .red
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - View Model

@MainActor
@Observable
final class KBProgressViewModel {
    enum TimePeriod {
        case week
        case month
        case all
    }

    // Stats
    private(set) var currentLevel: Int = 1
    private(set) var levelTitle: String = "Beginner"
    private(set) var levelProgress: Double = 0.0
    private(set) var xpToNextLevel: Int = 100
    private(set) var levelColor: Color = .blue

    private(set) var totalSessions: Int = 0
    private(set) var totalQuestions: Int = 0
    private(set) var overallAccuracy: Double = 0.0
    private(set) var totalPracticeTime: TimeInterval = 0

    // Trend data
    var selectedPeriod: TimePeriod = .week
    private(set) var accuracyHistory: [AccuracyDataPoint] = []

    // Domain data
    private(set) var topDomains: [DomainMasteryItem] = []

    // Session data
    private(set) var recentSessions: [RecentSession] = []

    struct AccuracyDataPoint: Identifiable {
        let id = UUID()
        let label: String
        let accuracy: Double
    }

    struct DomainMasteryItem: Identifiable {
        let id = UUID()
        let domain: KBDomain
        let mastery: Double
    }

    struct RecentSession: Identifiable {
        let id = UUID()
        let type: String
        let date: Date
        let correct: Int
        let total: Int
        let accuracy: Double
    }

    func loadData() async {
        // Calculate level from XP
        let totalXP = 450 // Would come from analytics service
        currentLevel = min(10, (totalXP / 100) + 1)
        levelProgress = Double(totalXP % 100) / 100.0
        xpToNextLevel = 100 - (totalXP % 100)
        levelTitle = levelTitle(for: currentLevel)
        levelColor = levelColor(for: currentLevel)

        // Load stats
        totalSessions = 12
        totalQuestions = 245
        overallAccuracy = 0.72
        totalPracticeTime = 3600 * 2.5 // 2.5 hours

        // Load trend data
        accuracyHistory = [
            AccuracyDataPoint(label: "Mon", accuracy: 0.65),
            AccuracyDataPoint(label: "Tue", accuracy: 0.70),
            AccuracyDataPoint(label: "Wed", accuracy: 0.68),
            AccuracyDataPoint(label: "Thu", accuracy: 0.75),
            AccuracyDataPoint(label: "Fri", accuracy: 0.72),
            AccuracyDataPoint(label: "Sat", accuracy: 0.78),
            AccuracyDataPoint(label: "Sun", accuracy: 0.80)
        ]

        // Load domain data
        topDomains = [
            DomainMasteryItem(domain: .science, mastery: 0.85),
            DomainMasteryItem(domain: .mathematics, mastery: 0.78),
            DomainMasteryItem(domain: .history, mastery: 0.72),
            DomainMasteryItem(domain: .literature, mastery: 0.65),
            DomainMasteryItem(domain: .socialStudies, mastery: 0.60)
        ]

        // Load recent sessions
        recentSessions = [
            RecentSession(type: "Oral Practice", date: Date().addingTimeInterval(-3600), correct: 18, total: 20, accuracy: 0.90),
            RecentSession(type: "Written Practice", date: Date().addingTimeInterval(-86400), correct: 35, total: 40, accuracy: 0.875),
            RecentSession(type: "Match Simulation", date: Date().addingTimeInterval(-172800), correct: 28, total: 40, accuracy: 0.70)
        ]
    }

    private func levelTitle(for level: Int) -> String {
        switch level {
        case 1: return "Beginner"
        case 2...3: return "Apprentice"
        case 4...5: return "Intermediate"
        case 6...7: return "Advanced"
        case 8...9: return "Expert"
        default: return "Master"
        }
    }

    private func levelColor(for level: Int) -> Color {
        switch level {
        case 1: return .gray
        case 2...3: return .green
        case 4...5: return .blue
        case 6...7: return .purple
        case 8...9: return .orange
        default: return .yellow
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        KBProgressView()
    }
}
