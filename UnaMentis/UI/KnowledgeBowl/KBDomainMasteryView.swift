//
//  KBDomainMasteryView.swift
//  UnaMentis
//
//  Domain mastery view for Knowledge Bowl.
//  Shows detailed progress for each academic domain.
//

import SwiftUI

// MARK: - Domain Mastery View

/// Detailed view showing mastery level for each Knowledge Bowl domain
struct KBDomainMasteryView: View {
    @State private var viewModel = KBDomainMasteryViewModel()
    @State private var selectedDomain: KBDomain?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Mastery Grid
                masteryGrid

                // Selected Domain Detail
                if let domain = selectedDomain {
                    domainDetailCard(domain)
                }

                // Recommendations
                recommendationsCard
            }
            .padding()
        }
        .navigationTitle("Domain Mastery")
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Mastery Grid

    private var masteryGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(KBDomain.allCases) { domain in
                domainCell(domain)
            }
        }
    }

    private func domainCell(_ domain: KBDomain) -> some View {
        let mastery = viewModel.getMastery(for: domain)
        let isSelected = selectedDomain == domain

        return Button {
            withAnimation {
                selectedDomain = selectedDomain == domain ? nil : domain
            }
        } label: {
            VStack(spacing: 8) {
                // Icon with progress ring
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 4)

                    Circle()
                        .trim(from: 0, to: mastery)
                        .stroke(domain.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Image(systemName: domain.icon)
                        .font(.title3)
                        .foregroundStyle(domain.color)
                }
                .frame(width: 50, height: 50)

                Text(domain.displayName)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(Int(mastery * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(masteryColor(mastery))
            }
            .padding(12)
            .background(isSelected ? domain.color.opacity(0.15) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? domain.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Domain Detail Card

    private func domainDetailCard(_ domain: KBDomain) -> some View {
        let stats = viewModel.getStats(for: domain)

        return VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: domain.icon)
                    .font(.title2)
                    .foregroundStyle(domain.color)

                Text(domain.displayName)
                    .font(.title3.bold())

                Spacer()

                Text(masteryLevel(stats.mastery))
                    .font(.subheadline.bold())
                    .foregroundStyle(masteryColor(stats.mastery))
            }

            Divider()

            // Stats
            HStack(spacing: 24) {
                statItem("Questions", value: "\(stats.questionsAnswered)")
                statItem("Accuracy", value: "\(Int(stats.accuracy * 100))%")
                statItem("Streak", value: "\(stats.currentStreak)")
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                Text("Progress to next level")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))

                        Capsule()
                            .fill(domain.color)
                            .frame(width: geo.size.width * stats.progressToNextLevel)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(masteryLevel(stats.mastery))
                        .font(.caption2)
                    Spacer()
                    Text(nextMasteryLevel(stats.mastery))
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            // Strengths/Weaknesses
            if !stats.strengths.isEmpty || !stats.weaknesses.isEmpty {
                Divider()

                if !stats.strengths.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Strengths", systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.green)

                        ForEach(stats.strengths, id: \.self) { strength in
                            Text("- \(strength)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !stats.weaknesses.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Focus Areas", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)

                        ForEach(stats.weaknesses, id: \.self) { weakness in
                            Text("- \(weakness)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Practice button
            NavigationLink {
                Text("Domain Drill: \(domain.displayName)")
            } label: {
                Label("Practice \(domain.displayName)", systemImage: "play.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(domain.color)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statItem(_ title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Recommendations

    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)

            ForEach(viewModel.recommendations) { rec in
                HStack(spacing: 12) {
                    Image(systemName: rec.icon)
                        .font(.title3)
                        .foregroundStyle(rec.color)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(rec.title)
                            .font(.subheadline.bold())
                        Text(rec.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func masteryColor(_ mastery: Double) -> Color {
        if mastery >= 0.8 { return Color.kbExcellent }
        if mastery >= 0.6 { return Color.kbStrong }
        if mastery >= 0.4 { return .orange }
        return .red
    }

    private func masteryLevel(_ mastery: Double) -> String {
        if mastery >= 0.9 { return "Master" }
        if mastery >= 0.75 { return "Expert" }
        if mastery >= 0.6 { return "Proficient" }
        if mastery >= 0.4 { return "Learning" }
        return "Beginner"
    }

    private func nextMasteryLevel(_ mastery: Double) -> String {
        if mastery >= 0.9 { return "Max" }
        if mastery >= 0.75 { return "Master" }
        if mastery >= 0.6 { return "Expert" }
        if mastery >= 0.4 { return "Proficient" }
        return "Learning"
    }
}

// MARK: - View Model

@MainActor
@Observable
final class KBDomainMasteryViewModel {
    private var domainData: [KBDomain: DomainStats] = [:]
    private(set) var recommendations: [Recommendation] = []

    struct DomainStats {
        var mastery: Double
        var questionsAnswered: Int
        var accuracy: Double
        var currentStreak: Int
        var progressToNextLevel: Double
        var strengths: [String]
        var weaknesses: [String]
    }

    struct Recommendation: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let icon: String
        let color: Color
    }

    func loadData() async {
        // Populate sample data
        for domain in KBDomain.allCases {
            let mastery = Double.random(in: 0.3...0.95)
            domainData[domain] = DomainStats(
                mastery: mastery,
                questionsAnswered: Int.random(in: 10...100),
                accuracy: Double.random(in: 0.5...0.95),
                currentStreak: Int.random(in: 0...10),
                progressToNextLevel: Double.random(in: 0.2...0.9),
                strengths: mastery > 0.7 ? ["Quick recall", "Consistent accuracy"] : [],
                weaknesses: mastery < 0.5 ? ["Needs more practice", "Review fundamentals"] : []
            )
        }

        // Generate recommendations
        let lowestDomains = KBDomain.allCases
            .sorted { getMastery(for: $0) < getMastery(for: $1) }
            .prefix(2)

        recommendations = lowestDomains.map { domain in
            Recommendation(
                title: "Practice \(domain.displayName)",
                description: "Your mastery is at \(Int(getMastery(for: domain) * 100))%. Focus on improving this area.",
                icon: domain.icon,
                color: domain.color
            )
        }

        recommendations.append(Recommendation(
            title: "Try a Match Simulation",
            description: "Test your skills across all domains in a realistic competition setting.",
            icon: "trophy",
            color: .yellow
        ))
    }

    func getMastery(for domain: KBDomain) -> Double {
        domainData[domain]?.mastery ?? 0
    }

    func getStats(for domain: KBDomain) -> DomainStats {
        domainData[domain] ?? DomainStats(
            mastery: 0,
            questionsAnswered: 0,
            accuracy: 0,
            currentStreak: 0,
            progressToNextLevel: 0,
            strengths: [],
            weaknesses: []
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        KBDomainMasteryView()
    }
}
