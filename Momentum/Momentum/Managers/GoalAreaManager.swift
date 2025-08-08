//
//  GoalAreaManager.swift
//  Momentum
//
//  Manages goal areas/categories
//

import Foundation
import CoreData
import SwiftUI

@MainActor
class GoalAreaManager: ObservableObject {
    static let shared = GoalAreaManager()
    
    @Published var categories: [Category] = []
    
    private let persistenceController = PersistenceController.shared
    private let context: NSManagedObjectContext
    
    // Default goal areas with their icons and colors
    private let defaultAreas = [
        ("Career", "briefcase.fill", "#96CEB4"),
        ("Finance", "dollarsign.circle.fill", "#45B7D1"),
        ("Health", "heart.fill", "#FF6B6B"),
        ("Fitness", "figure.run", "#4ECDC4"),
        ("Education", "graduationcap.fill", "#FECA57"),
        ("Social", "person.2.fill", "#FF9FF3"),
        ("Personal Growth", "star.fill", "#54A0FF"),
        ("Creative", "paintbrush.fill", "#FD79A8"),
        ("Family", "house.fill", "#FFB142"),
        ("Travel", "airplane", "#00D2D3"),
        ("Spiritual", "sparkles", "#A29BFE"),
        ("Hobby", "gamecontroller.fill", "#7B68EE")
    ]
    
    private init() {
        self.context = persistenceController.container.viewContext
        loadCategories()
        setupDefaultCategoriesIfNeeded()
    }
    
    func loadCategories() {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.sortOrder, ascending: true)]
        
        do {
            categories = try context.fetch(request)
        } catch {
            print("Error loading categories: \(error)")
        }
    }
    
    private func setupDefaultCategoriesIfNeeded() {
        // Check if we already have categories
        if !categories.isEmpty {
            // Check if any categories have the default folder icon (indicating they weren't set up properly)
            let needsReset = categories.contains { category in
                category.iconName == "folder.fill" || category.iconName == nil
            }
            
            if needsReset {
                resetCategoriesToDefaults()
            }
            return
        }
        
        // Create default categories
        for (index, (name, icon, color)) in defaultAreas.enumerated() {
            createCategory(
                name: name,
                iconName: icon,
                colorHex: color,
                sortOrder: Int32(index),
                isDefault: true
            )
        }
    }
    
    private func resetCategoriesToDefaults() {
        // Delete all existing categories
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        do {
            let existingCategories = try context.fetch(request)
            for category in existingCategories {
                context.delete(category)
            }
            try context.save()
            
            // Recreate default categories
            for (index, (name, icon, color)) in defaultAreas.enumerated() {
                createCategory(
                    name: name,
                    iconName: icon,
                    colorHex: color,
                    sortOrder: Int32(index),
                    isDefault: true
                )
            }
        } catch {
            print("Error resetting categories: \(error)")
        }
    }
    
    func createCategory(
        name: String,
        iconName: String = "folder.fill",
        colorHex: String = "#007AFF",
        sortOrder: Int32? = nil,
        isDefault: Bool = false
    ) {
        let category = Category(context: context)
        category.id = UUID()
        category.name = name
        category.iconName = iconName
        category.colorHex = colorHex
        category.createdAt = Date()
        category.isActive = true
        category.isDefault = isDefault
        category.sortOrder = sortOrder ?? Int32(categories.count)
        
        do {
            try context.save()
            loadCategories()
        } catch {
            print("Error creating category: \(error)")
        }
    }
    
    func updateCategory(
        _ category: Category,
        name: String? = nil,
        iconName: String? = nil,
        colorHex: String? = nil
    ) {
        if let name = name {
            category.name = name
        }
        if let iconName = iconName {
            category.iconName = iconName
        }
        if let colorHex = colorHex {
            category.colorHex = colorHex
        }
        
        do {
            try context.save()
            loadCategories()
        } catch {
            print("Error updating category: \(error)")
        }
    }
    
    func deleteCategory(_ category: Category) {
        // Don't delete default categories
        if category.isDefault {
            return
        }
        
        context.delete(category)
        
        do {
            try context.save()
            loadCategories()
        } catch {
            print("Error deleting category: \(error)")
        }
    }
    
    func toggleCategoryActive(_ category: Category) {
        category.isActive.toggle()
        
        do {
            try context.save()
            loadCategories()
        } catch {
            print("Error toggling category: \(error)")
        }
    }
}