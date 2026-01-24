//
//  KBConferenceTrainingView.swift
//  UnaMentis
//
//  Conference training mode for Knowledge Bowl.
//  Trains team conferring efficiency within time limits.
//

import SwiftUI

// MARK: - Conference Training View

/// Main view for conference training mode
struct KBConferenceTrainingView: View {
    @State private var viewModel: KBConferenceTrainingViewModel
    @Environment(\.dismiss) private var dismiss

    init(region: KBRegion, questions: [KBQuestion]) {
        _viewModel = State(initialValue: KBConferenceTrainingViewModel(region: region, questions: questions))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .setup:
                    setupView
                case .training:
                    trainingView
                case .signalPractice:
                    signalPracticeView
                case .results:
                    resultsView
                }
            }
            .navigationTitle("Conference Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Setup View

    private var setupView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.kbExcellent)

                    Text("Conference Training")
                        .font(.title2.bold())

                    Text("Practice quick team decisions within the time limit")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                // Region Rules Card
                regionRulesCard

                // Training Options
                trainingOptionsCard

                // Start Button
                Button {
                    viewModel.startTraining()
                } label: {
                    Label("Start Training", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.kbExcellent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                // Hand Signal Practice Button
                if viewModel.config.handSignalsOnly {
                    Button {
                        viewModel.startSignalPractice()
                    } label: {
                        Label("Practice Hand Signals", systemImage: "hand.raised.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.kbStrong.opacity(0.2))
                            .foregroundStyle(Color.kbStrong)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
        }
    }

    private var regionRulesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.kbExcellent)
                Text("\(viewModel.config.region.displayName) Conference Rules")
                    .font(.headline)
            }

            Divider()

            LabeledContent("Time Limit") {
                Text("\(Int(viewModel.config.baseTimeLimit)) seconds")
            }

            LabeledContent("Communication") {
                Text(viewModel.config.handSignalsOnly ? "Hand signals only" : "Verbal allowed")
            }

            if viewModel.config.handSignalsOnly {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("No talking during conference!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var trainingOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Options")
                .font(.headline)

            Toggle("Progressive Difficulty", isOn: $viewModel.progressiveDifficulty)
                .tint(Color.kbExcellent)

            if viewModel.progressiveDifficulty {
                Text("Time limits: 15s \u{2192} 12s \u{2192} 10s \u{2192} 8s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Stepper("Questions: \(viewModel.questionCount)", value: $viewModel.questionCount, in: 5...30, step: 5)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Training View

    private var trainingView: some View {
        VStack(spacing: 20) {
            // Progress and Level
            HStack {
                Text("Level \(viewModel.currentLevel + 1)")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(levelColor.opacity(0.2))
                    .foregroundStyle(levelColor)
                    .clipShape(Capsule())

                Spacer()

                Text("\(viewModel.currentQuestionIndex + 1)/\(viewModel.totalQuestions)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Timer
            conferenceTimer

            // Question Card
            if let question = viewModel.currentQuestion {
                questionCard(question)
            }

            Spacer()

            // Answer Buttons
            answerButtons

            // Skip Button
            Button {
                viewModel.skipQuestion()
            } label: {
                Text("Skip Question")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom)
        }
        .padding()
    }

    private var conferenceTimer: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)

                // Progress circle
                Circle()
                    .trim(from: 0, to: viewModel.timerProgress)
                    .stroke(timerColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: viewModel.timerProgress)

                // Time display
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", viewModel.remainingTime))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text("seconds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)

            // Time limit indicator
            Text("Time Limit: \(Int(viewModel.currentTimeLimit))s")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var timerColor: Color {
        if viewModel.remainingTime <= 3 {
            return .red
        } else if viewModel.remainingTime <= 5 {
            return .orange
        } else {
            return Color.kbExcellent
        }
    }

    private var levelColor: Color {
        switch viewModel.currentLevel {
        case 0: return .green
        case 1: return .blue
        case 2: return .orange
        case 3: return .red
        default: return Color.kbExcellent
        }
    }

    private func questionCard(_ question: KBQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(question.domain.displayName)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(question.domain.color.opacity(0.2))
                    .foregroundStyle(question.domain.color)
                    .clipShape(Capsule())

                Spacer()

                Text(question.difficulty.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(question.text)
                .font(.body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.config.handSignalsOnly {
                HStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(.orange)
                    Text("Use hand signals to confer")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var answerButtons: some View {
        VStack(spacing: 12) {
            // Ready to Answer
            Button {
                viewModel.submitAnswer(wasCorrect: true)
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Team Agreed - Answer")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 12) {
                // Pass
                Button {
                    viewModel.submitAnswer(wasCorrect: false)
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Pass")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Need More Time (if allowed)
                Button {
                    viewModel.requestMoreTime()
                } label: {
                    HStack {
                        Image(systemName: "clock.fill")
                        Text("More Time")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!viewModel.canRequestMoreTime)
                .opacity(viewModel.canRequestMoreTime ? 1 : 0.5)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Signal Practice View

    private var signalPracticeView: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.kbStrong)

                Text("Hand Signal Practice")
                    .font(.title2.bold())

                Text("Learn the standard KB hand signals")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top)

            if let prompt = viewModel.currentSignalPrompt {
                // Scenario
                VStack(spacing: 16) {
                    Text("Scenario:")
                        .font(.headline)

                    Text(prompt.scenario)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("What signal would you use?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()

                // Signal Options Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(KBHandSignal.allCases, id: \.self) { signal in
                        signalButton(signal)
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            // Back to Training
            Button {
                viewModel.endSignalPractice()
            } label: {
                Text("Back to Training")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom)
        }
    }

    private func signalButton(_ signal: KBHandSignal) -> some View {
        Button {
            viewModel.selectSignal(signal)
        } label: {
            VStack(spacing: 8) {
                Text(signal.emoji)
                    .font(.system(size: 32))

                Text(signal.displayName)
                    .font(.caption.bold())

                Text(signal.gestureDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(signalButtonBackground(signal))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func signalButtonBackground(_ signal: KBHandSignal) -> Color {
        if let result = viewModel.lastSignalResult {
            if signal == viewModel.currentSignalPrompt?.signal {
                return .green.opacity(0.3)
            } else if signal == viewModel.selectedSignal && !result {
                return .red.opacity(0.3)
            }
        }
        return Color(.secondarySystemBackground)
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                resultHeader

                // Stats Cards
                statsCards

                // Recommendation
                if let result = viewModel.trainingResult {
                    recommendationCard(result.recommendation)
                }

                // Actions
                VStack(spacing: 12) {
                    Button {
                        viewModel.restartTraining()
                    } label: {
                        Label("Train Again", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.kbExcellent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }

    private var resultHeader: some View {
        VStack(spacing: 12) {
            let stats = viewModel.trainingResult?.stats

            Image(systemName: resultIcon(for: stats?.accuracy ?? 0))
                .font(.system(size: 60))
                .foregroundStyle(resultColor(for: stats?.accuracy ?? 0))

            Text(resultTitle(for: stats?.accuracy ?? 0))
                .font(.title.bold())

            if let stats = stats {
                Text("\(stats.correctCount)/\(stats.totalAttempts) correct")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func resultIcon(for accuracy: Double) -> String {
        if accuracy >= 0.8 { return "star.fill" }
        if accuracy >= 0.6 { return "hand.thumbsup.fill" }
        return "arrow.up.circle.fill"
    }

    private func resultColor(for accuracy: Double) -> Color {
        if accuracy >= 0.8 { return .yellow }
        if accuracy >= 0.6 { return .green }
        return .blue
    }

    private func resultTitle(for accuracy: Double) -> String {
        if accuracy >= 0.8 { return "Excellent!" }
        if accuracy >= 0.6 { return "Good Progress!" }
        return "Keep Practicing!"
    }

    private var statsCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let stats = viewModel.trainingResult?.stats {
                statCard("Accuracy", value: "\(Int(stats.accuracy * 100))%", icon: "target")
                statCard("Avg Time", value: String(format: "%.1fs", stats.averageConferenceTime), icon: "clock")
                statCard("Fastest", value: String(format: "%.1fs", stats.fastestTime), icon: "bolt.fill")
                statCard("Timeouts", value: "\(stats.timeoutsCount)", icon: "exclamationmark.triangle")
                statCard("Final Level", value: "\(stats.currentDifficultyLevel + 1)", icon: "chart.line.uptrend.xyaxis")
                statCard("Efficiency", value: "\(Int(stats.averageEfficiency * 100))%", icon: "gauge.high")
            }
        }
        .padding(.horizontal)
    }

    private func statCard(_ title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.kbExcellent)

            Text(value)
                .font(.title2.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func recommendationCard(_ recommendation: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.title2)
                .foregroundStyle(.yellow)

            Text(recommendation)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - View Model

@MainActor
@Observable
final class KBConferenceTrainingViewModel {

    // MARK: - State

    enum TrainingState {
        case setup
        case training
        case signalPractice
        case results
    }

    private(set) var state: TrainingState = .setup
    private(set) var config: KBConferenceConfig
    private var manager: KBConferenceManager
    private var questions: [KBQuestion]

    // Setup options
    var progressiveDifficulty: Bool = true
    var questionCount: Int = 15

    // Training state
    private(set) var currentQuestionIndex: Int = 0
    private(set) var currentLevel: Int = 0
    private(set) var remainingTime: TimeInterval = 15
    private(set) var currentTimeLimit: TimeInterval = 15
    private(set) var canRequestMoreTime: Bool = true

    // Signal practice state
    private(set) var currentSignalPrompt: (signal: KBHandSignal, scenario: String)?
    private(set) var selectedSignal: KBHandSignal?
    private(set) var lastSignalResult: Bool?

    // Results
    private(set) var trainingResult: KBConferenceTrainingResult?

    // Timer
    private var timer: Timer?

    // MARK: - Computed Properties

    var currentQuestion: KBQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var totalQuestions: Int {
        min(questionCount, questions.count)
    }

    var timerProgress: Double {
        guard currentTimeLimit > 0 else { return 0 }
        return remainingTime / currentTimeLimit
    }

    // MARK: - Initialization

    init(region: KBRegion, questions: [KBQuestion]) {
        let regionConfig = KBConferenceConfig.forRegion(region)
        self.config = regionConfig
        self.manager = KBConferenceManager(config: regionConfig)
        self.questions = questions.shuffled()
        self.currentTimeLimit = regionConfig.baseTimeLimit
        self.remainingTime = regionConfig.baseTimeLimit
    }

    // MARK: - Training Control

    func startTraining() {
        // Update config with user preferences
        config = KBConferenceConfig(
            region: config.region,
            baseTimeLimit: config.baseTimeLimit,
            progressiveDifficulty: progressiveDifficulty,
            handSignalsOnly: config.handSignalsOnly,
            questionCount: questionCount
        )

        manager = KBConferenceManager(config: config)

        Task {
            await manager.startSession()
        }

        currentQuestionIndex = 0
        currentLevel = 0
        currentTimeLimit = config.timeLimit(forLevel: 0)
        remainingTime = currentTimeLimit
        canRequestMoreTime = true
        state = .training
        startTimer()
    }

    func submitAnswer(wasCorrect: Bool) {
        stopTimer()

        guard let question = currentQuestion else { return }

        let conferenceTime = currentTimeLimit - remainingTime

        Task {
            await manager.recordAttempt(
                questionId: question.id,
                domain: question.domain,
                conferenceTime: conferenceTime,
                wasCorrect: wasCorrect
            )

            currentLevel = await manager.getCurrentDifficultyLevel()
        }

        advanceToNextQuestion()
    }

    func skipQuestion() {
        stopTimer()
        advanceToNextQuestion()
    }

    func requestMoreTime() {
        // One-time extension (not realistic but helps learning)
        canRequestMoreTime = false
        remainingTime += 5
    }

    private func advanceToNextQuestion() {
        currentQuestionIndex += 1

        if currentQuestionIndex >= totalQuestions {
            endTraining()
        } else {
            currentTimeLimit = config.timeLimit(forLevel: currentLevel)
            remainingTime = currentTimeLimit
            canRequestMoreTime = true
            startTimer()
        }
    }

    private func endTraining() {
        stopTimer()

        Task {
            let stats = await manager.endSession()

            trainingResult = KBConferenceTrainingResult(
                sessionId: UUID(),
                region: config.region,
                startTime: Date().addingTimeInterval(-Double(totalQuestions) * 20),
                endTime: Date(),
                stats: stats,
                finalDifficultyLevel: stats.currentDifficultyLevel,
                recommendation: KBConferenceTrainingResult.generateRecommendation(from: stats)
            )

            state = .results
        }
    }

    func restartTraining() {
        trainingResult = nil
        state = .setup
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.timerTick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func timerTick() {
        remainingTime = max(0, remainingTime - 0.1)

        if remainingTime <= 0 {
            // Time expired
            submitAnswer(wasCorrect: false)
        }
    }

    // MARK: - Signal Practice

    func startSignalPractice() {
        currentSignalPrompt = KBConferenceManager.randomSignalPrompt()
        selectedSignal = nil
        lastSignalResult = nil
        state = .signalPractice
    }

    func selectSignal(_ signal: KBHandSignal) {
        selectedSignal = signal
        lastSignalResult = KBConferenceManager.validateSignal(
            expected: currentSignalPrompt?.signal ?? .confident,
            given: signal
        )

        // After a delay, show next prompt
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if state == .signalPractice {
                currentSignalPrompt = KBConferenceManager.randomSignalPrompt()
                selectedSignal = nil
                lastSignalResult = nil
            }
        }
    }

    func endSignalPractice() {
        state = .setup
    }
}

// MARK: - Preview

#Preview {
    KBConferenceTrainingView(
        region: .colorado,
        questions: [
            KBQuestion(
                id: UUID(),
                text: "What is the capital of France?",
                answer: KBAnswer(primary: "Paris", acceptable: nil, answerType: .place),
                domain: .socialStudies,
                difficulty: .foundational,
                gradeLevel: .highSchool,
                suitability: KBSuitability()
            )
        ]
    )
}
