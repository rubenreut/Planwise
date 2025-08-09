//
//  AIServiceProtocol.swift
//  Momentum
//
//  Protocol for all AI services to implement
//

import Foundation

/// Result type for AI function calls
struct AIResult {
    let success: Bool
    let message: String
    let data: Any?
    let error: Error?
    
    static func success(_ message: String, data: Any? = nil) -> AIResult {
        AIResult(success: true, message: message, data: data, error: nil)
    }
    
    static func failure(_ message: String, error: Error? = nil) -> AIResult {
        AIResult(success: false, message: message, data: nil, error: error)
    }
}

/// Base protocol for all AI services
protocol AIServiceProtocol {
    associatedtype EntityType
    
    /// Service name for logging
    var serviceName: String { get }
    
    /// Process a function call with given parameters
    func process(action: String, parameters: [String: Any]) async -> AIResult
    
    /// Validate parameters for an action
    func validate(action: String, parameters: [String: Any]) -> AIResult
}

/// Protocol for services that support CRUD operations
protocol CRUDServiceProtocol: AIServiceProtocol {
    /// Create one or more entities
    func create(parameters: [String: Any]) async -> AIResult
    
    /// Update one or more entities
    func update(id: String?, parameters: [String: Any]) async -> AIResult
    
    /// Delete one or more entities
    func delete(id: String?, parameters: [String: Any]) async -> AIResult
    
    /// List entities with optional filters
    func list(parameters: [String: Any]) async -> AIResult
    
    /// Search entities
    func search(query: String, parameters: [String: Any]) async -> AIResult
}

/// Protocol for services that support bulk operations
protocol BulkOperationsProtocol {
    /// Create multiple entities at once
    func createMultiple(items: [[String: Any]]) async -> AIResult
    
    /// Update multiple entities at once
    func updateMultiple(ids: [String], updates: [String: Any]) async -> AIResult
    
    /// Delete multiple entities at once
    func deleteMultiple(ids: [String]) async -> AIResult
    
    /// Perform operation on all entities matching filter
    func processAll(filter: [String: Any], action: String) async -> AIResult
}