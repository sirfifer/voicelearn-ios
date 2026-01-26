//
//  KBDashboardView.swift
//  UnaMentis
//
//  Main dashboard and entry point for Knowledge Bowl module
//

import SwiftUI

// MARK: - Dashboard View

struct KBDashboardView: View {
    @State private var engine = KBQuestionEngine()
    @State private var store = KBSessionStore()
    @State private var selectedRegion: KBRegion = .colorado
    @State private var showingWrittenSession = false
    @State private var showingOralSession = false
    @State private var showingSettings = false
    @State private var showingHelp = false
    @State private var writtenSessionViewModel: KBWrittenSessionViewModel?
    @State private var oralSessionViewModel: KBOralSessionViewModel?
    @State private var recentSessions: [KBSession] = []
    @State private var statistics: KBStatistics?

    // Competition Training states
    @State private var showingMatchSimulation = false
    @State private var showingConferenceTraining = false
    @State private var showingReboundTraining = false
    @State private var showingDomainDrill = false
    @State private var matchQuestions: [KBQuestion] = []
    @State private var conferenceQuestions: [KBQuestion] = []
    @State private var reboundQuestions: [KBQuestion] = []

    // Quickstart settings state
    @State private var oralQuestionCount: Int = 5
    @State private var writtenQuestionCount: Int = 10
    @State private var writtenTimePerQuestion: TimeInterval = 15
    @State private var domainMix: KBDomainMix = .default
    @State private var selectedPackId: String?
    @State private var localPackStore = KBLocalPackStore()

    // Quickstart settings sheet states
    @State private var showingOralSettings = false
    @State private var showingWrittenSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header card
                    headerCard

                    // Quick start section
                    quickStartSection

                    // Competition Training section
                    competitionTrainingSection

                    // Session history
                    if !recentSessions.isEmpty {
                        sessionHistorySection
                    }

                    // Overall statistics
                    if let statistics = statistics {
                        statisticsSection(statistics)
                    }

                    // Region selector
                    regionSelector

                    // Stats section (placeholder for now)
                    if engine.totalQuestionCount > 0 {
                        statsSection
                    }
                }
                .padding()
            }
            .background(Color.kbBgPrimary)
            .navigationTitle("Knowledge Bowl")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingHelp = true }) {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("Help")
                    .accessibilityHint("Opens Knowledge Bowl help and strategy guide")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Opens Knowledge Bowl settings")
                }
            }
            .task {
                await loadQuestions()
                await loadSessions()
            }
            .sheet(isPresented: $showingSettings) {
                KBSettingsView(selectedRegion: $selectedRegion)
            }
            .sheet(isPresented: $showingHelp) {
                KBHelpSheet()
            }
            .navigationDestination(isPresented: $showingWrittenSession) {
                if let viewModel = writtenSessionViewModel {
                    KBWrittenSessionView(viewModel: viewModel)
                }
            }
            .navigationDestination(isPresented: $showingOralSession) {
                if let viewModel = oralSessionViewModel {
                    KBOralSessionView(viewModel: viewModel)
                }
            }
            .navigationDestination(isPresented: $showingMatchSimulation) {
                KBMatchSimulationView(region: selectedRegion, questions: matchQuestions)
            }
            .navigationDestination(isPresented: $showingConferenceTraining) {
                KBConferenceTrainingView(region: selectedRegion, questions: conferenceQuestions)
            }
            .navigationDestination(isPresented: $showingReboundTraining) {
                KBReboundTrainingView(region: selectedRegion, questions: reboundQuestions)
            }
            .navigationDestination(isPresented: $showingDomainDrill) {
                KBDomainDrillView()
            }
            .sheet(isPresented: $showingOralSettings) {
                KBQuickstartSettingsView(
                    roundType: .oral,
                    questionCount: $oralQuestionCount,
                    timePerQuestion: .constant(0),  // Not used for oral
                    domainMix: $domainMix,
                    selectedPackId: $selectedPackId,
                    localPackStore: localPackStore
                )
            }
            .sheet(isPresented: $showingWrittenSettings) {
                KBQuickstartSettingsView(
                    roundType: .written,
                    questionCount: $writtenQuestionCount,
                    timePerQuestion: $writtenTimePerQuestion,
                    domainMix: $domainMix,
                    selectedPackId: $selectedPackId,
                    localPackStore: localPackStore
                )
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundColor(.kbMastered)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Knowledge Bowl")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.kbTextPrimary)

                    Text("Train for academic competitions")
                        .font(.subheadline)
                        .foregroundColor(.kbTextSecondary)
                }

                Spacer()
            }

            // Loading state
            if engine.isLoading {
                ProgressView("Loading questions...")
                    .foregroundColor(.kbTextSecondary)
            } else if let error = engine.loadError {
                Text("Error: \(error.localizedDescription)")
                    .font(.caption)
                    .foregroundColor(.kbFocusArea)
            } else {
                HStack {
                    statBadge(value: "\(engine.totalQuestionCount)", label: "Questions")
                    Spacer()
                    statBadge(value: "\(KBDomain.allCases.count)", label: "Domains")
                    Spacer()
                    statBadge(value: selectedRegion.abbreviation, label: "Region")
                }
            }
        }
        .padding()
        .background(Color.kbBgSecondary)
        .cornerRadius(16)
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.kbMastered)
            Text(label)
                .font(.caption)
                .foregroundColor(.kbTextSecondary)
        }
    }

    // MARK: - Quick Start Section

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick Start")
                    .font(.headline)
                    .foregroundColor(.kbTextPrimary)
                InfoButton(
                    title: "Quick Start",
                    content: KBHelpContent.UIElements.quickStart
                )
            }

            HStack(spacing: 12) {
                // Oral Practice (Voice-first)
                quickStartCard(
                    icon: "mic.fill",
                    title: "Oral",
                    subtitle: "\(oralQuestionCount) questions",
                    color: .kbMastered,
                    onTap: { startOralPractice() },
                    onSettings: { showingOralSettings = true }
                )

                // Written Practice
                quickStartCard(
                    icon: "pencil.and.list.clipboard",
                    title: "Written",
                    subtitle: "\(writtenQuestionCount) questions",
                    color: .kbIntermediate,
                    onTap: { startWrittenPractice() },
                    onSettings: { showingWrittenSettings = true }
                )
            }
        }
    }

    private func quickStartCard(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        onTap: @escaping () -> Void,
        onSettings: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            // Main button
            Button(action: onTap) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(color)

                    Text(title)
                        .font(.headline)
                        .foregroundColor(.kbTextPrimary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.kbTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.kbBgSecondary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 2)
                )
            }
            .disabled(engine.totalQuestionCount == 0)

            // Settings button (gear icon)
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(color.opacity(0.8))
                    .clipShape(Circle())
            }
            .offset(x: -8, y: 8)
            .accessibilityLabel("\(title) settings")
        }
    }

    private func quickStartButton(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.kbTextPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.kbTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.kbBgSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 2)
            )
        }
        .disabled(engine.totalQuestionCount == 0)
    }

    // MARK: - Competition Training Section

    private var competitionTrainingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Competition Training")
                    .font(.headline)
                    .foregroundColor(.kbTextPrimary)
                InfoButton(
                    title: "Competition Training",
                    content: KBHelpContent.General.gettingStarted
                )
            }

            // First row: Match Simulation and Conference
            HStack(spacing: 12) {
                trainingModeButton(
                    icon: "trophy.fill",
                    title: "Match",
                    subtitle: "Full Simulation",
                    color: .yellow
                ) {
                    startMatchSimulation()
                }

                trainingModeButton(
                    icon: "person.3.fill",
                    title: "Conference",
                    subtitle: "Team Practice",
                    color: .purple
                ) {
                    startConferenceTraining()
                }
            }

            // Second row: Rebound and Domain Drill
            HStack(spacing: 12) {
                trainingModeButton(
                    icon: "arrow.uturn.left.circle.fill",
                    title: "Rebound",
                    subtitle: "Second Chance",
                    color: .orange
                ) {
                    startReboundTraining()
                }

                trainingModeButton(
                    icon: "target",
                    title: "Domain Drill",
                    subtitle: "Focus Practice",
                    color: .cyan
                ) {
                    startDomainDrill()
                }
            }
        }
    }

    private func trainingModeButton(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.kbTextPrimary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.kbTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.kbBgSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 2)
            )
        }
        .disabled(engine.totalQuestionCount == 0)
    }

    // MARK: - Training Mode Start Functions

    private func startMatchSimulation() {
        // Match simulation uses a mix of written and oral questions
        let config = KBSessionConfig.quickPractice(
            region: selectedRegion,
            roundType: .oral,
            questionCount: 20
        )
        matchQuestions = engine.selectForSession(config: config)
        showingMatchSimulation = true
    }

    private func startConferenceTraining() {
        let config = KBSessionConfig.quickPractice(
            region: selectedRegion,
            roundType: .oral,
            questionCount: 15
        )
        conferenceQuestions = engine.selectForSession(config: config)
        showingConferenceTraining = true
    }

    private func startReboundTraining() {
        let config = KBSessionConfig.quickPractice(
            region: selectedRegion,
            roundType: .oral,
            questionCount: 20
        )
        reboundQuestions = engine.selectForSession(config: config)
        showingReboundTraining = true
    }

    private func startDomainDrill() {
        showingDomainDrill = true
    }

    // MARK: - Region Selector

    private var regionSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Competition Region")
                    .font(.headline)
                    .foregroundColor(.kbTextPrimary)
                InfoButton(
                    title: "Region Selection",
                    content: KBHelpContent.UIElements.regionSelector
                )
            }

            HStack(spacing: 8) {
                ForEach([KBRegion.colorado, .minnesota, .washington], id: \.self) { region in
                    regionButton(region)
                }
            }

            // Regional rules summary
            Text(selectedRegion.config.conferringRuleDescription)
                .font(.caption)
                .foregroundColor(.kbTextSecondary)
                .padding(.horizontal, 4)
        }
    }

    private func regionButton(_ region: KBRegion) -> some View {
        let isSelected = selectedRegion == region

        return Button(action: {
            withAnimation {
                selectedRegion = region
            }
        }) {
            Text(region.abbreviation)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .kbTextPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.kbMastered : Color.kbBgSecondary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.clear : Color.kbBorder, lineWidth: 1)
                )
        }
    }

    // MARK: - Session History Section

    private var sessionHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Practice")
                    .font(.headline)
                    .foregroundColor(.kbTextPrimary)
                InfoButton(
                    title: "Session History",
                    content: KBHelpContent.UIElements.sessionHistory
                )
            }

            VStack(spacing: 8) {
                ForEach(recentSessions.prefix(5)) { session in
                    sessionHistoryCard(session)
                }
            }

            if recentSessions.count > 5 {
                Text("+ \(recentSessions.count - 5) more sessions")
                    .font(.caption)
                    .foregroundColor(.kbTextSecondary)
                    .padding(.top, 4)
            }
        }
    }

    private func sessionHistoryCard(_ session: KBSession) -> some View {
        HStack(spacing: 12) {
            // Round type icon
            Image(systemName: session.config.roundType == .written ? "pencil.and.list.clipboard" : "mic.fill")
                .font(.title3)
                .foregroundColor(session.config.roundType == .written ? .kbIntermediate : .kbMastered)
                .frame(width: 40, height: 40)
                .background(
                    (session.config.roundType == .written ? Color.kbIntermediate : Color.kbMastered)
                        .opacity(0.1)
                )
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(session.config.roundType == .written ? "Written" : "Oral") Practice")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.kbTextPrimary)

                    Spacer()

                    Text(formatAccuracy(session.accuracy))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(session.accuracy >= 0.7 ? .kbMastered : .kbBeginner)
                }

                HStack(spacing: 12) {
                    Text("\(session.correctCount)/\(session.attempts.count) correct")
                        .font(.caption)
                        .foregroundColor(.kbTextSecondary)

                    if let endTime = session.endTime {
                        Text("•")
                            .foregroundColor(.kbTextSecondary)
                        Text(formatRelativeDate(endTime))
                            .font(.caption)
                            .foregroundColor(.kbTextSecondary)
                    }

                    Text("•")
                        .foregroundColor(.kbTextSecondary)
                    Text(session.config.region.abbreviation)
                        .font(.caption)
                        .foregroundColor(.kbTextSecondary)
                }
            }
        }
        .padding()
        .background(Color.kbBgSecondary)
        .cornerRadius(12)
    }

    // MARK: - Statistics Section

    private func statisticsSection(_ stats: KBStatistics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall Progress")
                .font(.headline)
                .foregroundColor(.kbTextPrimary)

            HStack(spacing: 12) {
                // Overall accuracy
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.kbBorder, lineWidth: 8)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(from: 0, to: stats.overallAccuracy)
                            .stroke(
                                stats.overallAccuracy >= 0.7 ? Color.kbMastered : Color.kbBeginner,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))

                        Text(formatAccuracy(stats.overallAccuracy))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.kbTextPrimary)
                    }

                    Text("Overall")
                        .font(.caption)
                        .foregroundColor(.kbTextSecondary)
                }

                Spacer()

                // Stats grid
                VStack(alignment: .leading, spacing: 8) {
                    statRow(label: "Sessions", value: "\(stats.totalSessions)")
                    statRow(label: "Questions", value: "\(stats.totalQuestions)")
                    statRow(label: "Streak", value: "\(stats.currentStreak) days")
                }
            }
            .padding()
            .background(Color.kbBgSecondary)
            .cornerRadius(12)

            // Oral vs Written breakdown (voice-first)
            HStack(spacing: 12) {
                statCard(
                    title: "Oral",
                    value: formatAccuracy(stats.oralAccuracy),
                    color: .kbMastered
                )

                statCard(
                    title: "Written",
                    value: formatAccuracy(stats.writtenAccuracy),
                    color: .kbIntermediate
                )
            }
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.kbTextSecondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.kbTextPrimary)
        }
        .frame(width: 140)
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.kbTextSecondary)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.kbBgSecondary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Question Bank")
                .font(.headline)
                .foregroundColor(.kbTextPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(KBDomain.allCases.prefix(6)) { domain in
                    domainCard(domain)
                }
            }

            // Show more domains
            if KBDomain.allCases.count > 6 {
                DisclosureGroup("More domains") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(Array(KBDomain.allCases.dropFirst(6))) { domain in
                            domainCard(domain)
                        }
                    }
                }
                .foregroundColor(.kbTextSecondary)
            }
        }
    }

    private func domainCard(_ domain: KBDomain) -> some View {
        let count = engine.questionsByDomain[domain] ?? 0

        return VStack(spacing: 4) {
            Image(systemName: domain.icon)
                .font(.title2)
                .foregroundColor(domain.color)

            Text("\(count)")
                .font(.headline)
                .foregroundColor(.kbTextPrimary)

            Text(domain.displayName)
                .font(.caption2)
                .foregroundColor(.kbTextSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.kbBgSecondary)
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func loadQuestions() async {
        do {
            try await engine.loadBundledQuestions()
        } catch {
            // Error is captured in engine.loadError
        }
    }

    private func loadSessions() async {
        do {
            recentSessions = try await store.loadRecent(limit: 10)
            statistics = try await store.calculateStatistics()
        } catch {
            print("[KB] Failed to load sessions: \(error)")
        }
    }

    // MARK: - Formatting Helpers

    private func formatAccuracy(_ accuracy: Double) -> String {
        String(format: "%.0f%%", accuracy * 100)
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    private func startWrittenPractice() {
        let config = KBSessionConfig.quickPractice(
            region: selectedRegion,
            roundType: .written,
            questionCount: writtenQuestionCount,
            timeLimit: writtenTimePerQuestion * Double(writtenQuestionCount),
            domainWeights: domainMix.selectionWeights
        )
        let questions = selectQuestionsForConfig(config)
        writtenSessionViewModel = KBWrittenSessionViewModel(questions: questions, config: config)
        showingWrittenSession = true
    }

    private func startOralPractice() {
        let config = KBSessionConfig.quickPractice(
            region: selectedRegion,
            roundType: .oral,
            questionCount: oralQuestionCount,
            domainWeights: domainMix.selectionWeights
        )
        let questions = selectQuestionsForConfig(config)
        oralSessionViewModel = KBOralSessionViewModel(questions: questions, config: config)
        showingOralSession = true
    }

    /// Select questions based on config and pack selection
    private func selectQuestionsForConfig(_ config: KBSessionConfig) -> [KBQuestion] {
        // If a pack is selected, filter to pack questions first
        if let packId = selectedPackId {
            // Check local packs
            if let pack = localPackStore.localPacks.first(where: { $0.id == packId }),
               let questionIds = pack.questionIds {
                let packQuestionIdSet = Set(questionIds.compactMap { UUID(uuidString: $0) })
                let packQuestions = engine.questions.filter { packQuestionIdSet.contains($0.id) }
                if !packQuestions.isEmpty {
                    return engine.selectWeighted(
                        count: config.questionCount,
                        respectDomainWeights: true,
                        from: packQuestions
                    )
                }
            }
            // For server packs, we'd need to fetch questions (future enhancement)
        }

        // Use standard selection with domain weights
        return engine.selectForSession(config: config)
    }
}

// MARK: - Settings View

struct KBSettingsView: View {
    @Binding var selectedRegion: KBRegion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Competition Region") {
                    ForEach(KBRegion.allCases) { region in
                        Button(action: {
                            selectedRegion = region
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(region.displayName)
                                        .foregroundColor(.kbTextPrimary)
                                    Text(region.config.conferringRuleDescription)
                                        .font(.caption)
                                        .foregroundColor(.kbTextSecondary)
                                }

                                Spacer()

                                if selectedRegion == region {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.kbMastered)
                                }
                            }
                        }
                    }
                }

                Section("Regional Rules") {
                    let config = selectedRegion.config

                    HStack {
                        Text("Written Questions")
                        Spacer()
                        Text("\(config.writtenQuestionCount)")
                            .foregroundColor(.kbTextSecondary)
                    }

                    HStack {
                        Text("Written Time")
                        Spacer()
                        Text(config.writtenTimeLimitDisplay)
                            .foregroundColor(.kbTextSecondary)
                    }

                    HStack {
                        Text("Points per Written")
                        Spacer()
                        Text("\(config.writtenPointsPerCorrect)")
                            .foregroundColor(.kbTextSecondary)
                    }

                    HStack {
                        Text("Conference Time")
                        Spacer()
                        Text(config.conferenceTimeDisplay)
                            .foregroundColor(.kbTextSecondary)
                    }

                    HStack {
                        Text("Verbal Conferring")
                        Spacer()
                        Text(config.verbalConferringAllowed ? "Allowed" : "Not Allowed")
                            .foregroundColor(config.verbalConferringAllowed ? .kbMastered : .kbFocusArea)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct KBDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        KBDashboardView()
    }
}
#endif
