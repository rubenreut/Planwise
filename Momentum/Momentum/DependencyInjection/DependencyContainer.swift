import Foundation
import SwiftUI

/// Central container for managing application dependencies
@MainActor
final class DependencyContainer: ObservableObject {
    
    // MARK: - Singleton (Production)
    static let shared = DependencyContainer()
    
    // MARK: - Dependencies
    private(set) var persistenceProvider: any PersistenceProviding
    private(set) var scheduleManager: any ScheduleManaging
    private(set) var scrollPositionManager: any ScrollPositionProviding
    private(set) var openAIService: OpenAIService
    private(set) var taskManager: any TaskManaging
    private(set) var habitManager: any HabitManaging
    private(set) var goalManager: GoalManager
    
    // MARK: - Initialization
    
    /// Private initializer for production singleton
    private init() {
        // Production dependencies
        self.persistenceProvider = PersistenceController.shared
        self.scheduleManager = ScheduleManager.shared
        self.scrollPositionManager = ScrollPositionManager.shared
        self.taskManager = TaskManager.shared
        self.habitManager = HabitManager.shared
        self.goalManager = GoalManager.shared
        #if DEBUG
        self.openAIService = APIConfiguration.useMockService ? MockOpenAIService() : OpenAIService()
        #else
        self.openAIService = OpenAIService()
        #endif
    }
    
    /// Public initializer for testing with dependency injection
    init(
        persistenceProvider: any PersistenceProviding,
        scheduleManager: any ScheduleManaging,
        scrollPositionManager: any ScrollPositionProviding,
        taskManager: (any TaskManaging)? = nil,
        habitManager: (any HabitManaging)? = nil,
        goalManager: GoalManager? = nil,
        openAIService: OpenAIService? = nil
    ) {
        self.persistenceProvider = persistenceProvider
        self.scheduleManager = scheduleManager
        self.scrollPositionManager = scrollPositionManager
        self.taskManager = taskManager ?? TaskManager(persistence: persistenceProvider)
        self.habitManager = habitManager ?? HabitManager.shared
        self.goalManager = goalManager ?? GoalManager.shared
        self.openAIService = openAIService ?? OpenAIService()
    }
    
    // MARK: - Factory Methods for Testing
    
    /// Creates a test container with mock dependencies
    static func makeTestContainer() -> DependencyContainer {
        let mockPersistence = MockPersistenceProvider()
        let mockSchedule = MockScheduleManager()
        let mockScroll = MockScrollPositionManager()
        let mockTasks = MockTaskManager(context: mockPersistence.container.viewContext)
        
        return DependencyContainer(
            persistenceProvider: mockPersistence,
            scheduleManager: mockSchedule,
            scrollPositionManager: mockScroll,
            taskManager: mockTasks
        )
    }
    
    /// Creates a container with a custom configuration
    static func makeContainer(
        with configuration: DependencyConfiguration
    ) -> DependencyContainer {
        return DependencyContainer(
            persistenceProvider: configuration.persistenceProvider,
            scheduleManager: configuration.scheduleManager,
            scrollPositionManager: configuration.scrollPositionManager,
            taskManager: configuration.taskManager,
            openAIService: configuration.openAIService
        )
    }
}

// MARK: - Dependency Configuration
struct DependencyConfiguration {
    let persistenceProvider: any PersistenceProviding
    let scheduleManager: any ScheduleManaging
    let scrollPositionManager: any ScrollPositionProviding
    let taskManager: (any TaskManaging)?
    let openAIService: OpenAIService?
}

// MARK: - Environment Key for SwiftUI
@preconcurrency
private struct DependencyContainerKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = DependencyContainer.shared
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Extension for Easy Access
extension View {
    func injectDependencies(_ container: DependencyContainer) -> some View {
        self.environment(\.dependencyContainer, container)
    }
}