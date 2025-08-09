# ChatViewModel Refactoring Plan
## From 11,249 lines to ~500 lines

### Current State Analysis
- **Total Lines**: 11,249
- **Private Functions**: 157
- **AI Functions**: 103
- **Major Sections**: 20

### Problems
1. Single file doing EVERYTHING
2. 64 duplicate AI functions + manage() function
3. No separation of concerns
4. Impossible to test
5. Massive memory footprint
6. Xcode performance issues
7. Merge conflict nightmare

### New Architecture

```
ChatViewModel (500 lines)
├── Services/
│   ├── AICoordinator.swift (200 lines)
│   ├── AIFunctionRouter.swift (100 lines)
│   └── ContextBuilder.swift (200 lines)
│
├── AIServices/
│   ├── Protocols/
│   │   ├── AIServiceProtocol.swift
│   │   └── CRUDServiceProtocol.swift
│   │
│   ├── BaseAIService.swift (300 lines) - Generic CRUD
│   ├── EventAIService.swift (400 lines)
│   ├── TaskAIService.swift (400 lines)
│   ├── GoalAIService.swift (400 lines)
│   ├── HabitAIService.swift (300 lines)
│   ├── MilestoneAIService.swift (200 lines)
│   └── CategoryAIService.swift (150 lines)
│
├── Streaming/
│   ├── OpenAIStreamHandler.swift (300 lines)
│   └── StreamingMessageBuilder.swift (200 lines)
│
├── Previews/
│   ├── PreviewFactory.swift (200 lines)
│   ├── EventPreviewBuilder.swift (150 lines)
│   └── BulkActionPreviewBuilder.swift (150 lines)
│
└── Utilities/
    ├── AILogger.swift (100 lines)
    ├── PerformanceMonitor.swift (100 lines)
    └── ErrorHandler.swift (150 lines)
```

### Refactoring Phases

## Phase 1: Setup Infrastructure (Day 1)
- [ ] Create folder structure
- [ ] Define protocols (AIServiceProtocol, CRUDServiceProtocol)
- [ ] Create BaseAIService with generic CRUD operations
- [ ] Setup dependency injection container

## Phase 2: Extract Services (Day 2-3)
- [ ] Extract EventAIService
- [ ] Extract TaskAIService
- [ ] Extract GoalAIService
- [ ] Extract HabitAIService
- [ ] Extract MilestoneAIService
- [ ] Extract CategoryAIService

## Phase 3: Extract Support Systems (Day 4)
- [ ] Extract ContextBuilder
- [ ] Extract OpenAIStreamHandler
- [ ] Extract PreviewFactory
- [ ] Create AICoordinator to manage all services

## Phase 4: Refactor Core (Day 5)
- [ ] Update ChatViewModel to use new services
- [ ] Replace switch statement with FunctionRouter
- [ ] Remove all old code
- [ ] Add proper error handling

## Phase 5: Testing & Optimization (Day 6)
- [ ] Create unit tests for each service
- [ ] Performance testing
- [ ] Memory profiling
- [ ] Fix any issues

### Code Examples

#### Before (11,249 lines in one file):
```swift
class ChatViewModel: ObservableObject {
    // 157 functions all mixed together
    private func createEvent(...) { /* 150 lines */ }
    private func updateEvent(...) { /* 120 lines */ }
    private func deleteEvent(...) { /* 80 lines */ }
    // ... 154 more functions
}
```

#### After (Clean separation):
```swift
// ChatViewModel.swift (500 lines)
class ChatViewModel: ObservableObject {
    private let aiCoordinator: AICoordinator
    private let streamHandler: OpenAIStreamHandler
    private let contextBuilder: ContextBuilder
    
    func sendMessage() {
        let context = contextBuilder.build(for: message)
        let result = await aiCoordinator.process(message, context: context)
        streamHandler.stream(result)
    }
}

// EventAIService.swift (400 lines)
class EventAIService: BaseAIService<Event> {
    override func create(_ params: Parameters) async -> Result {
        // Specific event creation logic
    }
}

// BaseAIService.swift (300 lines)
class BaseAIService<T: ManagedObject>: AIServiceProtocol {
    func create(_ params: Parameters) async -> Result { }
    func update(_ id: UUID, params: Parameters) async -> Result { }
    func delete(_ id: UUID) async -> Result { }
    func list(_ filter: Filter?) async -> Result { }
}
```

### Benefits After Refactoring
1. **Testable**: Each service can be unit tested
2. **Maintainable**: Find code easily
3. **Performance**: Load only what's needed
4. **Reusable**: Services can be used elsewhere
5. **Clean**: Single responsibility principle
6. **Scalable**: Easy to add new features
7. **Debuggable**: Clear separation of concerns

### Metrics Goals
- Reduce main file from 11,249 → 500 lines
- Split into 20+ focused files
- Each file < 500 lines
- 80% code reuse through generics
- 100% unit test coverage possible
- 50% faster Xcode performance
- 90% reduction in merge conflicts