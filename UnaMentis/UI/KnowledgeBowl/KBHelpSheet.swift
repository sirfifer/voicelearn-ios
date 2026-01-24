//
//  KBHelpSheet.swift
//  UnaMentis
//
//  Main help modal for Knowledge Bowl module
//

import SwiftUI

// MARK: - KB Help Sheet

/// Main help modal for Knowledge Bowl features, strategy, and regional rules
struct KBHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Overview Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(KBHelpContent.General.gettingStarted)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Getting Started Section
                Section("Getting Started") {
                    NavigationLink {
                        KBGettingStartedHelpView()
                    } label: {
                        KBHelpRow(
                            icon: "figure.walk",
                            iconColor: .green,
                            title: "Recommended Path",
                            description: "Step-by-step guide to becoming competition-ready"
                        )
                    }
                }

                // Training Modes Section
                Section("Training Modes") {
                    NavigationLink {
                        KBTrainingModesHelpView()
                    } label: {
                        KBHelpRow(
                            icon: "graduationcap.fill",
                            iconColor: .blue,
                            title: "Practice Modes",
                            description: "Oral, Written, Match, Conference, Rebound, Domain Drill"
                        )
                    }
                }

                // Competition Strategy Section
                Section("Competition Strategy") {
                    NavigationLink {
                        KBStrategyHelpView()
                    } label: {
                        KBHelpRow(
                            icon: "trophy.fill",
                            iconColor: .orange,
                            title: "Winning Strategies",
                            description: "Buzzing, conferring, rebounds, and time management"
                        )
                    }
                }

                // Regional Rules Section
                Section("Regional Rules") {
                    NavigationLink {
                        KBRegionalRulesHelpView()
                    } label: {
                        KBHelpRow(
                            icon: "map.fill",
                            iconColor: .purple,
                            title: "State Rules",
                            description: "Colorado, Minnesota, and Washington differences"
                        )
                    }
                }

                // Tips for Success Section
                Section("Tips for Success") {
                    VStack(alignment: .leading, spacing: 12) {
                        KBTipRow(
                            icon: "calendar",
                            text: "Practice 20-30 minutes daily for best results"
                        )
                        KBTipRow(
                            icon: "chart.line.uptrend.xyaxis",
                            text: "Focus on weak domains to improve overall score"
                        )
                        KBTipRow(
                            icon: "slider.horizontal.3",
                            text: "Use progressive difficulty to build skills gradually"
                        )
                        KBTipRow(
                            icon: "person.3.fill",
                            text: "Practice with teammates for match simulation"
                        )
                        KBTipRow(
                            icon: "arrow.counterclockwise",
                            text: "Review missed questions to learn from mistakes"
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Knowledge Bowl Help")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Helper Views

/// Row component for help list items
struct KBHelpRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
    }
}

/// Simple tip row with icon and text
struct KBTipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

// MARK: - Getting Started Help View

struct KBGettingStartedHelpView: View {
    var body: some View {
        List {
            Section("Recommended Learning Path") {
                KBStepRow(step: 1, title: "Oral Practice", description: "Build confidence with voice-based answers")
                KBStepRow(step: 2, title: "Domain Drills", description: "Strengthen weak areas with focused practice")
                KBStepRow(step: 3, title: "Conference Training", description: "Master team communication under time pressure")
                KBStepRow(step: 4, title: "Match Simulation", description: "Full competition experience with AI opponents")
                KBStepRow(step: 5, title: "Written Practice", description: "Reinforce knowledge with MCQ format")
            }

            Section("Before You Start") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Select your region in Settings to ensure practice matches your competition's rules.")
                        .font(.subheadline)
                    Text("2. Start with lower difficulty settings and increase as you improve.")
                        .font(.subheadline)
                    Text("3. Practice consistently rather than in long occasional sessions.")
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Getting Started")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Step row with number badge
struct KBStepRow: View {
    let step: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(step)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step): \(title). \(description)")
    }
}

// MARK: - Training Modes Help View

struct KBTrainingModesHelpView: View {
    var body: some View {
        List {
            Section("Written Practice") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(KBHelpContent.TrainingModes.writtenOverview)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)

                KBModeDetailRow(icon: "checkmark.circle", text: "Multiple choice questions")
                KBModeDetailRow(icon: "timer", text: "Timed sessions matching competition")
                KBModeDetailRow(icon: "chart.bar", text: "Domain-weighted question selection")
            }

            Section("Oral Practice") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(KBHelpContent.TrainingModes.oralOverview)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)

                KBModeDetailRow(icon: "mic.fill", text: "Voice-based answers with transcription")
                KBModeDetailRow(icon: "clock", text: "Conference time before answering")
                KBModeDetailRow(icon: "checkmark.seal", text: "Flexible answer validation")
            }

            Section("Match Simulation") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(KBHelpContent.TrainingModes.matchOverview)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)

                KBModeDetailRow(icon: "person.3.fill", text: "Compete against AI opponent teams")
                KBModeDetailRow(icon: "arrow.uturn.backward", text: "Rebound opportunities on wrong answers")
                KBModeDetailRow(icon: "list.number", text: "Written + oral rounds like real matches")
            }

            Section("Conference Training") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(KBHelpContent.TrainingModes.conferenceOverview)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)

                KBModeDetailRow(icon: "hand.raised.fill", text: "Practice hand signal communication")
                KBModeDetailRow(icon: "gauge.with.needle", text: "Progressive difficulty reduces time")
                KBModeDetailRow(icon: "stopwatch", text: "Build quick decision-making skills")
            }

            Section("Rebound Training") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(KBHelpContent.TrainingModes.reboundOverview)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)

                KBModeDetailRow(icon: "arrow.uturn.forward", text: "Practice capitalizing on opponent mistakes")
                KBModeDetailRow(icon: "brain.head.profile", text: "Build risk assessment skills")
                KBModeDetailRow(icon: "bolt.fill", text: "Quick decision scenarios")
            }

            Section("Domain Drill") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(KBHelpContent.TrainingModes.domainDrillOverview)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)

                KBModeDetailRow(icon: "target", text: "Focus on specific knowledge areas")
                KBModeDetailRow(icon: "arrow.up.right", text: "Progressive difficulty available")
                KBModeDetailRow(icon: "clock.badge.checkmark", text: "Optional time pressure mode")
            }
        }
        .navigationTitle("Training Modes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Detail row for training mode features
struct KBModeDetailRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

// MARK: - Strategy Help View

struct KBStrategyHelpView: View {
    var body: some View {
        List {
            Section("Written Round Strategy") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(KBHelpContent.Strategy.writtenRoundStrategy)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }

            Section("Oral Round Strategy") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(KBHelpContent.Strategy.oralRoundStrategy)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }

            Section("Buzzing Tips") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(KBHelpContent.Strategy.buzzingStrategy)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }

            Section("Conference Tips") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(KBHelpContent.Strategy.conferenceStrategy)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }

            Section("Rebound Strategy") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(KBHelpContent.Strategy.reboundStrategyTips)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }

            Section("Team Communication") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(KBHelpContent.Strategy.teamCommunication)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }

            Section("Time Management") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(KBHelpContent.Strategy.timeManagement)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Competition Strategy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Regional Rules Help View

struct KBRegionalRulesHelpView: View {
    var body: some View {
        List {
            Section("Colorado") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(KBHelpContent.Regional.coloradoRules)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }

            Section("Minnesota") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(KBHelpContent.Regional.minnesotaRules)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }

            Section("Washington") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(KBHelpContent.Regional.washingtonRules)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }

            Section("Key Differences") {
                // Conferring Differences
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.orange)
                        Text("Conferring Rules")
                            .font(.headline)
                    }
                    Text(KBHelpContent.Regional.conferenceDifferences)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)

                // Scoring Differences
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "number.circle.fill")
                            .foregroundStyle(.green)
                        Text("Scoring")
                            .font(.headline)
                    }
                    Text(KBHelpContent.Regional.scoringDifferences)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }

            Section("Quick Comparison") {
                KBComparisonTable()
            }
        }
        .navigationTitle("Regional Rules")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Comparison table for regional rules
struct KBComparisonTable: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("Rule")
                    .font(.caption.bold())
                    .frame(width: 90, alignment: .leading)
                Text("CO")
                    .font(.caption.bold())
                    .frame(width: 50, alignment: .center)
                Text("MN")
                    .font(.caption.bold())
                    .frame(width: 50, alignment: .center)
                Text("WA")
                    .font(.caption.bold())
                    .frame(width: 50, alignment: .center)
            }
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))

            Divider()

            // Rows
            KBComparisonRow(label: "Written Qs", co: "60", mn: "60", wa: "50")
            KBComparisonRow(label: "Written Time", co: "15m", mn: "15m", wa: "45m")
            KBComparisonRow(label: "Conferring", co: "Signals", mn: "Verbal", wa: "Verbal")
            KBComparisonRow(label: "Conf. Time", co: "15s", mn: "30s", wa: "20s")
            KBComparisonRow(label: "Team Size", co: "4", mn: "4-6", wa: "3-5")
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Regional rules comparison table")
    }
}

struct KBComparisonRow: View {
    let label: String
    let co: String
    let mn: String
    let wa: String

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .frame(width: 90, alignment: .leading)
            Text(co)
                .frame(width: 50, alignment: .center)
            Text(mn)
                .frame(width: 50, alignment: .center)
            Text(wa)
                .frame(width: 50, alignment: .center)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("KB Help Sheet") {
    KBHelpSheet()
}

#Preview("Training Modes Help") {
    NavigationStack {
        KBTrainingModesHelpView()
    }
}

#Preview("Regional Rules Help") {
    NavigationStack {
        KBRegionalRulesHelpView()
    }
}
#endif
