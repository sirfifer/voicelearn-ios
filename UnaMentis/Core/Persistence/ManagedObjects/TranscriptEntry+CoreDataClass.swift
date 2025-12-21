// UnaMentis - TranscriptEntry Core Data Class
// Manual NSManagedObject subclass for SPM compatibility
//
// This file enables Core Data entities to work with Swift Package Manager builds.
// The .xcdatamodeld must have codeGenerationType set to "Manual/None".

import Foundation
import CoreData

@objc(TranscriptEntry)
public class TranscriptEntry: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TranscriptEntry> {
        return NSFetchRequest<TranscriptEntry>(entityName: "TranscriptEntry")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var content: String?
    @NSManaged public var role: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var session: Session?
}
