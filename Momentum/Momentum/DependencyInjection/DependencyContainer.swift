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
    
    // MARK: - Initialization
    
    /// Private initializer for production singleton
    private init() {
        // Production dependencies
        self.persistenceProvider = PersistenceController.shared
        self.scheduleManager = ScheduleManager.shared
        self.scrollPositionManager = ScrollPositionManager.shared
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
        openAIService: OpenAIService? = nil
    ) {
        self.persistenceProvider = persistenceProvider
        self.scheduleManager = scheduleManager
        self.scrollPositionManager = scrollPositionManager
        self.openAIService = openAIService ?? OpenAIService()
    }
    
    // MARK: - Factory Methods for Testing
    
    /// Creates a test container with mock dependencies
    static func makeTestContainer() -> DependencyContainer {
        let mockPersistence = MockPersistenceProvider()
        let mockSchedule = MockScheduleManager()
        let mockScroll = MockScrollPositionManager()
        
        return DependencyContainer(
            persistenceProvider: mockPersistence,
            scheduleManager: mockSchedule,
            scrollPositionManager: mockScroll
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
            openAIService: configuration.openAIService
        )
    }
}

// MARK: - Dependency Configuration
struct DependencyConfiguration {
    let persistenceProvider: any PersistenceProviding
    let scheduleManager: any ScheduleManaging
    let scrollPositionManager: any ScrollPositionProviding
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