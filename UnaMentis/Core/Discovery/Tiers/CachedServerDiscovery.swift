// UnaMentis - Cached Server Discovery
// Tier 1: Check for previously connected server
//
// Part of Core/Discovery

import Foundation
import Logging

/// Tier 1: Attempts to reconnect to the last known good server
public actor CachedServerDiscovery: DiscoveryTierProtocol {
    public let tier: DiscoveryTier = .cached

    private let logger = Logger(label: "com.unamentis.discovery.cached")
    private let userDefaults: UserDefaults
    private var isCancelled = false

    // UserDefaults keys
    private enum Keys {
        static let host = "discovery.cached.host"
        static let port = "discovery.cached.port"
        static let name = "discovery.cached.name"
        static let timestamp = "discovery.cached.timestamp"
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func discover(timeout: TimeInterval) async throws -> DiscoveredServer? {
        isCancelled = false

        guard let host = userDefaults.string(forKey: Keys.host),
              !host.isEmpty else {
            logger.debug("No cached server found")
            return nil
        }

        let port = userDefaults.integer(forKey: Keys.port)
        guard port > 0 else {
            logger.debug("Invalid cached port")
            return nil
        }

        let name = userDefaults.string(forKey: Keys.name) ?? "Cached Server"

        logger.info("Found cached server: \(host):\(port)")

        // Create the server object
        let server = DiscoveredServer(
            name: name,
            host: host,
            port: port,
            discoveryMethod: .cached,
            timestamp: userDefaults.object(forKey: Keys.timestamp) as? Date ?? Date()
        )

        // Verify it's still reachable with health check
        if isCancelled { throw DiscoveryError.cancelled }

        do {
            let isHealthy = try await performHealthCheck(server: server, timeout: timeout)
            if isHealthy {
                logger.info("Cached server is healthy")
                return server
            } else {
                logger.info("Cached server health check failed")
                return nil
            }
        } catch {
            logger.debug("Health check error: \(error.localizedDescription)")
            return nil
        }
    }

    public func cancel() async {
        isCancelled = true
    }

    // MARK: - Cache Management

    /// Save a server to the cache for future reconnection
    public func saveToCache(_ server: DiscoveredServer) {
        userDefaults.set(server.host, forKey: Keys.host)
        userDefaults.set(server.port, forKey: Keys.port)
        userDefaults.set(server.name, forKey: Keys.name)
        userDefaults.set(Date(), forKey: Keys.timestamp)
        logger.info("Saved server to cache: \(server.host):\(server.port)")
    }

    /// Clear the cached server
    public func clearCache() {
        userDefaults.removeObject(forKey: Keys.host)
        userDefaults.removeObject(forKey: Keys.port)
        userDefaults.removeObject(forKey: Keys.name)
        userDefaults.removeObject(forKey: Keys.timestamp)
        logger.info("Cleared cached server")
    }

    // MARK: - Health Check

    private func performHealthCheck(server: DiscoveredServer, timeout: TimeInterval) async throws -> Bool {
        guard let healthURL = server.healthURL else {
            return false
        }

        var request = URLRequest(url: healthURL)
        request.timeoutInterval = timeout
        request.httpMethod = "GET"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return httpResponse.statusCode == 200
    }
}
