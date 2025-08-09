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
        habit.notes = parameters["description"] as? String
        habit.frequency = parameters["frequency"] as? String ?? "daily"
        // Target count would need to be stored differently
        habit.currentStreak = 0
        habit.currentStreak = 0
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
            let request: NSFetchRequest<Category> = Category.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", categoryUUID as CVarArg)
            if let category = try? context.fetch(request).first {
                habit.category = category
            }
        }
        
        // Color and icon would need to be stored differently
        
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
                habit.notes = description
            }
            if let frequency = parameters["frequency"] as? String {
                habit.frequency = frequency
            }
            // Target count update would need different implementation
            if let isActive = parameters["isActive"] as? Bool {
                habit.isActive = isActive
            }
            if let currentStreak = parameters["currentStreak"] as? Int {
                habit.currentStreak = Int32(currentStreak)
                // Update longest streak if needed
            }
            if let reminderTimeString = parameters["reminderTime"] as? String,
               let reminderTime = ISO8601DateFormatter().date(from: reminderTimeString) {
                habit.reminderTime = reminderTime
            }
            // Color and icon updates would need different implementation
            
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
                    "description": habit.notes ?? "",
                    "frequency": habit.frequency ?? "daily",
                    "frequency": habit.frequency ?? "daily",
                    "currentStreak": habit.currentStreak,
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
            
            // Log habit completion
            // HabitLog entity doesn't exist, would need different approach
            
            // Update last completion time if the property exists
            habit.currentStreak += 1
            // Update streaks as needed
            
            try context.save()
            return AIResult.success("Logged completion for habit: \(habit.name ?? "")")
        } catch {
            return AIResult.failure("Failed to log habit completion: \(error.localizedDescription)")
        }
    }
}