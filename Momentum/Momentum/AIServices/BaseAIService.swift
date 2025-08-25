//
//  BaseAIService.swift
//  Momentum
//
//  Base class for AI services with common CRUD functionality
//

import Foundation
import CoreData

/// Base class providing common CRUD operations for AI services
class BaseAIService<Entity: NSManagedObject>: CRUDServiceProtocol, BulkOperationsProtocol {
    typealias EntityType = Entity
    
    // MARK: - Properties
    
    let serviceName: String
    let context: NSManagedObjectContext
    private let logger = AILogger.shared
    
    // MARK: - Initialization
    
    init(serviceName: String, context: NSManagedObjectContext) {
        self.serviceName = serviceName
        self.context = context
    }
    
    // MARK: - AIServiceProtocol
    
    func process(action: String, parameters: [String: Any]) async -> AIResult {
        logger.log("[\(serviceName)] Processing action: \(action)", level: .debug)
        
        // Validate first
        let validation = validate(action: action, parameters: parameters)
        guard validation.success else {
            return validation
        }
        
        // Route to appropriate method
        switch action.lowercased() {
        case "create", "add", "new":
            if let items = parameters["items"] as? [[String: Any]] {
                return await createMultiple(items: items)
            }
            return await create(parameters: parameters)
            
        case "update", "edit", "modify":
            let id = parameters["id"] as? String
            if let ids = parameters["ids"] as? [String],
               let updates = parameters["updates"] as? [String: Any] {
                return await updateMultiple(ids: ids, updates: updates)
            }
            return await update(id: id, parameters: parameters)
            
        case "delete", "remove":
            let id = parameters["id"] as? String
            if let ids = parameters["ids"] as? [String] {
                return await deleteMultiple(ids: ids)
            }
            return await delete(id: id, parameters: parameters)
            
        case "list", "get", "fetch":
            return await list(parameters: parameters)
            
        case "search", "find":
            let query = parameters["query"] as? String ?? ""
            return await search(query: query, parameters: parameters)
            
        default:
            return AIResult.failure("Unknown action: \(action) for \(serviceName)")
        }
    }
    
    func validate(action: String, parameters: [String: Any]) -> AIResult {
        // Basic validation - override in subclasses for specific validation
        switch action.lowercased() {
        case "update", "delete":
            if parameters["id"] == nil && parameters["ids"] == nil {
                return AIResult.failure("Missing required parameter: id or ids")
            }
        case "search":
            if parameters["query"] == nil {
                return AIResult.failure("Missing required parameter: query")
            }
        default:
            break
        }
        
        return AIResult.success("Validation passed")
    }
    
    // MARK: - CRUDServiceProtocol
    
    func create(parameters: [String: Any]) async -> AIResult {
        // Override in subclasses
        return AIResult.failure("Create not implemented for \(serviceName)")
    }
    
    func update(id: String?, parameters: [String: Any]) async -> AIResult {
        guard let id = id, UUID(uuidString: id) != nil else {
            return AIResult.failure("Invalid or missing ID")
        }
        
        // Override in subclasses for specific update logic
        return AIResult.failure("Update not implemented for \(serviceName)")
    }
    
    func delete(id: String?, parameters: [String: Any]) async -> AIResult {
        guard let id = id, let uuid = UUID(uuidString: id) else {
            return AIResult.failure("Invalid or missing ID")
        }
        
        do {
            let request = Entity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            
            if let entities = try context.fetch(request) as? [Entity],
               let entity = entities.first {
                context.delete(entity)
                try context.save()
                
                logger.log("[\(serviceName)] Deleted entity with ID: \(id)", level: .info)
                return AIResult.success("Successfully deleted item")
            }
            
            return AIResult.failure("Item not found with ID: \(id)")
        } catch {
            logger.log("[\(serviceName)] Delete error: \(error)", level: .error)
            return AIResult.failure("Failed to delete: \(error.localizedDescription)", error: error)
        }
    }
    
    func list(parameters: [String: Any]) async -> AIResult {
        do {
            let request = Entity.fetchRequest()
            
            // Apply filters if provided
            if let filter = buildPredicate(from: parameters) {
                request.predicate = filter
            }
            
            // Apply sorting if provided
            if let sortKey = parameters["sortBy"] as? String {
                let ascending = parameters["ascending"] as? Bool ?? true
                request.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: ascending)]
            }
            
            // Apply limit if provided
            if let limit = parameters["limit"] as? Int {
                request.fetchLimit = limit
            }
            
            let entities = try context.fetch(request)
            logger.log("[\(serviceName)] Listed \(entities.count) items", level: .debug)
            
            return AIResult.success("Found \(entities.count) items", data: entities)
        } catch {
            logger.log("[\(serviceName)] List error: \(error)", level: .error)
            return AIResult.failure("Failed to list: \(error.localizedDescription)", error: error)
        }
    }
    
    func search(query: String, parameters: [String: Any]) async -> AIResult {
        // Override in subclasses for specific search logic
        return await list(parameters: parameters.merging(["query": query]) { $1 })
    }
    
    // MARK: - BulkOperationsProtocol
    
    func createMultiple(items: [[String: Any]]) async -> AIResult {
        var created = 0
        var failed = 0
        
        for item in items {
            let result = await create(parameters: item)
            if result.success {
                created += 1
            } else {
                failed += 1
            }
        }
        
        let message = "Created \(created) items" + (failed > 0 ? ", \(failed) failed" : "")
        return created > 0 ? AIResult.success(message) : AIResult.failure(message)
    }
    
    func updateMultiple(ids: [String], updates: [String: Any]) async -> AIResult {
        var updated = 0
        var failed = 0
        
        for id in ids {
            let result = await update(id: id, parameters: updates)
            if result.success {
                updated += 1
            } else {
                failed += 1
            }
        }
        
        let message = "Updated \(updated) items" + (failed > 0 ? ", \(failed) failed" : "")
        return updated > 0 ? AIResult.success(message) : AIResult.failure(message)
    }
    
    func deleteMultiple(ids: [String]) async -> AIResult {
        var deleted = 0
        var failed = 0
        
        for id in ids {
            let result = await delete(id: id, parameters: [:])
            if result.success {
                deleted += 1
            } else {
                failed += 1
            }
        }
        
        let message = "Deleted \(deleted) items" + (failed > 0 ? ", \(failed) failed" : "")
        return deleted > 0 ? AIResult.success(message) : AIResult.failure(message)
    }
    
    func processAll(filter: [String: Any], action: String) async -> AIResult {
        let listResult = await list(parameters: filter)
        guard listResult.success,
              let entities = listResult.data as? [Entity] else {
            return AIResult.failure("Failed to fetch items for bulk operation")
        }
        
        let ids = entities.compactMap { ($0.value(forKey: "id") as? UUID)?.uuidString }
        
        switch action.lowercased() {
        case "delete":
            return await deleteMultiple(ids: ids)
        case "update":
            if let updates = filter["updates"] as? [String: Any] {
                return await updateMultiple(ids: ids, updates: updates)
            }
            return AIResult.failure("Missing updates for bulk update")
        default:
            return AIResult.failure("Unsupported bulk action: \(action)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Build NSPredicate from filter parameters
    private func buildPredicate(from parameters: [String: Any]) -> NSPredicate? {
        let predicates: [NSPredicate] = []
        
        // Add common filters here
        // Override in subclasses for entity-specific filters
        
        return predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}