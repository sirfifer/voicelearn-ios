// UnaMentis - Device Metrics View
// Real-time device health monitoring (CPU, memory, thermal)
//
// Part of Debug & Testing Tools

import SwiftUI

// MARK: - Device Metrics View

/// Displays real-time device health metrics
struct DeviceMetricsView: View {
    @StateObject private var viewModel = DeviceMetricsViewModel()

    var body: some View {
        List {
            // Current Status Section
            Section {
                MetricRow(
                    icon: "cpu",
                    label: "CPU Usage",
                    value: String(format: "%.1f%%", viewModel.currentMetrics.cpuUsage),
                    status: cpuStatus(viewModel.currentMetrics.cpuUsage)
                )

                MetricRow(
                    icon: "memorychip",
                    label: "Memory Used",
                    value: viewModel.currentMetrics.memoryUsedString,
                    status: memoryStatus(viewModel.currentMetrics.memoryUsagePercent)
                )

                MetricRow(
                    icon: "thermometer.medium",
                    label: "Thermal State",
                    value: viewModel.currentMetrics.thermalStateString,
                    status: thermalStatus(viewModel.currentMetrics.thermalState)
                )

                if viewModel.currentMetrics.isUnderStress {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Device is under stress")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            } header: {
                HStack {
                    Text("Current Status")
                    Spacer()
                    if viewModel.isMonitoring {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Live")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Peak Values Section
            Section {
                MetricRow(
                    icon: "arrow.up.right",
                    label: "Peak CPU",
                    value: String(format: "%.1f%%", viewModel.peakMetrics.cpuUsage),
                    status: cpuStatus(viewModel.peakMetrics.cpuUsage)
                )

                MetricRow(
                    icon: "arrow.up.right",
                    label: "Peak Memory",
                    value: viewModel.peakMetrics.memoryUsedString,
                    status: memoryStatus(viewModel.peakMetrics.memoryUsagePercent)
                )

                MetricRow(
                    icon: "flame",
                    label: "Worst Thermal",
                    value: viewModel.peakMetrics.thermalStateString,
                    status: thermalStatus(viewModel.peakMetrics.thermalState)
                )
            } header: {
                Text("Peak Values (Last 60s)")
            }

            // Average Values Section
            Section {
                MetricRow(
                    icon: "equal",
                    label: "Avg CPU",
                    value: String(format: "%.1f%%", viewModel.averageMetrics.cpuUsage),
                    status: cpuStatus(viewModel.averageMetrics.cpuUsage)
                )

                MetricRow(
                    icon: "equal",
                    label: "Avg Memory",
                    value: viewModel.averageMetrics.memoryUsedString,
                    status: memoryStatus(viewModel.averageMetrics.memoryUsagePercent)
                )
            } header: {
                Text("Average Values (Last 60s)")
            }

            // Device Info Section
            Section {
                InfoRow(label: "Total Memory", value: ByteCountFormatter.string(fromByteCount: Int64(viewModel.currentMetrics.memoryTotal), countStyle: .memory))

                InfoRow(label: "Memory Usage", value: String(format: "%.1f%%", viewModel.currentMetrics.memoryUsagePercent))

                InfoRow(label: "Sample Count", value: "\(viewModel.sampleCount)")
            } header: {
                Text("Device Info")
            }

            // Controls Section
            Section {
                Button(action: {
                    if viewModel.isMonitoring {
                        viewModel.stopMonitoring()
                    } else {
                        viewModel.startMonitoring()
                    }
                }) {
                    HStack {
                        Image(systemName: viewModel.isMonitoring ? "stop.circle" : "play.circle")
                        Text(viewModel.isMonitoring ? "Stop Monitoring" : "Start Monitoring")
                    }
                }

                Button("Reset Peak Values") {
                    viewModel.resetPeaks()
                }
                .disabled(!viewModel.isMonitoring)
            }
        }
        .navigationTitle("Device Health")
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    // MARK: - Status Helpers

    private func cpuStatus(_ usage: Double) -> StatusLevel {
        if usage > 80 { return .critical }
        if usage > 50 { return .warning }
        return .good
    }

    private func memoryStatus(_ percent: Double) -> StatusLevel {
        if percent > 85 { return .critical }
        if percent > 70 { return .warning }
        return .good
    }

    private func thermalStatus(_ state: ProcessInfo.ThermalState) -> StatusLevel {
        switch state {
        case .critical: return .critical
        case .serious: return .critical
        case .fair: return .warning
        case .nominal: return .good
        @unknown default: return .unknown
        }
    }
}

// MARK: - Status Level

enum StatusLevel {
    case good, warning, critical, unknown

    var color: Color {
        switch self {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let icon: String
    let label: String
    let value: String
    let status: StatusLevel

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(status.color)
                .frame(width: 24)

            Text(label)

            Spacer()

            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(status.color)
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Device Metrics ViewModel

@MainActor
class DeviceMetricsViewModel: ObservableObject {
    @Published var currentMetrics = DeviceMetrics()
    @Published var peakMetrics = DeviceMetrics()
    @Published var averageMetrics = DeviceMetrics()
    @Published var isMonitoring = false
    @Published var sampleCount = 0

    private var monitoringTask: Task<Void, Never>?
    private var metricsHistory: [DeviceMetrics] = []
    private let maxHistory = 60

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        metricsHistory.removeAll()
        sampleCount = 0

        monitoringTask = Task {
            while !Task.isCancelled && isMonitoring {
                // Sample current metrics
                let sample = DeviceMetricsCollector.sample()
                currentMetrics = sample

                // Store in history
                metricsHistory.append(sample)
                if metricsHistory.count > maxHistory {
                    metricsHistory.removeFirst()
                }
                sampleCount = metricsHistory.count

                // Calculate peak
                updatePeakMetrics()

                // Calculate average
                updateAverageMetrics()

                // Wait 1 second
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    func resetPeaks() {
        metricsHistory.removeAll()
        sampleCount = 0
        peakMetrics = DeviceMetrics()
        averageMetrics = DeviceMetrics()
    }

    private func updatePeakMetrics() {
        guard !metricsHistory.isEmpty else { return }

        let peakCPU = metricsHistory.map { $0.cpuUsage }.max() ?? 0
        let peakMemory = metricsHistory.map { $0.memoryUsed }.max() ?? 0
        let worstThermal = metricsHistory.map { $0.thermalState.rawValue }.max() ?? 0

        peakMetrics = DeviceMetrics(
            cpuUsage: peakCPU,
            memoryUsed: peakMemory,
            memoryTotal: metricsHistory.first?.memoryTotal ?? 0,
            thermalState: ProcessInfo.ThermalState(rawValue: worstThermal) ?? .nominal,
            timestamp: Date()
        )
    }

    private func updateAverageMetrics() {
        guard !metricsHistory.isEmpty else { return }

        let avgCPU = metricsHistory.map { $0.cpuUsage }.reduce(0, +) / Double(metricsHistory.count)
        let avgMemory = metricsHistory.map { $0.memoryUsed }.reduce(0, +) / UInt64(metricsHistory.count)

        averageMetrics = DeviceMetrics(
            cpuUsage: avgCPU,
            memoryUsed: avgMemory,
            memoryTotal: metricsHistory.first?.memoryTotal ?? 0,
            thermalState: .nominal,
            timestamp: Date()
        )
    }
}

#Preview {
    NavigationStack {
        DeviceMetricsView()
    }
}
