// UnaMentis - Watch Connectivity Service (iOS)
// Manages communication between iOS app and Apple Watch
//
// Part of Core Components

import Foundation
import WatchConnectivity
import Combine
import Logging

/// Service managing WatchConnectivity on iOS side
/// Uses @MainActor for thread safety with SwiftUI
@MainActor
public final class WatchConnectivityService: NSObject, ObservableObject {

    // MARK: - Singleton

    public static let shared = WatchConnectivityService()

    // MARK: - Published State

    /// Whether Watch is paired and app installed
    @Published public private(set) var isPaired: Bool = false

    /// Whether Watch is currently reachable for immediate messaging
    @Published public private(set) var isReachable: Bool = false

    /// Whether WatchConnectivity is supported on this device
    @Published public private(set) var isSupported: Bool = false

    // MARK: - Private

    private let logger = Logger(label: "com.unamentis.watch.connectivity")
    private var session: WCSession?
    private var commandHandler: (@Sendable (SessionCommand) async -> CommandResponse)?

    // MARK: - Initialization

    override private init() {
        super.init()

        isSupported = WCSession.isSupported()

        if isSupported {
            session = WCSession.default
        }

        logger.info("WatchConnectivityService initialized, supported: \(isSupported)")
    }

    // MARK: - Activation

    /// Activate the WCSession (call early in app lifecycle)
    public func activateSession() {
        guard isSupported, let session = session else {
            logger.warning("WatchConnectivity not supported or session nil")
            return
        }

        session.delegate = self
        session.activate()
        logger.info("WCSession activation requested")
    }

    // MARK: - Command Handler Binding

    /// Set the handler for commands received from Watch
    public func setCommandHandler(_ handler: @escaping @Sendable (SessionCommand) async -> CommandResponse) {
        commandHandler = handler
        logger.info("Command handler set")
    }

    /// Clear the command handler
    public func clearCommandHandler() {
        commandHandler = nil
        logger.info("Command handler cleared")
    }

    // MARK: - State Sync (iOS -> Watch)

    /// Sync session state to Watch via Application Context
    public func syncSessionState(_ state: WatchSessionState) {
        guard isSupported, let session = session, session.activationState == .activated else {
            logger.debug("Cannot sync: session not activated")
            return
        }

        do {
            let data = try JSONEncoder().encode(state)
            let context: [String: Any] = ["sessionState": data]
            try session.updateApplicationContext(context)
            logger.debug("Synced state to Watch: active=\(state.isActive), progress=\(state.progressPercentage)")
        } catch {
            logger.error("Failed to sync state: \(error)")
        }
    }

    // MARK: - Command Handling (Watch -> iOS)

    /// Handle command received from Watch
    nonisolated private func handleCommand(_ command: SessionCommand) async -> CommandResponse {
        await MainActor.run {
            logger.info("Handling Watch command: \(command.commandDescription)")
        }

        if let handler = await MainActor.run(body: { commandHandler }) {
            return await handler(command)
        } else {
            await MainActor.run {
                logger.warning("No command handler set for command: \(command.commandDescription)")
            }
            return CommandResponse(
                command: command,
                success: false,
                error: "No active session"
            )
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: @preconcurrency WCSessionDelegate {

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Capture values before entering MainActor to avoid data race
        let paired = session.isPaired
        let reachable = session.isReachable

        Task { @MainActor in
            if let error = error {
                logger.error("WCSession activation failed: \(error)")
            } else {
                logger.info("WCSession activated: \(activationState.rawValue)")
                isPaired = paired
                isReachable = reachable
            }
        }
    }

    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            logger.info("WCSession became inactive")
        }
    }

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for quick switching between watches
        session.activate()

        Task { @MainActor in
            logger.info("WCSession deactivated and reactivated")
        }
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        // Capture value before entering MainActor to avoid data race
        let reachable = session.isReachable

        Task { @MainActor in
            isReachable = reachable
            logger.info("Reachability changed: \(reachable)")
        }
    }

    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        // Extract command before entering Task to avoid data race
        guard let commandString = message["command"] as? String,
              let command = SessionCommand(rawValue: commandString) else {
            replyHandler(["error": "Invalid command"])
            return
        }

        // Wrap replyHandler in unchecked Sendable for async context
        let replyBox = UncheckedSendableBox(replyHandler)

        Task {
            let response = await handleCommand(command)

            do {
                let data = try JSONEncoder().encode(response)
                replyBox.value(["response": data])
            } catch {
                replyBox.value(["error": error.localizedDescription])
            }
        }
    }
}

/// Wrapper to make non-Sendable closures usable in async contexts
/// Use with caution - only when you can ensure thread safety manually
private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
