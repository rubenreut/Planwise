import Foundation
import CoreData
import CloudKit

/// Mock persistence provider for testing
@MainActor
class MockPersistenceProvider: ObservableObject, PersistenceProviding {
    let container: NSPersistentCloudKitContainer
    private(set) var saveCallCount = 0
    private(set) var lastPerformedOperation: String?
    var shouldFailSave = false {
        didSet {
            saveFailureLock.lock()
            _threadSafeShouldFailSave = shouldFailSave
            saveFailureLock.unlock()
        }
    }
    
    // Thread-safe flag for save failures
    private let saveFailureLock = NSLock()
    nonisolated(unsafe) private var _threadSafeShouldFailSave = false
    
    init() {
        container = NSPersistentCloudKitContainer(name: "Momentum")
        
        // Configure for in-memory testing
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Failed to load mock store: \(error), \(error.userInfo)")
            }
        }
        
        // Configure context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    nonisolated func save() throws {
        let context = container.viewContext
        
        guard context.hasChanges else { return }
        
        // Check if we should fail (thread-safe)
        saveFailureLock.lock()
        let shouldFail = _threadSafeShouldFailSave
        saveFailureLock.unlock()
        
        if shouldFail {
            throw NSError(domain: "MockPersistenceProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save failure"])
        }
        
        // Update counter asynchronously
        _Concurrency.Task { @MainActor in
            self.saveCallCount += 1
        }
        
        try context.save()
    }
    
    nonisolated func performAndMeasure<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        _Concurrency.Task { @MainActor in
            lastPerformedOperation = operation
        }
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        }
        return try block()
    }
    
    // MARK: - Test Helpers
    
    /// Reset the mock state
    func reset() {
        saveCallCount = 0
        lastPerformedOperation = nil
        shouldFailSave = false
    }
    
    /// Create test categories in the mock context
    func createTestCategories() {
        let context = container.viewContext
        
        let categories = [
            ("Work", "briefcase.fill", "#007AFF"),
            ("Personal", "person.fill", "#34C759"),
            ("Health", "heart.fill", "#FF3B30")
        ]
        
        for (name, icon, color) in categories {
            let category = Category(context: context)
            category.id = UUID()
            category.name = name
            category.iconName = icon
            category.colorHex = color
            category.isActive = true
            category.isDefault = false
            category.sortOrder = Int32(categories.firstIndex { $0.0 == name } ?? 0)
            category.createdAt = Date()
        }
        
        do {
            try save()
        } catch {
        }
    }
    
    nonisolated func forceSyncWithCloudKit() {
        // No-op for testing
    }
}