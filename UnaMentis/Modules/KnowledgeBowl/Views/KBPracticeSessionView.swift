// UnaMentis - Knowledge Bowl Practice Session View
// Displays questions and handles user responses during practice
//
// Voice-first implementation: questions are automatically read aloud
// and voice recognition listens for verbal answers alongside text input.

import SwiftUI
import Logging

/// Main view for an active practice session
struct KBPracticeSessionView: View {
    let mode: KBStudyMode
    let questions: [KBQuestion]
    let onComplete: (KBSessionSummary) -> Void

    @StateObject private var engine = KBPracticeEngine()
    @StateObject private var voiceCoordinator = KBVoiceCoordinator()
    @State private var userAnswer = ""
    @State private var showingExitConfirmation = false
    @State private var lastSpokenQuestionId: String?
    @State private var voiceSetupComplete = false
    @FocusState private var isAnswerFocused: Bool

    @Environment(\.dismiss) private var dismiss

    private static let logger = Logger(label: "com.unamentis.kb.practice.view")

    var body: some View {
        VStack(spacing: 0) {
            // Progress header
            progressHeader

            Divider()

            // Main content based on state
            switch engine.sessionState {
            case .notStarted:
                startingView
            case .inProgress:
                questionView
            case .showingAnswer(let isCorrect):
                answerFeedbackView(isCorrect: isCorrect)
            case .completed:
                completedView
            }
        }
        .navigationTitle(mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(engine.sessionState != .completed)
        .toolbar {
            if engine.sessionState != .completed {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Exit") {
                        showingExitConfirmation = true
                    }
                }
            }
        }
        .confirmationDialog("Exit Practice?", isPresented: $showingExitConfirmation) {
            Button("Exit", role: .destructive) {
                // End session early and save progress before dismissing
                engine.endSessionEarly()
                let summary = engine.generateSummary()
                onComplete(summary)
                dismiss()
            }
            Button("Continue Practicing", role: .cancel) { }
        } message: {
            Text("Your progress will be saved, but the session will end.")
        }
        .onAppear {
            startSession()
            setupVoice()
        }
        .onDisappear {
            Task {
                await voiceCoordinator.shutdown()
            }
        }
        .onChange(of: engine.currentQuestion?.id) { _, newId in
            // Speak new question when it changes
            speakCurrentQuestion()
        }
        .onChange(of: engine.sessionState) { oldState, newState in
            handleStateChange(from: oldState, to: newState)
        }
        .onChange(of: voiceCoordinator.currentTranscript) { _, newTranscript in
            // Update text field with voice transcript in real-time
            if !newTranscript.isEmpty && engine.sessionState == .inProgress {
                userAnswer = newTranscript
            }
        }
    }

    // MARK: - Progress Header

    @ViewBuilder
    private var progressHeader: some View {
        HStack {
            // Question counter
            Text("\(engine.questionIndex + 1) of \(engine.totalQuestions)")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Spacer()

            // Voice status indicator
            if voiceCoordinator.isSpeaking {
                Label("Speaking", systemImage: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            } else if voiceCoordinator.isListening {
                Label("Listening", systemImage: "mic.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Spacer()

            // Score
            let correct = engine.results.filter { $0.isCorrect }.count
            Text("\(correct) correct")
                .font(.subheadline)
                .foregroundStyle(.green)

            // Timer for speed mode
            if mode == .speed && engine.timeRemaining > 0 {
                Spacer()
                Label(formatTime(engine.timeRemaining), systemImage: "clock")
                    .font(.subheadline.bold())
                    .foregroundStyle(engine.timeRemaining < 30 ? .red : .orange)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Starting View

    @ViewBuilder
    private var startingView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Preparing questions...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Question View

    @ViewBuilder
    private var questionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Domain badge
                if let question = engine.currentQuestion,
                   let domain = KBDomain.allCases.first(where: { $0.rawValue.lowercased().replacingOccurrences(of: " ", with: "-") == question.domainId || $0.rawValue.lowercased().replacingOccurrences(of: " & ", with: "-") == question.domainId || question.domainId == $0.rawValue.lowercased() }) {
                    DomainBadge(domain: domain, subcategory: question.subcategory)
                }

                // Question text
                if let question = engine.currentQuestion {
                    Text(question.questionText)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Difficulty indicator
                    DifficultyIndicator(level: question.difficulty)

                    // Speed target
                    if mode == .speed {
                        Text("Target: \(Int(question.speedTargetSeconds))s")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                // Answer input
                VStack(spacing: 12) {
                    TextField("Your answer...", text: $userAnswer)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .focused($isAnswerFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if !userAnswer.isEmpty {
                                submitAnswer()
                            }
                        }
                        .padding(.horizontal)

                    HStack(spacing: 16) {
                        Button("Skip") {
                            engine.skipQuestion()
                        }
                        .buttonStyle(.bordered)

                        Button("Submit") {
                            submitAnswer()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(userAnswer.isEmpty)
                    }
                }
                .padding(.top)
            }
            .padding(.vertical, 32)
        }
        .onAppear {
            isAnswerFocused = true
        }
    }

    // MARK: - Answer Feedback View

    @ViewBuilder
    private func answerFeedbackView(isCorrect: Bool) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Result icon
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(isCorrect ? .green : .red)

                Text(isCorrect ? "Correct!" : "Incorrect")
                    .font(.title.bold())
                    .foregroundStyle(isCorrect ? .green : .red)

                // Show correct answer if wrong
                if let question = engine.currentQuestion {
                    VStack(spacing: 8) {
                        Text("Correct Answer:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(question.answerText)
                            .font(.headline)
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Explanation
                    if !question.explanation.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Explanation")
                                .font(.subheadline.bold())

                            Text(question.explanation)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Response time
                    if let lastResult = engine.results.last {
                        HStack {
                            Label(String(format: "%.1fs", lastResult.responseTimeSeconds), systemImage: "clock")
                            if lastResult.wasWithinSpeedTarget {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                // Next button
                Button {
                    userAnswer = ""
                    engine.nextQuestion()
                } label: {
                    Text(engine.questionIndex + 1 >= engine.totalQuestions ? "See Results" : "Next Question")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(mode.color)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 32)
        }
    }

    // MARK: - Completed View

    @ViewBuilder
    private var completedView: some View {
        let summary = engine.generateSummary()

        ScrollView {
            VStack(spacing: 24) {
                // Celebration
                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)

                Text("Session Complete!")
                    .font(.title.bold())

                // Stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(
                        title: "Accuracy",
                        value: String(format: "%.0f%%", summary.accuracy * 100),
                        icon: "checkmark.circle",
                        color: summary.accuracy >= 0.7 ? .green : .orange
                    )

                    StatCard(
                        title: "Correct",
                        value: "\(summary.correctAnswers)/\(summary.totalQuestions)",
                        icon: "number",
                        color: .blue
                    )

                    StatCard(
                        title: "Avg Time",
                        value: String(format: "%.1fs", summary.averageResponseTime),
                        icon: "clock",
                        color: .purple
                    )

                    StatCard(
                        title: "Speed Target",
                        value: String(format: "%.0f%%", summary.speedTargetRate * 100),
                        icon: "bolt",
                        color: .orange
                    )
                }
                .padding(.horizontal)

                // Domain breakdown
                if !summary.domainBreakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Domain Performance")
                            .font(.headline)

                        ForEach(Array(summary.domainBreakdown.keys.sorted()), id: \.self) { domainId in
                            if let score = summary.domainBreakdown[domainId] {
                                HStack {
                                    Text(domainId.capitalized.replacingOccurrences(of: "-", with: " "))
                                        .font(.subheadline)

                                    Spacer()

                                    Text("\(score.correct)/\(score.total)")
                                        .font(.subheadline.bold())

                                    Text(String(format: "%.0f%%", score.accuracy * 100))
                                        .font(.caption)
                                        .foregroundStyle(score.accuracy >= 0.7 ? .green : .orange)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Done button
                Button {
                    onComplete(summary)
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(mode.color)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 32)
        }
    }

    // MARK: - Helpers

    private func startSession() {
        engine.startSession(questions: questions, mode: mode)
    }

    private func submitAnswer() {
        engine.submitAnswer(userAnswer)
        isAnswerFocused = false
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Voice Integration

    private func setupVoice() {
        Task {
            do {
                try await voiceCoordinator.setup()
                voiceSetupComplete = true

                // Set up callback for when voice transcript is finalized
                voiceCoordinator.onTranscriptComplete { transcript in
                    // Submit the voice answer
                    if engine.sessionState == .inProgress && !transcript.isEmpty {
                        userAnswer = transcript
                        submitAnswer()
                    }
                }

                Self.logger.info("Voice coordinator setup complete")
            } catch {
                Self.logger.error("Failed to setup voice: \(error)")
                // Continue without voice - text UI still works
            }
        }
    }

    private func speakCurrentQuestion() {
        guard let question = engine.currentQuestion,
              question.id != lastSpokenQuestionId,
              voiceSetupComplete else {
            return
        }

        lastSpokenQuestionId = question.id

        Task {
            // Stop listening while speaking
            await voiceCoordinator.stopListening()

            // Clear previous answer
            userAnswer = ""
            voiceCoordinator.resetTranscript()

            // Speak the question
            await voiceCoordinator.speakQuestion(question)

            // Start listening for the answer
            if engine.sessionState == .inProgress {
                do {
                    try await voiceCoordinator.startListening()
                } catch {
                    Self.logger.error("Failed to start listening: \(error)")
                }
            }
        }
    }

    private func handleStateChange(from oldState: KBPracticeEngine.SessionState, to newState: KBPracticeEngine.SessionState) {
        Task {
            switch newState {
            case .showingAnswer(let isCorrect):
                // Stop listening and speak feedback
                await voiceCoordinator.stopListening()

                if let question = engine.currentQuestion {
                    await voiceCoordinator.speakFeedback(
                        isCorrect: isCorrect,
                        correctAnswer: question.answerText,
                        explanation: question.explanation
                    )
                }

            case .completed:
                // Speak completion summary
                await voiceCoordinator.stopListening()

                let summary = engine.generateSummary()
                await voiceCoordinator.speakCompletion(
                    correctCount: summary.correctAnswers,
                    totalCount: summary.totalQuestions
                )

            case .inProgress:
                // The onChange for currentQuestion will handle speaking
                break

            case .notStarted:
                break
            }
        }
    }
}

// MARK: - Supporting Views

struct DomainBadge: View {
    let domain: KBDomain
    let subcategory: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: domain.iconName)
                .foregroundStyle(domain.color)

            Text(domain.rawValue)
                .font(.caption.bold())

            if !subcategory.isEmpty {
                Text("•")
                    .foregroundStyle(.secondary)
                Text(subcategory)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(domain.color.opacity(0.1))
        .clipShape(Capsule())
    }
}

struct DifficultyIndicator: View {
    let level: Int

    private var difficultyLabel: String {
        switch level {
        case 1: return "Very Easy"
        case 2: return "Easy"
        case 3: return "Medium"
        case 4: return "Hard"
        case 5: return "Very Hard"
        default: return "Difficulty \(level)"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= level ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Difficulty: \(difficultyLabel)")
        .accessibilityValue("\(level) of 5")
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        KBPracticeSessionView(
            mode: .diagnostic,
            questions: [
                KBQuestion(
                    id: "test-1",
                    domainId: "science",
                    subcategory: "Physics",
                    questionText: "What is the SI unit of electric current?",
                    answerText: "Ampere",
                    acceptableAnswers: ["Ampere", "Amp", "A"],
                    difficulty: 2,
                    speedTargetSeconds: 5.0,
                    questionType: "toss-up",
                    hints: ["Named after a French physicist"],
                    explanation: "The ampere (A) is the SI base unit of electric current."
                )
            ],
            onComplete: { _ in }
        )
    }
}
