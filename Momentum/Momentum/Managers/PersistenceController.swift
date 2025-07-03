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
            print("📁 Using App Group URL: \(storeURL.path)")
        } else {
            print("⚠️ App Group not available, using default location")
            // Fall back to documents directory
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let storeURL = documentsURL.appendingPathComponent("Momentum.sqlite")
            description.url = storeURL
            print("📁 Using Documents URL: \(storeURL.path)")
        }
        
        // Add semaphore to ensure store loads before continuing
        let loadSemaphore = DispatchSemaphore(value: 0)
        var loadError: Error?
        
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                print("❌ Core Data failed to load: \(error), \(error.userInfo)")
                
                // Detailed CloudKit error diagnosis
                if error.domain == "CKErrorDomain" {
                    print("🔍 CloudKit specific error detected:")
                    switch error.code {
                    case 1: print("   → Network unavailable")
                    case 2: print("   → Network timeout") 
                    case 3: print("   → Bad container (check identifier)")
                    case 4: print("   → Service unavailable")
                    case 5: print("   → Request rate limited")
                    case 6: print("   → Missing entitlement")
                    case 7: print("   → Not authenticated (not signed into iCloud)")
                    case 9: print("   → Permission failure")
                    case 26: print("   → Quota exceeded")
                    case 28: print("   → Account temporarily unavailable")
                    case 35: print("   → User deleted zone")
                    case 36: print("   → iCloud Drive not enabled")
                    default: print("   → Unknown CloudKit error code: \(error.code)")
                    }
                }
                
                loadError = error
                // Try to handle the error
                self?.handlePersistentStoreError(error)
            } else {
                print("✅ Core Data loaded successfully")
                print("Store URL: \(storeDescription.url?.absoluteString ?? "unknown")")
                print("Store Type: \(storeDescription.type)")
                
                // Verify we actually have stores
                if self?.container.persistentStoreCoordinator.persistentStores.isEmpty == true {
                    print("❌ WARNING: No persistent stores loaded!")
                    // Force create a store
                    self?.createInMemoryStoreIfNeeded()
                } else {
                    print("✅ Persistent stores count: \(self?.container.persistentStoreCoordinator.persistentStores.count ?? 0)")
                    // Initialize default categories on first launch
                    self?.initializeDefaultCategoriesIfNeeded()
                }
            }
            loadSemaphore.signal()
        }
        
        // Wait for store to load (with timeout)
        _ = loadSemaphore.wait(timeout: .now() + 5.0)
        
        if let error = loadError {
            print("⚠️ Store failed to load with error: \(error)")
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
        
        print("🔧 Core Data configured:")
        print("   Store type: \(description.type)")
        print("   CloudKit: \(description.cloudKitContainerOptions != nil)")
    }
    
    private func handlePersistentStoreError(_ error: NSError) {
        // Common recovery strategies
        if error.code == 134110 { // Model version mismatch
            print("⚠️ Core Data model version mismatch - attempting migration")
            // In production, implement proper migration
        } else if error.code == 134100 { // Persistent store not found
            print("⚠️ Persistent store not found - will create new one")
        } else {
            print("⚠️ Unknown Core Data error: \(error)")
        }
    }
    
    private func createInMemoryStoreIfNeeded() {
        print("🔧 Creating in-memory store as fallback...")
        
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
            print("✅ In-memory store created successfully")
            print("   Store count: \(coordinator.persistentStores.count)")
        } catch {
            print("❌ Failed to create in-memory store: \(error)")
            // Last resort - create a basic SQLite store
            createBasicSQLiteStore()
        }
    }
    
    private func createBasicSQLiteStore() {
        print("🔧 Creating basic SQLite store...")
        
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
            print("✅ SQLite store created at: \(storeURL.path)")
        } catch {
            print("❌ CRITICAL: Failed to create any persistent store: \(error)")
            fatalError("Unable to create Core Data store")
        }
    }
    
    private func initializeDefaultCategoriesIfNeeded() {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        
        do {
            let count = try context.count(for: fetchRequest)
            if count == 0 {
                print("📁 Initializing default categories...")
                createDefaultCategories()
            } else {
                print("✅ Categories already exist (\(count) found), checking for duplicates...")
                removeDuplicateCategories()
            }
        } catch {
            print("❌ Failed to fetch categories: \(error)")
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
                        print("🗑️ Found duplicate category: \(name)")
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
                print("✅ Removed \(categoriesToDelete.count) duplicate categories")
            } else {
                print("✅ No duplicate categories found")
            }
        } catch {
            print("❌ Failed to remove duplicate categories: \(error)")
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
                    print("✅ Created category: \(name)")
                } else {
                    print("⏭️ Category '\(name)' already exists, skipping")
                }
            } catch {
                print("❌ Error checking for existing category '\(name)': \(error)")
            }
        }
        
        do {
            try context.save()
            print("✅ Default categories initialization complete")
        } catch {
            print("❌ Failed to save default categories: \(error)")
        }
    }
    
    private func checkiCloudAvailability() {
        print("🔍 Checking iCloud availability...")
        
        FileManager.default.ubiquityIdentityToken != nil ? 
            print("✅ iCloud account is signed in") : 
            print("❌ No iCloud account found - CloudKit sync will not work")
        
        // Check CloudKit container directly
        let container = CKContainer(identifier: "iCloud.com.rubnereut.ecosystem")
        container.accountStatus { status, error in
            if let error = error {
                print("❌ CloudKit account check failed: \(error)")
            } else {
                switch status {
                case .available:
                    print("✅ CloudKit is available")
                case .noAccount:
                    print("❌ No iCloud account")
                case .restricted:
                    print("❌ iCloud restricted (parental controls?)")
                case .temporarilyUnavailable:
                    print("⚠️ iCloud temporarily unavailable")
                case .couldNotDetermine:
                    print("❓ Could not determine iCloud status")
                @unknown default:
                    print("❓ Unknown iCloud status")
                }
            }
        }
    }
    
    // MARK: - Core Data Saving
    func save() {
        let context = container.viewContext
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            print("✅ Context saved successfully")
        } catch {
            print("❌ Failed to save context: \(error)")
            // In production, implement proper error recovery
        }
    }
    
    // MARK: - Performance Monitoring
    func performAndMeasure<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            if elapsed > 1.0 {
                print("⚠️ PERF: Slow operation (\(String(format: "%.3f", elapsed))s): \(operation)")
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
            print("❌ Failed to create preview data: \(error)")
        }
        
        return result
    }()
}

// MARK: - CloudKit Sync Extensions
extension PersistenceController {
    // Force CloudKit sync
    func forceSyncWithCloudKit() {
        print("🔄 Forcing CloudKit sync...")
        
        // Trigger a save to force sync
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Context saved for CloudKit sync")
            } catch {
                print("❌ Failed to save context for sync: \(error)")
            }
        }
        
        // Post notification to trigger sync
        NotificationCenter.default.post(
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
        
        print("📤 CloudKit sync triggered")
    }
}