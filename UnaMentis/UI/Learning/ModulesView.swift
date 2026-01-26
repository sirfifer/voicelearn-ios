// UnaMentis - Modules View
// Lists available specialized training modules
//
// Module sources:
// - Bundled modules: Always available, shipped with the app (e.g., Knowledge Bowl)
// - Server modules: Fetched from connected server for additional content
// - Downloaded modules: Previously downloaded from server

import SwiftUI
import Logging

/// Wrapper for module ID to make it Identifiable for fullScreenCover
struct LaunchedModuleIdentifier: Identifiable {
    let id: String
}

/// Represents a bundled module that ships with the app
struct BundledModule: Identifiable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let themeColorHex: String
    let supportsTeamMode: Bool
    let supportsSpeedTraining: Bool
    let supportsCompetitionSim: Bool

    var themeColor: Color {
        Color(hex: themeColorHex) ?? .purple
    }

    /// All bundled modules that ship with the app
    static let all: [BundledModule] = [
        BundledModule(
            id: "knowledge-bowl",
            name: "Knowledge Bowl",
            description: "Academic competition training with 12 domains. Practice for oral rounds, written tests, and full competition simulation.",
            iconName: "brain.head.profile",
            themeColorHex: "#8B5CF6",  // Purple
            supportsTeamMode: true,
            supportsSpeedTraining: true,
            supportsCompetitionSim: true
        )
    ]
}

/// View displaying available specialized training modules
@MainActor
struct ModulesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var moduleService = ModuleService.shared
    @StateObject private var moduleRegistry = ModuleRegistry.shared

    @State private var availableModules: [ModuleSummary] = []
    @State private var isLoading = true
    @State private var serverError: String?  // Renamed from errorMessage to clarify it's server-specific
    @State private var selectedModule: ModuleSummary?
    @State private var selectedBundledModule: BundledModule?
    @State private var showingModuleDetail = false
    @State private var launchedModule: LaunchedModuleIdentifier?

    private static let logger = Logger(label: "com.unamentis.modules.view")

    var body: some View {
        // Always show the module list, even if server is unreachable
        // Bundled modules are always available
        moduleListView
            .task {
                await configureAndFetch()
            }
            .refreshable {
                await fetchModules()
            }
            .sheet(item: $selectedModule) { module in
                NavigationStack {
                    ModuleDetailSheet(
                        module: module,
                        isDownloaded: moduleRegistry.isDownloaded(moduleId: module.id),
                        onDownload: { await downloadModule(module) },
                        onLaunch: { launchModule(module) }
                    )
                }
            }
            .sheet(item: $selectedBundledModule) { module in
                NavigationStack {
                    BundledModuleDetailSheet(
                        module: module,
                        onLaunch: { launchBundledModule(module) }
                    )
                }
            }
            .fullScreenCover(item: $launchedModule) { module in
                NavigationStack {
                    moduleViewForId(module.id)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    launchedModule = nil
                                }
                            }
                        }
                }
            }
    }

    /// Returns the appropriate view for a module ID
    @ViewBuilder
    private func moduleViewForId(_ moduleId: String) -> some View {
        switch moduleId {
        case "knowledge-bowl":
            KBDashboardView()
        default:
            ContentUnavailableView(
                "Module Not Found",
                systemImage: "questionmark.circle",
                description: Text("This module is not available.")
            )
        }
    }

    // MARK: - Views

    @ViewBuilder
    private var moduleListView: some View {
        List {
            // Bundled modules section - ALWAYS shown, no server required
            Section {
                ForEach(BundledModule.all) { module in
                    BundledModuleRow(module: module)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedBundledModule = module
                        }
                }
            } header: {
                Text("Installed")
            } footer: {
                Text("These modules are ready to use without any downloads.")
            }

            // Downloaded modules section
            if !moduleRegistry.allDownloaded.isEmpty {
                Section {
                    ForEach(moduleRegistry.allDownloaded, id: \.id) { module in
                        // Skip if this is a bundled module (avoid duplicates)
                        if !BundledModule.all.contains(where: { $0.id == module.id }) {
                            DownloadedModuleRow(module: module)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // Launch downloaded module
                                    if let summary = availableModules.first(where: { $0.id == module.id }) {
                                        launchModule(summary)
                                    }
                                }
                        }
                    }
                    .onDelete(perform: deleteDownloadedModules)
                } header: {
                    Text("Downloaded")
                } footer: {
                    Text("Tap to start practicing. Swipe to remove.")
                }
            }

            // Available modules from server (only if connected)
            if !availableModules.isEmpty {
                // Filter out bundled modules to avoid duplicates
                let serverOnlyModules = availableModules.filter { serverModule in
                    !BundledModule.all.contains { $0.id == serverModule.id }
                }

                if !serverOnlyModules.isEmpty {
                    Section {
                        ForEach(serverOnlyModules) { module in
                            ServerModuleRow(
                                module: module,
                                isDownloaded: moduleRegistry.isDownloaded(moduleId: module.id)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedModule = module
                            }
                        }
                    } header: {
                        Text("Available on Server")
                    } footer: {
                        Text("Additional modules available for download.")
                    }
                }
            }

            // Server status section
            Section {
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Checking server...")
                            .foregroundStyle(.secondary)
                    }
                } else if let error = serverError {
                    HStack {
                        Image(systemName: "wifi.exclamationmark")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text("Server Unavailable")
                                .font(.subheadline)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Retry") {
                            Task { await fetchModules() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Connected to server")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Server Connection")
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await fetchModules() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
    }

    // MARK: - Data Loading

    private func configureAndFetch() async {
        // Get server IP from UserDefaults (configured in Settings)
        let serverIP = UserDefaults.standard.string(forKey: "primaryServerIP") ?? ""
        let host = serverIP.isEmpty ? "localhost" : serverIP

        do {
            try await moduleService.configure(host: host, port: 8766)
            await fetchModules()
        } catch {
            Self.logger.info("Server not available, continuing with bundled modules only")
            serverError = "Server not configured or unreachable"
            isLoading = false
        }
    }

    private func fetchModules() async {
        isLoading = true
        serverError = nil

        do {
            availableModules = try await moduleService.fetchAvailableModules()
            Self.logger.info("Fetched \(availableModules.count) modules from server")
        } catch {
            Self.logger.info("Could not fetch from server: \(error.localizedDescription)")
            serverError = error.localizedDescription
        }

        isLoading = false
    }

    private func launchBundledModule(_ module: BundledModule) {
        Self.logger.info("Launching bundled module: \(module.name)")
        launchedModule = LaunchedModuleIdentifier(id: module.id)
    }

    private func downloadModule(_ module: ModuleSummary) async {
        do {
            _ = try await moduleService.downloadModule(moduleId: module.id)
            Self.logger.info("Downloaded module: \(module.name)")
        } catch {
            Self.logger.error("Failed to download module: \(error)")
        }
    }

    private func launchModule(_ module: ModuleSummary) {
        Self.logger.info("Launching module: \(module.name)")
        launchedModule = LaunchedModuleIdentifier(id: module.id)
    }

    private func deleteDownloadedModules(at offsets: IndexSet) {
        let downloaded = moduleRegistry.allDownloaded
        for index in offsets {
            let module = downloaded[index]
            moduleRegistry.removeDownloaded(moduleId: module.id)
        }
    }
}

// MARK: - Server Module Row

struct ServerModuleRow: View {
    let module: ModuleSummary
    let isDownloaded: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Module icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(module.themeColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: module.iconName)
                    .font(.title2)
                    .foregroundStyle(module.themeColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(module.name)
                        .font(.headline)

                    if isDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                Text(module.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Feature badges
                HStack(spacing: 8) {
                    if module.supportsTeamMode {
                        FeatureBadge(text: "Team", icon: "person.2.fill", color: .blue)
                    }
                    if module.supportsSpeedTraining {
                        FeatureBadge(text: "Speed", icon: "bolt.fill", color: .orange)
                    }
                    if module.supportsCompetitionSim {
                        FeatureBadge(text: "Competition", icon: "trophy.fill", color: .yellow)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Downloaded Module Row

struct DownloadedModuleRow: View {
    let module: DownloadedModule

    var themeColor: Color {
        Color(hex: module.themeColorHex) ?? .purple
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: module.iconName)
                    .font(.title2)
                    .foregroundStyle(themeColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(module.name)
                    .font(.headline)

                Text(module.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("Ready to practice")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(themeColor)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Feature Badge

struct FeatureBadge: View {
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Module Detail Sheet

struct ModuleDetailSheet: View {
    let module: ModuleSummary
    let isDownloaded: Bool
    let onDownload: () async -> Void
    let onLaunch: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isDownloading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(module.themeColor.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Image(systemName: module.iconName)
                            .font(.largeTitle)
                            .foregroundStyle(module.themeColor)
                    }

                    Text(module.name)
                        .font(.title.bold())

                    Text(module.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

                // Action button - show Start Practicing if downloaded OR in DEBUG mode
                #if DEBUG
                let canLaunch = true  // Allow launch without download in DEBUG
                #else
                let canLaunch = isDownloaded
                #endif

                if canLaunch {
                    Button {
                        onLaunch()
                        dismiss()
                    } label: {
                        Label("Start Practicing", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(module.themeColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    #if DEBUG
                    if !isDownloaded {
                        Text("DEBUG: Launching without download")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    #endif
                } else {
                    Button {
                        Task {
                            isDownloading = true
                            await onDownload()
                            isDownloading = false
                        }
                    } label: {
                        if isDownloading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Label("Download Module", systemImage: "arrow.down.circle")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(module.themeColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(isDownloading)
                    .padding(.horizontal)

                    if let size = module.downloadSize {
                        Text("Download size: \(formatBytes(size))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Features
                VStack(alignment: .leading, spacing: 12) {
                    Text("Features")
                        .font(.headline)

                    if module.supportsTeamMode {
                        FeatureRow(icon: "person.2.fill", title: "Team Mode", description: "Practice with your team in synchronized sessions")
                    }
                    if module.supportsSpeedTraining {
                        FeatureRow(icon: "bolt.fill", title: "Speed Training", description: "Build quick recall with timed drills")
                    }
                    if module.supportsCompetitionSim {
                        FeatureRow(icon: "trophy.fill", title: "Competition Simulation", description: "Practice in realistic competition conditions")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()
            }
        }
        .navigationTitle("Module Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Bundled Module Row

struct BundledModuleRow: View {
    let module: BundledModule

    var body: some View {
        HStack(spacing: 16) {
            // Module icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(module.themeColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: module.iconName)
                    .font(.title2)
                    .foregroundStyle(module.themeColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(module.name)
                        .font(.headline)

                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }

                Text(module.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Feature badges
                HStack(spacing: 8) {
                    if module.supportsTeamMode {
                        FeatureBadge(text: "Team", icon: "person.2.fill", color: .blue)
                    }
                    if module.supportsSpeedTraining {
                        FeatureBadge(text: "Speed", icon: "bolt.fill", color: .orange)
                    }
                    if module.supportsCompetitionSim {
                        FeatureBadge(text: "Competition", icon: "trophy.fill", color: .yellow)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Bundled Module Detail Sheet

struct BundledModuleDetailSheet: View {
    let module: BundledModule
    let onLaunch: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(module.themeColor.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Image(systemName: module.iconName)
                            .font(.largeTitle)
                            .foregroundStyle(module.themeColor)
                    }

                    HStack {
                        Text(module.name)
                            .font(.title.bold())

                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }

                    Text(module.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

                // Launch button - always available for bundled modules
                Button {
                    onLaunch()
                    dismiss()
                } label: {
                    Label("Start Practicing", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(module.themeColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                Text("No download required")
                    .font(.caption)
                    .foregroundStyle(.green)

                // Features
                VStack(alignment: .leading, spacing: 12) {
                    Text("Features")
                        .font(.headline)

                    if module.supportsTeamMode {
                        FeatureRow(
                            icon: "person.2.fill",
                            title: "Team Mode",
                            description: "Practice with your team in synchronized sessions"
                        )
                    }
                    if module.supportsSpeedTraining {
                        FeatureRow(
                            icon: "bolt.fill",
                            title: "Speed Training",
                            description: "Build quick recall with timed drills"
                        )
                    }
                    if module.supportsCompetitionSim {
                        FeatureRow(
                            icon: "trophy.fill",
                            title: "Competition Simulation",
                            description: "Practice in realistic competition conditions"
                        )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()
            }
        }
        .navigationTitle("Module Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ModulesView()
            .environmentObject(AppState())
    }
}
