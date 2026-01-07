// UnaMentis Watch App
// Entry point for the watchOS companion app

import SwiftUI

@main
struct UnaMentisWatchApp: App {
    @StateObject private var connectivity = WatchConnectivityService.shared
    @StateObject private var runtimeManager = ExtendedRuntimeManager()

    init() {
        // Activate WatchConnectivity on launch
        WatchConnectivityService.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
                .environmentObject(runtimeManager)
        }
    }
}
