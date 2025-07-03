import XCTest
import Combine
@testable import Momentum

@MainActor
class DayViewModelTests: XCTestCase {
    var viewModel: DayViewModel!
    var context: NSManagedObjectContext!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        context = TestPersistenceController.createTestContext()
        viewModel = DayViewModel()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        viewModel = nil
        context = nil
        cancellables = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        // Given/When - viewModel created in setUp
        
        // Then
        XCTAssertNotNil(viewModel.selectedDate)
        XCTAssertTrue(viewModel.events.isEmpty)
        XCTAssertFalse(viewModel.showingAddEvent)
        XCTAssertNil(viewModel.selectedEvent)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.newEventStartTime)
    }
    
    func testSelectedDateStartsAsToday() {
        // Given/When - viewModel created in setUp
        
        // Then
        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDateInToday(viewModel.selectedDate))
    }
    
    // MARK: - Event Loading Tests
    
    func testRefreshEvents() async {
        // Given
        let expectation = XCTestExpectation(description: "Events loaded")
        
        viewModel.$events
            .dropFirst() // Skip initial empty value
            .sink { events in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        viewModel.refreshEvents()
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testDateChangeTriggersEventLoad() async {
        // Given
        let expectation = XCTestExpectation(description: "Events reloaded on date change")
        expectation.expectedFulfillmentCount = 2 // Initial load + date change
        
        viewModel.$events
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        viewModel.selectedDate = Date.testDate(year: 2025, month: 7, day: 1)
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Event Position and Layout Tests
    
    func testCalculateEventPosition() {
        // Given
        let event9AM = TestDataFactory.createTestEvent(
            in: context,
            startTime: Date.todayAt(hour: 9, minute: 0)
        )
        let event2_30PM = TestDataFactory.createTestEvent(
            in: context,
            startTime: Date.todayAt(hour: 14, minute: 30)
        )
        
        // When
        let position9AM = viewModel.calculateEventPosition(event9AM)
        let position2_30PM = viewModel.calculateEventPosition(event2_30PM)
        
        // Then
        XCTAssertEqual(position9AM, 9 * 68) // 9 hours * 68pt per hour
        XCTAssertEqual(position2_30PM, 14.5 * 68) // 14.5 hours * 68pt per hour
    }
    
    func testCalculateEventHeight() {
        // Given
        let event30Min = TestDataFactory.createTestEvent(
            in: context,
            startTime: Date.todayAt(hour: 10),
            endTime: Date.todayAt(hour: 10, minute: 30)
        )
        let event2Hours = TestDataFactory.createTestEvent(
            in: context,
            startTime: Date.todayAt(hour: 10),
            endTime: Date.todayAt(hour: 12)
        )
        let event15Min = TestDataFactory.createTestEvent(
            in: context,
            startTime: Date.todayAt(hour: 10),
            endTime: Date.todayAt(hour: 10, minute: 15)
        )
        
        // When
        let height30Min = viewModel.calculateEventHeight(event30Min)
        let height2Hours = viewModel.calculateEventHeight(event2Hours)
        let height15Min = viewModel.calculateEventHeight(event15Min)
        
        // Then
        XCTAssertEqual(height30Min, 0.5 * 68) // 30 min = 0.5 hour * 68pt
        XCTAssertEqual(height2Hours, 2 * 68) // 2 hours * 68pt
        XCTAssertEqual(height15Min, 44) // Minimum height for tappability
    }
    
    func testCalculateEventLayoutNoOverlap() {
        // Given
        let event1 = TestDataFactory.createTestEvent(
            in: context,
            startTime: Date.todayAt(hour: 9),
            endTime: Date.todayAt(hour: 10)
        )
        let event2 = TestDataFactory.createTestEvent(
            in: context,
            startTime: Date.todayAt(hour: 11),
            endTime: Date.todayAt(hour: 12)
        )
        let event3 = TestDataFactory.createTestEvent(
            in: context,
            startTime: Date.todayAt(hour: 14),
            endTime: Date.todayAt(hour: 15)
        )
        
        // When
        let layouts = viewModel.calculateEventLayout(for: [event1, event2, event3])
        
        // Then
        XCTAssertEqual(layouts.count, 3)
        layouts.forEach { layout in
            XCTAssertEqual(layout.column, 0) // All in first column
            XCTAssertEqual(layout.totalColumns, 1) // Only one column needed
            XCTAssertEqual(layout.widthMultiplier, 1.0) // Full width
        }
    }
    
    func testCalculateEventLayoutWithOverlap() {
        // Given
        let event1 = TestDataFactory.createTestEvent(
            in: context,
            startTime: Date.todayAt(hour: 10),
            endTime: Date.todayAt(hour: 12)
        )
        let event2 = TestDataFactory.createTestEvent(
            in: context,
            startTime: Date.todayAt(hour: 11),
            endTime: Date.todayAt(hour: 13)
        )
        let event3 = TestDataFactory.createTestEvent(
            in: context,
            startTime: Date.todayAt(hour: 11, minute: 30),
            endTime: Date.todayAt(hour: 12, minute: 30)
        )
        
        // When
        let layouts = viewModel.calculateEventLayout(for: [event1, event2, event3])
        
        // Then
        XCTAssertEqual(layouts.count, 3)
        
        // Event 1 should be in column 0
        XCTAssertEqual(layouts[0].column, 0)
        
        // Event 2 should be in column 1 (overlaps with event 1)
        XCTAssertEqual(layouts[1].column, 1)
        
        // Event 3 should be in column 2 (overlaps with both)
        XCTAssertEqual(layouts[2].column, 2)
        
        // All should show 3 total columns
        layouts.forEach { layout in
            XCTAssertEqual(layout.totalColumns, 3)
            XCTAssertEqual(layout.widthMultiplier, 1.0/3.0)
        }
    }
    
    // MARK: - User Interaction Tests
    
    func testHandleTimelineTapOnEmptySpace() {
        // Given
        viewModel.events = []
        XCTAssertFalse(viewModel.showingAddEvent)
        
        // When
        viewModel.handleTimelineTap(at: 14, minute: 30)
        
        // Then
        XCTAssertTrue(viewModel.showingAddEvent)
        XCTAssertNotNil(viewModel.newEventStartTime)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: viewModel.newEventStartTime!)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 30)
    }
    
    func testHandleTimelineTapOnExistingEvent() {
        // Given
        let event = TestDataFactory.createTestEvent(
            in: context,
            startTime: Date.todayAt(hour: 14),
            endTime: Date.todayAt(hour: 15)
        )
        viewModel.events = [event]
        
        // When
        viewModel.handleTimelineTap(at: 14, minute: 30)
        
        // Then
        XCTAssertEqual(viewModel.selectedEvent?.id, event.id)
        XCTAssertFalse(viewModel.showingAddEvent)
    }
    
    func testHandleEventTap() {
        // Given
        let event = TestDataFactory.createTestEvent(in: context)
        
        // When
        viewModel.handleEventTap(event)
        
        // Then
        XCTAssertEqual(viewModel.selectedEvent?.id, event.id)
    }
    
    // MARK: - Date Navigation Tests
    
    func testGoToToday() {
        // Given
        viewModel.selectedDate = Date.testDate(year: 2025, month: 1, day: 1)
        
        // When
        viewModel.goToToday()
        
        // Then
        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDateInToday(viewModel.selectedDate))
    }
    
    func testGoToPreviousDay() {
        // Given
        let startDate = Date.testDate(year: 2025, month: 6, day: 30)
        viewModel.selectedDate = startDate
        
        // When
        viewModel.goToPreviousDay()
        
        // Then
        let expectedDate = Calendar.current.date(byAdding: .day, value: -1, to: startDate)!
        XCTAssertEqual(
            Calendar.current.startOfDay(for: viewModel.selectedDate),
            Calendar.current.startOfDay(for: expectedDate)
        )
    }
    
    func testGoToNextDay() {
        // Given
        let startDate = Date.testDate(year: 2025, month: 6, day: 30)
        viewModel.selectedDate = startDate
        
        // When
        viewModel.goToNextDay()
        
        // Then
        let expectedDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
        XCTAssertEqual(
            Calendar.current.startOfDay(for: viewModel.selectedDate),
            Calendar.current.startOfDay(for: expectedDate)
        )
    }
    
    // MARK: - Date Title Tests
    
    func testDateTitleToday() {
        // Given
        viewModel.selectedDate = Date()
        
        // When
        let title = viewModel.dateTitle
        
        // Then
        XCTAssertEqual(title, "Today")
    }
    
    func testDateTitleYesterday() {
        // Given
        let calendar = Calendar.current
        viewModel.selectedDate = calendar.date(byAdding: .day, value: -1, to: Date())!
        
        // When
        let title = viewModel.dateTitle
        
        // Then
        XCTAssertEqual(title, "Yesterday")
    }
    
    func testDateTitleTomorrow() {
        // Given
        let calendar = Calendar.current
        viewModel.selectedDate = calendar.date(byAdding: .day, value: 1, to: Date())!
        
        // When
        let title = viewModel.dateTitle
        
        // Then
        XCTAssertEqual(title, "Tomorrow")
    }
    
    func testDateTitleCustomDate() {
        // Given
        viewModel.selectedDate = Date.testDate(year: 2025, month: 7, day: 4)
        
        // When
        let title = viewModel.dateTitle
        
        // Then
        XCTAssertTrue(title.contains("Friday"))
        XCTAssertTrue(title.contains("Jul"))
        XCTAssertTrue(title.contains("4"))
    }
    
    func testPreviousDayTitle() {
        // Given
        viewModel.selectedDate = Date()
        
        // When
        let title = viewModel.previousDayTitle
        
        // Then
        XCTAssertEqual(title, "Yesterday")
    }
    
    func testNextDayTitle() {
        // Given
        viewModel.selectedDate = Date()
        
        // When
        let title = viewModel.nextDayTitle
        
        // Then
        XCTAssertEqual(title, "Tomorrow")
    }
    
    // MARK: - Helper Property Tests
    
    func testHasEventsWhenEmpty() {
        // Given
        viewModel.events = []
        
        // When/Then
        XCTAssertFalse(viewModel.hasEvents)
    }
    
    func testHasEventsWhenNotEmpty() {
        // Given
        viewModel.events = [TestDataFactory.createTestEvent(in: context)]
        
        // When/Then
        XCTAssertTrue(viewModel.hasEvents)
    }
    
    // MARK: - Edge Cases
    
    func testEventLayoutWithManyOverlappingEvents() {
        // Given - Create 10 events all overlapping at 2pm
        let events = (0..<10).map { i in
            TestDataFactory.createTestEvent(
                in: context,
                title: "Event \(i)",
                startTime: Date.todayAt(hour: 14, minute: i * 5),
                endTime: Date.todayAt(hour: 15, minute: 30)
            )
        }
        
        // When
        let layouts = viewModel.calculateEventLayout(for: events)
        
        // Then
        XCTAssertEqual(layouts.count, 10)
        
        // Each event should be in its own column
        for (index, layout) in layouts.enumerated() {
            XCTAssertEqual(layout.column, index)
        }
        
        // All should show 10 total columns
        layouts.forEach { layout in
            XCTAssertEqual(layout.totalColumns, 10)
            XCTAssertEqual(layout.widthMultiplier, 0.1)
        }
    }
    
    func testEventPositionAtMidnight() {
        // Given
        let midnightEvent = TestDataFactory.createTestEvent(
            in: context,
            startTime: Calendar.current.startOfDay(for: Date())
        )
        
        // When
        let position = viewModel.calculateEventPosition(midnightEvent)
        
        // Then
        XCTAssertEqual(position, 0)
    }
    
    func testEventPositionAt11_59PM() {
        // Given
        let lateEvent = TestDataFactory.createTestEvent(
            in: context,
            startTime: Date.todayAt(hour: 23, minute: 59)
        )
        
        // When
        let position = viewModel.calculateEventPosition(lateEvent)
        
        // Then
        let expected = (23 + 59.0/60.0) * 68
        XCTAssertEqual(position, expected, accuracy: 0.1)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceOfEventLayout() {
        // Given - Create 100 events with various overlaps
        var events: [Event] = []
        for day in 0..<10 {
            for hour in 9..<18 {
                let event = TestDataFactory.createTestEvent(
                    in: context,
                    startTime: Date.todayAt(hour: hour, minute: day * 5),
                    endTime: Date.todayAt(hour: hour + 1, minute: 30)
                )
                events.append(event)
            }
        }
        
        // When/Then
        measure {
            _ = viewModel.calculateEventLayout(for: events)
        }
    }
}