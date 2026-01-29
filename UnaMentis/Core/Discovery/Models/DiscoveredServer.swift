// UnaMentis - Discovered Server Model
// Represents a server found through automatic discovery
//
// Part of Core/Discovery

import Foundation

/// A server discovered through automatic discovery
public struct DiscoveredServer: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let host: String
    public let port: Int
    public let discoveryMethod: DiscoveryMethod
    public let timestamp: Date
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int,
        discoveryMethod: DiscoveryMethod,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.discoveryMethod = discoveryMethod
        self.timestamp = timestamp
        self.metadata = metadata
    }

    /// Full URL to the server
    public var baseURL: URL? {
        URL(string: "http://\(host):\(port)")
    }

    /// URL for health check endpoint
    public var healthURL: URL? {
        baseURL?.appendingPathComponent("health")
    }
}

// MARK: - Discovery Method

/// How a server was discovered
public enum DiscoveryMethod: String, Codable, Sendable {
    case cached = "cached"
    case bonjour = "bonjour"
    case multipeer = "multipeer"
    case subnetScan = "subnet_scan"
    case manual = "manual"
    case qrCode = "qr_code"

    public var displayName: String {
        switch self {
        case .cached: return "Cached"
        case .bonjour: return "Bonjour"
        case .multipeer: return "Peer-to-Peer"
        case .subnetScan: return "Network Scan"
        case .manual: return "Manual"
        case .qrCode: return "QR Code"
        }
    }
}

// MARK: - Discovery State

/// Current state of the discovery process
public enum DiscoveryState: Equatable, Sendable {
    case idle
    case discovering
    case tryingTier(DiscoveryTier)
    case connected(DiscoveredServer)
    case manualConfigRequired
    case failed(String)

    public var isDiscovering: Bool {
        switch self {
        case .discovering, .tryingTier:
            return true
        default:
            return false
        }
    }

    public var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}
