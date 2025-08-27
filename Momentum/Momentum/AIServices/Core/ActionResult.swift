//
//  ActionResult.swift
//  Momentum
//
//  Generic typed result for AI Coordinator responses
//

import Foundation

/// Generic result type that can encode to dictionary for backward compatibility
struct ActionResult<Payload: Encodable>: Encodable {
    var success: Bool
    var message: String
    var id: String?
    var items: [Payload]?
    var matchedCount: Int?
    var updatedCount: Int?
    
    init(
        success: Bool,
        message: String,
        id: String? = nil,
        items: [Payload]? = nil,
        matchedCount: Int? = nil,
        updatedCount: Int? = nil
    ) {
        self.success = success
        self.message = message
        self.id = id
        self.items = items
        self.matchedCount = matchedCount
        self.updatedCount = updatedCount
    }
}

// MARK: - Dictionary Conversion
extension ActionResult {
    /// Convert to dictionary for backward compatibility with existing callers
    func toDictionary() -> [String: Any] {
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let data = try encoder.encode(self)
            
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return ["success": success, "message": message]
            }
            
            // Filter out nil values for cleaner output
            return obj.compactMapValues { value in
                if let value = value as? NSNull {
                    return nil
                }
                return value
            }
        } catch {
            // Fallback to basic dictionary if encoding fails
            return ["success": success, "message": message]
        }
    }
}

// MARK: - Empty Payload
/// Empty struct for operations that don't return items
struct EmptyPayload: Encodable {}

// MARK: - Convenience Initializers
extension ActionResult where Payload == EmptyPayload {
    /// Convenience initializer for results without items
    init(success: Bool, message: String, id: String? = nil) {
        self.init(
            success: success,
            message: message,
            id: id,
            items: nil,
            matchedCount: nil,
            updatedCount: nil
        )
    }
}