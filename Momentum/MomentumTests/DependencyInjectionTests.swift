import XCTest
import CoreData
@testable import Momentum

@MainActor
class DependencyInjectionTests: XCTestCase {
    
    var container: DependencyContainer!
    var mockPersistence: MockPersistenceProvider!
    var mockScheduleManager: MockScheduleManager!
    var mockScrollManager: MockScrollPositionManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock dependencies
        mockPersistence = MockPersistenceProvider()
        mockScheduleManager = MockScheduleManager()
        mockScrollManager = MockScrollPositionManager()
        
        // Create container with mocks
        container = DependencyContainer(
            persistenceProvider: mockPersistence,
            scheduleManager: mockScheduleManager,
            scrollPositionManager: mockScrollManager
        )
    }
    
    override func tearDown() async throws {
        container = nil
        mockPersistence = nil
        mockScheduleManager = nil
        mockScrollManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Container Tests
    
    func testContainerInitialization() {
        XCTAssertNotNil(container.persistenceProvider)
        XCTAssertNotNil(container.scheduleManager)
        XCTAssertNotNil(container.scrollPositionManager)
        
        XCTAssertTrue(container.persistenceProvider is MockPersistenceProvider)
        XCTAssertTrue(container.scheduleManager is MockScheduleManager)
        XCTAssertTrue(container.scrollPositionManager is MockScrollPositionManager)
    }
    
    func testSharedContainerUsesRealImplementations() {
        let sharedContainer = DependencyContainer.shared
        
        XCTAssertTrue(sharedContainer.persistenceProvider is PersistenceController)
        XCTAssertTrue(sharedContainer.scheduleManager is ScheduleManager)
        XCTAssertTrue(sharedContainer.scrollPositionManager is ScrollPositionManager)
    }
    
    func testTestContainerFactory() {
        let testContainer = DependencyContainer.makeTestContainer()
        
        XCTAssertTrue(testContainer.persistenceProvider is MockPersistenceProvider)
        XCTAssertTrue(testContainer.scheduleManager is MockScheduleManager)
        XCTAssertTrue(testContainer.scrollPositionManager is MockScrollPositionManager)
    }
    
    // MARK: - Schedule Manager DI Tests
    
    func testScheduleManagerCreateEvent() async {
        // Given
        let title = "DI Test Event"
        let startTime = Date()
        let endTime = Date().addingTimeInterval(3600)
        
        // When
        let result = mockScheduleManager.createEvent(
            title: title,
            startTime: startTime,
            endTime: endTime,
            category: nil,
            notes: nil,
            location: nil,
            isAllDay: false
        )
        
        // Then
        switch result {
        case .success(let event):
            XCTAssertEqual(event.title, title)
            XCTAssertEqual(mockScheduleManager.createEventCallCount, 1)
        case .failure:
            XCTFail("Event creation should succeed")
        }
    }
    
    func testScheduleManagerUpdateEvent() async {
        // Given
        let context = mockPersistence.container.viewContext
        let event = TestDataFactory.createTestEvent(in: context, title: "Original")
        mockScheduleManager.addMockEvents([event])
        let newTitle = "Updated via DI"
        
        // When
        let result = mockScheduleManager.updateEvent(event, title: newTitle)
        
        // Then
        switch result {
        case .success:
            XCTAssertEqual(event.title, newTitle)
            XCTAssertEqual(mockScheduleManager.updateEventCallCount, 1)
        case .failure:
            XCTFail("Event update should succeed")
        }
    }
    
    func testScheduleManagerDeleteEvent() async {
        // Given
        let context = mockPersistence.container.viewContext
        let event = TestDataFactory.createTestEvent(in: context)
        mockScheduleManager.addMockEvents([event])
        
        // When
        let result = mockScheduleManager.deleteEvent(event)
        
        // Then
        switch result {
        case .success:
            XCTAssertEqual(mockScheduleManager.deleteEventCallCount, 1)
            XCTAssertFalse(mockScheduleManager.events.contains { $0.id == event.id })
        case .failure:
            XCTFail("Event deletion should succeed")
        }
    }
    
    func testScheduleManagerEventQueries() {
        // Given
        let context = mockPersistence.container.viewContext
        let today = Date()
        let todayEvents = TestDataFactory.createEventsForDay(in: context, date: today, count: 3)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let tomorrowEvents = TestDataFactory.createEventsForDay(in: context, date: tomorrow, count: 2)
        
        mockScheduleManager.addMockEvents(todayEvents + tomorrowEvents)
        
        // When
        let todayFiltered = mockScheduleManager.events(for: today)
        let tomorrowFiltered = mockScheduleManager.events(for: tomorrow)
        
        // Then
        XCTAssertEqual(todayFiltered.count, 3)
        XCTAssertEqual(tomorrowFiltered.count, 2)
    }
    
    // MARK: - Persistence Provider DI Tests
    
    func testPersistenceProviderSave() {
        // Given
        let initialCount = mockPersistence.saveCallCount
        
        // When
        mockPersistence.save()
        
        // Then
        XCTAssertEqual(mockPersistence.saveCallCount, initialCount + 1)
    }
    
    func testPersistenceProviderPerformAndMeasure() throws {
        // Given
        let operation = "Test Operation"
        var operationExecuted = false
        
        // When
        let result = try mockPersistence.performAndMeasure(operation) {
            operationExecuted = true
            return "Success"
        }
        
        // Then
        XCTAssertEqual(result, "Success")
        XCTAssertTrue(operationExecuted)
        XCTAssertEqual(mockPersistence.lastPerformedOperation, operation)
    }
    
    // MARK: - Scroll Position Manager DI Tests
    
    func testScrollPositionManagerOffset() {
        // Given
        mockScrollManager.setOffset(500, for: 0)
        
        // When
        let offset = mockScrollManager.offset(for: 0)
        
        // Then
        XCTAssertEqual(offset, 500)
        XCTAssertEqual(mockScrollManager.offsetCallCount, 1)
    }
    
    func testScrollPositionManagerUpdate() {
        // Given
        let dayOffset = 1
        let newValue: CGFloat = 750
        
        // When
        mockScrollManager.update(dayOffset: dayOffset, to: newValue)
        
        // Then
        XCTAssertEqual(mockScrollManager.offsets[dayOffset], 750)
        XCTAssertEqual(mockScrollManager.updateCallCount, 1)
        XCTAssertEqual(mockScrollManager.lastUpdatedDayOffset, dayOffset)
        XCTAssertEqual(mockScrollManager.lastUpdatedValue, newValue)
    }
    
    // MARK: - Integration Tests
    
    func testViewModelWithDI() {
        // Given
        let viewModel = DayViewModel(scheduleManager: mockScheduleManager)
        let context = mockPersistence.container.viewContext
        
        // Create test events
        let events = TestDataFactory.createEventsForDay(in: context, date: Date(), count: 3)
        mockScheduleManager.addMockEvents(events)
        
        // When
        viewModel.refreshEvents()
        
        // Wait for async operations
        let expectation = XCTestExpectation(description: "Events loaded")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(viewModel.events.count, 3)
    }
    
    func testScheduleManagerWithCustomPersistence() {
        // Given
        let customScheduleManager = ScheduleManager(persistence: mockPersistence)
        
        // When
        mockPersistence.createTestCategories()
        
        // Then
        // The schedule manager should pick up the categories through Core Data
        let expectation = XCTestExpectation(description: "Categories loaded")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertGreaterThan(customScheduleManager.categories.count, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testScheduleManagerFailureScenarios() {
        // Given
        mockScheduleManager.shouldFailOperations = true
        
        // When
        let createResult = mockScheduleManager.createEvent(
            title: "Test",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            category: nil,
            notes: nil,
            location: nil,
            isAllDay: false
        )
        
        // Then
        switch createResult {
        case .success:
            XCTFail("Operation should fail when shouldFailOperations is true")
        case .failure:
            XCTAssertNotNil(mockScheduleManager.lastError)
        }
    }
    
    func testPersistenceProviderFailureScenarios() {
        // Given
        mockPersistence.shouldFailSave = true
        let context = mockPersistence.container.viewContext
        
        // Create a test object
        let category = Category(context: context)
        category.id = UUID()
        category.name = "Test Category"
        
        // When
        mockPersistence.save()
        
        // Then
        XCTAssertEqual(mockPersistence.saveCallCount, 1)
        // The mock should handle the failure gracefully
    }
}