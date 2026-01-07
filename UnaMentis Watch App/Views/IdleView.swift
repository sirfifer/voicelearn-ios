// UnaMentis Watch App - Idle View
// Shown when no tutoring session is active

import SwiftUI

struct IdleView: View {
    @EnvironmentObject var connectivity: WatchConnectivityService

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("UnaMentis")
                .font(.headline)

            Text("No Active Session")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !connectivity.isReachable {
                Label("iPhone Not Reachable", systemImage: "iphone.slash")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
    }
}

#Preview {
    IdleView()
        .environmentObject(WatchConnectivityService.shared)
}
