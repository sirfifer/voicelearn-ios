// UnaMentis - Feedback View
// SwiftUI interface for beta tester feedback submission
//
// Follows iOS Style Guide: accessibility, localization, iPad support
// Part of Beta Testing infrastructure

import SwiftUI

/// Feedback submission view for beta testers
/// Multi-section form with category selection, rating, message, and privacy controls
public struct FeedbackView: View {
    @StateObject private var viewModel = FeedbackViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init() { }

    public var body: some View {
        NavigationStack {
            Form {
                categorySection
                ratingSection
                messageSection
                privacySection
                submitSection
            }
            .navigationTitle("feedback.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("feedback.cancel") {
                        dismiss()
                    }
                }
            }
            .alert("feedback.error.title", isPresented: $viewModel.showError) {
                Button("common.ok", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("feedback.success.title", isPresented: $viewModel.showSuccess) {
                Button("common.ok", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("feedback.success.message")
            }
            .disabled(viewModel.isSubmitting)
            .task {
                // Capture context when view appears
                viewModel.context = await captureContext()
            }
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        Section {
            Picker("feedback.category.label", selection: $viewModel.category) {
                ForEach(FeedbackCategory.allCases, id: \.self) { category in
                    Label(category.rawValue, systemImage: category.systemImage)
                        .tag(category)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel(String(localized: "feedback.category.label"))
            .accessibilityHint(String(localized: "feedback.accessibility.category.hint"))
        } header: {
            Text("feedback.category.header")
        } footer: {
            Text("feedback.category.footer")
        }
    }

    // MARK: - Rating Section

    private var ratingSection: some View {
        Section {
            HStack(spacing: 12) {
                Text("feedback.rating.header")
                    .foregroundStyle(.secondary)
                Spacer()
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: (viewModel.rating ?? 0) >= star ? "star.fill" : "star")
                        .foregroundStyle(.yellow)
                        .font(.title3)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.toggleRating(star)
                        }
                        .accessibilityLabel(String(format: String(localized: "feedback.rating.accessibility %lld"), star))
                        .accessibilityAddTraits(viewModel.rating == star ? [.isSelected] : [])
                }

                if viewModel.rating != nil {
                    Button {
                        viewModel.setRating(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(String(localized: "feedback.rating.clear"))
                }
            }
        } header: {
            Text("feedback.rating.header")
        } footer: {
            Text("feedback.rating.footer")
        }
    }

    // MARK: - Message Section

    private var messageSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.currentPrompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $viewModel.message)
                    .frame(minHeight: 150)
                    .accessibilityLabel(String(localized: "feedback.message.accessibility.label"))
                    .accessibilityHint(String(localized: "feedback.message.accessibility.hint"))

                HStack {
                    Text("feedback.message.count \(viewModel.message.count)")
                        .font(.caption)
                        .foregroundStyle(viewModel.message.count < 30 ? .orange : .secondary)

                    if let hint = viewModel.messageQualityHint {
                        Spacer()
                        Label(hint, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        } header: {
            Text("feedback.message.header")
        } footer: {
            Text("feedback.message.footer")
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label("feedback.privacy.notice.title", systemImage: "info.circle")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("feedback.privacy.notice.basic")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("feedback.privacy.diagnostics.toggle", isOn: $viewModel.includeDiagnostics)
                    .help(String(localized: "feedback.privacy.diagnostics.help"))

                if viewModel.includeDiagnostics {
                    Text("feedback.privacy.diagnostics.help")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 32)
                }
            }
        } header: {
            Text("feedback.privacy.header")
        } footer: {
            Text("feedback.privacy.footer")
        }
    }

    // MARK: - Submit Section

    private var submitSection: some View {
        Section {
            Button {
                Task {
                    await viewModel.submit()
                }
            } label: {
                HStack {
                    Spacer()
                    if viewModel.isSubmitting {
                        ProgressView()
                            .padding(.trailing, 8)
                    }
                    Text(viewModel.isSubmitting ? "feedback.submitting" : "feedback.submit")
                    Spacer()
                }
            }
            .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
            .accessibilityLabel(String(localized: "feedback.submit"))
            .accessibilityHint(String(localized: "feedback.accessibility.submit.hint"))
        }
    }

    // MARK: - Context Capture

    /// Capture current app context for debugging
    /// Auto-populated with screen, navigation, and session info
    @MainActor
    private func captureContext() async -> FeedbackContext {
        // For v1, simple context capture
        // Future: Hook into navigation system for full path
        return FeedbackContext(
            currentScreen: "FeedbackView",
            navigationPath: ["Settings", "Feedback"],
            sessionActive: false,
            sessionDuration: nil,
            sessionState: nil,
            turnCount: nil,
            topicId: nil
        )
    }
}

// MARK: - Preview

#Preview {
    FeedbackView()
}
