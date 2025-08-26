import Foundation
import CoreData
import Combine

/// Mock task manager for testing
@MainActor
class MockTaskManager: ObservableObject, @preconcurrency TaskManaging {
    
    @Published private(set) var tasks: [Task] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    
    // Publisher for protocol conformance
    var tasksPublisher: AnyPublisher<[Task], Never> {
        $tasks.eraseToAnyPublisher()
    }
    
    // Test helpers
    var shouldFailOperations = false
    var createTaskCallCount = 0
    var updateTaskCallCount = 0
    var deleteTaskCallCount = 0
    var completeTaskCallCount = 0
    var createSubtaskCallCount = 0
    
    // Mock data storage
    private var mockTasksById: [UUID: Task] = [:]
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext? = nil) {
        // Create a mock context if none provided
        if let context = context {
            self.context = context
        } else {
            let container = NSPersistentContainer(name: "Momentum")
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
            container.loadPersistentStores { _, _ in }
            self.context = container.viewContext
        }
    }
    
    // MARK: - Task CRUD Operations
    
    func createTask(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: TaskPriority = .medium,
        category: Category? = nil,
        tags: [String]? = nil,
        estimatedDuration: Int16? = nil,
        scheduledTime: Date? = nil,
        linkedEvent: Event? = nil
    ) -> Result<Task, ScheduleError> {
        createTaskCallCount += 1
        
        if shouldFailOperations {
            return .failure(.saveFailed)
        }
        
        let task = Task(context: context)
        task.id = UUID()
        task.title = title
        task.notes = notes
        task.dueDate = dueDate
        task.priority = priority.rawValue
        task.category = category
        task.tags = tags?.joined(separator: ",")
        task.estimatedDuration = estimatedDuration ?? 0
        task.scheduledTime = scheduledTime
        task.linkedEvent = linkedEvent
        task.isCompleted = false
        task.createdAt = Date()
        task.modifiedAt = Date()
        
        mockTasksById[task.id!] = task
        tasks.append(task)
        
        return .success(task)
    }
    
    func updateTask(
        _ task: Task,
        title: String? = nil,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: TaskPriority? = nil,
        category: Category? = nil,
        tags: [String]? = nil,
        estimatedDuration: Int16? = nil,
        scheduledTime: Date? = nil,
        linkedEvent: Event? = nil,
        parentTask: Task? = nil
    ) -> Result<Void, ScheduleError> {
        updateTaskCallCount += 1
        
        if shouldFailOperations {
            return .failure(.saveFailed)
        }
        
        if let title = title { task.title = title }
        if let notes = notes { task.notes = notes }
        if dueDate != nil { task.dueDate = dueDate }
        if let priority = priority { task.priority = priority.rawValue }
        if category != nil { task.category = category }
        if let tags = tags { task.tags = tags.joined(separator: ",") }
        if let duration = estimatedDuration { task.estimatedDuration = duration }
        if scheduledTime != nil { task.scheduledTime = scheduledTime }
        if linkedEvent != nil { task.linkedEvent = linkedEvent }
        if parentTask != nil { task.parentTask = parentTask }
        
        task.modifiedAt = Date()
        
        return .success(())
    }
    
    func deleteTask(_ task: Task) -> Result<Void, ScheduleError> {
        deleteTaskCallCount += 1
        
        if shouldFailOperations {
            return .failure(.deleteFailed)
        }
        
        if let id = task.id {
            mockTasksById.removeValue(forKey: id)
            tasks.removeAll { $0.id == id }
        }
        
        return .success(())
    }
    
    func completeTask(_ task: Task) -> Result<Void, ScheduleError> {
        completeTaskCallCount += 1
        
        if shouldFailOperations {
            return .failure(.saveFailed)
        }
        
        task.isCompleted = true
        task.completedAt = Date()
        task.modifiedAt = Date()
        
        return .success(())
    }
    
    func uncompleteTask(_ task: Task) -> Result<Void, ScheduleError> {
        if shouldFailOperations {
            return .failure(.saveFailed)
        }
        
        task.isCompleted = false
        task.completedAt = nil
        task.modifiedAt = Date()
        
        return .success(())
    }
    
    func createSubtask(for parentTask: Task, title: String, notes: String? = nil) -> Result<Task, ScheduleError> {
        createSubtaskCallCount += 1
        
        if shouldFailOperations {
            return .failure(.saveFailed)
        }
        
        let subtask = Task(context: context)
        subtask.id = UUID()
        subtask.title = title
        subtask.notes = notes
        subtask.parentTask = parentTask
        subtask.priority = parentTask.priority
        subtask.category = parentTask.category
        subtask.dueDate = parentTask.dueDate
        subtask.isCompleted = false
        subtask.createdAt = Date()
        subtask.modifiedAt = Date()
        
        mockTasksById[subtask.id!] = subtask
        tasks.append(subtask)
        
        return .success(subtask)
    }
    
    // MARK: - Query Methods
    
    func tasks(for date: Date) -> [Task] {
        let calendar = Calendar.current
        return tasks.filter { task in
            if let scheduledTime = task.scheduledTime,
               calendar.isDate(scheduledTime, inSameDayAs: date) {
                return true
            }
            
            if task.scheduledTime == nil,
               let dueDate = task.dueDate,
               calendar.isDate(dueDate, inSameDayAs: date) {
                return true
            }
            
            return false
        }
    }
    
    func unscheduledTasks() -> [Task] {
        tasks.filter { task in
            !task.isCompleted && task.scheduledTime == nil
        }
    }
    
    func overdueTasks() -> [Task] {
        let now = Date()
        return tasks.filter { task in
            if task.isCompleted { return false }
            guard let dueDate = task.dueDate else { return false }
            return dueDate < now
        }
    }
    
    func tasksWithTag(_ tag: String) -> [Task] {
        tasks.filter { task in
            guard let tags = task.tags?.split(separator: ",").map({ String($0).trimmingCharacters(in: .whitespaces) }) else {
                return false
            }
            return tags.contains(tag)
        }
    }
    
    func tasksByPriority() -> [TaskPriority: [Task]] {
        var grouped: [TaskPriority: [Task]] = [:]
        
        for priority in TaskPriority.allCases {
            grouped[priority] = tasks.filter { $0.priority == priority.rawValue && !$0.isCompleted }
        }
        
        return grouped
    }
    
    // MARK: - Test Helpers
    
    func addMockTask(_ task: Task) {
        if let id = task.id {
            mockTasksById[id] = task
        }
        tasks.append(task)
    }
    
    func clearAllTasks() {
        tasks.removeAll()
        mockTasksById.removeAll()
    }
    
    func setTasks(_ newTasks: [Task]) {
        tasks = newTasks
        mockTasksById.removeAll()
        for task in newTasks {
            if let id = task.id {
                mockTasksById[id] = task
            }
        }
    }
}