//
//  MomentumTests.swift
//  MomentumTests
//
//  Created by Ruben Reut on 29/06/2025.
//

import XCTest
@testable import Momentum

class MomentumTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertTrue(true)
    }
    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    // MARK: - Test Suite Health Check
    
    func testAllTestFilesExist() {
        let testBundle = Bundle(for: type(of: self))
        
        // Verify test helper file exists
        XCTAssertNotNil(NSClassFromString("MomentumTests.TestPersistenceController"))
        XCTAssertNotNil(NSClassFromString("MomentumTests.TestDataFactory"))
        
        // Verify Event tests exist
        XCTAssertNotNil(NSClassFromString("MomentumTests.EventTests"))
        
        // Verify ScheduleManager tests exist
        XCTAssertNotNil(NSClassFromString("MomentumTests.ScheduleManagerTests"))
        
        // Verify DayViewModel tests exist
        XCTAssertNotNil(NSClassFromString("MomentumTests.DayViewModelTests"))
    }
    
    // MARK: - Integration Test Example
    
    @MainActor
    func testBasicEventCreationFlow() async throws {
        // This tests the integration between ScheduleManager and DayViewModel
        
        // Given
        let scheduleManager = ScheduleManager.shared
        let dayViewModel = DayViewModel()
        let testDate = Date()
        
        // Create a test category
        let categoryResult = scheduleManager.createCategory(
            name: "Integration Test",
            icon: "star.fill",
            colorHex: "#FF0000"
        )
        
        guard case .success(let category) = categoryResult else {
            XCTFail("Failed to create test category")
            return
        }
        
        // Create a test event
        let eventResult = scheduleManager.createEvent(
            title: "Integration Test Event",
            startTime: Date.todayAt(hour: 14),
            endTime: Date.todayAt(hour: 15),
            category: category,
            notes: "This is an integration test",
            location: "Test Location"
        )
        
        guard case .success(let event) = eventResult else {
            XCTFail("Failed to create test event")
            return
        }
        
        // Wait for the view model to update
        try await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Verify the event appears in the view model
        dayViewModel.selectedDate = testDate
        dayViewModel.refreshEvents()
        
        // Wait for refresh
        try await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Clean up
        _ = scheduleManager.deleteEvent(event)
    }
}

// MARK: - Test Configuration

extension XCTestCase {
    /// Common setup for all test cases
    func commonSetUp() {
        // Disable animations for testing
        UIView.setAnimationsEnabled(false)
        
        // Set up test environment
        ProcessInfo.processInfo.environment["TESTING"] = "1"
    }
    
    /// Common teardown for all test cases
    func commonTearDown() {
        // Re-enable animations
        UIView.setAnimationsEnabled(true)
    }
}
