//
//  OpenAIService.swift
//  Momentum
//
//  Created by Momentum on 7/1/25.
//

import Foundation

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
    let completionHistory: [CompletionItem]
    let timezone: String
    let timezoneOffset: String
}

/// Schedule item representation
struct ScheduleItem: Codable {
    let id: String
    let title: String
    let startTime: String
    let endTime: String
    let category: String?
    let isCompleted: Bool
}

/// Completion history item
struct CompletionItem: Codable {
    let eventId: String
    let completedAt: String
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
    private let appSecret = APIConfiguration.appSecret
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
        maxTokens: Int = 500,
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
        
        var request = URLRequest(url: URL(string: workerURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appSecret, forHTTPHeaderField: "X-App-Secret")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        request.httpBody = try encoder.encode(chatRequest)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Handle HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIError.invalidResponse
            }
            
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
        maxTokens: Int = 500,
        userContext: UserContext? = nil
    ) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
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
                    
                    var request = URLRequest(url: URL(string: workerURL)!)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(appSecret, forHTTPHeaderField: "X-App-Secret")
                    request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
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
                    
                    // Parse SSE stream
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString == "[DONE]" {
                                continuation.yield(.done)
                                break
                            }
                            
                            if let data = jsonString.data(using: .utf8),
                               let streamData = try? decoder.decode(ChatStreamData.self, from: data) {
                                continuation.yield(.data(streamData))
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
        
        rateLimitInfo = RateLimitInfo(
            limit: limit,
            remaining: remaining,
            resetTime: Date(timeIntervalSince1970: resetTimestamp)
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
        
        print("🔍 Parsing function call:")
        print("   Name: \(functionCall.name)")
        print("   Raw arguments: \(functionCall.arguments)")
        
        do {
            let arguments = try JSONSerialization.jsonObject(
                with: functionCall.arguments.data(using: .utf8)!,
                options: []
            ) as? [String: Any] ?? [:]
            
            print("   Parsed arguments: \(arguments)")
            
            return ParsedFunction(
                name: functionCall.name,
                arguments: arguments
            )
        } catch {
            print("❌ Failed to parse function arguments: \(error)")
            print("   Raw string was: \(functionCall.arguments)")
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
    /// Create user context from current schedule
    func createUserContext(from events: [Event]) -> UserContext {
        let formatter = ISO8601DateFormatter()
        
        let scheduleItems = events.map { event in
            ScheduleItem(
                id: event.id?.uuidString ?? "",
                title: event.title ?? "",
                startTime: formatter.string(from: event.startTime ?? Date()),
                endTime: formatter.string(from: event.endTime ?? Date()),
                category: event.category?.name,
                isCompleted: event.isCompleted
            )
        }
        
        let completionHistory = events
            .filter { $0.isCompleted }
            .compactMap { event -> CompletionItem? in
                guard let id = event.id?.uuidString,
                      let completedAt = event.completedAt else { return nil }
                
                return CompletionItem(
                    eventId: id,
                    completedAt: formatter.string(from: completedAt),
                    completionRate: 1.0 // You can calculate actual completion rate if needed
                )
            }
        
        return UserContext(
            currentTime: formatter.string(from: Date()),
            todaySchedule: scheduleItems,
            completionHistory: completionHistory,
            timezone: TimeZone.currentIdentifier,
            timezoneOffset: TimeZone.offsetString
        )
    }
}