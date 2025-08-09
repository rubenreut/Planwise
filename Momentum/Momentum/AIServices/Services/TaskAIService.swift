//
//  TaskAIService.swift
//  Momentum
//
//  Handles all task-related AI operations
//

import Foundation
import CoreData

final class TaskAIService: BaseAIService<Task> {
    
    private let taskManager: TaskManager
    
    init(context: NSManagedObjectContext, taskManager: TaskManager) {
        self.taskManager = taskManager
        super.init(serviceName: "TaskAIService", context: context)
    }
    
    override func create(parameters: [String: Any]) async -> AIResult {
        guard let title = parameters["title"] as? String else {
            return AIResult.failure("Missing required field: title")
        }
        
        let task = Task(context: context)
        task.id = UUID()
        task.title = title
        task.taskDescription = parameters["description"] as? String
        task.isCompleted = parameters["isCompleted"] as? Bool ?? false
        task.priority = Int16(parameters["priority"] as? Int ?? 1)
        task.estimatedMinutes = Int16(parameters["estimatedMinutes"] as? Int ?? 30)
        
        if let dueDateString = parameters["dueDate"] as? String,
           let dueDate = ISO8601DateFormatter().date(from: dueDateString) {
            task.dueDate = dueDate
        } else if let dueDate = parameters["dueDate"] as? Date {
            task.dueDate = dueDate
        }
        
        if let goalId = parameters["goalId"] as? String,
           let goalUUID = UUID(uuidString: goalId) {
            let request: NSFetchRequest<Goal> = Goal.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", goalUUID as CVarArg)
            if let goal = try? context.fetch(request).first {
                task.goal = goal
            }
        }
        
        if let categoryId = parameters["categoryId"] as? String,
           let categoryUUID = UUID(uuidString: categoryId) {
            let request: NSFetchRequest<Category> = Category.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", categoryUUID as CVarArg)
            if let category = try? context.fetch(request).first {
                task.category = category
            }
        }
        
        if let tags = parameters["tags"] as? [String] {
            task.tags = tags
        }
        
        do {
            try context.save()
            return AIResult.success("Created task: \(title)", data: ["id": task.id?.uuidString ?? ""])
        } catch {
            return AIResult.failure("Failed to create task: \(error.localizedDescription)")
        }
    }
    
    override func update(id: String?, parameters: [String: Any]) async -> AIResult {
        guard let id = id, let uuid = UUID(uuidString: id) else {
            return AIResult.failure("Invalid or missing task ID")
        }
        
        let request: NSFetchRequest<Task> = Task.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        do {
            guard let task = try context.fetch(request).first else {
                return AIResult.failure("Task not found")
            }
            
            if let title = parameters["title"] as? String {
                task.title = title
            }
            if let description = parameters["description"] as? String {
                task.taskDescription = description
            }
            if let isCompleted = parameters["isCompleted"] as? Bool {
                task.isCompleted = isCompleted
                if isCompleted {
                    task.completedAt = Date()
                }
            }
            if let priority = parameters["priority"] as? Int {
                task.priority = Int16(priority)
            }
            if let estimatedMinutes = parameters["estimatedMinutes"] as? Int {
                task.estimatedMinutes = Int16(estimatedMinutes)
            }
            if let dueDateString = parameters["dueDate"] as? String,
               let dueDate = ISO8601DateFormatter().date(from: dueDateString) {
                task.dueDate = dueDate
            }
            if let tags = parameters["tags"] as? [String] {
                task.tags = tags
            }
            
            try context.save()
            return AIResult.success("Updated task: \(task.title ?? "")")
        } catch {
            return AIResult.failure("Failed to update task: \(error.localizedDescription)")
        }
    }
    
    override func list(parameters: [String: Any]) async -> AIResult {
        let request: NSFetchRequest<Task> = Task.fetchRequest()
        var predicates: [NSPredicate] = []
        
        if let completed = parameters["completed"] as? Bool {
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: completed)))
        }
        
        if let goalId = parameters["goalId"] as? String,
           let uuid = UUID(uuidString: goalId) {
            predicates.append(NSPredicate(format: "goal.id == %@", uuid as CVarArg))
        }
        
        if let categoryId = parameters["categoryId"] as? String,
           let uuid = UUID(uuidString: categoryId) {
            predicates.append(NSPredicate(format: "category.id == %@", uuid as CVarArg))
        }
        
        if let dueDate = parameters["dueDate"] as? Date {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: dueDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            predicates.append(NSPredicate(format: "dueDate >= %@ AND dueDate < %@", startOfDay as NSDate, endOfDay as NSDate))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(key: "priority", ascending: false),
            NSSortDescriptor(key: "dueDate", ascending: true)
        ]
        
        do {
            let tasks = try context.fetch(request)
            let taskData = tasks.map { task in
                return [
                    "id": task.id?.uuidString ?? "",
                    "title": task.title ?? "",
                    "description": task.taskDescription ?? "",
                    "isCompleted": task.isCompleted,
                    "priority": task.priority,
                    "dueDate": task.dueDate != nil ? ISO8601DateFormatter().string(from: task.dueDate!) : nil as Any
                ]
            }
            return AIResult.success("Found \(tasks.count) tasks", data: taskData)
        } catch {
            return AIResult.failure("Failed to list tasks: \(error.localizedDescription)")
        }
    }
}