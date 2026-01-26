// UnaMentis - Knowledge Bowl Dashboard View
// Main dashboard for the Knowledge Bowl training module
//
// Displays domain mastery, practice modes, competition training,
// and quick access to all Knowledge Bowl features.

import SwiftUI
import Logging

/// Main dashboard view for Knowledge Bowl module
struct KBDashboardView: View {
    // MARK: - State

    @State private var selectedStudyMode: KBStudyMode?
    @State private var activePracticeMode: KBStudyMode = .diagnostic
    @State private var showingDomainDetail: KBDomain?
    @State private var showingPracticeSession = false
    @State private var practiceQuestions: [KBQuestion] = []
    @State private var pendingPracticeStart = false

    // Region selection
    @State private var selectedRegion: KBRegion = .colorado

    // Training mode presentations
    @State private var showingWrittenSession = false
    @State private var showingOralSession = false
    @State private var showingMatchSimulation = false
    @State private var showingConferenceTraining = false
    @State private var showingReboundTraining = false
    @State private var showingDomainDrill = false
    @State private var showingHelpSheet = false

    @StateObject private var questionService = KBQuestionService.shared
    @StateObject private var statsManager = KBStatsManager.shared
    @StateObject private var moduleRegistry = ModuleRegistry.shared

    // KBQuestionEngine for UI/KnowledgeBowl views (Core question format)
    @State private var questionEngine = KBQuestionEngine()

    private static let logger = Logger(label: "com.unamentis.kb.dashboard")

    /// Feature flags from the downloaded module (or defaults if not downloaded)
    private var moduleFeatures: ModuleFeatures {
        if let kbModule = moduleRegistry.getDownloaded(moduleId: "knowledge-bowl") {
            return ModuleFeatures(
                supportsTeamMode: kbModule.supportsTeamMode,
                supportsSpeedTraining: kbModule.supportsSpeedTraining,
                supportsCompetitionSim: kbModule.supportsCompetitionSim
            )
        }
        // Default to all enabled for local-only mode
        return .defaultEnabled
    }

    /// Study modes available based on feature flags
    private var availableStudyModes: [KBStudyMode] {
        KBStudyMode.allCases.filter { mode in
            switch mode.requiredFeature {
            case .none:
                return true
            case .teamMode:
                return moduleFeatures.supportsTeamMode
            case .speedTraining:
                return moduleFeatures.supportsSpeedTraining
            case .competitionSim:
                return moduleFeatures.supportsCompetitionSim
            }
        }
    }

    /// Questions for training modes (Core format for UI/KnowledgeBowl views)
    private var coreQuestions: [KBQuestion] {
        questionEngine.questions
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero section with mastery overview
                heroSection

                // Server connectivity indicator (only shown when offline)
                if !questionService.isServerConnected && questionService.isLoaded {
                    serverStatusBanner
                }

                // Region selector
                regionSelector

                // Practice Sessions (Written & Oral)
                practiceSessionsSection

                // Competition Training
                competitionTrainingSection

                // Domain mastery
                domainRadarSection

                // Study strategies (existing modes)
                studyModeSection

                // Quick stats
                statsSection
            }
            .padding()
        }
        .navigationTitle("Knowledge Bowl")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingHelpSheet = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
            }
        }
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
                        statsManager.recordSession(summary, mode: activePracticeMode)
                        showingPracticeSession = false
                    }
                )
            }
        }
        // Written Session
        .fullScreenCover(isPresented: $showingWrittenSession) {
            NavigationStack {
                KBWrittenSessionView(
                    viewModel: KBWrittenSessionViewModel(
                        questions: questionEngine.selectForSession(
                            config: KBSessionConfig.quickPractice(region: selectedRegion, roundType: .written, questionCount: 20)
                        ),
                        config: KBSessionConfig.quickPractice(region: selectedRegion, roundType: .written, questionCount: 20)
                    )
                )
            }
        }
        // Oral Session
        .fullScreenCover(isPresented: $showingOralSession) {
            NavigationStack {
                KBOralSessionView(
                    viewModel: KBOralSessionViewModel(
                        questions: questionEngine.selectForSession(
                            config: KBSessionConfig.quickPractice(region: selectedRegion, roundType: .oral, questionCount: 10)
                        ),
                        config: KBSessionConfig.quickPractice(region: selectedRegion, roundType: .oral, questionCount: 10)
                    )
                )
            }
        }
        // Match Simulation
        .fullScreenCover(isPresented: $showingMatchSimulation) {
            KBMatchSimulationView(
                region: selectedRegion,
                questions: coreQuestions.isEmpty ? questionEngine.filter().shuffled() : coreQuestions
            )
        }
        // Conference Training
        .fullScreenCover(isPresented: $showingConferenceTraining) {
            KBConferenceTrainingView(
                region: selectedRegion,
                questions: coreQuestions.isEmpty ? questionEngine.filter().shuffled() : coreQuestions
            )
        }
        // Rebound Training
        .fullScreenCover(isPresented: $showingReboundTraining) {
            KBReboundTrainingView(
                region: selectedRegion,
                questions: coreQuestions.isEmpty ? questionEngine.filter().shuffled() : coreQuestions
            )
        }
        // Domain Drill
        .fullScreenCover(isPresented: $showingDomainDrill) {
            NavigationStack {
                KBDomainDrillView()
            }
        }
        // Help Sheet
        .sheet(isPresented: $showingHelpSheet) {
            NavigationStack {
                KBHelpSheet()
            }
        }
        .task {
            // Load both question sources concurrently for best performance
            // Both are now local-first and don't require server connectivity
            async let serviceLoad: () = questionService.loadQuestions()
            async let engineLoad: () = {
                do {
                    try await questionEngine.loadBundledQuestions()
                } catch {
                    Self.logger.warning("Failed to load bundled questions: \(error.localizedDescription)")
                }
            }()

            // Wait for both to complete (both are now fast local operations)
            _ = await (serviceLoad, engineLoad)
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

    // MARK: - Region Selector

    @ViewBuilder
    private var regionSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Competition Region")
                    .font(.headline)
                Spacer()
                InfoButton(
                    title: "Regional Rules",
                    content: KBHelpContent.Regional.overview
                )
            }

            Picker("Region", selection: $selectedRegion) {
                ForEach(KBRegion.allCases) { region in
                    Text(region.displayName).tag(region)
                }
            }
            .pickerStyle(.segmented)

            Text(selectedRegion.shortDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Practice Sessions Section

    @ViewBuilder
    private var practiceSessionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Practice Sessions")
                    .font(.headline)
                Spacer()
                InfoButton(
                    title: "Practice Modes",
                    content: "Practice oral (voice) and written (MCQ) rounds to prepare for competition."
                )
            }

            HStack(spacing: 12) {
                // Oral Practice (Voice-first)
                TrainingModeCard(
                    title: "Oral",
                    subtitle: "Voice Q&A",
                    icon: "mic.fill",
                    color: .green
                ) {
                    Self.logger.info("Starting oral practice session")
                    showingOralSession = true
                }

                // Written Practice
                TrainingModeCard(
                    title: "Written",
                    subtitle: "MCQ Practice",
                    icon: "pencil.and.list.clipboard",
                    color: .blue
                ) {
                    Self.logger.info("Starting written practice session")
                    showingWrittenSession = true
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Competition Training Section

    @ViewBuilder
    private var competitionTrainingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Competition Training")
                    .font(.headline)
                Spacer()
                InfoButton(
                    title: "Competition Training",
                    content: KBHelpContent.TrainingModes.matchOverview
                )
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Match Simulation
                CompactTrainingCard(
                    title: "Match",
                    icon: "trophy.fill",
                    color: .yellow
                ) {
                    Self.logger.info("Starting match simulation")
                    showingMatchSimulation = true
                }

                // Conference Training
                CompactTrainingCard(
                    title: "Conference",
                    icon: "person.3.fill",
                    color: .purple
                ) {
                    Self.logger.info("Starting conference training")
                    showingConferenceTraining = true
                }

                // Rebound Training
                CompactTrainingCard(
                    title: "Rebound",
                    icon: "arrow.uturn.backward.circle.fill",
                    color: .orange
                ) {
                    Self.logger.info("Starting rebound training")
                    showingReboundTraining = true
                }
            }

            // Domain Drill (full width)
            Button {
                Self.logger.info("Starting domain drill")
                showingDomainDrill = true
            } label: {
                HStack {
                    Image(systemName: "scope")
                        .font(.title2)
                        .foregroundStyle(.cyan)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Domain Drill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("Focus on specific knowledge areas")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(Color.cyan.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Hero Section

    @ViewBuilder
    private var heroSection: some View {
        let readiness = statsManager.competitionReadiness
        VStack(spacing: 12) {
            // Readiness score
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 12)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: readiness)
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: readiness)

                VStack(spacing: 2) {
                    Text("\(Int(readiness * 100))%")
                        .font(.title.bold())
                    Text("Ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Competition Readiness")
                .font(.headline)

            Text(statsManager.totalQuestionsAnswered == 0
                 ? "Complete a diagnostic session to see your readiness score"
                 : "Based on \(statsManager.totalQuestionsAnswered) questions across \(statsManager.domainStats.count) domains")
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

    // MARK: - Server Status Banner

    @ViewBuilder
    private var serverStatusBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.title3)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Offline Mode")
                    .font(.subheadline.bold())
                Text("Using \(questionService.allQuestions.count.formatted()) bundled questions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Connection status dot
            Circle()
                .fill(.orange)
                .frame(width: 8, height: 8)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Domain Radar Section

    @ViewBuilder
    private var domainRadarSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Domain Mastery")
                .font(.headline)

            // Domain mastery grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(KBDomain.allCases.prefix(6)) { domain in
                    DomainMasteryCard(domain: domain, mastery: statsManager.mastery(for: domain))
                        .onTapGesture {
                            showingDomainDetail = domain
                        }
                }
            }

            // Show remaining domains in smaller view
            if KBDomain.allCases.count > 6 {
                HStack(spacing: 8) {
                    ForEach(Array(KBDomain.allCases.dropFirst(6))) { domain in
                        DomainMasteryBadge(domain: domain, mastery: statsManager.mastery(for: domain))
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
            HStack {
                Text("Study Sessions")
                    .font(.headline)
                Spacer()
                if availableStudyModes.count < KBStudyMode.allCases.count {
                    Text("\(KBStudyMode.allCases.count - availableStudyModes.count) restricted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(availableStudyModes) { mode in
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
                KBStatCard(
                    title: "Questions",
                    value: "\(statsManager.totalQuestionsAnswered)",
                    icon: "questionmark.circle"
                )
                KBStatCard(
                    title: "Avg Speed",
                    value: statsManager.averageResponseTime > 0
                        ? String(format: "%.1fs", statsManager.averageResponseTime)
                        : "--",
                    icon: "bolt"
                )
                KBStatCard(
                    title: "Accuracy",
                    value: statsManager.totalQuestionsAnswered > 0
                        ? String(format: "%.0f%%", statsManager.overallAccuracy * 100)
                        : "--%",
                    icon: "checkmark.circle"
                )
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Feature Flags

/// Feature type that a study mode requires
enum KBRequiredFeature {
    case none           // Always available
    case teamMode       // Requires supportsTeamMode
    case speedTraining  // Requires supportsSpeedTraining
    case competitionSim // Requires supportsCompetitionSim
}

/// Local copy of feature flags for the module
struct ModuleFeatures {
    let supportsTeamMode: Bool
    let supportsSpeedTraining: Bool
    let supportsCompetitionSim: Bool

    /// Default features when module is not downloaded (local-only mode)
    static let defaultEnabled = ModuleFeatures(
        supportsTeamMode: true,
        supportsSpeedTraining: true,
        supportsCompetitionSim: true
    )
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

    /// Which feature flag this mode requires (if any)
    var requiredFeature: KBRequiredFeature {
        switch self {
        case .diagnostic, .targeted, .breadth:
            return .none  // Core study modes, always available
        case .speed:
            return .speedTraining
        case .competition:
            return .competitionSim
        case .team:
            return .teamMode
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

            Text(domain.displayName)
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

/// Card for practice session modes (Written/Oral)
struct TrainingModeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)

                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

/// Compact card for competition training modes
struct CompactTrainingCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dashboard Summary (for Module List)

/// Compact summary view shown in the modules list
struct KBDashboardSummary: View {
    @StateObject private var statsManager = KBStatsManager.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(statsManager.competitionReadiness * 100))% Ready")
                    .font(.headline)
                Text("\(statsManager.totalQuestionsAnswered) questions practiced")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
    }
}

struct KBDomainDetailView: View {
    let domain: KBDomain
    @StateObject private var statsManager = KBStatsManager.shared

    private var domainStats: DomainStats? {
        // Use the raw value directly since KBDomain now uses lowercase identifiers
        return statsManager.domainStats[domain.rawValue]
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: domain.iconName)
                        .font(.largeTitle)
                        .foregroundStyle(domain.color)

                    VStack(alignment: .leading) {
                        Text(domain.displayName)
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
                        Text("--")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Stats") {
                if let stats = domainStats {
                    LabeledContent("Questions Answered", value: "\(stats.totalAnswered)")
                    LabeledContent("Accuracy", value: String(format: "%.0f%%", stats.accuracy * 100))
                    LabeledContent("Average Speed", value: "--")
                } else {
                    LabeledContent("Questions Answered", value: "0")
                    LabeledContent("Accuracy", value: "--%")
                    LabeledContent("Average Speed", value: "--")
                }
            }
        }
        .navigationTitle(domain.displayName)
    }
}

// MARK: - Previews

#Preview("Dashboard") {
    NavigationStack {
        KBDashboardView()
    }
}

#Preview("Domain Detail") {
    NavigationStack {
        KBDomainDetailView(domain: .science)
    }
}

// MARK: - Practice views are defined in separate files
// KBPracticeLauncherView is in KBPracticeLauncherView.swift
// KBPracticeSessionView is in KBPracticeSessionView.swift
