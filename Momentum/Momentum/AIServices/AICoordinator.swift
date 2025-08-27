//
//  AICoordinator.swift
//  Momentum
//
//  AI Coordinator - Pure router delegating to domain handlers
//

import Foundation
import CoreData

@MainActor
final class AICoordinator {
    
    private let context: NSManagedObjectContext
    private let scheduleManager: ScheduleManaging
    private let taskManager: TaskManager
    private let goalManager: GoalManager
    private let habitManager: HabitManaging
    
    // Domain Handlers
    private let eventsHandler: EventsHandling
    private let tasksHandler: TasksHandling
    private let habitsHandler: HabitsHandling
    private let goalsHandler: GoalsHandling
    private let categoriesHandler: CategoriesHandling
    
    init(context: NSManagedObjectContext,
         scheduleManager: ScheduleManaging,
         taskManager: TaskManager,
         goalManager: GoalManager,
         habitManager: HabitManaging? = nil) {
        self.context = context
        self.scheduleManager = scheduleManager
        self.taskManager = taskManager
        self.goalManager = goalManager
        self.habitManager = habitManager ?? HabitManager.shared
        
        // Initialize all handlers
        self.eventsHandler = EventsHandler(context: context, scheduleManager: scheduleManager)
        self.tasksHandler = TasksHandler(taskManager: taskManager, scheduleManager: scheduleManager, context: context)
        self.habitsHandler = HabitsHandler(habitManager: self.habitManager, scheduleManager: scheduleManager, context: context)
        self.goalsHandler = GoalsHandler(goalManager: goalManager, scheduleManager: scheduleManager, context: context)
        self.categoriesHandler = CategoriesHandler(
            scheduleManager: scheduleManager,
            taskManager: taskManager,
            habitManager: self.habitManager,
            goalManager: goalManager,
            context: context
        )
    }
    
    // MARK: - Events Management
    
    func manage_events(action: String, parameters: [String: Any]) async -> [String: Any] {
        print("🎯 AICoordinator.manage_events - Action: \(action)")
        
        switch action.lowercased() {
        case "create":
            return await eventsHandler.create(parameters)
        case "update":
            return await eventsHandler.update(parameters)
        case "delete":
            return await eventsHandler.delete(parameters)
        case "list":
            return await eventsHandler.list(parameters)
        default:
            return ActionResult<EmptyPayload>(
                success: false,
                message: "Unknown action: \(action)"
            ).toDictionary()
        }
    }
    
    // MARK: - Tasks Management
    
    func manage_tasks(action: String, parameters: [String: Any]) async -> [String: Any] {
        print("🎯 AICoordinator.manage_tasks - Action: \(action)")
        
        switch action.lowercased() {
        case "create":
            return await tasksHandler.create(parameters)
        case "update":
            return await tasksHandler.update(parameters)
        case "delete":
            return await tasksHandler.delete(parameters)
        case "list":
            return await tasksHandler.list(parameters)
        case "complete":
            var params = parameters
            params["isCompleted"] = true
            return await tasksHandler.update(params)
        default:
            return ActionResult<EmptyPayload>(
                success: false,
                message: "Unknown action: \(action)"
            ).toDictionary()
        }
    }
    
    // MARK: - Habits Management
    
    func manage_habits(action: String, parameters: [String: Any]) async -> [String: Any] {
        print("🎯 AICoordinator.manage_habits - Action: \(action)")
        
        switch action.lowercased() {
        case "create":
            return await habitsHandler.create(parameters)
        case "update":
            return await habitsHandler.update(parameters)
        case "delete":
            return await habitsHandler.delete(parameters)
        case "list":
            return await habitsHandler.list(parameters)
        case "log", "complete", "log_progress":
            return await habitsHandler.log(parameters)
        default:
            return ActionResult<EmptyPayload>(
                success: false,
                message: "Unknown action: \(action)"
            ).toDictionary()
        }
    }
    
    // MARK: - Goals Management
    
    func manage_goals(action: String, parameters: [String: Any]) async -> [String: Any] {
        print("🎯 AICoordinator.manage_goals - Action: \(action)")
        
        switch action.lowercased() {
        case "create":
            return await goalsHandler.create(parameters)
        case "update":
            return await goalsHandler.update(parameters)
        case "delete":
            return await goalsHandler.delete(parameters)
        case "list":
            return await goalsHandler.list(parameters)
        case "update_progress", "progress":
            return await goalsHandler.updateProgress(parameters)
        case "complete":
            var params = parameters
            params["isCompleted"] = true
            return await goalsHandler.update(params)
        default:
            return ActionResult<EmptyPayload>(
                success: false,
                message: "Unknown action: \(action)"
            ).toDictionary()
        }
    }
    
    // MARK: - Categories Management
    
    func manage_categories(action: String, parameters: [String: Any]) async -> [String: Any] {
        print("🎯 AICoordinator.manage_categories - Action: \(action)")
        
        switch action.lowercased() {
        case "create":
            return await categoriesHandler.create(parameters)
        case "update":
            return await categoriesHandler.update(parameters)
        case "delete":
            return await categoriesHandler.delete(parameters)
        case "list":
            return await categoriesHandler.list(parameters)
        default:
            return ActionResult<EmptyPayload>(
                success: false,
                message: "Unknown action: \(action)"
            ).toDictionary()
        }
    }
}