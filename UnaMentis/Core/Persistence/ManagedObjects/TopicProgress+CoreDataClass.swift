// UnaMentis - TopicProgress Core Data Class
// Manual NSManagedObject subclass for SPM compatibility
//
// This file enables Core Data entities to work with Swift Package Manager builds.
// The .xcdatamodeld must have codeGenerationType set to "Manual/None".

import Foundation
import CoreData

@objc(TopicProgress)
public class TopicProgress: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TopicProgress> {
        return NSFetchRequest<TopicProgress>(entityName: "TopicProgress")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timeSpent: Double
    @NSManaged public var lastAccessed: Date?
    @NSManaged public var quizScores: [Float]?
    @NSManaged public var topic: Topic?
}
