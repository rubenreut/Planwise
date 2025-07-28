//
//  OpenAIService.swift
//  Momentum
//
//  Created by Momentum on 7/1/25.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

// Type alias to avoid naming conflict with Core Data Task entity

// MARK: - Models

/// Represents a message in the chat conversation
struct ChatRequest: Codable {
    let messages: [ChatRequestMessage]
    let model: String
    let temperature: Double?
    let maxTokens: Int?
    let stream: Bool?
    let userContext: UserContext?
    let functionCall: String?
    
    enum CodingKeys: String, CodingKey {
        case messages, model, temperature, stream, userContext
        case maxTokens = "max_tokens"
        case functionCall = "function_call"
    }
}

/// Individual message in the request
struct ChatRequestMessage: Codable {
    let role: String
    let content: MessageContent
    let name: String?  // For function messages
    
    init(role: String, content: String, name: String? = nil) {
        self.role = role
        self.content = .text(content)
        self.name = name
    }
    
    init(role: String, content: [[String: Any]], name: String? = nil) {
        self.role = role
        self.content = .array(content)
        self.name = name
    }
    
    // Convenience initializer for image attachments
    init(role: String, content: String, imageData: Data?) {
        self.role = role
        
        if let imageData = imageData {
            // Create multimodal content with text and image
            let base64String = imageData.base64EncodedString()
            let contentArray: [[String: Any]] = [
                ["type": "text", "text": content],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64String)"]]
            ]
            self.content = .array(contentArray)
        } else {
            self.content = .text(content)
        }
        self.name = nil
    }
    
    // Convenience initializer for file attachments (documents)
    init(role: String, content: String, fileData: Data?, fileName: String?, mimeType: String?) {
        self.role = role
        
        if let fileData = fileData, let fileName = fileName, let mimeType = mimeType {
            // Create multimodal content with text and file reference
            // Note: OpenAI doesn't directly support file uploads in chat, so we'll convert certain files to text
            // For now, we'll just include the file info in the text content
            _ = fileData.base64EncodedString()
            let fileInfo = "\n\n[File Attachment: \(fileName) (\(mimeType))]\n"
            
            // For supported document types, we could potentially extract text content
            // For now, we'll just include file metadata
            self.content = .text(content + fileInfo)
        } else {
            self.content = .text(content)
        }
        self.name = nil
    }
    
    enum MessageContent: Codable {
        case text(String)
        case array([[String: Any]])
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                self = .text(text)
            } else if let array = try? container.decode([[String: AnyCodable]].self) {
                self = .array(array.map { dict in
                    dict.mapValues { $0.value }
                })
            } else {
                throw DecodingError.typeMismatch(MessageContent.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Array"))
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let string):
                try container.encode(string)
            case .array(let array):
                try container.encode(array.map { dict -> [String: AnyCodable] in
                    dict.mapValues { AnyCodable($0) }
                })
            }
        }
    }
}

// Helper for encoding Any values
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unable to encode"))
        }
    }
}

/// User context for better AI responses
struct UserContext: Codable {
    let currentTime: String
    let todaySchedule: [ScheduleItem]
    let pastWeekSchedule: [ScheduleItem]
    let nextWeekSchedule: [ScheduleItem]
    let completionHistory: [CompletionItem]
    let timezone: String
    let timezoneOffset: String
    let personalContext: String?
    let schedulePatterns: SchedulePatterns?
    let goals: [GoalItem]?
    let tasks: [TaskItem]?
    let habits: [HabitItem]?
}

/// Schedule patterns for AI insights
struct SchedulePatterns: Codable {
    let totalEventsLastWeek: Int
    let averageEventsPerDay: Double
    let busiestDayOfWeek: String?
    let mostFrequentCategory: String?
    let averageEventDuration: Double // in minutes
}

/// Schedule item representation
struct ScheduleItem: Codable {
    let id: String
    let title: String
    let startTime: String
    let endTime: String
    let category: String?
    let categoryColor: String?
    let notes: String?
    let isCompleted: Bool
    let location: String?
    let alerts: [String]?
}

/// Completion history item
struct CompletionItem: Codable {
    let eventId: String
    let completedAt: String
    let completionRate: Double
}

/// Goal item for AI context
struct GoalItem: Codable {
    let id: String
    let title: String
    let type: String
    let progress: Double
    let targetValue: Double?
    let currentValue: Double?
    let targetDate: String?
    let isCompleted: Bool
    let priority: String
}

/// Task item for AI context
struct TaskItem: Codable {
    let id: String
    let title: String
    let priority: String
    let dueDate: String?
    let isCompleted: Bool
    let category: String?
    let estimatedDuration: Int?
    let tags: [String]?
}

/// Habit item for AI context
struct HabitItem: Codable {
    let id: String
    let name: String
    let trackingType: String
    let goalTarget: Double?
    let currentStreak: Int
    let isCompletedToday: Bool
    let completionRate: Double
}

/// Response from OpenAI
struct ChatResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?
    let metadata: ResponseMetadata?
    
    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String?
        let functionCall: FunctionCall?
        
        enum CodingKeys: String, CodingKey {
            case role, content
            case functionCall = "function_call"
        }
    }
    
    struct FunctionCall: Codable {
        let name: String
        let arguments: String
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
    
    struct ResponseMetadata: Codable {
        let requestId: String
        let timestamp: String
        let model: String
    }
}

/// Error response structure
struct ErrorResponse: Codable {
    let error: String
    let message: String?
    let requestId: String?
    let retryAfter: Int?
    let limit: Int?
    let remaining: Int?
}

/// Rate limit information
struct RateLimitInfo {
    let limit: Int
    let remaining: Int
    let resetTime: Date
}

// MARK: - OpenAI Service

/// Service for communicating with OpenAI through Cloudflare Worker
@MainActor
class OpenAIService: ObservableObject {
    // MARK: - Properties
    
    private let workerURL = APIConfiguration.workerURL
    private var appSecret: String {
        KeychainService.shared.apiKey ?? APIConfiguration.appSecret
    }
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    @Published var isLoading = false
    @Published var rateLimitInfo: RateLimitInfo?
    @Published var lastError: OpenAIError?
    
    // MARK: - Initialization
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        
        self.session = URLSession(configuration: configuration)
        
        // Configure decoder
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Public Methods
    
    /// Send a chat request to OpenAI
    func sendChatRequest(
        messages: [ChatRequestMessage],
        model: String = APIConfiguration.defaultModel,
        temperature: Double = 0.7,
        maxTokens: Int = 15000,
        stream: Bool = false,
        userContext: UserContext? = nil
    ) async throws -> ChatResponse {
        isLoading = true
        defer { isLoading = false }
        
        // Build request
        let chatRequest = ChatRequest(
            messages: messages,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens,
            stream: stream,
            userContext: userContext,
            functionCall: "auto"
        )
        
        print("🔵 OpenAI Request - Worker URL: \(workerURL)")
        print("🔵 OpenAI Request - App Secret exists: \(!appSecret.isEmpty)")
        
        guard let url = URL(string: workerURL) else {
            print("🔴 Failed to create URL from: \(workerURL)")
            throw OpenAIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appSecret, forHTTPHeaderField: "X-App-Secret")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        
        // Add user ID for rate limiting (using device ID as user ID)
        #if canImport(UIKit)
        if let deviceID = UIDevice.current.identifierForVendor?.uuidString {
            request.setValue(deviceID, forHTTPHeaderField: "X-User-ID")
            request.setValue(deviceID, forHTTPHeaderField: "X-Device-ID")
        }
        #endif
        request.httpBody = try encoder.encode(chatRequest)
        
        do {
            print("🔵 Sending request to OpenAI...")
            let (data, response) = try await session.data(for: request)
            
            // Handle HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                print("🔴 Invalid response - not HTTP")
                throw OpenAIError.invalidResponse
            }
            
            print("🔵 Response status code: \(httpResponse.statusCode)")
            
            // Extract rate limit info from headers
            extractRateLimitInfo(from: httpResponse)
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200:
                let chatResponse = try decoder.decode(ChatResponse.self, from: data)
                return chatResponse
                
            case 401:
                throw OpenAIError.unauthorized
                
            case 429:
                let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
                throw OpenAIError.rateLimitExceeded(
                    retryAfter: errorResponse.retryAfter ?? 60,
                    limit: errorResponse.limit ?? 0
                )
                
            case 400...499:
                let errorResponse = try? decoder.decode(ErrorResponse.self, from: data)
                throw OpenAIError.clientError(
                    message: errorResponse?.message ?? "Client error"
                )
                
            case 500...599:
                let errorResponse = try? decoder.decode(ErrorResponse.self, from: data)
                throw OpenAIError.serverError(
                    message: errorResponse?.message ?? "Server error"
                )
                
            default:
                if let errorString = String(data: data, encoding: .utf8) {
                    // Try to parse error details
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        // Extract the actual error message
                        if let error = errorData["error"] as? String {
                            throw OpenAIError.clientError(message: error)
                        } else if let details = errorData["details"] as? [String: Any],
                                  let errorInfo = details["error"] as? [String: Any],
                                  let message = errorInfo["message"] as? String {
                            throw OpenAIError.clientError(message: message)
                        }
                    }
                }
                throw OpenAIError.unexpectedStatusCode(httpResponse.statusCode)
            }
            
        } catch let error as OpenAIError {
            lastError = error
            throw error
        } catch {
            let openAIError = OpenAIError.networkError(error)
            lastError = openAIError
            throw openAIError
        }
    }
    
    /// Stream a chat request (returns AsyncThrowingStream)
    func streamChatRequest(
        messages: [ChatRequestMessage],
        model: String = APIConfiguration.defaultModel,
        temperature: Double = 0.7,
        maxTokens: Int = 15000,
        userContext: UserContext? = nil
    ) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            AsyncTask {
                do {
                    
                    isLoading = true
                    
                    // Build request
                    let chatRequest = ChatRequest(
                        messages: messages,
                        model: model,
                        temperature: temperature,
                        maxTokens: maxTokens,
                        stream: true,
                        userContext: userContext,
                        functionCall: "auto"
                    )
                    
        
        // Debug log the actual message content being sent
        for (index, message) in messages.enumerated() {
            switch message.content {
            case .text(let text): break
            case .array(let array):
                for (itemIndex, item) in array.enumerated() {
                    if let type = item["type"] as? String {
                        if type == "image_url", 
                           let imageUrl = item["image_url"] as? [String: Any],
                           let url = imageUrl["url"] as? String {
                            let isBase64 = url.hasPrefix("data:image")
                            if isBase64 {
                                let dataSize = url.count
                            }
                        }
                    }
                }
            }
        }
                    
                    guard let url = URL(string: workerURL) else {
            throw OpenAIError.invalidResponse
        }
        var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(appSecret, forHTTPHeaderField: "X-App-Secret")
                    request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
                    
                    
                    // Add user ID for rate limiting (using device ID as user ID)
                    #if canImport(UIKit)
                    if let deviceID = UIDevice.current.identifierForVendor?.uuidString {
                        request.setValue(deviceID, forHTTPHeaderField: "X-User-ID")
                        request.setValue(deviceID, forHTTPHeaderField: "X-Device-ID")
                    }
                    #endif
                    request.httpBody = try encoder.encode(chatRequest)
                    
                    
                    let (bytes, response) = try await session.bytes(for: request)
                    
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw OpenAIError.invalidResponse
                    }
                    
                    
                    // Extract rate limit info
                    extractRateLimitInfo(from: httpResponse)
                    
                    guard httpResponse.statusCode == 200 else {
                        throw OpenAIError.unexpectedStatusCode(httpResponse.statusCode)
                    }
                    
                    var lineCount = 0
                    
                    // Parse SSE stream
                    for try await line in bytes.lines {
                        lineCount += 1
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString == "[DONE]" {
                                continuation.yield(.done)
                                break
                            }
                            
                            if let data = jsonString.data(using: .utf8),
                               let streamData = try? decoder.decode(ChatStreamData.self, from: data) {
                                continuation.yield(.data(streamData))
                            } else {
                            }
                        }
                    }
                    
                    isLoading = false
                    continuation.finish()
                    
                } catch {
                    isLoading = false
                    lastError = error as? OpenAIError ?? .networkError(error)
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func extractRateLimitInfo(from response: HTTPURLResponse) {
        guard let limitStr = response.value(forHTTPHeaderField: "X-RateLimit-Limit"),
              let remainingStr = response.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
              let resetStr = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
              let limit = Int(limitStr),
              let remaining = Int(remainingStr),
              let resetTimestamp = TimeInterval(resetStr) else {
            return
        }
        
        // CloudFlare worker sends timestamp in milliseconds, convert to seconds
        let resetTimeInSeconds = resetTimestamp / 1000.0
        
        rateLimitInfo = RateLimitInfo(
            limit: limit,
            remaining: remaining,
            resetTime: Date(timeIntervalSince1970: resetTimeInSeconds)
        )
    }
}

// MARK: - Error Types

enum OpenAIError: LocalizedError {
    case unauthorized
    case rateLimitExceeded(retryAfter: Int, limit: Int)
    case clientError(message: String)
    case serverError(message: String)
    case networkError(Error)
    case invalidResponse
    case unexpectedStatusCode(Int)
    case missingAPIKey
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Authentication failed. Please check your configuration."
        case .rateLimitExceeded(let retryAfter, _):
            return "Rate limit exceeded. Please try again in \(retryAfter) seconds."
        case .clientError(let message):
            return "Request error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .unexpectedStatusCode(let code):
            return "Unexpected response code: \(code)"
        case .missingAPIKey:
            return "API key not found. Please check your configuration."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .rateLimitExceeded:
            return "You've reached the rate limit. Consider upgrading to premium for higher limits."
        case .networkError:
            return "Check your internet connection and try again."
        default:
            return nil
        }
    }
}

// MARK: - Streaming Types

enum ChatStreamEvent {
    case data(ChatStreamData)
    case done
}

struct ChatStreamData: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [StreamChoice]
    
    struct StreamChoice: Codable {
        let index: Int
        let delta: StreamDelta
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, delta
            case finishReason = "finish_reason"
        }
    }
    
    struct StreamDelta: Codable {
        let role: String?
        let content: String?
        let functionCall: StreamFunctionCall?
        
        enum CodingKeys: String, CodingKey {
            case role, content
            case functionCall = "function_call"
        }
    }
    
    struct StreamFunctionCall: Codable {
        let name: String?
        let arguments: String?
    }
}

// MARK: - Function Call Parsing

extension OpenAIService {
    /// Parse a function call from the AI response
    func parseFunctionCall(from response: ChatResponse) -> ParsedFunction? {
        guard let firstChoice = response.choices.first,
              let functionCall = firstChoice.message.functionCall else {
            return nil
        }
        
        
        do {
            // First try to clean up common JSON issues
            var cleanedArguments = functionCall.arguments
            
            // Remove any trailing commas before closing braces/brackets
            cleanedArguments = cleanedArguments.replacingOccurrences(of: ",\\s*}", with: "}", options: .regularExpression)
            cleanedArguments = cleanedArguments.replacingOccurrences(of: ",\\s*]", with: "]", options: .regularExpression)
            
            // Check if JSON is truncated (common with streaming)
            if !cleanedArguments.hasSuffix("}") && !cleanedArguments.hasSuffix("]") {
                
                // Count opening and closing braces/brackets
                let openBraces = cleanedArguments.filter { $0 == "{" }.count
                let closeBraces = cleanedArguments.filter { $0 == "}" }.count
                let openBrackets = cleanedArguments.filter { $0 == "[" }.count
                let closeBrackets = cleanedArguments.filter { $0 == "]" }.count
                
                // Try to close any unterminated strings first
                if let lastQuoteIndex = cleanedArguments.lastIndex(of: "\"") {
                    let afterQuote = cleanedArguments[cleanedArguments.index(after: lastQuoteIndex)...]
                    if !afterQuote.contains("\"") && !afterQuote.contains("}") && !afterQuote.contains("]") {
                        // Unterminated string, close it
                        cleanedArguments += "\""
                    }
                }
                
                // Add missing closing brackets/braces
                cleanedArguments += String(repeating: "}", count: openBraces - closeBraces)
                cleanedArguments += String(repeating: "]", count: openBrackets - closeBrackets)
                
            }
            
            // Ensure we have valid UTF-8 data
            guard let argumentData = cleanedArguments.data(using: .utf8) else {
                return nil
            }
            
            let arguments = try JSONSerialization.jsonObject(
                with: argumentData,
                options: [.allowFragments]
            ) as? [String: Any] ?? [:]
            
            
            return ParsedFunction(
                name: functionCall.name,
                arguments: arguments
            )
        } catch {
            
            // Try to provide more specific error information
            if let nsError = error as NSError? {
                if let debugDescription = nsError.userInfo[NSDebugDescriptionErrorKey] {
                }
            }
            
            return nil
        }
    }
}

struct ParsedFunction {
    let name: String
    let arguments: [String: Any]
}

// MARK: - Convenience Extensions

extension OpenAIService {
    /// Create user context from current schedule, goals, tasks, and habits
    func createUserContext(from events: [Event], goals: [Goal]? = nil, tasks: [Task]? = nil, habits: [Habit]? = nil) -> UserContext {
        let formatter = ISO8601DateFormatter()
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        // Helper to convert event to schedule item
        let eventToScheduleItem: (Event) -> ScheduleItem = { event in
            ScheduleItem(
                id: event.id?.uuidString ?? "",
                title: event.title ?? "",
                startTime: formatter.string(from: event.startTime ?? Date()),
                endTime: formatter.string(from: event.endTime ?? Date()),
                category: event.category?.name,
                categoryColor: event.category?.colorHex,
                notes: event.notes,
                isCompleted: event.isCompleted,
                location: event.location,
                alerts: nil // TODO: Add alerts when available in Event model
            )
        }
        
        // Separate events into past, today, and future
        var todayEvents: [Event] = []
        var pastWeekEvents: [Event] = []
        var nextWeekEvents: [Event] = []
        
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday)!
        let sevenDaysFromNow = calendar.date(byAdding: .day, value: 7, to: startOfToday)!
        
        for event in events {
            guard let startTime = event.startTime else { continue }
            
            if calendar.isDate(startTime, inSameDayAs: now) {
                todayEvents.append(event)
            } else if startTime >= sevenDaysAgo && startTime < startOfToday {
                pastWeekEvents.append(event)
            } else if startTime > startOfToday && startTime <= sevenDaysFromNow {
                nextWeekEvents.append(event)
            }
        }
        
        // Calculate patterns from past week
        let patterns = calculateSchedulePatterns(from: pastWeekEvents)
        
        // Create completion history
        let completionHistory = events
            .filter { $0.isCompleted }
            .compactMap { event -> CompletionItem? in
                guard let id = event.id?.uuidString,
                      let completedAt = event.completedAt else { return nil }
                
                return CompletionItem(
                    eventId: id,
                    completedAt: formatter.string(from: completedAt),
                    completionRate: 1.0
                )
            }
        
        // Get user's personal context from UserDefaults
        let personalContext = UserDefaults.standard.string(forKey: "aiContextInfo")
        
        // Convert goals to GoalItems
        let goalItems = goals?.map { goal in
            GoalItem(
                id: goal.id?.uuidString ?? "",
                title: goal.title ?? "",
                type: goal.type ?? "",
                progress: goal.progress,
                targetValue: goal.targetValue,
                currentValue: goal.currentValue,
                targetDate: goal.targetDate.map { formatter.string(from: $0) },
                isCompleted: goal.isCompleted,
                priority: goal.priorityEnum.displayName
            )
        }
        
        // Convert tasks to TaskItems
        let taskItems = tasks?.map { task in
            TaskItem(
                id: task.id?.uuidString ?? "",
                title: task.title ?? "",
                priority: task.priorityEnum.displayName,
                dueDate: task.dueDate.map { formatter.string(from: $0) },
                isCompleted: task.isCompleted,
                category: task.category?.name,
                estimatedDuration: Int(task.estimatedDuration),
                tags: task.tags?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            )
        }
        
        // Convert habits to HabitItems
        let habitItems = habits?.map { habit in
            HabitItem(
                id: habit.id?.uuidString ?? "",
                name: habit.name ?? "",
                trackingType: habit.trackingType ?? "binary",
                goalTarget: habit.goalTarget,
                currentStreak: Int(habit.currentStreak),
                isCompletedToday: habit.isCompletedToday,
                completionRate: habit.totalCompletions > 0 ? min(1.0, Double(habit.totalCompletions) / 30.0) : 0.0
            )
        }
        
        return UserContext(
            currentTime: formatter.string(from: now),
            todaySchedule: todayEvents.map(eventToScheduleItem),
            pastWeekSchedule: pastWeekEvents.map(eventToScheduleItem),
            nextWeekSchedule: nextWeekEvents.map(eventToScheduleItem),
            completionHistory: completionHistory,
            timezone: TimeZone.currentIdentifier,
            timezoneOffset: TimeZone.offsetString,
            personalContext: personalContext,
            schedulePatterns: patterns,
            goals: goalItems,
            tasks: taskItems,
            habits: habitItems
        )
    }
    
    private func calculateSchedulePatterns(from events: [Event]) -> SchedulePatterns? {
        guard !events.isEmpty else { return nil }
        
        let calendar = Calendar.current
        
        // Calculate average events per day
        var eventsByDay: [String: Int] = [:]
        var totalDuration: TimeInterval = 0
        var categoryCount: [String: Int] = [:]
        
        for event in events {
            guard let startTime = event.startTime,
                  let endTime = event.endTime else { continue }
            
            // Count by day of week
            let dayOfWeek = calendar.component(.weekday, from: startTime)
            let dayName = calendar.weekdaySymbols[dayOfWeek - 1]
            eventsByDay[dayName, default: 0] += 1
            
            // Calculate duration
            totalDuration += endTime.timeIntervalSince(startTime)
            
            // Count categories
            if let category = event.category?.name {
                categoryCount[category, default: 0] += 1
            }
        }
        
        let averageEventsPerDay = Double(events.count) / 7.0
        let averageDurationMinutes = events.isEmpty ? 0 : (totalDuration / Double(events.count)) / 60.0
        
        let busiestDay = eventsByDay.max(by: { $0.value < $1.value })?.key
        let mostFrequentCategory = categoryCount.max(by: { $0.value < $1.value })?.key
        
        return SchedulePatterns(
            totalEventsLastWeek: events.count,
            averageEventsPerDay: averageEventsPerDay,
            busiestDayOfWeek: busiestDay,
            mostFrequentCategory: mostFrequentCategory,
            averageEventDuration: averageDurationMinutes
        )
    }
}