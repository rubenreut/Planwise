//
//  Validation.swift
//  Momentum
//
//  Validation logic for AI Coordinator operations
//

import Foundation

// MARK: - Validation Errors
enum AIValidationError: LocalizedError {
    case range(String)
    case notFound(String)
    case required(String)
    case confirm(String)
    case invalid(String)
    
    var errorDescription: String? {
        switch self {
        case .range(let message):
            return message
        case .notFound(let message):
            return message
        case .required(let message):
            return message
        case .confirm(let message):
            return message
        case .invalid(let message):
            return message
        }
    }
}

// MARK: - Event Time Validation
struct EventTimeRange {
    static let defaultDuration: TimeInterval = 3600 // 1 hour
    
    let start: Date
    let end: Date
    
    init(startRaw: String?, endRaw: String?, now: Date = Date()) throws {
        // Parse dates using existing utility
        let startDate = DateParsingUtility.parseDate(startRaw) ?? now
        let endDate = DateParsingUtility.parseDate(endRaw) ?? startDate.addingTimeInterval(Self.defaultDuration)
        
        // Validate range
        guard endDate >= startDate else {
            throw AIValidationError.range("endTime must be >= startTime")
        }
        
        self.start = startDate
        self.end = endDate
    }
    
    init(start: Date?, end: Date?, now: Date = Date()) throws {
        let startDate = start ?? now
        let endDate = end ?? startDate.addingTimeInterval(Self.defaultDuration)
        
        guard endDate >= startDate else {
            throw AIValidationError.range("endTime must be >= startTime")
        }
        
        self.start = startDate
        self.end = endDate
    }
}

// MARK: - Bulk Delete Validation
struct BulkDeleteGuard {
    /// Check if bulk delete is properly confirmed
    static func check(parameters: [String: Any], count: Int) throws {
        let deleteAll = parameters["deleteAll"] as? Bool == true
        let confirm = parameters["confirm"] as? Bool == true
        
        guard deleteAll else {
            throw AIValidationError.confirm("deleteAll flag must be explicitly set to true for bulk deletion")
        }
        
        guard confirm else {
            throw AIValidationError.confirm("Confirmation required. Set confirm=true to delete \(count) items")
        }
    }
}

// MARK: - Required Field Validation
struct RequiredField {
    /// Validate that a required field is present and non-empty
    static func validate(_ value: String?, fieldName: String) throws -> String {
        guard let value = value, !value.isEmpty else {
            throw AIValidationError.required("\(fieldName) is required")
        }
        return value
    }
    
    /// Validate that a UUID string is valid
    static func validateUUID(_ value: String?, fieldName: String) throws -> UUID {
        guard let value = value else {
            throw AIValidationError.required("\(fieldName) is required")
        }
        guard let uuid = UUID(uuidString: value) else {
            throw AIValidationError.invalid("Invalid UUID for \(fieldName): \(value)")
        }
        return uuid
    }
}

// MARK: - Numeric Validation
struct NumericValidation {
    /// Validate that a value is within a range
    static func validateRange(_ value: Double, min: Double, max: Double, fieldName: String) throws -> Double {
        guard value >= min && value <= max else {
            throw AIValidationError.range("\(fieldName) must be between \(min) and \(max)")
        }
        return value
    }
    
    /// Validate progress percentage (0.0 to 1.0)
    static func validateProgress(_ value: Double) throws -> Double {
        return try validateRange(value, min: 0.0, max: 1.0, fieldName: "progress")
    }
}