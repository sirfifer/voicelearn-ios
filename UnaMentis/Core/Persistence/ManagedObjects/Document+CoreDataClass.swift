// UnaMentis - Document Core Data Class
// Manual NSManagedObject subclass for SPM compatibility
//
// This file enables Core Data entities to work with Swift Package Manager builds.
// The .xcdatamodeld must have codeGenerationType set to "Manual/None".

import Foundation
import CoreData

@objc(Document)
public class Document: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Document> {
        return NSFetchRequest<Document>(entityName: "Document")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var content: String?
    @NSManaged public var summary: String?
    @NSManaged public var embedding: Data?
    @NSManaged public var type: String?
    @NSManaged public var sourceURL: URL?
    @NSManaged public var topic: Topic?
}
