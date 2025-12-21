// UnaMentis - Session Core Data Class
// Manual NSManagedObject subclass for SPM compatibility
//
// This file enables Core Data entities to work with Swift Package Manager builds.
// The .xcdatamodeld must have codeGenerationType set to "Manual/None".

import Foundation
import CoreData

@objc(Session)
public class Session: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Session> {
        return NSFetchRequest<Session>(entityName: "Session")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var startTime: Date?
    @NSManaged public var endTime: Date?
    @NSManaged public var duration: Double
    @NSManaged public var totalCost: NSDecimalNumber?
    @NSManaged public var config: Data?
    @NSManaged public var metricsSnapshot: Data?
    @NSManaged public var topic: Topic?
    @NSManaged public var transcript: NSOrderedSet?
}

// MARK: - Generated Accessors for Transcript

extension Session {
    @objc(insertObject:inTranscriptAtIndex:)
    @NSManaged public func insertIntoTranscript(_ value: TranscriptEntry, at idx: Int)

    @objc(removeObjectFromTranscriptAtIndex:)
    @NSManaged public func removeFromTranscript(at idx: Int)

    @objc(insertTranscript:atIndexes:)
    @NSManaged public func insertIntoTranscript(_ values: [TranscriptEntry], at indexes: NSIndexSet)

    @objc(removeTranscriptAtIndexes:)
    @NSManaged public func removeFromTranscript(at indexes: NSIndexSet)

    @objc(replaceObjectInTranscriptAtIndex:withObject:)
    @NSManaged public func replaceTranscript(at idx: Int, with value: TranscriptEntry)

    @objc(replaceTranscriptAtIndexes:withTranscript:)
    @NSManaged public func replaceTranscript(at indexes: NSIndexSet, with values: [TranscriptEntry])

    @objc(addTranscriptObject:)
    @NSManaged public func addToTranscript(_ value: TranscriptEntry)

    @objc(removeTranscriptObject:)
    @NSManaged public func removeFromTranscript(_ value: TranscriptEntry)

    @objc(addTranscript:)
    @NSManaged public func addToTranscript(_ values: NSOrderedSet)

    @objc(removeTranscript:)
    @NSManaged public func removeFromTranscript(_ values: NSOrderedSet)
}
