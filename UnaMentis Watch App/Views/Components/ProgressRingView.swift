// UnaMentis Watch App - Progress Ring View
// Circular gauge showing session progress

import SwiftUI

struct ProgressRingView: View {
    let progress: Double

    var body: some View {
        Gauge(value: progress, in: 0...1) {
            Text("Progress")
        } currentValueLabel: {
            Text("\(Int(progress * 100))%")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(progressGradient)
    }

    private var progressGradient: Gradient {
        Gradient(colors: [.blue, .cyan])
    }
}

#Preview("25%") {
    ProgressRingView(progress: 0.25)
}

#Preview("75%") {
    ProgressRingView(progress: 0.75)
}

#Preview("100%") {
    ProgressRingView(progress: 1.0)
}
