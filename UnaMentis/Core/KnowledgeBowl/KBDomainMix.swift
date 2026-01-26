//
//  KBDomainMix.swift
//  UnaMentis
//
//  Domain mix model for Knowledge Bowl question selection.
//  Supports linked sliders that maintain a sum of 100%.
//

import Foundation

/// Represents a distribution of question weights across Knowledge Bowl domains.
/// The weights always sum to 1.0 (100%).
struct KBDomainMix: Codable, Sendable, Equatable {
    /// Weight for each domain (0.0 to 1.0), always sums to 1.0
    private(set) var weights: [KBDomain: Double]

    /// Minimum weight threshold (below this is considered 0)
    private static let minThreshold: Double = 0.001

    // MARK: - Initialization

    /// Initialize with custom weights (will be normalized to sum to 1.0)
    init(weights: [KBDomain: Double]) {
        var normalizedWeights: [KBDomain: Double] = [:]
        let total = weights.values.reduce(0, +)

        if total > Self.minThreshold {
            for (domain, weight) in weights {
                normalizedWeights[domain] = max(0, weight / total)
            }
        } else {
            // Fallback to equal distribution if all weights are zero
            let equalWeight = 1.0 / Double(KBDomain.allCases.count)
            for domain in KBDomain.allCases {
                normalizedWeights[domain] = equalWeight
            }
        }

        self.weights = normalizedWeights
    }

    /// Default distribution using natural domain weights
    static var `default`: KBDomainMix {
        var weights: [KBDomain: Double] = [:]
        for domain in KBDomain.allCases {
            weights[domain] = domain.weight
        }
        return KBDomainMix(weights: weights)
    }

    /// Equal distribution across all domains
    static var equal: KBDomainMix {
        var weights: [KBDomain: Double] = [:]
        let equalWeight = 1.0 / Double(KBDomain.allCases.count)
        for domain in KBDomain.allCases {
            weights[domain] = equalWeight
        }
        return KBDomainMix(weights: weights)
    }

    // MARK: - Weight Access

    /// Get weight for a domain (returns 0 if not found)
    func weight(for domain: KBDomain) -> Double {
        weights[domain] ?? 0
    }

    /// Get weight as percentage (0-100)
    func percentage(for domain: KBDomain) -> Double {
        (weights[domain] ?? 0) * 100
    }

    // MARK: - Linked Slider Algorithm

    /// Set weight for a domain, adjusting all other domains proportionally to maintain sum of 1.0.
    ///
    /// Algorithm:
    /// 1. Calculate delta = newWeight - currentWeight
    /// 2. Get total weight of other domains that can absorb the change
    /// 3. Distribute delta inversely proportional across others
    /// 4. Clamp each to [0, 1] range
    /// 5. Normalize if clamping caused drift
    mutating func setWeight(for domain: KBDomain, to newWeight: Double) {
        let clampedNew = max(0, min(1, newWeight))
        let oldWeight = weights[domain] ?? 0
        let delta = clampedNew - oldWeight

        // Skip if change is negligible
        guard abs(delta) > Self.minThreshold else { return }

        // Get other domains
        let otherDomains = KBDomain.allCases.filter { $0 != domain }
        let otherTotal = otherDomains.reduce(0.0) { $0 + (weights[$1] ?? 0) }

        // Can't increase if all others are at 0
        if delta > 0 && otherTotal < Self.minThreshold {
            return
        }

        // Distribute delta proportionally across other domains
        if otherTotal > Self.minThreshold {
            for other in otherDomains {
                let currentWeight = weights[other] ?? 0
                let proportion = currentWeight / otherTotal
                let adjustment = -delta * proportion
                let newOtherWeight = max(0, min(1, currentWeight + adjustment))
                weights[other] = newOtherWeight
            }
        } else {
            // All others are at 0, distribute delta equally
            let adjustment = -delta / Double(otherDomains.count)
            for other in otherDomains {
                let currentWeight = weights[other] ?? 0
                weights[other] = max(0, min(1, currentWeight + adjustment))
            }
        }

        weights[domain] = clampedNew

        // Normalize to ensure sum is exactly 1.0
        normalize()
    }

    /// Normalize weights to sum to exactly 1.0
    private mutating func normalize() {
        let total = weights.values.reduce(0, +)

        guard total > Self.minThreshold else {
            // Fallback to equal distribution
            let equalWeight = 1.0 / Double(KBDomain.allCases.count)
            for domain in KBDomain.allCases {
                weights[domain] = equalWeight
            }
            return
        }

        // Scale all weights proportionally
        for domain in KBDomain.allCases {
            if let weight = weights[domain] {
                weights[domain] = weight / total
            }
        }
    }

    /// Reset to default distribution
    mutating func resetToDefault() {
        self = .default
    }

    // MARK: - Conversion

    /// Convert to array of (domain, weight) sorted by weight descending
    var sortedByWeight: [(domain: KBDomain, weight: Double)] {
        weights
            .map { (domain: $0.key, weight: $0.value) }
            .sorted { $0.weight > $1.weight }
    }

    /// Convert to domain filter (domains with non-zero weight)
    var activeDomains: [KBDomain] {
        weights
            .filter { $0.value > Self.minThreshold }
            .map { $0.key }
    }

    /// Convert to weighted selection dictionary (for question engine)
    var selectionWeights: [KBDomain: Double] {
        weights.filter { $0.value > Self.minThreshold }
    }
}

// MARK: - CustomStringConvertible

extension KBDomainMix: CustomStringConvertible {
    var description: String {
        sortedByWeight
            .map { "\($0.domain.displayName): \(Int($0.weight * 100))%" }
            .joined(separator: ", ")
    }
}

// MARK: - Preview Support

#if DEBUG
extension KBDomainMix {
    /// Science-focused mix for testing
    static var scienceFocused: KBDomainMix {
        KBDomainMix(weights: [
            .science: 0.50,
            .technology: 0.20,
            .mathematics: 0.15,
            .history: 0.10,
            .literature: 0.05
        ])
    }

    /// Humanities-focused mix for testing
    static var humanitiesFocused: KBDomainMix {
        KBDomainMix(weights: [
            .literature: 0.25,
            .history: 0.25,
            .arts: 0.20,
            .socialStudies: 0.15,
            .religionPhilosophy: 0.10,
            .language: 0.05
        ])
    }
}
#endif
