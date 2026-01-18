// WebSocketClient.swift
// Real-time event streaming from USM Core via WebSocket

import Foundation

/// WebSocket client for receiving real-time service events from USM Core
@MainActor
final class WebSocketClient: ObservableObject {
    private var webSocket: URLSessionWebSocketTask?
    private let session: URLSession
    private let url: URL

    @Published private(set) var isConnected = false
    @Published private(set) var lastError: String?

    /// Callback for received events
    var onEvent: ((ServiceEvent) -> Void)?

    /// Callback for connection state changes
    var onConnectionChange: ((Bool) -> Void)?

    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private var reconnectTask: Task<Void, Never>?

    init(port: Int = 8787) {
        self.url = URL(string: "ws://127.0.0.1:\(port)/ws")!
        self.session = URLSession(configuration: .default)
    }

    deinit {
        reconnectTask?.cancel()
        // Cancel websocket directly - can't call @MainActor isolated disconnect() from deinit
        webSocket?.cancel(with: .goingAway, reason: nil)
    }

    /// Connect to the USM Core WebSocket endpoint
    func connect() {
        guard webSocket == nil else { return }

        print("[WebSocket] Connecting to \(url)")
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()

        isConnected = true
        reconnectAttempts = 0
        lastError = nil
        onConnectionChange?(true)

        receiveMessage()
    }

    /// Disconnect from the WebSocket
    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil

        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil

        if isConnected {
            isConnected = false
            onConnectionChange?(false)
            print("[WebSocket] Disconnected")
        }
    }

    /// Attempt to reconnect with exponential backoff
    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            lastError = "Max reconnection attempts reached"
            print("[WebSocket] \(lastError!)")
            return
        }

        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0) // Max 30 seconds

        print("[WebSocket] Reconnecting in \(delay)s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")

        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            connect()
        }
    }

    /// Receive messages from the WebSocket
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor in
                self?.handleReceiveResult(result)
            }
        }
    }

    private func handleReceiveResult(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        switch result {
        case .success(let message):
            switch message {
            case .string(let text):
                parseAndDispatch(text)
            case .data(let data):
                if let text = String(data: data, encoding: .utf8) {
                    parseAndDispatch(text)
                }
            @unknown default:
                break
            }
            // Continue listening for more messages
            receiveMessage()

        case .failure(let error):
            print("[WebSocket] Receive error: \(error.localizedDescription)")
            lastError = error.localizedDescription
            isConnected = false
            webSocket = nil
            onConnectionChange?(false)

            // Attempt reconnection
            scheduleReconnect()
        }
    }

    /// Parse JSON message and dispatch to handler
    private func parseAndDispatch(_ json: String) {
        guard let data = json.data(using: .utf8) else {
            print("[WebSocket] Invalid UTF-8 in message")
            return
        }

        do {
            let event = try JSONDecoder().decode(ServiceEvent.self, from: data)
            onEvent?(event)
        } catch {
            // Try to parse as initial state message (array of instances)
            if let initialState = try? JSONDecoder().decode(InitialStateMessage.self, from: data) {
                print("[WebSocket] Received initial state with \(initialState.instances.count) instances")
                // Initial state is handled differently, just log it
                return
            }
            print("[WebSocket] Failed to decode event: \(error)")
        }
    }

    /// Send a ping to check connection health
    func ping() {
        webSocket?.sendPing { [weak self] error in
            if let error = error {
                Task { @MainActor in
                    print("[WebSocket] Ping failed: \(error.localizedDescription)")
                    self?.lastError = "Ping failed"
                    self?.isConnected = false
                }
            }
        }
    }
}

// MARK: - Initial State Message

/// Message sent by USM Core when WebSocket first connects
private struct InitialStateMessage: Codable {
    let type: String
    let instances: [InstanceState]

    struct InstanceState: Codable {
        let id: String
        let templateId: String
        let port: Int
        let status: Int

        enum CodingKeys: String, CodingKey {
            case id
            case templateId = "template_id"
            case port
            case status
        }
    }
}
