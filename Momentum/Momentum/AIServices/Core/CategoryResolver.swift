//
//  CategoryResolver.swift
//  Momentum
//
//  Centralized category resolution by ID or name
//

import Foundation
import CoreData

@MainActor
struct CategoryResolver {
    let scheduleManager: ScheduleManaging
    let context: NSManagedObjectContext
    
    init(scheduleManager: ScheduleManaging, context: NSManagedObjectContext) {
        self.scheduleManager = scheduleManager
        self.context = context
    }
    
    /// Resolve category by ID or name
    func resolve(id: String?, name: String?) -> Category? {
        // Try ID first (most specific)
        if let id = id, let uuid = UUID(uuidString: id) {
            return scheduleManager.categories.first { $0.id == uuid }
        }
        
        // Try name with normalization
        if let name = name {
            let normalizedKey = CategoryUtility.normalizedCategoryKey(name)
            return scheduleManager.categories.first { category in
                guard let categoryName = category.name else { return false }
                return CategoryUtility.normalizedCategoryKey(categoryName) == normalizedKey
            }
        }
        
        return nil
    }
    
    /// Find or create category with the given name
    func findOrCreate(name: String, color: String? = nil, icon: String? = nil) -> Category {
        // Check if already exists
        if let existing = resolve(id: nil, name: name) {
            // Update color and icon if provided
            if let color = color {
                existing.colorHex = color
            }
            if let icon = icon {
                existing.iconName = icon
            }
            return existing
        }
        
        // Create new category
        return CategoryUtility.findOrCreateCategory(
            name: name,
            color: color,
            icon: icon,
            context: context
        )
    }
    
    /// Resolve from parameters dictionary
    func resolveFromParameters(_ parameters: [String: Any]) -> Category? {
        let categoryId = parameters["categoryId"] as? String ?? parameters["category_id"] as? String
        let categoryName = parameters["category"] as? String ?? parameters["categoryName"] as? String
        
        return resolve(id: categoryId, name: categoryName)
    }
    
    /// Find or create from parameters dictionary
    func findOrCreateFromParameters(_ parameters: [String: Any]) -> Category? {
        // Try to resolve first
        if let existing = resolveFromParameters(parameters) {
            return existing
        }
        
        // Create if name is provided
        if let categoryName = parameters["category"] as? String ?? parameters["categoryName"] as? String {
            let color = parameters["categoryColor"] as? String ?? parameters["category_color"] as? String
            let icon = parameters["categoryIcon"] as? String ?? parameters["category_icon"] as? String
            return findOrCreate(name: categoryName, color: color, icon: icon)
        }
        
        return nil
    }
}