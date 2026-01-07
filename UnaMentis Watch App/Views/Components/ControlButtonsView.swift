// UnaMentis Watch App - Control Buttons View
// Session control buttons: Mute, Pause/Resume, Stop

import SwiftUI

struct ControlButtonsView: View {
    let state: WatchSessionState
    @EnvironmentObject var connectivity: WatchConnectivityService

    var body: some View {
        HStack(spacing: 12) {
            // Mute Button
            Button {
                connectivity.sendCommand(state.isMuted ? .unmute : .mute)
            } label: {
                Image(systemName: state.isMuted ? "mic.slash.fill" : "mic.fill")
            }
            .buttonStyle(.bordered)
            .tint(state.isMuted ? .red : .gray)

            // Pause/Resume Button
            Button {
                connectivity.sendCommand(state.isPaused ? .resume : .pause)
            } label: {
                Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(.borderedProminent)

            // Stop Button
            Button(role: .destructive) {
                connectivity.sendCommand(.stop)
            } label: {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}

#Preview("Playing") {
    ControlButtonsView(state: WatchSessionState(
        isActive: true,
        isPaused: false,
        isMuted: false,
        curriculumTitle: nil,
        topicTitle: nil,
        sessionMode: .freeform,
        currentSegment: 0,
        totalSegments: 0,
        elapsedSeconds: 0
    ))
    .environmentObject(WatchConnectivityService.shared)
}

#Preview("Paused & Muted") {
    ControlButtonsView(state: WatchSessionState(
        isActive: true,
        isPaused: true,
        isMuted: true,
        curriculumTitle: nil,
        topicTitle: nil,
        sessionMode: .freeform,
        currentSegment: 0,
        totalSegments: 0,
        elapsedSeconds: 0
    ))
    .environmentObject(WatchConnectivityService.shared)
}
