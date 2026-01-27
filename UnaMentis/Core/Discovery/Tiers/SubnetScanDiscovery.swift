// UnaMentis - Subnet Scan Discovery
// Tier 4: Aggressive network scanning for server discovery
//
// Part of Core/Discovery

import Foundation
import Logging

/// Tier 4: Scans the local subnet for UnaMentis servers
public actor SubnetScanDiscovery: DiscoveryTierProtocol {
    public let tier: DiscoveryTier = .subnetScan

    private let ports: [Int]
    private let logger = Logger(label: "com.unamentis.discovery.subnet")
    private var isCancelled = false

    /// Initialize with ports to scan
    /// - Parameter ports: Ports to check (default: UnaMentis gateway, management API, Ollama)
    public init(ports: [Int] = [11400, 8766, 11434]) {
        self.ports = ports
    }

    public func discover(timeout: TimeInterval) async throws -> DiscoveredServer? {
        isCancelled = false

        guard let localIP = getLocalIPAddress() else {
            logger.warning("Could not determine local IP address")
            return nil
        }

        logger.info("Starting subnet scan from \(localIP)")

        // Extract subnet (e.g., 192.168.1.x -> 192.168.1)
        let components = localIP.split(separator: ".")
        guard components.count == 4 else {
            logger.warning("Invalid IP format: \(localIP)")
            return nil
        }

        let subnet = components.prefix(3).joined(separator: ".")

        // Also check localhost and the local IP itself first (quick wins)
        let priorityHosts = ["127.0.0.1", "localhost", localIP]

        // First, try priority hosts
        for host in priorityHosts {
            if isCancelled { throw DiscoveryError.cancelled }

            for port in ports {
                if let server = await probeHost(host: host, port: port, timeout: 0.5) {
                    logger.info("Found server at priority host: \(host):\(port)")
                    return server
                }
            }
        }

        // Then scan the subnet in parallel
        let candidates: [String] = (1...254).map { "\(subnet).\($0)" }
            .filter { !priorityHosts.contains($0) }

        // Calculate per-host timeout based on total timeout
        let perHostTimeout = min(0.3, timeout / Double(candidates.count * ports.count))

        return await withTaskGroup(of: DiscoveredServer?.self) { group in
            for host in candidates {
                if isCancelled { break }

                for port in ports {
                    group.addTask {
                        await self.probeHost(host: host, port: port, timeout: perHostTimeout)
                    }
                }
            }

            // Return first successful probe
            for await result in group {
                if let server = result {
                    group.cancelAll()
                    logger.info("Found server via subnet scan: \(server.host):\(server.port)")
                    return server
                }
            }

            return nil
        }
    }

    public func cancel() async {
        isCancelled = true
    }

    // MARK: - Host Probing

    private func probeHost(host: String, port: Int, timeout: TimeInterval) async -> DiscoveredServer? {
        guard let url = URL(string: "http://\(host):\(port)/health") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Try to extract server name from response
            var serverName = "UnaMentis Server"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let name = json["server_name"] as? String ?? json["name"] as? String {
                serverName = name
            }

            return DiscoveredServer(
                name: serverName,
                host: host,
                port: port,
                discoveryMethod: .subnetScan
            )
        } catch {
            // Host not responding or not a valid server
            return nil
        }
    }

    // MARK: - Network Utilities

    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }
            let addrFamily = interface.ifa_addr.pointee.sa_family

            // Check for IPv4
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)

                // Prefer en0 (WiFi) or en1 (Ethernet)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        socklen_t(0),
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)

                    // Prefer en0 if found
                    if name == "en0" {
                        break
                    }
                }
            }
        }

        return address
    }
}
