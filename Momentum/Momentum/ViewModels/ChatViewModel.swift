import Foundation
import SwiftUI
import Combine
import Speech
import AVFoundation
import CoreData
import PhotosUI
import UIKit
import PDFKit

// MARK: - Chat View Model (Refactored as Facade)
// This class now acts as a facade, delegating to specialized ViewModels
// while maintaining the exact same public interface for backward compatibility

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
    
    // Original dependencies (kept for now)
    private let openAIService: OpenAIService
    private let scheduleManager: ScheduleManaging
    private let taskManager: TaskManaging
    private let habitManager: HabitManaging
    private let goalManager: GoalManager
    private let subscriptionManager = SubscriptionManager.shared
    
    // New specialized ViewModels
    private let conversationViewModel: ChatConversationViewModel
    private let voiceViewModel: VoiceRecordingViewModel
    private let attachmentViewModel: AttachmentViewModel
    private let bulkOperationsViewModel: BulkOperationsViewModel
    private let entityViewModel: EventTaskHabitViewModel
    private let aiServiceViewModel: AIServiceViewModel
    
    private var cancellables = Set<AnyCancellable>()
    private var streamingTask: AsyncTask<Void, Never>?
    private var conversationHistory: [ChatRequestMessage] = []
    private var rateLimitTimer: Timer?
    
    // MARK: - Mathematical Constants
    
    private let φ: Double = 1.618033988749895 // Golden ratio
    
    // MARK: - AI Coordinator
    
    private lazy var aiCoordinator: AICoordinator = {
        return AICoordinator(
            context: PersistenceController.shared.container.viewContext,
            scheduleManager: self.scheduleManager,
            taskManager: (self.taskManager as? TaskManager) ?? TaskManager(persistence: PersistenceController.shared),
            goalManager: self.goalManager,
            habitManager: self.habitManager
        )
    }()
    
    // MARK: - Simplified Function Definitions
    
    private func getSimplifiedTools() -> [[String: Any]] {
        return [
            [
                "type": "function",
                "function": [
                    "name": "manage_events",
                    "description": "Manage events - create, update, delete, list events. Handles single and bulk operations. Smart scheduling available.",
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
                                "description": "Parameters for the action. For create/update: title, startTime, endTime, location, notes, isAllDay, categoryId. For list: date, categoryId. For delete: id or ids array. For bulk operations, pass items array."
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
                                "description": "Parameters for the action. For create/update: title, description, dueDate, priority, estimatedMinutes, goalId, categoryId, tags, isCompleted. For list: completed, goalId, categoryId, dueDate. For delete: id or ids array. For bulk operations, pass items array."
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
                                "description": "Parameters for the action. For create/update: name, description, frequency, targetCount, reminderTime, categoryId, color, icon, isActive. For list: active, frequency, categoryId. For log/complete: id (habit ID). For delete: id or ids array. For bulk operations, pass items array."
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
                                "description": "Parameters for the action. For goals: title, description, targetDate, priority, categoryId, unit, targetValue, milestones (array). For milestones: goalId (for create), id/milestoneId (for update/delete), title, description, dueDate. For delete: id or ids array. For bulk operations, pass items array."
                            ]
                        ],
                        "required": ["action", "parameters"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
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
        ]
    }
    
    // MARK: - Initialization
    
    init(openAIService: OpenAIService? = nil, scheduleManager: ScheduleManaging? = nil, taskManager: TaskManaging? = nil, habitManager: HabitManaging? = nil, goalManager: GoalManager? = nil) {
        print("🔴 ChatViewModel init started")
        
        // Initialize original dependencies
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
        
        // Skip property bindings for now - we'll access sub-ViewModels directly
        print("🔴 ChatViewModel skipping property bindings to prevent crash")
        
        // Load messages through conversation ViewModel
        print("🔴 ChatViewModel loading persisted messages")
        loadPersistedMessages()
        if messages.isEmpty {
            print("🔴 ChatViewModel setting up initial greeting")
            setupInitialGreeting()
        }
        print("🔴 ChatViewModel observing rate limit info")
        observeRateLimitInfo()
        print("🔴 ChatViewModel init complete")
    }
    
    // MARK: - Property Bindings
    
    private func setupPropertyBindings() {
        // Use sink instead of assign to avoid crashes and retain cycles
        
        // Sync conversation properties
        conversationViewModel.$messages
            .sink { [weak self] newMessages in
                self?.messages = newMessages
            }
            .store(in: &cancellables)
        
        conversationViewModel.$inputText
            .sink { [weak self] value in
                self?.inputText = value
            }
            .store(in: &cancellables)
        
        conversationViewModel.$isTypingIndicatorVisible
            .sink { [weak self] value in
                self?.isTypingIndicatorVisible = value
            }
            .store(in: &cancellables)
        
        conversationViewModel.$isLoading
            .sink { [weak self] value in
                self?.isLoading = value
            }
            .store(in: &cancellables)
        
        // Sync voice properties
        voiceViewModel.$isRecording
            .sink { [weak self] value in
                self?.isRecordingVoice = value
            }
            .store(in: &cancellables)
        
        // Sync attachment properties
        attachmentViewModel.$selectedImage
            .sink { [weak self] value in
                self?.selectedImage = value
            }
            .store(in: &cancellables)
        
        attachmentViewModel.$selectedFileURL
            .sink { [weak self] value in
                self?.selectedFileURL = value
            }
            .store(in: &cancellables)
        
        attachmentViewModel.$selectedFileName
            .sink { [weak self] value in
                self?.selectedFileName = value
            }
            .store(in: &cancellables)
        
        attachmentViewModel.$selectedFileData
            .sink { [weak self] value in
                self?.selectedFileData = value
            }
            .store(in: &cancellables)
        
        attachmentViewModel.$selectedFileExtension
            .sink { [weak self] value in
                self?.selectedFileExtension = value
            }
            .store(in: &cancellables)
        
        attachmentViewModel.$selectedFileText
            .sink { [weak self] value in
                self?.selectedFileText = value
            }
            .store(in: &cancellables)
        
        attachmentViewModel.$pdfFileName
            .sink { [weak self] value in
                self?.pdfFileName = value
            }
            .store(in: &cancellables)
        
        attachmentViewModel.$pdfPageCount
            .sink { [weak self] value in
                self?.pdfPageCount = value
            }
            .store(in: &cancellables)
        
        attachmentViewModel.$showImagePicker
            .sink { [weak self] value in
                self?.showImagePicker = value
            }
            .store(in: &cancellables)
        
        attachmentViewModel.$showCamera
            .sink { [weak self] value in
                self?.showCamera = value
            }
            .store(in: &cancellables)
        
        attachmentViewModel.$showDocumentPicker
            .sink { [weak self] value in
                self?.showDocumentPicker = value
            }
            .store(in: &cancellables)
        
        // Sync AI service properties
        aiServiceViewModel.$isRateLimited
            .sink { [weak self] value in
                self?.isRateLimited = value
            }
            .store(in: &cancellables)
        
        aiServiceViewModel.$rateLimitResetTime
            .sink { [weak self] value in
                self?.rateLimitResetTime = value
            }
            .store(in: &cancellables)
        
        aiServiceViewModel.$rateLimitInfo
            .sink { [weak self] value in
                self?.rateLimitInfo = value
            }
            .store(in: &cancellables)
        
        aiServiceViewModel.$showRateLimitWarning
            .sink { [weak self] value in
                self?.showRateLimitWarning = value
            }
            .store(in: &cancellables)
        
        aiServiceViewModel.$showPaywall
            .sink { [weak self] value in
                self?.showPaywall = value
            }
            .store(in: &cancellables)
        
        aiServiceViewModel.$streamingMessageId
            .sink { [weak self] value in
                self?.streamingMessageId = value
            }
            .store(in: &cancellables)
        
        // Sync entity management properties
        entityViewModel.$acceptedEventIds
            .sink { [weak self] value in
                self?.acceptedEventIds = value
            }
            .store(in: &cancellables)
        
        entityViewModel.$deletedEventIds
            .sink { [weak self] value in
                self?.deletedEventIds = value
            }
            .store(in: &cancellables)
        
        // Sync bulk operations properties
        bulkOperationsViewModel.$acceptedMultiEventMessageIds
            .sink { [weak self] value in
                self?.acceptedMultiEventMessageIds = value
            }
            .store(in: &cancellables)
        
        bulkOperationsViewModel.$completedBulkActionIds
            .sink { [weak self] value in
                self?.completedBulkActionIds = value
            }
            .store(in: &cancellables)
        
        // Two-way sync for input text
        $inputText
            .sink { [weak self] value in
                self?.conversationViewModel.inputText = value
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func sendMessage() {
        
        // Check if rate limited
        if isRateLimited {
            return
        }
        
        // Allow sending if there's text OR an attachment
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImage != nil || selectedFileData != nil else {
            return
        }
        
        // Check if user can send message
        let hasImage = selectedImage != nil || selectedFileData != nil
        let imageCount = pdfFileName != nil ? pdfPageCount : (hasImage ? 1 : 0)
        guard subscriptionManager.canSendMessage(withImage: hasImage, imageCount: imageCount) else {
            showPaywall = true
            return
        }
        
        // Build message content
        let messageContent = inputText
        
        // Determine what file info to show
        var fileName: String? = nil
        var fileExtension: String? = nil
        
        if pdfFileName != nil, selectedImage != nil {
            // PDF converted to image
            fileName = pdfFileName
            fileExtension = "pdf"
        } else if let selectedFileName = selectedFileName, let selectedFileExtension = selectedFileExtension, selectedFileData != nil {
            // Other file types
            fileName = selectedFileName
            fileExtension = selectedFileExtension
        }
        
        // Add user message with attachments
        let userMessage = ChatMessage(
            content: messageContent,
            sender: .user(name: userName),
            timestamp: Date(),
            attachedImage: selectedImage,
            attachedFileName: fileName,
            attachedFileExtension: fileExtension
        )
        messages.append(userMessage)
        saveMessages()
        
        // Increment message count BEFORE clearing values
        let hasImageAttachment = selectedImage != nil || pdfFileName != nil || selectedFileData != nil
        let imageCountForIncrement = pdfFileName != nil ? pdfPageCount : (hasImageAttachment ? 1 : 0)
        subscriptionManager.incrementMessageCount(isImageMessage: hasImageAttachment, imageCount: imageCountForIncrement)
        
        // Handle different attachment types
        if let image = selectedImage {
            // Handle image attachment
            var imagePrompt = inputText
            if pdfFileName != nil {
                // This is a PDF converted to image - use same prompt as regular images
                imagePrompt = inputText.isEmpty ? "What's in this image?" : inputText
            } else {
                // Regular image
                imagePrompt = inputText.isEmpty ? "Please analyze this image" : inputText
            }
            
            // Resize image if too large
            let maxDimension: CGFloat = 2048
            let resizedImage: UIImage
            if image.size.width > maxDimension || image.size.height > maxDimension {
                let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
                let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
                UIGraphicsEndImageContext()
            } else {
                resizedImage = image
            }
            
            // Use lower compression for PDFs to ensure readability
            let compressionQuality: CGFloat = pdfFileName != nil ? 0.7 : 0.5
            let imageData = resizedImage.jpegData(compressionQuality: compressionQuality)
            
            conversationHistory.append(ChatRequestMessage(
                role: "user",
                content: imagePrompt,
                imageData: imageData
            ))
            selectedImage = nil
            pdfFileName = nil
            pdfPageCount = 1
        } else if selectedFileData != nil,
                  let fileExtension = selectedFileExtension,
                  let fileName = selectedFileName {
            // Handle non-PDF document attachments
            var messageContent = inputText.isEmpty ? "I've attached a \(fileExtension.uppercased()) document: \(fileName)" : inputText
            messageContent += "\n\n[Note: This file type cannot be directly analyzed. Please convert to PDF or image format.]"
            
            // Send as regular text message
            conversationHistory.append(ChatRequestMessage(
                role: "user",
                content: messageContent
            ))
            clearFileAttachment()
        } else {
            // Regular text message
            // For requests about goals/tasks/habits, prepend the actual data
            var enhancedMessage = inputText
            let lowercaseInput = inputText.lowercased()
            
            if lowercaseInput.contains("goal") || lowercaseInput.contains("schedule") {
                let goals = goalManager.goals.filter { !$0.isCompleted }
                if !goals.isEmpty {
                    var goalInfo = "My current goals: "
                    for goal in goals {
                        let progress = Int(goal.progress * 100)
                        let dueInfo = goal.targetDate.map { " (by \(DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .none)))" } ?? ""
                        goalInfo += "\(goal.title ?? "") - \(progress)% complete\(dueInfo); "
                    }
                    enhancedMessage = goalInfo + "\n\n" + inputText
                }
            }
            
            conversationHistory.append(ChatRequestMessage(
                role: "user",
                content: enhancedMessage
            ))
        }
        
        // Clear input
        inputText = ""
        
        // Cancel any existing streaming
        streamingTask?.cancel()
        
        // Send to OpenAI
        AsyncTask {
            await sendToOpenAI()
        }
    }
    
    func retryLastMessage() {
        // Find the last user message
        guard messages.last(where: { $0.sender.isUser }) != nil else { return }
        
        // Remove any error messages after it
        if let lastUserIndex = messages.lastIndex(where: { $0.sender.isUser }) {
            messages = Array(messages.prefix(lastUserIndex + 1))
        }
        
        // Retry sending
        AsyncTask {
            await sendToOpenAI()
        }
    }
    
    func handleImageAttachment() {
        // Check if user can upload images
        guard subscriptionManager.canUploadImage() else {
            showPaywall = true
            return
        }
        
        // Set on main view model (will sync to attachment view model if needed)
        showImagePicker = true
    }
    
    func handleCameraAttachment() {
        // Check if user can upload images
        guard subscriptionManager.canUploadImage() else {
            showPaywall = true
            return
        }
        
        // Delegate to attachment view model
        attachmentViewModel.showCamera = true
    }
    
    func processSelectedImage(_ image: UIImage) {
        // Update the main ViewModel's property
        selectedImage = image
        
        // Also delegate to attachment view model for processing
        attachmentViewModel.handleImageSelection(image)
        
        // If there's text in the input, send with the text
        if !inputText.isEmpty {
            // Convert image to base64 for AI analysis
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
            let base64String = imageData.base64EncodedString()
            
            // Add user message with image and custom text
            let userMessage = ChatMessage(
                content: inputText,
                sender: .user(name: userName),
                timestamp: Date(),
                attachedImage: image
            )
            messages.append(userMessage)
            
            // Clear input and image
            inputText = ""
            selectedImage = nil
            
            // Send to AI with image context
            AsyncTask {
                await sendImageToAI(base64Image: base64String)
            }
        }
        // Otherwise just store the image for when user types and sends
    }
    
    func handleFileAttachment() {
        // Check if user can upload files (same as images for free users)
        guard subscriptionManager.canUploadImage() else {
            showPaywall = true
            return
        }
        
        // Set on main view model (will sync to attachment view model if needed)
        showDocumentPicker = true
    }
    
    func processSelectedFile(_ url: URL) {
        // Delegate to attachment view model for processing
        attachmentViewModel.processSelectedFile(url)
        
        // Copy the processed data to main ViewModel properties
        selectedFileURL = attachmentViewModel.selectedFileURL
        selectedFileName = attachmentViewModel.selectedFileName
        selectedFileData = attachmentViewModel.selectedFileData
        selectedFileExtension = attachmentViewModel.selectedFileExtension
        selectedFileText = attachmentViewModel.selectedFileText
        selectedImage = attachmentViewModel.selectedImage
        pdfFileName = attachmentViewModel.pdfFileName
        pdfPageCount = attachmentViewModel.pdfPageCount
        
        AsyncTask { @MainActor in
            // Start accessing the security-scoped resource
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                // Process the file based on its type
                let fileExtension = url.pathExtension.lowercased()
                
                // Try to read the file data
                let fileData = try Data(contentsOf: url)
                let fileSizeInMB = Double(fileData.count) / (1024 * 1024)
                
                // Check file size (limit to 10MB for processing)
                if fileSizeInMB > 10 {
                    let message = ChatMessage(
                        content: "File is too large (\(String(format: "%.1f", fileSizeInMB)) MB). Please select a file smaller than 10 MB.",
                        sender: .assistant,
                        timestamp: Date()
                    )
                    messages.append(message)
                    saveMessages()
                    selectedFileURL = nil
                    selectedFileName = nil
                    return
                }
                
                // Process based on file type
                switch fileExtension {
                case "txt", "md", "csv", "json", "xml", "yaml", "yml":
                    // Text files - read and process content
                    if let content = String(data: fileData, encoding: .utf8) {
                        await processTextFile(content: content, fileName: selectedFileName ?? "file")
                    } else {
                        throw NSError(domain: "FileProcessing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to read file as text"])
                    }
                    
                case "pdf":
                    // Check PDF page count first
                    var pageCount = 1
                    if let pdfDoc = PDFDocument(url: url) {
                        pageCount = min(pdfDoc.pageCount, 10) // We process up to 10 pages
                        
                        // Check if user can send message with this many images
                        guard subscriptionManager.canSendMessage(withImage: true, imageCount: pageCount) else {
                            let message = ChatMessage(
                                content: "This PDF has \(pageCount) pages. You need \(pageCount) image credits but only have \(subscriptionManager.imageLimit - subscriptionManager.imageMessageCount) remaining today.",
                                sender: .assistant,
                                timestamp: Date()
                            )
                            messages.append(message)
                            selectedFileURL = nil
                            selectedFileName = nil
                            showPaywall = true
                            return
                        }
                    }
                    
                    // Convert PDF to image for GPT-4 Vision
                    if let pdfImage = convertPDFToImage(at: url) {
                        // Store as image with PDF context
                        selectedImage = pdfImage
                        pdfFileName = selectedFileName // Remember this was a PDF
                        pdfPageCount = pageCount // Store the page count
                        selectedFileURL = nil
                        selectedFileName = nil
                        selectedFileData = nil
                        selectedFileExtension = nil
                        
                        // Add a subtle info message for multi-page PDFs
                        if pageCount > 1 {
                            let infoMessage = ChatMessage(
                                content: "Processing \(pageCount) pages. This will use \(pageCount) of your daily image credits.",
                                sender: .assistant,
                                timestamp: Date()
                            )
                            messages.append(infoMessage)
                        }
                    } else {
                        let message = ChatMessage(
                            content: "Unable to process PDF. The file may be corrupted.",
                            sender: .assistant,
                            timestamp: Date()
                        )
                        messages.append(message)
                        selectedFileURL = nil
                        selectedFileName = nil
                    }
                    
                case "doc", "docx", "rtf":
                    // For other documents, just store the file info
                    selectedFileData = fileData
                    selectedFileExtension = fileExtension
                    // Don't send automatically - wait for user to type message and send
                    
                case "jpg", "jpeg", "png", "gif", "heic", "heif":
                    // Image files - convert to UIImage and process like camera/photo selection
                    if let image = UIImage(data: fileData) {
                        selectedImage = image
                        selectedFileURL = nil
                        selectedFileName = nil
                        // The existing image handling will take over
                    } else {
                        throw NSError(domain: "FileProcessing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to process image file"])
                    }
                    
                default:
                    // Unsupported file type
                    let message = ChatMessage(
                        content: "File type '.\(fileExtension)' is not supported. Supported formats: text files (.txt, .md, .csv, .json), documents (.pdf, .doc, .docx), and images (.jpg, .png, .gif).",
                        sender: .assistant,
                        timestamp: Date()
                    )
                    messages.append(message)
                    selectedFileURL = nil
                    selectedFileName = nil
                }
                
            } catch {
                let message = ChatMessage(
                    content: "Error processing file: \(error.localizedDescription)",
                    sender: .assistant,
                    timestamp: Date()
                )
                messages.append(message)
                selectedFileURL = nil
                selectedFileName = nil
            }
        }
    }
    
    @MainActor
    private func processTextFile(content: String, fileName: String) async {
        let truncatedContent = String(content.prefix(4000)) // Limit content length
        
        // Add user message with file content
        let userMessage = ChatMessage(
            content: "I've attached a file: \(fileName)\n\nContent:\n\(truncatedContent)",
            sender: .user(name: userName),
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // Clear file selection
        selectedFileURL = nil
        selectedFileName = nil
        
        // Send to AI for processing
        // Add to conversation history and send
        conversationHistory.append(ChatRequestMessage(
            role: "user",
            content: userMessage.content
        ))
        await sendToOpenAI()
    }
    
    func clearFileAttachment() {
        // Delegate to attachment view model
        attachmentViewModel.clearFileAttachment()
    }
    
    private func convertPDFToImage(at url: URL) -> UIImage? {
        
        guard let pdfDocument = PDFDocument(url: url) else {
            return nil
        }
        
        let pageCount = pdfDocument.pageCount
        let maxPages = min(pageCount, 10) // Process up to 10 pages
        
        var pageImages: [UIImage] = []
        
        // Convert each page to an image
        for pageIndex in 0..<maxPages {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            let pageBounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0 // High resolution
            let scaledBounds = CGRect(x: 0, y: 0,
                                      width: pageBounds.width * scale,
                                      height: pageBounds.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(scaledBounds.size, true, 1.0)
            guard let context = UIGraphicsGetCurrentContext() else {
                UIGraphicsEndImageContext()
                continue
            }
            
            // Fill with white background
            context.setFillColor(UIColor.white.cgColor)
            context.fill(scaledBounds)
            
            // Draw the PDF page with proper rotation handling
            context.saveGState()
            
            // Apply the page rotation
            let rotationAngle = page.rotation
            if rotationAngle != 0 {
                // Move to center, rotate, then move back
                context.translateBy(x: scaledBounds.width / 2, y: scaledBounds.height / 2)
                context.rotate(by: -CGFloat(rotationAngle) * .pi / 180.0)
                context.translateBy(x: -scaledBounds.width / 2, y: -scaledBounds.height / 2)
            }
            
            // Handle coordinate system flip for PDFs
            context.translateBy(x: 0, y: scaledBounds.height)
            context.scaleBy(x: scale, y: -scale)
            
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
            
            // Get the image
            if let pageImage = UIGraphicsGetImageFromCurrentImageContext() {
                pageImages.append(pageImage)
            }
            UIGraphicsEndImageContext()
        }
        
        
        // If no pages converted, return nil
        guard !pageImages.isEmpty else { return nil }
        
        // If only one page, return it directly
        if pageImages.count == 1 {
            return pageImages[0]
        }
        
        // For multiple pages, check if we should combine or just return first page
        // Calculate total height to see if it would be too large
        let totalHeight = pageImages.reduce(0) { $0 + $1.size.height }
        let maxAllowedHeight: CGFloat = 8000 // Limit to prevent issues
        
        if totalHeight > maxAllowedHeight {
            return pageImages[0]
        }
        
        // Calculate max width
        let maxWidth = pageImages.map { $0.size.width }.max() ?? 0
        let spacing: CGFloat = 20 // Space between pages
        let combinedHeight = totalHeight + CGFloat(pageImages.count - 1) * spacing
        
        
        // Create combined image
        UIGraphicsBeginImageContextWithOptions(CGSize(width: maxWidth, height: combinedHeight), true, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return pageImages[0] // Return first page as fallback
        }
        
        // Fill with white background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: maxWidth, height: combinedHeight))
        
        // Draw each page
        var currentY: CGFloat = 0
        for (index, pageImage) in pageImages.enumerated() {
            let x = (maxWidth - pageImage.size.width) / 2 // Center horizontally
            pageImage.draw(at: CGPoint(x: x, y: currentY))
            
            // Draw page separator and number
            if index < pageImages.count - 1 {
                currentY += pageImage.size.height
                
                // Draw separator line
                context.setStrokeColor(UIColor.lightGray.cgColor)
                context.setLineWidth(1)
                context.move(to: CGPoint(x: 50, y: currentY + spacing/2))
                context.addLine(to: CGPoint(x: maxWidth - 50, y: currentY + spacing/2))
                context.strokePath()
                
                // Draw page number
                let pageText = "Page \(index + 2)"
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.gray
                ]
                let textSize = pageText.size(withAttributes: attributes)
                let textRect = CGRect(x: (maxWidth - textSize.width) / 2,
                                      y: currentY + (spacing - textSize.height) / 2,
                                      width: textSize.width,
                                      height: textSize.height)
                pageText.draw(in: textRect, withAttributes: attributes)
                
                currentY += spacing
            }
        }
        
        let combinedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if combinedImage != nil {
        }
        
        return combinedImage
    }
    
    private func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "rtf":
            return "application/rtf"
        default:
            return "application/octet-stream"
        }
    }
    
    func handleVoiceInput() {
        // Toggle recording state on main ViewModel
        isRecordingVoice.toggle()
        
        // Delegate to voice view model
        _Concurrency.Task {
            if isRecordingVoice {
                await voiceViewModel.startRecording()
            } else {
                voiceViewModel.stopRecording()
                
                // If we have transcribed text, use it
                if !voiceViewModel.transcribedText.isEmpty {
                    inputText = voiceViewModel.transcribedText
                    // Clear transcribed text for next recording
                    voiceViewModel.transcribedText = ""
                }
            }
        }
    }
    
    @MainActor
    private func stopVoiceRecording() {
        
        // Update state immediately
        isRecordingVoice = false
        isLoading = false
        
        // Voice recording cleanup now handled by VoiceRecordingViewModel
        voiceViewModel.stopRecording()
        
    }
    
    @MainActor
    private func startVoiceRecognition() async {
        
        // Check microphone permission
        if #available(iOS 17.0, *) {
            let microphoneStatus = AVAudioApplication.shared.recordPermission
            
            switch microphoneStatus {
            case .undetermined:
                let granted = await AVAudioApplication.requestRecordPermission()
                if granted {
                    await self.startVoiceRecognition()
                }
                return
                
            case .denied:
                // Show alert to user
                let message = ChatMessage(
                    content: "Microphone access is required for voice input. Please enable it in Settings.",
                    sender: .assistant,
                    timestamp: Date()
                )
                messages.append(message)
                return
                
            case .granted:
                break
                
            @unknown default:
                return
            }
        } else {
            // Fallback for iOS 16 and earlier
            let microphoneStatus = AVAudioSession.sharedInstance().recordPermission
            
            switch microphoneStatus {
            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    if granted {
                        AsyncTask { @MainActor in
                            await self.startVoiceRecognition()
                        }
                    }
                }
                return
                
            case .denied:
                // Show alert to user
                let message = ChatMessage(
                    content: "Microphone access is required for voice input. Please enable it in Settings.",
                    sender: .assistant,
                    timestamp: Date()
                )
                messages.append(message)
                return
                
            case .granted:
                break
                
            @unknown default:
                return
            }
        }
        
        // Check speech recognition permission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        
        switch speechStatus {
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { status in
                if status == .authorized {
                    AsyncTask { @MainActor in
                        await self.startVoiceRecognition()
                    }
                }
            }
            return
            
        case .denied, .restricted:
            let message = ChatMessage(
                content: "Speech recognition access is required for voice input. Please enable it in Settings.",
                sender: .assistant,
                timestamp: Date()
            )
            messages.append(message)
            return
            
        case .authorized:
            break
            
        @unknown default:
            return
        }
        
        // Start voice recognition
        await performVoiceRecognition()
    }
    
    @MainActor
    private func performVoiceRecognition() async {
        
        guard let recognizer = SFSpeechRecognizer(),
              recognizer.isAvailable else {
            let message = ChatMessage(
                content: "Speech recognition is not available on this device.",
                sender: .assistant,
                timestamp: Date()
            )
            messages.append(message)
            return
        }
        // Voice recognition now handled by VoiceRecordingViewModel
        _Concurrency.Task {
            await voiceViewModel.startRecording()
            isRecordingVoice = voiceViewModel.isRecording
        }
    }
    
    func handleEventAction(eventId: String, action: EventAction) {
        // Find the event preview from messages
        let eventPreview = messages.first { $0.eventPreview?.id == eventId }?.eventPreview
        
        // Delegate to entity view model
        _Concurrency.Task {
            await entityViewModel.handleEventAction(eventId: eventId, action: action, preview: eventPreview)
        }
    }
    
    func handleMultiEventAction(_ action: MultiEventAction, messageId: UUID) {
        // Get events from message
        let events = messages.first { $0.id == messageId }?.multipleEventsPreview ?? []
        
        // Delegate to bulk operations view model
        bulkOperationsViewModel.handleMultiEventAction(action, events: events, messageId: messageId)
    }
    
    // MARK: - Message Persistence
    
    private func saveMessages() {
        // Keep only the last 10 messages
        let messagesToSave = Array(messages.suffix(10))
        
        // Convert messages to a format that can be saved
        let messageData = messagesToSave.compactMap { message -> [String: Any]? in
            // Only save text messages, not ones with images or complex content
            guard message.error == nil else { return nil }
            
            // Create a dictionary with only property list compatible types
            let dict: [String: Any] = [
                "id": message.id.uuidString,
                "content": message.content,
                "sender": message.sender.isUser ? "user" : "assistant",
                "timestamp": message.timestamp.timeIntervalSince1970,
                "isStreaming": message.isStreaming
            ]
            
            // Ensure all values are property list compatible
            return dict
        }
        
        // Validate property list compatibility before saving
        if PropertyListSerialization.propertyList(messageData, isValidFor: .binary) {
            UserDefaults.standard.set(messageData, forKey: "ChatMessages")
        } else {
            print("Warning: Message data is not property list compatible")
        }
        
        // Also save conversation history for context
        let historyToSave = Array(conversationHistory.suffix(20))
        let historyData = historyToSave.compactMap { message -> [String: String]? in
            // Extract string content from MessageContent enum
            let contentString: String
            switch message.content {
            case .text(let text):
                contentString = text
            case .array:
                // For array content (images, etc.), we'll skip saving
                return nil
            }
            
            return [
                "role": message.role,
                "content": contentString
            ]
        }
        
        // Validate property list compatibility before saving
        if PropertyListSerialization.propertyList(historyData, isValidFor: .binary) {
            UserDefaults.standard.set(historyData, forKey: "ChatHistory")
        } else {
            print("Warning: History data is not property list compatible")
        }
    }
    
    private func loadPersistedMessages() {
        // Load saved messages
        if let messageData = UserDefaults.standard.array(forKey: "ChatMessages") as? [[String: Any]] {
            messages = messageData.compactMap { data in
                guard let idString = data["id"] as? String,
                      let _ = UUID(uuidString: idString),
                      let content = data["content"] as? String,
                      let senderString = data["sender"] as? String,
                      let timestamp = data["timestamp"] as? TimeInterval else {
                    return nil
                }
                
                let sender: ChatMessage.MessageSender = senderString == "user" ? .user(name: "User") : .assistant
                let date = Date(timeIntervalSince1970: timestamp)
                let isStreaming = data["isStreaming"] as? Bool ?? false
                
                // Create message with persisted ID to maintain consistency
                let message = ChatMessage(
                    content: content,
                    sender: sender,
                    timestamp: date,
                    isStreaming: isStreaming
                )
                
                // Note: We can't restore the original ID due to it being a let constant
                // This is acceptable since we generate new IDs for each session
                return message
            }
        }
        
        // Load conversation history
        if let historyData = UserDefaults.standard.array(forKey: "ChatHistory") as? [[String: String]] {
            conversationHistory = historyData.compactMap { data in
                guard let role = data["role"],
                      let content = data["content"] else {
                    return nil
                }
                return ChatRequestMessage(role: role, content: content)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func startRateLimitTimer(seconds: Int) {
        // Cancel existing timer
        rateLimitTimer?.invalidate()
        
        // Start new timer
        rateLimitTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: false) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async { [weak self] in
                self?.isRateLimited = false
                self?.rateLimitResetTime = nil
            }
        }
    }
    
    private func setupInitialGreeting() {
        let greeting = ChatMessage(
            content: "Hello! I'm your Planwise Assistant. I can help you manage your schedule, create events, and optimize your time. How can I assist you today?",
            sender: .assistant,
            timestamp: Date()
        )
        messages.append(greeting)
        saveMessages()
        
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
    
    private func buildUserContext() -> String {
        let today = Date()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var contextLines: [String] = []
        
        // Add current date and time
        contextLines.append("📅 Current Date/Time: \(formatter.string(from: today))")
        contextLines.append("")
        
        // ALWAYS include ALL context for proper AI functioning
        // The AI needs complete context to make smart decisions about scheduling,
        // task dependencies, and resource allocation
        let includeGoals = true
        let includeTasks = true
        let includeHabits = true
        let includeEvents = true
        let includeAll = true
        
        // Add available categories
        let availableCategories = scheduleManager.categories
        if !availableCategories.isEmpty {
            contextLines.append("🏷️ AVAILABLE CATEGORIES:")
            for category in availableCategories {
                if let name = category.name, let icon = category.iconName {
                    contextLines.append("• \(name) (\(icon))")
                }
            }
            contextLines.append("")
        }
        
        // 1. Add today's events (if relevant or includeAll)
        if includeEvents || includeAll {
            let todayEvents = scheduleManager.eventsForToday()
            if !todayEvents.isEmpty {
                contextLines.append("📆 TODAY'S EVENTS (\(todayEvents.count)):")
                for event in todayEvents {
                    let startTime = event.startTime.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .short) } ?? ""
                    let endTime = event.endTime.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .short) } ?? ""
                    let category = event.category?.name ?? "uncategorized"
                    let status = event.isCompleted ? "✅" : "⏳"
                    let eventId = event.id?.uuidString ?? "unknown"
                    contextLines.append("• \(status) \(event.title ?? "") [ID: \(eventId)] (\(startTime)-\(endTime)) [\(category)]")
                }
                contextLines.append("")
            }
        }
        
        // 1b. Add next 7 days of events (brief summary)
        var upcomingEvents: [String] = []
        for dayOffset in 1...7 {
            if let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                let dayEvents = scheduleManager.events(for: targetDate)
                if !dayEvents.isEmpty {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "EEE, MMM d"
                    let dateStr = dateFormatter.string(from: targetDate)
                    upcomingEvents.append("\(dateStr): \(dayEvents.count) events")
                }
            }
        }
        if !upcomingEvents.isEmpty {
            contextLines.append("📅 UPCOMING WEEK:")
            upcomingEvents.forEach { contextLines.append("• \($0)") }
            contextLines.append("")
        }
        
        // 2. Add incomplete tasks (if relevant)
        if includeTasks || includeAll {
            let incompleteTasks = taskManager.tasks.filter { !$0.isCompleted }
            if !incompleteTasks.isEmpty {
            let highPriorityTasks = incompleteTasks.filter { $0.priority == 2 }.count
            let overdueTasks = incompleteTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < today
            }.count
            
            contextLines.append("📋 INCOMPLETE TASKS (\(incompleteTasks.count) total, \(highPriorityTasks) high priority, \(overdueTasks) overdue):")
            
            // Show ALL tasks sorted by priority
            let sortedTasks = incompleteTasks.sorted { (t1, t2) in
                // Sort by priority first, then due date
                if t1.priority != t2.priority {
                    return t1.priority > t2.priority
                }
                if let d1 = t1.dueDate, let d2 = t2.dueDate {
                    return d1 < d2
                }
                return t1.dueDate != nil && t2.dueDate == nil
            }
            
            for task in sortedTasks {
                let priority = task.priority == 2 ? "🔴" : task.priority == 1 ? "🟡" : "🟢"
                let dueInfo = task.dueDate.map { " (due \(DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .none)))" } ?? ""
                let category = task.category?.name ?? "uncategorized"
                let duration = task.estimatedDuration > 0 ? " ~\(task.estimatedDuration)min" : ""
                let taskId = task.id?.uuidString ?? "unknown"
                contextLines.append("• \(priority) \(task.title ?? "") [ID: \(taskId)]\(dueInfo) [\(category)]\(duration)")
            }
            contextLines.append("")
            }
        }
        
        // 3. Add active habits (if relevant)
        if includeHabits || includeAll {
            let activeHabits = habitManager.habits.filter { !$0.isPaused }
            let todaysHabits = activeHabits.filter { habit in
                // Check if habit should be done today based on frequency
                if habit.frequency == "daily" {
                    return true
                }
                // Add more frequency logic as needed
                return true
            }
            
            if !todaysHabits.isEmpty {
            contextLines.append("🌟 TODAY'S HABITS (\(todaysHabits.count)):")
            for habit in todaysHabits {
                let streak = habit.currentStreak > 0 ? " 🔥\(habit.currentStreak)" : ""
                let completed = habit.lastCompletedDate.map { calendar.isDateInToday($0) } ?? false
                let status = completed ? "✅" : "⭕"
                let category = habit.category?.name ?? "uncategorized"
                let habitId = habit.id?.uuidString ?? "unknown"
                contextLines.append("• \(status) \(habit.name ?? "") [ID: \(habitId)]\(streak) [\(category)]")
            }
            contextLines.append("")
            }
        }
        
        // 4. Add ALL goals with complete details including milestones (if relevant)
        if includeGoals {
            let allGoals = goalManager.goals
            if !allGoals.isEmpty {
            contextLines.append("🎯 ALL GOALS (\(allGoals.count) total):")
            for goal in allGoals {
                let progress = Int(goal.progress * 100)
                let priority = goal.priority == 3 ? "🔴" : goal.priority == 2 ? "🟡" : goal.priority == 1 ? "🟢" : "⚪"
                let status = goal.isCompleted ? "✅" : "📌"
                let dueInfo = goal.targetDate.map { " (by \(DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .none)))" } ?? ""
                let targetInfo = goal.targetValue > 0 ? " (target: \(Int(goal.targetValue))\(goal.unit ?? ""))" : ""
                let goalId = goal.id?.uuidString ?? "unknown"
                let category = goal.category?.name ?? "uncategorized"
                
                contextLines.append("• \(status) \(priority) \(goal.title ?? "") [ID: \(goalId)] [\(category)] - \(progress)% complete\(dueInfo)\(targetInfo)")
                
                // Add milestones for this goal
                if let milestones = goal.milestones?.allObjects as? [GoalMilestone], !milestones.isEmpty {
                    let sortedMilestones = milestones.sorted { ($0.sortOrder) < ($1.sortOrder) }
                    contextLines.append("  Milestones:")
                    for milestone in sortedMilestones {
                        let milestoneStatus = milestone.isCompleted ? "✓" : "○"
                        let milestoneId = milestone.id?.uuidString ?? "unknown"
                        contextLines.append("    \(milestoneStatus) \(milestone.title ?? "") [MID: \(milestoneId)]")
                    }
                }
            }
            contextLines.append("")
            }
        }
        
        // 5. Add available categories
        let categories = scheduleManager.categories.map { $0.name ?? "" }.joined(separator: ", ")
        contextLines.append("📁 AVAILABLE CATEGORIES: \(categories)")
        
        return """
        
        === USER'S CURRENT CONTEXT (USE THIS DATA FOR ALL OPERATIONS) ===
        \(contextLines.joined(separator: "\n"))
        
        🚨 CRITICAL INSTRUCTIONS FOR AI ASSISTANT 🚨
        
        You have access to ALL the user's data above. This includes:
        - ALL goals with their IDs, progress, categories, and milestones
        - ALL tasks with their IDs, priorities, due dates, and categories  
        - ALL habits with their IDs, streaks, frequencies, and completion status
        - ALL events for today and upcoming week
        - ALL available categories
        
        🎯 SIMPLIFIED FUNCTION SYSTEM - USE THESE 5 FUNCTIONS ONLY:
        
        1. manage_events(action, parameters)
           Actions: create, update, delete, list
           
        2. manage_tasks(action, parameters)  
           Actions: create, update, delete, list, complete
           
        3. manage_habits(action, parameters)
           Actions: create, update, delete, list, log, complete
           
        4. manage_goals(action, parameters)
           Actions: create, update, delete, list, complete
           
        5. manage_categories(action, parameters)
           Actions: create, update, delete, list
           
        📌 BULK OPERATIONS FORMAT (CRITICAL):
        For updating/creating multiple items with DIFFERENT values, use this EXACT format:
        {
            "action": "update",
            "items": [
                {"id": "ID1", "name": "New Name 1", ...other fields...},
                {"id": "ID2", "name": "New Name 2", ...other fields...},
                {"id": "ID3", "name": "New Name 3", ...other fields...}
            ]
        }
        
        DO NOT send multiple concatenated JSON objects like {"action":"update","parameters":{...}}{"action":"update","parameters":{...}}
        ALWAYS use the items array for bulk operations!
        
        For updating ALL items with the SAME value:
        {
            "action": "update", 
            "updateAll": true,
            "category": "Work"  // This will update ALL items to have category "Work"
        }
        
        CRITICAL: ALWAYS USE THE EXACT IDs FROM THE CONTEXT ABOVE!
        
        When user says "update all goal categories" or "add descriptions to all tasks":
        1. Look at the items listed above with their [ID: xxx] tags
        2. Use those EXACT IDs in your function calls
        3. For bulk updates with different values, use items array with the actual IDs
        
        EXAMPLES:
        - Update goal categories (USE REAL IDs FROM ABOVE):
          manage_goals("update", {items: [
            {id:"ACTUAL-UUID-FROM-CONTEXT", category:"Health"}, 
            {id:"ANOTHER-UUID-FROM-CONTEXT", category:"Work"}
          ]})
        - Add descriptions to all tasks (for same value):
          manage_tasks("update", {updateAll:true, description:"Generated description"})
        - Schedule events based on tasks/goals (USE THE DATA ABOVE):
          manage_events("create", {items: [/* events created from your actual tasks/goals */]})
        
        WHEN USER ASKS TO SCHEDULE:
        The AI has access to ALL your goals, tasks, and habits above.
        It will create events based on YOUR specific request.
        For example: "schedule my day based on my goals" - AI will look at YOUR goals listed above and create appropriate time blocks.
        
        BULK OPERATIONS:
        - For updating multiple items with DIFFERENT values: use items:[] array
        - For updating ALL items with SAME value: use updateAll:true
        - Always include the ID when updating specific items
        
        CATEGORY RULES:
        Use existing categories from the list above. Map intelligently:
        - Work: business, office, projects, meetings
        - Personal: self-care, errands, personal time
        - Health: medical, wellness, therapy
        - Fitness: gym, exercise, sports
        - Learning: study, courses, reading
        - Social: friends, parties, networking
        - Family: home, relatives, kids
        - Finance: money, budget, investments
        
        NEVER ask for information that's already in the context above!
        When user says "my goals/tasks/habits" use the specific items with IDs from above.
        
        === END CONTEXT ===
        
        """
    }
    
    private func sendToOpenAI() async {
        
        // Build and inject context FIRST, before any trimming
        let dynamicContext = buildUserContext()
        
        // Debug: Print context to see what's being built
        print("🔍 DEBUG - Dynamic Context Length: \(dynamicContext.count) characters")
        print("🔍 DEBUG - Full Context:")
        print(dynamicContext)
        print("🔍 DEBUG - Tasks count: \(taskManager.tasks.count)")
        print("🔍 DEBUG - Habits count: \(habitManager.habits.count)")
        print("🔍 DEBUG - Goals count: \(goalManager.goals.count)")
        
        // Remove any existing context messages first
        conversationHistory = conversationHistory.filter { message in
            if message.role == "system" {
                switch message.content {
                case .text(let text):
                    return !text.contains("USER'S CURRENT CONTEXT")
                case .array:
                    return true
                }
            }
            return true
        }
        
        // Always add fresh context as the FIRST message
        conversationHistory.insert(ChatRequestMessage(
            role: "system",
            content: dynamicContext
        ), at: 0)
        
        // NOW limit conversation history to prevent token explosion
        let maxHistoryCount = 20
        if conversationHistory.count > maxHistoryCount {
            // Keep ALL system messages + last N messages
            let systemMessages = conversationHistory.filter { $0.role == "system" }
            let nonSystemMessages = conversationHistory.filter { $0.role != "system" }
            let recentNonSystemMessages = Array(nonSystemMessages.suffix(maxHistoryCount - systemMessages.count))
            conversationHistory = systemMessages + recentNonSystemMessages
            
            print("🔍 DEBUG - After trimming: \(systemMessages.count) system messages, \(recentNonSystemMessages.count) other messages")
        }
        
        // Check network connection first
        guard NetworkMonitor.shared.isConnected else {
            let errorMessage = ChatMessage(
                content: "",
                sender: .assistant,
                timestamp: Date(),
                error: "No internet connection. Please check your network and try again."
            )
            messages.append(errorMessage)
            return
        }
        
        isLoading = true
        isTypingIndicatorVisible = true
        
        // Create user context from past week, today, and next week
        let calendar = Calendar.current
        let today = Date()
        
        // Get events from past 7 days to next 7 days
        var allEvents: [Event] = []
        
        // Past 7 days
        for dayOffset in -7..<0 {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                let dayEvents = scheduleManager.events(for: date)
                allEvents.append(contentsOf: dayEvents)
            }
        }
        
        // Today
        allEvents.append(contentsOf: scheduleManager.eventsForToday())
        
        // Next 7 days
        for dayOffset in 1...7 {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                let dayEvents = scheduleManager.events(for: date)
                allEvents.append(contentsOf: dayEvents)
            }
        }
        
        let userContext = openAIService.createUserContext(
            from: allEvents,
            goals: goalManager.goals,
            tasks: taskManager.tasks,
            habits: habitManager.habits
        )
        
        // Debug: Print what's in conversation history
        print("🔍 DEBUG - Conversation History Count: \(conversationHistory.count)")
        for (index, msg) in conversationHistory.enumerated() {
            let preview: String
            switch msg.content {
            case .text(let text):
                preview = String(text.prefix(100))
            case .array:
                preview = "[Array content]"
            }
            print("🔍 DEBUG - Message \(index): role=\(msg.role), content=\(preview)...")
        }
        
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
            do {
                let response = try await openAIService.sendChatRequest(
                    messages: conversationHistory,
                    userContext: userContext
                )
                
                isTypingIndicatorVisible = false
                
                // Process response
                if let choice = response.choices.first {
                    await self.processAssistantResponse(choice.message)
                }
            } catch {
                isTypingIndicatorVisible = false
                self.handleGenericError(error)
            }
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
        
        // Determine model based on content
        let hasImages = conversationHistory.contains { msg in
            if case .array(let content) = msg.content {
                return content.contains { ($0["type"] as? String) == "image_url" }
            }
            return false
        }
        _ = hasImages ? "gpt-4o" : "gpt-4o-mini"
        
        // Add system message about new functions if not already present
        if !conversationHistory.contains(where: { msg in
            if case .text(let text) = msg.content {
                return msg.role == "system" && text.contains("IMPORTANT: Use only these 5 functions")
            }
            return false
        }) {
            conversationHistory.insert(ChatRequestMessage(
                role: "system",
                content: """
                IMPORTANT: Use only these 5 functions for ALL operations:
                - manage_events: For creating, updating, deleting, listing events
                - manage_tasks: For creating, updating, deleting, listing tasks  
                - manage_habits: For creating, updating, deleting, listing habits
                - manage_goals: For creating, updating, deleting, listing goals
                - manage_categories: For creating, updating, deleting, listing categories
                
                DO NOT use old function names like create_event, delete_event, etc. They no longer exist.
                For milestones, use manage_goals with action: 'create_milestone', 'update_milestone', or 'delete_milestone'.
                """
            ), at: 0)
        }
        
        let stream = openAIService.streamChatRequest(
            messages: conversationHistory,
            userContext: userContext,
            tools: getSimplifiedTools()
        )
        
        var accumulatedContent = ""
        var functionCallName: String?
        var functionCallArguments = ""
        
        streamingTask = AsyncTask { @MainActor in
            do {
                var eventCount = 0
                
                for try await event in stream {
                    // Check for cancellation is handled by the async stream
                    
                    
                    eventCount += 1
                    
                    switch event {
                    case .data(let streamData):
                        if let choice = streamData.choices.first {
                            // Handle content
                            if let content = choice.delta.content {
                                accumulatedContent += content
                                self.updateStreamingMessage(id: messageId, content: accumulatedContent)
                            }
                            
                            // Handle function call
                            if let functionCall = choice.delta.functionCall {
                                if let name = functionCall.name {
                                    functionCallName = name
                                }
                                if let args = functionCall.arguments {
                                    functionCallArguments += args
                                }
                            }
                        }
                        
                    case .done:
                        
                        // Process function call if any
                        if let functionName = functionCallName {
                            
                            let message = ChatResponse.Message(
                                role: "assistant",
                                content: accumulatedContent.isEmpty ? nil : accumulatedContent,
                                functionCall: ChatResponse.FunctionCall(
                                    name: functionName,
                                    arguments: functionCallArguments
                                )
                            )
                            // Process with the message ID so we can update it
                            await self.processAssistantResponseForStreaming(message, streamingMessageId: messageId)
                        } else if !accumulatedContent.isEmpty {
                            // Add to conversation history
                            conversationHistory.append(ChatRequestMessage(
                                role: "assistant",
                                content: accumulatedContent
                            ))
                        }
                        
                        // Finalize message after processing
                        self.finalizeStreamingMessage(id: messageId)
                    }
                }
            } catch {
                self.handleStreamingError(error, messageId: messageId)
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
        saveMessages()
    }
    
    private func processAssistantResponseForStreaming(_ message: ChatResponse.Message, streamingMessageId: UUID) async {
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
                // For delete operations, the deletion already happened in the function
                // The preview is just to show what was done
                bulkActionPreview = createBulkActionPreview(from: result, functionName: functionCall.name)
            // Task Management Functions
            case "create_task", "update_task", "complete_task", "delete_task",
                 "create_subtasks", "link_task_to_event", "list_tasks",
                 "create_multiple_tasks", "update_multiple_tasks", 
                 "complete_multiple_tasks", "reopen_multiple_tasks",
                 "delete_multiple_tasks", "complete_all_tasks_by_filter",
                 "delete_all_completed_tasks", "delete_all_tasks", "reschedule_tasks",
                 "search_tasks", "get_task_statistics":
                // Task operations don't need previews - they show results directly
                // The function result message contains all the information
                break
            // Habit Management Functions
            case "create_habit", "log_habit", "list_habits", "update_habit",
                 "delete_habit", "get_habit_stats", "pause_habit", "get_habit_insights":
                // Habit operations don't need previews - they show results directly
                break
            default:
                break
            }
            
            // Update existing streaming message
            if let index = messages.firstIndex(where: { $0.id == streamingMessageId }) {
                messages[index].functionCall = result
                messages[index].eventPreview = eventPreview
                messages[index].multipleEventsPreview = multipleEventsPreview
                messages[index].bulkActionPreview = bulkActionPreview
            }
            
            // Update the streaming message content with the function result if no content
            if let index = messages.firstIndex(where: { $0.id == streamingMessageId }) {
                if messages[index].content.isEmpty {
                    messages[index].content = result.message
                }
            }
            
            // Add to conversation history
            conversationHistory.append(ChatRequestMessage(
                role: "assistant",
                content: message.content ?? "I've performed the requested action."
            ))
            
            // Add function result to history as assistant message
            // Note: OpenAI expects function results as assistant messages with the function name
            conversationHistory.append(ChatRequestMessage(
                role: "assistant",
                content: "[Function: \(functionCall.name)] \(result.message)"
            ))
        } else {
            // Update content only
            if let index = messages.firstIndex(where: { $0.id == streamingMessageId }) {
                messages[index].content = message.content ?? ""
            }
            
            // Add to conversation history
            conversationHistory.append(ChatRequestMessage(
                role: "assistant",
                content: message.content ?? ""
            ))
        }
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
                // For delete operations, the deletion already happened in the function
                // The preview is just to show what was done
                bulkActionPreview = createBulkActionPreview(from: result, functionName: functionCall.name)
            default:
                break
            }
            
            // Check if we're in streaming mode and update existing message
            if let streamingId = streamingMessageId,
               let index = messages.firstIndex(where: { $0.id == streamingId }) {
                // Update existing streaming message
                messages[index].functionCall = result
                messages[index].eventPreview = eventPreview
                messages[index].multipleEventsPreview = multipleEventsPreview
                messages[index].bulkActionPreview = bulkActionPreview
                messages[index].isStreaming = false
                streamingMessageId = nil
            } else {
                // Create new message (non-streaming case)
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
            }
            
            // Add to conversation history
            conversationHistory.append(ChatRequestMessage(
                role: "assistant",
                content: message.content ?? "I've performed the requested action."
            ))
            
            // Add function result to history as assistant message
            // Note: OpenAI expects function results as assistant messages with the function name
            conversationHistory.append(ChatRequestMessage(
                role: "assistant",
                content: "[Function: \(functionCall.name)] \(result.message)"
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
    
    private func routeToSimplifiedSystem(functionName: String, parameters: [String: Any]) async -> FunctionCallResult {
        // Debug logging
        print("🔍 routeToSimplifiedSystem called")
        print("   Function: \(functionName)")
        print("   Raw parameters: \(parameters)")
        
        let action = parameters["action"] as? String ?? "unknown"
        var params = parameters["parameters"] as? [String: Any] ?? [:]
        
        // CRITICAL FIX: Handle malformed parameters where AI puts data at wrong level
        // Sometimes AI sends: {action: "update", id: "xxx", category: "yyy"} 
        // Instead of: {action: "update", parameters: {id: "xxx", category: "yyy"}}
        
        // If parameters is empty but we have other keys, those are probably the actual parameters
        if params.isEmpty && parameters.count > 1 {
            print("   ⚠️ Parameters object is empty but found other keys - restructuring")
            for (key, value) in parameters {
                if key != "action" && key != "parameters" {
                    params[key] = value
                    print("   ➡️ Moved '\(key)' to parameters")
                }
            }
        }
        
        // Also handle specific common mistakes
        if let id = parameters["id"] as? String, params["id"] == nil {
            print("   ⚠️ Found 'id' at top level, moving to parameters")
            params["id"] = id
        }
        
        if let ids = parameters["ids"] as? [String], params["ids"] == nil {
            print("   ⚠️ Found 'ids' at top level, moving to parameters")
            params["ids"] = ids
        }
        
        if let items = parameters["items"] as? [[String: Any]], params["items"] == nil {
            print("   ⚠️ Found 'items' at top level, moving to parameters")
            params["items"] = items
        }
        
        if let category = parameters["category"], params["category"] == nil {
            print("   ⚠️ Found 'category' at top level, moving to parameters")
            params["category"] = category
        }
        
        print("   Extracted action: \(action)")
        print("   Extracted params: \(params)")
        
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
        
        print("   Result: \(result)")
        
        let success = result["success"] as? Bool ?? false
        let message = result["message"] as? String ?? "Operation completed"
        
        // If failed and action is "unknown", provide more helpful error
        if !success && action == "unknown" {
            print("❌ ERROR: Action not found in parameters")
            print("   Expected format: {\"action\": \"create\", \"parameters\": {...}}")
            return FunctionCallResult(
                functionName: functionName,
                success: false,
                message: "Missing 'action' parameter. Expected format: {\"action\": \"create\", \"parameters\": {...}}",
                details: ["debug": "Parameters received: \(parameters)"]
            )
        }
        
        var details: [String: String] = [:]
        if let data = result["data"] {
            // Convert data to JSON string for details
            if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                details["data"] = jsonString
            } else {
                details["data"] = String(describing: data)
            }
        }
        
        return FunctionCallResult(
            functionName: functionName,
            success: success,
            message: message,
            details: details
        )
    }
    
    private func processFunctionCall(_ functionCall: ChatResponse.FunctionCall) async -> FunctionCallResult {
        // Processing function call
        
        // AUTO-CONVERT OLD FUNCTION NAMES TO NEW ONES
        var convertedFunctionCall = functionCall
        let oldToNewMapping: [String: (name: String, action: String)] = [
            // Events
            "create_event": ("manage_events", "create"),
            "update_event": ("manage_events", "update"),
            "delete_event": ("manage_events", "delete"),
            "list_events": ("manage_events", "list"),
            "create_multiple_events": ("manage_events", "create"),
            
            // Tasks
            "create_task": ("manage_tasks", "create"),
            "update_task": ("manage_tasks", "update"),
            "delete_task": ("manage_tasks", "delete"),
            "complete_task": ("manage_tasks", "complete"),
            "list_tasks": ("manage_tasks", "list"),
            "create_multiple_tasks": ("manage_tasks", "create"),
            
            // Habits
            "create_habit": ("manage_habits", "create"),
            "update_habit": ("manage_habits", "update"),
            "delete_habit": ("manage_habits", "delete"),
            "list_habits": ("manage_habits", "list"),
            "log_habit": ("manage_habits", "log"),
            
            // Goals
            "create_goal": ("manage_goals", "create"),
            "update_goal": ("manage_goals", "update"),
            "delete_goal": ("manage_goals", "delete"),
            "list_goals": ("manage_goals", "list"),
            "add_milestone": ("manage_goals", "create_milestone"),
            "add_goal_milestone": ("manage_goals", "create_milestone"),
            
            // Categories
            "create_category": ("manage_categories", "create"),
            "update_category": ("manage_categories", "update"),
            "delete_category": ("manage_categories", "delete"),
            "list_categories": ("manage_categories", "list")
        ]
        
        // Check if this is an old function name that needs conversion
        if let mapping = oldToNewMapping[functionCall.name] {
            print("🔄 AUTO-CONVERTING: \(functionCall.name) → \(mapping.name) with action: \(mapping.action)")
            
            // Parse the old arguments
            if let argumentsData = functionCall.arguments.data(using: .utf8),
               let oldArgs = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] {
                
                // Create new arguments structure
                let newArgs: [String: Any] = [
                    "action": mapping.action,
                    "parameters": oldArgs
                ]
                
                // Convert back to JSON string
                if let newArgsData = try? JSONSerialization.data(withJSONObject: newArgs),
                   let newArgsString = String(data: newArgsData, encoding: .utf8) {
                    convertedFunctionCall = ChatResponse.FunctionCall(
                        name: mapping.name,
                        arguments: newArgsString
                    )
                    print("✅ Converted arguments: \(newArgsString)")
                }
            }
        }
        
        // FIX: Clean up concatenated JSON objects from AI
        // Sometimes the AI sends multiple JSON objects concatenated like {...}{...}
        // We need to convert these to proper bulk update format with items array
        var cleanedArguments = convertedFunctionCall.arguments
        
        // Check if we have concatenated JSON (look for }{)
        if cleanedArguments.contains("}{") {
            print("⚠️ Detected concatenated JSON objects in arguments")
            print("   Original: \(cleanedArguments)")
            
            // Split the concatenated JSON objects
            let jsonObjects = cleanedArguments.components(separatedBy: "}{")
            var allItems: [[String: Any]] = []
            var commonAction: String? = nil
            
            for (index, jsonStr) in jsonObjects.enumerated() {
                // Add back the braces that were removed by split
                var fixedJson = jsonStr
                if index > 0 { fixedJson = "{" + fixedJson }
                if index < jsonObjects.count - 1 { fixedJson = fixedJson + "}" }
                
                // Parse each JSON object
                if let data = fixedJson.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    // Extract action (should be same for all)
                    if let action = json["action"] as? String {
                        if commonAction == nil {
                            commonAction = action
                        }
                    }
                    
                    // Extract parameters and add to items array
                    if let params = json["parameters"] as? [String: Any] {
                        allItems.append(params)
                    } else if let items = json["items"] as? [[String: Any]] {
                        // In case one of them already has items format
                        allItems.append(contentsOf: items)
                    }
                }
            }
            
            // If we successfully parsed multiple items, create proper bulk format
            if allItems.count > 1, let action = commonAction {
                print("   Found \(allItems.count) concatenated operations")
                
                // Create proper bulk update format
                let bulkArgs: [String: Any] = [
                    "action": action,
                    "items": allItems
                ]
                
                // Convert to JSON string
                if let bulkData = try? JSONSerialization.data(withJSONObject: bulkArgs, options: []),
                   let bulkString = String(data: bulkData, encoding: .utf8) {
                    cleanedArguments = bulkString
                    print("   Converted to bulk format: \(bulkString)")
                    convertedFunctionCall = ChatResponse.FunctionCall(
                        name: convertedFunctionCall.name,
                        arguments: cleanedArguments
                    )
                }
            } else if allItems.count == 1 {
                // Single item, just clean it up
                let singleArgs: [String: Any] = [
                    "action": commonAction ?? "update",
                    "parameters": allItems[0]
                ]
                if let singleData = try? JSONSerialization.data(withJSONObject: singleArgs, options: []),
                   let singleString = String(data: singleData, encoding: .utf8) {
                    cleanedArguments = singleString
                    print("   Cleaned single item: \(singleString)")
                    convertedFunctionCall = ChatResponse.FunctionCall(
                        name: convertedFunctionCall.name,
                        arguments: cleanedArguments
                    )
                }
            }
        }
        
        // Parse function arguments
        print("🔍 About to parse function call:")
        print("   Function name: \(convertedFunctionCall.name)")
        print("   Arguments string: \(convertedFunctionCall.arguments)")
        
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
                        functionCall: convertedFunctionCall
                    ),
                    finishReason: nil
                )],
                usage: nil,
                metadata: nil
            )
        ) else {
            print("❌ Failed to parse function arguments!")
            print("   Function: \(convertedFunctionCall.name)")
            print("   Arguments: \(convertedFunctionCall.arguments)")
            
            return FunctionCallResult(
                functionName: convertedFunctionCall.name,
                success: false,
                message: "I encountered an error processing that request. Could you please try rephrasing it or breaking it down into smaller parts?",
                details: ["error": "Failed to parse function arguments", "function": convertedFunctionCall.name, "arguments": convertedFunctionCall.arguments]
            )
        }
        
        switch parsedFunction.name {
        // NEW SIMPLIFIED FUNCTIONS (5 total)
        case "manage_events":
            return await routeToSimplifiedSystem(functionName: "manage_events", parameters: parsedFunction.arguments)
        case "manage_tasks":
            return await routeToSimplifiedSystem(functionName: "manage_tasks", parameters: parsedFunction.arguments)
        case "manage_habits":
            return await routeToSimplifiedSystem(functionName: "manage_habits", parameters: parsedFunction.arguments)
        case "manage_goals":
            return await routeToSimplifiedSystem(functionName: "manage_goals", parameters: parsedFunction.arguments)
        case "manage_categories":
            return await routeToSimplifiedSystem(functionName: "manage_categories", parameters: parsedFunction.arguments)
            
        // LEGACY - THE ONE FUNCTION TO RULE THEM ALL (keeping for backwards compatibility temporarily)
        case "manage":
            return await self.manage(with: parsedFunction.arguments)
            
        // Legacy functions - DISABLED (AI should only use "manage" function)
        // Keeping the implementations since manage() sub-managers still need them
        /* case "create_event":
            return await createEvent(with: parsedFunction.arguments)
        case "update_event":
            return await self.updateEvent(with: parsedFunction.arguments)
        case "delete_event":
            return await self.deleteEvent(with: parsedFunction.arguments)
        case "create_multiple_events":
            return await self.createMultipleEvents(with: parsedFunction.arguments)
        case "create_recurring_event":
            return await self.createRecurringEvent(with: parsedFunction.arguments)
        case "search_events":
            return await self.searchEvents(with: parsedFunction.arguments)
        case "list_events":
            return await self.listEvents(with: parsedFunction.arguments)
        case "get_event_details":
            return await self.getEventDetails(with: parsedFunction.arguments)
        case "delete_all_events":
            return await self.deleteAllEvents(with: parsedFunction.arguments)
        case "update_all_events":
            return await self.updateAllEvents(with: parsedFunction.arguments)
        case "mark_all_complete":
            return await self.markAllComplete(with: parsedFunction.arguments)
        case "list_categories":
            return await self.listCategories(with: parsedFunction.arguments)
        case "create_category":
            return await self.createCategory(with: parsedFunction.arguments)
        case "update_category":
            return await self.updateCategory(with: parsedFunction.arguments)
        case "delete_category":
            return await self.deleteCategory(with: parsedFunction.arguments)
        case "create_task":
            return await self.createTask(with: parsedFunction.arguments)
        case "update_task":
            return await self.updateTask(with: parsedFunction.arguments)
        case "complete_task":
            return await self.completeTask(with: parsedFunction.arguments)
        case "delete_task":
            return await self.deleteTask(with: parsedFunction.arguments)
        case "create_subtasks":
            return await self.createSubtasks(with: parsedFunction.arguments)
        case "link_task_to_event":
            return await self.linkTaskToEvent(with: parsedFunction.arguments)
        case "list_tasks":
            return await self.listTasks(with: parsedFunction.arguments)
        case "create_multiple_tasks":
            return await self.createMultipleTasks(with: parsedFunction.arguments)
        case "update_multiple_tasks":
            return await self.updateMultipleTasks(with: parsedFunction.arguments)
        case "complete_multiple_tasks":
            return await self.completeMultipleTasks(with: parsedFunction.arguments)
        case "reopen_multiple_tasks":
            return await self.reopenMultipleTasks(with: parsedFunction.arguments)
        case "delete_multiple_tasks":
            return await self.deleteMultipleTasks(with: parsedFunction.arguments)
        case "complete_all_tasks_by_filter":
            return await self.completeAllTasksByFilter(with: parsedFunction.arguments)
        case "delete_all_completed_tasks":
            return await self.deleteAllCompletedTasks(with: parsedFunction.arguments)
        case "delete_all_tasks":
            return await self.deleteAllTasks(with: parsedFunction.arguments)
        case "reschedule_tasks":
            return await self.rescheduleTasks(with: parsedFunction.arguments)
        case "search_tasks":
            return await self.searchTasks(with: parsedFunction.arguments)
        case "get_task_statistics":
            return await self.getTaskStatistics(with: parsedFunction.arguments)
        case "create_habit":
            return await self.createHabit(with: parsedFunction.arguments)
        case "log_habit":
            return await self.logHabit(with: parsedFunction.arguments)
        case "list_habits":
            return await self.listHabits(with: parsedFunction.arguments)
        case "update_habit":
            return await self.updateHabit(with: parsedFunction.arguments)
        case "delete_habit":
            return await self.deleteHabit(with: parsedFunction.arguments)
        case "get_habit_stats":
            return await self.getHabitStats(with: parsedFunction.arguments)
        case "pause_habit":
            return await self.pauseHabit(with: parsedFunction.arguments)
        case "get_habit_insights":
            return await self.getHabitInsights(with: parsedFunction.arguments)
        case "create_multiple_habits":
            return await self.createMultipleHabits(with: parsedFunction.arguments)
        case "update_multiple_habits":
            return await self.updateMultipleHabits(with: parsedFunction.arguments)
        case "delete_multiple_habits":
            return await self.deleteMultipleHabits(with: parsedFunction.arguments)
        case "delete_all_habits":
            return await self.deleteAllHabits(with: parsedFunction.arguments)
        case "create_goal":
            return await self.createGoal(with: parsedFunction.arguments)
        case "list_goals":
            return await self.listGoals(with: parsedFunction.arguments)
        case "update_goal":
            return await self.updateGoal(with: parsedFunction.arguments)
        case "delete_goal":
            return await self.deleteGoal(with: parsedFunction.arguments)
        case "delete_multiple_goals":
            return await self.deleteMultipleGoals(with: parsedFunction.arguments)
        case "delete_all_goals":
            return await self.deleteAllGoals(with: parsedFunction.arguments)
        case "complete_goal":
            return await self.completeGoal(with: parsedFunction.arguments)
        case "add_goal_progress":
            return await self.addGoalProgress(with: parsedFunction.arguments)
        case "get_goal_progress":
            return await self.getGoalProgress(with: parsedFunction.arguments)
        case "create_multiple_goals":
            return await self.createMultipleGoals(with: parsedFunction.arguments)
        case "update_multiple_goals":
            return await self.updateMultipleGoals(with: parsedFunction.arguments)
        case "complete_multiple_goals":
            return await self.completeMultipleGoals(with: parsedFunction.arguments)
        case "add_milestone":
            return await self.addMilestone(with: parsedFunction.arguments)
        case "add_multiple_milestones":
            return await self.addMultipleMilestones(with: parsedFunction.arguments)
        case "complete_milestone":
            return await self.completeMilestone(with: parsedFunction.arguments)
        case "delete_milestone":
            return await self.deleteMilestone(with: parsedFunction.arguments)
        case "delete_multiple_milestones":
            return await self.deleteMultipleMilestones(with: parsedFunction.arguments)
        case "create_multiple_categories":
            return await self.createMultipleCategories(with: parsedFunction.arguments)
        case "update_multiple_categories":
            return await self.updateMultipleCategories(with: parsedFunction.arguments)
        case "delete_multiple_categories":
            return await self.deleteMultipleCategories(with: parsedFunction.arguments)
        case "delete_all_categories":
            return await self.deleteAllCategories(with: parsedFunction.arguments) */
        default:
            // If not "manage", it's an unknown or disabled function
            return FunctionCallResult(
                functionName: parsedFunction.name,
                success: false,
                message: "ERROR: Function '\(parsedFunction.name)' is not available. Please use the 'manage' function instead.\n\nExample: manage(type: 'event', action: 'create', parameters: {...})",
                details: ["error": "deprecated_function", "function": parsedFunction.name, "suggestion": "Use manage() instead"]
            )
        }
    }
    
    // MARK: - Old Functions DELETED
    // 103 old functions (9187 lines) removed. Use the 5 new simplified functions instead:
    // - manage_events
    // - manage_tasks
    // - manage_habits
    // - manage_goals
    // - manage_categories
    
    // MARK: - Bulk Action Handler
    
    func handleBulkAction(_ action: BulkActionPreview.BulkAction, for messageId: UUID) {
        // Get bulk action preview from message
        guard let bulkActionPreview = messages.first(where: { $0.id == messageId })?.bulkActionPreview else { return }
        
        // Delegate to bulk operations view model
        bulkOperationsViewModel.handleBulkAction(action, preview: bulkActionPreview, messageId: messageId.uuidString)
    }
    
    // MARK: - Helper Functions (Restored for compatibility)
    
    private func actuallyCreateEvent(with arguments: [String: Any]) async -> FunctionCallResult {
        // This is a helper for the manage function - redirect to new system
        return await routeToSimplifiedSystem(functionName: "manage_events", parameters: ["action": "create", "parameters": arguments])
    }
    
    private func manage(with arguments: [String: Any]) async -> FunctionCallResult {
        // Legacy manage function - kept for compatibility
        guard let type = arguments["type"] as? String,
              let action = arguments["action"] as? String else {
            return FunctionCallResult(
                functionName: "manage",
                success: false,
                message: "Missing required parameters: type and action",
                details: nil
            )
        }
        
        let params = arguments["parameters"] as? [String: Any] ?? [:]
        
        switch type.lowercased() {
        case "event", "events":
            return await routeToSimplifiedSystem(functionName: "manage_events", parameters: ["action": action, "parameters": params])
        case "task", "tasks":
            return await routeToSimplifiedSystem(functionName: "manage_tasks", parameters: ["action": action, "parameters": params])
        case "habit", "habits":
            return await routeToSimplifiedSystem(functionName: "manage_habits", parameters: ["action": action, "parameters": params])
        case "goal", "goals":
            return await routeToSimplifiedSystem(functionName: "manage_goals", parameters: ["action": action, "parameters": params])
        case "category", "categories":
            return await routeToSimplifiedSystem(functionName: "manage_categories", parameters: ["action": action, "parameters": params])
        default:
            return FunctionCallResult(
                functionName: "manage",
                success: false,
                message: "Unknown type: \(type)",
                details: nil
            )
        }
    }
    
    private func handleGenericError(_ error: Error) {
        let errorMessage = ChatMessage(
            content: "I encountered an error: \(error.localizedDescription). Please try again.",
            sender: .assistant,
            timestamp: Date()
        )
        messages.append(errorMessage)
    }
    
    private func handleStreamingError(_ error: Error, messageId: UUID) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].content = "I encountered an error while processing your request: \(error.localizedDescription)"
            messages[index].isStreaming = false
        }
    }
    
    private func createEventPreview(from result: FunctionCallResult, functionName: String) -> EventPreview? {
        guard let details = result.details else {
            return nil
        }
        
        // Extract actual event data from details
        var title = "Untitled Event"
        var timeDescription = "Scheduled"
        var location: String? = nil
        var category: String? = nil
        var isMultiDay = false
        let dayCount = 1
        
        // Check for event data in different possible locations
        // Since details is [String: String], we work with strings directly
        if let eventTitle = details["title"] {
            title = eventTitle
        }
        
        if let eventLocation = details["location"] {
            location = eventLocation
        }
        
        if let eventCategory = details["category"] {
            category = eventCategory
        }
        
        // Format time description from start and end times
        if let startTime = details["startTime"],
           let endTime = details["endTime"] {
            timeDescription = "\(startTime) - \(endTime)"
        } else if let startTime = details["startTime"] {
            timeDescription = startTime
        }
        
        // Check if multi-day
        if let startDate = details["startDate"],
           let endDate = details["endDate"],
           startDate != endDate {
            isMultiDay = true
            // Calculate day count if possible
            timeDescription = "\(startDate) - \(endDate)"
        } else {
            // Fallback: try to extract from message
            let messageComponents = result.message.components(separatedBy: ": ")
            if messageComponents.count > 1 {
                title = messageComponents.last ?? title
            }
        }
        
        // Determine icon based on category or use default
        let icon = getIconForCategory(category) ?? "📅"
        
        // Determine actions based on function name
        let actions: [EventAction] = functionName == "update_event" ? 
            [.edit, .delete] : [.edit, .delete, .complete]
        
        return EventPreview(
            id: UUID().uuidString,
            icon: icon,
            title: title,
            timeDescription: timeDescription,
            location: location,
            category: category,
            isMultiDay: isMultiDay,
            dayCount: dayCount,
            dayBreakdown: nil,
            actions: actions
        )
    }
    
    private func getIconForCategory(_ category: String?) -> String? {
        guard let category = category else { return nil }
        
        switch category.lowercased() {
        case "work", "meeting": return "💼"
        case "personal": return "🏠"
        case "health", "exercise", "fitness": return "💪"
        case "travel", "vacation": return "✈️"
        case "education", "learning": return "📚"
        case "social", "party": return "🎉"
        case "appointment", "medical": return "🏥"
        default: return "📅"
        }
    }
    
    private func createMultipleEventsPreview(from result: FunctionCallResult) -> [EventListItem]? {
        guard result.success else { return nil }
        
        // Parse events from result
        var events: [EventListItem] = []
        
        if let data = result.details?["data"] as? [[String: Any]] {
            for eventData in data {
                if let title = eventData["title"] as? String {
                    let startTime = eventData["startTime"] as? String ?? "TBD"
                    events.append(EventListItem(
                        id: UUID().uuidString,
                        time: startTime,
                        title: title,
                        isCompleted: false,
                        date: Date()
                    ))
                }
            }
        }
        
        return events.isEmpty ? nil : events
    }
    
    private func createBulkActionPreview(from result: FunctionCallResult, functionName: String) -> BulkActionPreview? {
        let count = result.details?["count"] as? Int ?? 1
        
        let (icon, title, description, warningLevel, actionType) = getActionDetails(for: functionName, count: count)
        
        return BulkActionPreview(
            id: UUID().uuidString,
            action: actionType,
            icon: icon,
            title: title,
            description: description,
            affectedCount: count,
            dateRange: nil,
            warningLevel: warningLevel,
            actions: [.confirm, .cancel]
        )
    }
    
    private func getActionDetails(for functionName: String, count: Int) -> (icon: String, title: String, description: String, warningLevel: BulkActionPreview.WarningLevel, action: String) {
        switch functionName {
        case "delete_event", "delete_all_events":
            return ("🗑️", "Delete Events", "\(count) event(s) will be deleted", .critical, "delete")
        case "update_all_events":
            return ("✏️", "Update Events", "\(count) event(s) will be updated", .caution, "update")
        case "mark_all_complete":
            return ("✅", "Complete Events", "\(count) event(s) will be marked as complete", .normal, "complete")
        default:
            return ("⚡", "Bulk Action", "\(count) item(s) will be affected", .caution, "update")
        }
    }
    
    // MARK: - Category Matching Helpers
    
    private func findBestMatchingCategory(for term: String) -> Category? {
        let lowercasedTerm = term.lowercased()
        
        // Define mappings for common terms to default categories
        let categoryMappings: [String: [String]] = [
            "work": ["work", "job", "office", "business", "project", "meeting", "conference", "presentation"],
            "personal": ["personal", "private", "me time", "self", "own"],
            "health": ["health", "medical", "doctor", "hospital", "checkup", "therapy"],
            "learning": ["learning", "study", "education", "course", "class", "lecture", "homework", "research"],
            "meeting": ["meeting", "call", "zoom", "teams", "conference", "interview", "standup", "1:1"],
            "fitness": ["fitness", "gym", "workout", "exercise", "run", "yoga", "sport", "training"],
            "finance": ["finance", "money", "bank", "budget", "payment", "investment", "accounting"],
            "family": ["family", "kids", "parent", "spouse", "relative", "home"],
            "social": ["social", "friend", "party", "dinner", "lunch", "coffee", "date", "hangout"],
            "other": ["other", "misc", "miscellaneous", "general"]
        ]
        
        // First, try to find exact match in existing categories
        let categories = scheduleManager.getCategories()
        
        // Check for exact name match
        if let exactMatch = categories.first(where: { $0.name?.lowercased() == lowercasedTerm }) {
            return exactMatch
        }
        
        // Check if term contains any category name
        for category in categories {
            if let categoryName = category.name?.lowercased(),
               lowercasedTerm.contains(categoryName) || categoryName.contains(lowercasedTerm) {
                return category
            }
        }
        
        // Check against category mappings
        for (defaultCategoryName, keywords) in categoryMappings {
            if keywords.contains(where: { lowercasedTerm.contains($0) || $0.contains(lowercasedTerm) }) {
                // Find or create the default category
                if let existingCategory = categories.first(where: { $0.name?.lowercased() == defaultCategoryName }) {
                    return existingCategory
                }
            }
        }
        
        // Return the "Other" category as fallback
        return categories.first(where: { $0.name?.lowercased() == "other" })
    }
}

// MARK: - Extensions (if any)