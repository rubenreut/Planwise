//
//  HabitsHandler.swift
//  Momentum
//
//  Habits domain handler for AI Coordinator
//

import Foundation
import CoreData

// MARK: - Protocol
protocol HabitsHandling {
    func create(_ parameters: [String: Any]) async -> [String: Any]
    func update(_ parameters: [String: Any]) async -> [String: Any]
    func delete(_ parameters: [String: Any]) async -> [String: Any]
    func list(_ parameters: [String: Any]) async -> [String: Any]
    func log(_ parameters: [String: Any]) async -> [String: Any]
}

// MARK: - Implementation
@MainActor
final class HabitsHandler: HabitsHandling {
    private let habitManager: HabitManaging
    private let scheduleManager: ScheduleManaging
    private let context: NSManagedObjectContext
    private let categoryResolver: CategoryResolver
    private let gateway: CoreDataGateway
    
    init(habitManager: HabitManaging, scheduleManager: ScheduleManaging, context: NSManagedObjectContext) {
        self.habitManager = habitManager
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
            let req = try ParameterDecoder.decode(HabitCreateRequest.self, from: parameters)
            
            // Parse frequency enum
            let frequency = HabitFrequency(rawValue: req.frequency) ?? .daily
            
            // Determine tracking type based on unit or default to binary
            let trackingType: HabitTrackingType = {
                if req.unit != nil {
                    return .quantity
                } else {
                    return .binary
                }
            }()
            
            let result = habitManager.createHabit(
                name: req.name,
                icon: req.icon ?? "star.fill",
                color: req.color ?? "#007AFF",
                frequency: frequency,
                trackingType: trackingType,
                goalTarget: Double(req.goalTarget),
                goalUnit: req.unit,
                category: categoryResolver.resolve(id: req.categoryId, name: req.category),
                notes: req.notes
            )
            
            if case .success(let habit) = result {
                // Note: Additional properties like reminder, startDate, endDate are not
                // part of the current Habit entity model
                
                try? context.save()
                
                return ActionResult<HabitView>(
                    success: true,
                    message: "Created habit: \(habit.name ?? "Habit")",
                    id: habit.id?.uuidString,
                    updatedCount: 1
                ).toDictionary()
            }
            
            return ActionResult<HabitView>(
                success: false,
                message: "Failed to create habit"
            ).toDictionary()
            
        } catch {
            return ActionResult<HabitView>(
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
            let req = try ParameterDecoder.decode(HabitUpdateRequest.self, from: parameters)
            
            guard let uuid = UUID(uuidString: req.id),
                  let habit = habitManager.habits.first(where: { $0.id == uuid }) else {
                return ActionResult<HabitView>(
                    success: false,
                    message: "Habit not found"
                ).toDictionary()
            }
            
            // Update habit properties directly
            if let name = req.name {
                habit.name = name
            }
            if let notes = req.notes {
                habit.notes = notes
            }
            if let frequency = req.frequency {
                habit.frequency = frequency
            }
            if let goalTarget = req.goalTarget {
                habit.goalTarget = Double(goalTarget)
            }
            if let unit = req.unit {
                habit.goalUnit = unit
            }
            if let color = req.color {
                habit.colorHex = color
            }
            if let icon = req.icon {
                habit.iconName = icon
            }
            if let category = categoryResolver.resolve(id: req.categoryId, name: req.category) {
                habit.category = category
            }
            
            // Update through manager to trigger necessary side effects
            let result = habitManager.updateHabit(habit)
            
            if case .success = result {
                
                try? context.save()
                
                return ActionResult<HabitView>(
                    success: true,
                    message: "Updated habit",
                    id: habit.id?.uuidString,
                    updatedCount: 1
                ).toDictionary()
            }
            
            return ActionResult<HabitView>(
                success: false,
                message: "Failed to update habit"
            ).toDictionary()
            
        } catch {
            return ActionResult<HabitView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
    
    // MARK: - Delete
    func delete(_ parameters: [String: Any]) async -> [String: Any] {
        // Check for bulk delete
        if parameters["deleteAll"] as? Bool == true {
            let habits = habitManager.habits
            
            do {
                try BulkDeleteGuard.check(parameters: parameters, count: habits.count)
                
                var deleted = 0
                for habit in habits {
                    if case .success = habitManager.deleteHabit(habit) {
                        deleted += 1
                    }
                }
                
                return ActionResult<HabitView>(
                    success: true,
                    message: "Deleted \(deleted) habits",
                    matchedCount: habits.count,
                    updatedCount: deleted
                ).toDictionary()
                
            } catch {
                return ActionResult<HabitView>(
                    success: false,
                    message: error.localizedDescription,
                    matchedCount: habits.count
                ).toDictionary()
            }
        }
        
        // Delete by IDs
        if let ids = parameters["ids"] as? [String] {
            var deleted = 0
            
            for id in ids {
                if let uuid = UUID(uuidString: id),
                   let habit = habitManager.habits.first(where: { $0.id == uuid }),
                   case .success = habitManager.deleteHabit(habit) {
                    deleted += 1
                }
            }
            
            return ActionResult<HabitView>(
                success: deleted > 0,
                message: "Deleted \(deleted) habits",
                matchedCount: ids.count,
                updatedCount: deleted
            ).toDictionary()
        }
        
        // Single delete
        if let id = parameters["id"] as? String,
           let uuid = UUID(uuidString: id),
           let habit = habitManager.habits.first(where: { $0.id == uuid }),
           case .success = habitManager.deleteHabit(habit) {
            
            return ActionResult<HabitView>(
                success: true,
                message: "Deleted habit",
                id: id,
                matchedCount: 1,
                updatedCount: 1
            ).toDictionary()
        }
        
        return ActionResult<HabitView>(
            success: false,
            message: "Failed to delete - no valid parameters provided"
        ).toDictionary()
    }
    
    // MARK: - List
    func list(_ parameters: [String: Any]) async -> [String: Any] {
        let filter = parameters["filter"] as? String
        var habits = habitManager.habits
        
        // Apply filters
        if let filter = filter?.lowercased() {
            switch filter {
            case "active":
                break  // All habits are active by default, no filter needed
            case "archived":
                habits = []  // No archive functionality in current model
            case "daily":
                habits = habits.filter { $0.frequency == "daily" }
            case "weekly":
                habits = habits.filter { $0.frequency == "weekly" }
            case "monthly":
                habits = habits.filter { $0.frequency == "monthly" }
            default:
                break
            }
        }
        
        let views = habits.compactMap { habit -> HabitView? in
            guard let id = habit.id?.uuidString else { return nil }
            
            // Calculate streaks
            let streakData = StreakCalculator.calculateStreak(for: habit)
            
            // Get today's progress from entries
            let todayEntries = habit.entries?.allObjects as? [HabitEntry] ?? []
            let today = Calendar.current.startOfDay(for: Date())
            let todayProgress = todayEntries.filter { entry in
                guard let date = entry.date else { return false }
                return Calendar.current.isDate(date, inSameDayAs: today)
            }.reduce(0) { $0 + Int($1.value) }
            
            return HabitView(
                id: id,
                name: habit.name ?? "",
                notes: habit.notes ?? "",
                frequency: habit.frequency ?? "daily",
                goalTarget: Int(habit.goalTarget),
                unit: habit.goalUnit ?? "",
                color: habit.colorHex ?? "#007AFF",
                icon: habit.iconName ?? "star",
                category: habit.category?.name ?? "",
                reminder: nil,  // Not in current model
                startDate: nil,  // Not in current model
                endDate: nil,    // Not in current model
                isArchived: false,  // Not in current model
                currentStreak: streakData.currentStreak,
                longestStreak: streakData.longestStreak,
                todayProgress: Int(todayProgress),
                createdAt: DateParsingUtility.formatDate(habit.createdAt) ?? ""
            )
        }
        
        return ActionResult<HabitView>(
            success: true,
            message: "Found \(views.count) habits",
            items: views,
            matchedCount: views.count
        ).toDictionary()
    }
    
    // MARK: - Log Progress
    func log(_ parameters: [String: Any]) async -> [String: Any] {
        do {
            let req = try ParameterDecoder.decode(HabitLogRequest.self, from: parameters)
            
            guard let uuid = UUID(uuidString: req.habitId),
                  let habit = habitManager.habits.first(where: { $0.id == uuid }) else {
                return ActionResult<HabitView>(
                    success: false,
                    message: "Habit not found"
                ).toDictionary()
            }
            
            let date = req.date.flatMap(DateParsingUtility.parseDate) ?? Date()
            let value = Double(req.value ?? 1)
            
            let result = habitManager.logHabit(
                habit,
                value: value,
                date: date,
                notes: nil,
                mood: nil,
                duration: nil,
                quality: nil
            )
            
            if case .success = result {
                return ActionResult<HabitView>(
                    success: true,
                    message: "Logged progress: \(value) \(habit.goalUnit ?? "times")",
                    id: habit.id?.uuidString,
                    updatedCount: 1
                ).toDictionary()
            }
            
            return ActionResult<HabitView>(
                success: false,
                message: "Failed to log progress"
            ).toDictionary()
            
        } catch {
            return ActionResult<HabitView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
    
    // MARK: - Bulk Helpers
    
    private func bulkCreate(_ items: Any) async -> [String: Any] {
        do {
            let requests = try ParameterDecoder.decodeArray(HabitCreateRequest.self, from: items)
            var created = 0
            var errors: [String] = []
            
            for req in requests {
                // Parse frequency enum
                let frequency = HabitFrequency(rawValue: req.frequency) ?? .daily
                
                // Determine tracking type
                let trackingType: HabitTrackingType = req.unit != nil ? .quantity : .binary
                
                let result = habitManager.createHabit(
                    name: req.name,
                    icon: req.icon ?? "star.fill",
                    color: req.color ?? "#007AFF",
                    frequency: frequency,
                    trackingType: trackingType,
                    goalTarget: Double(req.goalTarget),
                    goalUnit: req.unit,
                    category: categoryResolver.resolve(id: req.categoryId, name: req.category),
                    notes: req.notes
                )
                
                if case .success = result {
                    created += 1
                } else {
                    errors.append("\(req.name): create failed")
                }
            }
            
            try? context.save()
            
            let message = errors.isEmpty
                ? "Created \(created) habits"
                : "Created \(created) habits. Errors: \(errors.joined(separator: "; "))"
            
            return ActionResult<HabitView>(
                success: created > 0,
                message: message,
                updatedCount: created
            ).toDictionary()
            
        } catch {
            return ActionResult<HabitView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
    
    private func bulkUpdate(_ items: Any) async -> [String: Any] {
        do {
            let requests = try ParameterDecoder.decodeArray(HabitUpdateRequest.self, from: items)
            var updated = 0
            var errors: [String] = []
            
            for req in requests {
                guard let uuid = UUID(uuidString: req.id),
                      let habit = habitManager.habits.first(where: { $0.id == uuid }) else {
                    errors.append("Habit not found: \(req.id)")
                    continue
                }
                
                // Update habit properties directly
                if let name = req.name {
                    habit.name = name
                }
                if let notes = req.notes {
                    habit.notes = notes
                }
                if let frequency = req.frequency {
                    habit.frequency = frequency
                }
                if let goalTarget = req.goalTarget {
                    habit.goalTarget = Double(goalTarget)
                }
                if let unit = req.unit {
                    habit.goalUnit = unit
                }
                if let color = req.color {
                    habit.colorHex = color
                }
                if let icon = req.icon {
                    habit.iconName = icon
                }
                if let category = categoryResolver.resolve(id: req.categoryId, name: req.category) {
                    habit.category = category
                }
                
                // Update through manager
                let result = habitManager.updateHabit(habit)
                
                if case .success = result {
                    updated += 1
                }
            }
            
            try? context.save()
            
            let message = errors.isEmpty
                ? "Updated \(updated) habits"
                : "Updated \(updated) habits. Errors: \(errors.joined(separator: "; "))"
            
            return ActionResult<HabitView>(
                success: updated > 0,
                message: message,
                updatedCount: updated
            ).toDictionary()
            
        } catch {
            return ActionResult<HabitView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
}