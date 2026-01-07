// UnaMentis Watch App - Extended Runtime Manager
// Keeps app alive during long tutoring sessions for always-on display

import Foundation
import WatchKit

/// Manages extended runtime sessions for always-on display during tutoring
@MainActor
public final class ExtendedRuntimeManager: NSObject, ObservableObject {

    /// Whether an extended runtime session is currently active
    @Published public private(set) var isSessionActive: Bool = false

    private var extendedSession: WKExtendedRuntimeSession?

    override public init() {
        super.init()
    }

    /// Start an extended runtime session for always-on display
    public func startSession() {
        guard extendedSession == nil else {
            print("[ExtendedRuntime] Session already active")
            return
        }

        extendedSession = WKExtendedRuntimeSession()
        extendedSession?.delegate = self
        extendedSession?.start()

        print("[ExtendedRuntime] Session started")
    }

    /// End the extended runtime session
    public func endSession() {
        guard extendedSession != nil else { return }

        extendedSession?.invalidate()
        extendedSession = nil
        isSessionActive = false

        print("[ExtendedRuntime] Session ended")
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate

extension ExtendedRuntimeManager: WKExtendedRuntimeSessionDelegate {

    nonisolated public func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        Task { @MainActor in
            isSessionActive = false
            extendedSession = nil

            let reasonString: String
            switch reason {
            case .none:
                reasonString = "none"
            case .sessionInProgress:
                reasonString = "sessionInProgress"
            case .expired:
                reasonString = "expired"
            case .resignedFrontmost:
                reasonString = "resignedFrontmost"
            case .error:
                reasonString = "error"
            case .suppressedBySystem:
                reasonString = "suppressedBySystem"
            @unknown default:
                reasonString = "unknown"
            }

            print("[ExtendedRuntime] Invalidated: \(reasonString), error: \(error?.localizedDescription ?? "none")")

            // If the session expired due to time limit, we could restart it here
            // for 90+ minute tutoring sessions
            if reason == .expired {
                print("[ExtendedRuntime] Session expired, restarting...")
                startSession()
            }
        }
    }

    nonisolated public func extendedRuntimeSessionDidStart(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        Task { @MainActor in
            isSessionActive = true
            print("[ExtendedRuntime] Session started successfully")
        }
    }

    nonisolated public func extendedRuntimeSessionWillExpire(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        Task { @MainActor in
            print("[ExtendedRuntime] Session will expire soon")
        }
    }
}
