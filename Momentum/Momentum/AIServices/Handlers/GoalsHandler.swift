//
//  GoalsHandler.swift
//  Momentum
//
//  Goals domain handler for AI Coordinator
//

import Foundation
import CoreData

// MARK: - Protocol
protocol GoalsHandling {
    func create(_ parameters: [String: Any]) async -> [String: Any]
    func update(_ parameters: [String: Any]) async -> [String: Any]
    func delete(_ parameters: [String: Any]) async -> [String: Any]
    func list(_ parameters: [String: Any]) async -> [String: Any]
    func updateProgress(_ parameters: [String: Any]) async -> [String: Any]
}

// MARK: - Implementation
@MainActor
final class GoalsHandler: GoalsHandling {
    private let goalManager: GoalManager
    private let scheduleManager: ScheduleManaging
    private let context: NSManagedObjectContext
    private let categoryResolver: CategoryResolver
    private let gateway: CoreDataGateway
    
    init(goalManager: GoalManager, scheduleManager: ScheduleManaging, context: NSManagedObjectContext) {
        self.goalManager = goalManager
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
            let req = try ParameterDecoder.decode(GoalCreateRequest.self, from: parameters)
            
            // Convert priority string to GoalPriority
            let priority: GoalPriority = {
                switch req.priority.lowercased() {
                case "high": return .high
                case "low": return .low
                default: return .medium
                }
            }()
            
            let result = goalManager.createGoal(
                title: req.title,
                description: req.desc,
                targetValue: req.targetValue,
                targetDate: DateParsingUtility.parseDate(req.targetDate),
                unit: req.unit,
                priority: priority,
                category: categoryResolver.resolve(id: req.categoryId, name: req.category)
            )
            
            if case .success(let goal) = result {
                // Set current value
                goal.currentValue = req.currentValue
                
                try? context.save()
                
                return ActionResult<GoalView>(
                    success: true,
                    message: "Created goal: \(goal.title ?? "Goal")",
                    id: goal.id?.uuidString,
                    updatedCount: 1
                ).toDictionary()
            }
            
            return ActionResult<GoalView>(
                success: false,
                message: "Failed to create goal"
            ).toDictionary()
            
        } catch {
            return ActionResult<GoalView>(
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
            let req = try ParameterDecoder.decode(GoalUpdateRequest.self, from: parameters)
            
            guard let uuid = UUID(uuidString: req.id),
                  let goal = goalManager.goals.first(where: { $0.id == uuid }) else {
                return ActionResult<GoalView>(
                    success: false,
                    message: "Goal not found"
                ).toDictionary()
            }
            
            // Update main properties through manager
            if let title = req.title {
                goal.title = title
            }
            if let desc = req.desc {
                goal.desc = desc
            }
            if let targetValue = req.targetValue {
                goal.targetValue = targetValue
            }
            if let currentValue = req.currentValue {
                goal.currentValue = currentValue
                // Check if goal is completed
                if currentValue >= goal.targetValue {
                    goal.isCompleted = true
                    // Goal completed
                }
            }
            if let unit = req.unit {
                goal.unit = unit
            }
            if let targetDate = req.targetDate {
                goal.targetDate = DateParsingUtility.parseDate(targetDate)
            }
            if let category = categoryResolver.resolve(id: req.categoryId, name: req.category) {
                goal.category = category
            }
            if let priorityStr = req.priority {
                let priority: GoalPriority = {
                    switch priorityStr.lowercased() {
                    case "high": return .high
                    case "low": return .low
                    default: return .medium
                    }
                }()
                goal.priority = priority.rawValue
            }
            if let isCompleted = req.isCompleted {
                goal.isCompleted = isCompleted
            }
            
            try? context.save()
            
            return ActionResult<GoalView>(
                success: true,
                message: "Updated goal",
                id: goal.id?.uuidString,
                updatedCount: 1
            ).toDictionary()
            
        } catch {
            return ActionResult<GoalView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
    
    // MARK: - Delete
    func delete(_ parameters: [String: Any]) async -> [String: Any] {
        // Check for bulk delete
        if parameters["deleteAll"] as? Bool == true {
            let goals = goalManager.goals
            
            do {
                try BulkDeleteGuard.check(parameters: parameters, count: goals.count)
                
                var deleted = 0
                for goal in goals {
                    if case .success = goalManager.deleteGoal(goal) {
                        deleted += 1
                    }
                }
                
                return ActionResult<GoalView>(
                    success: true,
                    message: "Deleted \(deleted) goals",
                    matchedCount: goals.count,
                    updatedCount: deleted
                ).toDictionary()
                
            } catch {
                return ActionResult<GoalView>(
                    success: false,
                    message: error.localizedDescription,
                    matchedCount: goals.count
                ).toDictionary()
            }
        }
        
        // Delete by IDs
        if let ids = parameters["ids"] as? [String] {
            var deleted = 0
            
            for id in ids {
                if let uuid = UUID(uuidString: id),
                   let goal = goalManager.goals.first(where: { $0.id == uuid }),
                   case .success = goalManager.deleteGoal(goal) {
                    deleted += 1
                }
            }
            
            return ActionResult<GoalView>(
                success: deleted > 0,
                message: "Deleted \(deleted) goals",
                matchedCount: ids.count,
                updatedCount: deleted
            ).toDictionary()
        }
        
        // Single delete
        if let id = parameters["id"] as? String,
           let uuid = UUID(uuidString: id),
           let goal = goalManager.goals.first(where: { $0.id == uuid }),
           case .success = goalManager.deleteGoal(goal) {
            
            return ActionResult<GoalView>(
                success: true,
                message: "Deleted goal",
                id: id,
                matchedCount: 1,
                updatedCount: 1
            ).toDictionary()
        }
        
        return ActionResult<GoalView>(
            success: false,
            message: "Failed to delete - no valid parameters provided"
        ).toDictionary()
    }
    
    // MARK: - List
    func list(_ parameters: [String: Any]) async -> [String: Any] {
        let filter = parameters["filter"] as? String
        var goals = goalManager.goals
        
        // Apply filters
        if let filter = filter?.lowercased() {
            switch filter {
            case "active", "incomplete":
                goals = goals.filter { !$0.isCompleted }
            case "completed":
                goals = goals.filter { $0.isCompleted }
            case "overdue":
                let now = Date()
                goals = goals.filter { goal in
                    guard let targetDate = goal.targetDate, !goal.isCompleted else { return false }
                    return targetDate < now
                }
            case "high", "high-priority":
                goals = goals.filter { $0.priority == GoalPriority.high.rawValue }
            case "medium", "medium-priority":
                goals = goals.filter { $0.priority == GoalPriority.medium.rawValue }
            case "low", "low-priority":
                goals = goals.filter { $0.priority == GoalPriority.low.rawValue }
            default:
                break
            }
        }
        
        let views = goals.compactMap { goal -> GoalView? in
            guard let id = goal.id?.uuidString else { return nil }
            
            let progress = goal.targetValue > 0 ? (goal.currentValue / goal.targetValue) : 0
            
            return GoalView(
                id: id,
                title: goal.title ?? "",
                description: goal.desc ?? "",
                targetValue: goal.targetValue,
                currentValue: goal.currentValue,
                unit: goal.unit ?? "",
                targetDate: DateParsingUtility.formatDate(goal.targetDate),
                isCompleted: goal.isCompleted,
                category: goal.category?.name ?? "",
                priority: {
                    switch goal.priority {
                    case GoalPriority.high.rawValue: return "high"
                    case GoalPriority.low.rawValue: return "low"
                    default: return "medium"
                    }
                }(),
                progress: progress,
                createdAt: DateParsingUtility.formatDate(goal.createdAt) ?? "",
                completedAt: goal.isCompleted ? DateParsingUtility.formatDate(Date()) : nil
            )
        }
        
        return ActionResult(
            success: true,
            message: "Found \(views.count) goals",
            items: views,
            matchedCount: views.count
        ).toDictionary()
    }
    
    // MARK: - Update Progress
    func updateProgress(_ parameters: [String: Any]) async -> [String: Any] {
        do {
            let req = try ParameterDecoder.decode(GoalProgressRequest.self, from: parameters)
            
            guard let uuid = UUID(uuidString: req.id),
                  let goal = goalManager.goals.first(where: { $0.id == uuid }) else {
                return ActionResult<GoalView>(
                    success: false,
                    message: "Goal not found"
                ).toDictionary()
            }
            
            // Update progress
            if let value = req.value {
                goal.currentValue = value
            } else if let increment = req.increment {
                goal.currentValue += increment
            } else {
                return ActionResult<GoalView>(
                    success: false,
                    message: "No value or increment provided"
                ).toDictionary()
            }
            
            // Check if goal is completed
            if goal.currentValue >= goal.targetValue {
                goal.isCompleted = true
                goal.completedDate = Date()
            }
            
            try? context.save()
            
            let progress = goal.targetValue > 0 ? (goal.currentValue / goal.targetValue) : 0
            let message = goal.isCompleted 
                ? "Goal completed! Progress: \(Int(progress * 100))%"
                : "Updated progress: \(Int(progress * 100))%"
            
            return ActionResult<GoalView>(
                success: true,
                message: message,
                id: goal.id?.uuidString,
                updatedCount: 1
            ).toDictionary()
            
        } catch {
            return ActionResult<GoalView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
    
    // MARK: - Bulk Helpers
    
    private func bulkCreate(_ items: Any) async -> [String: Any] {
        do {
            let requests = try ParameterDecoder.decodeArray(GoalCreateRequest.self, from: items)
            var created = 0
            var errors: [String] = []
            
            for req in requests {
                let priority: GoalPriority = {
                    switch req.priority.lowercased() {
                    case "high": return .high
                    case "low": return .low
                    default: return .medium
                    }
                }()
                
                let result = goalManager.createGoal(
                    title: req.title,
                    description: req.desc,
                    targetValue: req.targetValue,
                    targetDate: DateParsingUtility.parseDate(req.targetDate),
                    unit: req.unit,
                    priority: priority,
                    category: categoryResolver.resolve(id: req.categoryId, name: req.category)
                )
                
                if case .success(let goal) = result {
                    goal.currentValue = req.currentValue
                    created += 1
                } else {
                    errors.append("\(req.title): create failed")
                }
            }
            
            try? context.save()
            
            let message = errors.isEmpty
                ? "Created \(created) goals"
                : "Created \(created) goals. Errors: \(errors.joined(separator: "; "))"
            
            return ActionResult<GoalView>(
                success: created > 0,
                message: message,
                updatedCount: created
            ).toDictionary()
            
        } catch {
            return ActionResult<GoalView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
    
    private func bulkUpdate(_ items: Any) async -> [String: Any] {
        do {
            let requests = try ParameterDecoder.decodeArray(GoalUpdateRequest.self, from: items)
            var updated = 0
            var errors: [String] = []
            
            for req in requests {
                guard let uuid = UUID(uuidString: req.id),
                      let goal = goalManager.goals.first(where: { $0.id == uuid }) else {
                    errors.append("Goal not found: \(req.id)")
                    continue
                }
                
                // Update properties
                if let title = req.title {
                    goal.title = title
                }
                if let desc = req.desc {
                    goal.desc = desc
                }
                if let targetValue = req.targetValue {
                    goal.targetValue = targetValue
                }
                if let currentValue = req.currentValue {
                    goal.currentValue = currentValue
                }
                if let unit = req.unit {
                    goal.unit = unit
                }
                if let targetDate = req.targetDate {
                    goal.targetDate = DateParsingUtility.parseDate(targetDate)
                }
                if let category = categoryResolver.resolve(id: req.categoryId, name: req.category) {
                    goal.category = category
                }
                if let priorityStr = req.priority {
                    let priority: GoalPriority = {
                        switch priorityStr.lowercased() {
                        case "high": return .high
                        case "low": return .low
                        default: return .medium
                        }
                    }()
                    goal.priority = priority.rawValue
                }
                if let isCompleted = req.isCompleted {
                    goal.isCompleted = isCompleted
                }
                
                updated += 1
            }
            
            try? context.save()
            
            let message = errors.isEmpty
                ? "Updated \(updated) goals"
                : "Updated \(updated) goals. Errors: \(errors.joined(separator: "; "))"
            
            return ActionResult<GoalView>(
                success: updated > 0,
                message: message,
                updatedCount: updated
            ).toDictionary()
            
        } catch {
            return ActionResult<GoalView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
}