import Foundation
import CoreData
import Combine

/// Protocol defining the interface for schedule management operations
@MainActor
protocol ScheduleManaging: AnyObject {
    // MARK: - Published Properties
    var events: [Event] { get }
    var categories: [Category] { get }
    var isLoading: Bool { get }
    var lastError: String? { get }
    
    // MARK: - Publisher for updates
    var eventsPublisher: AnyPublisher<[Event], Never> { get }
    
    // MARK: - Event CRUD Operations
    func createEvent(
        title: String,
        startTime: Date,
        endTime: Date,
        category: Category?,
        notes: String?,
        location: String?,
        isAllDay: Bool,
        recurrenceRule: String?,
        recurrenceID: UUID?,
        recurrenceEndDate: Date?
    ) -> Result<Event, Error>
    
    // Add conflict detection
    func checkForConflicts(startTime: Date, endTime: Date, excludingEvent: Event?) -> [Event]
    
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
    ) -> Result<Void, Error>
    
    func deleteEvent(_ event: Event) -> Result<Void, Error>
    
    // MARK: - Event Queries
    func eventsForToday() -> [Event]
    func eventsForWeek() -> [Event]
    func eventsForMonth() -> [Event]
    func events(for date: Date) -> [Event]
    func preloadEvents(for dates: [Date])
    
    // MARK: - Category Management
    func createCategory(name: String, icon: String, colorHex: String) -> Result<Category, Error>
    func getCategories() -> [Category]
    
    // MARK: - Refresh
    func forceRefresh()
}

// MARK: - Default implementations
extension ScheduleManaging {
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
        return createEvent(
            title: title,
            startTime: startTime,
            endTime: endTime,
            category: category,
            notes: notes,
            location: location,
            isAllDay: isAllDay,
            recurrenceRule: recurrenceRule,
            recurrenceID: recurrenceID,
            recurrenceEndDate: recurrenceEndDate
        )
    }
}