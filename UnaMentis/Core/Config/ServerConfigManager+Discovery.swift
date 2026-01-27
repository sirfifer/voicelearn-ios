// UnaMentis - ServerConfigManager Discovery Extension
// Integrates DeviceDiscoveryManager with ServerConfigManager
//
// Part of Core/Config

import Foundation

// MARK: - Discovery Integration

extension ServerConfigManager {

    /// Connect using automatic discovery, falling back through all tiers
    /// This is the recommended way to establish initial server connection
    /// - Returns: The ServerConfig for the discovered server, or nil if all tiers fail
    @MainActor
    public func connectWithAutoDiscovery() async -> ServerConfig? {
        let discoveryManager = DeviceDiscoveryManager.shared

        // Start multi-tier discovery
        if let discovered = await discoveryManager.startDiscovery() {
            // Convert DiscoveredServer to ServerConfig and add
            let config = ServerConfig(
                name: discovered.name,
                host: discovered.host,
                port: discovered.port,
                serverType: .unamentisGateway,
                discoveredServices: [],
                discoveredModels: [],
                discoveredVoices: []
            )

            // Add to managed servers (actor-isolated, so use await)
            _ = await addServer(config)

            // Trigger capability discovery in background
            Task {
                _ = await discoverCapabilities(host: discovered.host)
            }

            return config
        }

        return nil
    }

    /// Check if automatic discovery found a server
    @MainActor
    public var hasAutoDiscoveredServer: Bool {
        DeviceDiscoveryManager.shared.connectedServer != nil
    }

    /// Get the auto-discovered server as a ServerConfig
    @MainActor
    public var autoDiscoveredServerConfig: ServerConfig? {
        guard let discovered = DeviceDiscoveryManager.shared.connectedServer else {
            return nil
        }

        return ServerConfig(
            name: discovered.name,
            host: discovered.host,
            port: discovered.port,
            serverType: .unamentisGateway
        )
    }

    /// Retry automatic discovery
    @MainActor
    @discardableResult
    public func retryAutoDiscovery() async -> ServerConfig? {
        await DeviceDiscoveryManager.shared.retryDiscovery()
        return autoDiscoveredServerConfig
    }

    /// Configure server manually (bypassing automatic discovery)
    /// - Parameters:
    ///   - host: Server hostname or IP address
    ///   - port: Server port
    ///   - name: Optional display name
    /// - Returns: The ServerConfig if validation succeeds
    @MainActor
    public func configureServerManually(host: String, port: Int, name: String? = nil) async -> ServerConfig? {
        let discoveryManager = DeviceDiscoveryManager.shared

        if let discovered = await discoveryManager.configureManually(host: host, port: port, name: name) {
            let config = ServerConfig(
                name: discovered.name,
                host: discovered.host,
                port: discovered.port,
                serverType: .unamentisGateway
            )

            _ = await addServer(config)
            return config
        }

        return nil
    }

    /// Configure server from QR code scan
    /// - Parameter qrData: JSON data scanned from QR code
    /// - Returns: The ServerConfig if validation succeeds
    @MainActor
    public func configureServerFromQRCode(_ qrData: Data) async -> ServerConfig? {
        let discoveryManager = DeviceDiscoveryManager.shared

        if let discovered = await discoveryManager.configureFromQRCode(qrData) {
            let config = ServerConfig(
                name: discovered.name,
                host: discovered.host,
                port: discovered.port,
                serverType: .unamentisGateway
            )

            _ = await addServer(config)
            return config
        }

        return nil
    }
}

// MARK: - Discovery State Observation

extension ServerConfigManager {

    /// Current discovery state
    @MainActor
    public var discoveryState: DiscoveryState {
        DeviceDiscoveryManager.shared.state
    }

    /// Whether discovery is currently in progress
    @MainActor
    public var isDiscoveryInProgress: Bool {
        DeviceDiscoveryManager.shared.state.isDiscovering
    }

    /// Current discovery tier being attempted
    @MainActor
    public var currentDiscoveryTier: DiscoveryTier? {
        DeviceDiscoveryManager.shared.currentTier
    }

    /// Discovery progress (0.0 to 1.0)
    @MainActor
    public var discoveryProgress: Double {
        DeviceDiscoveryManager.shared.progress
    }
}
