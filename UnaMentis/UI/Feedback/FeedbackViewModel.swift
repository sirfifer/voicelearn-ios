// UnaMentis - Feedback ViewModel
// Business logic for feedback submission
//
// Follows UnaMentis MVVM pattern: @MainActor for all UI-related state
// Part of Beta Testing infrastructure

import Foundation
import SwiftUI
import CoreData

/// ViewModel for feedback submission following UnaMentis MVVM pattern
/// @MainActor ensures all UI updates happen on main thread
@MainActor
public class FeedbackViewModel: ObservableObject {
    // MARK: - User Input

    @Published public var category: FeedbackCategory = .other
    @Published public var rating: Int? = nil
    @Published public var message: String = ""

    // MARK: - Privacy Controls (GDPR/CCPA Compliance)

    @Published public var includeDiagnostics: Bool = false

    // MARK: - UI State

    @Published public var isSubmitting: Bool = false
    @Published public var showError: Bool = false
    @Published public var errorMessage: String = ""
    @Published public var showSuccess: Bool = false

    // MARK: - Context (Injected)

    public var context: FeedbackContext?

    // MARK: - Dependencies

    private let persistenceController = PersistenceController.shared
    private let feedbackService = FeedbackService.shared
    private let diagnosticsCollector = DeviceDiagnosticsCollector()

    // MARK: - Computed Properties

    /// Validation: message must not be empty
    public var canSubmit: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Quality indicator: encourage detailed feedback (30+ chars recommended)
    /// Industry best practice from TestFlight and Firebase
    public var messageQualityHint: String? {
        message.count < 30 ? String(localized: "feedback.message.quality.hint") : nil
    }

    /// Dynamic prompt based on selected category (industry best practice)
    /// Guides users to provide more useful, actionable feedback
    public var currentPrompt: LocalizedStringKey {
        category.messagePrompt
    }

    // MARK: - Actions

    /// Submit feedback to server and Core Data
    /// Implements local-first pattern: always save to Core Data, then attempt server upload
    public func submit() async {
        guard canSubmit else { return }
        guard let context = context else { return }

        isSubmitting = true
        errorMessage = ""

        do {
            // Collect diagnostics if user consented
            let diagnostics: DeviceDiagnostics? = includeDiagnostics
                ? await diagnosticsCollector.collect()
                : nil

            // Create Core Data entity
            let coreDataContext = persistenceController.container.viewContext
            let feedback = Feedback(context: coreDataContext)
            feedback.id = UUID()
            feedback.timestamp = Date()
            feedback.category = category.rawValue
            feedback.rating = rating.map { Int16($0) } ?? 0
            feedback.message = message

            // Auto-captured context
            feedback.currentScreen = context.currentScreen
            feedback.navigationPath = context.navigationPath.joined(separator: " > ")
            feedback.deviceModel = UIDevice.current.model
            feedback.iOSVersion = UIDevice.current.systemVersion
            feedback.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

            // Session context (if applicable)
            if let duration = context.sessionDuration {
                feedback.sessionDurationSeconds = Int32(duration)
            }
            feedback.sessionState = context.sessionState
            if let turns = context.turnCount {
                feedback.turnCount = Int16(turns)
            }

            // Diagnostics (if consented)
            feedback.includedDiagnostics = includeDiagnostics
            if let diag = diagnostics {
                feedback.memoryUsageMB = Int32(diag.memoryUsageMB)
                feedback.batteryLevel = diag.batteryLevel
                feedback.networkType = diag.networkType
                feedback.lowPowerMode = diag.lowPowerMode
            }

            feedback.submitted = false

            try coreDataContext.save()

            // Try to submit to server (best effort)
            do {
                _ = try await feedbackService.submitFeedback(
                    feedback,
                    context: context,
                    diagnostics: diagnostics
                )

                // Mark as submitted
                feedback.submitted = true
                feedback.submittedAt = Date()
                try coreDataContext.save()

                showSuccess = true
                reset()

            } catch {
                // Failed to submit, but saved locally
                // Future: Background sync will retry
                errorMessage = String(localized: "feedback.error.saved.locally")
                showError = true
            }

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isSubmitting = false
    }

    /// Reset form to initial state
    public func reset() {
        category = .other
        rating = nil
        message = ""
        includeDiagnostics = false
    }

    /// Set rating value (1-5)
    /// - Parameter value: Star rating (1-5) or nil to clear
    public func setRating(_ value: Int?) {
        rating = value
    }

    /// Toggle rating value (tap same star to clear)
    /// - Parameter value: Star rating (1-5)
    public func toggleRating(_ value: Int) {
        if rating == value {
            rating = nil
        } else {
            rating = value
        }
    }
}
