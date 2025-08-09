//
//  EventAIService.swift
//  Momentum
//
//  Handles all event-related AI operations
//

import Foundation
import CoreData

final class EventAIService: BaseAIService<Event> {
    
    private let eventManager: EventManager
    
    init(context: NSManagedObjectContext, eventManager: EventManager) {
        self.eventManager = eventManager
        super.init(serviceName: "EventAIService", context: context)
    }
    
    override func create(parameters: [String: Any]) async -> AIResult {
        guard let title = parameters["title"] as? String else {
            return AIResult.failure("Missing required field: title")
        }
        
        let event = Event(context: context)
        event.id = UUID()
        event.title = title
        event.isAllDay = parameters["isAllDay"] as? Bool ?? false
        event.location = parameters["location"] as? String
        event.notes = parameters["notes"] as? String
        
        if let startTimeString = parameters["startTime"] as? String,
           let startTime = ISO8601DateFormatter().date(from: startTimeString) {
            event.startTime = startTime
        } else if let startTime = parameters["startTime"] as? Date {
            event.startTime = startTime
        } else {
            event.startTime = Date()
        }
        
        if let endTimeString = parameters["endTime"] as? String,
           let endTime = ISO8601DateFormatter().date(from: endTimeString) {
            event.endTime = endTime
        } else if let endTime = parameters["endTime"] as? Date {
            event.endTime = endTime
        } else {
            event.endTime = event.startTime?.addingTimeInterval(3600) ?? Date()
        }
        
        if let categoryId = parameters["categoryId"] as? String,
           let categoryUUID = UUID(uuidString: categoryId) {
            let request: NSFetchRequest<GoalCategory> = GoalCategory.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", categoryUUID as CVarArg)
            if let category = try? context.fetch(request).first {
                event.category = category
            }
        }
        
        if let reminderMinutes = parameters["reminderMinutes"] as? [Int] {
            event.reminderMinutes = reminderMinutes
        }
        
        do {
            try context.save()
            return AIResult.success("Created event: \(title)", data: ["id": event.id?.uuidString ?? ""])
        } catch {
            return AIResult.failure("Failed to create event: \(error.localizedDescription)")
        }
    }
    
    override func update(id: String?, parameters: [String: Any]) async -> AIResult {
        guard let id = id, let uuid = UUID(uuidString: id) else {
            return AIResult.failure("Invalid or missing event ID")
        }
        
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        do {
            guard let event = try context.fetch(request).first else {
                return AIResult.failure("Event not found")
            }
            
            if let title = parameters["title"] as? String {
                event.title = title
            }
            if let location = parameters["location"] as? String {
                event.location = location
            }
            if let notes = parameters["notes"] as? String {
                event.notes = notes
            }
            if let isAllDay = parameters["isAllDay"] as? Bool {
                event.isAllDay = isAllDay
            }
            if let startTimeString = parameters["startTime"] as? String,
               let startTime = ISO8601DateFormatter().date(from: startTimeString) {
                event.startTime = startTime
            }
            if let endTimeString = parameters["endTime"] as? String,
               let endTime = ISO8601DateFormatter().date(from: endTimeString) {
                event.endTime = endTime
            }
            if let categoryId = parameters["categoryId"] as? String,
               let categoryUUID = UUID(uuidString: categoryId) {
                let categoryRequest: NSFetchRequest<GoalCategory> = GoalCategory.fetchRequest()
                categoryRequest.predicate = NSPredicate(format: "id == %@", categoryUUID as CVarArg)
                if let category = try context.fetch(categoryRequest).first {
                    event.category = category
                }
            }
            
            try context.save()
            return AIResult.success("Updated event: \(event.title ?? "")")
        } catch {
            return AIResult.failure("Failed to update event: \(error.localizedDescription)")
        }
    }
    
    override func list(parameters: [String: Any]) async -> AIResult {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        var predicates: [NSPredicate] = []
        
        if let date = parameters["date"] as? Date {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            predicates.append(NSPredicate(format: "startTime >= %@ AND startTime < %@", startOfDay as NSDate, endOfDay as NSDate))
        }
        
        if let categoryId = parameters["categoryId"] as? String,
           let uuid = UUID(uuidString: categoryId) {
            predicates.append(NSPredicate(format: "category.id == %@", uuid as CVarArg))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
        
        do {
            let events = try context.fetch(request)
            let eventData = events.map { event in
                return [
                    "id": event.id?.uuidString ?? "",
                    "title": event.title ?? "",
                    "startTime": ISO8601DateFormatter().string(from: event.startTime ?? Date()),
                    "endTime": ISO8601DateFormatter().string(from: event.endTime ?? Date()),
                    "location": event.location ?? "",
                    "isAllDay": event.isAllDay
                ]
            }
            return AIResult.success("Found \(events.count) events", data: eventData)
        } catch {
            return AIResult.failure("Failed to list events: \(error.localizedDescription)")
        }
    }
}