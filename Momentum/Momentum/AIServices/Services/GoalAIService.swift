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
        goal.goalDescription = parameters["description"] as? String
        goal.createdAt = Date()
        goal.progress = 0
        goal.isCompleted = false
        
        if let targetDateString = parameters["targetDate"] as? String,
           let targetDate = ISO8601DateFormatter().date(from: targetDateString) {
            goal.targetDate = targetDate
        } else if let targetDate = parameters["targetDate"] as? Date {
            goal.targetDate = targetDate
        }
        
        if let categoryId = parameters["categoryId"] as? String,
           let categoryUUID = UUID(uuidString: categoryId) {
            let request: NSFetchRequest<GoalCategory> = GoalCategory.fetchRequest()
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
        
        if let milestones = parameters["milestones"] as? [[String: Any]] {
            for milestoneData in milestones {
                if let milestoneTitle = milestoneData["title"] as? String {
                    let milestone = Milestone(context: context)
                    milestone.id = UUID()
                    milestone.title = milestoneTitle
                    milestone.milestoneDescription = milestoneData["description"] as? String
                    milestone.isCompleted = false
                    milestone.goal = goal
                    
                    if let dueDateString = milestoneData["dueDate"] as? String,
                       let dueDate = ISO8601DateFormatter().date(from: dueDateString) {
                        milestone.dueDate = dueDate
                    }
                }
            }
        }
        
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
                goal.goalDescription = description
            }
            if let targetDateString = parameters["targetDate"] as? String,
               let targetDate = ISO8601DateFormatter().date(from: targetDateString) {
                goal.targetDate = targetDate
            }
            if let priority = parameters["priority"] as? Int {
                goal.priority = Int16(priority)
            }
            if let progress = parameters["progress"] as? Float {
                goal.progress = progress
            }
            if let isCompleted = parameters["isCompleted"] as? Bool {
                goal.isCompleted = isCompleted
                if isCompleted {
                    goal.completedAt = Date()
                }
            }
            if let unit = parameters["unit"] as? String {
                goal.unit = unit
            }
            if let targetValue = parameters["targetValue"] as? Double {
                goal.targetValue = targetValue
            }
            if let categoryId = parameters["categoryId"] as? String,
               let categoryUUID = UUID(uuidString: categoryId) {
                let categoryRequest: NSFetchRequest<GoalCategory> = GoalCategory.fetchRequest()
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
                    "description": goal.goalDescription ?? "",
                    "progress": goal.progress,
                    "isCompleted": goal.isCompleted,
                    "targetDate": goal.targetDate != nil ? ISO8601DateFormatter().string(from: goal.targetDate!) : nil as Any,
                    "milestoneCount": goal.milestones?.count ?? 0
                ]
            }
            return AIResult.success("Found \(goals.count) goals", data: goalData)
        } catch {
            return AIResult.failure("Failed to list goals: \(error.localizedDescription)")
        }
    }
    
    func createMilestone(goalId: String, parameters: [String: Any]) async -> AIResult {
        guard let goalUUID = UUID(uuidString: goalId),
              let title = parameters["title"] as? String else {
            return AIResult.failure("Invalid goal ID or missing title")
        }
        
        let goalRequest: NSFetchRequest<Goal> = Goal.fetchRequest()
        goalRequest.predicate = NSPredicate(format: "id == %@", goalUUID as CVarArg)
        
        do {
            guard let goal = try context.fetch(goalRequest).first else {
                return AIResult.failure("Goal not found")
            }
            
            let milestone = Milestone(context: context)
            milestone.id = UUID()
            milestone.title = title
            milestone.milestoneDescription = parameters["description"] as? String
            milestone.isCompleted = false
            milestone.goal = goal
            
            if let dueDateString = parameters["dueDate"] as? String,
               let dueDate = ISO8601DateFormatter().date(from: dueDateString) {
                milestone.dueDate = dueDate
            }
            
            try context.save()
            return AIResult.success("Created milestone: \(title)", data: ["id": milestone.id?.uuidString ?? ""])
        } catch {
            return AIResult.failure("Failed to create milestone: \(error.localizedDescription)")
        }
    }
    
    func updateMilestone(milestoneId: String, parameters: [String: Any]) async -> AIResult {
        guard let uuid = UUID(uuidString: milestoneId) else {
            return AIResult.failure("Invalid milestone ID")
        }
        
        let request: NSFetchRequest<Milestone> = Milestone.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        do {
            guard let milestone = try context.fetch(request).first else {
                return AIResult.failure("Milestone not found")
            }
            
            if let title = parameters["title"] as? String {
                milestone.title = title
            }
            if let description = parameters["description"] as? String {
                milestone.milestoneDescription = description
            }
            if let isCompleted = parameters["isCompleted"] as? Bool {
                milestone.isCompleted = isCompleted
                if isCompleted {
                    milestone.completedAt = Date()
                }
            }
            if let dueDateString = parameters["dueDate"] as? String,
               let dueDate = ISO8601DateFormatter().date(from: dueDateString) {
                milestone.dueDate = dueDate
            }
            
            try context.save()
            return AIResult.success("Updated milestone: \(milestone.title ?? "")")
        } catch {
            return AIResult.failure("Failed to update milestone: \(error.localizedDescription)")
        }
    }
    
    func deleteMilestone(milestoneId: String) async -> AIResult {
        guard let uuid = UUID(uuidString: milestoneId) else {
            return AIResult.failure("Invalid milestone ID")
        }
        
        let request: NSFetchRequest<Milestone> = Milestone.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        do {
            guard let milestone = try context.fetch(request).first else {
                return AIResult.failure("Milestone not found")
            }
            
            context.delete(milestone)
            try context.save()
            return AIResult.success("Deleted milestone")
        } catch {
            return AIResult.failure("Failed to delete milestone: \(error.localizedDescription)")
        }
    }
}