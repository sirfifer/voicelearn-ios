// UnaMentis - Knowledge Bowl Dashboard View
// Main dashboard for the Knowledge Bowl training module
//
// Displays domain mastery radar, study session options,
// and quick access to competition simulation.

import SwiftUI
import Logging

/// Main dashboard view for Knowledge Bowl module
struct KBDashboardView: View {
    @State private var selectedStudyMode: KBStudyMode?
    @State private var activePracticeMode: KBStudyMode = .diagnostic
    @State private var showingDomainDetail: KBDomain?
    @State private var showingPracticeSession = false
    @State private var practiceQuestions: [KBQuestion] = []
    @State private var pendingPracticeStart = false  // Track pending practice session launch
    @StateObject private var questionService = KBQuestionService.shared

    private static let logger = Logger(label: "com.unamentis.kb.dashboard")

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero section with mastery overview
                heroSection

                // Domain mastery radar chart
                domainRadarSection

                // Study session options
                studyModeSection

                // Quick stats
                statsSection
            }
            .padding()
        }
        .navigationTitle("Knowledge Bowl")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .sheet(item: $selectedStudyMode) { mode in
            NavigationStack {
                KBPracticeLauncherView(
                    mode: mode,
                    questionService: questionService,
                    onStart: { questions in
                        activePracticeMode = mode
                        practiceQuestions = questions
                        pendingPracticeStart = true
                        selectedStudyMode = nil
                    },
                    onCancel: {
                        selectedStudyMode = nil
                    }
                )
            }
        }
        .onChange(of: selectedStudyMode) { oldValue, newValue in
            // When sheet dismisses and we have a pending practice start
            if oldValue != nil && newValue == nil && pendingPracticeStart {
                pendingPracticeStart = false
                // Delay slightly to ensure sheet animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingPracticeSession = true
                }
            }
        }
        .fullScreenCover(isPresented: $showingPracticeSession) {
            NavigationStack {
                KBPracticeSessionView(
                    mode: activePracticeMode,
                    questions: practiceQuestions,
                    onComplete: { summary in
                        Self.logger.info("Practice completed: \(summary.correctAnswers)/\(summary.totalQuestions)")
                        showingPracticeSession = false
                    }
                )
            }
        }
        .task {
            await questionService.loadQuestions()
        }
        .sheet(item: $showingDomainDetail) { domain in
            NavigationStack {
                KBDomainDetailView(domain: domain)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingDomainDetail = nil
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Hero Section

    @ViewBuilder
    private var heroSection: some View {
        VStack(spacing: 12) {
            // Readiness score
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 12)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: 0.0)  // Will be dynamic
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("0%")
                        .font(.title.bold())
                    Text("Ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Competition Readiness")
                .font(.headline)

            Text("Complete a diagnostic session to see your readiness score")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Domain Radar Section

    @ViewBuilder
    private var domainRadarSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Domain Mastery")
                    .font(.headline)
                Spacer()
                Button("View All") {
                    // Show domain list
                }
                .font(.subheadline)
            }

            // Simplified radar visualization (placeholder for now)
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(KBDomain.allCases.prefix(6)) { domain in
                    DomainMasteryCard(domain: domain, mastery: 0.0)
                        .onTapGesture {
                            showingDomainDetail = domain
                        }
                }
            }

            // Show remaining domains in smaller view
            if KBDomain.allCases.count > 6 {
                HStack(spacing: 8) {
                    ForEach(Array(KBDomain.allCases.dropFirst(6))) { domain in
                        DomainMasteryBadge(domain: domain, mastery: 0.0)
                            .onTapGesture {
                                showingDomainDetail = domain
                            }
                    }
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Study Mode Section

    @ViewBuilder
    private var studyModeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Study Sessions")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(KBStudyMode.allCases) { mode in
                    StudyModeCard(mode: mode)
                        .onTapGesture {
                            Self.logger.info("Selected study mode: \(mode.rawValue)")
                            selectedStudyMode = mode
                        }
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Stats Section

    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Stats")
                .font(.headline)

            HStack(spacing: 16) {
                KBStatCard(title: "Questions", value: "0", icon: "questionmark.circle")
                KBStatCard(title: "Avg Speed", value: "--", icon: "bolt")
                KBStatCard(title: "Accuracy", value: "--%", icon: "checkmark.circle")
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Study Modes

/// Available study session modes
enum KBStudyMode: String, CaseIterable, Identifiable {
    case diagnostic = "Diagnostic"
    case targeted = "Targeted"
    case breadth = "Breadth"
    case speed = "Speed Drill"
    case competition = "Competition"
    case team = "Team Practice"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .diagnostic: return "Assess all domains"
        case .targeted: return "Focus on weak areas"
        case .breadth: return "Maintain coverage"
        case .speed: return "Build quick recall"
        case .competition: return "Full simulation"
        case .team: return "Practice with team"
        }
    }

    var iconName: String {
        switch self {
        case .diagnostic: return "chart.pie"
        case .targeted: return "scope"
        case .breadth: return "rectangle.grid.3x2"
        case .speed: return "bolt.circle"
        case .competition: return "trophy"
        case .team: return "person.3"
        }
    }

    var color: Color {
        switch self {
        case .diagnostic: return .blue
        case .targeted: return .orange
        case .breadth: return .green
        case .speed: return .red
        case .competition: return .purple
        case .team: return .cyan
        }
    }
}

// MARK: - Supporting Views

struct DomainMasteryCard: View {
    let domain: KBDomain
    let mastery: Double

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: domain.iconName)
                .font(.title2)
                .foregroundStyle(domain.color)

            Text(domain.rawValue)
                .font(.caption)
                .lineLimit(1)

            Text("\(Int(mastery * 100))%")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(domain.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DomainMasteryBadge: View {
    let domain: KBDomain
    let mastery: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: domain.iconName)
                .font(.caption2)
            Text("\(Int(mastery * 100))%")
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(domain.color)
        .background(domain.color.opacity(0.1))
        .clipShape(Capsule())
    }
}

struct StudyModeCard: View {
    let mode: KBStudyMode

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: mode.iconName)
                .font(.title2)
                .foregroundStyle(mode.color)

            Text(mode.rawValue)
                .font(.subheadline.bold())

            Text(mode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(mode.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct KBStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Dashboard Summary (for Module List)

/// Compact summary view shown in the modules list
struct KBDashboardSummary: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("0% Ready")
                    .font(.headline)
                Text("0 questions practiced")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Placeholder Views

struct KBStudyModeView: View {
    let mode: KBStudyMode

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: mode.iconName)
                .font(.system(size: 60))
                .foregroundStyle(mode.color)

            Text(mode.rawValue)
                .font(.title)

            Text(mode.description)
                .foregroundStyle(.secondary)

            Text("Coming Soon")
                .font(.headline)
                .padding()
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .navigationTitle(mode.rawValue)
    }
}

struct KBDomainDetailView: View {
    let domain: KBDomain

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: domain.iconName)
                        .font(.largeTitle)
                        .foregroundStyle(domain.color)

                    VStack(alignment: .leading) {
                        Text(domain.rawValue)
                            .font(.title2.bold())
                        Text("\(Int(domain.weight * 100))% of competition questions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical)
            }

            Section("Subcategories") {
                ForEach(domain.subcategories, id: \.self) { subcategory in
                    HStack {
                        Text(subcategory)
                        Spacer()
                        Text("0%")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Stats") {
                LabeledContent("Questions Answered", value: "0")
                LabeledContent("Accuracy", value: "0%")
                LabeledContent("Average Speed", value: "--")
            }
        }
        .navigationTitle(domain.rawValue)
    }
}

// MARK: - Previews

#Preview("Dashboard") {
    NavigationStack {
        KBDashboardView()
    }
}

#Preview("Study Mode") {
    NavigationStack {
        KBStudyModeView(mode: .diagnostic)
    }
}

#Preview("Domain Detail") {
    NavigationStack {
        KBDomainDetailView(domain: .science)
    }
}

// MARK: - Practice Launcher View

struct KBPracticeLauncherView: View {
    let mode: KBStudyMode
    let questionService: KBQuestionService
    let onStart: ([KBQuestion]) -> Void
    let onCancel: () -> Void

    @State private var isLoading = true
    @State private var loadedQuestions: [KBQuestion] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 50))
                    .foregroundStyle(mode.color)
                Text(mode.rawValue)
                    .font(.title.bold())
                Text(mode.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            Spacer()

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
                    Button("Try Again") {
                        Task { await loadQuestions() }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Questions")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(loadedQuestions.count)")
                                .fontWeight(.medium)
                        }
                        if mode == .speed {
                            HStack {
                                Text("Time Limit")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("5 minutes")
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }

            Spacer()

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

                Button("Cancel", role: .cancel) { onCancel() }
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("Start \(mode.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel() }
            }
        }
        .task { await loadQuestions() }
    }

    private func loadQuestions() async {
        isLoading = true
        errorMessage = nil
        if !questionService.isLoaded {
            await questionService.loadQuestions()
        }
        let questions = questionService.questions(forMode: mode)
        if questions.isEmpty {
            errorMessage = "No questions available."
        } else {
            loadedQuestions = questions
        }
        isLoading = false
    }
}

// MARK: - Practice Session View

struct KBPracticeSessionView: View {
    let mode: KBStudyMode
    let questions: [KBQuestion]
    let onComplete: (KBSessionSummary) -> Void

    @StateObject private var engine = KBPracticeEngine()
    @State private var userAnswer = ""
    @State private var showingExitConfirmation = false
    @FocusState private var isAnswerFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            Divider()
            switch engine.sessionState {
            case .notStarted:
                ProgressView("Starting...")
            case .inProgress:
                questionView
            case .showingAnswer(let isCorrect):
                answerFeedbackView(isCorrect: isCorrect)
            case .completed:
                completedView
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle(mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(engine.sessionState != .completed)
        .toolbar {
            if engine.sessionState != .completed {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Exit") { showingExitConfirmation = true }
                }
            }
        }
        .confirmationDialog("Exit Practice?", isPresented: $showingExitConfirmation) {
            Button("Exit", role: .destructive) { dismiss() }
            Button("Continue", role: .cancel) { }
        }
        .onAppear { engine.startSession(questions: questions, mode: mode) }
    }

    @ViewBuilder
    private var progressHeader: some View {
        HStack {
            Text("\(engine.questionIndex + 1) of \(engine.totalQuestions)")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(engine.results.filter { $0.isCorrect }.count) correct")
                .font(.subheadline)
                .foregroundStyle(.green)
            if mode == .speed && engine.timeRemaining > 0 {
                Spacer()
                Text(formatTime(engine.timeRemaining))
                    .font(.subheadline.bold())
                    .foregroundStyle(engine.timeRemaining < 30 ? .red : .orange)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var questionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let question = engine.currentQuestion {
                    Text(question.questionText)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { i in
                            Circle()
                                .fill(i <= question.difficulty ? Color.orange : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }

                VStack(spacing: 12) {
                    TextField("Your answer...", text: $userAnswer)
                        .textFieldStyle(.roundedBorder)
                        .focused($isAnswerFocused)
                        .submitLabel(.done)
                        .onSubmit { if !userAnswer.isEmpty { engine.submitAnswer(userAnswer); isAnswerFocused = false } }
                        .padding(.horizontal)

                    HStack(spacing: 16) {
                        Button("Skip") { engine.skipQuestion() }
                            .buttonStyle(.bordered)
                        Button("Submit") { engine.submitAnswer(userAnswer); isAnswerFocused = false }
                            .buttonStyle(.borderedProminent)
                            .disabled(userAnswer.isEmpty)
                    }
                }
                .padding(.top)
            }
            .padding(.vertical, 32)
        }
        .onAppear { isAnswerFocused = true }
    }

    @ViewBuilder
    private func answerFeedbackView(isCorrect: Bool) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(isCorrect ? .green : .red)
                Text(isCorrect ? "Correct!" : "Incorrect")
                    .font(.title.bold())
                    .foregroundStyle(isCorrect ? .green : .red)

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

                    if !question.explanation.isEmpty {
                        Text(question.explanation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

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

    @ViewBuilder
    private var completedView: some View {
        let summary = engine.generateSummary()
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)
                Text("Session Complete!")
                    .font(.title.bold())

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    SummaryStatCard(title: "Accuracy", value: String(format: "%.0f%%", summary.accuracy * 100), color: summary.accuracy >= 0.7 ? .green : .orange)
                    SummaryStatCard(title: "Correct", value: "\(summary.correctAnswers)/\(summary.totalQuestions)", color: .blue)
                    SummaryStatCard(title: "Avg Time", value: String(format: "%.1fs", summary.averageResponseTime), color: .purple)
                    SummaryStatCard(title: "Speed Target", value: String(format: "%.0f%%", summary.speedTargetRate * 100), color: .orange)
                }
                .padding(.horizontal)

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

    private func formatTime(_ seconds: TimeInterval) -> String {
        String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}

struct SummaryStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
