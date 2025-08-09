//
//  CategoryAIService.swift
//  Momentum
//
//  Handles all category-related AI operations
//

import Foundation
import CoreData

final class CategoryAIService: BaseAIService<Category> {
    
    init(context: NSManagedObjectContext) {
        super.init(serviceName: "CategoryAIService", context: context)
    }
    
    override func create(parameters: [String: Any]) async -> AIResult {
        guard let name = parameters["name"] as? String else {
            return AIResult.failure("Missing required field: name")
        }
        
        let category = Category(context: context)
        category.id = UUID()
        category.name = name
        category.color = parameters["color"] as? String ?? "#007AFF"
        category.icon = parameters["icon"] as? String ?? "folder"
        category.createdAt = Date()
        
        do {
            try context.save()
            return AIResult.success("Created category: \(name)", data: ["id": category.id?.uuidString ?? ""])
        } catch {
            return AIResult.failure("Failed to create category: \(error.localizedDescription)")
        }
    }
    
    override func update(id: String?, parameters: [String: Any]) async -> AIResult {
        guard let id = id, let uuid = UUID(uuidString: id) else {
            return AIResult.failure("Invalid or missing category ID")
        }
        
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        do {
            guard let category = try context.fetch(request).first else {
                return AIResult.failure("Category not found")
            }
            
            if let name = parameters["name"] as? String {
                category.name = name
            }
            if let color = parameters["color"] as? String {
                category.color = color
            }
            if let icon = parameters["icon"] as? String {
                category.icon = icon
            }
            
            try context.save()
            return AIResult.success("Updated category: \(category.name ?? "")")
        } catch {
            return AIResult.failure("Failed to update category: \(error.localizedDescription)")
        }
    }
    
    override func list(parameters: [String: Any]) async -> AIResult {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            let categories = try context.fetch(request)
            let categoryData = categories.map { category in
                return [
                    "id": category.id?.uuidString ?? "",
                    "name": category.name ?? "",
                    "color": category.color ?? "#007AFF",
                    "icon": category.icon ?? "folder",
                    "goalCount": category.goals?.count ?? 0,
                    "taskCount": category.tasks?.count ?? 0
                ]
            }
            return AIResult.success("Found \(categories.count) categories", data: categoryData)
        } catch {
            return AIResult.failure("Failed to list categories: \(error.localizedDescription)")
        }
    }
    
    override func delete(id: String?, parameters: [String: Any]) async -> AIResult {
        guard let id = id, let uuid = UUID(uuidString: id) else {
            return AIResult.failure("Invalid or missing category ID")
        }
        
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        do {
            guard let category = try context.fetch(request).first else {
                return AIResult.failure("Category not found")
            }
            
            if (category.goals?.count ?? 0) > 0 || (category.tasks?.count ?? 0) > 0 {
                return AIResult.failure("Cannot delete category with existing goals or tasks")
            }
            
            context.delete(category)
            try context.save()
            return AIResult.success("Deleted category: \(category.name ?? "")")
        } catch {
            return AIResult.failure("Failed to delete category: \(error.localizedDescription)")
        }
    }
}