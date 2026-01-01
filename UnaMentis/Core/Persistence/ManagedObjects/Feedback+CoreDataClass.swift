// UnaMentis - Feedback Core Data Class
// Manual NSManagedObject subclass for SPM compatibility
//
// This file enables Core Data entities to work with Swift Package Manager builds.
// The .xcdatamodeld must have codeGenerationType set to "Manual/None".

import Foundation
import CoreData

@objc(Feedback)
public class Feedback: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Feedback> {
        return NSFetchRequest<Feedback>(entityName: "Feedback")
    }

    // Identity
    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?

    // User Input
    @NSManaged public var category: String?
    @NSManaged public var rating: Int16
    @NSManaged public var message: String?

    // Auto-Captured Context
    @NSManaged public var currentScreen: String?
    @NSManaged public var navigationPath: String?
    @NSManaged public var deviceModel: String?
    @NSManaged public var iOSVersion: String?
    @NSManaged public var appVersion: String?

    // Diagnostic Data (Requires User Consent)
    @NSManaged public var includedDiagnostics: Bool
    @NSManaged public var memoryUsageMB: Int32
    @NSManaged public var batteryLevel: Float
    @NSManaged public var networkType: String?
    @NSManaged public var lowPowerMode: Bool

    // Session Context
    @NSManaged public var sessionDurationSeconds: Int32
    @NSManaged public var sessionState: String?
    @NSManaged public var turnCount: Int16

    // Submission Tracking
    @NSManaged public var submitted: Bool
    @NSManaged public var submittedAt: Date?

    // Relationships
    @NSManaged public var session: Session?
    @NSManaged public var topic: Topic?
}

extension Feedback: Identifiable { }
