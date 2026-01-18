// UnaMentis - Feature Flag Keys
// Centralized feature flag key definitions
//
// Flag names should match what's configured in Unleash.
// Use semantic naming: {category}_{feature}_{variant}

import Foundation

/// Centralized feature flag keys used across the app
public enum FeatureFlagKeys {
    // MARK: - Operations

    /// Maintenance mode - blocks new sessions
    public static let maintenanceMode = "ops_maintenance_mode"

    // MARK: - Features

    /// Specialized training modules (Knowledge Bowl, etc.)
    /// Controls visibility of the Modules section in Learning tab
    public static let specializedModules = "feature_specialized_modules"

    /// Team collaboration features within modules
    public static let teamMode = "feature_team_mode"

    /// Competition simulation features
    public static let competitionSim = "feature_competition_sim"

    // MARK: - Experiments

    /// A/B test for new onboarding flow
    public static let newOnboarding = "experiment_new_onboarding"
}
