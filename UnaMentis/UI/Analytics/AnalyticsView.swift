// UnaMentis - Analytics View
// Telemetry dashboard for session metrics
//
// Part of UI/UX (TDD Section 10)

import SwiftUI

/// Analytics dashboard showing session metrics
///
/// Architecture Note:
/// This view observes TelemetryPublisher (MainActor-isolated) rather than
/// TelemetryEngine (actor) directly. This prevents cross-actor deadlocks
/// when switching between tabs.
public struct AnalyticsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var showingAnalyticsHelp = false

    public init() { }

    /// Access to the telemetry publisher for reactive updates
    private var telemetryPublisher: TelemetryPublisher {
        appState.telemetry.publisher
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Quick stats - observe publisher directly for reactive updates
                    QuickStatsView(metrics: telemetryPublisher.metrics)

                    // Latency metrics
                    LatencyMetricsCard(metrics: telemetryPublisher.metrics)

                    // Cost breakdown
                    CostMetricsCard(metrics: telemetryPublisher.metrics)

                    // Session quality
                    QualityMetricsCard(metrics: telemetryPublisher.metrics)
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .refreshable {
                // Force refresh from actor (for pull-to-refresh)
                await viewModel.refresh(telemetry: appState.telemetry)
            }
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BrandLogo(size: .compact)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingAnalyticsHelp = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .accessibilityLabel("Analytics help")
                        .accessibilityHint("Learn about performance metrics and costs")

                        if let exportURL = viewModel.exportURL {
                            ShareLink(item: exportURL) {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Export metrics")
                        } else {
                            Button {
                                Task {
                                    await viewModel.generateExport(telemetry: appState.telemetry)
                                }
                            } label: {
                                Label("Prepare Export", systemImage: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Prepare metrics export")
                        }
                    }
                }
            }
            #endif
            .sheet(isPresented: $showingAnalyticsHelp) {
                AnalyticsHelpSheet()
            }
        }
    }
}

// MARK: - Quick Stats

struct QuickStatsView: View {
    let metrics: SessionMetrics
    
    var body: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Sessions",
                value: "\(metrics.turnsTotal)",
                icon: "message.fill",
                color: .blue
            )
            
            StatCard(
                title: "Duration",
                value: formatDuration(metrics.duration),
                icon: "clock.fill",
                color: .green
            )
            
            StatCard(
                title: "Cost",
                value: formatCost(metrics.totalCost),
                icon: "dollarsign.circle.fill",
                color: .orange
            )
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private func formatCost(_ cost: Decimal) -> String {
        String(format: "$%.2f", NSDecimalNumber(decimal: cost).doubleValue)
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
                .font(.title3.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

// MARK: - Latency Metrics Card

struct LatencyMetricsCard: View {
    let metrics: SessionMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Latency", systemImage: "timer")
                .font(.headline)
            
            VStack(spacing: 12) {
                LatencyRow(
                    label: "STT",
                    median: metrics.sttLatencies.median,
                    p99: metrics.sttLatencies.percentile(99),
                    target: 0.150
                )
                
                LatencyRow(
                    label: "LLM TTFT",
                    median: metrics.llmLatencies.median,
                    p99: metrics.llmLatencies.percentile(99),
                    target: 0.200
                )
                
                LatencyRow(
                    label: "TTS TTFB",
                    median: metrics.ttsLatencies.median,
                    p99: metrics.ttsLatencies.percentile(99),
                    target: 0.100
                )
                
                Divider()
                
                LatencyRow(
                    label: "End-to-End",
                    median: metrics.e2eLatencies.median,
                    p99: metrics.e2eLatencies.percentile(99),
                    target: 0.500
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

struct LatencyRow: View {
    let label: String
    let median: TimeInterval
    let p99: TimeInterval
    let target: TimeInterval

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)

            Spacer()

            // Median
            VStack(alignment: .trailing) {
                Text(formatMs(median))
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(median <= target ? .green : .orange)
                Text("median")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60)

            // P99
            VStack(alignment: .trailing) {
                Text(formatMs(p99))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(p99 <= target * 2 ? Color.secondary : Color.red)
                Text("p99")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) latency")
        .accessibilityValue("Median \(formatMs(median)), 99th percentile \(formatMs(p99))")
    }

    private func formatMs(_ seconds: TimeInterval) -> String {
        String(format: "%.0fms", seconds * 1000)
    }
}

// MARK: - Cost Metrics Card

struct CostMetricsCard: View {
    let metrics: SessionMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Cost Breakdown", systemImage: "dollarsign.circle")
                .font(.headline)
            
            VStack(spacing: 12) {
                CostRow(label: "STT", cost: metrics.sttCost)
                CostRow(label: "TTS", cost: metrics.ttsCost)
                CostRow(label: "LLM", cost: metrics.llmCost)
                
                Divider()
                
                HStack {
                    Text("Total")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(formatCost(metrics.totalCost))
                        .font(.subheadline.monospacedDigit().bold())
                }
                
                HStack {
                    Text("Cost/Hour")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "$%.2f/hr", metrics.costPerHour))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
    
    private func formatCost(_ cost: Decimal) -> String {
        String(format: "$%.4f", NSDecimalNumber(decimal: cost).doubleValue)
    }
}

struct CostRow: View {
    let label: String
    let cost: Decimal
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(String(format: "$%.4f", NSDecimalNumber(decimal: cost).doubleValue))
                .font(.subheadline.monospacedDigit())
        }
    }
}

// MARK: - Quality Metrics Card

struct QualityMetricsCard: View {
    let metrics: SessionMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Session Quality", systemImage: "chart.bar")
                .font(.headline)
            
            HStack(spacing: 24) {
                QualityItem(
                    label: "Turns",
                    value: "\(metrics.turnsTotal)"
                )
                
                QualityItem(
                    label: "Interruptions",
                    value: "\(metrics.interruptions)"
                )
                
                QualityItem(
                    label: "Throttle Events",
                    value: "\(metrics.thermalThrottleEvents)"
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

struct QualityItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

// MARK: - View Model

/// ViewModel for Analytics view export functionality.
/// Note: Metrics display is handled by observing TelemetryPublisher directly,
/// so this ViewModel only handles export and refresh operations.
@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var exportURL: URL?

    /// Refresh metrics from the telemetry actor (used for pull-to-refresh)
    /// This updates the TelemetryPublisher which the view observes
    func refresh(telemetry: TelemetryEngine) async {
        // Get current metrics from actor - this triggers publisher update
        _ = await telemetry.currentMetrics
    }

    /// Generate export file from telemetry data
    func generateExport(telemetry: TelemetryEngine) async {
        let snapshot = await telemetry.exportMetrics()

        // Convert to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(snapshot)
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "UnaMentis_Session_\(Date().ISO8601Format()).json"
            let fileURL = tempDir.appendingPathComponent(fileName)

            try data.write(to: fileURL)
            exportURL = fileURL
        } catch {
            print("Failed to export metrics: \(error)")
        }
    }
}

// MARK: - Analytics Help Sheet

/// In-app help for the analytics view explaining all metrics
struct AnalyticsHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Overview Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Track your learning progress and system performance. Use this data to optimize your experience and reduce costs.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Latency Section
                Section("Latency Metrics") {
                    AnalyticsHelpRow(
                        icon: "waveform",
                        iconColor: .blue,
                        title: "STT (Speech-to-Text)",
                        description: "Time to convert your speech to text. Target: < 150ms."
                    )
                    AnalyticsHelpRow(
                        icon: "brain",
                        iconColor: .purple,
                        title: "LLM TTFT",
                        description: "Time-To-First-Token. How quickly the AI starts responding. Target: < 200ms."
                    )
                    AnalyticsHelpRow(
                        icon: "speaker.wave.2",
                        iconColor: .green,
                        title: "TTS TTFB",
                        description: "Time-To-First-Byte. How quickly you hear audio. Target: < 100ms."
                    )
                    AnalyticsHelpRow(
                        icon: "timer",
                        iconColor: .orange,
                        title: "End-to-End",
                        description: "Total response time from your speech to hearing the AI. Target: < 500ms median."
                    )
                }

                // Understanding Percentiles
                Section("Median vs P99") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Median: The typical (50th percentile) response time. Half of all responses are faster.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("P99: The 99th percentile. 99% of responses are faster than this value. Shows worst-case performance.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Cost Section
                Section("Cost Breakdown") {
                    AnalyticsHelpRow(
                        icon: "mic.fill",
                        iconColor: .blue,
                        title: "STT Cost",
                        description: "Speech recognition charges. On-device STT is free."
                    )
                    AnalyticsHelpRow(
                        icon: "cpu",
                        iconColor: .purple,
                        title: "LLM Cost",
                        description: "AI model usage. Self-hosted and on-device are free."
                    )
                    AnalyticsHelpRow(
                        icon: "speaker.wave.3.fill",
                        iconColor: .green,
                        title: "TTS Cost",
                        description: "Text-to-speech charges. Apple TTS is free."
                    )
                }

                // Quality Metrics Section
                Section("Quality Metrics") {
                    AnalyticsHelpRow(
                        icon: "message.fill",
                        iconColor: .blue,
                        title: "Turns",
                        description: "Total conversation exchanges across all sessions."
                    )
                    AnalyticsHelpRow(
                        icon: "hand.raised.fill",
                        iconColor: .orange,
                        title: "Interruptions",
                        description: "Times you spoke while the AI was talking. Natural and expected."
                    )
                    AnalyticsHelpRow(
                        icon: "thermometer.medium",
                        iconColor: .red,
                        title: "Throttle Events",
                        description: "Times the device slowed down due to heat. Rest the device if high."
                    )
                }

                // Tips Section
                Section("Optimization Tips") {
                    Label("Use on-device STT for zero-cost speech recognition", systemImage: "iphone")
                        .foregroundStyle(.blue, .primary)
                    Label("Self-host LLM on your Mac for free AI responses", systemImage: "desktopcomputer")
                        .foregroundStyle(.purple, .primary)
                    Label("Use Apple TTS for free voice output", systemImage: "speaker.wave.2")
                        .foregroundStyle(.green, .primary)
                }
            }
            .navigationTitle("Analytics Help")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Helper row for analytics help items
private struct AnalyticsHelpRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
    }
}

// MARK: - Preview

#Preview {
    AnalyticsView()
}

#Preview("Analytics Help") {
    AnalyticsHelpSheet()
}
