//
//  HabitAIService.swift
//  Momentum
//
//  Handles all habit-related AI operations
//

import Foundation
import CoreData

final class HabitAIService: BaseAIService<Habit> {
    
    init(context: NSManagedObjectContext) {
        super.init(serviceName: "HabitAIService", context: context)
    }
    
    override func create(parameters: [String: Any]) async -> AIResult {
        guard let name = parameters["name"] as? String else {
            return AIResult.failure("Missing required field: name")
        }
        
        let habit = Habit(context: context)
        habit.id = UUID()
        habit.name = name
        habit.habitDescription = parameters["description"] as? String
        habit.frequency = parameters["frequency"] as? String ?? "daily"
        habit.targetCount = Int16(parameters["targetCount"] as? Int ?? 1)
        habit.currentStreak = 0
        habit.longestStreak = 0
        habit.isActive = parameters["isActive"] as? Bool ?? true
        habit.createdAt = Date()
        
        if let reminderTime = parameters["reminderTime"] as? Date {
            habit.reminderTime = reminderTime
        } else if let reminderTimeString = parameters["reminderTime"] as? String,
                  let date = ISO8601DateFormatter().date(from: reminderTimeString) {
            habit.reminderTime = date
        }
        
        if let categoryId = parameters["categoryId"] as? String,
           let categoryUUID = UUID(uuidString: categoryId) {
            let request: NSFetchRequest<GoalCategory> = GoalCategory.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", categoryUUID as CVarArg)
            if let category = try? context.fetch(request).first {
                habit.category = category
            }
        }
        
        if let color = parameters["color"] as? String {
            habit.color = color
        }
        
        if let icon = parameters["icon"] as? String {
            habit.icon = icon
        }
        
        do {
            try context.save()
            return AIResult.success("Created habit: \(name)", data: ["id": habit.id?.uuidString ?? ""])
        } catch {
            return AIResult.failure("Failed to create habit: \(error.localizedDescription)")
        }
    }
    
    override func update(id: String?, parameters: [String: Any]) async -> AIResult {
        guard let id = id, let uuid = UUID(uuidString: id) else {
            return AIResult.failure("Invalid or missing habit ID")
        }
        
        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        do {
            guard let habit = try context.fetch(request).first else {
                return AIResult.failure("Habit not found")
            }
            
            if let name = parameters["name"] as? String {
                habit.name = name
            }
            if let description = parameters["description"] as? String {
                habit.habitDescription = description
            }
            if let frequency = parameters["frequency"] as? String {
                habit.frequency = frequency
            }
            if let targetCount = parameters["targetCount"] as? Int {
                habit.targetCount = Int16(targetCount)
            }
            if let isActive = parameters["isActive"] as? Bool {
                habit.isActive = isActive
            }
            if let currentStreak = parameters["currentStreak"] as? Int {
                habit.currentStreak = Int32(currentStreak)
                if habit.currentStreak > habit.longestStreak {
                    habit.longestStreak = habit.currentStreak
                }
            }
            if let reminderTimeString = parameters["reminderTime"] as? String,
               let reminderTime = ISO8601DateFormatter().date(from: reminderTimeString) {
                habit.reminderTime = reminderTime
            }
            if let color = parameters["color"] as? String {
                habit.color = color
            }
            if let icon = parameters["icon"] as? String {
                habit.icon = icon
            }
            
            try context.save()
            return AIResult.success("Updated habit: \(habit.name ?? "")")
        } catch {
            return AIResult.failure("Failed to update habit: \(error.localizedDescription)")
        }
    }
    
    override func list(parameters: [String: Any]) async -> AIResult {
        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
        var predicates: [NSPredicate] = []
        
        if let isActive = parameters["active"] as? Bool {
            predicates.append(NSPredicate(format: "isActive == %@", NSNumber(value: isActive)))
        }
        
        if let frequency = parameters["frequency"] as? String {
            predicates.append(NSPredicate(format: "frequency == %@", frequency))
        }
        
        if let categoryId = parameters["categoryId"] as? String,
           let uuid = UUID(uuidString: categoryId) {
            predicates.append(NSPredicate(format: "category.id == %@", uuid as CVarArg))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            let habits = try context.fetch(request)
            let habitData = habits.map { habit in
                return [
                    "id": habit.id?.uuidString ?? "",
                    "name": habit.name ?? "",
                    "description": habit.habitDescription ?? "",
                    "frequency": habit.frequency ?? "daily",
                    "targetCount": habit.targetCount,
                    "currentStreak": habit.currentStreak,
                    "longestStreak": habit.longestStreak,
                    "isActive": habit.isActive
                ]
            }
            return AIResult.success("Found \(habits.count) habits", data: habitData)
        } catch {
            return AIResult.failure("Failed to list habits: \(error.localizedDescription)")
        }
    }
    
    func logCompletion(habitId: String, date: Date = Date()) async -> AIResult {
        guard let uuid = UUID(uuidString: habitId) else {
            return AIResult.failure("Invalid habit ID")
        }
        
        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        do {
            guard let habit = try context.fetch(request).first else {
                return AIResult.failure("Habit not found")
            }
            
            let completion = HabitLog(context: context)
            completion.id = UUID()
            completion.habit = habit
            completion.completedAt = date
            completion.count = 1
            
            habit.lastCompletedAt = date
            habit.currentStreak += 1
            if habit.currentStreak > habit.longestStreak {
                habit.longestStreak = habit.currentStreak
            }
            
            try context.save()
            return AIResult.success("Logged completion for habit: \(habit.name ?? "")")
        } catch {
            return AIResult.failure("Failed to log habit completion: \(error.localizedDescription)")
        }
    }
}