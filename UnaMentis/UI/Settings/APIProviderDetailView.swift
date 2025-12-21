// UnaMentis - API Provider Detail View
// Comprehensive information about each LM API provider
//
// Part of UI/UX (TDD Section 10)

import SwiftUI

/// Detailed view for a specific API provider showing pricing, usage, and configuration
public struct APIProviderDetailView: View {
    let keyType: APIKeyManager.KeyType
    let isConfigured: Bool
    let onSave: (APIKeyManager.KeyType, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var keyValue = ""
    @State private var showKey = false
    @State private var showingKeyEntry = false

    private var info: LMAPIProviderInfo {
        LMAPIProviderRegistry.info(for: keyType)
    }

    public init(
        keyType: APIKeyManager.KeyType,
        isConfigured: Bool,
        onSave: @escaping (APIKeyManager.KeyType, String) -> Void
    ) {
        self.keyType = keyType
        self.isConfigured = isConfigured
        self.onSave = onSave
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with categories
                headerSection

                // Status and API Key
                apiKeySection

                Divider()

                // What is this provider
                descriptionSection

                Divider()

                // How it's used in UnaMentis
                usageSection

                Divider()

                // Pricing breakdown
                pricingSection

                // Conversation cost estimates
                if let estimate = info.conversationEstimate {
                    Divider()
                    costEstimateSection(estimate)
                }

                // Available models
                if !info.models.isEmpty {
                    Divider()
                    modelsSection
                }

                // Tips and recommendations
                if !info.tips.isEmpty {
                    Divider()
                    tipsSection
                }

                // Links
                if info.websiteURL != nil || info.apiDocsURL != nil {
                    Divider()
                    linksSection
                }
            }
            .padding()
        }
        .navigationTitle(info.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .sheet(isPresented: $showingKeyEntry) {
            apiKeyEntrySheet
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category badges
            HStack(spacing: 8) {
                ForEach(info.categories, id: \.rawValue) { category in
                    CategoryBadge(category: category)
                }
            }

            Text(info.shortDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key Status")
                        .font(.headline)

                    HStack(spacing: 6) {
                        Image(systemName: isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(isConfigured ? .green : .orange)
                        Text(isConfigured ? "Configured" : "Not configured")
                            .foregroundStyle(isConfigured ? .green : .orange)
                    }
                    .font(.subheadline)
                }

                Spacer()

                Button {
                    showingKeyEntry = true
                } label: {
                    Text(isConfigured ? "Update Key" : "Add Key")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "What is \(info.name)?", icon: "info.circle")

            Text(info.fullDescription)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Usage Section

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "How UnaMentis Uses It", icon: "app.badge")

            Text(info.usageInApp)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Pricing Section

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Pricing", icon: "dollarsign.circle")

            VStack(alignment: .leading, spacing: 8) {
                Text(info.pricing.formattedCost)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                if let notes = info.pricing.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    // MARK: - Cost Estimate Section

    private func costEstimateSection(_ estimate: ConversationCostEstimate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Estimated Session Costs", icon: "clock")

            HStack(spacing: 16) {
                CostCard(
                    duration: "10 min",
                    cost: estimate.formattedTenMinute,
                    color: .blue
                )

                CostCard(
                    duration: "60 min",
                    cost: estimate.formattedSixtyMinute,
                    color: .purple
                )
            }

            Text(estimate.assumptions)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    // MARK: - Models Section

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Available Models", icon: "cpu")

            ForEach(info.models) { model in
                ModelRow(model: model)
            }
        }
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Tips", icon: "lightbulb")

            VStack(alignment: .leading, spacing: 8) {
                ForEach(info.tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .padding(.top, 2)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Links Section

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Resources", icon: "link")

            HStack(spacing: 16) {
                if let url = info.websiteURL {
                    Link(destination: url) {
                        Label("Website", systemImage: "globe")
                    }
                    .buttonStyle(.bordered)
                }

                if let url = info.apiDocsURL {
                    Link(destination: url) {
                        Label("API Docs", systemImage: "doc.text")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - API Key Entry Sheet

    private var apiKeyEntrySheet: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if showKey {
                            TextField("API Key", text: $keyValue)
                                .textContentType(.password)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("API Key", text: $keyValue)
                        }

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Enter \(info.name) API Key")
                } footer: {
                    Text("Your API key is stored securely in the iOS Keychain and never leaves your device except to authenticate with the service.")
                }

                if let url = info.apiDocsURL {
                    Section {
                        Link(destination: url) {
                            HStack {
                                Text("Get an API key from \(info.name)")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                        }
                    }
                }
            }
            .navigationTitle("API Key")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingKeyEntry = false
                        keyValue = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(keyType, keyValue)
                        showingKeyEntry = false
                        keyValue = ""
                    }
                    .disabled(keyValue.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Supporting Views

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
    }
}

struct CategoryBadge: View {
    let category: LMAPIProviderCategory

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.caption)
            Text(category.shortLabel)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(category.color.opacity(0.15))
        )
        .foregroundStyle(category.color)
    }
}

private struct CostCard: View {
    let duration: String
    let cost: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(duration)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(cost)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
            Text("session")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

private struct ModelRow: View {
    let model: LMAPIProviderInfo.ModelInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.name)
                    .font(.subheadline.weight(.medium))

                if model.isRecommended {
                    Text("Recommended")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.15))
                        )
                        .foregroundStyle(.green)
                }
            }

            Text(model.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let pricing = model.pricing {
                Text(pricing.formattedCost)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Combined Cost View

/// Shows estimated total session costs across all providers
public struct SessionCostOverviewView: View {
    public init() {}

    private let balanced10 = CombinedCostEstimator.balancedEstimate10Min
    private let balanced60 = CombinedCostEstimator.balancedEstimate60Min
    private let costOptimized10 = CombinedCostEstimator.costOptimizedEstimate10Min

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                introSection

                Divider()

                balancedEstimateSection

                Divider()

                costOptimizedSection

                Divider()

                breakdownSection
            }
            .padding()
        }
        .navigationTitle("Session Costs")
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Understanding Costs", systemImage: "info.circle")
                .font(.headline)

            Text("""
                UnaMentis uses multiple AI services during a tutoring session. \
                The total cost depends on which providers you configure and how \
                long your sessions are. Here are typical estimates.
                """)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var balancedEstimateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Balanced Configuration", systemImage: "scale.3d")
                .font(.headline)

            Text("Best quality experience using GPT-4o and Deepgram")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                CostSummaryCard(
                    estimate: balanced10,
                    color: .blue
                )
                CostSummaryCard(
                    estimate: balanced60,
                    color: .purple
                )
            }
        }
    }

    private var costOptimizedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Cost Optimized", systemImage: "leaf")
                .font(.headline)

            Text("Lower cost using GPT-4o-mini for most responses")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                CostSummaryCard(
                    estimate: costOptimized10,
                    color: .green
                )

                VStack(spacing: 4) {
                    Text("60 min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("~$0.24")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.green)
                    Text("estimated")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )
            }
        }
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Cost Breakdown", systemImage: "chart.pie")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                CostBreakdownRow(
                    category: .speechToText,
                    provider: "Deepgram Nova-3",
                    portion: "~10%",
                    note: "Only charges for actual speech"
                )
                CostBreakdownRow(
                    category: .languageModel,
                    provider: "GPT-4o / Claude",
                    portion: "~75%",
                    note: "Largest cost - input + output tokens"
                )
                CostBreakdownRow(
                    category: .textToSpeech,
                    provider: "Deepgram Aura",
                    portion: "~15%",
                    note: "Per character of AI speech"
                )
            }
        }
    }
}

private struct CostSummaryCard: View {
    let estimate: CombinedCostEstimator.SessionCostEstimate
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(estimate.duration) min")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(estimate.formattedTotal)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
            Text("total")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

private struct CostBreakdownRow: View {
    let category: LMAPIProviderCategory
    let provider: String
    let portion: String
    let note: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(category.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(category.shortLabel)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(portion)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("Provider Detail - OpenAI") {
    NavigationStack {
        APIProviderDetailView(
            keyType: .openAI,
            isConfigured: true,
            onSave: { _, _ in }
        )
    }
}

#Preview("Provider Detail - Deepgram") {
    NavigationStack {
        APIProviderDetailView(
            keyType: .deepgram,
            isConfigured: false,
            onSave: { _, _ in }
        )
    }
}

#Preview("Session Cost Overview") {
    NavigationStack {
        SessionCostOverviewView()
    }
}
