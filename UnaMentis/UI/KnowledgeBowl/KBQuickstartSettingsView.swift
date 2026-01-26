//
//  KBQuickstartSettingsView.swift
//  UnaMentis
//
//  Settings sheet for configuring Quickstart practice sessions.
//  Allows adjustment of question count, time limit, pack, and domain mix.
//

import SwiftUI

/// Settings view for Quickstart modes (Oral/Written).
struct KBQuickstartSettingsView: View {
    let roundType: KBRoundType
    @Binding var questionCount: Int
    @Binding var timePerQuestion: TimeInterval  // Only used for written
    @Binding var domainMix: KBDomainMix
    @Binding var selectedPackId: String?
    @Bindable var localPackStore: KBLocalPackStore

    @State private var showingDomainMix = false
    @State private var showingPackPicker = false
    @Environment(\.dismiss) private var dismiss

    // Internal double for slider binding
    @State private var questionCountDouble: Double = 10

    var body: some View {
        NavigationStack {
            Form {
                // Question count section
                questionCountSection

                // Time limit section (written only)
                if roundType == .written {
                    timeLimitSection
                }

                // Pack selection
                packSelectionSection

                // Domain mix
                domainMixSection
            }
            .navigationTitle(roundType == .oral ? "Oral Settings" : "Written Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                questionCountDouble = Double(questionCount)
            }
            .sheet(isPresented: $showingDomainMix) {
                KBDomainMixView(domainMix: $domainMix)
            }
            .sheet(isPresented: $showingPackPicker) {
                KBPackPickerView(
                    selectedPackId: $selectedPackId,
                    localPackStore: localPackStore
                )
            }
        }
    }

    // MARK: - Question Count Section

    private var questionCountSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Questions")
                        .font(.subheadline)
                    Spacer()
                    Text("\(questionCount)")
                        .font(.subheadline.monospacedDigit())
                        .fontWeight(.medium)
                        .foregroundColor(.kbMastered)
                }

                Slider(value: $questionCountDouble, in: 5...30, step: 5) { _ in
                    questionCount = Int(questionCountDouble)
                }
                .tint(.kbMastered)

                // Quick presets
                HStack(spacing: 8) {
                    ForEach([5, 10, 15, 20, 30], id: \.self) { count in
                        presetButton(count: count)
                    }
                }
            }
        } header: {
            Text("Session Length")
        } footer: {
            Text(roundType == .oral
                 ? "Oral practice uses voice-first question delivery"
                 : "Written practice uses multiple choice format")
        }
    }

    private func presetButton(count: Int) -> some View {
        Button {
            withAnimation {
                questionCount = count
                questionCountDouble = Double(count)
            }
        } label: {
            Text("\(count)")
                .font(.caption.weight(questionCount == count ? .bold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(questionCount == count ? Color.kbMastered : Color.kbBgSecondary)
                .foregroundColor(questionCount == count ? .white : .kbTextPrimary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Time Limit Section

    private var timeLimitSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Time per Question")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(timePerQuestion)) sec")
                        .font(.subheadline.monospacedDigit())
                        .fontWeight(.medium)
                        .foregroundColor(.kbIntermediate)
                }

                Slider(value: $timePerQuestion, in: 10...60, step: 5)
                    .tint(.kbIntermediate)

                HStack {
                    Text("Total time: \(formattedTotalTime)")
                        .font(.caption)
                        .foregroundColor(.kbTextSecondary)
                    Spacer()
                }
            }
        } header: {
            Text("Time Limit")
        }
    }

    private var formattedTotalTime: String {
        let totalSeconds = Int(timePerQuestion) * questionCount
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if seconds == 0 {
            return "\(minutes) min"
        }
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    // MARK: - Pack Selection Section

    private var packSelectionSection: some View {
        Section {
            Button {
                showingPackPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Question Pack")
                            .font(.subheadline)
                            .foregroundColor(.kbTextPrimary)

                        Text(selectedPackDisplayName)
                            .font(.caption)
                            .foregroundColor(.kbTextSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.kbTextSecondary)
                }
            }
        } header: {
            Text("Question Source")
        }
    }

    private var selectedPackDisplayName: String {
        if let packId = selectedPackId {
            // Check local packs first
            if let pack = localPackStore.localPacks.first(where: { $0.id == packId }) {
                return pack.name
            }
            // Fallback to ID
            return "Pack: \(packId)"
        }
        return "All Questions"
    }

    // MARK: - Domain Mix Section

    private var domainMixSection: some View {
        Section {
            Button {
                showingDomainMix = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Domain Mix")
                            .font(.subheadline)
                            .foregroundColor(.kbTextPrimary)

                        // Show top domains
                        HStack(spacing: 8) {
                            ForEach(domainMix.sortedByWeight.prefix(4), id: \.domain) { item in
                                HStack(spacing: 4) {
                                    Image(systemName: item.domain.icon)
                                        .font(.system(size: 10))
                                    Text("\(Int(item.weight * 100))%")
                                        .font(.caption2)
                                }
                                .foregroundColor(item.domain.color)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.kbMastered)
                }
            }
        } header: {
            Text("Subject Distribution")
        } footer: {
            Text("Adjust the mix of question domains using linked sliders")
        }
    }
}

// MARK: - Preview

#Preview("Oral Settings") {
    struct PreviewWrapper: View {
        @State private var questionCount = 5
        @State private var timePerQuestion: TimeInterval = 15
        @State private var domainMix = KBDomainMix.default
        @State private var selectedPackId: String?
        @State private var store = KBLocalPackStore()

        var body: some View {
            KBQuickstartSettingsView(
                roundType: .oral,
                questionCount: $questionCount,
                timePerQuestion: $timePerQuestion,
                domainMix: $domainMix,
                selectedPackId: $selectedPackId,
                localPackStore: store
            )
        }
    }

    return PreviewWrapper()
}

#Preview("Written Settings") {
    struct PreviewWrapper: View {
        @State private var questionCount = 10
        @State private var timePerQuestion: TimeInterval = 15
        @State private var domainMix = KBDomainMix.default
        @State private var selectedPackId: String?
        @State private var store = KBLocalPackStore()

        var body: some View {
            KBQuickstartSettingsView(
                roundType: .written,
                questionCount: $questionCount,
                timePerQuestion: $timePerQuestion,
                domainMix: $domainMix,
                selectedPackId: $selectedPackId,
                localPackStore: store
            )
        }
    }

    return PreviewWrapper()
}
