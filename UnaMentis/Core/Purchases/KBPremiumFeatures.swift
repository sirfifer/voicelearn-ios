//
//  KBPremiumFeatures.swift
//  UnaMentis
//
//  DEPRECATED: This file has been replaced by KBFeatureFlags.swift
//
//  UnaMentis is an open-source project. Features are controlled by server administrators
//  via feature flags (KBFeatureFlags), not premium subscriptions.
//  This file is kept for reference only and should not be used in new code.
//
//  See: UnaMentis/Core/Purchases/KBFeatureFlags.swift
//

import Foundation
import OSLog

// MARK: - Premium Features

/// Premium feature management for Knowledge Bowl
actor KBPremiumFeatures {
    private let logger = Logger(subsystem: "com.unamentis", category: "KBPremiumFeatures")

    // MARK: - Feature Flags

    /// Premium features available for Knowledge Bowl
    enum Feature: String, Sendable {
        case llmValidation = "kb_llm_validation"
        case customDictionaries = "kb_custom_dictionaries"
        case advancedAnalytics = "kb_advanced_analytics"
        case offlineMode = "kb_offline_mode"

        var displayName: String {
            switch self {
            case .llmValidation:
                return "LLM Answer Validation"
            case .customDictionaries:
                return "Custom Synonym Dictionaries"
            case .advancedAnalytics:
                return "Advanced Performance Analytics"
            case .offlineMode:
                return "Full Offline Mode"
            }
        }

        var description: String {
            switch self {
            case .llmValidation:
                return "Expert-level answer validation using a small language model. Achieves 95-98% accuracy."
            case .customDictionaries:
                return "Create and manage custom synonym dictionaries for specialized topics."
            case .advancedAnalytics:
                return "Detailed performance metrics and learning insights."
            case .offlineMode:
                return "Use all features without an internet connection."
            }
        }
    }

    // MARK: - Subscription Status

    /// Current subscription status
    enum SubscriptionStatus: Sendable {
        case free
        case premium
        case premiumPlus
        case lifetime

        var displayName: String {
            switch self {
            case .free:
                return "Free"
            case .premium:
                return "Premium"
            case .premiumPlus:
                return "Premium Plus"
            case .lifetime:
                return "Lifetime"
            }
        }
    }

    private var subscriptionStatus: SubscriptionStatus = .free

    // MARK: - Public API

    /// Get current subscription status
    nonisolated func currentStatus() async -> SubscriptionStatus {
        await subscriptionStatus
    }

    /// Check if a feature is available
    /// - Parameter feature: Feature to check
    /// - Returns: True if feature is available
    nonisolated func isFeatureAvailable(_ feature: Feature) async -> Bool {
        let status = await currentStatus()

        switch feature {
        case .llmValidation:
            // Requires premium or higher
            return status == .premium || status == .premiumPlus || status == .lifetime

        case .customDictionaries:
            // Requires premium plus or higher
            return status == .premiumPlus || status == .lifetime

        case .advancedAnalytics:
            // Requires premium or higher
            return status == .premium || status == .premiumPlus || status == .lifetime

        case .offlineMode:
            // Available to all (but Tier 2/3 models require premium)
            return true
        }
    }

    /// Update subscription status (called after successful purchase)
    func updateSubscriptionStatus(_ status: SubscriptionStatus) {
        logger.info("Subscription status updated to: \(status.displayName)")
        subscriptionStatus = status
    }

    /// Restore purchases
    func restorePurchases() async throws {
        logger.info("Restoring purchases")

        // TODO: Integrate with StoreKit to restore purchases
        // For now, this is a placeholder

        // Simulate restore
        // In production, this would:
        // 1. Query StoreKit for purchase history
        // 2. Verify receipts with App Store
        // 3. Update subscription status accordingly

        logger.info("Purchases restored")
    }

    /// Check device capability for feature
    /// - Parameter feature: Feature to check
    /// - Returns: True if device supports the feature
    nonisolated func isDeviceCapable(for feature: Feature) -> Bool {
        switch feature {
        case .llmValidation:
            // Tier 3 requires iPhone 12+ with 4GB+ RAM
            return DeviceCapability.supportsLLMValidation()

        case .customDictionaries, .advancedAnalytics, .offlineMode:
            // Available on all devices
            return true
        }
    }

    /// Get feature availability with reason
    /// - Parameter feature: Feature to check
    /// - Returns: Tuple of (available, reason)
    nonisolated func featureAvailability(for feature: Feature) async -> (available: Bool, reason: String?) {
        // Check subscription
        let hasSubscription = await isFeatureAvailable(feature)
        guard hasSubscription else {
            return (false, "Requires \(feature.requiredSubscription) subscription")
        }

        // Check device capability
        guard isDeviceCapable(for: feature) else {
            return (false, "Device does not meet minimum requirements")
        }

        return (true, nil)
    }
}

// MARK: - Feature Extensions

extension KBPremiumFeatures.Feature {
    var requiredSubscription: String {
        switch self {
        case .llmValidation, .advancedAnalytics:
            return "Premium"
        case .customDictionaries:
            return "Premium Plus"
        case .offlineMode:
            return "Free"
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension KBPremiumFeatures {
    static func preview(status: SubscriptionStatus = .free) -> KBPremiumFeatures {
        let features = KBPremiumFeatures()
        Task {
            await features.updateSubscriptionStatus(status)
        }
        return features
    }
}
#endif
