// UnaMentis - Analytics View
// Telemetry dashboard for session metrics
//
// Part of UI/UX (TDD Section 10)

import SwiftUI

/// Analytics dashboard showing session metrics
public struct AnalyticsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AnalyticsViewModel()
    
    public init() { }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Quick stats
                    QuickStatsView(metrics: viewModel.currentMetrics)
                    
                    // Latency metrics
                    LatencyMetricsCard(metrics: viewModel.currentMetrics)
                    
                    // Cost breakdown
                    CostMetricsCard(metrics: viewModel.currentMetrics)
                    
                    // Session quality
                    QualityMetricsCard(metrics: viewModel.currentMetrics)
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .refreshable {
                await viewModel.refresh(telemetry: appState.telemetry)
            }
            .task {
                // Initial load
                await viewModel.refresh(telemetry: appState.telemetry)
            }
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let exportURL = viewModel.exportURL {
                        ShareLink(item: exportURL) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            Task {
                                await viewModel.generateExport(telemetry: appState.telemetry)
                            }
                        } label: {
                            Label("Prepare Export", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            #endif
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

struct StatCard: View {
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
    }
}

// MARK: - View Model

@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var currentMetrics = SessionMetrics()
    @Published var exportURL: URL?
    
    func refresh(telemetry: TelemetryEngine) async {
        currentMetrics = await telemetry.currentMetrics
    }
    
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

// MARK: - Preview

#Preview {
    AnalyticsView()
}
