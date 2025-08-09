//
//  SimplifiedAISystem.swift
//  Momentum
//
//  5 simple functions to replace 103 complex ones
//  Each function handles full CRUD + bulk operations
//

import Foundation
import CoreData

class SimplifiedAISystem {
    
    // MARK: - Dependencies
    private let scheduleManager: ScheduleManaging
    private let taskManager: TaskManaging
    private let habitManager: HabitManaging
    private let goalManager: GoalManager
    private let context: NSManagedObjectContext
    
    init(scheduleManager: ScheduleManaging,
         taskManager: TaskManaging,
         habitManager: HabitManaging,
         goalManager: GoalManager,
         context: NSManagedObjectContext) {
        self.scheduleManager = scheduleManager
        self.taskManager = taskManager
        self.habitManager = habitManager
        self.goalManager = goalManager
        self.context = context
    }
    
    // MARK: - 1. EVENTS (handles all event operations)
    
    func manage_events(action: String, parameters: [String: Any]) async -> [String: Any] {
        let action = action.lowercased()
        
        switch action {
        case "create":
            // Handle single or multiple
            if let items = parameters["items"] as? [[String: Any]] {
                return await createMultipleEvents(items)
            } else {
                return await createSingleEvent(parameters)
            }
            
        case "update":
            // Handle single, multiple, or all
            if let filter = parameters["filter"] as? String, filter == "all" {
                return await updateAllEvents(parameters["updates"] as? [String: Any] ?? [:])
            } else if let ids = parameters["ids"] as? [String] {
                return await updateMultipleEvents(ids: ids, updates: parameters["updates"] as? [String: Any] ?? [:])
            } else if let id = parameters["id"] as? String {
                return await updateSingleEvent(id: id, updates: parameters)
            }
            return ["success": false, "message": "Specify id, ids, or filter:'all'"]
            
        case "delete":
            // Handle single, multiple, or filtered
            if let filter = parameters["filter"] {
                return await deleteFilteredEvents(filter: filter)
            } else if let ids = parameters["ids"] as? [String] {
                return await deleteMultipleEvents(ids: ids)
            } else if let id = parameters["id"] as? String {
                return await deleteSingleEvent(id: id)
            }
            return ["success": false, "message": "Specify id, ids, or filter"]
            
        case "list", "get":
            return await listEvents(filter: parameters["filter"])
            
        default:
            return ["success": false, "message": "Unknown action: \(action). Use: create, update, delete, list"]
        }
    }
    
    // MARK: - 2. TASKS (handles all task operations)
    
    func manage_tasks(action: String, parameters: [String: Any]) async -> [String: Any] {
        let action = action.lowercased()
        
        switch action {
        case "create":
            if let items = parameters["items"] as? [[String: Any]] {
                return await createMultipleTasks(items)
            } else {
                return await createSingleTask(parameters)
            }
            
        case "update":
            if let filter = parameters["filter"] as? String, filter == "all" {
                return await updateAllTasks(parameters["updates"] as? [String: Any] ?? [:])
            } else if let ids = parameters["ids"] as? [String] {
                return await updateMultipleTasks(ids: ids, updates: parameters["updates"] as? [String: Any] ?? [:])
            } else if let id = parameters["id"] as? String {
                return await updateSingleTask(id: id, updates: parameters)
            }
            return ["success": false, "message": "Specify id, ids, or filter:'all'"]
            
        case "delete":
            if let filter = parameters["filter"] {
                return await deleteFilteredTasks(filter: filter)
            } else if let ids = parameters["ids"] as? [String] {
                return await deleteMultipleTasks(ids: ids)
            } else if let id = parameters["id"] as? String {
                return await deleteSingleTask(id: id)
            }
            return ["success": false, "message": "Specify id, ids, or filter"]
            
        case "complete":
            if let filter = parameters["filter"] as? String, filter == "all" {
                return await completeAllTasks()
            } else if let ids = parameters["ids"] as? [String] {
                return await completeMultipleTasks(ids: ids)
            } else if let id = parameters["id"] as? String {
                return await completeSingleTask(id: id)
            }
            return ["success": false, "message": "Specify id, ids, or filter:'all'"]
            
        case "list", "get":
            return await listTasks(filter: parameters["filter"])
            
        default:
            return ["success": false, "message": "Unknown action: \(action). Use: create, update, delete, complete, list"]
        }
    }
    
    // MARK: - 3. HABITS (handles all habit operations)
    
    func manage_habits(action: String, parameters: [String: Any]) async -> [String: Any] {
        let action = action.lowercased()
        
        switch action {
        case "create":
            if let items = parameters["items"] as? [[String: Any]] {
                return await createMultipleHabits(items)
            } else {
                return await createSingleHabit(parameters)
            }
            
        case "update":
            if let filter = parameters["filter"] as? String, filter == "all" {
                return await updateAllHabits(parameters["updates"] as? [String: Any] ?? [:])
            } else if let ids = parameters["ids"] as? [String] {
                return await updateMultipleHabits(ids: ids, updates: parameters["updates"] as? [String: Any] ?? [:])
            } else if let id = parameters["id"] as? String {
                return await updateSingleHabit(id: id, updates: parameters)
            }
            return ["success": false, "message": "Specify id, ids, or filter:'all'"]
            
        case "delete":
            if let filter = parameters["filter"] {
                return await deleteFilteredHabits(filter: filter)
            } else if let ids = parameters["ids"] as? [String] {
                return await deleteMultipleHabits(ids: ids)
            } else if let id = parameters["id"] as? String {
                return await deleteSingleHabit(id: id)
            }
            return ["success": false, "message": "Specify id, ids, or filter"]
            
        case "log":
            if let id = parameters["id"] as? String {
                return await logHabit(id: id, value: parameters["value"] as? Double ?? 1.0)
            }
            return ["success": false, "message": "Specify habit id to log"]
            
        case "list", "get":
            return await listHabits(filter: parameters["filter"])
            
        default:
            return ["success": false, "message": "Unknown action: \(action). Use: create, update, delete, log, list"]
        }
    }
    
    // MARK: - 4. GOALS (handles all goal operations + milestones)
    
    func manage_goals(action: String, parameters: [String: Any]) async -> [String: Any] {
        let action = action.lowercased()
        
        switch action {
        case "create":
            if let items = parameters["items"] as? [[String: Any]] {
                return await createMultipleGoals(items)
            } else {
                return await createSingleGoal(parameters)
            }
            
        case "update":
            if let filter = parameters["filter"] as? String, filter == "all" {
                return await updateAllGoals(parameters["updates"] as? [String: Any] ?? [:])
            } else if let ids = parameters["ids"] as? [String] {
                return await updateMultipleGoals(ids: ids, updates: parameters["updates"] as? [String: Any] ?? [:])
            } else if let id = parameters["id"] as? String {
                return await updateSingleGoal(id: id, updates: parameters)
            }
            return ["success": false, "message": "Specify id, ids, or filter:'all'"]
            
        case "delete":
            if let filter = parameters["filter"] {
                return await deleteFilteredGoals(filter: filter)
            } else if let ids = parameters["ids"] as? [String] {
                return await deleteMultipleGoals(ids: ids)
            } else if let id = parameters["id"] as? String {
                return await deleteSingleGoal(id: id)
            }
            return ["success": false, "message": "Specify id, ids, or filter"]
            
        case "add_milestones":
            if let goalId = parameters["goalId"] as? String,
               let milestones = parameters["milestones"] as? [[String: Any]] {
                return await addMilestones(to: goalId, milestones: milestones)
            }
            return ["success": false, "message": "Specify goalId and milestones array"]
            
        case "complete":
            if let id = parameters["id"] as? String {
                return await completeGoal(id: id)
            }
            return ["success": false, "message": "Specify goal id"]
            
        case "list", "get":
            return await listGoals(filter: parameters["filter"])
            
        default:
            return ["success": false, "message": "Unknown action: \(action). Use: create, update, delete, add_milestones, complete, list"]
        }
    }
    
    // MARK: - 5. CATEGORIES (handles all category operations)
    
    func manage_categories(action: String, parameters: [String: Any]) async -> [String: Any] {
        let action = action.lowercased()
        
        switch action {
        case "create":
            if let items = parameters["items"] as? [[String: Any]] {
                return await createMultipleCategories(items)
            } else {
                return await createSingleCategory(parameters)
            }
            
        case "update":
            if let id = parameters["id"] as? String {
                return await updateCategory(id: id, updates: parameters)
            }
            return ["success": false, "message": "Specify category id"]
            
        case "delete":
            if let id = parameters["id"] as? String {
                return await deleteCategory(id: id)
            }
            return ["success": false, "message": "Specify category id"]
            
        case "list", "get":
            return await listCategories()
            
        default:
            return ["success": false, "message": "Unknown action: \(action). Use: create, update, delete, list"]
        }
    }
}

// MARK: - Private Implementation Methods

extension SimplifiedAISystem {
    
    // MARK: Events Implementation
    
    private func createSingleEvent(_ params: [String: Any]) async -> [String: Any] {
        guard let title = params["title"] as? String,
              let startTime = params["startTime"] as? Date ?? parseDate(params["startTime"]),
              let endTime = params["endTime"] as? Date ?? parseDate(params["endTime"]) else {
            return ["success": false, "message": "Missing title, startTime, or endTime"]
        }
        
        let category = findCategory(params["category"])
        let result = scheduleManager.createEvent(
            title: title,
            startTime: startTime,
            endTime: endTime,
            category: category,
            notes: params["notes"] as? String,
            location: params["location"] as? String,
            url: params["url"] as? String,
            reminder: params["reminder"] as? Int,
            isAllDay: params["isAllDay"] as? Bool ?? false
        )
        
        switch result {
        case .success(let event):
            return ["success": true, "message": "Created event: \(event.title ?? "")", "id": event.id?.uuidString ?? ""]
        case .failure(let error):
            return ["success": false, "message": error.localizedDescription]
        }
    }
    
    private func createMultipleEvents(_ items: [[String: Any]]) async -> [String: Any] {
        var created = 0
        var failed = 0
        
        for item in items {
            let result = await createSingleEvent(item)
            if result["success"] as? Bool == true {
                created += 1
            } else {
                failed += 1
            }
        }
        
        return [
            "success": created > 0,
            "message": "Created \(created) events" + (failed > 0 ? ", \(failed) failed" : "")
        ]
    }
    
    private func updateAllEvents(_ updates: [String: Any]) async -> [String: Any] {
        let events = scheduleManager.events
        var updated = 0
        
        for event in events {
            // Apply updates to each event
            if let title = updates["title"] as? String {
                event.title = title
            }
            if let category = findCategory(updates["category"]) {
                event.category = category
            }
            if let notes = updates["notes"] as? String {
                event.notes = notes
            }
            if let isCompleted = updates["isCompleted"] as? Bool {
                event.isCompleted = isCompleted
            }
            updated += 1
        }
        
        do {
            try context.save()
            return ["success": true, "message": "Updated \(updated) events"]
        } catch {
            return ["success": false, "message": "Failed to save: \(error.localizedDescription)"]
        }
    }
    
    private func updateMultipleEvents(ids: [String], updates: [String: Any]) async -> [String: Any] {
        var updated = 0
        
        for idStr in ids {
            if let id = UUID(uuidString: idStr),
               let event = scheduleManager.events.first(where: { $0.id == id }) {
                // Apply updates
                if let title = updates["title"] as? String {
                    event.title = title
                }
                if let category = findCategory(updates["category"]) {
                    event.category = category
                }
                updated += 1
            }
        }
        
        do {
            try context.save()
            return ["success": true, "message": "Updated \(updated) events"]
        } catch {
            return ["success": false, "message": "Failed to save: \(error.localizedDescription)"]
        }
    }
    
    private func updateSingleEvent(id: String, updates: [String: Any]) async -> [String: Any] {
        return await updateMultipleEvents(ids: [id], updates: updates)
    }
    
    private func deleteFilteredEvents(filter: Any) async -> [String: Any] {
        var eventsToDelete: [Event] = []
        
        if let filterDict = filter as? [String: Any] {
            // Apply filters
            if let completed = filterDict["completed"] as? Bool {
                eventsToDelete = scheduleManager.events.filter { $0.isCompleted == completed }
            } else if filterDict["all"] as? Bool == true {
                eventsToDelete = scheduleManager.events
            }
        } else if let filterStr = filter as? String, filterStr == "all" {
            eventsToDelete = scheduleManager.events
        }
        
        for event in eventsToDelete {
            _ = scheduleManager.deleteEvent(event)
        }
        
        return ["success": true, "message": "Deleted \(eventsToDelete.count) events"]
    }
    
    private func deleteMultipleEvents(ids: [String]) async -> [String: Any] {
        var deleted = 0
        
        for idStr in ids {
            if let id = UUID(uuidString: idStr),
               let event = scheduleManager.events.first(where: { $0.id == id }) {
                _ = scheduleManager.deleteEvent(event)
                deleted += 1
            }
        }
        
        return ["success": true, "message": "Deleted \(deleted) events"]
    }
    
    private func deleteSingleEvent(id: String) async -> [String: Any] {
        return await deleteMultipleEvents(ids: [id])
    }
    
    private func listEvents(filter: Any?) async -> [String: Any] {
        var events = scheduleManager.events
        
        if let filterDict = filter as? [String: Any] {
            if let date = filterDict["date"] as? Date {
                events = scheduleManager.events(for: date)
            } else if filterDict["today"] as? Bool == true {
                events = scheduleManager.eventsForToday()
            } else if let completed = filterDict["completed"] as? Bool {
                events = events.filter { $0.isCompleted == completed }
            }
        }
        
        let eventData = events.map { event in
            [
                "id": event.id?.uuidString ?? "",
                "title": event.title ?? "",
                "startTime": ISO8601DateFormatter().string(from: event.startTime ?? Date()),
                "endTime": ISO8601DateFormatter().string(from: event.endTime ?? Date()),
                "category": event.category?.name ?? "",
                "isCompleted": event.isCompleted
            ]
        }
        
        return ["success": true, "count": events.count, "events": eventData]
    }
    
    // MARK: Tasks Implementation
    
    private func createSingleTask(_ params: [String: Any]) async -> [String: Any] {
        guard let title = params["title"] as? String else {
            return ["success": false, "message": "Missing title"]
        }
        
        let category = findCategory(params["category"])
        let priority = TaskPriority(rawValue: params["priority"] as? Int16 ?? 1) ?? .medium
        
        let result = taskManager.createTask(
            title: title,
            notes: params["notes"] as? String,
            dueDate: params["dueDate"] as? Date ?? parseDate(params["dueDate"]),
            priority: priority,
            category: category,
            estimatedDuration: params["duration"] as? Int32 ?? 0
        )
        
        switch result {
        case .success(let task):
            return ["success": true, "message": "Created task: \(task.title ?? "")", "id": task.id?.uuidString ?? ""]
        case .failure(let error):
            return ["success": false, "message": error.localizedDescription]
        }
    }
    
    private func createMultipleTasks(_ items: [[String: Any]]) async -> [String: Any] {
        var created = 0
        var failed = 0
        
        for item in items {
            let result = await createSingleTask(item)
            if result["success"] as? Bool == true {
                created += 1
            } else {
                failed += 1
            }
        }
        
        return [
            "success": created > 0,
            "message": "Created \(created) tasks" + (failed > 0 ? ", \(failed) failed" : "")
        ]
    }
    
    private func updateAllTasks(_ updates: [String: Any]) async -> [String: Any] {
        let tasks = taskManager.tasks
        var updated = 0
        
        for task in tasks {
            if let title = updates["title"] as? String {
                task.title = title
            }
            if let dueDate = parseDate(updates["dueDate"]) {
                task.dueDate = dueDate
            }
            if let priority = updates["priority"] as? Int16 {
                task.priority = priority
            }
            if let category = findCategory(updates["category"]) {
                task.category = category
            }
            updated += 1
        }
        
        do {
            try context.save()
            return ["success": true, "message": "Updated \(updated) tasks"]
        } catch {
            return ["success": false, "message": "Failed to save: \(error.localizedDescription)"]
        }
    }
    
    private func updateMultipleTasks(ids: [String], updates: [String: Any]) async -> [String: Any] {
        var updated = 0
        
        for idStr in ids {
            if let id = UUID(uuidString: idStr),
               let task = taskManager.tasks.first(where: { $0.id == id }) {
                if let title = updates["title"] as? String {
                    task.title = title
                }
                if let dueDate = parseDate(updates["dueDate"]) {
                    task.dueDate = dueDate
                }
                updated += 1
            }
        }
        
        do {
            try context.save()
            return ["success": true, "message": "Updated \(updated) tasks"]
        } catch {
            return ["success": false, "message": "Failed to save: \(error.localizedDescription)"]
        }
    }
    
    private func updateSingleTask(id: String, updates: [String: Any]) async -> [String: Any] {
        return await updateMultipleTasks(ids: [id], updates: updates)
    }
    
    private func completeAllTasks() async -> [String: Any] {
        let tasks = taskManager.tasks.filter { !$0.isCompleted }
        var completed = 0
        
        for task in tasks {
            _ = taskManager.completeTask(task)
            completed += 1
        }
        
        return ["success": true, "message": "Completed \(completed) tasks"]
    }
    
    private func completeMultipleTasks(ids: [String]) async -> [String: Any] {
        var completed = 0
        
        for idStr in ids {
            if let id = UUID(uuidString: idStr),
               let task = taskManager.tasks.first(where: { $0.id == id }) {
                _ = taskManager.completeTask(task)
                completed += 1
            }
        }
        
        return ["success": true, "message": "Completed \(completed) tasks"]
    }
    
    private func completeSingleTask(id: String) async -> [String: Any] {
        return await completeMultipleTasks(ids: [id])
    }
    
    private func deleteFilteredTasks(filter: Any) async -> [String: Any] {
        var tasksToDelete: [Task] = []
        
        if let filterDict = filter as? [String: Any] {
            if let completed = filterDict["completed"] as? Bool {
                tasksToDelete = taskManager.tasks.filter { $0.isCompleted == completed }
            } else if filterDict["all"] as? Bool == true {
                tasksToDelete = taskManager.tasks
            }
        }
        
        for task in tasksToDelete {
            _ = taskManager.deleteTask(task)
        }
        
        return ["success": true, "message": "Deleted \(tasksToDelete.count) tasks"]
    }
    
    private func deleteMultipleTasks(ids: [String]) async -> [String: Any] {
        var deleted = 0
        
        for idStr in ids {
            if let id = UUID(uuidString: idStr),
               let task = taskManager.tasks.first(where: { $0.id == id }) {
                _ = taskManager.deleteTask(task)
                deleted += 1
            }
        }
        
        return ["success": true, "message": "Deleted \(deleted) tasks"]
    }
    
    private func deleteSingleTask(id: String) async -> [String: Any] {
        return await deleteMultipleTasks(ids: [id])
    }
    
    private func listTasks(filter: Any?) async -> [String: Any] {
        var tasks = taskManager.tasks
        
        if let filterDict = filter as? [String: Any] {
            if let completed = filterDict["completed"] as? Bool {
                tasks = tasks.filter { $0.isCompleted == completed }
            }
            if let priority = filterDict["priority"] as? Int16 {
                tasks = tasks.filter { $0.priority == priority }
            }
        }
        
        let taskData = tasks.map { task in
            [
                "id": task.id?.uuidString ?? "",
                "title": task.title ?? "",
                "dueDate": task.dueDate != nil ? ISO8601DateFormatter().string(from: task.dueDate!) : "",
                "priority": task.priority,
                "isCompleted": task.isCompleted,
                "category": task.category?.name ?? ""
            ] as [String : Any]
        }
        
        return ["success": true, "count": tasks.count, "tasks": taskData]
    }
    
    // MARK: Habits Implementation
    
    private func createSingleHabit(_ params: [String: Any]) async -> [String: Any] {
        guard let name = params["name"] as? String else {
            return ["success": false, "message": "Missing name"]
        }
        
        let category = findCategory(params["category"])
        let frequency = params["frequency"] as? String ?? "daily"
        
        let result = habitManager.createHabit(
            name: name,
            description: params["description"] as? String,
            frequency: frequency,
            goalTarget: params["target"] as? Double ?? 1.0,
            goalUnit: params["unit"] as? String,
            category: category,
            reminderTime: params["reminderTime"] as? Date,
            trackingType: params["trackingType"] as? String ?? "binary"
        )
        
        switch result {
        case .success(let habit):
            return ["success": true, "message": "Created habit: \(habit.name ?? "")", "id": habit.id?.uuidString ?? ""]
        case .failure(let error):
            return ["success": false, "message": error.localizedDescription]
        }
    }
    
    private func createMultipleHabits(_ items: [[String: Any]]) async -> [String: Any] {
        var created = 0
        
        for item in items {
            let result = await createSingleHabit(item)
            if result["success"] as? Bool == true {
                created += 1
            }
        }
        
        return ["success": true, "message": "Created \(created) habits"]
    }
    
    private func updateAllHabits(_ updates: [String: Any]) async -> [String: Any] {
        let habits = habitManager.habits
        var updated = 0
        
        for habit in habits {
            _ = habitManager.updateHabit(
                habit,
                name: updates["name"] as? String,
                description: updates["description"] as? String,
                frequency: updates["frequency"] as? String,
                goalTarget: updates["target"] as? Double,
                goalUnit: updates["unit"] as? String,
                category: findCategory(updates["category"]),
                reminderTime: parseDate(updates["reminderTime"]),
                trackingType: updates["trackingType"] as? String
            )
            updated += 1
        }
        
        return ["success": true, "message": "Updated \(updated) habits"]
    }
    
    private func updateMultipleHabits(ids: [String], updates: [String: Any]) async -> [String: Any] {
        var updated = 0
        
        for idStr in ids {
            if let id = UUID(uuidString: idStr),
               let habit = habitManager.habits.first(where: { $0.id == id }) {
                _ = habitManager.updateHabit(
                    habit,
                    name: updates["name"] as? String,
                    description: updates["description"] as? String,
                    frequency: updates["frequency"] as? String,
                    goalTarget: updates["target"] as? Double,
                    goalUnit: updates["unit"] as? String,
                    category: findCategory(updates["category"]),
                    reminderTime: parseDate(updates["reminderTime"]),
                    trackingType: updates["trackingType"] as? String
                )
                updated += 1
            }
        }
        
        return ["success": true, "message": "Updated \(updated) habits"]
    }
    
    private func updateSingleHabit(id: String, updates: [String: Any]) async -> [String: Any] {
        return await updateMultipleHabits(ids: [id], updates: updates)
    }
    
    private func deleteFilteredHabits(filter: Any) async -> [String: Any] {
        var habitsToDelete: [Habit] = []
        
        if let filterDict = filter as? [String: Any] {
            if filterDict["all"] as? Bool == true {
                habitsToDelete = habitManager.habits
            }
        }
        
        for habit in habitsToDelete {
            _ = habitManager.deleteHabit(habit)
        }
        
        return ["success": true, "message": "Deleted \(habitsToDelete.count) habits"]
    }
    
    private func deleteMultipleHabits(ids: [String]) async -> [String: Any] {
        var deleted = 0
        
        for idStr in ids {
            if let id = UUID(uuidString: idStr),
               let habit = habitManager.habits.first(where: { $0.id == id }) {
                _ = habitManager.deleteHabit(habit)
                deleted += 1
            }
        }
        
        return ["success": true, "message": "Deleted \(deleted) habits"]
    }
    
    private func deleteSingleHabit(id: String) async -> [String: Any] {
        return await deleteMultipleHabits(ids: [id])
    }
    
    private func logHabit(id: String, value: Double) async -> [String: Any] {
        guard let uuid = UUID(uuidString: id),
              let habit = habitManager.habits.first(where: { $0.id == uuid }) else {
            return ["success": false, "message": "Habit not found"]
        }
        
        let result = habitManager.logHabit(habit, value: value, date: Date())
        
        switch result {
        case .success:
            return ["success": true, "message": "Logged habit: \(habit.name ?? "")"]
        case .failure(let error):
            return ["success": false, "message": error.localizedDescription]
        }
    }
    
    private func listHabits(filter: Any?) async -> [String: Any] {
        let habits = habitManager.habits
        
        let habitData = habits.map { habit in
            [
                "id": habit.id?.uuidString ?? "",
                "name": habit.name ?? "",
                "frequency": habit.frequency ?? "",
                "streak": habit.currentStreak,
                "category": habit.category?.name ?? ""
            ] as [String : Any]
        }
        
        return ["success": true, "count": habits.count, "habits": habitData]
    }
    
    // MARK: Goals Implementation
    
    private func createSingleGoal(_ params: [String: Any]) async -> [String: Any] {
        guard let title = params["title"] as? String else {
            return ["success": false, "message": "Missing title"]
        }
        
        let category = findCategory(params["category"])
        let priority = GoalPriority(rawValue: Int16(params["priority"] as? Int ?? 1)) ?? .medium
        
        let result = goalManager.createGoal(
            title: title,
            description: params["description"] as? String,
            targetValue: params["targetValue"] as? Double ?? 0,
            targetDate: parseDate(params["targetDate"]),
            unit: params["unit"] as? String,
            type: params["type"] as? String ?? "milestone",
            priority: priority,
            category: category
        )
        
        switch result {
        case .success(let goal):
            return ["success": true, "message": "Created goal: \(goal.title ?? "")", "id": goal.id?.uuidString ?? ""]
        case .failure(let error):
            return ["success": false, "message": error.localizedDescription]
        }
    }
    
    private func createMultipleGoals(_ items: [[String: Any]]) async -> [String: Any] {
        var created = 0
        
        for item in items {
            let result = await createSingleGoal(item)
            if result["success"] as? Bool == true {
                created += 1
            }
        }
        
        return ["success": true, "message": "Created \(created) goals"]
    }
    
    private func updateAllGoals(_ updates: [String: Any]) async -> [String: Any] {
        let goals = goalManager.goals
        var updated = 0
        
        for goal in goals {
            _ = goalManager.updateGoal(
                goal,
                title: updates["title"] as? String,
                description: updates["description"] as? String,
                targetValue: updates["targetValue"] as? Double,
                targetDate: parseDate(updates["targetDate"]),
                unit: updates["unit"] as? String,
                priority: updates["priority"] as? Int16 != nil ? GoalPriority(rawValue: updates["priority"] as! Int16) : nil,
                category: findCategory(updates["category"])
            )
            updated += 1
        }
        
        return ["success": true, "message": "Updated \(updated) goals"]
    }
    
    private func updateMultipleGoals(ids: [String], updates: [String: Any]) async -> [String: Any] {
        var updated = 0
        
        for idStr in ids {
            if let id = UUID(uuidString: idStr),
               let goal = goalManager.goals.first(where: { $0.id == id }) {
                _ = goalManager.updateGoal(
                    goal,
                    title: updates["title"] as? String,
                    description: updates["description"] as? String,
                    targetValue: updates["targetValue"] as? Double,
                    targetDate: parseDate(updates["targetDate"]),
                    unit: updates["unit"] as? String,
                    priority: updates["priority"] as? Int16 != nil ? GoalPriority(rawValue: updates["priority"] as! Int16) : nil,
                    category: findCategory(updates["category"])
                )
                updated += 1
            }
        }
        
        return ["success": true, "message": "Updated \(updated) goals"]
    }
    
    private func updateSingleGoal(id: String, updates: [String: Any]) async -> [String: Any] {
        return await updateMultipleGoals(ids: [id], updates: updates)
    }
    
    private func deleteFilteredGoals(filter: Any) async -> [String: Any] {
        var goalsToDelete: [Goal] = []
        
        if let filterDict = filter as? [String: Any] {
            if let completed = filterDict["completed"] as? Bool {
                goalsToDelete = goalManager.goals.filter { $0.isCompleted == completed }
            } else if filterDict["all"] as? Bool == true {
                goalsToDelete = goalManager.goals
            }
        }
        
        for goal in goalsToDelete {
            _ = goalManager.deleteGoal(goal)
        }
        
        return ["success": true, "message": "Deleted \(goalsToDelete.count) goals"]
    }
    
    private func deleteMultipleGoals(ids: [String]) async -> [String: Any] {
        var deleted = 0
        
        for idStr in ids {
            if let id = UUID(uuidString: idStr),
               let goal = goalManager.goals.first(where: { $0.id == id }) {
                _ = goalManager.deleteGoal(goal)
                deleted += 1
            }
        }
        
        return ["success": true, "message": "Deleted \(deleted) goals"]
    }
    
    private func deleteSingleGoal(id: String) async -> [String: Any] {
        return await deleteMultipleGoals(ids: [id])
    }
    
    private func addMilestones(to goalId: String, milestones: [[String: Any]]) async -> [String: Any] {
        guard let id = UUID(uuidString: goalId),
              let goal = goalManager.goals.first(where: { $0.id == id }) else {
            return ["success": false, "message": "Goal not found"]
        }
        
        var added = 0
        for milestone in milestones {
            if let title = milestone["title"] as? String {
                let result = goalManager.addMilestone(
                    to: goal,
                    title: title,
                    description: milestone["description"] as? String,
                    targetDate: parseDate(milestone["targetDate"]),
                    targetValue: milestone["targetValue"] as? Double
                )
                if case .success = result {
                    added += 1
                }
            }
        }
        
        return ["success": true, "message": "Added \(added) milestones to \(goal.title ?? "goal")"]
    }
    
    private func completeGoal(id: String) async -> [String: Any] {
        guard let uuid = UUID(uuidString: id),
              let goal = goalManager.goals.first(where: { $0.id == uuid }) else {
            return ["success": false, "message": "Goal not found"]
        }
        
        let result = goalManager.completeGoal(goal)
        
        switch result {
        case .success:
            return ["success": true, "message": "Completed goal: \(goal.title ?? "")"]
        case .failure(let error):
            return ["success": false, "message": error.localizedDescription]
        }
    }
    
    private func listGoals(filter: Any?) async -> [String: Any] {
        var goals = goalManager.goals
        
        if let filterDict = filter as? [String: Any] {
            if let completed = filterDict["completed"] as? Bool {
                goals = goals.filter { $0.isCompleted == completed }
            }
        }
        
        let goalData = goals.map { goal in
            [
                "id": goal.id?.uuidString ?? "",
                "title": goal.title ?? "",
                "progress": goal.progress,
                "targetDate": goal.targetDate != nil ? ISO8601DateFormatter().string(from: goal.targetDate!) : "",
                "isCompleted": goal.isCompleted,
                "category": goal.category?.name ?? ""
            ] as [String : Any]
        }
        
        return ["success": true, "count": goals.count, "goals": goalData]
    }
    
    // MARK: Categories Implementation
    
    private func createSingleCategory(_ params: [String: Any]) async -> [String: Any] {
        guard let name = params["name"] as? String else {
            return ["success": false, "message": "Missing name"]
        }
        
        let result = scheduleManager.createCategory(
            name: name,
            colorHex: params["color"] as? String ?? "#007AFF",
            iconName: params["icon"] as? String ?? "folder.fill"
        )
        
        switch result {
        case .success(let category):
            return ["success": true, "message": "Created category: \(category.name ?? "")", "id": category.id?.uuidString ?? ""]
        case .failure(let error):
            return ["success": false, "message": error.localizedDescription]
        }
    }
    
    private func createMultipleCategories(_ items: [[String: Any]]) async -> [String: Any] {
        var created = 0
        
        for item in items {
            let result = await createSingleCategory(item)
            if result["success"] as? Bool == true {
                created += 1
            }
        }
        
        return ["success": true, "message": "Created \(created) categories"]
    }
    
    private func updateCategory(id: String, updates: [String: Any]) async -> [String: Any] {
        guard let uuid = UUID(uuidString: id),
              let category = scheduleManager.categories.first(where: { $0.id == uuid }) else {
            return ["success": false, "message": "Category not found"]
        }
        
        if let name = updates["name"] as? String {
            category.name = name
        }
        if let color = updates["color"] as? String {
            category.colorHex = color
        }
        if let icon = updates["icon"] as? String {
            category.iconName = icon
        }
        
        do {
            try context.save()
            return ["success": true, "message": "Updated category: \(category.name ?? "")"]
        } catch {
            return ["success": false, "message": error.localizedDescription]
        }
    }
    
    private func deleteCategory(id: String) async -> [String: Any] {
        guard let uuid = UUID(uuidString: id),
              let category = scheduleManager.categories.first(where: { $0.id == uuid }) else {
            return ["success": false, "message": "Category not found"]
        }
        
        let result = scheduleManager.deleteCategory(category)
        
        switch result {
        case .success:
            return ["success": true, "message": "Deleted category: \(category.name ?? "")"]
        case .failure(let error):
            return ["success": false, "message": error.localizedDescription]
        }
    }
    
    private func listCategories() async -> [String: Any] {
        let categories = scheduleManager.categories
        
        let categoryData = categories.map { category in
            [
                "id": category.id?.uuidString ?? "",
                "name": category.name ?? "",
                "color": category.colorHex ?? "",
                "icon": category.iconName ?? ""
            ]
        }
        
        return ["success": true, "count": categories.count, "categories": categoryData]
    }
    
    // MARK: Helper Methods
    
    private func parseDate(_ value: Any?) -> Date? {
        if let date = value as? Date {
            return date
        }
        if let dateStr = value as? String {
            // Try ISO8601 first
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dateStr) {
                return date
            }
            
            // Try other formats
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: dateStr) {
                return date
            }
            
            // Natural language (end of year, tomorrow, etc)
            if dateStr.lowercased().contains("end of year") {
                let calendar = Calendar.current
                let year = calendar.component(.year, from: Date())
                return calendar.date(from: DateComponents(year: year, month: 12, day: 31))
            }
        }
        return nil
    }
    
    private func findCategory(_ value: Any?) -> Category? {
        if let categoryName = value as? String {
            return scheduleManager.categories.first { 
                $0.name?.lowercased() == categoryName.lowercased() 
            }
        }
        return nil
    }
}