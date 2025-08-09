//
//  AICoordinator.swift
//  Momentum
//
//  Coordinates all AI services and routes function calls to the appropriate service
//

import Foundation
import CoreData

final class AICoordinator {
    
    private let context: NSManagedObjectContext
    private let eventService: EventAIService
    private let taskService: TaskAIService
    private let habitService: HabitAIService
    private let goalService: GoalAIService
    private let categoryService: CategoryAIService
    private let logger = AILogger.shared
    
    init(context: NSManagedObjectContext,
         scheduleManager: ScheduleManaging,
         taskManager: TaskManager,
         goalManager: GoalManager) {
        self.context = context
        self.eventService = EventAIService(context: context, scheduleManager: scheduleManager)
        self.taskService = TaskAIService(context: context, taskManager: taskManager)
        self.habitService = HabitAIService(context: context)
        self.goalService = GoalAIService(context: context, goalManager: goalManager)
        self.categoryService = CategoryAIService(context: context)
    }
    
    // MARK: - Main Entry Points (5 Simple Functions)
    
    func manage_events(action: String, parameters: [String: Any]) async -> [String: Any] {
        logger.log("Managing events: \(action)", level: .info)
        let result = await eventService.process(action: action, parameters: parameters)
        return formatResult(result)
    }
    
    func manage_tasks(action: String, parameters: [String: Any]) async -> [String: Any] {
        logger.log("Managing tasks: \(action)", level: .info)
        let result = await taskService.process(action: action, parameters: parameters)
        return formatResult(result)
    }
    
    func manage_habits(action: String, parameters: [String: Any]) async -> [String: Any] {
        logger.log("Managing habits: \(action)", level: .info)
        
        if action.lowercased() == "log" || action.lowercased() == "complete" {
            if let habitId = parameters["id"] as? String {
                let result = await habitService.logCompletion(habitId: habitId)
                return formatResult(result)
            }
        }
        
        let result = await habitService.process(action: action, parameters: parameters)
        return formatResult(result)
    }
    
    func manage_goals(action: String, parameters: [String: Any]) async -> [String: Any] {
        logger.log("Managing goals: \(action)", level: .info)
        
        if action.lowercased().contains("milestone") {
            return await handleMilestoneAction(action: action, parameters: parameters)
        }
        
        let result = await goalService.process(action: action, parameters: parameters)
        return formatResult(result)
    }
    
    func manage_categories(action: String, parameters: [String: Any]) async -> [String: Any] {
        logger.log("Managing categories: \(action)", level: .info)
        let result = await categoryService.process(action: action, parameters: parameters)
        return formatResult(result)
    }
    
    // MARK: - Helper Methods
    
    private func handleMilestoneAction(action: String, parameters: [String: Any]) async -> [String: Any] {
        // Milestones not currently implemented in data model
        return formatResult(AIResult.failure("Milestone operations are not currently available"))
    }
    
    private func formatResult(_ result: AIResult) -> [String: Any] {
        var response: [String: Any] = [
            "success": result.success,
            "message": result.message
        ]
        
        if let data = result.data {
            response["data"] = data
        }
        
        if let error = result.error {
            response["error"] = error.localizedDescription
        }
        
        return response
    }
}