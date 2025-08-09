//
//  ChatViewModelIntegration.swift
//  Momentum
//
//  Integration layer between ChatViewModel and the new AI system
//

import Foundation
import CoreData

extension ChatViewModel {
    
    // MARK: - New Simplified Function Definitions for OpenAI
    
    static func getSimplifiedFunctions() -> [[String: Any]] {
        return [
            [
                "name": "manage_events",
                "description": "Manage events - create, update, delete, list events. Handles single and bulk operations.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "action": [
                            "type": "string",
                            "enum": ["create", "update", "delete", "list", "search"],
                            "description": "The operation to perform"
                        ],
                        "parameters": [
                            "type": "object",
                            "description": "Parameters for the action. For create/update: title, startTime, endTime, location, notes, isAllDay, categoryId, reminderMinutes. For list: date, categoryId. For delete: id or ids array."
                        ]
                    ],
                    "required": ["action", "parameters"]
                ]
            ],
            [
                "name": "manage_tasks",
                "description": "Manage tasks - create, update, delete, list tasks. Handles single and bulk operations.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "action": [
                            "type": "string",
                            "enum": ["create", "update", "delete", "list", "search"],
                            "description": "The operation to perform"
                        ],
                        "parameters": [
                            "type": "object",
                            "description": "Parameters for the action. For create/update: title, description, dueDate, priority, estimatedMinutes, goalId, categoryId, tags, isCompleted. For list: completed, goalId, categoryId, dueDate. For delete: id or ids array."
                        ]
                    ],
                    "required": ["action", "parameters"]
                ]
            ],
            [
                "name": "manage_habits",
                "description": "Manage habits - create, update, delete, list, log completions. Handles single and bulk operations.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "action": [
                            "type": "string",
                            "enum": ["create", "update", "delete", "list", "log", "complete"],
                            "description": "The operation to perform"
                        ],
                        "parameters": [
                            "type": "object",
                            "description": "Parameters for the action. For create/update: name, description, frequency, targetCount, reminderTime, categoryId, color, icon, isActive. For list: active, frequency, categoryId. For log/complete: id (habit ID). For delete: id or ids array."
                        ]
                    ],
                    "required": ["action", "parameters"]
                ]
            ],
            [
                "name": "manage_goals",
                "description": "Manage goals and milestones - create, update, delete, list goals and their milestones. Handles single and bulk operations.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "action": [
                            "type": "string",
                            "enum": ["create", "update", "delete", "list", "create_milestone", "update_milestone", "delete_milestone"],
                            "description": "The operation to perform"
                        ],
                        "parameters": [
                            "type": "object",
                            "description": "Parameters for the action. For goals: title, description, targetDate, priority, categoryId, unit, targetValue, milestones (array). For milestones: goalId (for create), id/milestoneId (for update/delete), title, description, dueDate. For delete: id or ids array."
                        ]
                    ],
                    "required": ["action", "parameters"]
                ]
            ],
            [
                "name": "manage_categories",
                "description": "Manage categories - create, update, delete, list categories for organizing items.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "action": [
                            "type": "string",
                            "enum": ["create", "update", "delete", "list"],
                            "description": "The operation to perform"
                        ],
                        "parameters": [
                            "type": "object",
                            "description": "Parameters for the action. For create/update: name, color, icon. For delete: id. For list: no parameters needed."
                        ]
                    ],
                    "required": ["action", "parameters"]
                ]
            ]
        ]
    }
    
    // MARK: - Route Functions to New System
    
    func routeToNewSystem(functionName: String, parameters: [String: Any]) async -> String {
        guard let aiCoordinator = self.aiCoordinator else {
            return "Error: AI Coordinator not initialized"
        }
        
        let action = parameters["action"] as? String ?? "unknown"
        let params = parameters["parameters"] as? [String: Any] ?? [:]
        
        let result: [String: Any]
        
        switch functionName {
        case "manage_events":
            result = await aiCoordinator.manage_events(action: action, parameters: params)
        case "manage_tasks":
            result = await aiCoordinator.manage_tasks(action: action, parameters: params)
        case "manage_habits":
            result = await aiCoordinator.manage_habits(action: action, parameters: params)
        case "manage_goals":
            result = await aiCoordinator.manage_goals(action: action, parameters: params)
        case "manage_categories":
            result = await aiCoordinator.manage_categories(action: action, parameters: params)
        default:
            result = ["success": false, "message": "Unknown function: \(functionName)"]
        }
        
        let success = result["success"] as? Bool ?? false
        let message = result["message"] as? String ?? "Operation completed"
        
        return success ? "✅ \(message)" : "❌ \(message)"
    }
    
    // MARK: - Initialize AI Coordinator
    
    private var aiCoordinator: AICoordinator? {
        guard let eventManager = self.eventManager,
              let taskManager = self.taskManager,
              let goalManager = self.goalManager else {
            return nil
        }
        
        return AICoordinator(
            context: PersistenceController.shared.container.viewContext,
            eventManager: eventManager,
            taskManager: taskManager,
            goalManager: goalManager
        )
    }
}