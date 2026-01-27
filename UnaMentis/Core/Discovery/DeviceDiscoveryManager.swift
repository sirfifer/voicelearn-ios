// UnaMentis - Device Discovery Manager
// Orchestrates multi-tier server discovery with fallback hierarchy
//
// Part of Core/Discovery

import Foundation
import Combine
import Logging

/// Orchestrates multi-tier server discovery
@MainActor
public final class DeviceDiscoveryManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = DeviceDiscoveryManager()

    // MARK: - Published State

    @Published public private(set) var state: DiscoveryState = .idle
    @Published public private(set) var discoveredServers: [DiscoveredServer] = []
    @Published public private(set) var connectedServer: DiscoveredServer?
    @Published public private(set) var currentTier: DiscoveryTier?
    @Published public private(set) var progress: Double = 0

    // MARK: - Discovery Tiers

    private let cachedDiscovery = CachedServerDiscovery()
    private let bonjourDiscovery = BonjourDiscovery(serviceType: "_unamentis._tcp")
    private let subnetDiscovery = SubnetScanDiscovery(ports: [11400, 8766, 11434])

    private var tiers: [any DiscoveryTierProtocol] {
        [cachedDiscovery, bonjourDiscovery, subnetDiscovery]
    }

    private let logger = Logger(label: "com.unamentis.discovery.manager")
    private var discoveryTask: Task<DiscoveredServer?, Never>?

    // MARK: - Initialization

    private init() {}

    // MARK: - Discovery

    /// Start automatic server discovery through all tiers
    /// - Returns: The first successfully discovered and validated server, or nil
    @discardableResult
    public func startDiscovery() async -> DiscoveredServer? {
        // Cancel any existing discovery
        await cancelDiscovery()

        state = .discovering
        progress = 0
        discoveredServers = []
        connectedServer = nil

        logger.info("Starting multi-tier discovery")

        let totalTiers = Double(tiers.count)

        for (index, tier) in tiers.enumerated() {
            currentTier = tier.tier
            progress = Double(index) / totalTiers

            logger.info("Trying tier \(index + 1)/\(Int(totalTiers)): \(tier.tier.displayName)")
            state = .tryingTier(tier.tier)

            do {
                if let server = try await tier.discover(timeout: tier.tier.timeout) {
                    // Validate with health check
                    if await validateServer(server) {
                        connectedServer = server
                        state = .connected(server)
                        progress = 1.0

                        // Save to cache for next time
                        await cachedDiscovery.saveToCache(server)

                        logger.info("Connected via \(tier.tier.displayName): \(server.host):\(server.port)")
                        return server
                    } else {
                        logger.debug("Server found but health check failed")
                    }
                }
            } catch DiscoveryError.cancelled {
                logger.info("Discovery cancelled")
                state = .idle
                return nil
            } catch {
                logger.debug("\(tier.tier.displayName) failed: \(error.localizedDescription)")
            }
        }

        // All tiers exhausted
        progress = 1.0
        state = .manualConfigRequired
        logger.info("All discovery tiers exhausted, manual configuration required")
        return nil
    }

    /// Start discovery in the background
    public func startDiscoveryInBackground() {
        discoveryTask = Task {
            await startDiscovery()
        }
    }

    /// Cancel any ongoing discovery
    public func cancelDiscovery() async {
        discoveryTask?.cancel()
        discoveryTask = nil

        for tier in tiers {
            await tier.cancel()
        }

        if state.isDiscovering {
            state = .idle
        }
    }

    /// Retry discovery from the beginning
    @discardableResult
    public func retryDiscovery() async -> DiscoveredServer? {
        await cancelDiscovery()
        return await startDiscovery()
    }

    // MARK: - Manual Configuration

    /// Manually configure a server
    /// - Parameters:
    ///   - host: Server hostname or IP
    ///   - port: Server port
    ///   - name: Optional display name
    /// - Returns: The configured server if validation succeeds
    public func configureManually(host: String, port: Int, name: String? = nil) async -> DiscoveredServer? {
        let server = DiscoveredServer(
            name: name ?? "UnaMentis Server",
            host: host,
            port: port,
            discoveryMethod: .manual
        )

        if await validateServer(server) {
            connectedServer = server
            state = .connected(server)
            await cachedDiscovery.saveToCache(server)
            logger.info("Manual configuration successful: \(host):\(port)")
            return server
        } else {
            state = .failed("Could not connect to \(host):\(port)")
            return nil
        }
    }

    /// Configure from QR code data
    /// - Parameter qrData: JSON data from QR code
    /// - Returns: The configured server if validation succeeds
    public func configureFromQRCode(_ qrData: Data) async -> DiscoveredServer? {
        do {
            let decoder = JSONDecoder()
            let qrInfo = try decoder.decode(QRCodeServerInfo.self, from: qrData)

            let server = DiscoveredServer(
                name: qrInfo.name ?? "UnaMentis Server",
                host: qrInfo.host,
                port: qrInfo.port,
                discoveryMethod: .qrCode
            )

            if await validateServer(server) {
                connectedServer = server
                state = .connected(server)
                await cachedDiscovery.saveToCache(server)
                logger.info("QR code configuration successful: \(qrInfo.host):\(qrInfo.port)")
                return server
            }
        } catch {
            logger.error("Failed to parse QR code: \(error.localizedDescription)")
        }

        state = .failed("Invalid QR code")
        return nil
    }

    // MARK: - Cache Management

    /// Clear the cached server
    public func clearCache() async {
        await cachedDiscovery.clearCache()
        connectedServer = nil
        state = .idle
    }

    // MARK: - Validation

    /// Validate that a server is reachable and healthy
    private func validateServer(_ server: DiscoveredServer) async -> Bool {
        guard let healthURL = server.healthURL else {
            return false
        }

        var request = URLRequest(url: healthURL)
        request.timeoutInterval = 3
        request.httpMethod = "GET"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let isHealthy = (response as? HTTPURLResponse)?.statusCode == 200

            if isHealthy {
                // Add to discovered servers list
                if !discoveredServers.contains(where: { $0.host == server.host && $0.port == server.port }) {
                    discoveredServers.append(server)
                }
            }

            return isHealthy
        } catch {
            logger.debug("Health check failed for \(server.host):\(server.port): \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - QR Code Server Info

/// Server information encoded in QR code
private struct QRCodeServerInfo: Codable {
    let host: String
    let port: Int
    let name: String?
    let timestamp: Date?

    enum CodingKeys: String, CodingKey {
        case host
        case port
        case name
        case timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        host = try container.decode(String.self, forKey: .host)
        port = try container.decode(Int.self, forKey: .port)
        name = try container.decodeIfPresent(String.self, forKey: .name)

        // Handle timestamp as either Date or TimeInterval
        if let date = try? container.decodeIfPresent(Date.self, forKey: .timestamp) {
            timestamp = date
        } else if let interval = try? container.decodeIfPresent(TimeInterval.self, forKey: .timestamp) {
            timestamp = Date(timeIntervalSince1970: interval)
        } else {
            timestamp = nil
        }
    }
}
