import Foundation
import CoreData
import Combine

/// Mock schedule manager for testing
@MainActor
class MockScheduleManager: ObservableObject, ScheduleManaging {
    
    // MARK: - Conflict Detection
    func checkForConflicts(startTime: Date, endTime: Date, excludingEvent: Event?) -> [Event] {
        return events.filter { event in
            if let excludingEvent = excludingEvent, event.id == excludingEvent.id {
                return false
            }
            
            guard let eventStart = event.startTime,
                  let eventEnd = event.endTime else {
                return false
            }
            
            return startTime < eventEnd && endTime > eventStart
        }
    }
    @Published private(set) var events: [Event] = []
    @Published private(set) var categories: [Category] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    
    // Publisher for protocol conformance
    var eventsPublisher: AnyPublisher<[Event], Never> {
        $events.eraseToAnyPublisher()
    }
    
    // Test helpers
    var shouldFailOperations = false
    var createEventCallCount = 0
    var updateEventCallCount = 0
    var deleteEventCallCount = 0
    var refreshCallCount = 0
    
    // Mock data storage
    private var mockEventsById: [UUID: Event] = [:]
    private var mockCategoriesById: [UUID: Category] = [:]
    
    init() {
        // Initialize with empty data
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
        createEventCallCount += 1
        
        guard !shouldFailOperations else {
            lastError = "Mock error: Operation failed"
            return .failure(ScheduleError.invalidTitle)
        }
        
        // Validation
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(ScheduleError.invalidTitle)
        }
        
        guard endTime > startTime else {
            return .failure(ScheduleError.invalidTimeRange)
        }
        
        // Create mock event
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        let event = Event(context: context)
        event.id = UUID()
        event.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.startTime = startTime
        event.endTime = endTime
        event.category = category
        event.notes = isAllDay ? (notes ?? "") + "[ALL_DAY]" : notes
        event.location = location
        event.dataSource = "manual"
        event.createdAt = Date()
        event.modifiedAt = Date()
        event.isCompleted = false
        event.colorHex = category?.colorHex ?? "#007AFF"
        
        // Store in mock storage
        mockEventsById[event.id!] = event
        events.append(event)
        
        return .success(event)
    }
    
    func updateEvent(
        _ event: Event,
        title: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        category: Category? = nil,
        notes: String? = nil,
        location: String? = nil,
        isCompleted: Bool? = nil,
        colorHex: String? = nil,
        iconName: String? = nil,
        priority: String? = nil,
        tags: String? = nil,
        url: String? = nil,
        energyLevel: String? = nil,
        weatherRequired: String? = nil,
        bufferTimeBefore: Int32? = nil,
        bufferTimeAfter: Int32? = nil,
        recurrenceRule: String? = nil,
        recurrenceEndDate: Date? = nil,
        linkedTasks: NSSet? = nil
    ) -> Result<Void, Error> {
        updateEventCallCount += 1
        
        guard !shouldFailOperations else {
            lastError = "Mock error: Operation failed"
            return .failure(ScheduleError.invalidTimeRange)
        }
        
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
        
        return .success(())
    }
    
    func deleteEvent(_ event: Event) -> Result<Void, Error> {
        deleteEventCallCount += 1
        
        guard !shouldFailOperations else {
            lastError = "Mock error: Operation failed"
            return .failure(ScheduleError.eventNotFound)
        }
        
        guard let eventId = event.id else {
            return .failure(ScheduleError.eventNotFound)
        }
        
        mockEventsById.removeValue(forKey: eventId)
        events.removeAll { $0.id == eventId }
        
        return .success(())
    }
    
    // MARK: - Event Queries
    
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
        let calendar = Calendar.current
        
        return events.filter { event in
            guard let eventStart = event.startTime else { return false }
            return calendar.isDate(eventStart, inSameDayAs: date)
        }.sorted { ($0.startTime ?? Date.distantPast) < ($1.startTime ?? Date.distantPast) }
    }
    
    func preloadEvents(for dates: [Date]) {
        // Mock implementation - no actual preloading needed
    }
    
    // MARK: - Category Management
    
    func getCategories() -> [Category] {
        return categories
    }
    
    func createCategory(name: String, icon: String, colorHex: String) -> Result<Category, Error> {
        guard !shouldFailOperations else {
            lastError = "Mock error: Operation failed"
            return .failure(ScheduleError.invalidCategoryName)
        }
        
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(ScheduleError.invalidCategoryName)
        }
        
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        let category = Category(context: context)
        category.id = UUID()
        category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        category.iconName = icon
        category.colorHex = colorHex
        category.isActive = true
        category.isDefault = false
        category.sortOrder = Int32(categories.count)
        category.createdAt = Date()
        
        mockCategoriesById[category.id!] = category
        categories.append(category)
        
        return .success(category)
    }
    
    // MARK: - Refresh
    
    func forceRefresh() {
        refreshCallCount += 1
        isLoading = true
        
        // Simulate async refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isLoading = false
        }
    }
    
    // MARK: - Test Helpers
    
    /// Reset all mock state
    func reset() {
        events.removeAll()
        categories.removeAll()
        mockEventsById.removeAll()
        mockCategoriesById.removeAll()
        isLoading = false
        lastError = nil
        shouldFailOperations = false
        createEventCallCount = 0
        updateEventCallCount = 0
        deleteEventCallCount = 0
        refreshCallCount = 0
    }
    
    /// Add mock events for testing
    func addMockEvents(_ mockEvents: [Event]) {
        for event in mockEvents {
            if let id = event.id {
                mockEventsById[id] = event
            }
        }
        events.append(contentsOf: mockEvents)
    }
    
    /// Add mock categories for testing
    func addMockCategories(_ mockCategories: [Category]) {
        for category in mockCategories {
            if let id = category.id {
                mockCategoriesById[id] = category
            }
        }
        categories.append(contentsOf: mockCategories)
    }
}