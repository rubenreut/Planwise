//
//  Task+Widget.swift
//  MomentumWidget
//
//  Task extensions for widget functionality
//

import Foundation
import CoreData

extension Task {
    /// Check if task is overdue based on due date
    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return dueDate < Date()
    }
    
    /// Get priority as string for widgets
    var priorityString: String? {
        switch priority {
        case 0:
            return "low"
        case 1:
            return "medium"
        case 2:
            return "high"
        default:
            return "medium"
        }
    }
}