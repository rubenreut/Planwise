//
//  GoalAIService.swift
//  Momentum
//
//  Handles all goal-related AI operations including milestones
//

import Foundation
import CoreData

final class GoalAIService: BaseAIService<Goal> {
    
    private let goalManager: GoalManager
    
    init(context: NSManagedObjectContext, goalManager: GoalManager) {
        self.goalManager = goalManager
        super.init(serviceName: "GoalAIService", context: context)
    }
    
    override func create(parameters: [String: Any]) async -> AIResult {
        guard let title = parameters["title"] as? String else {
            return AIResult.failure("Missing required field: title")
        }
        
        let goal = Goal(context: context)
        goal.id = UUID()
        goal.title = title
        goal.desc = parameters["description"] as? String
        goal.createdAt = Date()
        // Progress is calculated, not set directly
        goal.isCompleted = false
        
        if let targetDateString = parameters["targetDate"] as? String,
           let targetDate = ISO8601DateFormatter().date(from: targetDateString) {
            goal.targetDate = targetDate
        } else if let targetDate = parameters["targetDate"] as? Date {
            goal.targetDate = targetDate
        }
        
        if let categoryId = parameters["categoryId"] as? String,
           let categoryUUID = UUID(uuidString: categoryId) {
            let request: NSFetchRequest<Category> = Category.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", categoryUUID as CVarArg)
            if let category = try? context.fetch(request).first {
                goal.category = category
            }
        }
        
        if let priority = parameters["priority"] as? Int {
            goal.priority = Int16(priority)
        }
        
        if let unit = parameters["unit"] as? String {
            goal.unit = unit
        }
        
        if let targetValue = parameters["targetValue"] as? Double {
            goal.targetValue = targetValue
        }
        
        // Milestones would need to be handled differently
        
        do {
            try context.save()
            return AIResult.success("Created goal: \(title)", data: ["id": goal.id?.uuidString ?? ""])
        } catch {
            return AIResult.failure("Failed to create goal: \(error.localizedDescription)")
        }
    }
    
    override func update(id: String?, parameters: [String: Any]) async -> AIResult {
        guard let id = id, let uuid = UUID(uuidString: id) else {
            return AIResult.failure("Invalid or missing goal ID")
        }
        
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        do {
            guard let goal = try context.fetch(request).first else {
                return AIResult.failure("Goal not found")
            }
            
            if let title = parameters["title"] as? String {
                goal.title = title
            }
            if let description = parameters["description"] as? String {
                goal.desc = description
            }
            if let targetDateString = parameters["targetDate"] as? String,
               let targetDate = ISO8601DateFormatter().date(from: targetDateString) {
                goal.targetDate = targetDate
            }
            if let priority = parameters["priority"] as? Int {
                goal.priority = Int16(priority)
            }
            // Progress is calculated, not directly set
            if let isCompleted = parameters["isCompleted"] as? Bool {
                goal.isCompleted = isCompleted
                // Mark completion time if needed
            }
            if let unit = parameters["unit"] as? String {
                goal.unit = unit
            }
            if let targetValue = parameters["targetValue"] as? Double {
                goal.targetValue = targetValue
            }
            if let categoryId = parameters["categoryId"] as? String,
               let categoryUUID = UUID(uuidString: categoryId) {
                let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
                categoryRequest.predicate = NSPredicate(format: "id == %@", categoryUUID as CVarArg)
                if let category = try context.fetch(categoryRequest).first {
                    goal.category = category
                }
            }
            
            try context.save()
            return AIResult.success("Updated goal: \(goal.title ?? "")")
        } catch {
            return AIResult.failure("Failed to update goal: \(error.localizedDescription)")
        }
    }
    
    override func list(parameters: [String: Any]) async -> AIResult {
        let request: NSFetchRequest<Goal> = Goal.fetchRequest()
        var predicates: [NSPredicate] = []
        
        if let isCompleted = parameters["completed"] as? Bool {
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: isCompleted)))
        }
        
        if let categoryId = parameters["categoryId"] as? String,
           let uuid = UUID(uuidString: categoryId) {
            predicates.append(NSPredicate(format: "category.id == %@", uuid as CVarArg))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(key: "priority", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        
        do {
            let goals = try context.fetch(request)
            let goalData = goals.map { goal in
                return [
                    "id": goal.id?.uuidString ?? "",
                    "title": goal.title ?? "",
                    "description": goal.desc ?? "",
                    "progress": 0.0,
                    "isCompleted": goal.isCompleted,
                    "targetDate": goal.targetDate != nil ? ISO8601DateFormatter().string(from: goal.targetDate!) : "" as Any,
                    "subgoalCount": goal.milestones?.count ?? 0
                ]
            }
            return AIResult.success("Found \(goals.count) goals", data: goalData)
        } catch {
            return AIResult.failure("Failed to list goals: \(error.localizedDescription)")
        }
    }
    
    // Milestone functions removed - not part of current data model
    
    // Milestone functions removed - not part of current data model
}