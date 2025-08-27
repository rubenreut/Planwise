//
//  EventsHandler.swift
//  Momentum
//
//  Events domain handler for AI Coordinator
//

import Foundation
import CoreData

// MARK: - Protocol
protocol EventsHandling {
    func create(_ parameters: [String: Any]) async -> [String: Any]
    func update(_ parameters: [String: Any]) async -> [String: Any]
    func delete(_ parameters: [String: Any]) async -> [String: Any]
    func list(_ parameters: [String: Any]) async -> [String: Any]
}

// MARK: - Implementation
@MainActor
final class EventsHandler: EventsHandling {
    private let context: NSManagedObjectContext
    private let scheduleManager: ScheduleManaging
    private let categoryResolver: CategoryResolver
    private let gateway: CoreDataGateway
    
    init(context: NSManagedObjectContext, scheduleManager: ScheduleManaging) {
        self.context = context
        self.scheduleManager = scheduleManager
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
            let req = try ParameterDecoder.decode(EventCreateRequest.self, from: parameters)
            let range = try EventTimeRange(startRaw: req.startTime, endRaw: req.endTime)
            
            let result = scheduleManager.createEvent(
                title: req.title,
                startTime: range.start,
                endTime: range.end,
                category: categoryResolver.resolve(id: req.categoryId, name: req.category),
                notes: req.notes,
                location: req.location,
                isAllDay: req.isAllDay
            )
            
            if case .success(let event) = result {
                return ActionResult<EventView>(
                    success: true,
                    message: "Created event: \(event.title ?? "Event")",
                    id: event.id?.uuidString,
                    updatedCount: 1
                ).toDictionary()
            }
            
            return ActionResult<EventView>(
                success: false,
                message: "Failed to create event"
            ).toDictionary()
            
        } catch {
            return ActionResult<EventView>(
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
            let req = try ParameterDecoder.decode(EventUpdateRequest.self, from: parameters)
            
            guard let uuid = UUID(uuidString: req.id),
                  let event = scheduleManager.events.first(where: { $0.id == uuid }) else {
                return ActionResult<EventView>(
                    success: false,
                    message: "Event not found"
                ).toDictionary()
            }
            
            // Validate time range if both provided
            if let startStr = req.startTime, let endStr = req.endTime {
                _ = try EventTimeRange(startRaw: startStr, endRaw: endStr)
            }
            
            let result = scheduleManager.updateEvent(
                event,
                title: req.title,
                startTime: DateParsingUtility.parseDate(req.startTime),
                endTime: DateParsingUtility.parseDate(req.endTime),
                category: categoryResolver.resolve(id: req.categoryId, name: req.category),
                notes: req.notes,
                location: req.location,
                isCompleted: req.isCompleted,
                colorHex: req.colorHex,
                iconName: req.iconName,
                priority: req.priority,
                tags: req.tags,
                url: req.url,
                energyLevel: req.energyLevel,
                weatherRequired: req.weatherRequired,
                bufferTimeBefore: req.bufferTimeBefore,
                bufferTimeAfter: req.bufferTimeAfter,
                recurrenceRule: req.recurrenceRule,
                recurrenceEndDate: DateParsingUtility.parseDate(req.recurrenceEndDate),
                linkedTasks: nil
            )
            
            if case .success = result {
                return ActionResult<EventView>(
                    success: true,
                    message: "Updated event",
                    id: event.id?.uuidString,
                    updatedCount: 1
                ).toDictionary()
            }
            
            return ActionResult<EventView>(
                success: false,
                message: "Failed to update event"
            ).toDictionary()
            
        } catch {
            return ActionResult<EventView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
    
    // MARK: - Delete
    func delete(_ parameters: [String: Any]) async -> [String: Any] {
        // Check for bulk delete
        if parameters["deleteAll"] as? Bool == true {
            let events = scheduleManager.events
            
            do {
                try BulkDeleteGuard.check(parameters: parameters, count: events.count)
                
                var deleted = 0
                for event in events {
                    if case .success = scheduleManager.deleteEvent(event) {
                        deleted += 1
                    }
                }
                
                return ActionResult<EventView>(
                    success: true,
                    message: "Deleted \(deleted) events",
                    matchedCount: events.count,
                    updatedCount: deleted
                ).toDictionary()
                
            } catch {
                return ActionResult<EventView>(
                    success: false,
                    message: error.localizedDescription,
                    matchedCount: events.count
                ).toDictionary()
            }
        }
        
        // Delete by IDs
        if let ids = parameters["ids"] as? [String] {
            var deleted = 0
            
            for id in ids {
                if let uuid = UUID(uuidString: id),
                   let event = scheduleManager.events.first(where: { $0.id == uuid }),
                   case .success = scheduleManager.deleteEvent(event) {
                    deleted += 1
                }
            }
            
            return ActionResult<EventView>(
                success: deleted > 0,
                message: "Deleted \(deleted) events",
                matchedCount: ids.count,
                updatedCount: deleted
            ).toDictionary()
        }
        
        // Single delete
        if let id = parameters["id"] as? String,
           let uuid = UUID(uuidString: id),
           let event = scheduleManager.events.first(where: { $0.id == uuid }),
           case .success = scheduleManager.deleteEvent(event) {
            
            return ActionResult<EventView>(
                success: true,
                message: "Deleted event",
                id: id,
                matchedCount: 1,
                updatedCount: 1
            ).toDictionary()
        }
        
        return ActionResult<EventView>(
            success: false,
            message: "Failed to delete - no valid parameters provided"
        ).toDictionary()
    }
    
    // MARK: - List
    func list(_ parameters: [String: Any]) async -> [String: Any] {
        let dateStr = parameters["date"] as? String
        let events: [Event]
        
        if let dateStr = dateStr, let date = DateParsingUtility.parseDate(dateStr) {
            events = scheduleManager.events(for: date)
        } else {
            events = scheduleManager.eventsForToday()
        }
        
        let views = events.compactMap { event -> EventView? in
            guard let id = event.id?.uuidString else { return nil }
            
            return EventView(
                id: id,
                title: event.title ?? "",
                startTime: DateParsingUtility.formatDate(event.startTime),
                endTime: DateParsingUtility.formatDate(event.endTime),
                location: event.location ?? "",
                notes: event.notes ?? "",
                isCompleted: event.isCompleted,
                colorHex: event.colorHex ?? "#007AFF",
                iconName: event.iconName ?? "calendar",
                category: event.category?.name ?? "",
                priority: event.priority,
                energyLevel: event.energyLevel,
                weatherRequired: event.weatherRequired ?? "",
                url: event.url ?? "",
                tags: event.tags?.components(separatedBy: ",") ?? [],
                bufferTimeBefore: Int(event.bufferTimeBefore),
                bufferTimeAfter: Int(event.bufferTimeAfter)
            )
        }
        
        return ActionResult(
            success: true,
            message: "Found \(views.count) events",
            items: views,
            matchedCount: views.count
        ).toDictionary()
    }
    
    // MARK: - Bulk Helpers
    
    private func bulkCreate(_ items: Any) async -> [String: Any] {
        do {
            let requests = try ParameterDecoder.decodeArray(EventCreateRequest.self, from: items)
            var created = 0
            var errors: [String] = []
            
            for req in requests {
                do {
                    let range = try EventTimeRange(startRaw: req.startTime, endRaw: req.endTime)
                    
                    let result = scheduleManager.createEvent(
                        title: req.title,
                        startTime: range.start,
                        endTime: range.end,
                        category: categoryResolver.resolve(id: req.categoryId, name: req.category),
                        notes: req.notes,
                        location: req.location,
                        isAllDay: req.isAllDay
                    )
                    
                    if case .success = result {
                        created += 1
                    } else {
                        errors.append("\(req.title): create failed")
                    }
                } catch {
                    errors.append("\(req.title): \(error.localizedDescription)")
                }
            }
            
            let message = errors.isEmpty
                ? "Created \(created) events"
                : "Created \(created) events. Errors: \(errors.joined(separator: "; "))"
            
            return ActionResult<EventView>(
                success: created > 0,
                message: message,
                updatedCount: created
            ).toDictionary()
            
        } catch {
            return ActionResult<EventView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
    
    private func bulkUpdate(_ items: Any) async -> [String: Any] {
        do {
            let requests = try ParameterDecoder.decodeArray(EventUpdateRequest.self, from: items)
            var updated = 0
            var errors: [String] = []
            
            for req in requests {
                guard let uuid = UUID(uuidString: req.id),
                      let event = scheduleManager.events.first(where: { $0.id == uuid }) else {
                    errors.append("Event not found: \(req.id)")
                    continue
                }
                
                // Validate time range if both provided
                if let startStr = req.startTime, let endStr = req.endTime {
                    do {
                        _ = try EventTimeRange(startRaw: startStr, endRaw: endStr)
                    } catch {
                        errors.append("Event \(event.title ?? ""): \(error.localizedDescription)")
                        continue
                    }
                }
                
                let result = scheduleManager.updateEvent(
                    event,
                    title: req.title,
                    startTime: DateParsingUtility.parseDate(req.startTime),
                    endTime: DateParsingUtility.parseDate(req.endTime),
                    category: categoryResolver.resolve(id: req.categoryId, name: req.category),
                    notes: req.notes,
                    location: req.location,
                    isCompleted: req.isCompleted,
                    colorHex: req.colorHex,
                    iconName: req.iconName,
                    priority: req.priority,
                    tags: req.tags,
                    url: req.url,
                    energyLevel: req.energyLevel,
                    weatherRequired: req.weatherRequired,
                    bufferTimeBefore: req.bufferTimeBefore,
                    bufferTimeAfter: req.bufferTimeAfter,
                    recurrenceRule: req.recurrenceRule,
                    recurrenceEndDate: DateParsingUtility.parseDate(req.recurrenceEndDate),
                    linkedTasks: nil
                )
                
                if case .success = result {
                    updated += 1
                }
            }
            
            let message = errors.isEmpty
                ? "Updated \(updated) events"
                : "Updated \(updated) events. Errors: \(errors.joined(separator: "; "))"
            
            return ActionResult<EventView>(
                success: updated > 0,
                message: message,
                updatedCount: updated
            ).toDictionary()
            
        } catch {
            return ActionResult<EventView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
}