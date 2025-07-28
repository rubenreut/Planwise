import CoreData

struct WidgetPersistenceController {
    static let shared = WidgetPersistenceController()
    
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "Momentum")
        
        // Configure for app group
        let appGroupID = "group.com.rubnereut.productivity"
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let storeURL = appGroupURL.appendingPathComponent("Momentum.sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)
            container.persistentStoreDescriptions = [description]
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
            } else {
            }
        }
        
        // Set merge policy
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}

// Extension to use widget persistence controller
extension Event {
    static func widgetTodayEvents() -> [Event] {
        let context = WidgetPersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Event> = Event.fetchRequest()
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        fetchRequest.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Event.startTime, ascending: true)]
        
        do {
            let events = try context.fetch(fetchRequest)
            return events
        } catch {
            return []
        }
    }
}