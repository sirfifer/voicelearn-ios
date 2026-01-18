// UnaMentis - Knowledge Bowl Practice Launcher View
// Setup screen before starting a practice session
//
// Shows mode information, loads questions, and lets
// the user start when ready.

import SwiftUI
import Logging

/// View shown before starting a practice session
struct KBPracticeLauncherView: View {
    let mode: KBStudyMode
    let questionService: KBQuestionService
    let onStart: ([KBQuestion]) -> Void
    let onCancel: () -> Void

    @State private var isLoading = true
    @State private var loadedQuestions: [KBQuestion] = []
    @State private var errorMessage: String?

    private static let logger = Logger(label: "com.unamentis.kb.launcher")

    var body: some View {
        VStack(spacing: 24) {
            // Mode header
            VStack(spacing: 16) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 50))
                    .foregroundStyle(mode.color)

                Text(mode.rawValue)
                    .font(.title.bold())

                Text(mode.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)

            Spacer()

            // Loading or ready state
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Preparing questions...")
                        .foregroundStyle(.secondary)
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)

                    Text(error)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Try Again") {
                        Task { await loadQuestions() }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // Ready to start
                VStack(spacing: 16) {
                    // Session info
                    VStack(spacing: 8) {
                        InfoRow(label: "Questions", value: "\(loadedQuestions.count)")

                        if mode == .speed {
                            InfoRow(label: "Time Limit", value: "5 minutes")
                        }

                        InfoRow(label: "Difficulty", value: difficultyDescription)
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Tips for this mode
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tips")
                            .font(.subheadline.bold())

                        ForEach(tipsForMode, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                                Text(tip)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    onStart(loadedQuestions)
                } label: {
                    Text("Start Practice")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(loadedQuestions.isEmpty ? Color.gray : mode.color)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(loadedQuestions.isEmpty || isLoading)

                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("Start \(mode.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                }
            }
        }
        .task {
            await loadQuestions()
        }
    }

    // MARK: - Loading

    private func loadQuestions() async {
        isLoading = true
        errorMessage = nil
        loadedQuestions = []  // Clear stale data before loading

        // Ensure questions are loaded in the service
        if !questionService.isLoaded {
            await questionService.loadQuestions()
        }

        // Get questions for this mode
        let questions = questionService.questions(forMode: mode)

        if questions.isEmpty {
            errorMessage = "No questions available for this mode. Please check your connection and try again."
        } else {
            loadedQuestions = questions
            Self.logger.info("Loaded \(questions.count) questions for \(mode.rawValue)")
        }

        isLoading = false
    }

    // MARK: - Helpers

    private var difficultyDescription: String {
        switch mode {
        case .diagnostic: return "All levels"
        case .targeted: return "Varies"
        case .breadth: return "Mixed"
        case .speed: return "Easy to Medium"
        case .competition: return "Competition level"
        case .team: return "Competition level"
        }
    }

    private var tipsForMode: [String] {
        switch mode {
        case .diagnostic:
            return [
                "Answer all questions to get an accurate assessment",
                "Don't spend too long on any single question",
                "This helps identify your strengths and weaknesses"
            ]
        case .targeted:
            return [
                "Questions focus on your weaker areas",
                "Take time to understand explanations",
                "Review incorrect answers carefully"
            ]
        case .breadth:
            return [
                "Questions cover all domains evenly",
                "Good for maintaining overall knowledge",
                "Helps prevent forgetting less-practiced areas"
            ]
        case .speed:
            return [
                "Answer as quickly as possible",
                "Each question has a target time",
                "Builds quick recall for competitions"
            ]
        case .competition:
            return [
                "Simulates real competition conditions",
                "Questions are timed like actual meets",
                "Good practice before competitions"
            ]
        case .team:
            return [
                "Designed for team practice",
                "Take turns answering",
                "Discuss strategies together"
            ]
        }
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    NavigationStack {
        KBPracticeLauncherView(
            mode: .diagnostic,
            questionService: KBQuestionService.shared,
            onStart: { _ in },
            onCancel: { }
        )
    }
}
