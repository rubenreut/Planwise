# Dependency Injection in Momentum

## Overview

The Momentum app uses a dependency injection (DI) system to improve testability, maintainability, and flexibility. This system allows us to easily swap implementations for testing and provides a clean separation of concerns.

## Architecture

### 1. Protocol Abstractions

All major managers have protocol abstractions that define their interface:

- `ScheduleManaging` - Defines schedule and event management operations
- `PersistenceProviding` - Defines Core Data persistence operations
- `ScrollPositionProviding` - Defines scroll position management

### 2. Dependency Container

The `DependencyContainer` is the central hub for managing dependencies:

```swift
@MainActor
final class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer() // Production singleton
    
    private(set) var persistenceProvider: any PersistenceProviding
    private(set) var scheduleManager: any ScheduleManaging
    private(set) var scrollPositionManager: any ScrollPositionProviding
}
```

### 3. Injection via Environment

Dependencies are injected through SwiftUI's environment system:

```swift
ContentView()
    .environment(\.dependencyContainer, container)
    .environmentObject(container.scheduleManager)
```

## Usage

### Production Code

In production, use the shared container which provides real implementations:

```swift
@main
struct MomentumApp: App {
    @StateObject private var dependencyContainer = DependencyContainer.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .injectDependencies(dependencyContainer)
        }
    }
}
```

### Testing

For tests, create a container with mock implementations:

```swift
let mockPersistence = MockPersistenceProvider()
let mockSchedule = MockScheduleManager()
let mockScroll = MockScrollPositionManager()

let testContainer = DependencyContainer(
    persistenceProvider: mockPersistence,
    scheduleManager: mockSchedule,
    scrollPositionManager: mockScroll
)
```

### ViewModels

ViewModels accept dependencies through their initializers:

```swift
class DayViewModel: ObservableObject {
    private let scheduleManager: any ScheduleManaging
    
    init(scheduleManager: any ScheduleManaging = ScheduleManager.shared) {
        self.scheduleManager = scheduleManager
    }
}
```

## Benefits

1. **Testability** - Easy to test components in isolation with mock dependencies
2. **Flexibility** - Can swap implementations without changing consumer code
3. **Maintainability** - Clear contracts via protocols
4. **Backward Compatibility** - Default parameters ensure existing code continues to work

## Mock Implementations

Mock implementations are provided for all protocols:

- `MockScheduleManager` - Simulates schedule operations with in-memory storage
- `MockPersistenceProvider` - Provides in-memory Core Data stack for testing
- `MockScrollPositionManager` - Tracks scroll position changes for verification

Each mock includes:
- Call counters for verification
- Configurable failure modes
- State inspection methods
- Reset functionality

## Best Practices

1. **Always use protocols** - Depend on protocols, not concrete types
2. **Default to production** - Use default parameters pointing to shared instances
3. **Inject at the top** - Inject dependencies as high in the view hierarchy as possible
4. **Test with mocks** - Always use mocks for unit tests
5. **Keep protocols focused** - Each protocol should have a single responsibility

## Migration Guide

To add DI to existing components:

1. Create a protocol defining the component's public interface
2. Make the component conform to the protocol
3. Add the component to `DependencyContainer`
4. Update consumers to use the protocol type
5. Create a mock implementation for testing
6. Add tests using the mock

## Example Test

```swift
func testEventCreation() async {
    // Given
    let mockScheduleManager = MockScheduleManager()
    let viewModel = DayViewModel(scheduleManager: mockScheduleManager)
    
    // When
    let result = mockScheduleManager.createEvent(
        title: "Test Event",
        startTime: Date(),
        endTime: Date().addingTimeInterval(3600),
        category: nil,
        notes: nil,
        location: nil,
        isAllDay: false
    )
    
    // Then
    XCTAssertEqual(mockScheduleManager.createEventCallCount, 1)
    XCTAssertEqual(mockScheduleManager.events.count, 1)
}
```