//
//  MockOpenAIService.swift
//  Momentum
//
//  Created by Momentum on 7/1/25.
//

import Foundation

// Using global AsyncTask typealias to avoid naming conflict with Core Data Task entity

/// Mock OpenAI Service for testing without real API calls
@MainActor
class MockOpenAIService: OpenAIService {
    
    // MARK: - Test Configuration
    
    var shouldSimulateError = false
    var simulatedErrorType: OpenAIError = .networkError(NSError(domain: "Test", code: -1, userInfo: nil))
    var simulatedDelay: TimeInterval = 0.5
    var shouldSimulateRateLimit = false
    var shouldSimulateFunctionCall = false
    var simulatedFunctionName = "create_event"
    
    // MARK: - Overrides
    
    override func sendChatRequest(
        messages: [ChatRequestMessage],
        model: String = "gpt-4",
        temperature: Double = 0.7,
        maxTokens: Int = 500,
        stream: Bool = false,
        userContext: UserContext? = nil,
        tools: [[String: Any]]? = nil
    ) async throws -> ChatResponse {
        // Simulate network delay
        try await _Concurrency.Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        
        // Simulate errors if configured
        if shouldSimulateError {
            throw simulatedErrorType
        }
        
        if shouldSimulateRateLimit {
            throw OpenAIError.rateLimitExceeded(retryAfter: 60, limit: 10)
        }
        
        // Generate mock response based on last user message
        let lastMessageContent = messages.last { $0.role == "user" }?.content
        let lastMessageText: String
        switch lastMessageContent {
        case .text(let text):
            lastMessageText = text
        case .array(let array):
            // Extract text from array content (for image messages)
            lastMessageText = array.compactMap { dict in
                if let type = dict["type"] as? String, type == "text",
                   let text = dict["text"] as? String {
                    return text
                }
                return nil
            }.first ?? "Image uploaded"
        case .none:
            lastMessageText = ""
        }
        let mockContent = generateMockResponse(for: lastMessageText)
        
        // Create mock response
        let response = ChatResponse(
            id: UUID().uuidString,
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: model,
            choices: [
                ChatResponse.Choice(
                    index: 0,
                    message: ChatResponse.Message(
                        role: "assistant",
                        content: shouldSimulateFunctionCall ? nil : mockContent,
                        functionCall: shouldSimulateFunctionCall ? generateMockFunctionCall() : nil
                    ),
                    finishReason: "stop"
                )
            ],
            usage: ChatResponse.Usage(
                promptTokens: 50,
                completionTokens: 100,
                totalTokens: 150
            ),
            metadata: ChatResponse.ResponseMetadata(
                requestId: UUID().uuidString,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                model: model
            )
        )
        
        // Update rate limit info
        rateLimitInfo = RateLimitInfo(
            limit: 100,
            remaining: shouldSimulateRateLimit ? 0 : 95,
            resetTime: Date().addingTimeInterval(3600)
        )
        
        return response
    }
    
    override func streamChatRequest(
        messages: [ChatRequestMessage],
        model: String = "gpt-4",
        temperature: Double = 0.7,
        maxTokens: Int = 500,
        userContext: UserContext? = nil,
        tools: [[String: Any]]? = nil
    ) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            AsyncTask {
                do {
                    // Simulate initial delay
                    try await _Concurrency.Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
                    
                    if shouldSimulateError {
                        throw simulatedErrorType
                    }
                    
                    let lastMessageContent = messages.last { $0.role == "user" }?.content
                    let lastMessageText: String
                    switch lastMessageContent {
                    case .text(let text):
                        lastMessageText = text
                    case .array(let array):
                        // Extract text from array content (for image messages)
                        lastMessageText = array.compactMap { dict in
                            if let type = dict["type"] as? String, type == "text",
                               let text = dict["text"] as? String {
                                return text
                            }
                            return nil
                        }.first ?? "Image uploaded"
                    case .none:
                        lastMessageText = ""
                    }
                    let fullResponse = generateMockResponse(for: lastMessageText)
                    let words = fullResponse.split(separator: " ")
                    
                    // Stream words one by one
                    for (index, word) in words.enumerated() {
                        let content = index == 0 ? String(word) : " " + String(word)
                        
                        let streamData = ChatStreamData(
                            id: UUID().uuidString,
                            object: "chat.completion.chunk",
                            created: Int(Date().timeIntervalSince1970),
                            model: model,
                            choices: [
                                ChatStreamData.StreamChoice(
                                    index: 0,
                                    delta: ChatStreamData.StreamDelta(
                                        role: index == 0 ? "assistant" : nil,
                                        content: content,
                                        functionCall: nil
                                    ),
                                    finishReason: nil
                                )
                            ]
                        )
                        
                        continuation.yield(.data(streamData))
                        
                        // Small delay between words
                        try await _Concurrency.Task.sleep(nanoseconds: 50_000_000) // 50ms
                    }
                    
                    continuation.yield(.done)
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Mock Response Generation
    
    private func generateMockResponse(for message: String) -> String {
        let lowercased = message.lowercased()
        
        if lowercased.contains("schedule") || lowercased.contains("calendar") {
            return "I can see you have a busy day ahead! You have 3 meetings scheduled and 2 deep work blocks. Would you like me to help optimize your schedule or find time for a specific task?"
        } else if lowercased.contains("create") || lowercased.contains("add") {
            return "I'll help you create a new event. What would you like to schedule? Please provide the title, time, and any other details you'd like to include."
        } else if lowercased.contains("productivity") || lowercased.contains("focus") {
            return "Based on your past patterns, you're most productive between 9-11 AM. I recommend scheduling your most important tasks during this time. Would you like me to block this time for deep work?"
        } else if lowercased.contains("time") || lowercased.contains("manage") {
            return "Time management is about prioritizing what matters most. I notice you have some gaps in your schedule that could be used for focused work. Shall I suggest an optimized schedule for today?"
        } else {
            return "I'm here to help you manage your time more effectively. You can ask me to create events, view your schedule, or get productivity insights. What would you like to do?"
        }
    }
    
    private func generateMockFunctionCall() -> ChatResponse.FunctionCall {
        let arguments: String
        
        switch simulatedFunctionName {
        case "create_event":
            arguments = """
            {
                "title": "Deep Work Session",
                "start_time": "2025-07-01T09:00:00Z",
                "end_time": "2025-07-01T11:00:00Z",
                "category": "Work",
                "notes": "Focus on the quarterly report"
            }
            """
        case "list_events":
            arguments = """
            {
                "date": "2025-07-01",
                "limit": 10
            }
            """
        default:
            arguments = "{}"
        }
        
        return ChatResponse.FunctionCall(
            name: simulatedFunctionName,
            arguments: arguments
        )
    }
}