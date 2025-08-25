import Foundation
import SwiftUI
import Combine

/// Manages core chat conversation functionality, messages, and persistence
@MainActor
class ChatConversationViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isTypingIndicatorVisible: Bool = false
    @Published var isLoading: Bool = false
    
    // MARK: - Private Properties
    
    private let messagesKey = "chat_messages"
    private let maxStoredMessages = 100
    private var conversationHistory: [ChatRequestMessage] = []
    private let userName: String
    
    // MARK: - Mathematical Constants
    
    private let φ: Double = 1.618033988749895 // Golden ratio for conversation flow
    
    // MARK: - Initialization
    
    init(userName: String? = nil) {
        self.userName = userName ?? UserDefaults.standard.string(forKey: "userDisplayName") ?? "User"
        loadMessages()
        
        // Add initial greeting if no messages
        if messages.isEmpty {
            addInitialGreeting()
        }
    }
    
    // MARK: - Message Management
    
    func addMessage(_ message: ChatMessage) {
        messages.append(message)
        saveMessages()
        
        // Update conversation history
        updateConversationHistory(with: message)
    }
    
    func addUserMessage(_ content: String, attachmentInfo: String? = nil) -> ChatMessage {
        var fullContent = content
        if let attachmentInfo = attachmentInfo {
            fullContent = "\(content)\n\n[Attachment: \(attachmentInfo)]"
        }
        
        let message = ChatMessage(
            content: fullContent,
            sender: .user(name: userName),
            timestamp: Date()
        )
        
        addMessage(message)
        return message
    }
    
    func addAssistantMessage(_ content: String, functionCall: FunctionCallResult? = nil) -> ChatMessage {
        let message = ChatMessage(
            content: content,
            sender: .assistant,
            timestamp: Date(),
            functionCall: functionCall
        )
        
        addMessage(message)
        return message
    }
    
    func addSystemMessage(_ content: String) -> ChatMessage {
        let message = ChatMessage(
            content: content,
            sender: .assistant,
            timestamp: Date()
        )
        
        addMessage(message)
        return message
    }
    
    func updateMessage(id: UUID, content: String) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].content = content
            saveMessages()
        }
    }
    
    func deleteMessage(id: UUID) {
        messages.removeAll { $0.id == id }
        saveMessages()
    }
    
    func clearConversation() {
        messages.removeAll()
        conversationHistory.removeAll()
        saveMessages()
        addInitialGreeting()
    }
    
    // MARK: - Typing Indicator
    
    func showTypingIndicator() {
        isTypingIndicatorVisible = true
    }
    
    func hideTypingIndicator() {
        isTypingIndicatorVisible = false
    }
    
    // MARK: - Conversation History
    
    func getConversationHistory(maxTokens: Int = 4000) -> [ChatRequestMessage] {
        var history: [ChatRequestMessage] = []
        var approximateTokens = 0
        
        // Add recent messages in reverse order
        for message in messages.reversed() {
            let role = message.sender.isUser ? "user" : "assistant"
            let requestMessage = ChatRequestMessage(
                role: role,
                content: message.content
            )
            
            // Rough token estimation (4 chars ≈ 1 token)
            let messageTokens = message.content.count / 4
            
            if approximateTokens + messageTokens > maxTokens {
                break
            }
            
            history.insert(requestMessage, at: 0)
            approximateTokens += messageTokens
        }
        
        return history
    }
    
    private func updateConversationHistory(with message: ChatMessage) {
        let role = message.sender.isUser ? "user" : "assistant"
        let requestMessage = ChatRequestMessage(
            role: role,
            content: message.content
        )
        
        conversationHistory.append(requestMessage)
        
        // Keep conversation history manageable
        if conversationHistory.count > 50 {
            conversationHistory.removeFirst(10)
        }
    }
    
    // MARK: - Persistence
    
    private func saveMessages() {
        // For now, skip persistence since ChatMessage isn't Codable
        // This can be implemented later with proper serialization
    }
    
    private func loadMessages() {
        // For now, skip loading since ChatMessage isn't Codable
        // This can be implemented later with proper deserialization
    }
    
    // MARK: - Initial Greeting
    
    private func addInitialGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        
        switch hour {
        case 0..<12:
            greeting = "Good morning"
        case 12..<17:
            greeting = "Good afternoon"
        case 17..<22:
            greeting = "Good evening"
        default:
            greeting = "Hello"
        }
        
        let initialMessage = """
        \(greeting), \(userName)! 👋
        
        I'm your AI assistant for Momentum. I can help you:
        • 📅 Manage your events and schedule
        • ✅ Create and track tasks
        • 🎯 Set and monitor goals
        • 💪 Build and maintain habits
        • 📊 Analyze your productivity
        
        How can I assist you today?
        """
        
        _ = addAssistantMessage(initialMessage)
    }
    
    // MARK: - Helper Methods
    
    func getLastUserMessage() -> ChatMessage? {
        messages.last { $0.sender.isUser }
    }
    
    func getLastAssistantMessage() -> ChatMessage? {
        messages.last { !$0.sender.isUser }
    }
    
    func countMessages(byUser isUser: Bool) -> Int {
        messages.filter { $0.sender.isUser == isUser }.count
    }
    
    func getMessagesSince(_ date: Date) -> [ChatMessage] {
        messages.filter { $0.timestamp > date }
    }
    
    func exportConversation() -> String {
        var export = "Momentum Chat Export\n"
        export += "Date: \(Date())\n"
        export += "User: \(userName)\n"
        export += String(repeating: "=", count: 50) + "\n\n"
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        for message in messages {
            export += "[\(formatter.string(from: message.timestamp))] "
            export += "\(message.sender.displayName): "
            export += "\(message.content)\n\n"
        }
        
        return export
    }
}

// MARK: - Supporting Types
// Note: ChatMessage and related types are defined in Models/ChatMessage.swift
// ChatRequestMessage is defined in OpenAIService.swift