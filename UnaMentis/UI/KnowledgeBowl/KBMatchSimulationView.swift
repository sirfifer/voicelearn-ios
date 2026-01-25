//
//  KBMatchSimulationView.swift
//  UnaMentis
//
//  Match simulation view for Knowledge Bowl.
//  Full match experience with simulated opponents.
//

import SwiftUI

// MARK: - Match Simulation View

/// Main view for match simulation
struct KBMatchSimulationView: View {
    @State private var viewModel: KBMatchSimulationViewModel
    @Environment(\.dismiss) private var dismiss

    init(region: KBRegion, questions: [KBQuestion]) {
        _viewModel = State(initialValue: KBMatchSimulationViewModel(region: region, questions: questions))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .setup:
                    setupView
                case .writtenRound:
                    writtenRoundView
                case .writtenReview:
                    writtenReviewView
                case .oralRound:
                    oralRoundView
                case .oralReview:
                    oralReviewView
                case .results:
                    resultsView
                }
            }
            .navigationTitle("Match Simulation")
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
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.yellow)

                    Text("Match Simulation")
                        .font(.title2.bold())

                    Text("Experience a full Knowledge Bowl match")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                // Match Format Selection
                formatSelectionCard

                // Opponent Settings
                opponentSettingsCard

                // Team Name
                teamNameCard

                // Start Button
                Button {
                    viewModel.startMatch()
                } label: {
                    Label("Start Match", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.kbExcellent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }

    private var formatSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Match Format")
                    .font(.headline)
                InfoButton(
                    title: "Match Format",
                    content: KBHelpContent.TrainingModes.matchFormat
                )
            }

            ForEach(KBMatchConfig.MatchFormat.allCases, id: \.self) { format in
                Button {
                    viewModel.selectedFormat = format
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(format.displayName)
                                .font(.subheadline.bold())

                            Text("\(format.writtenQuestions) written + \(format.oralRounds) oral rounds")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if viewModel.selectedFormat == format {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.kbExcellent)
                        }
                    }
                    .padding()
                    .background(viewModel.selectedFormat == format
                        ? Color.kbExcellent.opacity(0.1)
                        : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var opponentSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Opponent Difficulty")
                    .font(.headline)
                InfoButton(
                    title: "Opponent Difficulty",
                    content: KBHelpContent.TrainingModes.matchOpponents
                )
            }

            ForEach(Array(viewModel.opponentStrengths.enumerated()), id: \.offset) { index, strength in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Team \(index + 2)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Strength", selection: $viewModel.opponentStrengths[index]) {
                        ForEach(KBMatchConfig.OpponentStrength.allCases, id: \.self) { str in
                            Text(str.displayName).tag(str)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var teamNameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Team")
                .font(.headline)

            TextField("Team Name", text: $viewModel.teamName)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Written Round View

    private var writtenRoundView: some View {
        VStack(spacing: 20) {
            // Progress
            writtenProgressHeader

            // Timer (if applicable)
            if viewModel.writtenTimeRemaining > 0 {
                writtenTimer
            }

            // Question
            if let question = viewModel.currentQuestion {
                writtenQuestionCard(question)
            }

            Spacer()

            // Answer buttons
            writtenAnswerButtons
        }
        .padding()
    }

    private var writtenProgressHeader: some View {
        HStack {
            Text("Written Round")
                .font(.headline)
                .foregroundStyle(Color.kbStrong)

            Spacer()

            Text("Q\(viewModel.writtenProgress.current + 1)/\(viewModel.writtenProgress.total)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var writtenTimer: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundStyle(viewModel.writtenTimeRemaining < 30 ? .red : .secondary)

            Text(timeString(viewModel.writtenTimeRemaining))
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(viewModel.writtenTimeRemaining < 30 ? .red : .primary)
        }
    }

    private func writtenQuestionCard(_ question: KBQuestion) -> some View {
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
            }

            Text(question.text)
                .font(.body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var writtenAnswerButtons: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.submitWrittenAnswer(isCorrect: true)
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("I Got It Right")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                viewModel.submitWrittenAnswer(isCorrect: false)
            } label: {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("I Got It Wrong")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.red)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Show answer hint
            if let question = viewModel.currentQuestion {
                Text("Answer: \(question.answer.primary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Written Review View

    private var writtenReviewView: some View {
        VStack(spacing: 24) {
            // Scores
            Text("Written Round Complete!")
                .font(.title2.bold())

            standingsCard

            Button {
                viewModel.startOralRounds()
            } label: {
                Label("Continue to Oral Rounds", systemImage: "arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.kbExcellent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Oral Round View

    private var oralRoundView: some View {
        VStack(spacing: 20) {
            // Progress
            oralProgressHeader

            // Current state
            switch viewModel.oralState {
            case .readingQuestion:
                oralReadingView
            case .buzzing:
                oralBuzzingView
            case .answering:
                oralAnsweringView
            case .feedback:
                oralFeedbackView
            }
        }
        .padding()
    }

    private var oralProgressHeader: some View {
        HStack {
            Text("Oral Round \(viewModel.oralProgress.round)")
                .font(.headline)
                .foregroundStyle(Color.kbExcellent)

            Spacer()

            Text("Q\(viewModel.oralProgress.question + 1)/\(viewModel.oralProgress.questionsPerRound)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var oralReadingView: some View {
        VStack(spacing: 16) {
            Spacer()

            if let question = viewModel.currentQuestion {
                writtenQuestionCard(question)
            }

            Text("Question being read...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView()
                .scaleEffect(1.5)

            Spacer()
        }
        .onAppear {
            viewModel.simulateBuzz()
        }
    }

    private var oralBuzzingView: some View {
        VStack(spacing: 24) {
            Spacer()

            if let question = viewModel.currentQuestion {
                writtenQuestionCard(question)
            }

            // Buzz button with help
            VStack(spacing: 8) {
                Button {
                    viewModel.playerBuzz()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 60))
                        Text("BUZZ!")
                            .font(.title.bold())
                    }
                    .frame(width: 150, height: 150)
                    .background(Color.kbExcellent)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
                }
                .disabled(!viewModel.canBuzz)
                .opacity(viewModel.canBuzz ? 1 : 0.5)

                InfoButton(
                    title: "Buzzing Strategy",
                    content: KBHelpContent.TrainingModes.matchBuzzing
                )
            }

            if viewModel.buzzWinner != nil && !viewModel.playerBuzzedFirst {
                Text("\(viewModel.buzzWinnerName) buzzed first!")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }

            Spacer()
        }
    }

    private var oralAnsweringView: some View {
        VStack(spacing: 24) {
            if let question = viewModel.currentQuestion {
                writtenQuestionCard(question)
            }

            if viewModel.playerBuzzedFirst {
                Text("Your turn to answer!")
                    .font(.headline)
                    .foregroundStyle(Color.kbExcellent)

                writtenAnswerButtons
            } else {
                Text("\(viewModel.buzzWinnerName) is answering...")
                    .font(.headline)
                    .foregroundStyle(.orange)

                ProgressView()
            }
        }
        .onAppear {
            if !viewModel.playerBuzzedFirst {
                viewModel.simulateOpponentAnswer()
            }
        }
    }

    private var oralFeedbackView: some View {
        VStack(spacing: 16) {
            if let feedback = viewModel.oralFeedback {
                Image(systemName: feedback.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(feedback.color)

                Text(feedback.title)
                    .font(.title3.bold())

                Text(feedback.message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                if feedback.points != 0 {
                    Text("\(feedback.points > 0 ? "+" : "")\(feedback.points) points")
                        .font(.headline)
                        .foregroundStyle(feedback.points > 0 ? .green : .red)
                }
            }

            Button {
                viewModel.nextOralQuestion()
            } label: {
                Text("Next Question")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.kbExcellent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Oral Review View

    private var oralReviewView: some View {
        VStack(spacing: 24) {
            Text("Round \(viewModel.oralProgress.round) Complete!")
                .font(.title2.bold())

            standingsCard

            Button {
                viewModel.continueMatch()
            } label: {
                Label(
                    viewModel.isLastOralRound ? "See Final Results" : "Next Round",
                    systemImage: "arrow.right"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.kbExcellent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Winner announcement
                if let summary = viewModel.matchSummary {
                    resultHeader(rank: summary.playerRank)
                }

                // Final standings
                standingsCard

                // Player stats
                if let summary = viewModel.matchSummary {
                    playerStatsCard(summary.playerStats)
                }

                // Actions
                VStack(spacing: 12) {
                    Button {
                        viewModel.restartMatch()
                    } label: {
                        Label("New Match", systemImage: "arrow.counterclockwise")
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

    private func resultHeader(rank: Int) -> some View {
        VStack(spacing: 12) {
            Image(systemName: rank == 1 ? "trophy.fill" : "medal.fill")
                .font(.system(size: 60))
                .foregroundStyle(rank == 1 ? .yellow : (rank == 2 ? .gray : .brown))

            Text(rank == 1 ? "Victory!" : (rank == 2 ? "2nd Place" : "3rd Place"))
                .font(.title.bold())

            Text("Match Complete")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var standingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Standings")
                .font(.headline)

            ForEach(Array(viewModel.teams.sorted { $0.totalScore > $1.totalScore }.enumerated()),
                    id: \.element.id) { index, team in
                HStack {
                    Text("\(index + 1).")
                        .font(.subheadline.bold())
                        .frame(width: 24)

                    Text(team.name)
                        .font(.subheadline)
                        .foregroundStyle(team.isPlayer ? Color.kbExcellent : .primary)

                    if team.isPlayer {
                        Text("(You)")
                            .font(.caption)
                            .foregroundStyle(Color.kbExcellent)
                    }

                    Spacer()

                    Text("\(team.totalScore)")
                        .font(.subheadline.bold())
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func playerStatsCard(_ stats: KBMatchSummary.PlayerMatchStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Performance")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statItem("Oral", value: "\(stats.oralCorrect)/\(stats.oralTotal)")
                statItem("Written", value: "\(stats.writtenCorrect)/\(stats.writtenTotal)")
                statItem("Accuracy", value: "\(Int(stats.overallAccuracy * 100))%")
                statItem("Avg Time", value: String(format: "%.1fs", stats.averageResponseTime))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func statItem(_ title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func timeString(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Oral Feedback

struct OralFeedback {
    let title: String
    let message: String
    let icon: String
    let color: Color
    let points: Int
}

// MARK: - View Model

@MainActor
@Observable
final class KBMatchSimulationViewModel {
    // MARK: - State

    enum ViewState {
        case setup
        case writtenRound
        case writtenReview
        case oralRound
        case oralReview
        case results
    }

    enum OralState {
        case readingQuestion
        case buzzing
        case answering
        case feedback
    }

    private(set) var state: ViewState = .setup
    private(set) var oralState: OralState = .readingQuestion
    private var engine: KBMatchEngine
    private var questions: [KBQuestion]
    private let region: KBRegion

    // Setup options
    var selectedFormat: KBMatchConfig.MatchFormat = .quickMatch
    var opponentStrengths: [KBMatchConfig.OpponentStrength] = [.intermediate, .intermediate]
    var teamName: String = "My Team"

    // Written state
    private(set) var currentQuestion: KBQuestion?
    private(set) var writtenTimeRemaining: TimeInterval = 0
    private(set) var writtenProgress: (current: Int, total: Int) = (0, 0)
    private var writtenTimer: Timer?
    private var questionStartTime: Date?

    // Oral state
    private(set) var oralProgress: (round: Int, totalRounds: Int, question: Int, questionsPerRound: Int) = (0, 0, 0, 0)
    private(set) var buzzWinner: UUID?
    private(set) var buzzWinnerName: String = ""
    private(set) var playerBuzzedFirst: Bool = false
    private(set) var canBuzz: Bool = false
    private(set) var oralFeedback: OralFeedback?
    private(set) var isLastOralRound: Bool = false

    // Match state
    private(set) var teams: [KBTeam] = []
    private(set) var matchSummary: KBMatchSummary?

    // MARK: - Initialization

    init(region: KBRegion, questions: [KBQuestion]) {
        self.region = region
        self.questions = questions
        let config = KBMatchConfig.forRegion(region)
        self.engine = KBMatchEngine(config: config)
    }

    // MARK: - Match Control

    func startMatch() {
        let config = KBMatchConfig(
            region: region,
            matchFormat: selectedFormat,
            opponentStrengths: opponentStrengths,
            enablePracticeMode: true
        )
        engine = KBMatchEngine(config: config)

        Task {
            await engine.setupMatch(questions: questions, playerTeamName: teamName)
            await engine.startMatch()
            teams = await engine.getTeams()
            currentQuestion = await engine.getCurrentWrittenQuestion()
            writtenProgress = await engine.getWrittenProgress()
            questionStartTime = Date()
            state = .writtenRound
        }
    }

    func submitWrittenAnswer(isCorrect: Bool) {
        let responseTime = questionStartTime.map { Date().timeIntervalSince($0) } ?? 0

        Task {
            await engine.submitWrittenAnswer(isCorrect: isCorrect, responseTime: responseTime)
            teams = await engine.getTeams()

            let phase = await engine.getCurrentPhase()
            if case .writtenReview = phase {
                state = .writtenReview
            } else {
                currentQuestion = await engine.getCurrentWrittenQuestion()
                writtenProgress = await engine.getWrittenProgress()
                questionStartTime = Date()
            }
        }
    }

    func startOralRounds() {
        Task {
            await engine.startOralRounds()
            currentQuestion = await engine.getCurrentOralQuestion()
            oralProgress = await engine.getOralProgress()
            oralState = .readingQuestion
            state = .oralRound
        }
    }

    func simulateBuzz() {
        Task {
            // Simulate reading time
            try? await Task.sleep(for: .seconds(2))

            canBuzz = true
            oralState = .buzzing

            // Give player time to buzz
            try? await Task.sleep(for: .seconds(3))

            // If player hasn't buzzed, simulate opponent buzz
            if canBuzz {
                if let buzz = await engine.simulateBuzz() {
                    buzzWinner = buzz.teamId
                    buzzWinnerName = teams.first { $0.id == buzz.teamId }?.name ?? "Unknown"
                    playerBuzzedFirst = teams.first { $0.id == buzz.teamId }?.isPlayer ?? false
                    canBuzz = false
                    oralState = .answering
                }
            }
        }
    }

    func playerBuzz() {
        guard canBuzz else { return }
        canBuzz = false

        if let playerTeam = teams.first(where: { $0.isPlayer }) {
            buzzWinner = playerTeam.id
            buzzWinnerName = playerTeam.name
            playerBuzzedFirst = true
            questionStartTime = Date()
            oralState = .answering
        }
    }

    func submitOralAnswer(isCorrect: Bool) {
        let responseTime = questionStartTime.map { Date().timeIntervalSince($0) } ?? 0

        Task {
            await engine.recordOralResult(
                answeringTeamId: buzzWinner,
                wasCorrect: isCorrect,
                responseTime: responseTime
            )
            teams = await engine.getTeams()

            let points = isCorrect ? region.oralPointValue : region.incorrectOralPenalty

            oralFeedback = OralFeedback(
                title: isCorrect ? "Correct!" : "Incorrect",
                message: isCorrect
                    ? "Great answer!"
                    : "The answer was: \(currentQuestion?.answer.primary ?? "")",
                icon: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill",
                color: isCorrect ? .green : .red,
                points: points
            )

            oralState = .feedback
        }
    }

    func simulateOpponentAnswer() {
        Task {
            try? await Task.sleep(for: .seconds(2))

            // Simulate opponent accuracy
            let isCorrect = Double.random(in: 0...1) < 0.6

            await engine.recordOralResult(
                answeringTeamId: buzzWinner,
                wasCorrect: isCorrect,
                responseTime: 2.0
            )
            teams = await engine.getTeams()

            let points = isCorrect ? region.oralPointValue : region.incorrectOralPenalty

            oralFeedback = OralFeedback(
                title: isCorrect ? "\(buzzWinnerName) Correct!" : "\(buzzWinnerName) Wrong!",
                message: isCorrect
                    ? "They got it right."
                    : "The answer was: \(currentQuestion?.answer.primary ?? "")",
                icon: isCorrect ? "person.fill.checkmark" : "person.fill.xmark",
                color: isCorrect ? .orange : .blue,
                points: 0
            )

            oralState = .feedback
        }
    }

    func nextOralQuestion() {
        Task {
            let phase = await engine.getCurrentPhase()

            if case .oralReview(let roundNumber) = phase {
                oralProgress = await engine.getOralProgress()
                isLastOralRound = oralProgress.round >= oralProgress.totalRounds
                state = .oralReview
            } else {
                currentQuestion = await engine.getCurrentOralQuestion()
                oralProgress = await engine.getOralProgress()
                buzzWinner = nil
                buzzWinnerName = ""
                playerBuzzedFirst = false
                oralFeedback = nil
                oralState = .readingQuestion
            }
        }
    }

    func continueMatch() {
        Task {
            await engine.startNextOralRound()
            let phase = await engine.getCurrentPhase()

            if case .finalResults = phase {
                matchSummary = await engine.getMatchSummary()
                state = .results
            } else {
                currentQuestion = await engine.getCurrentOralQuestion()
                oralProgress = await engine.getOralProgress()
                oralState = .readingQuestion
                state = .oralRound
            }
        }
    }

    func restartMatch() {
        matchSummary = nil
        state = .setup
    }
}

// MARK: - Preview

#Preview {
    KBMatchSimulationView(
        region: .colorado,
        questions: (0..<50).map { index in
            KBQuestion(
                id: UUID(),
                text: "Sample question \(index + 1)?",
                answer: KBAnswer(primary: "Answer \(index + 1)", acceptable: nil, answerType: .text),
                domain: KBDomain.allCases[index % KBDomain.allCases.count],
                difficulty: .foundational,
                gradeLevel: .highSchool,
                suitability: KBSuitability()
            )
        }
    )
}
