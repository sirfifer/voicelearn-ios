// UnaMentis Watch App - Active Session View
// Displays session progress and controls

import SwiftUI

struct ActiveSessionView: View {
    let state: WatchSessionState
    @EnvironmentObject var connectivity: WatchConnectivityService

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header: Context
                SessionHeaderView(state: state)

                // Progress Ring
                ProgressRingView(progress: state.progressPercentage)
                    .frame(width: 100, height: 100)

                // Control Buttons
                ControlButtonsView(state: state)

                // Connection status
                if !connectivity.isReachable {
                    Label("Reconnecting...", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Session Header

struct SessionHeaderView: View {
    let state: WatchSessionState

    var body: some View {
        VStack(spacing: 2) {
            if let curriculum = state.curriculumTitle {
                Text(curriculum)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(state.topicTitle ?? state.sessionMode.displayName)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if state.isPaused {
                Label("Paused", systemImage: "pause.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 8)
    }
}

#Preview("Active Session") {
    ActiveSessionView(state: WatchSessionState(
        isActive: true,
        isPaused: false,
        isMuted: false,
        curriculumTitle: "Calculus 101",
        topicTitle: "Introduction to Derivatives",
        sessionMode: .curriculum,
        currentSegment: 5,
        totalSegments: 20,
        elapsedSeconds: 300
    ))
    .environmentObject(WatchConnectivityService.shared)
}
