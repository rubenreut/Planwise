//
//  AICoordinator.swift
//  Momentum
//
//  Simplified AI Coordinator that handles all 5 manage functions
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
    
    init(context: NSManagedObjectContext,
         scheduleManager: ScheduleManaging,
         taskManager: TaskManager,
         goalManager: GoalManager,
         habitManager: HabitManaging? = nil) {
        self.context = context
        self.scheduleManager = scheduleManager
        self.taskManager = taskManager
        self.goalManager = goalManager
        // Use the shared HabitManager if not provided
        self.habitManager = habitManager ?? HabitManager.shared
    }
    
    // MARK: - Helper Functions
    
    private func parseDate(_ value: Any?) -> Date? {
        guard let dateStr = value as? String else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) {
            return date
        }
        
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateStr) {
            return date
        }
        
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return fallbackFormatter.date(from: dateStr)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
    
    private func findOrCreateCategory(name: String, color: String? = nil, icon: String? = nil) -> Category {
        // First try to find existing category
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        
        if let existingCategory = try? context.fetch(request).first {
            // Update color and icon if provided
            if let color = color {
                existingCategory.colorHex = color
            }
            if let icon = icon {
                existingCategory.iconName = icon
            }
            return existingCategory
        }
        
        // Create new category
        let category = Category(context: context)
        category.id = UUID()
        category.name = name
        category.colorHex = color ?? "#007AFF"
        category.iconName = icon ?? "folder"
        category.isActive = true
        
        try? context.save()
        return category
    }
    
    private func findCategory(from parameters: [String: Any]) -> Category? {
        if let categoryId = parameters["categoryId"] as? String,
           let uuid = UUID(uuidString: categoryId) {
            return scheduleManager.categories.first { $0.id == uuid }
        }
        
        if let categoryName = parameters["category"] as? String {
            return scheduleManager.categories.first { $0.name?.lowercased() == categoryName.lowercased() }
        }
        
        return nil
    }
    
    // MARK: - Main Entry Points (5 Simple Functions)
    
    func manage_events(action: String, parameters: [String: Any]) async -> [String: Any] {
        print("🎯 AICoordinator.manage_events - Action: \(action)")
        print("📦 Parameters: \(parameters)")
        
        switch action.lowercased() {
        case "create":
            if let items = parameters["items"] as? [[String: Any]] {
                // Bulk create
                var created = 0
                var createdEvents: [String] = []
                for item in items {
                    let title = item["title"] as? String ?? "New Event"
                    let startTime = parseDate(item["startTime"]) ?? Date()
                    let endTime = parseDate(item["endTime"]) ?? Date().addingTimeInterval(3600)
                    let notes = item["notes"] as? String
                    let location = item["location"] as? String
                    let isAllDay = item["isAllDay"] as? Bool ?? false
                    
                    let category = findCategory(from: item)
                    
                    let result = scheduleManager.createEvent(
                        title: title,
                        startTime: startTime,
                        endTime: endTime,
                        category: category,
                        notes: notes,
                        location: location,
                        isAllDay: isAllDay
                    )
                    
                    if case .success(let event) = result {
                        createdEvents.append(event.title ?? "Event")
                        created += 1
                    }
                }
                return ["success": true, "message": "Created \(created) events: \(createdEvents.joined(separator: ", "))"]
            } else {
                // Single create
                let title = parameters["title"] as? String ?? "New Event"
                let startTime = parseDate(parameters["startTime"]) ?? Date()
                let endTime = parseDate(parameters["endTime"]) ?? Date().addingTimeInterval(3600)
                let notes = parameters["notes"] as? String
                let location = parameters["location"] as? String
                let isAllDay = parameters["isAllDay"] as? Bool ?? false
                
                let category = findCategory(from: parameters)
                
                let result = scheduleManager.createEvent(
                    title: title,
                    startTime: startTime,
                    endTime: endTime,
                    category: category,
                    notes: notes,
                    location: location,
                    isAllDay: isAllDay
                )
                
                if case .success(let event) = result {
                    return ["success": true, "message": "Created event: \(event.title ?? "Event")", "id": event.id?.uuidString ?? ""]
                }
                return ["success": false, "message": "Failed to create event"]
            }
            
        case "update":
            // Check if this is a bulk update with items array (for different values per event)
            if let items = parameters["items"] as? [[String: Any]] {
                print("📦 Bulk update with items array - updating \(items.count) events")
                print("   Items received: \(items)")
                
                var updatedCount = 0
                var failedUpdates: [String] = []
                
                for item in items {
                    // Handle both "id" and "eventId" keys
                    let eventIdString = item["id"] as? String ?? item["eventId"] as? String
                    
                    if let eventIdString = eventIdString, let eventId = UUID(uuidString: eventIdString) {
                        if let event = scheduleManager.events.first(where: { $0.id == eventId }) {
                            // Update ALL event properties that can be changed
                            if let title = item["title"] as? String {
                                event.title = title
                            }
                            if let startTime = parseDate(item["startTime"]) {
                                event.startTime = startTime
                            }
                            if let endTime = parseDate(item["endTime"]) {
                                event.endTime = endTime
                            }
                            if let notes = item["notes"] as? String {
                                event.notes = notes
                            }
                            if let location = item["location"] as? String {
                                event.location = location
                            }
                            if let isCompleted = item["isCompleted"] as? Bool {
                                event.isCompleted = isCompleted
                            }
                            if item["isAllDay"] != nil {
                                // event.isAllDay = item["isAllDay"] as? Bool // If this property exists
                            }
                            if let categoryName = item["category"] as? String {
                                event.category = findOrCreateCategory(name: categoryName)
                            }
                            if let colorHex = item["colorHex"] as? String ?? item["color"] as? String {
                                event.colorHex = colorHex
                            }
                            if let iconName = item["iconName"] as? String ?? item["icon"] as? String {
                                event.iconName = iconName
                            }
                            if let priority = item["priority"] as? String {
                                event.priority = priority
                            }
                            if let tags = item["tags"] as? String {
                                event.tags = tags
                            }
                            if let url = item["url"] as? String {
                                event.url = url
                            }
                            if let energyLevel = item["energyLevel"] as? String {
                                event.energyLevel = energyLevel
                            }
                            if let weatherRequired = item["weatherRequired"] as? String {
                                event.weatherRequired = weatherRequired
                            }
                            if let bufferTimeBefore = item["bufferTimeBefore"] as? Int32 {
                                event.bufferTimeBefore = bufferTimeBefore
                            }
                            if let bufferTimeAfter = item["bufferTimeAfter"] as? Int32 {
                                event.bufferTimeAfter = bufferTimeAfter
                            }
                            if let recurrenceRule = item["recurrenceRule"] as? String {
                                event.recurrenceRule = recurrenceRule
                            }
                            if let recurrenceEndDate = parseDate(item["recurrenceEndDate"]) {
                                event.recurrenceEndDate = recurrenceEndDate
                            }
                            
                            updatedCount += 1
                            print("✅ Updated event: \(event.title ?? "Unknown")")
                        } else {
                            failedUpdates.append("Event not found: \(eventIdString)")
                            print("❌ Event not found with ID: \(eventIdString)")
                        }
                    } else {
                        // If the item structure is wrong, log it
                        print("❌ Invalid item structure: \(item)")
                        failedUpdates.append("Invalid item: missing or invalid ID")
                    }
                }
                
                do {
                    try context.save()
                    let message = failedUpdates.isEmpty 
                        ? "Updated \(updatedCount) events" 
                        : "Updated \(updatedCount) events. Failed: \(failedUpdates.joined(separator: ", "))"
                    return ["success": updatedCount > 0, "message": message]
                } catch {
                    return ["success": false, "message": "Failed to save updates: \(error.localizedDescription)"]
                }
            }
            
            // Check if this is a simple bulk update for all events
            if let updateAll = parameters["updateAll"] as? Bool, updateAll == true {
                print("📦 Bulk update requested for all events")
                
                let events = scheduleManager.events
                var updatedCount = 0
                
                for event in events {
                    // Update fields that were provided
                    if let colorHex = parameters["colorHex"] as? String ?? parameters["color"] as? String {
                        event.colorHex = colorHex
                    }
                    if let iconName = parameters["iconName"] as? String ?? parameters["icon"] as? String {
                        event.iconName = iconName
                    }
                    if let categoryName = parameters["category"] as? String {
                        event.category = findOrCreateCategory(name: categoryName)
                    } else if let categoryData = parameters["category"] as? [String: Any],
                       let categoryName = categoryData["name"] as? String {
                        event.category = findOrCreateCategory(name: categoryName, color: categoryData["color"] as? String, icon: categoryData["icon"] as? String)
                    }
                    
                    updatedCount += 1
                }
                
                // Save all changes
                do {
                    try context.save()
                    return ["success": true, "message": "Updated \(updatedCount) events"]
                } catch {
                    return ["success": false, "message": "Failed to update events: \(error.localizedDescription)"]
                }
            }
            
            // Handle bulk update by date/filter
            if let updateFilter = parameters["filter"] as? [String: Any] {
                print("📝 Bulk update by filter")
                
                // Get events based on filter
                let dateStr = updateFilter["date"] as? String
                let eventsToUpdate: [Event]
                
                if let dateStr = dateStr, let date = parseDate(dateStr) {
                    eventsToUpdate = scheduleManager.events(for: date)
                } else if updateFilter["all_tomorrow"] as? Bool == true {
                    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
                    eventsToUpdate = scheduleManager.events(for: tomorrow)
                } else if updateFilter["all_today"] as? Bool == true {
                    eventsToUpdate = scheduleManager.eventsForToday()
                } else {
                    eventsToUpdate = scheduleManager.events
                }
                
                print("   Found \(eventsToUpdate.count) events to update")
                
                // Apply updates to all matching events
                var updated = 0
                let timeShift = parameters["timeShift"] as? TimeInterval
                
                for event in eventsToUpdate {
                    var newStartTime = event.startTime
                    var newEndTime = event.endTime
                    
                    // Handle time shift (e.g., "move back one hour" = -3600 seconds)
                    if let shift = timeShift {
                        newStartTime = event.startTime?.addingTimeInterval(shift)
                        newEndTime = event.endTime?.addingTimeInterval(shift)
                    }
                    
                    // Allow overriding with specific times if provided
                    if let startTimeStr = parameters["startTime"] as? String,
                       let startTime = parseDate(startTimeStr) {
                        newStartTime = startTime
                    }
                    if let endTimeStr = parameters["endTime"] as? String,
                       let endTime = parseDate(endTimeStr) {
                        newEndTime = endTime
                    }
                    
                    let result = scheduleManager.updateEvent(
                        event,
                        title: parameters["title"] as? String,
                        startTime: newStartTime,
                        endTime: newEndTime,
                        category: findCategory(from: parameters),
                        notes: parameters["notes"] as? String,
                        location: parameters["location"] as? String,
                        isCompleted: parameters["isCompleted"] as? Bool,
                        colorHex: parameters["colorHex"] as? String ?? parameters["color"] as? String,
                        iconName: parameters["iconName"] as? String ?? parameters["icon"] as? String,
                        priority: nil,
                        tags: nil,
                        url: nil,
                        energyLevel: nil,
                        weatherRequired: nil,
                        bufferTimeBefore: nil,
                        bufferTimeAfter: nil,
                        recurrenceRule: nil,
                        recurrenceEndDate: nil,
                        linkedTasks: nil
                    )
                    
                    if case .success = result {
                        updated += 1
                    }
                }
                
                return ["success": updated > 0, "message": "Updated \(updated) events"]
            }
            
            // Handle bulk update with explicit IDs
            if let ids = parameters["ids"] as? [String] {
                var updated = 0
                let events = scheduleManager.events
                
                for id in ids {
                    if let eventId = UUID(uuidString: id),
                       let event = events.first(where: { $0.id == eventId }) {
                        
                        let result = scheduleManager.updateEvent(
                            event,
                            title: parameters["title"] as? String,
                            startTime: parseDate(parameters["startTime"]),
                            endTime: parseDate(parameters["endTime"]),
                            category: findCategory(from: parameters),
                            notes: parameters["notes"] as? String,
                            location: parameters["location"] as? String,
                            isCompleted: parameters["isCompleted"] as? Bool,
                            colorHex: parameters["colorHex"] as? String ?? parameters["color"] as? String,
                            iconName: parameters["iconName"] as? String ?? parameters["icon"] as? String,
                            priority: nil,
                            tags: nil,
                            url: nil,
                            energyLevel: nil,
                            weatherRequired: nil,
                            bufferTimeBefore: nil,
                            bufferTimeAfter: nil,
                            recurrenceRule: nil,
                            recurrenceEndDate: nil,
                            linkedTasks: nil
                        )
                        
                        if case .success = result {
                            updated += 1
                        }
                    }
                }
                
                return ["success": updated > 0, "message": "Updated \(updated) events"]
            }
            
            // Single update (original code)
            guard let id = parameters["id"] as? String,
                  let eventId = UUID(uuidString: id) else {
                return ["success": false, "message": "Valid event ID required for update. For bulk updates, use 'filter' parameter with date or 'ids' array."]
            }
            
            // Find the event
            let events = scheduleManager.events
            guard let event = events.first(where: { $0.id == eventId }) else {
                return ["success": false, "message": "Event not found"]
            }
            
            let result = scheduleManager.updateEvent(
                event,
                title: parameters["title"] as? String,
                startTime: parseDate(parameters["startTime"]),
                endTime: parseDate(parameters["endTime"]),
                category: findCategory(from: parameters),
                notes: parameters["notes"] as? String,
                location: parameters["location"] as? String,
                isCompleted: parameters["isCompleted"] as? Bool,
                colorHex: parameters["colorHex"] as? String ?? parameters["color"] as? String,
                iconName: parameters["iconName"] as? String ?? parameters["icon"] as? String,
                priority: nil,
                tags: nil,
                url: nil,
                energyLevel: nil,
                weatherRequired: nil,
                bufferTimeBefore: nil,
                bufferTimeAfter: nil,
                recurrenceRule: nil,
                recurrenceEndDate: nil,
                linkedTasks: nil
            )
            
            if case .success = result {
                return ["success": true, "message": "Updated event"]
            }
            return ["success": false, "message": "Failed to update event"]
            
        case "delete":
            // Check if deleteAll flag is set OR if there's an empty filter (which means delete all)
            if (parameters["deleteAll"] as? Bool) == true || 
               (parameters["filter"] as? [String: Any])?.isEmpty == true ||
               (parameters["confirm"] as? Bool) == true && parameters["filter"] != nil {
                print("🗑️ Delete all events requested")
                var deleted = 0
                let allEvents = scheduleManager.events
                print("🗑️ Found \(allEvents.count) events to delete")
                
                for event in allEvents {
                    let result = scheduleManager.deleteEvent(event)
                    if case .success = result {
                        deleted += 1
                    }
                }
                return ["success": true, "message": "Deleted \(deleted) events"]
            } else if let ids = parameters["ids"] as? [String] {
                var deleted = 0
                let events = scheduleManager.events
                for id in ids {
                    if let eventId = UUID(uuidString: id),
                       let event = events.first(where: { $0.id == eventId }) {
                        let result = scheduleManager.deleteEvent(event)
                        if case .success = result {
                            deleted += 1
                        }
                    }
                }
                return ["success": true, "message": "Deleted \(deleted) events"]
            } else if let id = parameters["id"] as? String,
                      let eventId = UUID(uuidString: id) {
                let events = scheduleManager.events
                if let event = events.first(where: { $0.id == eventId }) {
                    let result = scheduleManager.deleteEvent(event)
                    if case .success = result {
                        return ["success": true, "message": "Deleted event"]
                    }
                }
            }
            return ["success": false, "message": "Failed to delete event - no valid parameters provided"]
            
        case "list":
            let dateStr = parameters["date"] as? String
            let events: [Event]
            if let dateStr = dateStr, let date = parseDate(dateStr) {
                events = scheduleManager.events(for: date)
            } else {
                events = scheduleManager.eventsForToday()
            }
            
            let eventData = events.compactMap { event -> [String: Any]? in
                guard let eventId = event.id else { 
                    print("⚠️ Skipping event with nil ID: \(event.title ?? "Unknown")")
                    return nil 
                }
                return [
                    "id": eventId.uuidString,
                    "title": event.title ?? "",
                    "startTime": formatDate(event.startTime),
                    "endTime": formatDate(event.endTime),
                    "location": event.location ?? "",
                    "notes": event.notes ?? "",
                    // "isAllDay": event.isAllDay, // Commented out - property might not exist
                    "isCompleted": event.isCompleted,
                    "colorHex": event.colorHex ?? "#007AFF",
                    "iconName": event.iconName ?? "calendar",
                    "category": event.category?.name ?? "",
                    "priority": event.priority as Any,
                    "energyLevel": event.energyLevel as Any,
                    "weatherRequired": event.weatherRequired ?? "",
                    "url": event.url ?? "",
                    "tags": event.tags?.components(separatedBy: ",") ?? []
                ] as [String: Any]
            }
            return ["success": true, "items": eventData, "message": "Found \(eventData.count) events with valid IDs"]
            
        default:
            return ["success": false, "message": "Unknown action: \(action)"]
        }
    }
    
    func manage_tasks(action: String, parameters: [String: Any]) async -> [String: Any] {
        print("🎯 AICoordinator.manage_tasks - Action: \(action)")
        print("📦 Parameters: \(parameters)")
        
        switch action.lowercased() {
        case "create":
            if let items = parameters["items"] as? [[String: Any]] {
                // Bulk create
                var created = 0
                var createdTasks: [String] = []
                for item in items {
                    let title = item["title"] as? String ?? "New Task"
                    let notes = item["description"] as? String ?? item["notes"] as? String
                    let dueDate = parseDate(item["dueDate"])
                    let priority = TaskPriority(rawValue: Int16(item["priority"] as? Int ?? 2)) ?? .medium
                    let category = findCategory(from: item)
                    let tags = item["tags"] as? [String]
                    let estimatedDuration = Int16(item["estimatedMinutes"] as? Int ?? 30)
                    
                    let result = taskManager.createTask(
                        title: title,
                        notes: notes,
                        dueDate: dueDate,
                        priority: priority,
                        category: category,
                        tags: tags,
                        estimatedDuration: estimatedDuration,
                        scheduledTime: nil,
                        linkedEvent: nil
                    )
                    
                    if case .success(let task) = result {
                        createdTasks.append(task.title ?? "Task")
                        created += 1
                    }
                }
                return ["success": true, "message": "Created \(created) tasks: \(createdTasks.joined(separator: ", "))"]
            } else {
                // Single create
                let title = parameters["title"] as? String ?? "New Task"
                let notes = parameters["description"] as? String ?? parameters["notes"] as? String
                let dueDate = parseDate(parameters["dueDate"])
                let priority = TaskPriority(rawValue: Int16(parameters["priority"] as? Int ?? 2)) ?? .medium
                let category = findCategory(from: parameters)
                let tags = parameters["tags"] as? [String]
                let estimatedDuration = Int16(parameters["estimatedMinutes"] as? Int ?? 30)
                
                let result = taskManager.createTask(
                    title: title,
                    notes: notes,
                    dueDate: dueDate,
                    priority: priority,
                    category: category,
                    tags: tags,
                    estimatedDuration: estimatedDuration,
                    scheduledTime: nil,
                    linkedEvent: nil
                )
                
                if case .success(let task) = result {
                    return ["success": true, "message": "Created task: \(task.title ?? "Task")", "id": task.id?.uuidString ?? ""]
                }
                return ["success": false, "message": "Failed to create task"]
            }
            
        case "update":
            // Check if this is a bulk update with items array
            if let items = parameters["items"] as? [[String: Any]] {
                print("📦 Bulk update with items array - updating \(items.count) tasks")
                
                var updatedCount = 0
                var failedUpdates: [String] = []
                
                for item in items {
                    if let id = item["id"] as? String, let taskId = UUID(uuidString: id) {
                        if let task = taskManager.tasks.first(where: { $0.id == taskId }) {
                            // Update ALL task properties
                            if let title = item["title"] as? String {
                                task.title = title
                            }
                            if let description = item["description"] as? String ?? item["notes"] as? String {
                                task.notes = description
                            }
                            if let dueDate = parseDate(item["dueDate"]) {
                                task.dueDate = dueDate
                            }
                            if let priority = item["priority"] as? Int {
                                task.priority = Int16(priority)
                            }
                            if let estimatedDuration = item["estimatedDuration"] as? Int ?? item["estimatedMinutes"] as? Int {
                                task.estimatedDuration = Int16(estimatedDuration)
                            }
                            if let scheduledTime = parseDate(item["scheduledTime"]) {
                                task.scheduledTime = scheduledTime
                            }
                            if let isCompleted = item["isCompleted"] as? Bool {
                                task.isCompleted = isCompleted
                                // completedDate property doesn't exist on Task
                                // Mark completion through the isCompleted flag only
                            }
                            if let categoryName = item["category"] as? String {
                                task.category = findOrCreateCategory(name: categoryName)
                            }
                            if let tags = item["tags"] as? [String] {
                                // Convert array to comma-separated string for storage
                                task.tags = tags.joined(separator: ",")
                            }
                            // Link to event if provided
                            if let eventId = item["linkedEventId"] as? String,
                               let eventUUID = UUID(uuidString: eventId) {
                                task.linkedEvent = scheduleManager.events.first { $0.id == eventUUID }
                            }
                            // Parent task for subtasks
                            if let parentTaskId = item["parentTaskId"] as? String,
                               let parentUUID = UUID(uuidString: parentTaskId) {
                                task.parentTask = taskManager.tasks.first { $0.id == parentUUID }
                            }
                            updatedCount += 1
                        } else {
                            failedUpdates.append("Task not found: \(id)")
                        }
                    } else {
                        failedUpdates.append("Invalid or missing ID in item")
                    }
                }
                
                do {
                    try context.save()
                    let message = failedUpdates.isEmpty 
                        ? "Updated \(updatedCount) tasks" 
                        : "Updated \(updatedCount) tasks. Failed: \(failedUpdates.joined(separator: ", "))"
                    return ["success": true, "message": message]
                } catch {
                    return ["success": false, "message": "Failed to save updates: \(error.localizedDescription)"]
                }
            }
            
            // Check if this is a bulk update for all tasks
            if let updateAll = parameters["updateAll"] as? Bool, updateAll == true {
                print("📦 Bulk update requested for all tasks")
                
                let tasks = taskManager.tasks
                var updatedCount = 0
                
                for task in tasks {
                    // Add support for bulk description updates
                    if let description = parameters["description"] as? String {
                        // Generate smart description based on task title if requested
                        if description == "auto" || description == "generate" {
                            task.notes = "Task: \(task.title ?? ""). Priority: \(task.priority == 3 ? "High" : task.priority == 2 ? "Medium" : "Low"). Category: \(task.category?.name ?? "General")."
                        } else {
                            task.notes = description
                        }
                    }
                    
                    // Tasks don't have colorHex or iconName - only update category
                    if let categoryData = parameters["category"] as? [String: Any],
                       let categoryName = categoryData["name"] as? String {
                        task.category = findOrCreateCategory(name: categoryName, color: categoryData["color"] as? String, icon: categoryData["icon"] as? String)
                    } else if let categoryName = parameters["category"] as? String {
                        // Handle simple category name string
                        task.category = findOrCreateCategory(name: categoryName)
                    }
                    
                    // Update other task-specific fields if provided
                    if let priority = parameters["priority"] as? Int {
                        task.priority = Int16(priority)
                    }
                    if let isCompleted = parameters["isCompleted"] as? Bool {
                        task.isCompleted = isCompleted
                    }
                    
                    updatedCount += 1
                }
                
                // Save all changes
                do {
                    try context.save()
                    return ["success": true, "message": "Updated \(updatedCount) tasks"]
                } catch {
                    return ["success": false, "message": "Failed to update tasks: \(error.localizedDescription)"]
                }
            }
            
            guard let id = parameters["id"] as? String,
                  let taskId = UUID(uuidString: id) else {
                return ["success": false, "message": "Valid task ID required for update"]
            }
            
            // Find the task
            let tasks = taskManager.tasks
            guard let task = tasks.first(where: { $0.id == taskId }) else {
                return ["success": false, "message": "Task not found"]
            }
            
            let result = taskManager.updateTask(
                task,
                title: parameters["title"] as? String,
                notes: parameters["description"] as? String ?? parameters["notes"] as? String,
                dueDate: parseDate(parameters["dueDate"]),
                priority: parameters["priority"] != nil ? TaskPriority(rawValue: Int16(parameters["priority"] as? Int ?? 2)) : nil,
                category: findCategory(from: parameters),
                tags: parameters["tags"] as? [String],
                estimatedDuration: parameters["estimatedMinutes"] != nil ? Int16(parameters["estimatedMinutes"] as? Int ?? 30) : nil,
                scheduledTime: nil,
                linkedEvent: nil,
                parentTask: nil
            )
            
            if case .success = result {
                return ["success": true, "message": "Updated task"]
            }
            return ["success": false, "message": "Failed to update task"]
            
        case "complete":
            guard let id = parameters["id"] as? String,
                  let taskId = UUID(uuidString: id) else {
                return ["success": false, "message": "Valid task ID required"]
            }
            
            let tasks = taskManager.tasks
            guard let task = tasks.first(where: { $0.id == taskId }) else {
                return ["success": false, "message": "Task not found"]
            }
            
            let result = taskManager.completeTask(task)
            if case .success = result {
                return ["success": true, "message": "Completed task"]
            }
            return ["success": false, "message": "Failed to complete task"]
            
        case "delete":
            // Check if deleteAll flag is set OR if there's an empty filter (which means delete all)
            if (parameters["deleteAll"] as? Bool) == true || 
               (parameters["filter"] as? [String: Any])?.isEmpty == true ||
               (parameters["confirm"] as? Bool) == true && parameters["filter"] != nil {
                print("🗑️ Delete all tasks requested")
                var deleted = 0
                let allTasks = taskManager.tasks
                print("🗑️ Found \(allTasks.count) tasks to delete")
                
                for task in allTasks {
                    let result = taskManager.deleteTask(task)
                    if case .success = result {
                        deleted += 1
                    }
                }
                return ["success": true, "message": "Deleted \(deleted) tasks"]
            } else if let ids = parameters["ids"] as? [String] {
                var deleted = 0
                let tasks = taskManager.tasks
                for id in ids {
                    if let taskId = UUID(uuidString: id),
                       let task = tasks.first(where: { $0.id == taskId }) {
                        let result = taskManager.deleteTask(task)
                        if case .success = result {
                            deleted += 1
                        }
                    }
                }
                return ["success": true, "message": "Deleted \(deleted) tasks"]
            } else if let id = parameters["id"] as? String,
                      let taskId = UUID(uuidString: id) {
                let tasks = taskManager.tasks
                if let task = tasks.first(where: { $0.id == taskId }) {
                    let result = taskManager.deleteTask(task)
                    if case .success = result {
                        return ["success": true, "message": "Deleted task"]
                    }
                }
            }
            return ["success": false, "message": "Failed to delete task - no valid parameters provided"]
            
        case "list":
            let tasks = taskManager.tasks
            let taskData = tasks.compactMap { task -> [String: Any]? in
                guard let taskId = task.id else { 
                    print("⚠️ Skipping task with nil ID: \(task.title ?? "Unknown")")
                    return nil 
                }
                return [
                    "id": taskId.uuidString,
                    "title": task.title ?? "",
                    "description": task.notes ?? "",
                    "dueDate": task.dueDate != nil ? formatDate(task.dueDate!) : "",
                    "priority": task.priority,
                    "isCompleted": task.isCompleted,
                    "category": task.category?.name ?? "",
                    "tags": task.tags?.components(separatedBy: ",") ?? [],
                    "estimatedDuration": task.estimatedDuration,
                    // "actualDuration": task.actualDuration, // Property doesn't exist
                    // "completedDate": formatDate(task.completedDate), // Property doesn't exist
                    "scheduledTime": formatDate(task.scheduledTime),
                    "createdAt": formatDate(task.createdAt),
                    // "updatedAt": formatDate(task.updatedAt), // Property doesn't exist
                    // "isRecurring": task.isRecurring, // Property doesn't exist
                    // "recurrenceRule": task.recurrenceRule ?? "", // Property doesn't exist
                    "parentTaskId": task.parentTask?.id?.uuidString ?? "",
                    "linkedEventId": task.linkedEvent?.id?.uuidString ?? ""
                ] as [String: Any]
            }
            return ["success": true, "items": taskData, "message": "Found \(taskData.count) tasks with valid IDs"]
            
        default:
            return ["success": false, "message": "Unknown action: \(action)"]
        }
    }
    
    func manage_habits(action: String, parameters: [String: Any]) async -> [String: Any] {
        print("🎯 AICoordinator.manage_habits - Action: \(action)")
        print("📦 Parameters: \(parameters)")
        
        // Add error handling for invalid action
        if action == "unknown" || action.isEmpty {
            print("❌ ERROR: Invalid or missing action: '\(action)'")
            return ["success": false, "message": "Invalid action. Please specify 'create', 'update', 'delete', 'list', 'log', or 'complete'"]
        }
        
        switch action.lowercased() {
        case "create":
            if let items = parameters["items"] as? [[String: Any]] {
                // Bulk create habits
                print("📝 Creating \(items.count) habits")
                var created = 0
                var createdHabits: [String] = []
                
                for item in items {
                    let name = item["name"] as? String ?? item["title"] as? String ?? "Habit \(created + 1)"
                    print("  Creating habit: \(name)")
                    
                    let habit = Habit(context: context)
                    habit.id = UUID()
                    habit.name = name
                    habit.notes = item["description"] as? String
                    habit.frequency = item["frequency"] as? String ?? "daily"
                    habit.isActive = item["isActive"] as? Bool ?? true
                    habit.createdAt = Date()
                    habit.currentStreak = 0
                    
                    // Parse reminder time if provided
                    if let reminderTimeStr = item["reminderTime"] as? String {
                        // Convert HH:MM to Date
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        habit.reminderTime = formatter.date(from: reminderTimeStr)
                    }
                    
                    // Set category if provided
                    if let categoryName = item["category"] as? String {
                        let categories = scheduleManager.categories
                        habit.category = categories.first { $0.name?.lowercased() == categoryName.lowercased() }
                    }
                    
                    createdHabits.append(name)
                    created += 1
                }
                
                do {
                    try context.save()
                    print("✅ Successfully created \(created) habits")
                    print("   Created habits: \(createdHabits)")
                    return ["success": true, "message": "Created \(created) habits: \(createdHabits.joined(separator: ", "))"]
                } catch {
                    print("❌ Failed to save habits: \(error)")
                    print("   Error details: \(error.localizedDescription)")
                    print("   Full error: \(error)")
                    return ["success": false, "message": "Failed to save habits: \(error.localizedDescription)"]
                }
            } else {
                // Single create
                let name = parameters["name"] as? String ?? parameters["title"] as? String ?? "New Habit"
                print("📝 Creating single habit: \(name)")
                
                let habit = Habit(context: context)
                habit.id = UUID()
                habit.name = name
                habit.notes = parameters["description"] as? String
                habit.frequency = parameters["frequency"] as? String ?? "daily"
                habit.isActive = parameters["isActive"] as? Bool ?? true
                habit.createdAt = Date()
                habit.currentStreak = 0
                
                // Parse reminder time if provided
                if let reminderTimeStr = parameters["reminderTime"] as? String {
                    // Convert HH:MM to Date
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    habit.reminderTime = formatter.date(from: reminderTimeStr)
                }
                
                // Set category if provided
                if let categoryName = parameters["category"] as? String {
                    let categories = scheduleManager.categories
                    habit.category = categories.first { $0.name?.lowercased() == categoryName.lowercased() }
                }
                
                do {
                    try context.save()
                    return ["success": true, "message": "Created habit: \(name)", "id": habit.id?.uuidString ?? ""]
                } catch {
                    return ["success": false, "message": "Failed to create habit: \(error.localizedDescription)"]
                }
            }
            
        case "update":
            // Check if this is a bulk update with items array FIRST
            if let items = parameters["items"] as? [[String: Any]] {
                print("📦 Bulk update with items array - updating \(items.count) habits")
                
                var updatedCount = 0
                var failedUpdates: [String] = []
                
                for item in items {
                    if let id = item["id"] as? String, let habitId = UUID(uuidString: id) {
                        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
                        request.predicate = NSPredicate(format: "id == %@", habitId as CVarArg)
                        
                        if let habit = try? context.fetch(request).first {
                            // Update ALL habit properties
                            if let name = item["name"] as? String {
                                habit.name = name
                            }
                            if let desc = item["description"] as? String ?? item["notes"] as? String {
                                habit.notes = desc
                            }
                            if let frequency = item["frequency"] as? String {
                                habit.frequency = frequency
                            }
                            if let isActive = item["isActive"] as? Bool {
                                habit.isActive = isActive
                            }
                            if let isPaused = item["isPaused"] as? Bool {
                                habit.isPaused = isPaused
                            }
                            if let colorHex = item["colorHex"] as? String ?? item["color"] as? String {
                                habit.colorHex = colorHex
                            }
                            if let iconName = item["iconName"] as? String ?? item["icon"] as? String {
                                habit.iconName = iconName
                            }
                            if let trackingType = item["trackingType"] as? String {
                                habit.trackingType = trackingType
                            }
                            if let goalTarget = item["goalTarget"] as? Double {
                                habit.goalTarget = goalTarget
                            }
                            if let reminderTime = item["reminderTime"] as? String {
                                // Parse time string (HH:mm format)
                                let formatter = DateFormatter()
                                formatter.dateFormat = "HH:mm"
                                habit.reminderTime = formatter.date(from: reminderTime)
                            }
                            if let bestStreak = item["bestStreak"] as? Int32 {
                                habit.bestStreak = bestStreak
                            }
                            if let currentStreak = item["currentStreak"] as? Int32 {
                                habit.currentStreak = currentStreak
                            }
                            if let categoryName = item["category"] as? String {
                                habit.category = findOrCreateCategory(name: categoryName)
                            }
                            updatedCount += 1
                        } else {
                            failedUpdates.append("Habit not found: \(id)")
                        }
                    } else {
                        failedUpdates.append("Invalid or missing ID in item")
                    }
                }
                
                do {
                    try context.save()
                    let message = failedUpdates.isEmpty 
                        ? "Updated \(updatedCount) habits" 
                        : "Updated \(updatedCount) habits. Failed: \(failedUpdates.joined(separator: ", "))"
                    return ["success": true, "message": message]
                } catch {
                    return ["success": false, "message": "Failed to save updates: \(error.localizedDescription)"]
                }
            }
            
            // Check if this is a bulk update for all habits
            if let updateAll = parameters["updateAll"] as? Bool, updateAll == true {
                print("📦 Bulk update requested for all habits")
                
                let request: NSFetchRequest<Habit> = Habit.fetchRequest()
                
                do {
                    let habits = try context.fetch(request)
                    var updatedCount = 0
                    
                    for habit in habits {
                        // Update fields that were provided
                        if let colorHex = parameters["colorHex"] as? String ?? parameters["color"] as? String {
                            habit.colorHex = colorHex
                        }
                        if let iconName = parameters["iconName"] as? String ?? parameters["icon"] as? String {
                            habit.iconName = iconName
                        }
                        if let categoryData = parameters["category"] as? [String: Any],
                           let categoryName = categoryData["name"] as? String {
                            habit.category = findOrCreateCategory(name: categoryName, color: categoryData["color"] as? String, icon: categoryData["icon"] as? String)
                        }
                        
                        updatedCount += 1
                    }
                    
                    try context.save()
                    return ["success": true, "message": "Updated \(updatedCount) habits"]
                } catch {
                    return ["success": false, "message": "Failed to update habits: \(error.localizedDescription)"]
                }
            }
            
            // Single habit update - now check for single ID
            guard let id = parameters["id"] as? String,
                  let habitId = UUID(uuidString: id) else {
                return ["success": false, "message": "Valid habit ID required"]
            }
            
            let request: NSFetchRequest<Habit> = Habit.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", habitId as CVarArg)
            
            // Single habit update
            do {
                if let habit = try context.fetch(request).first {
                    if let name = parameters["name"] as? String {
                        habit.name = name
                    }
                    if let desc = parameters["description"] as? String {
                        habit.notes = desc
                    }
                    if let frequency = parameters["frequency"] as? String {
                        habit.frequency = frequency
                    }
                    if let isActive = parameters["isActive"] as? Bool {
                        habit.isActive = isActive
                    }
                    if let isPaused = parameters["isPaused"] as? Bool {
                        habit.isPaused = isPaused
                    }
                    if let colorHex = parameters["colorHex"] as? String ?? parameters["color"] as? String {
                        habit.colorHex = colorHex
                    }
                    if let iconName = parameters["iconName"] as? String ?? parameters["icon"] as? String {
                        habit.iconName = iconName
                    }
                    if let trackingType = parameters["trackingType"] as? String {
                        habit.trackingType = trackingType
                    }
                    if let goalTarget = parameters["goalTarget"] as? Double {
                        habit.goalTarget = goalTarget
                    }
                    if let reminderTime = parseDate(parameters["reminderTime"]) {
                        habit.reminderTime = reminderTime
                    }
                    if let bestStreak = parameters["bestStreak"] as? Int32 {
                        habit.bestStreak = bestStreak
                    }
                    if let currentStreak = parameters["currentStreak"] as? Int32 {
                        habit.currentStreak = currentStreak
                    }
                    if let categoryData = parameters["category"] as? [String: Any],
                       let categoryName = categoryData["name"] as? String {
                        habit.category = findOrCreateCategory(name: categoryName, color: categoryData["color"] as? String, icon: categoryData["icon"] as? String)
                    } else if let categoryName = parameters["category"] as? String {
                        habit.category = findOrCreateCategory(name: categoryName)
                    }
                    
                    try context.save()
                    return ["success": true, "message": "Updated habit: \(habit.name ?? "")"]
                }
                return ["success": false, "message": "Habit not found"]
            } catch {
                return ["success": false, "message": "Failed to update habit"]
            }
            
        case "delete":
            if let ids = parameters["ids"] as? [String] {
                var deleted = 0
                for id in ids {
                    if let habitId = UUID(uuidString: id) {
                        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
                        request.predicate = NSPredicate(format: "id == %@", habitId as CVarArg)
                        
                        if let habit = try? context.fetch(request).first {
                            context.delete(habit)
                            deleted += 1
                        }
                    }
                }
                
                do {
                    try context.save()
                    return ["success": true, "message": "Deleted \(deleted) habits"]
                } catch {
                    return ["success": false, "message": "Failed to delete habits"]
                }
            } else if let id = parameters["id"] as? String,
                      let habitId = UUID(uuidString: id) {
                let request: NSFetchRequest<Habit> = Habit.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", habitId as CVarArg)
                
                do {
                    if let habit = try context.fetch(request).first {
                        context.delete(habit)
                        try context.save()
                        return ["success": true, "message": "Deleted habit"]
                    }
                    return ["success": false, "message": "Habit not found"]
                } catch {
                    return ["success": false, "message": "Failed to delete habit"]
                }
            }
            return ["success": false, "message": "Habit ID required"]
            
        case "log", "complete":
            guard let id = parameters["id"] as? String,
                  let habitId = UUID(uuidString: id) else {
                return ["success": false, "message": "Valid habit ID required"]
            }
            
            let request: NSFetchRequest<Habit> = Habit.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", habitId as CVarArg)
            
            do {
                if let habit = try context.fetch(request).first {
                    // Update streak
                    habit.currentStreak += 1
                    habit.lastCompletedDate = Date()
                    
                    try context.save()
                    return ["success": true, "message": "Logged completion for: \(habit.name ?? "")"]
                }
                return ["success": false, "message": "Habit not found"]
            } catch {
                return ["success": false, "message": "Failed to log habit"]
            }
            
        case "list":
            let request: NSFetchRequest<Habit> = Habit.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            
            if let isActive = parameters["active"] as? Bool {
                request.predicate = NSPredicate(format: "isActive == %@", NSNumber(value: isActive))
            }
            
            do {
                let habits = try context.fetch(request)
                let habitData = habits.compactMap { habit -> [String: Any]? in
                    guard let habitId = habit.id else { 
                        print("⚠️ Skipping habit with nil ID: \(habit.name ?? "Unknown")")
                        return nil 
                    }
                    return [
                        "id": habitId.uuidString,
                        "name": habit.name ?? "",
                        "description": habit.notes ?? "",
                        "frequency": habit.frequency ?? "daily",
                        "currentStreak": habit.currentStreak,
                        "bestStreak": habit.bestStreak,
                        "isActive": habit.isActive,
                        "isPaused": habit.isPaused,
                        "colorHex": habit.colorHex ?? "#FF6B6B",
                        "iconName": habit.iconName ?? "star.fill",
                        "category": habit.category?.name ?? "",
                        "reminderTime": formatDate(habit.reminderTime),
                        "trackingType": habit.trackingType ?? "binary",
                        "goalTarget": habit.goalTarget,
                        // "unit": habit.unit ?? "", // Property doesn't exist
                        "createdAt": formatDate(habit.createdAt),
                        "lastCompletedDate": formatDate(habit.lastCompletedDate)
                    ] as [String: Any]
                }
                return ["success": true, "items": habitData, "message": "Found \(habitData.count) habits with valid IDs"]
            } catch {
                return ["success": false, "message": "Failed to list habits"]
            }
            
        default:
            return ["success": false, "message": "Unknown action: \(action)"]
        }
    }
    
    func manage_goals(action: String, parameters: [String: Any]) async -> [String: Any] {
        print("🎯 AICoordinator.manage_goals - Action: \(action)")
        print("📦 Parameters: \(parameters)")
        
        // For now, return a simple response since GoalManager doesn't have processAIRequest
        switch action.lowercased() {
        case "create":
            let title = parameters["title"] as? String ?? "New Goal"
            let description = parameters["description"] as? String
            let targetDate = parseDate(parameters["targetDate"])
            
            // Create a goal using GoalManager
            let goalType: GoalType = parameters["targetValue"] != nil ? .numeric : .milestone
            let result = goalManager.createGoal(
                title: title,
                description: description,
                type: goalType,
                targetValue: parameters["targetValue"] as? Double,
                targetDate: targetDate ?? Date().addingTimeInterval(86400 * 30),
                unit: parameters["unit"] as? String,
                priority: .medium,
                category: findCategory(from: parameters)
            )
            
            if case .success(let goal) = result {
                return ["success": true, "message": "Created goal: \(goal.title ?? "")", "id": goal.id?.uuidString ?? ""]
            } else {
                return ["success": false, "message": "Failed to create goal"]
            }
            
        case "list":
            let goals = goalManager.goals
            let goalData = goals.compactMap { goal -> [String: Any]? in
                guard let goalId = goal.id else { 
                    print("⚠️ Skipping goal with nil ID: \(goal.title ?? "Unknown")")
                    return nil 
                }
                return [
                    "id": goalId.uuidString,
                    "title": goal.title ?? "",
                    "description": goal.desc ?? "",
                    "targetDate": formatDate(goal.targetDate),
                    "progress": goal.progress,
                    "isCompleted": goal.isCompleted
                ] as [String: Any]
            }
            return ["success": true, "items": goalData, "message": "Found \(goalData.count) goals with valid IDs"]
            
        case "update":
            // Debug: Log the parameters received
            print("🎯 Goal update parameters received: \(parameters)")
            
            // Check if this is a bulk update with items array (multiple goals with individual updates)
            if let items = parameters["items"] as? [[String: Any]] {
                print("📦 Bulk update with items array - updating \(items.count) goals")
                
                var updatedCount = 0
                var failedUpdates: [String] = []
                
                for (index, item) in items.enumerated() {
                    // Get the ID from the item
                    if let id = item["id"] as? String, let goalId = UUID(uuidString: id) {
                        if let goal = goalManager.goals.first(where: { $0.id == goalId }) {
                            // Handle category updates
                            if let categoryName = item["category"] as? String ?? item["categoryId"] as? String {
                                // Create category with appropriate defaults for known categories
                                let categoryColors: [String: String] = [
                                    "Education": "#4A90E2",
                                    "Fitness": "#7FD13B", 
                                    "Health": "#FF6B6B",
                                    "Social": "#F5A623",
                                    "Spiritual": "#BD10E0",
                                    "Family": "#FF3B30",
                                    "Finance": "#50E3C2",
                                    "Hobby": "#9013FE",
                                    "Work": "#417505",
                                    "Personal": "#FF9500"
                                ]
                                
                                let categoryIcons: [String: String] = [
                                    "Education": "graduationcap.fill",
                                    "Fitness": "figure.run",
                                    "Health": "heart.fill",
                                    "Social": "person.2.fill",
                                    "Spiritual": "sparkles",
                                    "Family": "house.fill",
                                    "Finance": "dollarsign.circle.fill",
                                    "Hobby": "paintbrush.fill",
                                    "Work": "briefcase.fill",
                                    "Personal": "person.fill"
                                ]
                                
                                let color = categoryColors[categoryName] ?? "#007AFF"
                                let icon = categoryIcons[categoryName] ?? "folder.fill"
                                
                                // Set the category with proper Core Data management
                                let category = findOrCreateCategory(name: categoryName, color: color, icon: icon)
                                goal.category = category
                                
                                // Also update goal's color and icon to match category
                                goal.colorHex = category.colorHex ?? "#007AFF"
                                goal.iconName = category.iconName ?? "target"
                                
                                // Mark the goal as modified to ensure Core Data tracks the change
                                goal.modifiedAt = Date()
                            }
                            
                            updatedCount += 1
                            print("✅ Updated goal: \(goal.title ?? "Unknown") with category: \(goal.category?.name ?? "none")")
                        } else {
                            failedUpdates.append("Goal \(index + 1): ID not found")
                        }
                    } else {
                        // If no ID, try updating by matching categoryId to all goals
                        if let categoryId = item["categoryId"] as? String ?? item["category"] as? String {
                            print("⚠️ Item \(index) has no ID, but has category: \(categoryId)")
                        }
                        failedUpdates.append("Goal \(index + 1): No valid ID")
                    }
                }
                
                // Save all changes with proper Core Data management
                do {
                    // First save the context
                    try context.save()
                    
                    // Force Core Data to process the changes immediately
                    context.processPendingChanges()
                    
                    // Refresh the goal manager to ensure it has the latest data
                    goalManager.loadGoals()
                    
                    let message = failedUpdates.isEmpty 
                        ? "Updated \(updatedCount) goals" 
                        : "Updated \(updatedCount) goals. Failed: \(failedUpdates.joined(separator: ", "))"
                    return ["success": true, "message": message]
                } catch {
                    return ["success": false, "message": "Failed to save updates: \(error.localizedDescription)"]
                }
            }
            
            // Check if this is a bulk update (update all goals)
            if let updateAll = parameters["updateAll"] as? Bool, updateAll == true {
                print("📦 Bulk update requested for all goals")
                
                let goals = goalManager.goals
                var updatedCount = 0
                
                for goal in goals {
                    // Ensure goal has an ID
                    if goal.id == nil {
                        goal.id = UUID()
                        print("⚠️ Assigned new ID to goal: \(goal.title ?? "Unknown")")
                    }
                    
                    // Update fields that were provided
                    if let categoryData = parameters["category"] as? [String: Any],
                       let categoryName = categoryData["name"] as? String {
                        let category = findOrCreateCategory(name: categoryName, color: categoryData["color"] as? String, icon: categoryData["icon"] as? String)
                        goal.category = category
                    }
                    
                    updatedCount += 1
                }
                
                // Save all changes with proper Core Data management
                do {
                    // First save the context
                    try context.save()
                    
                    // Force Core Data to process the changes immediately
                    context.processPendingChanges()
                    
                    // Refresh the goal manager to ensure it has the latest data
                    goalManager.loadGoals()
                    
                    return ["success": true, "message": "Updated \(updatedCount) goals"]
                } catch {
                    return ["success": false, "message": "Failed to update goals: \(error.localizedDescription)"]
                }
            }
            
            // Try to find goal by ID first, then by title as fallback
            var goal: Goal?
            
            if let id = parameters["id"] as? String {
                print("🎯 Attempting to parse UUID from string: '\(id)'")
                
                if let goalId = UUID(uuidString: id) {
                    print("🎯 Looking for goal with ID: \(goalId)")
                    goal = goalManager.goals.first(where: { $0.id == goalId })
                    
                    if goal == nil {
                        print("❌ Goal not found with ID: \(goalId)")
                        print("📋 Available goal IDs: \(goalManager.goals.compactMap { $0.id?.uuidString })")
                    }
                } else {
                    print("❌ Failed to parse UUID from: '\(id)'")
                }
            }
            
            // Fallback: Try to find by title if ID didn't work
            if goal == nil, let title = parameters["title"] as? String {
                print("🔍 Falling back to search by title: '\(title)'")
                goal = goalManager.goals.first(where: { $0.title?.lowercased() == title.lowercased() })
                
                if let foundGoal = goal {
                    print("✅ Found goal by title: \(foundGoal.title ?? "Untitled") with ID: \(foundGoal.id?.uuidString ?? "nil")")
                    
                    // Ensure the goal has an ID (fix legacy goals)
                    if foundGoal.id == nil {
                        print("⚠️ Goal has no ID, assigning new UUID")
                        foundGoal.id = UUID()
                    }
                } else {
                    print("❌ Goal not found by title either")
                }
            }
            
            guard let goalToUpdate = goal else {
                return ["success": false, "message": "Goal not found. Please provide either a valid ID or title."]
            }
            
            print("✅ Found goal to update: \(goalToUpdate.title ?? "Untitled")")
            
            // Update all provided fields
            if let title = parameters["title"] as? String {
                goalToUpdate.title = title
            }
            if let description = parameters["description"] as? String {
                goalToUpdate.desc = description
            }
            if let targetDate = parseDate(parameters["targetDate"]) {
                goalToUpdate.targetDate = targetDate
            }
            if let targetValue = parameters["targetValue"] as? Double {
                goalToUpdate.targetValue = targetValue
            }
            if let currentValue = parameters["currentValue"] as? Double {
                goalToUpdate.currentValue = currentValue
            }
            if let unit = parameters["unit"] as? String {
                goalToUpdate.unit = unit
            }
            // Color and icon come from category only
            if let isCompleted = parameters["isCompleted"] as? Bool {
                goalToUpdate.isCompleted = isCompleted
            }
            if let categoryData = parameters["category"] as? [String: Any],
               let categoryName = categoryData["name"] as? String {
                let category = findOrCreateCategory(name: categoryName, color: categoryData["color"] as? String, icon: categoryData["icon"] as? String)
                goalToUpdate.category = category
            }
            
            // Save changes
            do {
                try context.save()
                return ["success": true, "message": "Updated goal: \(goalToUpdate.title ?? "")", "id": goalToUpdate.id?.uuidString ?? ""]
            } catch {
                return ["success": false, "message": "Failed to update goal: \(error.localizedDescription)"]
            }
            
        case "delete":
            guard let id = parameters["id"] as? String,
                  let goalId = UUID(uuidString: id) else {
                return ["success": false, "message": "Valid goal ID required for deletion"]
            }
            
            guard let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
                return ["success": false, "message": "Goal not found"]
            }
            
            let result = goalManager.deleteGoal(goal)
            if case .success = result {
                return ["success": true, "message": "Deleted goal"]
            } else {
                return ["success": false, "message": "Failed to delete goal"]
            }
            
        case "complete":
            guard let id = parameters["id"] as? String,
                  let goalId = UUID(uuidString: id) else {
                return ["success": false, "message": "Valid goal ID required"]
            }
            
            guard let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
                return ["success": false, "message": "Goal not found"]
            }
            
            goal.isCompleted = true
            goal.completedDate = Date()
            
            do {
                try context.save()
                return ["success": true, "message": "Marked goal as completed"]
            } catch {
                return ["success": false, "message": "Failed to complete goal"]
            }
            
        case "update_progress":
            guard let id = parameters["id"] as? String,
                  let goalId = UUID(uuidString: id) else {
                return ["success": false, "message": "Valid goal ID required"]
            }
            
            guard let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
                return ["success": false, "message": "Goal not found"]
            }
            
            if let progress = parameters["progress"] as? Double {
                goal.currentValue = progress * goal.targetValue
            } else if let currentValue = parameters["currentValue"] as? Double {
                goal.currentValue = currentValue
            }
            
            do {
                try context.save()
                return ["success": true, "message": "Updated goal progress", "progress": goal.progress]
            } catch {
                return ["success": false, "message": "Failed to update progress"]
            }
            
        default:
            return ["success": false, "message": "Goal action not implemented: \(action)"]
        }
    }
    
    func manage_categories(action: String, parameters: [String: Any]) async -> [String: Any] {
        print("🎯 AICoordinator.manage_categories - Action: \(action)")
        print("📦 Parameters: \(parameters)")
        
        switch action.lowercased() {
        case "create":
            guard let name = parameters["name"] as? String else {
                return ["success": false, "message": "Category name is required"]
            }
            
            let category = Category(context: context)
            category.id = UUID()
            category.name = name
            category.colorHex = parameters["color"] as? String ?? "#007AFF"
            category.iconName = parameters["icon"] as? String ?? "folder"
            
            do {
                try context.save()
                return ["success": true, "message": "Created category: \(name)"]
            } catch {
                return ["success": false, "message": "Failed to create category"]
            }
            
        case "list":
            let categories = scheduleManager.categories.map { cat in
                return [
                    "id": cat.id?.uuidString ?? "",
                    "name": cat.name ?? "",
                    "color": cat.colorHex ?? "",
                    "icon": cat.iconName ?? ""
                ] as [String: Any]
            }
            return ["success": true, "items": categories, "message": "Found \(categories.count) categories"]
            
        case "delete":
            guard let id = parameters["id"] as? String,
                  let categoryId = UUID(uuidString: id) else {
                return ["success": false, "message": "Valid category ID required"]
            }
            
            let request: NSFetchRequest<Category> = Category.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", categoryId as CVarArg)
            
            do {
                if let category = try context.fetch(request).first {
                    context.delete(category)
                    try context.save()
                    return ["success": true, "message": "Deleted category"]
                }
                return ["success": false, "message": "Category not found"]
            } catch {
                return ["success": false, "message": "Failed to delete category"]
            }
            
        default:
            return ["success": false, "message": "Unknown action: \(action)"]
        }
    }
}