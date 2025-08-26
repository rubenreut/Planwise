import SwiftUI
import Combine
import Speech
import AVFoundation
import UIKit
import CoreData

// MARK: - Chat View Model (Refactored as Facade)
// This class acts as a facade, delegating to specialized ViewModels
// All implementation details have been moved to the sub-ViewModels

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties (Preserved for backward compatibility)
    
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
    @Published var showDocumentPicker: Bool = false
    @Published var selectedFileURL: URL?
    @Published var selectedFileName: String?
    @Published var selectedFileData: Data?
    @Published var selectedFileExtension: String?
    @Published var selectedFileText: String?
    @Published var pdfFileName: String?
    @Published var pdfPageCount: Int = 1
    @Published var isRecordingVoice: Bool = false
    @Published var acceptedEventIds: Set<String> = []
    @Published var deletedEventIds: Set<String> = []
    @Published var acceptedMultiEventMessageIds: Set<UUID> = []
    @Published var completedBulkActionIds: Set<String> = []
    @Published var isRateLimited: Bool = false
    @Published var rateLimitResetTime: Date?
    
    // MARK: - Private Properties
    
    private var userName: String {
        UserDefaults.standard.string(forKey: "userDisplayName") ?? "User"
    }
    
    // Dependencies
    private let openAIService: OpenAIService
    private let scheduleManager: ScheduleManaging
    private let taskManager: TaskManaging
    private let habitManager: HabitManaging
    private let goalManager: GoalManager
    private let subscriptionManager = SubscriptionManager.shared
    
    // Specialized ViewModels
    private let conversationViewModel: ChatConversationViewModel
    private let voiceViewModel: VoiceRecordingViewModel
    private let attachmentViewModel: AttachmentViewModel
    private let bulkOperationsViewModel: BulkOperationsViewModel
    private let entityViewModel: EventTaskHabitViewModel
    private let aiServiceViewModel: AIServiceViewModel
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(openAIService: OpenAIService? = nil, 
         scheduleManager: ScheduleManaging? = nil, 
         taskManager: TaskManaging? = nil, 
         habitManager: HabitManaging? = nil, 
         goalManager: GoalManager? = nil) {
        
        print("🔴 ChatViewModel init started")
        
        // Initialize dependencies
        self.openAIService = openAIService ?? DependencyContainer.shared.openAIService
        self.scheduleManager = scheduleManager ?? DependencyContainer.shared.scheduleManager
        self.taskManager = taskManager ?? DependencyContainer.shared.taskManager
        self.habitManager = habitManager ?? DependencyContainer.shared.habitManager
        self.goalManager = goalManager ?? DependencyContainer.shared.goalManager
        
        print("🔴 ChatViewModel dependencies initialized")
        
        // Initialize specialized ViewModels
        self.conversationViewModel = ChatConversationViewModel(userName: UserDefaults.standard.string(forKey: "userDisplayName"))
        print("🔴 ChatViewModel conversationViewModel created")
        
        self.voiceViewModel = VoiceRecordingViewModel()
        print("🔴 ChatViewModel voiceViewModel created")
        
        self.attachmentViewModel = AttachmentViewModel()
        print("🔴 ChatViewModel attachmentViewModel created")
        
        self.bulkOperationsViewModel = BulkOperationsViewModel(
            scheduleManager: self.scheduleManager,
            taskManager: self.taskManager,
            habitManager: self.habitManager,
            goalManager: self.goalManager,
            context: PersistenceController.shared.container.viewContext
        )
        print("🔴 ChatViewModel bulkOperationsViewModel created")
        
        self.entityViewModel = EventTaskHabitViewModel(
            scheduleManager: self.scheduleManager,
            taskManager: self.taskManager,
            habitManager: self.habitManager,
            goalManager: self.goalManager,
            context: PersistenceController.shared.container.viewContext
        )
        print("🔴 ChatViewModel entityViewModel created")
        
        self.aiServiceViewModel = AIServiceViewModel(
            openAIService: self.openAIService,
            context: PersistenceController.shared.container.viewContext,
            scheduleManager: self.scheduleManager,
            taskManager: self.taskManager,
            goalManager: self.goalManager,
            habitManager: self.habitManager
        )
        print("🔴 ChatViewModel aiServiceViewModel created")
        
        // Skip property bindings to prevent crash - accessing sub-ViewModels directly
        print("🔴 ChatViewModel skipping property bindings to prevent crash")
        
        // Initialize messages
        loadPersistedMessages()
        if messages.isEmpty {
            setupInitialGreeting()
        }
        
        print("🔴 ChatViewModel init complete")
    }
    
    // MARK: - Public Methods (Facade Interface)
    
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
              selectedImage != nil || 
              selectedFileData != nil else { return }
        
        // Check rate limit
        guard !isRateLimited else { return }
        
        // Check subscription
        let hasImage = selectedImage != nil || selectedFileData != nil
        guard subscriptionManager.canSendMessage(withImage: hasImage) else {
            showPaywall = true
            return
        }
        
        // Add user message
        let userMessage = conversationViewModel.addUserMessage(
            inputText,
            attachmentInfo: selectedFileName
        )
        messages.append(userMessage)
        
        // Clear input
        let messageContent = inputText
        let image = selectedImage
        inputText = ""
        selectedImage = nil
        selectedFileName = nil
        selectedFileData = nil
        
        // Send to AI
        AsyncTask {
            await sendToAI(content: messageContent, image: image)
        }
    }
    
    func handleImageAttachment() {
        guard subscriptionManager.canUploadImage() else {
            showPaywall = true
            return
        }
        showImagePicker = true
    }
    
    func handleCameraAttachment() {
        guard subscriptionManager.canUploadImage() else {
            showPaywall = true
            return
        }
        showCamera = true
    }
    
    func handleFileAttachment() {
        guard subscriptionManager.canUploadImage() else {
            showPaywall = true
            return
        }
        showDocumentPicker = true
    }
    
    func processSelectedImage(_ image: UIImage) {
        selectedImage = image
        attachmentViewModel.handleImageSelection(image)
        
        // Copy processed data from attachment ViewModel
        selectedFileName = attachmentViewModel.selectedFileName
        pdfFileName = attachmentViewModel.pdfFileName
        pdfPageCount = attachmentViewModel.pdfPageCount
    }
    
    func processSelectedFile(_ url: URL) {
        attachmentViewModel.processSelectedFile(url)
        
        // Copy processed data to main ViewModel
        selectedFileURL = attachmentViewModel.selectedFileURL
        selectedFileName = attachmentViewModel.selectedFileName
        selectedFileData = attachmentViewModel.selectedFileData
        selectedFileExtension = attachmentViewModel.selectedFileExtension
        selectedFileText = attachmentViewModel.selectedFileText
        selectedImage = attachmentViewModel.selectedImage
        pdfFileName = attachmentViewModel.pdfFileName
        pdfPageCount = attachmentViewModel.pdfPageCount
    }
    
    func handleVoiceInput() {
        isRecordingVoice.toggle()
        
        _Concurrency.Task {
            if isRecordingVoice {
                await voiceViewModel.startRecording()
            } else {
                voiceViewModel.stopRecording()
                if !voiceViewModel.transcribedText.isEmpty {
                    inputText = voiceViewModel.transcribedText
                    voiceViewModel.transcribedText = ""
                }
            }
        }
    }
    
    func handleEventAction(eventId: String, action: EventAction) {
        let eventPreview = messages.first { $0.eventPreview?.id == eventId }?.eventPreview
        
        _Concurrency.Task {
            await entityViewModel.handleEventAction(eventId: eventId, action: action, preview: eventPreview)
        }
    }
    
    func handleMultiEventAction(_ action: MultiEventAction, messageId: UUID) {
        let events = messages.first { $0.id == messageId }?.multipleEventsPreview ?? []
        bulkOperationsViewModel.handleMultiEventAction(action, events: events, messageId: messageId)
    }
    
    func handleBulkAction(_ action: BulkActionPreview.BulkAction, preview: BulkActionPreview, messageId: String) {
        bulkOperationsViewModel.handleBulkAction(action, preview: preview, messageId: messageId)
    }
    
    func clearConversation() {
        conversationViewModel.clearConversation()
        messages = []
        setupInitialGreeting()
    }
    
    func removeAttachment() {
        selectedImage = nil
        selectedFileName = nil
        selectedFileData = nil
        selectedFileExtension = nil
        selectedFileText = nil
        pdfFileName = nil
        pdfPageCount = 1
        
        attachmentViewModel.clearSelection()
    }
    
    // MARK: - Private Helper Methods
    
    private func sendToAI(content: String, image: UIImage? = nil) async {
        showTypingIndicator()
        
        do {
            // Build messages for AI
            let requestMessages = buildRequestMessages(content: content, image: image)
            
            // Send to AI through AIServiceViewModel
            let response = try await aiServiceViewModel.sendMessageToAI(
                messages: requestMessages,
                withFunctions: true
            )
            
            hideTypingIndicator()
            messages.append(response)
            
        } catch {
            hideTypingIndicator()
            let errorMessage = ChatMessage(
                content: "Sorry, I encountered an error: \(error.localizedDescription)",
                sender: .assistant,
                timestamp: Date(),
                error: error.localizedDescription
            )
            messages.append(errorMessage)
        }
    }
    
    private func buildRequestMessages(content: String, image: UIImage?) -> [ChatRequestMessage] {
        var messages: [ChatRequestMessage] = []
        
        // Add system context
        let systemMessage = ChatRequestMessage(
            role: "system",
            content: "You are a helpful AI assistant for the Momentum productivity app."
        )
        messages.append(systemMessage)
        
        // Add conversation history
        messages.append(contentsOf: conversationViewModel.getConversationHistory())
        
        // Add current message
        var userContent = content
        if let image = image {
            // Add image context
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                let base64String = imageData.base64EncodedString()
                userContent += "\n[Image attached: base64 encoded]"
                // In real implementation, handle image properly
            }
        }
        
        let userMessage = ChatRequestMessage(
            role: "user",
            content: userContent
        )
        messages.append(userMessage)
        
        return messages
    }
    
    private func showTypingIndicator() {
        isTypingIndicatorVisible = true
        conversationViewModel.showTypingIndicator()
    }
    
    private func hideTypingIndicator() {
        isTypingIndicatorVisible = false
        conversationViewModel.hideTypingIndicator()
    }
    
    private func loadPersistedMessages() {
        // Simple loading - full implementation in conversationViewModel
        if let messageData = UserDefaults.standard.array(forKey: "ChatMessages") as? [[String: Any]] {
            messages = messageData.compactMap { data in
                guard let content = data["content"] as? String,
                      let senderString = data["sender"] as? String else {
                    return nil
                }
                
                let sender: ChatSender = senderString == "user" ? 
                    .user(name: userName) : .assistant
                    
                return ChatMessage(
                    content: content,
                    sender: sender,
                    timestamp: Date()
                )
            }
        }
    }
    
    private func setupInitialGreeting() {
        let greeting = ChatMessage(
            content: "Hello! I'm your Momentum Assistant. I can help you manage your schedule, create events, tasks, habits, and goals. How can I assist you today?",
            sender: .assistant,
            timestamp: Date()
        )
        messages.append(greeting)
    }
    
    private func saveMessages() {
        // Simple save - could be enhanced
        let messagesToSave = Array(messages.suffix(10))
        let messageData = messagesToSave.compactMap { message -> [String: Any]? in
            guard message.error == nil else { return nil }
            return [
                "content": message.content,
                "sender": message.sender.isUser ? "user" : "assistant",
                "timestamp": message.timestamp.timeIntervalSince1970
            ]
        }
        UserDefaults.standard.set(messageData, forKey: "ChatMessages")
    }
    
    // MARK: - Computed Properties for Compatibility
    
    var isMultiEventAccepted: Bool {
        !acceptedMultiEventMessageIds.isEmpty
    }
    
    var isBulkActionCompleted: Bool {
        !completedBulkActionIds.isEmpty
    }
}