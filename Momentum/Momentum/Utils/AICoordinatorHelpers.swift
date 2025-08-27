//
//  AICoordinatorHelpers.swift
//  Momentum
//
//  Shared utilities for AICoordinator
//

import Foundation
import CoreData

// MARK: - Date Parsing Utilities
class DateParsingUtility {
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    private static let isoNoFracFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    
    private static let dateOnlyISO: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
    
    static func parseDate(_ value: Any?) -> Date? {
        guard let s = value as? String else { return nil }
        
        // Try ISO with fractional seconds
        if let d = isoFormatter.date(from: s) { return d }
        
        // Try ISO without fractional seconds
        if let d = isoNoFracFormatter.date(from: s) { return d }
        
        // Try date-only ISO
        if let d = dateOnlyISO.date(from: s) { return d }
        
        // Try custom format with time
        let df1 = DateFormatter()
        df1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = df1.date(from: s) { return d }
        
        // Try date-only format
        let df2 = DateFormatter()
        df2.dateFormat = "yyyy-MM-dd"
        return df2.date(from: s)
    }
    
    static func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        return isoNoFracFormatter.string(from: date)
    }
    
    static func parseHHmm(_ s: String) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = .current
        return fmt.date(from: s)
    }
}

// MARK: - Category Utilities
class CategoryUtility {
    
    static func normalizedCategoryKey(_ name: String) -> String {
        return name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    static func findOrCreateCategory(name: String, 
                                    color: String? = nil, 
                                    icon: String? = nil,
                                    context: NSManagedObjectContext) -> Category {
        let normalized = normalizedCategoryKey(name)
        
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", name)
        request.fetchLimit = 1
        
        if let existing = (try? context.fetch(request))?.first {
            if let color = color { existing.colorHex = color }
            if let icon = icon { existing.iconName = icon }
            return existing
        }
        
        let category = Category(context: context)
        category.id = UUID()
        category.name = name
        category.colorHex = color ?? "#007AFF"
        category.iconName = icon ?? "folder"
        category.isActive = true
        
        do {
            try context.save()
        } catch {
            print("Category save failed: \(error)")
        }
        return category
    }
}

// MARK: - Streak Calculator
class StreakCalculator {
    
    struct StreakData {
        let currentStreak: Int
        let longestStreak: Int
    }
    
    static func calculateStreak(for habit: Habit) -> StreakData {
        return StreakData(
            currentStreak: Int(habit.currentStreak),
            longestStreak: Int(habit.bestStreak)
        )
    }
    
    static func updateStreak(for habit: Habit) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        
        if let last = habit.lastCompletedDate.map({ cal.startOfDay(for: $0) }) {
            if let days = cal.dateComponents([.day], from: last, to: today).day {
                if days == 0 {
                    // Already completed today; do nothing
                    return
                } else if days == 1 {
                    habit.currentStreak += 1
                } else {
                    habit.currentStreak = 1
                }
            }
        } else {
            habit.currentStreak = 1
        }
        
        habit.lastCompletedDate = Date()
        
        // Update best streak if needed
        if habit.currentStreak > habit.bestStreak {
            habit.bestStreak = habit.currentStreak
        }
    }
}

// MARK: - Numeric Type Consistency
extension Dictionary where Key == String, Value == Any {
    
    func withConsistentTypes() -> [String: Any] {
        var result = self
        
        // Convert Int16 and Int32 to Int
        for (key, value) in self {
            if let int16Value = value as? Int16 {
                result[key] = Int(int16Value)
            } else if let int32Value = value as? Int32 {
                result[key] = Int(int32Value)
            }
        }
        
        return result
    }
}