import Foundation
import CoreData
import SwiftUI
import Combine

// Using global AsyncTask typealias to avoid naming conflict with Core Data Task entity

@MainActor
class ScheduleManager: NSObject, ObservableObject, ScheduleManaging {
    static let shared = ScheduleManager()
    
    @Published private(set) var events: [Event] = []
    @Published private(set) var categories: [Category] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    
    // Publisher for protocol conformance
    var eventsPublisher: AnyPublisher<[Event], Never> {
        $events.eraseToAnyPublisher()
    }
    
    private let persistence: any PersistenceProviding
    private var fetchedResultsController: NSFetchedResultsController<Event>?
    private var categoriesFetchedResultsController: NSFetchedResultsController<Category>?
    
    // Cache for events by date
    private var eventsCache: [Date: [Event]] = [:]
    private let cacheLock = NSLock()
    
    // MARK: - Initialization
    
    /// Singleton for production use
    private override init() {
        self.persistence = PersistenceController.shared
        super.init()
        setupFetchedResultsControllers()
        fetchEvents()
        fetchCategories()
    }
    
    // MARK: - Setup
    private func setupFetchedResultsControllers() {
        // Events controller
        let eventRequest: NSFetchRequest<Event> = Event.fetchRequest()
        eventRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \Event.startTime, ascending: true)
        ]
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: eventRequest,
            managedObjectContext: persistence.container.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultsController?.delegate = self
        
        // Categories controller
        let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
        categoryRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \Category.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Category.name, ascending: true)
        ]
        categoryRequest.predicate = NSPredicate(format: "isActive == YES")
        
        categoriesFetchedResultsController = NSFetchedResultsController(
            fetchRequest: categoryRequest,
            managedObjectContext: persistence.container.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        categoriesFetchedResultsController?.delegate = self
    }
    
    // MARK: - Fetching
    func forceRefresh() {
        fetchEvents()
        objectWillChange.send()
    }
    
    private func fetchEvents() {
        isLoading = true
        
        persistence.performAndMeasure("Fetch all events") {
            do {
                try fetchedResultsController?.performFetch()
                events = fetchedResultsController?.fetchedObjects ?? []
                clearEventCache()
                
                // Log performance metric
                CrashReporter.shared.logPerformanceMetric(
                    name: "events_fetched",
                    value: Double(events.count),
                    unit: "events"
                )
            } catch {
                lastError = "Failed to fetch events: \(error.localizedDescription)"
                
                // Log error to crash reporter
                CrashReporter.shared.logError(
                    error,
                    userInfo: [
                        "operation": "fetch_events",
                        "event_count": events.count
                    ]
                )
            }
        }
        
        isLoading = false
    }
    
    private func fetchCategories() {
        persistence.performAndMeasure("Fetch categories") {
            do {
                try categoriesFetchedResultsController?.performFetch()
                categories = categoriesFetchedResultsController?.fetchedObjects ?? []
                
                // Log category count
                CrashReporter.shared.setCustomValue(categories.count, forKey: "category_count")
            } catch {
                lastError = "Failed to fetch categories: \(error.localizedDescription)"
                
                // Log error to crash reporter
                CrashReporter.shared.logError(
                    error,
                    userInfo: [
                        "operation": "fetch_categories",
                        "category_count": categories.count
                    ]
                )
            }
        }
    }
    
    // MARK: - Conflict Detection
    
    func checkForConflicts(startTime: Date, endTime: Date, excludingEvent: Event?) -> [Event] {
        let events = events(for: startTime) // Get events for that day
        
        return events.filter { event in
            // Skip the event we're excluding (for updates)
            if let excludingEvent = excludingEvent, event.id == excludingEvent.id {
                return false
            }
            
            // Check if times overlap
            guard let eventStart = event.startTime,
                  let eventEnd = event.endTime else {
                return false
            }
            
            // Check for overlap: 
            // New event starts before existing ends AND new event ends after existing starts
            return startTime < eventEnd && endTime > eventStart
        }
    }
    
    // MARK: - Event CRUD Operations
    func createEvent(
        title: String,
        startTime: Date,
        endTime: Date,
        category: Category?,
        notes: String? = nil,
        location: String? = nil,
        isAllDay: Bool = false,
        recurrenceRule: String? = nil,
        recurrenceID: UUID? = nil,
        recurrenceEndDate: Date? = nil
    ) -> Result<Event, Error> {
        
        // Check subscription limits
        let todayEvents = events(for: Date()).count
        if !SubscriptionManager.shared.canCreateEvent(currentCount: todayEvents) {
            return .failure(ScheduleError.subscriptionLimitReached)
        }
        
        let context = persistence.container.viewContext
        
        // Validation
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(ScheduleError.invalidTitle)
        }
        
        guard endTime > startTime else {
            return .failure(ScheduleError.invalidTimeRange)
        }
        
        // Check for conflicts
        let conflicts = checkForConflicts(startTime: startTime, endTime: endTime, excludingEvent: nil)
        if !conflicts.isEmpty {
            // Note: We'll still create the event but warn about conflicts
        }
        
        
        let event = Event(context: context)
        
        // Set required fields one by one with error checking
        do {
            event.id = UUID()
            
            event.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            
            event.startTime = startTime
            
            event.endTime = endTime
            
            if let category = category {
                event.category = category
            }
            
            // Handle notes with ALL_DAY marker
            if isAllDay {
                event.notes = (notes ?? "") + "[ALL_DAY]"
            } else {
                event.notes = notes
            }
            
            event.location = location
            
            event.dataSource = "manual"
            
            event.createdAt = Date()
            
            event.modifiedAt = Date()
            
            // Set other required Core Data fields with defaults
            event.isCompleted = false
            event.colorHex = category?.colorHex ?? "#007AFF"
            
            // Set recurrence fields if provided
            if let recurrenceRule = recurrenceRule {
                event.recurrenceRule = recurrenceRule
                event.recurrenceID = recurrenceID
                event.recurrenceEndDate = recurrenceEndDate
            }
            
            try context.save()
            clearEventCache()
            
            // Schedule notification for the event
            AsyncTask {
                await NotificationManager.shared.scheduleNotification(for: event)
            }
            
            // Reload widgets
            reloadWidgets()
            
            // Log event creation
            CrashReporter.shared.logUserAction(
                "create_event",
                target: title,
                data: [
                    "duration": endTime.timeIntervalSince(startTime),
                    "has_category": category != nil,
                    "is_all_day": isAllDay,
                    "has_notes": notes != nil,
                    "has_location": location != nil
                ]
            )
            
            return .success(event)
        } catch let error as NSError {
            lastError = "Failed to create event: \(error.localizedDescription)"
            
            // Log error
            CrashReporter.shared.logError(
                error,
                userInfo: [
                    "operation": "create_event",
                    "event_title": title,
                    "error_code": error.code,
                    "error_domain": error.domain
                ]
            )
            
            // Rollback
            context.rollback()
            
            return .failure(error)
        }
    }
    
    func updateEvent(
        _ event: Event,
        title: String?,
        startTime: Date?,
        endTime: Date?,
        category: Category?,
        notes: String?,
        location: String?,
        isCompleted: Bool?,
        colorHex: String?,
        iconName: String?,
        priority: String?,
        tags: String?,
        url: String?,
        energyLevel: String?,
        weatherRequired: String?,
        bufferTimeBefore: Int32?,
        bufferTimeAfter: Int32?,
        recurrenceRule: String?,
        recurrenceEndDate: Date?,
        linkedTasks: NSSet?
    ) -> Result<Void, Error> {
        let context = persistence.container.viewContext
        
        // Debug: Log the update request
        
        if let title = title {
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .failure(ScheduleError.invalidTitle)
            }
            event.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let startTime = startTime {
            event.startTime = startTime
        }
        
        if let endTime = endTime {
            event.endTime = endTime
        }
        
        // Validate time range if both times were updated
        if let start = event.startTime, let end = event.endTime {
            guard end > start else {
                return .failure(ScheduleError.invalidTimeRange)
            }
            // No duration field - calculate when needed
        }
        
        if let category = category {
            event.category = category
        }
        
        if let notes = notes {
            event.notes = notes
        }
        
        if let location = location {
            event.location = location
        }
        
        if let isCompleted = isCompleted {
            event.isCompleted = isCompleted
            if isCompleted {
                event.completedAt = Date()
            } else {
                event.completedAt = nil
            }
        }
        
        if let colorHex = colorHex {
            event.colorHex = colorHex
        }
        
        if let iconName = iconName {
            event.iconName = iconName
        }
        
        if let priority = priority {
            event.priority = priority
        }
        
        if let tags = tags {
            event.tags = tags
        }
        
        if let url = url {
            event.url = url
        }
        
        if let energyLevel = energyLevel {
            event.energyLevel = energyLevel
        }
        
        if let weatherRequired = weatherRequired {
            event.weatherRequired = weatherRequired
        }
        
        if let bufferTimeBefore = bufferTimeBefore {
            event.bufferTimeBefore = bufferTimeBefore
        }
        
        if let bufferTimeAfter = bufferTimeAfter {
            event.bufferTimeAfter = bufferTimeAfter
        }
        
        if let recurrenceRule = recurrenceRule {
            event.recurrenceRule = recurrenceRule
        }
        
        if let recurrenceEndDate = recurrenceEndDate {
            event.recurrenceEndDate = recurrenceEndDate
        }
        
        if let linkedTasks = linkedTasks {
            event.linkedTasks = linkedTasks
        }
        
        event.modifiedAt = Date()
        
        do {
            try context.save()
            clearEventCache()
            
            // Reschedule notification if time changed
            if startTime != nil || endTime != nil {
                AsyncTask {
                    await NotificationManager.shared.scheduleNotification(for: event)
                }
            }
            
            // Reload widgets
            reloadWidgets()
            
            // Debug: Check if event changed days
            if let oldStart = event.startTime, let newStart = startTime {
                let calendar = Calendar.current
                if !calendar.isDate(oldStart, inSameDayAs: newStart) {
                }
            }
            
            return .success(())
        } catch {
            lastError = "Failed to update event: \(error.localizedDescription)"
            return .failure(error)
        }
    }
    
    func deleteEvent(_ event: Event) -> Result<Void, Error> {
        let context = persistence.container.viewContext
        
        // Debug: Check event state before deletion
        
        // Get the event in the correct context if needed
        let eventToDelete: Event
        if event.managedObjectContext == nil {
            // Event has no context, fetch it fresh
            guard let eventId = event.id,
                  let fetchedEvent = fetchEventById(eventId) else {
                return .failure(ScheduleError.eventNotFound)
            }
            eventToDelete = fetchedEvent
        } else if event.managedObjectContext != context {
            // Event is in a different context, fetch it
            guard let eventId = event.id,
                  let fetchedEvent = fetchEventById(eventId) else {
                return .failure(ScheduleError.invalidContext)
            }
            eventToDelete = fetchedEvent
        } else {
            eventToDelete = event
        }
        
        context.delete(eventToDelete)
        
        do {
            let eventTitle = event.title ?? "Untitled"
            let eventId = event.id?.uuidString ?? "no-id"
            
            // Cancel notifications for this event
            if let id = event.id {
                AsyncTask {
                    await NotificationManager.shared.cancelNotifications(for: id)
                }
            }
            
            // Save with CloudKit sync
            try context.save()
            
            // Force refresh to ensure UI updates
            clearEventCache()
            fetchEvents()
            
            // Reload widgets
            reloadWidgets()
            
            // Force CloudKit sync
            persistence.forceSyncWithCloudKit()
            
            // Wait a bit for CloudKit to process
            AsyncTask {
                try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await MainActor.run {
                    self.objectWillChange.send()
                }
            }
            
            // Log event deletion
            CrashReporter.shared.logUserAction(
                "delete_event",
                target: eventTitle,
                data: ["event_id": eventId]
            )
            
            return .success(())
        } catch {
            lastError = "Failed to delete event: \(error.localizedDescription)"
            
            // Log error
            CrashReporter.shared.logError(
                error,
                userInfo: [
                    "operation": "delete_event",
                    "event_title": event.title ?? "Untitled"
                ]
            )
            
            return .failure(error)
        }
    }
    
    // Helper to fetch event by ID
    private func fetchEventById(_ id: UUID) -> Event? {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            return results.first
        } catch {
            return nil
        }
    }
    
    // MARK: - Filtered Views
    func eventsForToday() -> [Event] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        
        return events.filter { event in
            guard let eventStart = event.startTime else { return false }
            return eventStart >= start && eventStart < end
        }.sorted { ($0.startTime ?? Date.distantPast) < ($1.startTime ?? Date.distantPast) }
    }
    
    func eventsForWeek() -> [Event] {
        let calendar = Calendar.current
        let today = Date()
        
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let weekEnd = calendar.dateInterval(of: .weekOfYear, for: today)?.end else {
            return []
        }
        
        return events.filter { event in
            guard let eventStart = event.startTime else { return false }
            return eventStart >= weekStart && eventStart < weekEnd
        }.sorted { ($0.startTime ?? Date.distantPast) < ($1.startTime ?? Date.distantPast) }
    }
    
    func eventsForMonth() -> [Event] {
        let calendar = Calendar.current
        let today = Date()
        
        guard let monthStart = calendar.dateInterval(of: .month, for: today)?.start,
              let monthEnd = calendar.dateInterval(of: .month, for: today)?.end else {
            return []
        }
        
        return events.filter { event in
            guard let eventStart = event.startTime else { return false }
            return eventStart >= monthStart && eventStart < monthEnd
        }.sorted { ($0.startTime ?? Date.distantPast) < ($1.startTime ?? Date.distantPast) }
    }
    
    func events(for date: Date) -> [Event] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        // Normalize date to start of day for caching
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Check cache first
        cacheLock.lock()
        if let cachedEvents = eventsCache[normalizedDate] {
            cacheLock.unlock()
            return cachedEvents
        }
        cacheLock.unlock()
        
        // Filter events for this date
        let filteredEvents = events.filter { event in
            guard let eventStart = event.startTime else { 
                return false 
            }
            
            // Use calendar method to check if dates are in the same day considering timezone
            return calendar.isDate(eventStart, inSameDayAs: date)
        }.sorted { ($0.startTime ?? Date.distantPast) < ($1.startTime ?? Date.distantPast) }
        
        // Cache the result
        cacheLock.lock()
        eventsCache[normalizedDate] = filteredEvents
        cacheLock.unlock()
        
        return filteredEvents
    }
    
    // Clear cache when events are updated
    private func clearEventCache() {
        cacheLock.lock()
        eventsCache.removeAll()
        cacheLock.unlock()
    }
    
    // Preload events for multiple days
    func preloadEvents(for dates: [Date]) {
        // Process in background to avoid blocking UI
        _Concurrency.Task.detached { [weak self] in
            guard let self = self else { return }
            
            await MainActor.run {
                for date in dates {
                    // This will trigger caching
                    _ = self.events(for: date)
                }
            }
        }
    }
    
    // MARK: - Category Management
    func getCategories() -> [Category] {
        return categories
    }
    
    func createCategory(name: String, icon: String, colorHex: String) -> Result<Category, Error> {
        let context = persistence.container.viewContext
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return .failure(ScheduleError.invalidCategoryName)
        }
        
        // Check for existing category with same name (case-insensitive)
        if categories.contains(where: { $0.name?.lowercased() == trimmedName.lowercased() }) {
            return .failure(ScheduleError.duplicateCategoryName)
        }
        
        let category = Category(context: context)
        category.id = UUID()
        category.name = trimmedName
        category.iconName = icon
        category.colorHex = colorHex
        category.isActive = true
        category.isDefault = false
        category.sortOrder = Int32(categories.count)
        category.createdAt = Date()
        // No updatedAt field in Core Data model
        
        do {
            try context.save()
            return .success(category)
        } catch {
            lastError = "Failed to create category: \(error.localizedDescription)"
            return .failure(error)
        }
    }
    
    // MARK: - Default Categories
    private func createDefaultCategories() {
        let defaultCategories = [
            // 10 default categories with unique colors and icons
            ("Work", "briefcase.fill", "#007AFF"),         // Blue
            ("Personal", "person.fill", "#34C759"),         // Green  
            ("Health", "heart.fill", "#FF3B30"),            // Red
            ("Learning", "book.fill", "#FF9500"),           // Orange
            ("Meeting", "person.3.fill", "#5856D6"),        // Purple
            ("Fitness", "figure.run", "#00C7BE"),           // Teal
            ("Finance", "dollarsign.circle.fill", "#50E3C2"), // Mint
            ("Family", "house.circle.fill", "#FF6B9D"),     // Pink
            ("Social", "bubble.left.and.bubble.right.fill", "#4A90E2"), // Light Blue
            ("Other", "square.grid.2x2.fill", "#8E8E93")   // Gray
        ]
        
        for (name, icon, color) in defaultCategories {
            _ = createCategory(name: name, icon: icon, colorHex: color)
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate
// NSFetchedResultsControllerDelegate conformance
extension ScheduleManager: NSFetchedResultsControllerDelegate {
    nonisolated func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        AsyncTask { @MainActor in
            if controller == fetchedResultsController {
                let _ = events.count
                events = fetchedResultsController?.fetchedObjects ?? []
                clearEventCache()
                
                // Debug: Show all events after update
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm"
                for _ in events {
                    // Debug logging removed
                }
            } else if controller == categoriesFetchedResultsController {
                categories = categoriesFetchedResultsController?.fetchedObjects ?? []
            }
        }
    }
}

// MARK: - Error Types
enum ScheduleError: LocalizedError {
    case invalidTitle
    case invalidTimeRange
    case invalidCategoryName
    case eventNotFound
    case invalidContext
    case duplicateCategoryName
    case saveFailed
    case deleteFailed
    case subscriptionLimitReached
    
    var errorDescription: String? {
        switch self {
        case .invalidTitle:
            return "Event title cannot be empty"
        case .invalidTimeRange:
            return "End time must be after start time"
        case .invalidCategoryName:
            return "Category name cannot be empty"
        case .eventNotFound:
            return "Event not found"
        case .invalidContext:
            return "Event is not in the expected context"
        case .duplicateCategoryName:
            return "A category with this name already exists"
        case .saveFailed:
            return "Failed to save changes"
        case .deleteFailed:
            return "Failed to delete item"
        case .subscriptionLimitReached:
            return "You've reached the free plan limit. Upgrade to Premium for unlimited events."
        }
    }
}