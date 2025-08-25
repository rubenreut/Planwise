import Foundation
import SwiftUI
import Combine
import CoreData

/// Handles AI communication, rate limiting, and function calling
@MainActor
class AIServiceViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isRateLimited: Bool = false
    @Published var rateLimitResetTime: Date?
    @Published var rateLimitInfo: RateLimitInfo?
    @Published var showRateLimitWarning: Bool = false
    @Published var showPaywall: Bool = false
    @Published var isProcessingAI: Bool = false
    @Published var streamingMessageId: UUID?
    
    // MARK: - Dependencies
    
    private let openAIService: OpenAIService
    private let aiCoordinator: AICoordinator
    private let subscriptionManager = SubscriptionManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var rateLimitTimer: Timer?
    private var streamingTask: AsyncTask<Void, Never>?
    
    // MARK: - Configuration
    
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    
    // MARK: - Initialization
    
    init(openAIService: OpenAIService, context: NSManagedObjectContext, scheduleManager: ScheduleManaging, taskManager: TaskManaging, goalManager: GoalManager, habitManager: HabitManaging) {
        self.openAIService = openAIService
        self.aiCoordinator = AICoordinator(
            context: context,
            scheduleManager: scheduleManager,
            taskManager: taskManager as? TaskManager ?? TaskManager(persistence: PersistenceController.shared),
            goalManager: goalManager,
            habitManager: habitManager
        )
        setupRateLimitObserver()
    }
    
    // MARK: - Rate Limit Management
    
    private func setupRateLimitObserver() {
        // Observe rate limit changes
        // Observe rate limit changes from subscription manager
        // Note: SubscriptionManager needs to expose rateLimitInfo as @Published
    }
    
    private func handleRateLimitUpdate(_ info: RateLimitInfo?) {
        guard let info = info else {
            isRateLimited = false
            rateLimitResetTime = nil
            return
        }
        
        rateLimitInfo = info
        
        // Check if rate limited
        if info.remaining <= 0 {
            isRateLimited = true
            // info.resetTime is already a Date
            rateLimitResetTime = info.resetTime
            showRateLimitWarning = true
            
            // Set timer to reset rate limit
            startRateLimitTimer()
        } else {
            isRateLimited = false
            rateLimitResetTime = nil
        }
    }
    
    private func startRateLimitTimer() {
        rateLimitTimer?.invalidate()
        
        guard let resetTime = rateLimitResetTime else { return }
        
        let timeInterval = resetTime.timeIntervalSinceNow
        if timeInterval > 0 {
            rateLimitTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                _Concurrency.Task { @MainActor in
                    self?.isRateLimited = false
                    self?.rateLimitResetTime = nil
                    self?.showRateLimitWarning = false
                }
            }
        }
    }
    
    func checkRateLimit() -> Bool {
        if isRateLimited {
            if !subscriptionManager.isPremium {
                showPaywall = true
            } else {
                showRateLimitWarning = true
            }
            return false
        }
        return true
    }
    
    // MARK: - AI Communication
    
    func sendMessageToAI(messages: [ChatRequestMessage], withFunctions: Bool = true) async throws -> ChatMessage {
        isProcessingAI = true
        defer { isProcessingAI = false }
        
        // Check rate limit
        guard checkRateLimit() else {
            throw AIServiceError.rateLimited
        }
        
        // Prepare request
        let _ = withFunctions ? getSimplifiedTools() : nil
        
        // Send with retry logic
        var retryCount = 0
        var lastError: Error?
        
        while retryCount < maxRetries {
            do {
                let response = try await openAIService.sendChatRequest(
                    messages: messages
                )
                
                return processAIResponse(response)
                
            } catch {
                lastError = error
                retryCount += 1
                
                if retryCount < maxRetries {
                    try await _Concurrency.Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? AIServiceError.unknownError
    }
    
    func streamMessageFromAI(messages: [ChatRequestMessage], onChunk: @escaping (String) -> Void) async throws {
        isProcessingAI = true
        defer { isProcessingAI = false }
        
        // Check rate limit
        guard checkRateLimit() else {
            throw AIServiceError.rateLimited
        }
        
        // Cancel any existing streaming task
        streamingTask?.cancel()
        
        // Create new streaming message ID
        streamingMessageId = UUID()
        
        // Start streaming
        streamingTask = AsyncTask {
            do {
                let stream = self.openAIService.streamChatRequest(messages: messages)
                for try await event in stream {
                    if case .data(let streamData) = event {
                        if let content = streamData.choices.first?.delta.content {
                            _Concurrency.Task { @MainActor in
                                onChunk(content)
                            }
                        }
                    }
                }
            } catch {
                print("Streaming error: \(error)")
            }
        }
        
        await streamingTask?.value
        streamingMessageId = nil
    }
    
    // MARK: - Function Calling
    
    func processFunctionCall(_ functionName: String, arguments: String) async throws -> FunctionCallResult {
        isProcessingAI = true
        defer { isProcessingAI = false }
        
        // Process the function call
        // Note: This needs to be implemented based on actual AI coordinator capabilities
        return FunctionCallResult(
            functionName: functionName,
            success: true,
            message: "Function processed",
            details: nil
        )
    }
    
    func buildDynamicContext(userName: String, currentDate: Date) -> String {
        // Build context with user info and current state
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        
        var context = """
        Current Information:
        - User: \(userName)
        - Date/Time: \(formatter.string(from: currentDate))
        - Timezone: \(TimeZone.current.identifier)
        """
        
        // Add subscription status
        if subscriptionManager.isPremium {
            context += "\n- Subscription: Premium"
        } else {
            context += "\n- Subscription: Free (Limited)"
        }
        
        // Add rate limit info if available
        if let rateLimitInfo = rateLimitInfo {
            context += "\n- API Calls Remaining: \(rateLimitInfo.remaining)/\(rateLimitInfo.limit)"
        }
        
        return context
    }
    
    // MARK: - Helper Methods
    
    private func processAIResponse(_ response: ChatResponse) -> ChatMessage {
        let content = response.choices.first?.message.content ?? ""
        
        return ChatMessage(
            content: content,
            sender: .assistant,
            timestamp: Date()
        )
    }
    
    private func getSimplifiedTools() -> [[String: Any]] {
        return [
            [
                "type": "function",
                "function": [
                    "name": "manage_events",
                    "description": "Manage calendar events - create, update, delete, list",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "action": [
                                "type": "string",
                                "enum": ["create", "update", "delete", "list"]
                            ],
                            "parameters": [
                                "type": "object",
                                "description": "Action-specific parameters"
                            ]
                        ],
                        "required": ["action", "parameters"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "manage_tasks",
                    "description": "Manage tasks - create, update, complete, delete, list",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "action": [
                                "type": "string",
                                "enum": ["create", "update", "complete", "delete", "list"]
                            ],
                            "parameters": [
                                "type": "object",
                                "description": "Action-specific parameters"
                            ]
                        ],
                        "required": ["action", "parameters"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "manage_habits",
                    "description": "Manage habits - create, update, log, delete, list",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "action": [
                                "type": "string",
                                "enum": ["create", "update", "log", "delete", "list"]
                            ],
                            "parameters": [
                                "type": "object",
                                "description": "Action-specific parameters"
                            ]
                        ],
                        "required": ["action", "parameters"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "manage_goals",
                    "description": "Manage goals - create, update, progress, delete, list",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "action": [
                                "type": "string",
                                "enum": ["create", "update", "progress", "delete", "list"]
                            ],
                            "parameters": [
                                "type": "object",
                                "description": "Action-specific parameters"
                            ]
                        ],
                        "required": ["action", "parameters"]
                    ]
                ]
            ]
        ]
    }
    
    // MARK: - Cleanup
    
    deinit {
        rateLimitTimer?.invalidate()
        streamingTask?.cancel()
    }
}

// MARK: - Error Types

enum AIServiceError: LocalizedError {
    case rateLimited
    case networkError
    case invalidResponse
    case functionCallFailed
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .rateLimited:
            return "Rate limit exceeded. Please try again later."
        case .networkError:
            return "Network connection error"
        case .invalidResponse:
            return "Invalid response from AI service"
        case .functionCallFailed:
            return "Function execution failed"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

// MARK: - Supporting Types
// Note: RateLimitInfo, FunctionCallResult are defined in the main Models
// ChatResponse comes from OpenAIService