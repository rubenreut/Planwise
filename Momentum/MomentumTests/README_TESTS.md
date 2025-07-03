# Momentum Test Suite

## Overview

This test suite provides comprehensive unit testing for the Momentum iOS app, covering:
- Core Data models (Event, Category)
- Business logic (ScheduleManager)
- View models (DayViewModel)
- Edge cases and error conditions

## Test Structure

### Test Files

1. **TestHelpers.swift**
   - Mock objects and factories
   - Test Core Data stack setup
   - Common test utilities

2. **EventTests.swift**
   - Event model creation and validation
   - Core Data persistence
   - Event relationships
   - Edge cases (invalid dates, empty titles, etc.)

3. **CategoryTests.swift**
   - Category model testing
   - Category-Event relationships
   - Sorting and filtering

4. **ScheduleManagerTests.swift**
   - Event CRUD operations
   - Date filtering
   - Category management
   - Performance and caching

5. **DayViewModelTests.swift**
   - Event loading and display
   - Event positioning calculations
   - User interaction handling
   - Date navigation

## Running Tests

### Command Line
```bash
# Run all tests
xcodebuild test -scheme Momentum -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -scheme Momentum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MomentumTests/EventTests

# Run with code coverage
xcodebuild test -scheme Momentum -enableCodeCoverage YES
```

### Xcode
1. Open Momentum.xcodeproj
2. Press `Cmd+U` to run all tests
3. Or click the diamond icon next to individual test methods

## Test Best Practices

### 1. Use Test Helpers
```swift
// Good
let event = TestDataFactory.createTestEvent(in: context)

// Avoid
let event = Event(context: context)
event.id = UUID()
event.title = "Test"
// ... many more properties
```

### 2. Test One Thing Per Test
```swift
// Good
func testEventCreationWithEmptyTitle() { }
func testEventCreationWithInvalidTimeRange() { }

// Avoid
func testEventValidation() { 
    // Tests multiple validation rules
}
```

### 3. Use Descriptive Test Names
```swift
// Good
func testUpdateEventWithOverlappingTimesShouldSucceed()

// Avoid
func testUpdate()
```

### 4. Clean Up After Tests
```swift
override func tearDown() {
    context = nil
    super.tearDown()
}
```

### 5. Use Async/Await for Async Tests
```swift
func testAsyncOperation() async throws {
    // Use async/await instead of expectations when possible
    let result = await someAsyncOperation()
    XCTAssertEqual(result, expectedValue)
}
```

## Code Coverage Goals

Target minimum coverage:
- Models: 90%
- ViewModels: 85%
- Managers: 85%
- Overall: 80%

## Performance Testing

Performance tests are included for:
- Event creation (100 events)
- Event fetching (1000 events)
- Event layout calculation (100 overlapping events)

Run performance tests separately as they can be slow:
```bash
xcodebuild test -scheme Momentum -only-testing:MomentumTests/**/testPerformance*
```

## Mock Objects

### MockScheduleManager
- Simulates ScheduleManager without Core Data
- Allows testing failure scenarios
- Tracks method calls for verification

### TestPersistenceController
- Creates in-memory Core Data stack
- Isolated from production data
- Fast test execution

### TestDataFactory
- Creates test objects with sensible defaults
- Reduces boilerplate in tests
- Ensures consistent test data

## Common Test Patterns

### Testing Success Cases
```swift
func testCreateEventSuccess() {
    // Given
    let startTime = Date()
    
    // When
    let result = manager.createEvent(title: "Test", startTime: startTime, ...)
    
    // Then
    switch result {
    case .success(let event):
        XCTAssertEqual(event.title, "Test")
    case .failure:
        XCTFail("Should succeed")
    }
}
```

### Testing Failure Cases
```swift
func testCreateEventWithEmptyTitle() {
    // Given
    let emptyTitle = ""
    
    // When
    let result = manager.createEvent(title: emptyTitle, ...)
    
    // Then
    switch result {
    case .success:
        XCTFail("Should fail")
    case .failure(let error):
        XCTAssertEqual(error as? ScheduleError, .invalidTitle)
    }
}
```

### Testing Async Operations
```swift
func testAsyncEventLoad() async throws {
    // Given
    await createTestEvents()
    
    // When
    viewModel.refreshEvents()
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
    
    // Then
    XCTAssertFalse(viewModel.events.isEmpty)
}
```

## Debugging Failed Tests

1. Check test output for detailed error messages
2. Use breakpoints in test methods
3. Add print statements to track execution
4. Verify test data setup is correct
5. Check for timing issues in async tests

## Adding New Tests

When adding new features:
1. Write tests first (TDD approach)
2. Cover happy path and edge cases
3. Test error conditions
4. Add performance tests for critical paths
5. Update this README with new patterns

## CI/CD Integration

These tests are designed to run in CI/CD pipelines:
- Fast execution (< 30 seconds for unit tests)
- No external dependencies
- Deterministic results
- Clear failure messages