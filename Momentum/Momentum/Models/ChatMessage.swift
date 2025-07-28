import Foundation
import SwiftUI

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Equatable {
    let id: UUID = UUID()
    var content: String
    let sender: MessageSender
    let timestamp: Date
    var isStreaming: Bool = false
    var functionCall: FunctionCallResult?
    var error: String?
    var eventPreview: EventPreview?
    var multipleEventsPreview: [EventListItem]?
    var bulkActionPreview: BulkActionPreview?
    var attachedImage: UIImage?
    var attachedFileName: String?
    var attachedFileExtension: String?
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.sender == rhs.sender &&
        lhs.timestamp == rhs.timestamp &&
        lhs.isStreaming == rhs.isStreaming &&
        lhs.functionCall == rhs.functionCall &&
        lhs.error == rhs.error &&
        lhs.eventPreview == rhs.eventPreview &&
        lhs.multipleEventsPreview == rhs.multipleEventsPreview &&
        lhs.bulkActionPreview == rhs.bulkActionPreview
        // Note: We don't compare UIImage for performance reasons
    }
    
    enum MessageSender: Equatable {
        case user(name: String)
        case assistant
        
        var displayName: String {
            switch self {
            case .user(let name):
                return name
            case .assistant:
                return "Momentum Assistant"
            }
        }
        
        var isUser: Bool {
            switch self {
            case .user:
                return true
            case .assistant:
                return false
            }
        }
    }
}

// MARK: - Function Call Result
struct FunctionCallResult: Equatable {
    let functionName: String
    let success: Bool
    let message: String
    let details: [String: String]?
    
    var displayName: String {
        switch functionName {
        case "create_event":
            return "Created Event"
        case "update_event":
            return "Updated Event"
        case "delete_event":
            return "Deleted Event"
        case "list_events":
            return "Listed Events"
        case "suggest_schedule":
            return "Schedule Suggestion"
        // Task functions
        case "create_task":
            return "Created Task"
        case "update_task":
            return "Updated Task"
        case "complete_task":
            return "Completed Task"
        case "delete_task":
            return "Deleted Task"
        case "list_tasks":
            return "Listed Tasks"
        case "create_multiple_tasks":
            return "Created Multiple Tasks"
        case "update_multiple_tasks":
            return "Updated Multiple Tasks"
        case "complete_multiple_tasks":
            return "Completed Multiple Tasks"
        case "delete_multiple_tasks":
            return "Deleted Multiple Tasks"
        default:
            return functionName
        }
    }
}

// MARK: - Typing Indicator State

struct TypingIndicator: Identifiable {
    let id: UUID = UUID()
    let sender: ChatMessage.MessageSender
}