//
//  CoreDataGateway.swift
//  Momentum
//
//  Thread-safe Core Data operations wrapper
//

import Foundation
import CoreData

/// Thread-safe wrapper for Core Data operations
struct CoreDataGateway {
    let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Synchronous Operations
    
    /// Save context if there are changes
    func save() throws {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            // Log error for debugging
            print("CoreDataGateway save error: \(error)")
            throw CoreDataError.saveFailed(error.localizedDescription)
        }
    }
    
    /// Perform a block on the context's queue and return result
    func perform<T>(_ block: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let result = try block()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Perform a block on the context's queue without return value
    func performVoid(_ block: @escaping () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    try block()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Batch Operations
    
    /// Execute batch delete request
    func batchDelete<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> Int {
        try await perform {
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
            deleteRequest.resultType = .resultTypeCount
            
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            return (result?.result as? Int) ?? 0
        }
    }
    
    /// Execute batch update request
    func batchUpdate<T: NSManagedObject>(
        _ entityType: T.Type,
        predicate: NSPredicate?,
        propertiesToUpdate: [String: Any]
    ) async throws -> Int {
        try await perform {
            let updateRequest = NSBatchUpdateRequest(entityName: String(describing: entityType))
            updateRequest.predicate = predicate
            updateRequest.propertiesToUpdate = propertiesToUpdate
            updateRequest.resultType = .updatedObjectsCountResultType
            
            let result = try context.execute(updateRequest) as? NSBatchUpdateResult
            return (result?.result as? Int) ?? 0
        }
    }
    
    // MARK: - Fetch Operations
    
    /// Fetch objects with request
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> [T] {
        try await perform {
            try context.fetch(request)
        }
    }
    
    /// Count objects with request
    func count<T: NSManagedObject>(for request: NSFetchRequest<T>) async throws -> Int {
        try await perform {
            try context.count(for: request)
        }
    }
}

// MARK: - Core Data Errors
enum CoreDataError: LocalizedError {
    case saveFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
    case updateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "Failed to save: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete: \(message)"
        case .updateFailed(let message):
            return "Failed to update: \(message)"
        }
    }
}