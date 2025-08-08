import Foundation
import CoreData
import SwiftUI
import Combine

// MARK: - Task Priority Enum
enum TaskPriority: Int16, CaseIterable, Comparable {
    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        // Higher priority (higher rawValue) should come first
        return lhs.rawValue > rhs.rawValue
    }
    
    case low = 0
    case medium = 1
    case high = 2
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .yellow
        case .high: return .red
        }
    }
}

// MARK: - Task Managing Protocol
protocol TaskManaging {
    var tasks: [Task] { get }
    var tasksPublisher: AnyPublisher<[Task], Never> { get }
    
    func createTask(title: String, notes: String?, dueDate: Date?, priority: TaskPriority, category: Category?, tags: [String]?, estimatedDuration: Int16?, scheduledTime: Date?, linkedEvent: Event?) -> Result<Task, ScheduleError>
    func updateTask(_ task: Task, title: String?, notes: String?, dueDate: Date?, priority: TaskPriority?, category: Category?, tags: [String]?, estimatedDuration: Int16?, scheduledTime: Date?, linkedEvent: Event?, parentTask: Task?) -> Result<Void, ScheduleError>
    func deleteTask(_ task: Task) -> Result<Void, ScheduleError>
    func completeTask(_ task: Task) -> Result<Void, ScheduleError>
    func uncompleteTask(_ task: Task) -> Result<Void, ScheduleError>
    func createSubtask(for parentTask: Task, title: String, notes: String?) -> Result<Task, ScheduleError>
    
    func tasks(for date: Date) -> [Task]
    func unscheduledTasks() -> [Task]
    func overdueTasks() -> [Task]
    func tasksWithTag(_ tag: String) -> [Task]
    func tasksByPriority() -> [TaskPriority: [Task]]
}

// MARK: - Task Manager
@MainActor
class TaskManager: NSObject, ObservableObject, @preconcurrency TaskManaging {
    static let shared = TaskManager()
    
    @Published private(set) var tasks: [Task] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    
    // Publisher for protocol conformance
    var tasksPublisher: AnyPublisher<[Task], Never> {
        $tasks.eraseToAnyPublisher()
    }
    
    private let persistence: any PersistenceProviding
    private var fetchedResultsController: NSFetchedResultsController<Task>?
    
    // Cache for tasks by date
    private var tasksCache: [Date: [Task]] = [:]
    private let cacheLock = NSLock()
    
    // MARK: - Initialization
    
    /// Singleton for production use
    private override init() {
        self.persistence = PersistenceController.shared
        super.init()
        setupFetchedResultsController()
        fetchTasks()
    }
    
    /// Initializer for dependency injection (testing)
    init(persistence: any PersistenceProviding) {
        self.persistence = persistence
        super.init()
        setupFetchedResultsController()
        fetchTasks()
    }
    
    // MARK: - Setup
    private func setupFetchedResultsController() {
        let request: NSFetchRequest<Task> = Task.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Task.priority, ascending: false),
            NSSortDescriptor(keyPath: \Task.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \Task.createdAt, ascending: true)
        ]
        // Filter out subtasks - only fetch top-level tasks
        request.predicate = NSPredicate(format: "parentTask == nil")
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: persistence.container.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultsController?.delegate = self
    }
    
    // MARK: - Fetching
    func forceRefresh() {
        fetchTasks()
        objectWillChange.send()
    }
    
    private func fetchTasks() {
        isLoading = true
        
        persistence.performAndMeasure("Fetch all tasks") {
            do {
                try fetchedResultsController?.performFetch()
                tasks = fetchedResultsController?.fetchedObjects ?? []
                clearTaskCache()
                isLoading = false
            } catch {
                lastError = "Failed to fetch tasks: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func clearTaskCache() {
        cacheLock.lock()
        tasksCache.removeAll()
        cacheLock.unlock()
    }
    
    // MARK: - CRUD Operations
    
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
        // Check subscription limits
        if !SubscriptionManager.shared.canCreateTask(currentCount: tasks.count) {
            return .failure(.subscriptionLimitReached)
        }
        
        let context = persistence.container.viewContext
        
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
        
        do {
            try persistence.save()
            clearTaskCache()
            return .success(task)
        } catch {
            return .failure(.saveFailed)
        }
    }
    
    func updateTask(
        _ task: Task,
        title: String?,
        notes: String?,
        dueDate: Date?,
        priority: TaskPriority?,
        category: Category?,
        tags: [String]?,
        estimatedDuration: Int16?,
        scheduledTime: Date?,
        linkedEvent: Event?,
        parentTask: Task?
    ) -> Result<Void, ScheduleError> {
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
        
        do {
            try persistence.save()
            clearTaskCache()
            return .success(())
        } catch {
            return .failure(.saveFailed)
        }
    }
    
    func deleteTask(_ task: Task) -> Result<Void, ScheduleError> {
        persistence.container.viewContext.delete(task)
        
        do {
            try persistence.save()
            clearTaskCache()
            return .success(())
        } catch {
            return .failure(.deleteFailed)
        }
    }
    
    func completeTask(_ task: Task) -> Result<Void, ScheduleError> {
        task.isCompleted = true
        task.completedAt = Date()
        task.modifiedAt = Date()
        
        do {
            try persistence.save()
            clearTaskCache()
            return .success(())
        } catch {
            return .failure(.saveFailed)
        }
    }
    
    func uncompleteTask(_ task: Task) -> Result<Void, ScheduleError> {
        task.isCompleted = false
        task.completedAt = nil
        task.modifiedAt = Date()
        
        do {
            try persistence.save()
            clearTaskCache()
            return .success(())
        } catch {
            return .failure(.saveFailed)
        }
    }
    
    func createSubtask(for parentTask: Task, title: String, notes: String? = nil) -> Result<Task, ScheduleError> {
        let context = persistence.container.viewContext
        
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
        
        do {
            try persistence.save()
            clearTaskCache()
            return .success(subtask)
        } catch {
            return .failure(.saveFailed)
        }
    }
    
    // MARK: - Query Methods
    
    func tasks(for date: Date) -> [Task] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // Check cache first
        cacheLock.lock()
        if let cachedTasks = tasksCache[startOfDay] {
            cacheLock.unlock()
            return cachedTasks
        }
        cacheLock.unlock()
        
        // Filter tasks for the given date
        let dayTasks = tasks.filter { task in
            // Include tasks scheduled for this date
            if let scheduledTime = task.scheduledTime,
               calendar.isDate(scheduledTime, inSameDayAs: date) {
                return true
            }
            
            // Include tasks due on this date (but not scheduled)
            if task.scheduledTime == nil,
               let dueDate = task.dueDate,
               calendar.isDate(dueDate, inSameDayAs: date) {
                return true
            }
            
            return false
        }
        
        // Cache the result
        cacheLock.lock()
        tasksCache[startOfDay] = dayTasks
        cacheLock.unlock()
        
        return dayTasks
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
}

// MARK: - NSFetchedResultsControllerDelegate
extension TaskManager: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Re-fetch tasks when Core Data changes
        if controller == fetchedResultsController {
            tasks = fetchedResultsController?.fetchedObjects ?? []
            clearTaskCache()
        }
    }
}

// MARK: - Task Extensions
extension Task {
    var priorityEnum: TaskPriority {
        TaskPriority(rawValue: self.priority) ?? .medium
    }
    
    var tagsArray: [String] {
        guard let tags = tags else { return [] }
        return tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    }
    
    var isOverdue: Bool {
        guard !isCompleted, let dueDate = dueDate else { return false }
        return dueDate < Date()
    }
    
    var hasSubtasks: Bool {
        (subtasks?.count ?? 0) > 0
    }
    
    var completedSubtaskCount: Int {
        subtasks?.filter { ($0 as? Task)?.isCompleted == true }.count ?? 0
    }
    
    var totalSubtaskCount: Int {
        subtasks?.count ?? 0
    }
}