//
//  KBTrendChartView.swift
//  UnaMentis
//
//  Trend chart component for Knowledge Bowl analytics.
//  Displays accuracy and performance trends over time.
//

import SwiftUI

// MARK: - Trend Chart View

/// Reusable trend chart component for displaying performance data
struct KBTrendChartView: View {
    let dataPoints: [DataPoint]
    var lineColor: Color = Color.kbExcellent
    var showLabels: Bool = true
    var showGrid: Bool = true
    var animated: Bool = true

    @State private var animationProgress: CGFloat = 0

    struct DataPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let date: Date?

        init(label: String, value: Double, date: Date? = nil) {
            self.label = label
            self.value = value
            self.date = date
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let chartHeight = showLabels ? height - 24 : height

            ZStack {
                // Grid lines
                if showGrid {
                    gridLines(width: width, height: chartHeight)
                }

                // Line chart
                if !dataPoints.isEmpty {
                    lineChart(width: width, height: chartHeight)

                    // Data points
                    dataPointMarkers(width: width, height: chartHeight)
                }

                // X-axis labels
                if showLabels && !dataPoints.isEmpty {
                    xAxisLabels(width: width, yOffset: chartHeight + 8)
                }
            }
        }
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 0.8)) {
                    animationProgress = 1
                }
            } else {
                animationProgress = 1
            }
        }
    }

    // MARK: - Grid Lines

    private func gridLines(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Horizontal lines
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { fraction in
                Path { path in
                    let y = height * (1 - fraction)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
                .stroke(Color(.systemGray5), lineWidth: 1)
            }
        }
    }

    // MARK: - Line Chart

    private func lineChart(width: CGFloat, height: CGFloat) -> some View {
        let normalizedPoints = normalizeDataPoints(width: width, height: height)

        return ZStack {
            // Fill gradient
            Path { path in
                guard normalizedPoints.count >= 2 else { return }

                path.move(to: CGPoint(x: normalizedPoints[0].x, y: height))
                path.addLine(to: normalizedPoints[0])

                for point in normalizedPoints.dropFirst() {
                    path.addLine(to: point)
                }

                path.addLine(to: CGPoint(x: normalizedPoints.last!.x, y: height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [lineColor.opacity(0.3), lineColor.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .mask(
                Rectangle()
                    .frame(width: width * animationProgress)
                    .frame(maxWidth: .infinity, alignment: .leading)
            )

            // Line
            Path { path in
                guard normalizedPoints.count >= 2 else { return }

                path.move(to: normalizedPoints[0])
                for point in normalizedPoints.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .trim(from: 0, to: animationProgress)
            .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: - Data Point Markers

    private func dataPointMarkers(width: CGFloat, height: CGFloat) -> some View {
        let normalizedPoints = normalizeDataPoints(width: width, height: height)

        return ForEach(Array(normalizedPoints.enumerated()), id: \.offset) { index, point in
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(lineColor, lineWidth: 2)
                )
                .position(point)
                .opacity(animationProgress >= CGFloat(index) / CGFloat(max(1, normalizedPoints.count - 1)) ? 1 : 0)
        }
    }

    // MARK: - X-Axis Labels

    private func xAxisLabels(width: CGFloat, yOffset: CGFloat) -> some View {
        let spacing = width / CGFloat(max(1, dataPoints.count - 1))

        return HStack(spacing: 0) {
            ForEach(Array(dataPoints.enumerated()), id: \.offset) { index, point in
                Text(point.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: spacing)
            }
        }
        .frame(width: width)
        .offset(y: yOffset)
    }

    // MARK: - Helpers

    private func normalizeDataPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard dataPoints.count >= 2 else {
            if let first = dataPoints.first {
                return [CGPoint(x: width / 2, y: height * (1 - first.value))]
            }
            return []
        }

        let spacing = width / CGFloat(dataPoints.count - 1)

        return dataPoints.enumerated().map { index, point in
            CGPoint(
                x: CGFloat(index) * spacing,
                y: height * (1 - point.value)
            )
        }
    }
}

// MARK: - Comparison Chart View

/// Side-by-side comparison chart for written vs oral performance
struct KBComparisonChartView: View {
    let writtenData: [KBTrendChartView.DataPoint]
    let oralData: [KBTrendChartView.DataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Legend (voice-first)
            HStack(spacing: 16) {
                legendItem(color: Color.kbStrong, label: "Oral")
                legendItem(color: Color.kbExcellent, label: "Written")
            }

            // Chart
            ZStack {
                if !writtenData.isEmpty {
                    KBTrendChartView(
                        dataPoints: writtenData,
                        lineColor: Color.kbExcellent,
                        showLabels: true,
                        showGrid: true
                    )
                }

                if !oralData.isEmpty {
                    KBTrendChartView(
                        dataPoints: oralData,
                        lineColor: Color.kbStrong,
                        showLabels: false,
                        showGrid: false
                    )
                }
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Bar Chart View

/// Simple bar chart for domain comparison
struct KBBarChartView: View {
    let data: [BarData]
    var barColor: Color = Color.kbExcellent
    var showValues: Bool = true

    struct BarData: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let color: Color?

        init(label: String, value: Double, color: Color? = nil) {
            self.label = label
            self.value = value
            self.color = color
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let barWidth = max(20, (geometry.size.width - CGFloat(data.count - 1) * 8) / CGFloat(data.count))
            let maxHeight = geometry.size.height - (showValues ? 40 : 20)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data) { item in
                    VStack(spacing: 4) {
                        if showValues {
                            Text("\(Int(item.value * 100))%")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }

                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.color ?? barColor)
                            .frame(width: barWidth, height: max(4, CGFloat(item.value) * maxHeight))

                        Text(item.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Circular Progress View

/// Circular progress indicator for overall metrics
struct KBCircularProgressView: View {
    let progress: Double
    let title: String
    let subtitle: String?
    var color: Color = Color.kbExcellent
    var lineWidth: CGFloat = 8

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: lineWidth)

                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // Center text
                VStack(spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.title2.bold())
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Streak Calendar View

/// Mini calendar showing practice streak
struct KBStreakCalendarView: View {
    let streakDays: Set<Date>
    let currentStreak: Int

    private let calendar = Calendar.current
    private let daysToShow = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("\(currentStreak) day streak")
                    .font(.subheadline.bold())
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(recentDays(), id: \.self) { date in
                    let isActive = streakDays.contains { calendar.isDate($0, inSameDayAs: date) }
                    let isToday = calendar.isDateInToday(date)

                    Circle()
                        .fill(isActive ? Color.orange : Color(.systemGray5))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(isToday ? Color.orange : Color.clear, lineWidth: 2)
                        )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func recentDays() -> [Date] {
        let today = Date()
        return (0..<daysToShow).compactMap { offset in
            calendar.date(byAdding: .day, value: -daysToShow + 1 + offset, to: today)
        }
    }
}

// MARK: - Previews

#Preview("Trend Chart") {
    KBTrendChartView(
        dataPoints: [
            .init(label: "Mon", value: 0.65),
            .init(label: "Tue", value: 0.70),
            .init(label: "Wed", value: 0.68),
            .init(label: "Thu", value: 0.75),
            .init(label: "Fri", value: 0.72),
            .init(label: "Sat", value: 0.78),
            .init(label: "Sun", value: 0.80)
        ]
    )
    .frame(height: 150)
    .padding()
}

#Preview("Bar Chart") {
    KBBarChartView(
        data: [
            .init(label: "Sci", value: 0.85, color: .blue),
            .init(label: "Math", value: 0.72, color: .green),
            .init(label: "Hist", value: 0.60, color: .orange),
            .init(label: "Lit", value: 0.45, color: .purple)
        ]
    )
    .frame(height: 150)
    .padding()
}

#Preview("Circular Progress") {
    HStack(spacing: 24) {
        KBCircularProgressView(
            progress: 0.75,
            title: "Accuracy",
            subtitle: "Overall"
        )
        .frame(width: 100, height: 120)

        KBCircularProgressView(
            progress: 0.60,
            title: "Mastery",
            subtitle: "Average",
            color: .orange
        )
        .frame(width: 100, height: 120)
    }
    .padding()
}

#Preview("Streak Calendar") {
    let today = Date()
    let calendar = Calendar.current
    let streakDates: Set<Date> = Set((0..<5).compactMap {
        calendar.date(byAdding: .day, value: -$0, to: today)
    })

    KBStreakCalendarView(
        streakDays: streakDates,
        currentStreak: 5
    )
    .padding()
}
