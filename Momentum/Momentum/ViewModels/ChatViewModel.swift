import Foundation
import SwiftUI
import Combine
import CoreData
import PhotosUI
import UIKit

// MARK: - Chat View Model

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isTypingIndicatorVisible: Bool = false
    @Published var streamingMessageId: UUID?
    @Published var isLoading: Bool = false
    @Published var rateLimitInfo: RateLimitInfo?
    @Published var showRateLimitWarning: Bool = false
    @Published var showImagePicker: Bool = false
    @Published var showCamera: Bool = false
    @Published var selectedImage: UIImage?
    @Published var showPaywall: Bool = false
    
    // MARK: - Private Properties
    
    private let userName: String = "User" // Could be fetched from settings
    private let openAIService: OpenAIService
    private let scheduleManager: ScheduleManaging
    private let subscriptionManager = SubscriptionManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var streamingTask: Task<Void, Never>?
    private var conversationHistory: [ChatRequestMessage] = []
    
    // MARK: - Mathematical Constants
    
    private let φ: Double = 1.618033988749895 // Golden ratio
    
    // MARK: - Initialization
    
    init(openAIService: OpenAIService? = nil, scheduleManager: ScheduleManaging? = nil) {
        self.openAIService = openAIService ?? DependencyContainer.shared.openAIService
        self.scheduleManager = scheduleManager ?? DependencyContainer.shared.scheduleManager
        setupInitialGreeting()
        observeRateLimitInfo()
    }
    
    // MARK: - Public Methods
    
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Check if user can send message
        guard subscriptionManager.canSendMessage() else {
            showPaywall = true
            return
        }
        
        // Add user message
        let userMessage = ChatMessage(
            content: inputText,
            sender: .user(name: userName),
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // Add to conversation history
        conversationHistory.append(ChatRequestMessage(
            role: "user",
            content: inputText
        ))
        
        // Clear input
        let messageContent = inputText
        inputText = ""
        
        // Cancel any existing streaming
        streamingTask?.cancel()
        
        // Send to OpenAI
        Task {
            // Increment message count before sending
            subscriptionManager.incrementMessageCount()
            await sendToOpenAI()
        }
    }
    
    func retryLastMessage() {
        // Find the last user message
        guard let lastUserMessage = messages.last(where: { $0.sender.isUser }) else { return }
        
        // Remove any error messages after it
        if let lastUserIndex = messages.lastIndex(where: { $0.sender.isUser }) {
            messages = Array(messages.prefix(lastUserIndex + 1))
        }
        
        // Retry sending
        Task {
            await sendToOpenAI()
        }
    }
    
    func handleImageAttachment() {
        // Check if user can upload images
        guard subscriptionManager.canUploadImage() else {
            showPaywall = true
            return
        }
        
        // Handle image attachment from photos/camera
        showImagePicker = true
    }
    
    func handleCameraAttachment() {
        // Check if user can upload images
        guard subscriptionManager.canUploadImage() else {
            showPaywall = true
            return
        }
        
        // Handle camera capture
        showCamera = true
    }
    
    func processSelectedImage(_ image: UIImage) {
        selectedImage = image
        
        // Convert image to base64 for AI analysis
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let base64String = imageData.base64EncodedString()
        
        // Add user message with image
        let userMessage = ChatMessage(
            content: "I've attached an image for you to analyze.",
            sender: .user(name: userName),
            timestamp: Date(),
            attachedImage: image
        )
        messages.append(userMessage)
        
        // Send to AI with image context
        Task {
            await sendImageToAI(base64Image: base64String)
        }
    }
    
    func handleFileAttachment() {
        // Handle file attachment
        print("File attachment requested")
    }
    
    func handleVoiceInput() {
        // Handle voice input
        print("Voice input requested")
    }
    
    func handleEventAction(eventId: String, action: EventAction) {
        // Handle actions on event previews
        switch action {
        case .edit:
            // TODO: Implement edit functionality
            print("Edit event: \(eventId)")
        case .delete:
            // Send a message to delete the event
            inputText = "Delete the event"
            sendMessage()
        case .complete:
            // Send a message to mark complete
            inputText = "Mark the event as complete"
            sendMessage()
        case .viewFull:
            // TODO: Navigate to full event view
            print("View full event: \(eventId)")
        case .share:
            // TODO: Share event
            print("Share event: \(eventId)")
        default:
            break
        }
    }
    
    func handleMultiEventAction(_ action: MultiEventAction) {
        switch action {
        case .toggleComplete(let eventId):
            // TODO: Toggle specific event completion
            print("Toggle complete: \(eventId)")
        case .markAllComplete:
            inputText = "Mark all events as complete"
            sendMessage()
        case .editTimes:
            // TODO: Implement bulk edit times
            print("Edit all times")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupInitialGreeting() {
        let greeting = ChatMessage(
            content: "Hello! I'm your Momentum Assistant. I can help you manage your schedule, create events, and optimize your time. How can I assist you today?",
            sender: .assistant,
            timestamp: Date()
        )
        messages.append(greeting)
        
        // Add to conversation history
        conversationHistory.append(ChatRequestMessage(
            role: "assistant",
            content: greeting.content
        ))
    }
    
    private func observeRateLimitInfo() {
        openAIService.$rateLimitInfo
            .sink { [weak self] info in
                self?.rateLimitInfo = info
                
                // Show warning if less than 10% remaining
                if let info = info {
                    let percentRemaining = Double(info.remaining) / Double(info.limit)
                    self?.showRateLimitWarning = percentRemaining < 0.1
                }
            }
            .store(in: &cancellables)
    }
    
    private func sendToOpenAI() async {
        isLoading = true
        isTypingIndicatorVisible = true
        
        do {
            // Create user context from current schedule
            let events = await scheduleManager.events
            let userContext = openAIService.createUserContext(from: events)
            
            // Always stream for better UX
            let shouldStream = true
            
            if shouldStream {
                // Create streaming message
                let streamingMessage = ChatMessage(
                    content: "",
                    sender: .assistant,
                    timestamp: Date(),
                    isStreaming: true
                )
                messages.append(streamingMessage)
                streamingMessageId = streamingMessage.id
                isTypingIndicatorVisible = false
                
                // Stream response
                await streamResponse(messageId: streamingMessage.id, userContext: userContext)
            } else {
                // Non-streaming response
                let response = try await openAIService.sendChatRequest(
                    messages: conversationHistory,
                    userContext: userContext
                )
                
                isTypingIndicatorVisible = false
                
                // Process response
                if let choice = response.choices.first {
                    await processAssistantResponse(choice.message)
                }
            }
        } catch let error as OpenAIError {
            isTypingIndicatorVisible = false
            handleOpenAIError(error)
        } catch {
            isTypingIndicatorVisible = false
            handleGenericError(error)
        }
        
        isLoading = false
    }
    
    private func sendImageToAI(base64Image: String) async {
        isLoading = true
        isTypingIndicatorVisible = true
        
        // Create message with image for vision model
        let imageContent = [
            [
                "type": "text",
                "text": "I've attached an image. Please analyze it and help me create relevant calendar events based on what you see. Look for dates, times, event details, meeting information, schedules, or any other scheduling-related content. If you find event information, use the appropriate functions to create the events."
            ],
            [
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(base64Image)"
                ]
            ]
        ]
        
        // Add to conversation history with vision content
        conversationHistory.append(ChatRequestMessage(
            role: "user",
            content: imageContent
        ))
        
        // Send to OpenAI with vision support
        await sendToOpenAI()
    }
    
    private func streamResponse(messageId: UUID, userContext: UserContext) async {
        let stream = openAIService.streamChatRequest(
            messages: conversationHistory,
            userContext: userContext
        )
        
        var accumulatedContent = ""
        var functionCallName: String?
        var functionCallArguments = ""
        
        streamingTask = Task {
            do {
                for try await event in stream {
                    guard !Task.isCancelled else { break }
                    
                    switch event {
                    case .data(let streamData):
                        if let choice = streamData.choices.first {
                            // Handle content
                            if let content = choice.delta.content {
                                accumulatedContent += content
                                updateStreamingMessage(id: messageId, content: accumulatedContent)
                            }
                            
                            // Handle function call
                            if let functionCall = choice.delta.functionCall {
                                if let name = functionCall.name {
                                    functionCallName = name
                                    print("📞 Stream: Function name detected: \(name)")
                                }
                                if let args = functionCall.arguments {
                                    functionCallArguments += args
                                    print("📞 Stream: Function args chunk: \(args)")
                                }
                            }
                        }
                        
                    case .done:
                        // Finalize message
                        finalizeStreamingMessage(id: messageId)
                        
                        // Process function call if any
                        if let functionName = functionCallName {
                            print("📞 Stream complete - Function: \(functionName)")
                            print("📞 Stream complete - Arguments: \(functionCallArguments)")
                            
                            let message = ChatResponse.Message(
                                role: "assistant",
                                content: accumulatedContent.isEmpty ? nil : accumulatedContent,
                                functionCall: ChatResponse.FunctionCall(
                                    name: functionName,
                                    arguments: functionCallArguments
                                )
                            )
                            await processAssistantResponse(message)
                        } else {
                            // Add to conversation history
                            conversationHistory.append(ChatRequestMessage(
                                role: "assistant",
                                content: accumulatedContent
                            ))
                        }
                    }
                }
            } catch {
                handleStreamingError(error, messageId: messageId)
            }
        }
    }
    
    private func updateStreamingMessage(id: UUID, content: String) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].content = content
        }
    }
    
    private func finalizeStreamingMessage(id: UUID) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].isStreaming = false
        }
        streamingMessageId = nil
    }
    
    private func processAssistantResponse(_ message: ChatResponse.Message) async {
        // Handle function call
        if let functionCall = message.functionCall {
            let result = await processFunctionCall(functionCall)
            
            // Create event preview based on function call
            var eventPreview: EventPreview?
            var multipleEventsPreview: [EventListItem]?
            var bulkActionPreview: BulkActionPreview?
            
            // Always show previews for modification operations
            switch functionCall.name {
            case "create_event":
                if result.success {
                    eventPreview = createEventPreview(from: result, functionName: functionCall.name)
                }
            case "update_event":
                // Show preview for updates even if they need confirmation
                eventPreview = createEventPreview(from: result, functionName: functionCall.name)
                if !result.success {
                    // If update failed, still show as bulk action for retry
                    bulkActionPreview = createBulkActionPreview(from: result, functionName: functionCall.name)
                }
            case "create_multiple_events", "create_recurring_event":
                if result.success {
                    multipleEventsPreview = createMultipleEventsPreview(from: result)
                }
            case "delete_event", "delete_all_events", "update_all_events", "mark_all_complete":
                bulkActionPreview = createBulkActionPreview(from: result, functionName: functionCall.name)
            default:
                break
            }
            
            // Create message with function result
            let assistantMessage = ChatMessage(
                content: message.content ?? "",
                sender: .assistant,
                timestamp: Date(),
                functionCall: result,
                eventPreview: eventPreview,
                multipleEventsPreview: multipleEventsPreview,
                bulkActionPreview: bulkActionPreview
            )
            messages.append(assistantMessage)
            
            // Add to conversation history
            conversationHistory.append(ChatRequestMessage(
                role: "assistant",
                content: message.content ?? "I've performed the requested action."
            ))
            
            // Add function result to history
            conversationHistory.append(ChatRequestMessage(
                role: "function",
                content: result.message,
                name: functionCall.name
            ))
        } else {
            // Regular text response
            let assistantMessage = ChatMessage(
                content: message.content ?? "",
                sender: .assistant,
                timestamp: Date()
            )
            messages.append(assistantMessage)
            
            // Add to conversation history
            conversationHistory.append(ChatRequestMessage(
                role: "assistant",
                content: message.content ?? ""
            ))
        }
    }
    
    private func processFunctionCall(_ functionCall: ChatResponse.FunctionCall) async -> FunctionCallResult {
        print("🔧 Processing function call: \(functionCall.name)")
        print("📊 Raw Arguments: \(functionCall.arguments)")
        
        // Try to parse arguments and print them
        if let data = functionCall.arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            print("📊 Parsed Arguments: \(json)")
        }
        
        // Parse function arguments
        guard let parsedFunction = openAIService.parseFunctionCall(
            from: ChatResponse(
                id: "",
                object: "",
                created: 0,
                model: "",
                choices: [ChatResponse.Choice(
                    index: 0,
                    message: ChatResponse.Message(
                        role: "assistant",
                        content: nil,
                        functionCall: functionCall
                    ),
                    finishReason: nil
                )],
                usage: nil,
                metadata: nil
            )
        ) else {
            return FunctionCallResult(
                functionName: functionCall.name,
                success: false,
                message: "Failed to parse function arguments",
                details: nil
            )
        }
        
        switch parsedFunction.name {
        case "create_event":
            return await createEvent(with: parsedFunction.arguments)
        case "update_event":
            return await updateEvent(with: parsedFunction.arguments)
        case "delete_event":
            return await deleteEvent(with: parsedFunction.arguments)
        case "list_events":
            return await listEvents(with: parsedFunction.arguments)
        case "suggest_schedule":
            return await suggestSchedule(with: parsedFunction.arguments)
        case "delete_all_events":
            return await deleteAllEvents(with: parsedFunction.arguments)
        case "create_multiple_events":
            return await createMultipleEvents(with: parsedFunction.arguments)
        case "update_all_events":
            return await updateAllEvents(with: parsedFunction.arguments)
        case "mark_all_complete":
            return await markAllComplete(with: parsedFunction.arguments)
        case "create_recurring_event":
            return await createRecurringEvent(with: parsedFunction.arguments)
        default:
            return FunctionCallResult(
                functionName: parsedFunction.name,
                success: false,
                message: "Unknown function",
                details: nil
            )
        }
    }
    
    // MARK: - Schedule Functions
    
    private func createEvent(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let title = arguments["title"] as? String,
              let startTimeStr = arguments["startTime"] as? String ?? arguments["start_time"] as? String,
              let endTimeStr = arguments["endTime"] as? String ?? arguments["end_time"] as? String else {
            return FunctionCallResult(
                functionName: "create_event",
                success: false,
                message: "Missing required parameters",
                details: nil
            )
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Try with full format first, then fallback to basic format
        var startTime = formatter.date(from: startTimeStr)
        if startTime == nil {
            formatter.formatOptions = [.withInternetDateTime]
            startTime = formatter.date(from: startTimeStr)
        }
        
        var endTime = formatter.date(from: endTimeStr)
        if endTime == nil {
            formatter.formatOptions = [.withInternetDateTime]
            endTime = formatter.date(from: endTimeStr)
        }
        
        guard let startTime = startTime,
              let endTime = endTime else {
            return FunctionCallResult(
                functionName: "create_event",
                success: false,
                message: "Invalid date format",
                details: nil
            )
        }
        
        // Find category if specified
        let categoryName = arguments["category"] as? String
        let category = scheduleManager.categories.first { $0.name == categoryName }
        
        let result = scheduleManager.createEvent(
            title: title,
            startTime: startTime,
            endTime: endTime,
            category: category,
            notes: arguments["notes"] as? String,
            location: arguments["location"] as? String,
            isAllDay: arguments["is_all_day"] as? Bool ?? false
        )
        
        switch result {
        case .success(let event):
            let timeFormatter = DateFormatter()
            timeFormatter.dateStyle = .none
            timeFormatter.timeStyle = .short
            
            // Check for conflicts
            let conflicts = scheduleManager.checkForConflicts(
                startTime: event.startTime ?? Date(),
                endTime: event.endTime ?? Date(),
                excludingEvent: nil
            )
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            
            var message = "Created '\(event.title ?? "")'"
            var details: [String: String] = [
                "EventId": event.id?.uuidString ?? "",
                "Title": event.title ?? "",
                "Time": "\(timeFormatter.string(from: event.startTime ?? Date())) - \(timeFormatter.string(from: event.endTime ?? Date()))",
                "Date": dateFormatter.string(from: event.startTime ?? Date()),
                "Category": event.category?.name ?? "None"
            ]
            
            if let location = event.location {
                details["Location"] = location
            }
            
            if !conflicts.isEmpty {
                message += " ⚠️ Warning: Conflicts with \(conflicts.count) existing event(s)"
                let conflictTitles = conflicts.compactMap { $0.title }.joined(separator: ", ")
                details["Conflicts"] = conflictTitles
            }
            
            return FunctionCallResult(
                functionName: "create_event",
                success: true,
                message: message,
                details: details
            )
        case .failure(let error):
            return FunctionCallResult(
                functionName: "create_event",
                success: false,
                message: error.localizedDescription,
                details: nil
            )
        }
    }
    
    private func updateEvent(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let eventId = arguments["eventId"] as? String ?? arguments["event_id"] as? String,
              let eventUUID = UUID(uuidString: eventId) else {
            return FunctionCallResult(
                functionName: "update_event",
                success: false,
                message: "Invalid event ID",
                details: nil
            )
        }
        
        // Find the event
        guard let event = scheduleManager.events.first(where: { $0.id == eventUUID }) else {
            return FunctionCallResult(
                functionName: "update_event",
                success: false,
                message: "Event not found",
                details: nil
            )
        }
        
        // Parse optional updates - handle both formats
        let updates = arguments["updates"] as? [String: Any] ?? arguments
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var startTime: Date?
        if let startTimeStr = updates["startTime"] as? String ?? updates["start_time"] as? String {
            startTime = formatter.date(from: startTimeStr)
            if startTime == nil {
                formatter.formatOptions = [.withInternetDateTime]
                startTime = formatter.date(from: startTimeStr)
            }
        }
        
        var endTime: Date?
        if let endTimeStr = updates["endTime"] as? String ?? updates["end_time"] as? String {
            endTime = formatter.date(from: endTimeStr)
            if endTime == nil {
                formatter.formatOptions = [.withInternetDateTime]
                endTime = formatter.date(from: endTimeStr)
            }
        }
        
        let result = scheduleManager.updateEvent(
            event,
            title: updates["title"] as? String,
            startTime: startTime,
            endTime: endTime,
            category: nil, // TODO: Handle category updates
            notes: updates["notes"] as? String,
            location: updates["location"] as? String,
            isCompleted: updates["isCompleted"] as? Bool ?? updates["is_completed"] as? Bool
        )
        
        switch result {
        case .success:
            return FunctionCallResult(
                functionName: "update_event",
                success: true,
                message: "Updated '\(event.title ?? "")'",
                details: nil
            )
        case .failure(let error):
            return FunctionCallResult(
                functionName: "update_event",
                success: false,
                message: error.localizedDescription,
                details: nil
            )
        }
    }
    
    private func deleteEvent(with arguments: [String: Any]) async -> FunctionCallResult {
        print("🗑️ delete_event called with arguments: \(arguments)")
        
        let eventId = arguments["eventId"] as? String ?? arguments["event_id"] as? String
        print("🆔 eventId: \(eventId ?? "nil")")
        
        guard let eventId = eventId,
              let eventUUID = UUID(uuidString: eventId) else {
            return FunctionCallResult(
                functionName: "delete_event",
                success: false,
                message: "Invalid event ID",
                details: nil
            )
        }
        
        // Find the event
        guard let event = scheduleManager.events.first(where: { $0.id == eventUUID }) else {
            return FunctionCallResult(
                functionName: "delete_event",
                success: false,
                message: "Event not found",
                details: nil
            )
        }
        
        let eventTitle = event.title ?? "Untitled"
        let result = scheduleManager.deleteEvent(event)
        
        switch result {
        case .success:
            return FunctionCallResult(
                functionName: "delete_event",
                success: true,
                message: "Deleted '\(eventTitle)'",
                details: nil
            )
        case .failure(let error):
            return FunctionCallResult(
                functionName: "delete_event",
                success: false,
                message: error.localizedDescription,
                details: nil
            )
        }
    }
    
    private func listEvents(with arguments: [String: Any]) async -> FunctionCallResult {
        print("📋 list_events called with arguments: \(arguments)")
        
        // Handle both old and new parameter names
        let startDateStr = arguments["startDate"] as? String ?? arguments["start_date"] as? String
        let endDateStr = arguments["endDate"] as? String ?? arguments["end_date"] as? String
        let limit = arguments["limit"] as? Int ?? 50
        
        print("📅 startDateStr: \(startDateStr ?? "nil")")
        print("📅 endDateStr: \(endDateStr ?? "nil")")
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        var allEvents: [Event] = []
        
        print("📅 Trying to parse date: \(startDateStr ?? "nil")")
        
        if let startDateStr = startDateStr, let startDate = formatter.date(from: startDateStr) {
            print("✅ Successfully parsed start date: \(startDate)")
            if let endDateStr = endDateStr, let endDate = formatter.date(from: endDateStr) {
                print("✅ Successfully parsed end date: \(endDate)")
                // Get events in date range
                let calendar = Calendar.current
                var currentDate = startDate
                while currentDate <= endDate {
                    allEvents.append(contentsOf: scheduleManager.events(for: currentDate))
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                }
            } else {
                // Single date
                allEvents = scheduleManager.events(for: startDate)
            }
        } else {
            // Date parsing failed
            print("❌ Failed to parse date: \(startDateStr ?? "nil")")
            return FunctionCallResult(
                functionName: "list_events",
                success: false,
                message: "Failed to parse date. Please ensure date is in YYYY-MM-DD format.",
                details: ["provided": startDateStr ?? "nil"]
            )
        }
        
        let limitedEvents = Array(allEvents.prefix(limit))
        
        if limitedEvents.isEmpty {
            return FunctionCallResult(
                functionName: "list_events",
                success: true,
                message: "No events scheduled",
                details: nil
            )
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        
        var eventList = ""
        var eventDetails: [[String: String]] = []
        
        for (index, event) in limitedEvents.enumerated() {
            let time = "\(timeFormatter.string(from: event.startTime ?? Date())) - \(timeFormatter.string(from: event.endTime ?? Date()))"
            let eventId = event.id?.uuidString ?? "no-id"
            eventList += "\(index + 1). \(event.title ?? "Untitled") at \(time)\n"
            
            // Add structured data for AI to parse
            eventDetails.append([
                "id": eventId,
                "title": event.title ?? "Untitled",
                "time": time
            ])
        }
        
        // Include event IDs in a structured format at the end
        var structuredInfo = "\n\nEvent IDs for deletion/update:\n"
        for detail in eventDetails {
            structuredInfo += "- \(detail["title"] ?? ""): \(detail["id"] ?? "")\n"
        }
        
        return FunctionCallResult(
            functionName: "list_events",
            success: true,
            message: eventList.trimmingCharacters(in: .whitespacesAndNewlines) + structuredInfo,
            details: nil
        )
    }
    
    private func deleteAllEvents(with arguments: [String: Any]) async -> FunctionCallResult {
        // Support both single date and date range
        let startDateStr = arguments["date"] as? String ?? arguments["startDate"] as? String ?? arguments["start_date"] as? String
        let endDateStr = arguments["endDate"] as? String ?? arguments["end_date"] as? String
        
        // If no date is provided, delete ALL events
        if startDateStr == nil && endDateStr == nil {
            // Force refresh to get latest events from Core Data
            scheduleManager.forceRefresh()
            
            // Create a copy of the events array to avoid mutation during iteration
            let allEvents = Array(scheduleManager.events)
            print("🗑️ Attempting to delete ALL \(allEvents.count) events")
            
            var deletedCount = 0
            var failedCount = 0
            var deletedTitles: [String] = []
            
            for event in allEvents {
                let title = event.title ?? "Untitled"
                let result = scheduleManager.deleteEvent(event)
                switch result {
                case .success:
                    deletedCount += 1
                    deletedTitles.append(title)
                    print("✅ Deleted: \(title)")
                case .failure(let error):
                    failedCount += 1
                    print("❌ Failed to delete \(title): \(error)")
                }
            }
            
            // Force another refresh after all deletions
            scheduleManager.forceRefresh()
            print("📊 Deletion complete: \(deletedCount) succeeded, \(failedCount) failed")
            print("🗑️ Deleted events: \(deletedTitles.joined(separator: ", "))")
            
            // Add a small delay to ensure Core Data completes
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            if failedCount > 0 {
                return FunctionCallResult(
                    functionName: "delete_all_events",
                    success: false,
                    message: "Deleted \(deletedCount) events, but \(failedCount) failed",
                    details: nil
                )
            } else if deletedCount == 0 {
                return FunctionCallResult(
                    functionName: "delete_all_events",
                    success: true,
                    message: "No events found to delete",
                    details: nil
                )
            } else {
                return FunctionCallResult(
                    functionName: "delete_all_events",
                    success: true,
                    message: "Successfully deleted all \(deletedCount) events",
                    details: nil
                )
            }
        }
        
        // Parse dates
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        guard let startDateStr = startDateStr,
              let startDate = formatter.date(from: startDateStr) else {
            return FunctionCallResult(
                functionName: "delete_all_events",
                success: false,
                message: "Invalid or missing date",
                details: nil
            )
        }
        
        // Force refresh before getting events
        scheduleManager.forceRefresh()
        
        var eventsToDelete: [Event] = []
        
        if let endDateStr = endDateStr,
           let endDate = formatter.date(from: endDateStr) {
            // Delete events in date range
            let calendar = Calendar.current
            var currentDate = startDate
            
            while currentDate <= endDate {
                eventsToDelete.append(contentsOf: scheduleManager.events(for: currentDate))
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
        } else {
            // Single date
            eventsToDelete = scheduleManager.events(for: startDate)
        }
        
        // Create a copy to avoid mutation during iteration
        let eventsToDeleteCopy = Array(eventsToDelete)
        print("🗑️ Attempting to delete \(eventsToDeleteCopy.count) events in date range")
        
        var deletedCount = 0
        var failedCount = 0
        var deletedTitles: [String] = []
        
        for event in eventsToDeleteCopy {
            let title = event.title ?? "Untitled"
            let result = scheduleManager.deleteEvent(event)
            switch result {
            case .success:
                deletedCount += 1
                deletedTitles.append(title)
                print("✅ Deleted: \(title)")
            case .failure(let error):
                failedCount += 1
                print("❌ Failed to delete \(title): \(error)")
            }
        }
        
        // Force refresh after deletions
        scheduleManager.forceRefresh()
        print("📊 Date range deletion complete: \(deletedCount) succeeded, \(failedCount) failed")
        
        // Add a small delay to ensure Core Data completes
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let dateDescription = endDateStr != nil ? "from \(startDateStr) to \(endDateStr)" : "on \(startDateStr)"
        
        if failedCount > 0 {
            return FunctionCallResult(
                functionName: "delete_all_events",
                success: false,
                message: "Deleted \(deletedCount) events \(dateDescription), but \(failedCount) failed",
                details: nil
            )
        } else if deletedCount == 0 {
            return FunctionCallResult(
                functionName: "delete_all_events",
                success: true,
                message: "No events found \(dateDescription)",
                details: nil
            )
        } else {
            return FunctionCallResult(
                functionName: "delete_all_events",
                success: true,
                message: "Successfully deleted \(deletedCount) events \(dateDescription)",
                details: nil
            )
        }
    }
    
    private func createMultipleEvents(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let events = arguments["events"] as? [[String: Any]] else {
            return FunctionCallResult(
                functionName: "create_multiple_events",
                success: false,
                message: "Missing events array",
                details: nil
            )
        }
        
        var createdCount = 0
        var failedCount = 0
        var createdEvents: [[String: String]] = []
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        
        for eventData in events {
            let result = await createEvent(with: eventData)
            if result.success {
                createdCount += 1
                if let title = eventData["title"] as? String,
                   let startTimeStr = eventData["startTime"] as? String ?? eventData["start_time"] as? String {
                    
                    // Parse time for display
                    let formatter = ISO8601DateFormatter()
                    if let startTime = formatter.date(from: startTimeStr) {
                        createdEvents.append([
                            "title": title,
                            "time": timeFormatter.string(from: startTime)
                        ])
                    } else {
                        createdEvents.append([
                            "title": title,
                            "time": "Time TBD"
                        ])
                    }
                }
            } else {
                failedCount += 1
            }
        }
        
        // Format event list for details
        let eventList = createdEvents.map { "\($0["title"] ?? "") at \($0["time"] ?? "")" }.joined(separator: ", ")
        let eventTitles = createdEvents.map { $0["title"] ?? "" }.joined(separator: ", ")
        
        if failedCount > 0 {
            return FunctionCallResult(
                functionName: "create_multiple_events",
                success: false,
                message: "Created \(createdCount) events, but \(failedCount) failed",
                details: [
                    "created": eventTitles,
                    "eventList": eventList,
                    "count": "\(createdCount)"
                ]
            )
        } else {
            return FunctionCallResult(
                functionName: "create_multiple_events",
                success: true,
                message: "Successfully created \(createdCount) events",
                details: [
                    "created": eventTitles,
                    "eventList": eventList,
                    "count": "\(createdCount)"
                ]
            )
        }
    }
    
    private func updateAllEvents(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let dateStr = arguments["date"] as? String,
              let updates = arguments["updates"] as? [String: Any] else {
            return FunctionCallResult(
                functionName: "update_all_events",
                success: false,
                message: "Missing required parameters",
                details: nil
            )
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        guard let date = formatter.date(from: dateStr) else {
            return FunctionCallResult(
                functionName: "update_all_events",
                success: false,
                message: "Invalid date format",
                details: nil
            )
        }
        
        let eventsToUpdate = scheduleManager.events(for: date)
        var updatedCount = 0
        var failedCount = 0
        
        for event in eventsToUpdate {
            let result = scheduleManager.updateEvent(
                event,
                title: nil, // Don't change titles in bulk
                startTime: nil, // Don't change times in bulk
                endTime: nil,
                category: nil, // TODO: Handle category updates
                notes: updates["notes"] as? String,
                location: nil,
                isCompleted: updates["isCompleted"] as? Bool
            )
            
            switch result {
            case .success:
                updatedCount += 1
            case .failure:
                failedCount += 1
            }
        }
        
        if failedCount > 0 {
            return FunctionCallResult(
                functionName: "update_all_events",
                success: false,
                message: "Updated \(updatedCount) events, but \(failedCount) failed",
                details: nil
            )
        } else if updatedCount == 0 {
            return FunctionCallResult(
                functionName: "update_all_events",
                success: true,
                message: "No events found on \(dateStr)",
                details: nil
            )
        } else {
            return FunctionCallResult(
                functionName: "update_all_events",
                success: true,
                message: "Successfully updated \(updatedCount) events on \(dateStr)",
                details: nil
            )
        }
    }
    
    private func markAllComplete(with arguments: [String: Any]) async -> FunctionCallResult {
        // This is a convenience function that calls updateAllEvents with isCompleted: true
        let updateArguments: [String: Any] = [
            "date": arguments["date"] as? String ?? "",
            "updates": ["isCompleted": true]
        ]
        
        let result = await updateAllEvents(with: updateArguments)
        // Change the function name in the result
        return FunctionCallResult(
            functionName: "mark_all_complete",
            success: result.success,
            message: result.message.replacingOccurrences(of: "updated", with: "marked as complete"),
            details: result.details
        )
    }
    
    private func createRecurringEvent(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let title = arguments["title"] as? String,
              let startTimeStr = arguments["startTime"] as? String ?? arguments["start_time"] as? String,
              let duration = arguments["duration"] as? Int,
              let recurrenceStr = arguments["recurrence"] as? String else {
            return FunctionCallResult(
                functionName: "create_recurring_event",
                success: false,
                message: "Missing required parameters",
                details: nil
            )
        }
        
        let formatter = ISO8601DateFormatter()
        guard let startTime = formatter.date(from: startTimeStr) else {
            return FunctionCallResult(
                functionName: "create_recurring_event",
                success: false,
                message: "Invalid start time format",
                details: nil
            )
        }
        
        // Parse recurrence rule
        guard let recurrenceRule = RecurrenceRule.from(expression: recurrenceStr) else {
            return FunctionCallResult(
                functionName: "create_recurring_event",
                success: false,
                message: "Invalid recurrence pattern",
                details: nil
            )
        }
        
        // Parse optional end date for recurrence
        var recurrenceEndDate: Date?
        if let endDateStr = arguments["endDate"] as? String {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
            recurrenceEndDate = dateFormatter.date(from: endDateStr)
        }
        
        // Calculate end time based on duration
        let endTime = Calendar.current.date(byAdding: .minute, value: duration, to: startTime)!
        
        // Generate recurrence ID for all events in this series
        let recurrenceID = UUID()
        
        // Create the first event and store recurrence rule
        let categoryName = arguments["category"] as? String
        let category = scheduleManager.categories.first { $0.name == categoryName }
        
        let result = scheduleManager.createEvent(
            title: title,
            startTime: startTime,
            endTime: endTime,
            category: category,
            notes: arguments["notes"] as? String,
            location: arguments["location"] as? String,
            isAllDay: false,
            recurrenceRule: recurrenceRule.ruleString,
            recurrenceID: recurrenceID,
            recurrenceEndDate: recurrenceEndDate
        )
        
        switch result {
        case .success(let event):
            // Generate next occurrences (up to 10 for preview)
            let nextOccurrences = recurrenceRule.nextOccurrences(after: startTime, limit: 10)
            
            var createdCount = 1 // First event already created
            
            // Create the recurring instances
            for nextDate in nextOccurrences {
                let nextEndTime = Calendar.current.date(byAdding: .minute, value: duration, to: nextDate)!
                
                let _ = scheduleManager.createEvent(
                    title: title,
                    startTime: nextDate,
                    endTime: nextEndTime,
                    category: category,
                    notes: arguments["notes"] as? String,
                    location: arguments["location"] as? String,
                    isAllDay: false,
                    recurrenceRule: recurrenceRule.ruleString,
                    recurrenceID: recurrenceID,
                    recurrenceEndDate: recurrenceEndDate
                )
                createdCount += 1
            }
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateStyle = .none
            timeFormatter.timeStyle = .short
            
            return FunctionCallResult(
                functionName: "create_recurring_event",
                success: true,
                message: "Created recurring event '\(title)' \(recurrenceRule.naturalDescription)",
                details: [
                    "First occurrence": "\(timeFormatter.string(from: startTime))",
                    "Duration": "\(duration) minutes",
                    "Created": "\(createdCount) occurrences",
                    "Pattern": recurrenceRule.naturalDescription
                ]
            )
            
        case .failure(let error):
            return FunctionCallResult(
                functionName: "create_recurring_event",
                success: false,
                message: error.localizedDescription,
                details: nil
            )
        }
    }
    
    private func suggestSchedule(with arguments: [String: Any]) async -> FunctionCallResult {
        // This is a more complex function that would analyze the schedule
        // For now, return a simple suggestion
        let events = scheduleManager.eventsForToday()
        
        if events.isEmpty {
            return FunctionCallResult(
                functionName: "suggest_schedule",
                success: true,
                message: "Generated suggestions for open day",
                details: [
                    "9:00 AM - 11:00 AM": "Deep Work",
                    "2:00 PM - 3:30 PM": "Project Time",
                    "4:00 PM - 5:00 PM": "Email & Admin"
                ]
            )
        }
        
        // Find gaps in schedule
        var suggestions: [String: String] = [:]
        let calendar = Calendar.current
        let now = Date()
        
        // Check morning availability
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        let hasMorningEvent = events.contains { event in
            guard let start = event.startTime else { return false }
            return start < calendar.date(byAdding: .hour, value: 3, to: morning)!
        }
        
        if !hasMorningEvent {
            suggestions["9:00 AM - 11:00 AM"] = "Prime time for deep work"
        }
        
        return FunctionCallResult(
            functionName: "suggest_schedule",
            success: true,
            message: "Generated suggestions",
            details: suggestions.isEmpty ? ["Status": "Your schedule is well-optimized!"] : suggestions
        )
    }
    
    // MARK: - Error Handling
    
    private func handleOpenAIError(_ error: OpenAIError) {
        let errorMessage = ChatMessage(
            content: "",
            sender: .assistant,
            timestamp: Date(),
            error: error.errorDescription ?? "An error occurred"
        )
        messages.append(errorMessage)
    }
    
    private func handleGenericError(_ error: Error) {
        let errorMessage = ChatMessage(
            content: "",
            sender: .assistant,
            timestamp: Date(),
            error: "Failed to connect. Please check your internet connection and try again."
        )
        messages.append(errorMessage)
    }
    
    private func handleStreamingError(_ error: Error, messageId: UUID) {
        finalizeStreamingMessage(id: messageId)
        
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].error = "Connection interrupted. Please try again."
        }
    }
    
    // MARK: - Event Preview Helpers
    
    private func createEventPreview(from result: FunctionCallResult, functionName: String) -> EventPreview? {
        guard let details = result.details,
              let timeStr = details["Time"] else {
            return nil
        }
        
        // Parse the event title from the message
        let title = result.message.replacingOccurrences(of: "Created '", with: "")
            .replacingOccurrences(of: "Updated '", with: "")
            .replacingOccurrences(of: "'", with: "")
            .components(separatedBy: " ⚠️").first ?? "Event"
        
        // Determine icon based on category
        let category = details["Category"] ?? ""
        let icon = getIconForCategory(category)
        
        // Check if multi-day (simple check - if time contains "-" with dates)
        let isMultiDay = timeStr.contains(" - ") && timeStr.contains("/")
        
        return EventPreview(
            id: UUID().uuidString,
            icon: icon,
            title: title,
            timeDescription: timeStr,
            location: details["Location"],
            category: category,
            isMultiDay: isMultiDay,
            dayCount: 1,
            dayBreakdown: nil,
            actions: functionName == "create_event" ? [.edit, .delete, .complete] : [.edit, .delete]
        )
    }
    
    private func createMultipleEventsPreview(from result: FunctionCallResult) -> [EventListItem]? {
        // Parse created events from the result message
        guard result.message.contains("created"),
              let details = result.details else { return nil }
        
        var events: [EventListItem] = []
        
        // Check if we have the eventList with times
        if let eventList = details["eventList"] {
            // Parse "Title at Time, Title at Time" format
            let eventStrings = eventList.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            
            for eventString in eventStrings {
                if let atRange = eventString.range(of: " at ") {
                    let title = String(eventString[..<atRange.lowerBound])
                    let time = String(eventString[atRange.upperBound...])
                    
                    events.append(EventListItem(
                        id: UUID().uuidString,
                        time: time,
                        title: title,
                        isCompleted: false
                    ))
                }
            }
        } else if let createdList = details["created"] {
            // Fallback to just titles
            let eventTitles = createdList.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            
            for (index, title) in eventTitles.enumerated() {
                events.append(EventListItem(
                    id: UUID().uuidString,
                    time: "Time \(index + 1)",
                    title: title,
                    isCompleted: false
                ))
            }
        }
        
        return events.isEmpty ? nil : events
    }
    
    private func getIconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "work":
            return "💼"
        case "personal":
            return "🏠"
        case "health":
            return "💪"
        case "learning":
            return "📚"
        case "meeting":
            return "👥"
        default:
            return "📅"
        }
    }
    
    private func createBulkActionPreview(from result: FunctionCallResult, functionName: String) -> BulkActionPreview? {
        // Extract count from result message
        let message = result.message
        var affectedCount = 0
        var dateRange: String?
        
        // Parse count from message like "Successfully deleted 5 events"
        if let range = message.range(of: #"(\d+) event"#, options: .regularExpression) {
            let countStr = String(message[range]).components(separatedBy: " ").first ?? "0"
            affectedCount = Int(countStr) ?? 0
        }
        
        // Parse date range from message
        if message.contains("from") && message.contains("to") {
            if let fromRange = message.range(of: "from "),
               let toRange = message.range(of: " to ") {
                let startIdx = fromRange.upperBound
                let endIdx = message.index(toRange.upperBound, offsetBy: 10)
                if endIdx <= message.endIndex {
                    dateRange = String(message[startIdx..<endIdx])
                }
            }
        } else if let onRange = message.range(of: "on ") {
            let startIdx = onRange.upperBound
            let endIdx = message.index(startIdx, offsetBy: 10, limitedBy: message.endIndex) ?? message.endIndex
            dateRange = String(message[startIdx..<endIdx])
        }
        
        // Determine action details
        let (icon, title, description, warningLevel) = getActionDetails(for: functionName, count: affectedCount)
        
        // For successful operations, show undo option
        let actions: [BulkActionPreview.BulkAction] = result.success ? [.undo] : [.confirm, .cancel]
        
        return BulkActionPreview(
            id: UUID().uuidString,
            action: functionName,
            icon: icon,
            title: title,
            description: description,
            affectedCount: affectedCount,
            dateRange: dateRange,
            warningLevel: warningLevel,
            actions: actions
        )
    }
    
    private func getActionDetails(for functionName: String, count: Int) -> (icon: String, title: String, description: String, warningLevel: BulkActionPreview.WarningLevel) {
        switch functionName {
        case "delete_event":
            return ("🗑️", "Delete Event", "Remove this event from your calendar", .caution)
        case "delete_all_events":
            return ("🗑️", "Delete \(count) Events", "Permanently remove these events", .critical)
        case "update_event":
            return ("✏️", "Update Event", "Modify event details", .normal)
        case "update_all_events":
            return ("✏️", "Update \(count) Events", "Apply changes to multiple events", .caution)
        case "mark_all_complete":
            return ("✅", "Complete \(count) Events", "Mark these events as completed", .normal)
        default:
            return ("📅", "Modify Events", "Change calendar events", .normal)
        }
    }
    
    func handleBulkAction(_ action: BulkActionPreview.BulkAction, for messageId: UUID) {
        guard let messageIndex = messages.firstIndex(where: { $0.id == messageId }),
              let preview = messages[messageIndex].bulkActionPreview else { return }
        
        switch action {
        case .confirm:
            // The action was already performed, just update UI
            messages[messageIndex].bulkActionPreview = nil
        case .cancel:
            // Remove the preview
            messages[messageIndex].bulkActionPreview = nil
        case .undo:
            // Implement undo functionality
            inputText = "Undo the last action"
            sendMessage()
        }
    }
    
    deinit {
        streamingTask?.cancel()
    }
}