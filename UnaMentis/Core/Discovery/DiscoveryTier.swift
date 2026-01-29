// UnaMentis - Discovery Tier Protocol
// Defines the interface for discovery tiers in the fallback hierarchy
//
// Part of Core/Discovery

import Foundation

// MARK: - Discovery Tier Enum

/// Discovery tiers in order of preference
public enum DiscoveryTier: Int, CaseIterable, Sendable {
    case cached = 1
    case bonjour = 2
    case multipeer = 3
    case subnetScan = 4

    /// Display name for UI
    public var displayName: String {
        switch self {
        case .cached: return "Checking saved server"
        case .bonjour: return "Scanning local network"
        case .multipeer: return "Trying peer-to-peer"
        case .subnetScan: return "Deep network scan"
        }
    }

    /// Timeout for this tier in seconds
    public var timeout: TimeInterval {
        switch self {
        case .cached: return 2
        case .bonjour: return 3
        case .multipeer: return 5
        case .subnetScan: return 10
        }
    }

    /// Priority for sorting (lower is better)
    public var priority: Int {
        rawValue
    }
}

// MARK: - Discovery Tier Protocol

/// Protocol for implementing a discovery tier
public protocol DiscoveryTierProtocol: Sendable {
    /// The tier this implementation represents
    var tier: DiscoveryTier { get }

    /// Attempt to discover servers using this method
    /// - Parameter timeout: Maximum time to wait for discovery
    /// - Returns: A discovered server, or nil if not found
    func discover(timeout: TimeInterval) async throws -> DiscoveredServer?

    /// Stop any ongoing discovery
    func cancel() async
}

// MARK: - Discovery Error

/// Errors that can occur during discovery
public enum DiscoveryError: Error, LocalizedError, Sendable {
    case timeout
    case networkUnavailable
    case invalidResponse
    case healthCheckFailed(String)
    case cancelled
    case tierNotAvailable(DiscoveryTier)

    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "Discovery timed out"
        case .networkUnavailable:
            return "Network is unavailable"
        case .invalidResponse:
            return "Invalid response from server"
        case .healthCheckFailed(let reason):
            return "Health check failed: \(reason)"
        case .cancelled:
            return "Discovery was cancelled"
        case .tierNotAvailable(let tier):
            return "\(tier.displayName) is not available"
        }
    }
}
