// UnaMentis Watch App - Watch Connectivity Service
// Manages communication with iOS companion app

import Foundation
import WatchConnectivity

/// Service managing WatchConnectivity on watchOS side
@MainActor
public final class WatchConnectivityService: NSObject, ObservableObject {

    // MARK: - Singleton

    public static let shared = WatchConnectivityService()

    // MARK: - Published State

    /// Current session state received from iOS
    @Published public private(set) var sessionState: WatchSessionState?

    /// Whether iOS app is currently reachable
    @Published public private(set) var isReachable: Bool = false

    /// Connection status for UI display
    @Published public private(set) var connectionStatus: ConnectionStatus = .disconnected

    // MARK: - Types

    public enum ConnectionStatus: String {
        case disconnected = "Disconnected"
        case connecting = "Connecting"
        case connected = "Connected"
    }

    // MARK: - Private

    private var session: WCSession?

    // MARK: - Initialization

    override private init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
        }
    }

    // MARK: - Activation

    /// Activate the WCSession
    public func activate() {
        guard let session = session else { return }
        session.delegate = self
        session.activate()
        connectionStatus = .connecting
    }

    // MARK: - Commands

    /// Send a command to the iOS app
    public func sendCommand(_ command: SessionCommand) {
        guard let session = session, session.isReachable else {
            print("[Watch] Cannot send command: not reachable")
            return
        }

        let message: [String: Any] = ["command": command.rawValue]

        session.sendMessage(message, replyHandler: { [weak self] response in
            Task { @MainActor in
                self?.handleCommandResponse(response)
            }
        }, errorHandler: { error in
            print("[Watch] Command error: \(error)")
        })
    }

    private func handleCommandResponse(_ response: [String: Any]) {
        guard let data = response["response"] as? Data,
              let commandResponse = try? JSONDecoder().decode(CommandResponse.self, from: data) else {
            return
        }

        if let updatedState = commandResponse.updatedState {
            sessionState = updatedState
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Capture values before entering MainActor to avoid data race
        let reachable = session.isReachable
        let stateData = session.receivedApplicationContext["sessionState"] as? Data
        let decodedState: WatchSessionState?
        if let data = stateData {
            decodedState = try? JSONDecoder().decode(WatchSessionState.self, from: data)
        } else {
            decodedState = nil
        }

        Task { @MainActor in
            if error == nil && activationState == .activated {
                connectionStatus = .connected
                isReachable = reachable

                // Load any existing application context
                if let state = decodedState {
                    sessionState = state
                }
            } else {
                connectionStatus = .disconnected
            }
        }
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        // Capture value before entering MainActor to avoid data race
        let reachable = session.isReachable

        Task { @MainActor in
            isReachable = reachable
            connectionStatus = reachable ? .connected : .disconnected
        }
    }

    nonisolated public func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        // Decode state before entering MainActor to avoid data race
        let decodedState: WatchSessionState?
        if let data = applicationContext["sessionState"] as? Data {
            decodedState = try? JSONDecoder().decode(WatchSessionState.self, from: data)
        } else {
            decodedState = nil
        }

        Task { @MainActor in
            if let state = decodedState {
                sessionState = state
            }
        }
    }
}
