import XCTest
import CoreData
@testable import Momentum

class EventTests: XCTestCase {
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        context = TestPersistenceController.createTestContext()
    }
    
    override func tearDown() {
        context = nil
        super.tearDown()
    }
    
    // MARK: - Basic Event Creation Tests
    
    func testEventCreation() {
        // Given
        let event = Event(context: context)
        let testDate = Date()
        
        // When
        event.id = UUID()
        event.title = "Test Event"
        event.startTime = testDate
        event.endTime = testDate.addingTimeInterval(3600)
        event.dataSource = "manual"
        event.createdAt = testDate
        event.modifiedAt = testDate
        event.isCompleted = false
        event.colorHex = "#007AFF"
        
        // Then
        XCTAssertNotNil(event.id)
        XCTAssertEqual(event.title, "Test Event")
        XCTAssertEqual(event.startTime, testDate)
        XCTAssertEqual(event.endTime, testDate.addingTimeInterval(3600))
        XCTAssertEqual(event.dataSource, "manual")
        XCTAssertEqual(event.isCompleted, false)
        XCTAssertEqual(event.colorHex, "#007AFF")
    }
    
    func testEventWithCategory() {
        // Given
        let category = TestDataFactory.createTestCategory(in: context, name: "Work")
        let event = TestDataFactory.createTestEvent(in: context, category: category)
        
        // Then
        XCTAssertNotNil(event.category)
        XCTAssertEqual(event.category?.name, "Work")
        XCTAssertEqual(event.colorHex, category.colorHex)
    }
    
    func testEventWithAllProperties() {
        // Given
        let event = Event(context: context)
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(7200) // 2 hours
        
        // When
        event.id = UUID()
        event.title = "Complete Event"
        event.startTime = startTime
        event.endTime = endTime
        event.notes = "Test notes"
        event.location = "Test location"
        event.url = "https://example.com"
        event.priority = "high"
        event.tags = "test,event"
        event.energyLevel = "high"
        event.weatherRequired = "sunny"
        event.bufferTimeBefore = 15
        event.bufferTimeAfter = 10
        event.iconName = "star.fill"
        event.externalAppID = "com.example.app"
        event.externalEventID = "external-123"
        event.syncToken = "sync-token-123"
        event.dataSource = "external"
        event.isCompleted = false
        event.colorHex = "#FF0000"
        event.createdAt = Date()
        event.modifiedAt = Date()
        
        // Then
        XCTAssertNotNil(event.id)
        XCTAssertEqual(event.title, "Complete Event")
        XCTAssertEqual(event.notes, "Test notes")
        XCTAssertEqual(event.location, "Test location")
        XCTAssertEqual(event.url, "https://example.com")
        XCTAssertEqual(event.priority, "high")
        XCTAssertEqual(event.tags, "test,event")
        XCTAssertEqual(event.energyLevel, "high")
        XCTAssertEqual(event.weatherRequired, "sunny")
        XCTAssertEqual(event.bufferTimeBefore, 15)
        XCTAssertEqual(event.bufferTimeAfter, 10)
        XCTAssertEqual(event.iconName, "star.fill")
        XCTAssertEqual(event.externalAppID, "com.example.app")
        XCTAssertEqual(event.externalEventID, "external-123")
        XCTAssertEqual(event.syncToken, "sync-token-123")
        XCTAssertEqual(event.dataSource, "external")
        XCTAssertEqual(event.colorHex, "#FF0000")
    }
    
    // MARK: - Event Duration Tests
    
    func testEventDuration() {
        // Given
        let event = Event(context: context)
        let startTime = Date.testDate(hour: 10, minute: 0)
        let endTime = Date.testDate(hour: 11, minute: 30)
        
        // When
        event.startTime = startTime
        event.endTime = endTime
        
        // Then
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertEqual(duration, 5400) // 90 minutes in seconds
    }
    
    func testAllDayEvent() {
        // Given
        let event = Event(context: context)
        let calendar = Calendar.current
        let date = Date()
        
        // When
        event.startTime = calendar.startOfDay(for: date)
        event.endTime = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
        event.notes = "All day event [ALL_DAY]"
        
        // Then
        XCTAssertTrue(event.notes?.contains("[ALL_DAY]") ?? false)
        let duration = event.endTime!.timeIntervalSince(event.startTime!)
        XCTAssertEqual(duration, 86400) // 24 hours in seconds
    }
    
    // MARK: - Event Completion Tests
    
    func testEventCompletion() {
        // Given
        let event = TestDataFactory.createTestEvent(in: context)
        let completionDate = Date()
        
        // When
        event.isCompleted = true
        event.completedAt = completionDate
        event.completionDuration = 45 // minutes
        
        // Then
        XCTAssertTrue(event.isCompleted)
        XCTAssertEqual(event.completedAt, completionDate)
        XCTAssertEqual(event.completionDuration, 45)
    }
    
    func testEventUncompletion() {
        // Given
        let event = TestDataFactory.createTestEvent(in: context)
        event.isCompleted = true
        event.completedAt = Date()
        
        // When
        event.isCompleted = false
        event.completedAt = nil
        
        // Then
        XCTAssertFalse(event.isCompleted)
        XCTAssertNil(event.completedAt)
    }
    
    // MARK: - Event Recurrence Tests
    
    func testRecurringEvent() {
        // Given
        let event = TestDataFactory.createTestEvent(in: context)
        let recurrenceID = UUID()
        let endDate = Date().addingTimeInterval(86400 * 30) // 30 days
        
        // When
        event.recurrenceID = recurrenceID
        event.recurrenceRule = "FREQ=DAILY;COUNT=30"
        event.recurrenceEndDate = endDate
        
        // Then
        XCTAssertEqual(event.recurrenceID, recurrenceID)
        XCTAssertEqual(event.recurrenceRule, "FREQ=DAILY;COUNT=30")
        XCTAssertEqual(event.recurrenceEndDate, endDate)
    }
    
    // MARK: - Event Validation Tests
    
    func testEventWithInvalidTimeRange() {
        // Given
        let event = Event(context: context)
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(-3600) // End before start
        
        // When
        event.startTime = startTime
        event.endTime = endTime
        
        // Then
        XCTAssertTrue(event.endTime! < event.startTime!)
    }
    
    func testEventWithEmptyTitle() {
        // Given
        let event = Event(context: context)
        
        // When
        event.title = ""
        event.startTime = Date()
        event.endTime = Date().addingTimeInterval(3600)
        
        // Then
        XCTAssertEqual(event.title, "")
    }
    
    // MARK: - Core Data Save Tests
    
    func testSaveEvent() throws {
        // Given
        let event = TestDataFactory.createTestEvent(in: context, title: "Save Test")
        
        // When
        try context.save()
        
        // Then
        let fetchRequest: NSFetchRequest<Event> = Event.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@", "Save Test")
        
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Save Test")
    }
    
    func testSaveMultipleEvents() throws {
        // Given
        let events = TestDataFactory.createEventsForDay(
            in: context,
            date: Date(),
            count: 10
        )
        
        // When
        try context.save()
        
        // Then
        let fetchRequest: NSFetchRequest<Event> = Event.fetchRequest()
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 10)
    }
    
    // MARK: - Event Fetching Tests
    
    func testFetchEventsByDate() throws {
        // Given
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        _ = TestDataFactory.createEventsForDay(in: context, date: today, count: 3)
        _ = TestDataFactory.createEventsForDay(in: context, date: tomorrow, count: 2)
        
        try context.save()
        
        // When
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        let startOfTomorrow = calendar.startOfDay(for: tomorrow)
        
        let fetchRequest: NSFetchRequest<Event> = Event.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime < %@",
            startOfToday as NSDate,
            startOfTomorrow as NSDate
        )
        
        // Then
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 3)
    }
    
    func testFetchEventsByCategory() throws {
        // Given
        let workCategory = TestDataFactory.createTestCategory(in: context, name: "Work")
        let personalCategory = TestDataFactory.createTestCategory(in: context, name: "Personal")
        
        _ = TestDataFactory.createTestEvent(in: context, title: "Work Event 1", category: workCategory)
        _ = TestDataFactory.createTestEvent(in: context, title: "Work Event 2", category: workCategory)
        _ = TestDataFactory.createTestEvent(in: context, title: "Personal Event", category: personalCategory)
        
        try context.save()
        
        // When
        let fetchRequest: NSFetchRequest<Event> = Event.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "category == %@", workCategory)
        
        // Then
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.category?.name == "Work" })
    }
    
    // MARK: - Edge Cases
    
    func testEventWithNilValues() {
        // Given
        let event = Event(context: context)
        
        // When
        event.id = UUID()
        event.title = "Minimal Event"
        event.startTime = Date()
        event.endTime = Date().addingTimeInterval(3600)
        event.dataSource = "manual"
        event.createdAt = Date()
        event.modifiedAt = Date()
        event.colorHex = "#007AFF"
        // Leave optional fields as nil
        
        // Then
        XCTAssertNil(event.notes)
        XCTAssertNil(event.location)
        XCTAssertNil(event.category)
        XCTAssertNil(event.url)
        XCTAssertNil(event.priority)
        XCTAssertNil(event.tags)
        XCTAssertNil(event.completedAt)
        XCTAssertNil(event.recurrenceID)
        XCTAssertNil(event.recurrenceRule)
    }
    
    func testEventWithVeryLongTitle() {
        // Given
        let event = Event(context: context)
        let longTitle = String(repeating: "A", count: 1000)
        
        // When
        event.title = longTitle
        
        // Then
        XCTAssertEqual(event.title?.count, 1000)
    }
    
    func testEventWithSpecialCharactersInTitle() {
        // Given
        let event = Event(context: context)
        let specialTitle = "Test 😀 Event with \"quotes\" & <tags> and 日本語"
        
        // When
        event.title = specialTitle
        
        // Then
        XCTAssertEqual(event.title, specialTitle)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceOfEventCreation() {
        measure {
            for _ in 0..<100 {
                _ = TestDataFactory.createTestEvent(in: context)
            }
        }
    }
    
    func testPerformanceOfEventFetching() throws {
        // Setup
        for i in 0..<1000 {
            let event = TestDataFactory.createTestEvent(
                in: context,
                title: "Event \(i)"
            )
            event.startTime = Date().addingTimeInterval(Double(i) * 3600)
        }
        try context.save()
        
        // Measure
        measure {
            let fetchRequest: NSFetchRequest<Event> = Event.fetchRequest()
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \Event.startTime, ascending: true)
            ]
            _ = try? context.fetch(fetchRequest)
        }
    }
}