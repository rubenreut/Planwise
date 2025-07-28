import CoreData
import CloudKit

/// Protocol defining the interface for persistence operations
protocol PersistenceProviding: AnyObject {
    var container: NSPersistentCloudKitContainer { get }
    
    /// Save the current context
    func save() throws
    
    /// Perform an operation and measure its performance
    func performAndMeasure<T>(_ operation: String, block: () throws -> T) rethrows -> T
    
    /// Force sync with CloudKit
    func forceSyncWithCloudKit()
}