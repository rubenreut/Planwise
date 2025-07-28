//
//  CoreData+Optimization.swift
//  Momentum
//
//  Core Data performance optimizations
//

import Foundation
import CoreData
import SwiftUI

// Helper functions for NSFetchRequest optimization
struct FetchRequestOptimizer {
    /// Configure fetch request for optimal performance
    static func optimize<T>(_ request: NSFetchRequest<T>) -> NSFetchRequest<T> {
        // Batch size for memory efficiency
        request.fetchBatchSize = 20
        
        // Return faults by default
        request.returnsObjectsAsFaults = true
        
        // Include only properties that will be accessed
        request.includesPropertyValues = true
        
        return request
    }
    
    /// Configure for counting without loading objects
    static func configureForCounting<T>(_ request: NSFetchRequest<T>) -> NSFetchRequest<T> {
        request.includesPropertyValues = false
        request.includesSubentities = false
        request.returnsObjectsAsFaults = true
        return request
    }
    
    /// Configure for lightweight fetch (IDs only)
    static func configureAsLightweight<T>(_ request: NSFetchRequest<T>) -> NSFetchRequest<T> {
        request.resultType = .managedObjectIDResultType
        return request
    }
}

// Batch operations extension
extension NSManagedObjectContext {
    /// Perform batch update with proper error handling
    func batchUpdate(
        entityName: String,
        predicate: NSPredicate? = nil,
        propertiesToUpdate: [String: Any]
    ) throws -> Int {
        let batchUpdate = NSBatchUpdateRequest(entityName: entityName)
        batchUpdate.predicate = predicate
        batchUpdate.propertiesToUpdate = propertiesToUpdate
        batchUpdate.resultType = .updatedObjectsCountResultType
        
        let result = try self.execute(batchUpdate) as? NSBatchUpdateResult
        return result?.result as? Int ?? 0
    }
    
    /// Perform batch delete with proper error handling
    func batchDelete(
        entityName: String,
        predicate: NSPredicate? = nil
    ) throws -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        fetchRequest.predicate = predicate
        
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDelete.resultType = .resultTypeCount
        
        let result = try self.execute(batchDelete) as? NSBatchDeleteResult
        return result?.result as? Int ?? 0
    }
}

// Efficient fetch request builder
struct OptimizedFetchRequest<T: NSManagedObject> {
    let request: NSFetchRequest<T>
    
    init(entityName: String) {
        self.request = NSFetchRequest<T>(entityName: entityName)
        self.request.fetchBatchSize = 20
    }
    
    func filtered(by predicate: NSPredicate) -> Self {
        request.predicate = predicate
        return self
    }
    
    func sorted(by descriptors: [NSSortDescriptor]) -> Self {
        request.sortDescriptors = descriptors
        return self
    }
    
    func limited(to limit: Int) -> Self {
        request.fetchLimit = limit
        return self
    }
    
    func including(properties: [String]) -> Self {
        request.propertiesToFetch = properties
        return self
    }
    
    func prefetching(relationships: [String]) -> Self {
        request.relationshipKeyPathsForPrefetching = relationships
        return self
    }
    
    func build() -> NSFetchRequest<T> {
        return request
    }
}

// Helper methods for creating optimized fetch requests
// Note: We cannot extend NSFetchRequest with generic constraints due to Objective-C limitations

// Convenience functions for common entity fetch requests
struct EventFetchRequests {
    static func todaysFetchRequest() -> NSFetchRequest<Event> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Event.startTime, ascending: true)]
        request.relationshipKeyPathsForPrefetching = ["category"]
        request.fetchBatchSize = 20
        
        return request
    }
}

struct TaskFetchRequests {
    static func activeFetchRequest() -> NSFetchRequest<Task> {
        let request: NSFetchRequest<Task> = Task.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == %@", NSNumber(value: false))
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Task.priority, ascending: false),
            NSSortDescriptor(keyPath: \Task.dueDate, ascending: true)
        ]
        request.relationshipKeyPathsForPrefetching = ["category", "subtasks"]
        request.fetchBatchSize = 20
        
        return request
    }
}

struct HabitFetchRequests {
    static func activeFetchRequest() -> NSFetchRequest<Habit> {
        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
        request.predicate = NSPredicate(format: "isPaused == %@", NSNumber(value: false))
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Habit.name, ascending: true)]
        request.relationshipKeyPathsForPrefetching = ["entries"]
        request.fetchBatchSize = 20
        
        return request
    }
}

// Usage example
/*
struct OptimizedTaskListView: View {
    @FetchRequest(fetchRequest: TaskFetchRequests.activeFetchRequest()) 
    private var tasks: FetchedResults<Task>
    
    var body: some View {
        List(tasks) { task in
            TaskRow(task: task)
        }
    }
}
*/