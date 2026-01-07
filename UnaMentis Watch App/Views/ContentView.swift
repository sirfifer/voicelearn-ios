// UnaMentis Watch App - Content View
// Root view showing active session or idle state

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var connectivity: WatchConnectivityService
    @EnvironmentObject var runtimeManager: ExtendedRuntimeManager

    // Debug mode: set to true to preview ActiveSessionView in simulator
    #if DEBUG
    @State private var showDebugSession = false
    #endif

    var body: some View {
        Group {
            #if DEBUG
            if showDebugSession {
                ActiveSessionView(state: WatchSessionState.debugMock)
                    .onTapGesture(count: 3) {
                        showDebugSession = false
                    }
            } else if let state = connectivity.sessionState, state.isActive {
                ActiveSessionView(state: state)
                    .onAppear {
                        runtimeManager.startSession()
                    }
            } else {
                IdleView()
                    .onAppear {
                        runtimeManager.endSession()
                    }
                    .onTapGesture(count: 3) {
                        showDebugSession = true
                    }
            }
            #else
            if let state = connectivity.sessionState, state.isActive {
                ActiveSessionView(state: state)
                    .onAppear {
                        runtimeManager.startSession()
                    }
            } else {
                IdleView()
                    .onAppear {
                        runtimeManager.endSession()
                    }
            }
            #endif
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityService.shared)
        .environmentObject(ExtendedRuntimeManager())
}
