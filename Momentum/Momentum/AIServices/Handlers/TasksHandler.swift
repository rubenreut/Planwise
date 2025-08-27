//
//  TasksHandler.swift
//  Momentum
//
//  Tasks domain handler for AI Coordinator
//

import Foundation
import CoreData

// MARK: - Protocol
protocol TasksHandling {
    func create(_ parameters: [String: Any]) async -> [String: Any]
    func update(_ parameters: [String: Any]) async -> [String: Any]
    func delete(_ parameters: [String: Any]) async -> [String: Any]
    func list(_ parameters: [String: Any]) async -> [String: Any]
}

// MARK: - Implementation
@MainActor
final class TasksHandler: TasksHandling {
    private let taskManager: TaskManaging
    private let scheduleManager: ScheduleManaging
    private let context: NSManagedObjectContext
    private let categoryResolver: CategoryResolver
    private let gateway: CoreDataGateway
    
    init(taskManager: TaskManaging, scheduleManager: ScheduleManaging, context: NSManagedObjectContext) {
        self.taskManager = taskManager
        self.scheduleManager = scheduleManager
        self.context = context
        self.categoryResolver = CategoryResolver(scheduleManager: scheduleManager, context: context)
        self.gateway = CoreDataGateway(context: context)
    }
    
    // MARK: - Create
    func create(_ parameters: [String: Any]) async -> [String: Any] {
        // Check for bulk create
        if let items = parameters["items"] {
            return await bulkCreate(items)
        }
        
        // Single create
        do {
            let req = try ParameterDecoder.decode(TaskCreateRequest.self, from: parameters)
            
            // Find parent task if specified
            var parentTask: Task?
            if let parentId = req.parentTaskId, let uuid = UUID(uuidString: parentId) {
                parentTask = taskManager.tasks.first { $0.id == uuid }
            }
            
            // Parse priority
            let priority: TaskPriority = {
                switch req.priority.lowercased() {
                case "high": return .high
                case "low": return .low
                default: return .medium
                }
            }()
            
            // Parse tags
            let tagsArray = req.tags?.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            
            let result = taskManager.createTask(
                title: req.title,
                notes: req.desc,
                dueDate: DateParsingUtility.parseDate(req.dueDate),
                priority: priority,
                category: categoryResolver.resolve(id: req.categoryId, name: req.category),
                tags: tagsArray,
                estimatedDuration: req.estimatedDuration != nil ? Int16(req.estimatedDuration!) : nil,
                scheduledTime: nil, // Not in DTO
                linkedEvent: nil  // Will set after if provided
            )
            
            if case .success(let task) = result {
                // Handle additional properties
                if let completedAt = req.completedAt {
                    task.completedAt = DateParsingUtility.parseDate(completedAt)
                    task.isCompleted = true
                }
                if let linkedEventId = req.linkedEventId, let uuid = UUID(uuidString: linkedEventId) {
                    task.linkedEvent = scheduleManager.events.first { $0.id == uuid }
                }
                // Note: notes already set via createTask parameter
                // Note: tags already set via createTask parameter
                // Note: recurrenceRule and reminder are not part of Task entity
                if req.isCompleted && task.completedAt == nil {
                    task.isCompleted = true
                    task.completedAt = Date()
                }
                
                try? context.save()
                
                return ActionResult<TaskView>(
                    success: true,
                    message: "Created task: \(task.title ?? "Task")",
                    id: task.id?.uuidString,
                    updatedCount: 1
                ).toDictionary()
            }
            
            return ActionResult<TaskView>(
                success: false,
                message: "Failed to create task"
            ).toDictionary()
            
        } catch {
            return ActionResult<TaskView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
    
    // MARK: - Update
    func update(_ parameters: [String: Any]) async -> [String: Any] {
        // Check for bulk update
        if let items = parameters["items"] {
            return await bulkUpdate(items)
        }
        
        // Single update
        do {
            let req = try ParameterDecoder.decode(TaskUpdateRequest.self, from: parameters)
            
            guard let uuid = UUID(uuidString: req.id),
                  let task = taskManager.tasks.first(where: { $0.id == uuid }) else {
                return ActionResult<TaskView>(
                    success: false,
                    message: "Task not found"
                ).toDictionary()
            }
            
            // Find parent task if specified
            var parentTask: Task?
            if let parentId = req.parentTaskId, let parentUuid = UUID(uuidString: parentId) {
                parentTask = taskManager.tasks.first { $0.id == parentUuid }
            }
            
            // Parse priority if provided
            let priority: TaskPriority? = req.priority.map { priorityStr in
                switch priorityStr.lowercased() {
                case "high": return .high
                case "low": return .low
                default: return .medium
                }
            }
            
            // Parse tags
            let tagsArray = req.tags?.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            
            // Parse linkedEvent
            var linkedEvent: Event?
            if let linkedEventId = req.linkedEventId, let uuid = UUID(uuidString: linkedEventId) {
                linkedEvent = scheduleManager.events.first { $0.id == uuid }
            }
            
            let result = taskManager.updateTask(
                task,
                title: req.title,
                notes: req.desc,
                dueDate: DateParsingUtility.parseDate(req.dueDate),
                priority: priority,
                category: categoryResolver.resolve(id: req.categoryId, name: req.category),
                tags: tagsArray,
                estimatedDuration: req.estimatedDuration != nil ? Int16(req.estimatedDuration!) : nil,
                scheduledTime: nil, // Not in DTO
                linkedEvent: linkedEvent,
                parentTask: parentTask
            )
            
            if case .success = result {
                // Handle additional properties
                if let completedAt = req.completedAt {
                    task.completedAt = DateParsingUtility.parseDate(completedAt)
                }
                if let isCompleted = req.isCompleted {
                    task.isCompleted = isCompleted
                    if isCompleted && task.completedAt == nil {
                        task.completedAt = Date()
                    }
                }
                // Note: notes, tags, linkedEvent already handled via updateTask parameters
                // Note: recurrenceRule and reminder are not part of Task entity
                
                try? context.save()
                
                return ActionResult<TaskView>(
                    success: true,
                    message: "Updated task",
                    id: task.id?.uuidString,
                    updatedCount: 1
                ).toDictionary()
            }
            
            return ActionResult<TaskView>(
                success: false,
                message: "Failed to update task"
            ).toDictionary()
            
        } catch {
            return ActionResult<TaskView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
    
    // MARK: - Delete
    func delete(_ parameters: [String: Any]) async -> [String: Any] {
        // Check for bulk delete
        if parameters["deleteAll"] as? Bool == true {
            let tasks = taskManager.tasks
            
            do {
                try BulkDeleteGuard.check(parameters: parameters, count: tasks.count)
                
                var deleted = 0
                for task in tasks {
                    if case .success = taskManager.deleteTask(task) {
                        deleted += 1
                    }
                }
                
                return ActionResult<TaskView>(
                    success: true,
                    message: "Deleted \(deleted) tasks",
                    matchedCount: tasks.count,
                    updatedCount: deleted
                ).toDictionary()
                
            } catch {
                return ActionResult<TaskView>(
                    success: false,
                    message: error.localizedDescription,
                    matchedCount: tasks.count
                ).toDictionary()
            }
        }
        
        // Delete by IDs
        if let ids = parameters["ids"] as? [String] {
            var deleted = 0
            
            for id in ids {
                if let uuid = UUID(uuidString: id),
                   let task = taskManager.tasks.first(where: { $0.id == uuid }),
                   case .success = taskManager.deleteTask(task) {
                    deleted += 1
                }
            }
            
            return ActionResult<TaskView>(
                success: deleted > 0,
                message: "Deleted \(deleted) tasks",
                matchedCount: ids.count,
                updatedCount: deleted
            ).toDictionary()
        }
        
        // Single delete
        if let id = parameters["id"] as? String,
           let uuid = UUID(uuidString: id),
           let task = taskManager.tasks.first(where: { $0.id == uuid }),
           case .success = taskManager.deleteTask(task) {
            
            return ActionResult<TaskView>(
                success: true,
                message: "Deleted task",
                id: id,
                matchedCount: 1,
                updatedCount: 1
            ).toDictionary()
        }
        
        return ActionResult<TaskView>(
            success: false,
            message: "Failed to delete - no valid parameters provided"
        ).toDictionary()
    }
    
    // MARK: - List
    func list(_ parameters: [String: Any]) async -> [String: Any] {
        let filter = parameters["filter"] as? String
        var tasks = taskManager.tasks
        
        // Apply filters
        if let filter = filter?.lowercased() {
            switch filter {
            case "incomplete", "pending":
                tasks = tasks.filter { !$0.isCompleted }
            case "completed", "done":
                tasks = tasks.filter { $0.isCompleted }
            case "overdue":
                let now = Date()
                tasks = tasks.filter { task in
                    guard let dueDate = task.dueDate, !task.isCompleted else { return false }
                    return dueDate < now
                }
            case "today":
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                tasks = tasks.filter { task in
                    guard let dueDate = task.dueDate else { return false }
                    return calendar.isDate(dueDate, inSameDayAs: today)
                }
            default:
                break
            }
        }
        
        let views = tasks.compactMap { task -> TaskView? in
            guard let id = task.id?.uuidString else { return nil }
            
            return TaskView(
                id: id,
                title: task.title ?? "",
                description: task.notes ?? "",
                dueDate: DateParsingUtility.formatDate(task.dueDate),
                isCompleted: task.isCompleted,
                priority: {
                    switch task.priority {
                    case TaskPriority.high.rawValue: return "high"
                    case TaskPriority.low.rawValue: return "low"
                    default: return "medium"
                    }
                }(),
                category: task.category?.name ?? "",
                estimatedDuration: Int(task.estimatedDuration),
                completedAt: DateParsingUtility.formatDate(task.completedAt),
                parentTaskId: task.parentTask?.id?.uuidString,
                linkedEventId: task.linkedEvent?.id?.uuidString,
                notes: task.notes ?? "",
                tags: task.tags?.components(separatedBy: ",") ?? [],
                recurrenceRule: nil,  // Not in Task entity
                reminder: nil  // Not in Task entity
            )
        }
        
        return ActionResult<TaskView>(
            success: true,
            message: "Found \(views.count) tasks",
            items: views,
            matchedCount: views.count
        ).toDictionary()
    }
    
    // MARK: - Bulk Helpers
    
    private func bulkCreate(_ items: Any) async -> [String: Any] {
        do {
            let requests = try ParameterDecoder.decodeArray(TaskCreateRequest.self, from: items)
            var created = 0
            var errors: [String] = []
            
            for req in requests {
                // Find parent task if specified
                var parentTask: Task?
                if let parentId = req.parentTaskId, let uuid = UUID(uuidString: parentId) {
                    parentTask = taskManager.tasks.first { $0.id == uuid }
                }
                
                // Parse priority
                let priority: TaskPriority = {
                    switch req.priority.lowercased() {
                    case "high": return .high
                    case "low": return .low
                    default: return .medium
                    }
                }()
                
                // Parse tags
                let tagsArray = req.tags?.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                
                let result = taskManager.createTask(
                    title: req.title,
                    notes: req.desc,
                    dueDate: DateParsingUtility.parseDate(req.dueDate),
                    priority: priority,
                    category: categoryResolver.resolve(id: req.categoryId, name: req.category),
                    tags: tagsArray,
                    estimatedDuration: req.estimatedDuration != nil ? Int16(req.estimatedDuration!) : nil,
                    scheduledTime: nil,
                    linkedEvent: nil
                )
                
                if case .success = result {
                    created += 1
                } else {
                    errors.append("\(req.title): create failed")
                }
            }
            
            try? context.save()
            
            let message = errors.isEmpty
                ? "Created \(created) tasks"
                : "Created \(created) tasks. Errors: \(errors.joined(separator: "; "))"
            
            return ActionResult<TaskView>(
                success: created > 0,
                message: message,
                updatedCount: created
            ).toDictionary()
            
        } catch {
            return ActionResult<TaskView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
    
    private func bulkUpdate(_ items: Any) async -> [String: Any] {
        do {
            let requests = try ParameterDecoder.decodeArray(TaskUpdateRequest.self, from: items)
            var updated = 0
            var errors: [String] = []
            
            for req in requests {
                guard let uuid = UUID(uuidString: req.id),
                      let task = taskManager.tasks.first(where: { $0.id == uuid }) else {
                    errors.append("Task not found: \(req.id)")
                    continue
                }
                
                // Find parent task if specified
                var parentTask: Task?
                if let parentId = req.parentTaskId, let parentUuid = UUID(uuidString: parentId) {
                    parentTask = taskManager.tasks.first { $0.id == parentUuid }
                }
                
                // Parse priority if provided
                let priority: TaskPriority? = req.priority.map { priorityStr in
                    switch priorityStr.lowercased() {
                    case "high": return .high
                    case "low": return .low
                    default: return .medium
                    }
                }
                
                // Parse tags
                let tagsArray = req.tags?.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                
                // Parse linkedEvent
                var linkedEvent: Event?
                if let linkedEventId = req.linkedEventId, let uuid = UUID(uuidString: linkedEventId) {
                    linkedEvent = scheduleManager.events.first { $0.id == uuid }
                }
                
                let result = taskManager.updateTask(
                    task,
                    title: req.title,
                    notes: req.desc,
                    dueDate: DateParsingUtility.parseDate(req.dueDate),
                    priority: priority,
                    category: categoryResolver.resolve(id: req.categoryId, name: req.category),
                    tags: tagsArray,
                    estimatedDuration: req.estimatedDuration != nil ? Int16(req.estimatedDuration!) : nil,
                    scheduledTime: nil,
                    linkedEvent: linkedEvent,
                    parentTask: parentTask
                )
                
                if case .success = result {
                    updated += 1
                }
            }
            
            try? context.save()
            
            let message = errors.isEmpty
                ? "Updated \(updated) tasks"
                : "Updated \(updated) tasks. Errors: \(errors.joined(separator: "; "))"
            
            return ActionResult<TaskView>(
                success: updated > 0,
                message: message,
                updatedCount: updated
            ).toDictionary()
            
        } catch {
            return ActionResult<TaskView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
}