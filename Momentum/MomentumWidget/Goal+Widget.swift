//
//  Goal+Widget.swift
//  MomentumWidget
//
//  Goal extensions for widget functionality
//

import Foundation
import CoreData

extension Goal {
    /// Returns the type as a string for display
    var typeString: String {
        guard let typeValue = self.type else { return "milestone" }
        
        // Map the Core Data integer to string
        switch Int16(typeValue) {
        case 0: return "milestone"
        case 1: return "numeric"
        case 2: return "habit"
        case 3: return "project"
        default: return "milestone"
        }
    }
    
    /// Returns the priority as a string for display
    var priorityString: String {
        // Map the Core Data integer to string
        switch self.priority {
        case 0: return "low"
        case 1: return "medium"
        case 2: return "high"
        default: return "medium"
        }
    }
    
    /// Calculates and returns the progress percentage (0.0 to 1.0)
    var progressPercentage: Double {
        // New unified progress calculation - average of all active components
        var progressComponents: [Double] = []
        
        // Component 1: Milestone progress (if has milestones)
        if let milestones = self.milestones?.allObjects as? [GoalMilestone], !milestones.isEmpty {
            let completedCount = milestones.filter { $0.isCompleted }.count
            let milestoneProgress = Double(completedCount) / Double(milestones.count)
            progressComponents.append(milestoneProgress)
        }
        
        // Component 2: Numeric progress (if has target value)
        if self.targetValue > 0 {
            let numericProgress = min(1.0, self.currentValue / self.targetValue)
            progressComponents.append(numericProgress)
        }
        
        // Component 3: Habit progress (if has linked habits)
        if let habits = self.linkedHabits?.allObjects as? [Habit], !habits.isEmpty {
            // Count total completions across all linked habits
            let totalCompletions = habits.reduce(0) { sum, habit in
                let entries = habit.entries?.allObjects as? [HabitEntry] ?? []
                return sum + entries.count
            }
            
            // Calculate habit progress
            let habitProgress: Double
            if self.targetValue > 0 && (self.type == "habit" || self.type == "2") {
                // Legacy: if it was specifically a habit type goal with target
                habitProgress = min(1.0, Double(totalCompletions) / self.targetValue)
            } else {
                // Calculate based on consistency - average completion rate
                let daysSinceStart = Calendar.current.dateComponents([.day], 
                    from: self.startDate ?? Date(), to: Date()).day ?? 1
                let avgCompletionRate = habits.reduce(0.0) { sum, habit in
                    let entries = habit.entries?.allObjects as? [HabitEntry] ?? []
                    let rate = min(Double(entries.count) / Double(max(daysSinceStart, 1)), 1.0)
                    return sum + rate
                } / Double(habits.count)
                habitProgress = avgCompletionRate
            }
            progressComponents.append(habitProgress)
        }
        
        // Return average of all active components
        guard !progressComponents.isEmpty else { return 0.0 }
        return progressComponents.reduce(0, +) / Double(progressComponents.count)
    }
}

// MARK: - Goal Type Enum Support
extension Goal {
    /// Check if goal is of milestone type
    var isMilestoneType: Bool {
        guard let typeValue = self.type else { return true }
        return typeValue == "milestone" || Int16(typeValue) == 0
    }
    
    /// Check if goal is of numeric type
    var isNumericType: Bool {
        guard let typeValue = self.type else { return false }
        return typeValue == "numeric" || Int16(typeValue) == 1
    }
    
    /// Check if goal is of habit type
    var isHabitType: Bool {
        guard let typeValue = self.type else { return false }
        return typeValue == "habit" || Int16(typeValue) == 2
    }
    
    /// Check if goal is of project type
    var isProjectType: Bool {
        guard let typeValue = self.type else { return false }
        return typeValue == "project" || Int16(typeValue) == 3
    }
}