//
//  CategoriesHandler.swift
//  Momentum
//
//  Categories domain handler for AI Coordinator
//

import Foundation
import CoreData

// MARK: - Protocol
protocol CategoriesHandling {
    func create(_ parameters: [String: Any]) async -> [String: Any]
    func update(_ parameters: [String: Any]) async -> [String: Any]
    func delete(_ parameters: [String: Any]) async -> [String: Any]
    func list(_ parameters: [String: Any]) async -> [String: Any]
}

// MARK: - Implementation
@MainActor
final class CategoriesHandler: CategoriesHandling {
    private let scheduleManager: ScheduleManaging
    private let taskManager: TaskManaging
    private let habitManager: HabitManaging
    private let goalManager: GoalManager
    private let context: NSManagedObjectContext
    private let gateway: CoreDataGateway
    
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
            let req = try ParameterDecoder.decode(CategoryCreateRequest.self, from: parameters)
            
            let result = scheduleManager.createCategory(
                name: req.name,
                icon: req.iconName ?? "folder",
                colorHex: req.colorHex ?? "#007AFF"
            )
            
            if case .success(let category) = result {
                try? context.save()
                
                return ActionResult<CategoryView>(
                    success: true,
                    message: "Created category: \(category.name ?? "Category")",
                    id: category.id?.uuidString,
                    updatedCount: 1
                ).toDictionary()
            }
            
            return ActionResult<CategoryView>(
                success: false,
                message: "Failed to create category"
            ).toDictionary()
            
        } catch {
            return ActionResult<CategoryView>(
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
            let req = try ParameterDecoder.decode(CategoryUpdateRequest.self, from: parameters)
            
            guard let uuid = UUID(uuidString: req.id),
                  let category = scheduleManager.categories.first(where: { $0.id == uuid }) else {
                return ActionResult<CategoryView>(
                    success: false,
                    message: "Category not found"
                ).toDictionary()
            }
            
            // Update category properties directly
            if let name = req.name {
                category.name = name
            }
            if let colorHex = req.colorHex {
                category.colorHex = colorHex
            }
            if let iconName = req.iconName {
                category.iconName = iconName
            }
            
            do {
                try context.save()
                return ActionResult<CategoryView>(
                    success: true,
                    message: "Updated category",
                    id: category.id?.uuidString,
                    updatedCount: 1
                ).toDictionary()
            } catch {
                return ActionResult<CategoryView>(
                    success: false,
                    message: "Failed to update category: \(error.localizedDescription)"
                ).toDictionary()
            }
            
        } catch {
            return ActionResult<CategoryView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
    
    // MARK: - Delete
    func delete(_ parameters: [String: Any]) async -> [String: Any] {
        // Check for bulk delete
        if parameters["deleteAll"] as? Bool == true {
            let categories = scheduleManager.categories
            
            do {
                try BulkDeleteGuard.check(parameters: parameters, count: categories.count)
                
                var deleted = 0
                for category in categories {
                    context.delete(category)
                    deleted += 1
                }
                try? context.save()
                
                return ActionResult<CategoryView>(
                    success: true,
                    message: "Deleted \(deleted) categories",
                    matchedCount: categories.count,
                    updatedCount: deleted
                ).toDictionary()
                
            } catch {
                return ActionResult<CategoryView>(
                    success: false,
                    message: error.localizedDescription,
                    matchedCount: categories.count
                ).toDictionary()
            }
        }
        
        // Delete by IDs
        if let ids = parameters["ids"] as? [String] {
            var deleted = 0
            
            for id in ids {
                if let uuid = UUID(uuidString: id),
                   let category = scheduleManager.categories.first(where: { $0.id == uuid }) {
                    context.delete(category)
                    deleted += 1
                }
            }
            try? context.save()
            
            return ActionResult<CategoryView>(
                success: deleted > 0,
                message: "Deleted \(deleted) categories",
                matchedCount: ids.count,
                updatedCount: deleted
            ).toDictionary()
        }
        
        // Single delete
        if let id = parameters["id"] as? String,
           let uuid = UUID(uuidString: id),
           let category = scheduleManager.categories.first(where: { $0.id == uuid }) {
            
            context.delete(category)
            try? context.save()
            
            return ActionResult<CategoryView>(
                success: true,
                message: "Deleted category",
                id: id,
                matchedCount: 1,
                updatedCount: 1
            ).toDictionary()
        }
        
        return ActionResult<CategoryView>(
            success: false,
            message: "Failed to delete - no valid parameters provided"
        ).toDictionary()
    }
    
    // MARK: - List
    func list(_ parameters: [String: Any]) async -> [String: Any] {
        let categories = scheduleManager.categories
        
        let views = categories.compactMap { category -> CategoryView? in
            guard let id = category.id?.uuidString else { return nil }
            
            // Count items in each category
            let eventCount = scheduleManager.events.filter { $0.category == category }.count
            let taskCount = taskManager.tasks.filter { $0.category == category }.count
            let habitCount = habitManager.habits.filter { $0.category == category }.count
            let goalCount = goalManager.goals.filter { $0.category == category }.count
            
            return CategoryView(
                id: id,
                name: category.name ?? "",
                colorHex: category.colorHex ?? "#007AFF",
                iconName: category.iconName ?? "folder",
                orderIndex: 0,
                eventCount: eventCount,
                taskCount: taskCount,
                habitCount: habitCount,
                goalCount: goalCount
            )
        }
        
        return ActionResult(
            success: true,
            message: "Found \(views.count) categories",
            items: views,
            matchedCount: views.count
        ).toDictionary()
    }
    
    // MARK: - Bulk Helpers
    
    private func bulkCreate(_ items: Any) async -> [String: Any] {
        do {
            let requests = try ParameterDecoder.decodeArray(CategoryCreateRequest.self, from: items)
            var created = 0
            var errors: [String] = []
            
            for req in requests {
                let result = scheduleManager.createCategory(
                    name: req.name,
                    icon: req.iconName ?? "folder",
                    colorHex: req.colorHex ?? "#007AFF"
                )
                
                if case .success = result {
                    created += 1
                } else {
                    errors.append("\(req.name): create failed")
                }
            }
            
            try? context.save()
            
            let message = errors.isEmpty
                ? "Created \(created) categories"
                : "Created \(created) categories. Errors: \(errors.joined(separator: "; "))"
            
            return ActionResult<CategoryView>(
                success: created > 0,
                message: message,
                updatedCount: created
            ).toDictionary()
            
        } catch {
            return ActionResult<CategoryView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
    
    private func bulkUpdate(_ items: Any) async -> [String: Any] {
        do {
            let requests = try ParameterDecoder.decodeArray(CategoryUpdateRequest.self, from: items)
            var updated = 0
            var errors: [String] = []
            
            for req in requests {
                guard let uuid = UUID(uuidString: req.id),
                      let category = scheduleManager.categories.first(where: { $0.id == uuid }) else {
                    errors.append("Category not found: \(req.id)")
                    continue
                }
                
                // Update category properties directly
                if let name = req.name {
                    category.name = name
                }
                if let colorHex = req.colorHex {
                    category.colorHex = colorHex
                }
                if let iconName = req.iconName {
                    category.iconName = iconName
                }
                updated += 1
            }
            
            try? context.save()
            
            let message = errors.isEmpty
                ? "Updated \(updated) categories"
                : "Updated \(updated) categories. Errors: \(errors.joined(separator: "; "))"
            
            return ActionResult<CategoryView>(
                success: updated > 0,
                message: message,
                updatedCount: updated
            ).toDictionary()
            
        } catch {
            return ActionResult<CategoryView>(
                success: false,
                message: error.localizedDescription
            ).toDictionary()
        }
    }
}