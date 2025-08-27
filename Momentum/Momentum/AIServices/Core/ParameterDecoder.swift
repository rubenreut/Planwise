//
//  ParameterDecoder.swift
//  Momentum
//
//  Converts [String: Any] dictionaries to strongly-typed DTOs
//

import Foundation

enum DecodeError: LocalizedError {
    case invalidJSON
    case decodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid JSON object"
        case .decodingFailed(let message):
            return "Decoding failed: \(message)"
        }
    }
}

struct ParameterDecoder {
    
    /// Decode a dictionary into a Decodable type
    static func decode<T: Decodable>(_ type: T.Type, from dict: [String: Any]) throws -> T {
        guard JSONSerialization.isValidJSONObject(dict) else {
            throw DecodeError.invalidJSON
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: dict, options: [])
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            // Allow missing keys to use default values
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw DecodeError.decodingFailed(error.localizedDescription)
        }
    }
    
    /// Decode an array of dictionaries into an array of Decodable types
    static func decodeArray<T: Decodable>(_ type: T.Type, from any: Any?) throws -> [T] {
        guard let array = any as? [[String: Any]] else {
            // Return empty array if not an array
            return []
        }
        
        guard JSONSerialization.isValidJSONObject(array) else {
            throw DecodeError.invalidJSON
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: array, options: [])
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([T].self, from: data)
        } catch {
            throw DecodeError.decodingFailed(error.localizedDescription)
        }
    }
    
    /// Safely decode optional value
    static func decodeOptional<T: Decodable>(_ type: T.Type, from dict: [String: Any]?) -> T? {
        guard let dict = dict else { return nil }
        return try? decode(type, from: dict)
    }
}