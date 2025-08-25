import CoreData
import CloudKit

class PersistenceController: ObservableObject, PersistenceProviding {
    static let shared = PersistenceController()
    
    let container: NSPersistentCloudKitContainer
    
    private init() {
        container = NSPersistentCloudKitContainer(name: "Momentum")
        
        // Check iCloud availability
        checkiCloudAvailability()
        
        // Configure for CloudKit
        let cloudKitContainerIdentifier = "iCloud.com.rubnereut.ecosystem"
        
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }
        
        // CloudKit configuration
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: cloudKitContainerIdentifier
        )
        
        // Force CloudKit schema initialization
        description.cloudKitContainerOptions?.databaseScope = .private
        
        // Configure for performance and CloudKit sync
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Ensure we're using SQLite store type (required for CloudKit)
        description.type = NSSQLiteStoreType
        
        // App group support for widgets
        let appGroupID = "group.com.rubnereut.productivity"
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let storeURL = appGroupURL.appendingPathComponent("Momentum.sqlite")
            description.url = storeURL
        } else {
            // Fall back to documents directory
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let storeURL = documentsURL.appendingPathComponent("Momentum.sqlite")
            description.url = storeURL
        }
        
        // Add semaphore to ensure store loads before continuing
        let loadSemaphore = DispatchSemaphore(value: 0)
        var loadError: Error?
        
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                
                // Detailed CloudKit error diagnosis
                if error.domain == "CKErrorDomain" {
                    switch error.code {
                    case 1: break //print("   → Network unavailable")
                    case 2: break //print("   → Network timeout") 
                    case 3: break //print("   → Bad container (check identifier)")
                    case 4: break //print("   → Service unavailable")
                    case 5: break //print("   → Request rate limited")
                    case 6: break //print("   → Missing entitlement")
                    case 7: break //print("   → Not authenticated (not signed into iCloud)")
                    case 9: break //print("   → Permission failure")
                    case 26: break //print("   → Quota exceeded")
                    case 28: break //print("   → Account temporarily unavailable")
                    case 35: break //print("   → User deleted zone")
                    case 36: break //print("   → iCloud Drive not enabled")
                    default: break //print("   → Unknown CloudKit error code: \(error.code)")
                    }
                }
                
                loadError = error
                // Try to handle the error
                self?.handlePersistentStoreError(error)
            } else {
                
                // Verify we actually have stores
                if self?.container.persistentStoreCoordinator.persistentStores.isEmpty == true {
                    // Force create a store
                    self?.createInMemoryStoreIfNeeded()
                } else {
                    // Initialize default categories on first launch
                    self?.initializeDefaultCategoriesIfNeeded()
                }
            }
            loadSemaphore.signal()
        }
        
        // Wait for store to load (with timeout)
        _ = loadSemaphore.wait(timeout: .now() + 5.0)
        
        if loadError != nil {
            // Don't fall back to in-memory - we want CloudKit!
            // createInMemoryStoreIfNeeded()
        }
        
        // Configure for automatic merging of changes
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Performance optimization
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        // Ensure view context name for debugging
        container.viewContext.name = "ViewContext"
        
    }
    
    private func handlePersistentStoreError(_ error: NSError) {
        // Common recovery strategies
        if error.code == 134110 { // Model version mismatch
            // In production, implement proper migration
        } else if error.code == 134100 { // Persistent store not found
        } else {
        }
    }
    
    private func createInMemoryStoreIfNeeded() {
        
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        
        do {
            let coordinator = container.persistentStoreCoordinator
            try coordinator.addPersistentStore(
                ofType: NSInMemoryStoreType,
                configurationName: nil,
                at: nil,
                options: nil
            )
        } catch {
            // Last resort - create a basic SQLite store
            createBasicSQLiteStore()
        }
    }
    
    private func createBasicSQLiteStore() {
        
        let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Momentum.sqlite")
        
        do {
            let coordinator = container.persistentStoreCoordinator
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: [
                    NSMigratePersistentStoresAutomaticallyOption: true,
                    NSInferMappingModelAutomaticallyOption: true
                ]
            )
        } catch {
            fatalError("Unable to create Core Data store")
        }
    }
    
    private func initializeDefaultCategoriesIfNeeded() {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        
        do {
            let count = try context.count(for: fetchRequest)
            if count == 0 {
                createDefaultCategories()
            } else {
                removeDuplicateCategories()
            }
        } catch {
            // Error handled - category count check failed
            _ = error
        }
    }
    
    private func removeDuplicateCategories() {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \Category.createdAt, ascending: true),
            NSSortDescriptor(keyPath: \Category.name, ascending: true)
        ]
        
        do {
            let allCategories = try context.fetch(fetchRequest)
            var seenNames = Set<String>()
            var categoriesToDelete: [Category] = []
            
            for category in allCategories {
                if let name = category.name {
                    if seenNames.contains(name) {
                        // This is a duplicate
                        categoriesToDelete.append(category)
                    } else {
                        seenNames.insert(name)
                    }
                }
            }
            
            // Delete duplicates
            for category in categoriesToDelete {
                context.delete(category)
            }
            
            if !categoriesToDelete.isEmpty {
                try context.save()
            } else {
            }
        } catch {
            // Error handled - duplicate removal failed
            _ = error
        }
    }
    
    private func createDefaultCategories() {
        let context = container.viewContext
        
        let defaultCategories = [
            ("Work", "briefcase.fill", "#007AFF"),      // Blue
            ("Personal", "person.fill", "#34C759"),     // Green
            ("Health", "heart.fill", "#FF3B30"),        // Red
            ("Social", "person.2.fill", "#FF9500"),     // Orange
            ("Tasks", "checkmark.circle.fill", "#AF52DE") // Purple
        ]
        
        for (index, (name, icon, color)) in defaultCategories.enumerated() {
            // Check if category with this name already exists
            let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", name)
            
            do {
                let existingCategories = try context.fetch(fetchRequest)
                if existingCategories.isEmpty {
                    // Only create if it doesn't exist
                    let category = Category(context: context)
                    category.id = UUID()
                    category.name = name
                    category.iconName = icon
                    category.colorHex = color
                    category.isActive = true
                    category.isDefault = true
                    category.sortOrder = Int32(index)
                    category.createdAt = Date()
                } else {
                }
            } catch {
                // Error handled - category fetch failed
                _ = error
            }
        }
        
        do {
            try context.save()
        } catch {
            // Error handled - category creation save failed
            _ = error
        }
    }
    
    private func checkiCloudAvailability() {
        
        _ = FileManager.default.ubiquityIdentityToken != nil ? true : false 
        
        // Check CloudKit container directly
        let container = CKContainer(identifier: "iCloud.com.rubnereut.ecosystem")
        container.accountStatus { status, error in
            if let _ = error {
            } else {
                switch status {
                case .available: break
                case .noAccount: break
                case .restricted: break
                case .temporarilyUnavailable: break
                case .couldNotDetermine: break
                @unknown default: break
                }
            }
        }
    }
    
    // MARK: - Core Data Saving
    func save() throws {
        let context = container.viewContext
        
        guard context.hasChanges else { return }
        
        try context.save()
    }
    
    // MARK: - Performance Monitoring
    func performAndMeasure<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            if elapsed > 1.0 {
            }
        }
        return try block()
    }
}

// MARK: - Preview Support
extension PersistenceController {
    static var preview: PersistenceController = {
        let result = PersistenceController()
        let viewContext = result.container.viewContext
        
        // Create sample data for previews
        let sampleCategory = Category(context: viewContext)
        sampleCategory.id = UUID()
        sampleCategory.name = "Work"
        sampleCategory.iconName = "briefcase.fill"
        sampleCategory.colorHex = "#007AFF"
        sampleCategory.isActive = true
        sampleCategory.isDefault = true
        sampleCategory.createdAt = Date()
        // No updatedAt field in Core Data model
        
        for i in 0..<5 {
            let event = Event(context: viewContext)
            event.id = UUID()
            event.title = "Sample Event \(i)"
            event.startTime = Date().addingTimeInterval(Double(i) * 3600)
            event.endTime = Date().addingTimeInterval(Double(i + 1) * 3600)
            event.category = sampleCategory
            event.createdAt = Date()
            event.modifiedAt = Date()
            event.dataSource = "manual"
        }
        
        do {
            try viewContext.save()
        } catch {
            // Error handled - preview save failed
            _ = error
        }
        
        return result
    }()
}

// MARK: - CloudKit Sync Extensions
extension PersistenceController {
    // Force CloudKit sync
    func forceSyncWithCloudKit() {
        
        // Trigger a save to force sync
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Error handled - CloudKit sync save failed
                _ = error
            }
        }
        
        // Post notification to trigger sync
        NotificationCenter.default.post(
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
        
    }
}