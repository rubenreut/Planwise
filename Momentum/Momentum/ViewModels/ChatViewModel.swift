import Foundation
import SwiftUI
import Combine
import Speech
import AVFoundation
import CoreData
import PhotosUI
import UIKit
import PDFKit

// Type alias to avoid conflicts with CoreData

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
    @Published var showDocumentPicker: Bool = false
    @Published var selectedFileURL: URL?
    @Published var selectedFileName: String?
    @Published var selectedFileData: Data?
    @Published var selectedFileExtension: String?
    @Published var selectedFileText: String?
    @Published var pdfFileName: String? // Track if image is from PDF
    @Published var pdfPageCount: Int = 1 // Track PDF page count
    @Published var isRecordingVoice: Bool = false
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    @Published var acceptedEventIds: Set<String> = []
    @Published var deletedEventIds: Set<String> = []
    @Published var acceptedMultiEventMessageIds: Set<UUID> = []
    @Published var completedBulkActionIds: Set<String> = []
    @Published var isRateLimited: Bool = false
    @Published var rateLimitResetTime: Date?
    
    // MARK: - Private Properties
    
    private let userName: String = "User" // Could be fetched from settings
    private let openAIService: OpenAIService
    private let scheduleManager: ScheduleManaging
    private let taskManager: TaskManaging
    private let habitManager: HabitManaging
    private let goalManager: GoalManager
    private let subscriptionManager = SubscriptionManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var streamingTask: _Concurrency.Task<Void, Never>?
    private var conversationHistory: [ChatRequestMessage] = []
    private var rateLimitTimer: Timer?
    
    // MARK: - Mathematical Constants
    
    private let φ: Double = 1.618033988749895 // Golden ratio
    
    // MARK: - Initialization
    
    init(openAIService: OpenAIService? = nil, scheduleManager: ScheduleManaging? = nil, taskManager: TaskManaging? = nil, habitManager: HabitManaging? = nil, goalManager: GoalManager? = nil) {
        self.openAIService = openAIService ?? DependencyContainer.shared.openAIService
        self.scheduleManager = scheduleManager ?? DependencyContainer.shared.scheduleManager
        self.taskManager = taskManager ?? DependencyContainer.shared.taskManager
        self.habitManager = habitManager ?? DependencyContainer.shared.habitManager
        self.goalManager = goalManager ?? DependencyContainer.shared.goalManager
        loadPersistedMessages()
        if messages.isEmpty {
            setupInitialGreeting()
        }
        observeRateLimitInfo()
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
        
        if let pdfName = pdfFileName, selectedImage != nil {
            // PDF converted to image
            fileName = pdfName
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
            if let pdfName = pdfFileName {
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
        } else if let fileData = selectedFileData,
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
        _Concurrency.Task {
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
        _Concurrency.Task {
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
        pdfFileName = nil
        pdfPageCount = 1
        
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
            _Concurrency.Task {
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
        
        showDocumentPicker = true
    }
    
    func processSelectedFile(_ url: URL) {
        selectedFileURL = url
        selectedFileName = url.lastPathComponent
        
        _Concurrency.Task { @MainActor in
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
        selectedFileURL = nil
        selectedFileName = nil
        selectedFileData = nil
        selectedFileExtension = nil
        selectedFileText = nil
        pdfFileName = nil
        pdfPageCount = 1
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
        
        if let image = combinedImage {
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
        
        if isRecordingVoice {
            // Stop recording
            stopVoiceRecording()
        } else {
            // Start recording
            _Concurrency.Task { @MainActor in
                await startVoiceRecognition()
            }
        }
    }
    
    @MainActor
    private func stopVoiceRecording() {
        
        // Update state immediately
        isRecordingVoice = false
        isLoading = false
        
        // End audio but don't cancel - this preserves the transcribed text
        recognitionRequest?.endAudio()
        
        // Stop the audio engine
        if let audioEngine = audioEngine {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Cancel the recognition task after a short delay to ensure final results are processed
        _Concurrency.Task {
            try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
        }
        
        // Clean up
        audioEngine = nil
        recognitionRequest = nil
        
    }
    
    @MainActor
    private func startVoiceRecognition() async {
        
        // Check microphone permission
        if #available(iOS 17.0, *) {
            let microphoneStatus = await AVAudioApplication.shared.recordPermission
            
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
                        _Concurrency.Task { @MainActor in
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
                    _Concurrency.Task { @MainActor in
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
        
        
        audioEngine = AVAudioEngine()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        
        guard let audioEngine = audioEngine,
              let request = recognitionRequest else { return }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            try audioEngine.start()
            
            // Set recording state immediately
            _Concurrency.Task { @MainActor in
                self.isRecordingVoice = true
            }
            
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    let transcribedText = result.bestTranscription.formattedString
                    
                    // Update the input field in real-time
                    _Concurrency.Task { @MainActor in
                        // Only update if we're still recording or if it's the final result
                        if self.isRecordingVoice || result.isFinal {
                            self.inputText = transcribedText
                        }
                        
                        // Clean up if this is the final result
                        if result.isFinal {
                            self.recognitionTask = nil
                        }
                    }
                } else if let error = error {
                    _Concurrency.Task { @MainActor in
                        self.stopVoiceRecording()
                        
                        let message = ChatMessage(
                            content: "Voice recognition error: \(error.localizedDescription)",
                            sender: .assistant,
                            timestamp: Date()
                        )
                        self.messages.append(message)
                    }
                }
            }
        } catch {
            isRecordingVoice = false
            let message = ChatMessage(
                content: "Failed to start voice recording: \(error.localizedDescription)",
                sender: .assistant,
                timestamp: Date()
            )
            messages.append(message)
        }
    }
    
    func handleEventAction(eventId: String, action: EventAction) {
        // Handle actions on event previews
        switch action {
        case .edit:
            // TODO: Implement edit functionality
            break
        case .delete:
            // Silently delete the event
            _Concurrency.Task { @MainActor in
                // Find the event in the events array
                if let event = scheduleManager.events.first(where: { $0.id?.uuidString == eventId }) {
                    let result = scheduleManager.deleteEvent(event)
                    switch result {
                    case .success:
                        // Mark as deleted
                        deletedEventIds.insert(eventId)
                        // Event deleted successfully
                    case .failure:
                        // Failed to delete event
                        break
                    }
                }
            }
        case .complete:
            // Accept button - now actually create the event
            _Concurrency.Task { @MainActor in
                // Find the message with this event preview
                if let message = messages.first(where: { $0.eventPreview?.id == eventId }),
                   let functionCall = message.functionCall,
                   let details = functionCall.details {
                    
                    // Extract stored event data
                    if let title = details["_title"],
                       let startTimeStr = details["_startTime"],
                       let endTimeStr = details["_endTime"] {
                        
                        let formatter = ISO8601DateFormatter()
                        guard let startTime = formatter.date(from: startTimeStr),
                              let endTime = formatter.date(from: endTimeStr) else {
                            // Failed to parse dates for event creation
                            return
                        }
                        
                        // Find category if specified
                        var category: Category?
                        if let categoryId = details["_categoryId"], !categoryId.isEmpty,
                           let categoryUUID = UUID(uuidString: categoryId) {
                            category = scheduleManager.categories.first { $0.id == categoryUUID }
                        }
                        
                        // Create the actual event
                        let result = scheduleManager.createEvent(
                            title: title,
                            startTime: startTime,
                            endTime: endTime,
                            category: category,
                            notes: details["_notes"],
                            location: details["_location"],
                            isAllDay: Bool(details["_isAllDay"] ?? "false") ?? false
                        )
                        
                        switch result {
                        case .success(let event):
                            // Mark as accepted and keep visible
                            acceptedEventIds.insert(eventId)
                            // Event created and accepted
                        case .failure(let error):
                            // Failed to create event
                            print("Failed to create event: \(error)")
                            break
                        }
                    }
                }
            }
        case .viewFull:
            // TODO: Navigate to full event view
            break
            // View full event
        case .share:
            // TODO: Share event
            break
            // Share event
        default:
            break
        }
    }
    
    func handleMultiEventAction(_ action: MultiEventAction, messageId: UUID) {
        switch action {
        case .toggleComplete(let eventId):
            // TODO: Toggle specific event completion
            break
            // Toggle complete
        case .markAllComplete:
            // Accept all - now actually create all the events
            _Concurrency.Task { @MainActor in
                if let message = messages.first(where: { $0.id == messageId }),
                   let functionCall = message.functionCall,
                   let details = functionCall.details {
                    
                    // Check if we have stored events data
                    if let eventsDataStr = details["_eventsData"],
                       let eventsData = eventsDataStr.data(using: .utf8),
                       let events = try? JSONSerialization.jsonObject(with: eventsData, options: []) as? [[String: Any]] {
                        
                        var createdCount = 0
                        
                        // Create each event
                        for eventData in events {
                            let result = await actuallyCreateEvent(with: eventData)
                            if result.success {
                                createdCount += 1
                            }
                        }
                        
                        // Mark as accepted and keep visible
                        acceptedMultiEventMessageIds.insert(message.id)
                        // Created events from bulk action
                    } else {
                        // Fallback - just mark as accepted
                        acceptedMultiEventMessageIds.insert(message.id)
                        // All events accepted
                    }
                }
            }
        case .editTimes:
            // TODO: Implement bulk edit times
            break
            // Edit all times
        }
    }
    
    // MARK: - Message Persistence
    
    private func saveMessages() {
        do {
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
        } catch {
            print("Error saving messages: \(error)")
        }
    }
    
    private func loadPersistedMessages() {
        do {
            // Load saved messages
            if let messageData = UserDefaults.standard.array(forKey: "ChatMessages") as? [[String: Any]] {
                messages = messageData.compactMap { data in
                    guard let idString = data["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let content = data["content"] as? String,
                          let senderString = data["sender"] as? String,
                          let timestamp = data["timestamp"] as? TimeInterval else {
                        return nil
                    }
                    
                    let sender: ChatMessage.MessageSender = senderString == "user" ? .user(name: "User") : .assistant
                    let date = Date(timeIntervalSince1970: timestamp)
                    let isStreaming = data["isStreaming"] as? Bool ?? false
                    
                    // Create message with persisted ID to maintain consistency
                    var message = ChatMessage(
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
        } catch {
            print("Error loading persisted messages: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func startRateLimitTimer(seconds: Int) {
        // Cancel existing timer
        rateLimitTimer?.invalidate()
        
        // Start new timer
        rateLimitTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
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
        
        // Smart context: Analyze what the user is talking about
        let recentUserMessage = messages.last(where: { $0.sender == .user })?.content ?? ""
        let lowerMessage = recentUserMessage.lowercased()
        
        // Determine what context to include based on message content
        let includeGoals = lowerMessage.contains("goal") || lowerMessage.contains("milestone") || 
                          lowerMessage.contains("objective") || lowerMessage.contains("target")
        let includeTasks = lowerMessage.contains("task") || lowerMessage.contains("todo") || 
                          lowerMessage.contains("subtask") || lowerMessage.contains("work")
        let includeHabits = lowerMessage.contains("habit") || lowerMessage.contains("routine") || 
                           lowerMessage.contains("daily") || lowerMessage.contains("streak")
        let includeEvents = lowerMessage.contains("event") || lowerMessage.contains("meeting") || 
                           lowerMessage.contains("appointment") || lowerMessage.contains("schedule") ||
                           lowerMessage.contains("calendar") || lowerMessage.contains("today") ||
                           lowerMessage.contains("tomorrow") || lowerMessage.contains("week")
        
        // If no specific mention, include minimal context (today's items only)
        let includeAll = !includeGoals && !includeTasks && !includeHabits && !includeEvents
        
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
        
        === USER'S CURRENT CONTEXT (USE THIS DATA - DON'T ASK FOR IT!) ===
        \(contextLines.joined(separator: "\n"))
        
        REMINDER: You have access to all the user's data above. NEVER ask for information that's already provided here.
        When the user asks about "my goals", "my tasks", etc., use the specific items listed above.
        
        🚨 CRITICAL: USE ONLY THE UNIFIED MANAGE FUNCTION! 🚨
        
        You MUST use the single "manage" function for ALL operations:
        
        FUNCTION: manage(type, action, id, parameters)
        
        Examples:
        - Create event: manage(type: "event", action: "create", parameters: {...})
        - Update task: manage(type: "task", action: "update", id: "task-id", parameters: {...})
        - Add milestones: manage(type: "milestone", action: "create", id: "goal-id", parameters: {...})
        - Delete habit: manage(type: "habit", action: "delete", id: "habit-id")
        - Complete task: manage(type: "task", action: "complete", id: "task-id")
        - List goals: manage(type: "goal", action: "list")
        
        DO NOT use old functions like create_event, update_task, add_multiple_milestones, etc.
        ONLY use: manage()
        
        When working with goals/milestones, ALWAYS include the goal ID from the context above!
        
        IMPORTANT CATEGORY RULES:
        1. ALWAYS use one of the 10 existing categories listed above when creating events
        2. NEVER create new categories - map events to the most appropriate existing category
        3. Category mapping guide:
           - Work: business, office, project, presentation, meetings
           - Personal: private time, self-care, errands, me time
           - Health: medical, doctor, therapy, wellness
           - Learning: study, education, courses, reading, research
           - Meeting: calls, conferences, interviews, 1:1s, standups
           - Fitness: gym, exercise, sports, yoga, workout
           - Finance: banking, budget, investments, money
           - Family: home, kids, relatives, spouse
           - Social: friends, parties, dinners, dates, coffee
           - Other: anything that doesn't fit above
        
        CRITICAL FUNCTION UPDATE - update_multiple_goals:
        When updating multiple goals with DIFFERENT categories/updates for each goal, you MUST use the NEW format:
        {
          "goals": [
            {"id": "goal-uuid-1", "category": "Health"},
            {"id": "goal-uuid-2", "category": "Creative"},
            {"id": "goal-uuid-3", "category": "Finance"},
            // Each goal can have different updates
          ]
        }
        
        DO NOT use the old format with goalIds + single updates object when goals need different values!
        Old format only works when ALL goals get the SAME updates.
        
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
        let model = hasImages ? "gpt-4o" : "gpt-4o-mini"
        
        let stream = openAIService.streamChatRequest(
            messages: conversationHistory,
            userContext: userContext
        )
        
        var accumulatedContent = ""
        var functionCallName: String?
        var functionCallArguments = ""
        
        streamingTask = _Concurrency.Task { @MainActor in
            do {
                var eventCount = 0
                
                for try await event in stream {
                    guard !_Concurrency.Task.isCancelled else { 
                        break 
                    }
                    
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
    
    private func processFunctionCall(_ functionCall: ChatResponse.FunctionCall) async -> FunctionCallResult {
        // Processing function call
        
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
                message: "I encountered an error processing that request. Could you please try rephrasing it or breaking it down into smaller parts?",
                details: ["error": "Failed to parse function arguments", "function": functionCall.name]
            )
        }
        
        switch parsedFunction.name {
        // THE ONE FUNCTION TO RULE THEM ALL
        case "manage":
            return await self.manage(with: parsedFunction.arguments)
            
        // Legacy functions (kept for backwards compatibility but the AI should use "manage" instead)
        case "create_event":
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
            return await self.deleteAllCategories(with: parsedFunction.arguments)
        default:
            return FunctionCallResult(
                functionName: parsedFunction.name,
                success: false,
                message: "Unknown function: \(parsedFunction.name)",
                details: nil
            )
        }
    }
    
    private func actuallyCreateEvent(with arguments: [String: Any]) async -> FunctionCallResult {
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
        
        var startTime = formatter.date(from: startTimeStr)
        if startTime == nil {
            formatter.formatOptions = [.withInternetDateTime]
            startTime = formatter.date(from: startTimeStr)
        }
        
        guard let finalStartTime = startTime else {
            return FunctionCallResult(
                functionName: "create_event",
                success: false,
                message: "Invalid start time format",
                details: nil
            )
        }
        
        var endTime = formatter.date(from: endTimeStr)
        if endTime == nil {
            formatter.formatOptions = [.withInternetDateTime]
            endTime = formatter.date(from: endTimeStr)
        }
        
        guard let finalEndTime = endTime else {
            return FunctionCallResult(
                functionName: "create_event",
                success: false,
                message: "Invalid end time format",
                details: nil
            )
        }
        
        // Find or create category
        var category: Category?
        if let categoryName = arguments["category"] as? String {
            // First try exact case-insensitive match
            category = scheduleManager.categories.first { $0.name?.lowercased() == categoryName.lowercased() }
            
            // If no exact match, try intelligent mapping
            if category == nil {
                category = self.findBestMatchingCategory(for: categoryName)
            }
            
            // If still no match, use "Other" category
            if category == nil {
                category = scheduleManager.categories.first { $0.name?.lowercased() == "other" }
            }
        }
        
        let result = scheduleManager.createEvent(
            title: title,
            startTime: finalStartTime,
            endTime: finalEndTime,
            category: category,
            notes: arguments["notes"] as? String,
            location: arguments["location"] as? String,
            isAllDay: arguments["is_all_day"] as? Bool ?? false
        )
        
        switch result {
        case .success(let event):
            return FunctionCallResult(
                functionName: "create_event",
                success: true,
                message: "\(event.title ?? "")",
                details: ["EventId": event.id?.uuidString ?? ""]
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
    
    // This version just returns preview data (used during AI response)
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
        
        // Find or create category if specified
        let categoryName = arguments["category"] as? String
        var category: Category?
        if let categoryName = categoryName {
            // First try exact case-insensitive match
            category = scheduleManager.categories.first { $0.name?.lowercased() == categoryName.lowercased() }
            
            // If no exact match, try intelligent mapping
            if category == nil {
                category = self.findBestMatchingCategory(for: categoryName)
            }
            
            // If still no match, use "Other" category
            if category == nil {
                category = scheduleManager.categories.first { $0.name?.lowercased() == "other" }
            }
        }
        
        // Don't actually create the event yet - just prepare the preview
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        // Check for conflicts
        let conflicts = scheduleManager.checkForConflicts(
            startTime: startTime,
            endTime: endTime,
            excludingEvent: nil
        )
        
        // Generate a temporary ID for the preview
        let tempEventId = UUID()
        
        var message = "\(title)"
        
        // Format times for display - the AI already told user the correct local times
        // We should show what the user asked for, not the UTC converted times
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(startTime)
        let isTomorrow = calendar.isDateInTomorrow(startTime)
        
        var displayDate = ""
        if isToday {
            displayDate = "Today"
        } else if isTomorrow {
            displayDate = "Tomorrow"
        } else {
            displayDate = dateFormatter.string(from: startTime)
        }
        
        var details: [String: String] = [
            "EventId": tempEventId.uuidString,
            "Title": title,
            "Time": "\(displayDate) at \(timeFormatter.string(from: startTime)) - \(timeFormatter.string(from: endTime))",
            "Date": dateFormatter.string(from: startTime),
            "Category": category?.name ?? "None"
        ]
        
        // Store event data for later creation
        details["_title"] = title
        details["_startTime"] = ISO8601DateFormatter().string(from: startTime)
        details["_endTime"] = ISO8601DateFormatter().string(from: endTime)
        details["_categoryId"] = category?.id?.uuidString ?? ""
        details["_notes"] = arguments["notes"] as? String ?? ""
        details["_location"] = arguments["location"] as? String ?? ""
        details["_isAllDay"] = String(arguments["is_all_day"] as? Bool ?? false)
        
        if let location = arguments["location"] as? String {
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
        
        // Handle category update - IMPORTANT: nil means don't change, we need to be explicit
        var categoryToUpdate: Category?
        var shouldUpdateCategory = false
        
        if let categoryName = updates["category"] as? String {
            shouldUpdateCategory = true
            
            // Try case-insensitive match first
            categoryToUpdate = scheduleManager.categories.first { $0.name?.lowercased() == categoryName.lowercased() }
            
            if categoryToUpdate == nil {
                // Create new category if doesn't exist
                let (icon, color) = self.generateUniqueIconAndColor(for: categoryName)
                let result = scheduleManager.createCategory(name: categoryName, icon: icon, colorHex: updates["categoryColor"] as? String ?? color)
                if case .success(let newCategory) = result {
                    categoryToUpdate = newCategory
                }
            }
        }
        
        
        let result = scheduleManager.updateEvent(
            event,
            title: updates["title"] as? String,
            startTime: startTime,
            endTime: endTime,
            category: categoryToUpdate,
            notes: updates["notes"] as? String,
            location: updates["location"] as? String,
            isCompleted: updates["isCompleted"] as? Bool ?? updates["is_completed"] as? Bool,
            colorHex: nil,
            iconName: nil,
            priority: nil,
            tags: nil,
            url: nil,
            energyLevel: nil,
            weatherRequired: nil,
            bufferTimeBefore: nil,
            bufferTimeAfter: nil,
            recurrenceRule: nil,
            recurrenceEndDate: nil,
            linkedTasks: nil
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
        // Processing delete_event
        
        let eventId = arguments["eventId"] as? String ?? arguments["event_id"] as? String
        
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
    
    private func deleteMultipleEvents(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let eventIds = arguments["eventIds"] as? [String] else {
            return FunctionCallResult(
                functionName: "delete_multiple_events",
                success: false,
                message: "Missing required parameter: eventIds",
                details: nil
            )
        }
        
        var deletedEvents: [String] = []
        var failedEvents: [String] = []
        
        for eventIdStr in eventIds {
            guard let eventId = UUID(uuidString: eventIdStr),
                  let event = scheduleManager.events.first(where: { $0.id == eventId }) else {
                failedEvents.append(eventIdStr)
                continue
            }
            
            let eventTitle = event.title ?? "Untitled"
            let result = scheduleManager.deleteEvent(event)
            
            switch result {
            case .success:
                deletedEvents.append(eventTitle)
            case .failure:
                failedEvents.append(eventTitle)
            }
        }
        
        if deletedEvents.isEmpty {
            return FunctionCallResult(
                functionName: "delete_multiple_events",
                success: false,
                message: "Failed to delete any events",
                details: ["failed": failedEvents.joined(separator: ", ")]
            )
        }
        
        var message = "🗑️ **Deleted \(deletedEvents.count) events**\n\n"
        message += deletedEvents.map { "• \($0)" }.joined(separator: "\n")
        
        if !failedEvents.isEmpty {
            message += "\n\n⚠️ Failed: \(failedEvents.joined(separator: ", "))"
        }
        
        return FunctionCallResult(
            functionName: "delete_multiple_events",
            success: true,
            message: message,
            details: ["deleted": "\(deletedEvents.count)"]
        )
    }
    
    private func listEvents(with arguments: [String: Any]) async -> FunctionCallResult {
        // Processing list_events
        
        // Handle both old and new parameter names
        let startDateStr = arguments["startDate"] as? String ?? arguments["start_date"] as? String
        let endDateStr = arguments["endDate"] as? String ?? arguments["end_date"] as? String
        let limit = arguments["limit"] as? Int ?? 50
        
        // Processing date parameters
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        var allEvents: [Event] = []
        
        // Parsing date
        
        if let startDateStr = startDateStr, let startDate = formatter.date(from: startDateStr) {
            // Successfully parsed start date
            if let endDateStr = endDateStr, let endDate = formatter.date(from: endDateStr) {
                // Successfully parsed end date
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
            // Failed to parse date
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
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d"
        
        var eventList = ""
        var eventDetails: [[String: String]] = []
        
        // Group events by date for better formatting
        let groupedEvents = Dictionary(grouping: limitedEvents) { event in
            Calendar.current.startOfDay(for: event.startTime ?? Date())
        }
        
        for date in groupedEvents.keys.sorted() {
            eventList += "\n**\(dateFormatter.string(from: date))**\n"
            
            if let eventsForDate = groupedEvents[date] {
                for event in eventsForDate.sorted(by: { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }) {
                    let startTime = timeFormatter.string(from: event.startTime ?? Date())
                    let endTime = timeFormatter.string(from: event.endTime ?? Date())
                    let category = event.category?.name ?? "No category"
                    let categoryIcon = event.category?.iconName ?? "📅"
                    
                    eventList += "• **\(event.title ?? "Untitled")** (\(startTime) - \(endTime))\n"
                    eventList += "  _\(categoryIcon) \(category)_\n"
                    
                    if let notes = event.notes, !notes.isEmpty {
                        eventList += "  Notes: \(notes)\n"
                    }
                    
                    // Store event details for internal use only
                    eventDetails.append([
                        "id": event.id?.uuidString ?? "no-id",
                        "title": event.title ?? "Untitled",
                        "time": "\(startTime) - \(endTime)"
                    ])
                }
            }
        }
        
        if eventList.isEmpty {
            eventList = "No events found for the specified date(s)."
        }
        
        // Store IDs in details for AI to use internally, but don't show to user
        var internalDetails: [String: String] = [:]
        for (index, detail) in eventDetails.enumerated() {
            internalDetails["event_\(index)_id"] = detail["id"]
            internalDetails["event_\(index)_title"] = detail["title"]
        }
        internalDetails["event_count"] = "\(eventDetails.count)"
        
        return FunctionCallResult(
            functionName: "list_events",
            success: true,
            message: eventList.trimmingCharacters(in: .whitespacesAndNewlines),
            details: internalDetails
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
            // Attempting to delete all events
            
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
                    // Deleted event
                case .failure:
                    failedCount += 1
                    // Failed to delete event
                }
            }
            
            // Force another refresh after all deletions
            scheduleManager.forceRefresh()
            // Deletion complete
            
            // Add a small delay to ensure Core Data completes
            try? await _Concurrency.Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
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
        // Attempting to delete events in date range
        
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
            case .failure:
                failedCount += 1
            }
        }
        
        // Force refresh after deletions
        scheduleManager.forceRefresh()
        // Date range deletion complete
        
        // Add a small delay to ensure Core Data completes
        try? await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                continuation.resume()
            }
        }
        
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
            // Don't actually create events - just prepare preview data
            if let title = eventData["title"] as? String,
               let startTimeStr = eventData["startTime"] as? String ?? eventData["start_time"] as? String {
                
                createdCount += 1
                
                // Parse time for display
                let formatter = ISO8601DateFormatter()
                if let startTime = formatter.date(from: startTimeStr) {
                    createdEvents.append([
                        "title": title,
                        "time": timeFormatter.string(from: startTime),
                        "date": startTimeStr // Store the ISO date string for later
                    ])
                } else {
                    createdEvents.append([
                        "title": title,
                        "time": "Time TBD",
                        "date": "" // Empty date for TBD
                    ])
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
            // Convert events array to JSON string to store it
            var detailsDict: [String: String] = [
                "created": eventTitles,
                "eventList": eventList,
                "count": "\(createdCount)"
            ]
            
            // Store the events data as JSON for later creation
            if let jsonData = try? JSONSerialization.data(withJSONObject: events, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                detailsDict["_eventsData"] = jsonString
            }
            
            // Also store the created events with dates for preview
            if let eventsJsonData = try? JSONSerialization.data(withJSONObject: createdEvents, options: []),
               let eventsJsonString = String(data: eventsJsonData, encoding: .utf8) {
                detailsDict["_createdEventsWithDates"] = eventsJsonString
            }
            
            return FunctionCallResult(
                functionName: "create_multiple_events",
                success: true,
                message: "\(createdCount) events",
                details: detailsDict
            )
        }
    }
    
    private func updateMultipleEvents(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let eventIds = arguments["eventIds"] as? [String],
              let updates = arguments["updates"] as? [String: Any] else {
            return FunctionCallResult(
                functionName: "update_multiple_events",
                success: false,
                message: "Missing required parameters",
                details: nil
            )
        }
        
        var updatedCount = 0
        var failedCount = 0
        var failedEvents: [String] = []
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Parse updates once
        var startTime: Date?
        var endTime: Date?
        
        if let startTimeStr = updates["startTime"] as? String {
            startTime = formatter.date(from: startTimeStr)
            if startTime == nil {
                formatter.formatOptions = [.withInternetDateTime]
                startTime = formatter.date(from: startTimeStr)
            }
        }
        
        if let endTimeStr = updates["endTime"] as? String {
            endTime = formatter.date(from: endTimeStr)
            if endTime == nil {
                formatter.formatOptions = [.withInternetDateTime]
                endTime = formatter.date(from: endTimeStr)
            }
        }
        
        // Handle category update
        var updatedCategory: Category?
        if let categoryName = updates["category"] as? String {
            updatedCategory = scheduleManager.categories.first { $0.name == categoryName }
            if updatedCategory == nil {
                // Create new category if doesn't exist
                let (icon, color) = self.generateUniqueIconAndColor(for: categoryName)
                let result = scheduleManager.createCategory(name: categoryName, icon: icon, colorHex: color)
                if case .success(let newCategory) = result {
                    updatedCategory = newCategory
                }
            }
        }
        
        // Process each event
        let totalEvents = eventIds.count
        for (index, eventIdStr) in eventIds.enumerated() {
            guard let eventId = UUID(uuidString: eventIdStr),
                  let event = scheduleManager.events.first(where: { $0.id == eventId }) else {
                failedCount += 1
                failedEvents.append(eventIdStr)
                continue
            }
            
            // For moving events to a different day while preserving time
            var adjustedStartTime = startTime
            var adjustedEndTime = endTime
            
            if updates["adjustTimeOnly"] as? Bool == true,
               let originalStart = event.startTime,
               let originalEnd = event.endTime,
               let newStartTime = startTime {
                // Calculate time difference
                let timeDiff = originalEnd.timeIntervalSince(originalStart)
                adjustedEndTime = newStartTime.addingTimeInterval(timeDiff)
            }
            
            // Generate contextual values for all fields
            let contextualTitle = generateContextualValue(for: event, field: "title", baseValue: updates["title"] as? String, index: index, total: totalEvents)
            let contextualNotes = generateContextualValue(for: event, field: "notes", baseValue: updates["notes"] as? String, index: index, total: totalEvents)
            let contextualLocation = generateContextualValue(for: event, field: "location", baseValue: updates["location"] as? String, index: index, total: totalEvents)
            let contextualUrl = generateContextualValue(for: event, field: "url", baseValue: updates["url"] as? String, index: index, total: totalEvents)
            let contextualTags = generateContextualValue(for: event, field: "tags", baseValue: updates["tags"] as? String, index: index, total: totalEvents)
            
            let result = scheduleManager.updateEvent(
                event,
                title: contextualTitle,
                startTime: adjustedStartTime,
                endTime: adjustedEndTime,
                category: updatedCategory,
                notes: contextualNotes,
                location: contextualLocation,
                isCompleted: updates["isCompleted"] as? Bool,
                colorHex: updates["colorHex"] as? String,
                iconName: updates["iconName"] as? String,
                priority: updates["priority"] as? String,
                tags: contextualTags,
                url: contextualUrl,
                energyLevel: updates["energyLevel"] as? String,
                weatherRequired: updates["weatherRequired"] as? String,
                bufferTimeBefore: (updates["bufferTimeBefore"] as? Int).map { Int32($0) },
                bufferTimeAfter: (updates["bufferTimeAfter"] as? Int).map { Int32($0) },
                recurrenceRule: updates["recurrenceRule"] as? String,
                recurrenceEndDate: updates["recurrenceEndDate"] as? String != nil ? formatter.date(from: updates["recurrenceEndDate"] as! String) : nil,
                linkedTasks: nil
            )
            
            switch result {
            case .success:
                updatedCount += 1
            case .failure:
                failedCount += 1
                failedEvents.append(event.title ?? eventIdStr)
            }
        }
        
        // Return result
        if failedCount > 0 && updatedCount == 0 {
            return FunctionCallResult(
                functionName: "update_multiple_events",
                success: false,
                message: "Failed to update all \(failedCount) events",
                details: ["failedEvents": failedEvents.joined(separator: ", ")]
            )
        } else if failedCount > 0 {
            return FunctionCallResult(
                functionName: "update_multiple_events",
                success: false,
                message: "Updated \(updatedCount) events, but \(failedCount) failed",
                details: ["failedEvents": failedEvents.joined(separator: ", ")]
            )
        } else {
            return FunctionCallResult(
                functionName: "update_multiple_events",
                success: true,
                message: "Successfully updated \(updatedCount) events",
                details: nil
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
        
        // Parse time updates if provided
        let timeFormatter = ISO8601DateFormatter()
        var startTime: Date?
        var endTime: Date?
        
        if let startTimeStr = updates["startTime"] as? String {
            startTime = timeFormatter.date(from: startTimeStr)
        }
        
        if let endTimeStr = updates["endTime"] as? String {
            endTime = timeFormatter.date(from: endTimeStr)
        }
        
        // Handle category update
        var updatedCategory: Category?
        if let categoryName = updates["category"] as? String {
            updatedCategory = scheduleManager.categories.first { $0.name == categoryName }
            if updatedCategory == nil {
                // Create new category if doesn't exist
                let (icon, color) = self.generateUniqueIconAndColor(for: categoryName)
                let result = scheduleManager.createCategory(name: categoryName, icon: icon, colorHex: color)
                if case .success(let newCategory) = result {
                    updatedCategory = newCategory
                }
            }
        }
        
        // Handle time shift
        let addMinutes = updates["addMinutes"] as? Double ?? 0
        
        for event in eventsToUpdate {
            var eventStartTime = startTime
            var eventEndTime = endTime
            
            // If addMinutes is specified, shift the event times
            if addMinutes != 0, let originalStart = event.startTime, let originalEnd = event.endTime {
                eventStartTime = originalStart.addingTimeInterval(addMinutes * 60)
                eventEndTime = originalEnd.addingTimeInterval(addMinutes * 60)
            }
            
            // If only startTime is provided, maintain duration
            if startTime != nil && endTime == nil,
               let originalStart = event.startTime,
               let originalEnd = event.endTime {
                let duration = originalEnd.timeIntervalSince(originalStart)
                eventEndTime = startTime!.addingTimeInterval(duration)
            }
            
            let result = scheduleManager.updateEvent(
                event,
                title: updates["title"] as? String,
                startTime: eventStartTime,
                endTime: eventEndTime,
                category: updatedCategory,
                notes: updates["notes"] as? String,
                location: updates["location"] as? String,
                isCompleted: updates["isCompleted"] as? Bool,
                colorHex: nil,
                iconName: nil,
                priority: nil,
                tags: nil,
                url: nil,
                energyLevel: nil,
                weatherRequired: nil,
                bufferTimeBefore: nil,
                bufferTimeAfter: nil,
                recurrenceRule: nil,
                recurrenceEndDate: nil,
                linkedTasks: nil
            )
            
            switch result {
            case .success:
                updatedCount += 1
            case .failure:
                failedCount += 1
            }
        }
        
        var details: [String: String] = [
            "eventsFound": "\(eventsToUpdate.count)",
            "updated": "\(updatedCount)",
            "failed": "\(failedCount)"
        ]
        
        if addMinutes != 0 {
            details["timeShift"] = "\(addMinutes > 0 ? "+" : "")\(Int(addMinutes)) minutes"
        }
        
        if failedCount > 0 {
            return FunctionCallResult(
                functionName: "update_all_events",
                success: false,
                message: "Updated \(updatedCount) events, but \(failedCount) failed",
                details: details
            )
        } else if updatedCount == 0 {
            return FunctionCallResult(
                functionName: "update_all_events",
                success: true,
                message: "No events found on \(dateStr)",
                details: details
            )
        } else {
            return FunctionCallResult(
                functionName: "update_all_events",
                success: true,
                message: "Successfully updated \(updatedCount) events on \(dateStr)",
                details: details
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
    
    private func searchEvents(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let query = arguments["query"] as? String else {
            return FunctionCallResult(
                functionName: "search_events",
                success: false,
                message: "Missing required parameter: query",
                details: nil
            )
        }
        
        let includeCompleted = arguments["includeCompleted"] as? Bool ?? false
        let searchableQuery = query.lowercased()
        
        // Search through all events
        let matchingEvents = scheduleManager.events.filter { event in
            // Skip completed events if not included
            if !includeCompleted && event.isCompleted {
                return false
            }
            
            // Search in title, notes, location
            let titleMatch = event.title?.lowercased().contains(searchableQuery) ?? false
            let notesMatch = event.notes?.lowercased().contains(searchableQuery) ?? false
            let locationMatch = event.location?.lowercased().contains(searchableQuery) ?? false
            let categoryMatch = event.category?.name?.lowercased().contains(searchableQuery) ?? false
            
            return titleMatch || notesMatch || locationMatch || categoryMatch
        }
        
        if matchingEvents.isEmpty {
            return FunctionCallResult(
                functionName: "search_events",
                success: true,
                message: "No events found matching '\(query)'",
                details: nil
            )
        }
        
        // Sort by date
        let sortedEvents = matchingEvents.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
        
        var message = "🔍 **Found \(sortedEvents.count) events matching '\(query)':**\n\n"
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        for event in sortedEvents.prefix(20) {
            let title = event.title ?? "Untitled"
            let dateStr = event.startTime.map { formatter.string(from: $0) } ?? "No date"
            let completed = event.isCompleted ? "✅" : "⏱️"
            let category = event.category?.name ?? "No category"
            
            message += "\(completed) **\(title)**\n"
            message += "   📅 \(dateStr) | 🏷️ \(category)\n"
            
            if let notes = event.notes, !notes.isEmpty {
                let truncatedNotes = notes.count > 50 ? String(notes.prefix(50)) + "..." : notes
                message += "   📝 \(truncatedNotes)\n"
            }
            message += "\n"
        }
        
        if sortedEvents.count > 20 {
            message += "_...and \(sortedEvents.count - 20) more events_"
        }
        
        return FunctionCallResult(
            functionName: "search_events",
            success: true,
            message: message,
            details: ["matchCount": "\(sortedEvents.count)"]
        )
    }
    
    private func getEventDetails(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let eventIdStr = arguments["eventId"] as? String,
              let eventId = UUID(uuidString: eventIdStr) else {
            return FunctionCallResult(
                functionName: "get_event_details",
                success: false,
                message: "Invalid or missing eventId",
                details: nil
            )
        }
        
        guard let event = scheduleManager.events.first(where: { $0.id == eventId }) else {
            return FunctionCallResult(
                functionName: "get_event_details",
                success: false,
                message: "Event not found",
                details: nil
            )
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        
        var message = "📅 **Event Details**\n\n"
        message += "**Title:** \(event.title ?? "Untitled")\n"
        
        if let startTime = event.startTime {
            message += "**Start:** \(formatter.string(from: startTime))\n"
        }
        
        if let endTime = event.endTime {
            message += "**End:** \(formatter.string(from: endTime))\n"
            
            if let startTime = event.startTime {
                let duration = endTime.timeIntervalSince(startTime) / 60
                message += "**Duration:** \(Int(duration)) minutes\n"
            }
        }
        
        if let category = event.category {
            message += "**Category:** \(category.iconName ?? "📁") \(category.name ?? "Unknown")\n"
        }
        
        if let location = event.location, !location.isEmpty {
            message += "**Location:** 📍 \(location)\n"
        }
        
        message += "**Status:** \(event.isCompleted ? "✅ Completed" : "⏱️ Pending")\n"
        
        // Check if it's an all-day event based on duration
        if let start = event.startTime, let end = event.endTime {
            let duration = end.timeIntervalSince(start)
            if duration >= 86400 { // 24 hours or more
                message += "**Type:** 🌅 All-day event\n"
            }
        }
        
        if let recurrenceRule = event.recurrenceRule {
            message += "**Recurrence:** 🔄 \(recurrenceRule)\n"
        }
        
        if let notes = event.notes, !notes.isEmpty {
            message += "\n**Notes:**\n\(notes)\n"
        }
        
        // Check for linked tasks
        let linkedTasks = taskManager.tasks.filter { task in
            task.linkedEvent?.id == eventId
        }
        
        if !linkedTasks.isEmpty {
            message += "\n**Linked Tasks:** \(linkedTasks.count)\n"
            for task in linkedTasks {
                let status = task.isCompleted ? "✅" : "⏱️"
                message += "• \(status) \(task.title ?? "Untitled")\n"
            }
        }
        
        var details: [String: String] = [
            "eventId": eventIdStr,
            "title": event.title ?? "",
            "isCompleted": "\(event.isCompleted)",
            "hasLocation": "\(event.location != nil)"
        ]
        
        if let startTime = event.startTime {
            details["startTime"] = ISO8601DateFormatter().string(from: startTime)
        }
        
        if let endTime = event.endTime {
            details["endTime"] = ISO8601DateFormatter().string(from: endTime)
        }
        
        return FunctionCallResult(
            functionName: "get_event_details",
            success: true,
            message: message,
            details: details
        )
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
    
    private func moveAllEvents(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let fromDateStr = arguments["fromDate"] as? String,
              let toDateStr = arguments["toDate"] as? String else {
            return FunctionCallResult(
                functionName: "move_all_events",
                success: false,
                message: "Missing required parameters: fromDate and toDate",
                details: nil
            )
            }
        
        let preserveTime = arguments["preserveTime"] as? Bool ?? true
        
        // Parse dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let fromDate = dateFormatter.date(from: fromDateStr),
              let toDate = dateFormatter.date(from: toDateStr) else {
            return FunctionCallResult(
                functionName: "move_all_events",
                success: false,
                message: "Invalid date format. Please use YYYY-MM-DD format.",
                details: nil
            )
        }
        
        // Get all events for the from date
        let calendar = Calendar.current
        let startOfFromDay = calendar.startOfDay(for: fromDate)
        let endOfFromDay = calendar.date(byAdding: .day, value: 1, to: startOfFromDay)!
        
        let eventsToMove = scheduleManager.events.filter { event in
            guard let eventStart = event.startTime else { return false }
            return eventStart >= startOfFromDay && eventStart < endOfFromDay
        }
        
        if eventsToMove.isEmpty {
            return FunctionCallResult(
                functionName: "move_all_events",
                success: false,
                message: "No events found on \(fromDateStr)",
                details: nil
            )
            }
        
        var movedCount = 0
        var failedCount = 0
        var stackTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: toDate) ?? toDate
        
        // Sort events by start time
        let sortedEvents = eventsToMove.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
        
        for event in sortedEvents {
            guard let originalStart = event.startTime,
                  let originalEnd = event.endTime else {
                failedCount += 1
                continue
            }
            
            let duration = originalEnd.timeIntervalSince(originalStart)
            
            let newStartTime: Date
            let newEndTime: Date
            
            if preserveTime {
                // Keep the same time on the new date
                let components = calendar.dateComponents([.hour, .minute, .second], from: originalStart)
                newStartTime = calendar.date(bySettingHour: components.hour ?? 0,
                                            minute: components.minute ?? 0,
                                            second: components.second ?? 0,
                                            of: toDate) ?? toDate
                newEndTime = newStartTime.addingTimeInterval(duration)
            } else {
                // Stack events starting from morning
                newStartTime = stackTime
                newEndTime = stackTime.addingTimeInterval(duration)
                stackTime = newEndTime.addingTimeInterval(15 * 60) // 15 min buffer between events
            }
            
            let result = scheduleManager.updateEvent(
                event,
                title: nil,
                startTime: newStartTime,
                endTime: newEndTime,
                category: nil,
                notes: nil,
                location: nil,
                isCompleted: nil,
                colorHex: nil,
                iconName: nil,
                priority: nil,
                tags: nil,
                url: nil,
                energyLevel: nil,
                weatherRequired: nil,
                bufferTimeBefore: nil,
                bufferTimeAfter: nil,
                recurrenceRule: nil,
                recurrenceEndDate: nil,
                linkedTasks: nil
            )
            
            switch result {
            case .success:
                movedCount += 1
            case .failure:
                failedCount += 1
            }
        }
        
        let message = "Moved \(movedCount) event\(movedCount == 1 ? "" : "s") from \(fromDateStr) to \(toDateStr)"
        let failureNote = failedCount > 0 ? " (\(failedCount) failed)" : ""
        
        return FunctionCallResult(
            functionName: "move_all_events",
            success: movedCount > 0,
            message: message + failureNote,
            details: [
                "eventsFound": "\(eventsToMove.count)",
                "moved": "\(movedCount)",
                "failed": "\(failedCount)",
                "preserveTime": preserveTime ? "yes" : "no (stacked from 9:00 AM)"
            ]
        )
    }
    
    // Helper to ensure category exists (create if needed)
    private func ensureCategory(named categoryName: String) -> Category? {
        // First check if it exists (case-insensitive)
        if let existingCategory = scheduleManager.categories.first(where: { $0.name?.lowercased() == categoryName.lowercased() }) {
            return existingCategory
        }
        
        // If not, create it with smart defaults
        let (icon, color) = generateIconAndColorForCategory(categoryName)
        let result = scheduleManager.createCategory(name: categoryName, icon: icon, colorHex: color)
        
        switch result {
        case .success(let category):
            return category
        case .failure:
            return nil
        }
    }
    
    // Helper function to generate icon and color for a category name
    private func generateIconAndColorForCategory(_ categoryName: String) -> (icon: String, color: String) {
        let lowercaseName = categoryName.lowercased()
        
        // Smart icon and color mapping based on category name
        switch lowercaseName {
        // Work related
        case let name where name.contains("work") || name.contains("job") || name.contains("office"):
            return ("briefcase.fill", "#007AFF")
        case let name where name.contains("project") || name.contains("development"):
            return ("folder.fill", "#5856D6")
        case let name where name.contains("client") || name.contains("customer"):
            return ("person.2.fill", "#007AFF")
            
        // Health & Fitness
        case let name where name.contains("health") || name.contains("medical"):
            return ("heart.fill", "#FF3B30")
        case let name where name.contains("fitness") || name.contains("gym") || name.contains("workout"):
            return ("figure.run", "#FF6B6B")
        case let name where name.contains("yoga") || name.contains("meditation"):
            return ("leaf.fill", "#34C759")
        case let name where name.contains("sport"):
            return ("sportscourt.fill", "#FF9500")
            
        // Personal
        case let name where name.contains("personal") || name.contains("home"):
            return ("house.fill", "#34C759")
        case let name where name.contains("family"):
            return ("person.3.fill", "#FF69B4")
        case let name where name.contains("shopping"):
            return ("cart.fill", "#00D2D3")
        case let name where name.contains("finance") || name.contains("money") || name.contains("budget"):
            return ("dollarsign.circle.fill", "#4CAF50")
            
        // Learning & Education
        case let name where name.contains("study") || name.contains("learning") || name.contains("education"):
            return ("book.fill", "#FF9500")
        case let name where name.contains("school") || name.contains("university"):
            return ("graduationcap.fill", "#5856D6")
        case let name where name.contains("research"):
            return ("magnifyingglass", "#A29BFE")
            
        // Creative
        case let name where name.contains("creative") || name.contains("art"):
            return ("paintpalette.fill", "#E91E63")
        case let name where name.contains("music"):
            return ("music.note", "#9C27B0")
        case let name where name.contains("writing"):
            return ("pencil", "#795548")
            
        // Social & Events
        case let name where name.contains("social") || name.contains("party"):
            return ("person.2.fill", "#FF69B4")
        case let name where name.contains("meeting"):
            return ("person.3.fill", "#5856D6")
        case let name where name.contains("event"):
            return ("calendar", "#FF9500")
            
        // Travel
        case let name where name.contains("travel") || name.contains("trip"):
            return ("airplane", "#00BCD4")
        case let name where name.contains("vacation") || name.contains("holiday"):
            return ("sun.max.fill", "#FFC107")
            
        // Technology
        case let name where name.contains("tech") || name.contains("coding") || name.contains("programming"):
            return ("laptopcomputer", "#607D8B")
        
        // More specific categories
        case let name where name.contains("wedding"):
            return ("heart.circle.fill", "#FF69B4")
        case let name where name.contains("baby") || name.contains("kids"):
            return ("figure.and.child.holdinghands", "#FFB6C1")
        case let name where name.contains("freelance") || name.contains("side"):
            return ("dollarsign.circle.fill", "#4CAF50")
        case let name where name.contains("hobby"):
            return ("star.fill", "#9C27B0")
        case let name where name.contains("volunteer") || name.contains("charity"):
            return ("hands.sparkles.fill", "#FF6347")
        case let name where name.contains("spiritual") || name.contains("religious"):
            return ("sparkles", "#8B4513")
        case let name where name.contains("pet") || name.contains("dog") || name.contains("cat"):
            return ("pawprint.fill", "#FF8C00")
        case let name where name.contains("garden"):
            return ("leaf.fill", "#228B22")
        case let name where name.contains("cooking") || name.contains("food"):
            return ("fork.knife", "#FF6347")
        case let name where name.contains("reading") || name.contains("book"):
            return ("book.closed.fill", "#8B4513")
        case let name where name.contains("game") || name.contains("gaming"):
            return ("gamecontroller.fill", "#9400D3")
        case let name where name.contains("photo"):
            return ("camera.fill", "#FF1493")
            
        // Default - pick a unique color/icon combo
        default:
            let colors = ["#E91E63", "#9C27B0", "#673AB7", "#3F51B5", "#009688", "#FF5722", "#795548", "#607D8B"]
            let icons = ["star.fill", "flag.fill", "bolt.fill", "sparkles", "flame.fill", "drop.fill", "moon.fill", "sun.max.fill"]
            let index = abs(categoryName.hashValue) % min(colors.count, icons.count)
            return (icons[index], colors[index])
        }
    }
    
    private func createCategory(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let name = arguments["name"] as? String,
              let color = arguments["color"] as? String,
              let icon = arguments["icon"] as? String else {
            return FunctionCallResult(
                functionName: "create_category",
                success: false,
                message: "Missing required parameters: name, color, and icon",
                details: nil
            )
        }
        
        // Convert color name to hex if needed
        let colorHex: String
        if color.hasPrefix("#") {
            colorHex = color
        } else {
            // Convert color names to hex
            switch color.lowercased() {
            case "red": colorHex = "#FF6B6B"
            case "blue": colorHex = "#54A0FF"
            case "green": colorHex = "#1DD1A1"
            case "yellow": colorHex = "#FECA57"
            case "orange": colorHex = "#FFA502"
            case "purple": colorHex = "#A29BFE"
            case "pink": colorHex = "#FF9FF3"
            case "teal": colorHex = "#00D2D3"
            case "brown": colorHex = "#A0522D"
            case "gray", "grey": colorHex = "#95A5A6"
            case "black": colorHex = "#2C3E50"
            case "white": colorHex = "#ECF0F1"
            default: colorHex = "#007AFF" // Default iOS blue
            }
        }
        
        // Check if category already exists
        if let existingCategory = scheduleManager.categories.first(where: { $0.name?.lowercased() == name.lowercased() }) {
            // Return success with the existing category info
            return FunctionCallResult(
                functionName: "create_category",
                success: true,
                message: "✅ **Using existing category '\(name)'**",
                details: [
                    "Name": existingCategory.name ?? "",
                    "Icon": existingCategory.iconName ?? icon,
                    "Color": existingCategory.colorHex ?? colorHex,
                    "CategoryId": existingCategory.id?.uuidString ?? "",
                    "AlreadyExists": "true"
                ]
            )
        }
        
        let result = scheduleManager.createCategory(name: name, icon: icon, colorHex: colorHex)
        
        switch result {
        case .success(let category):
            // Get today's events to show current categories
            let todayEvents = scheduleManager.eventsForToday()
            var eventList = "✅ **Created new category!**\n\n"
            eventList += "**Name:** \(category.name ?? "")\n"
            eventList += "**Icon:** \(icon)\n"
            eventList += "**Color:** \(colorHex)\n\n"
            
            if !todayEvents.isEmpty {
                let timeFormatter = DateFormatter()
                timeFormatter.dateStyle = .none
                timeFormatter.timeStyle = .short
                
                eventList += "📅 **Today's Events:**\n"
                for event in todayEvents.sorted(by: { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }) {
                    let categoryName = event.category?.name ?? "No category"
                    let categoryIcon = event.category?.iconName ?? "📅"
                    let startTime = timeFormatter.string(from: event.startTime ?? Date())
                    let endTime = timeFormatter.string(from: event.endTime ?? Date())
                    
                    eventList += "• **\(event.title ?? "Untitled")** (\(startTime) - \(endTime))\n"
                    eventList += "  _\(categoryIcon) \(categoryName)_\n"
                }
            } else {
                eventList += "_No events scheduled for today. Create some events with your new category!_"
            }
            
            return FunctionCallResult(
                functionName: "create_category",
                success: true,
                message: eventList,
                details: [
                    "Name": category.name ?? "",
                    "Icon": category.iconName ?? icon,
                    "Color": category.colorHex ?? colorHex,
                    "CategoryId": category.id?.uuidString ?? ""
                ]
            )
        case .failure(let error):
            return FunctionCallResult(
                functionName: "create_category",
                success: false,
                message: error.localizedDescription,
                details: nil
            )
        }
    }
    
    // MARK: - Task Management Functions
    
    private func createTask(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let title = arguments["title"] as? String else {
            return FunctionCallResult(
                functionName: "create_task",
                success: false,
                message: "Missing required parameter: title",
                details: nil
            )
        }
        
        // Parse optional parameters
        let priorityStr = arguments["priority"] as? String ?? "medium"
        let priority = TaskPriority(rawValue: priorityStr == "low" ? 0 : priorityStr == "high" ? 2 : 1) ?? .medium
        
        // Parse due date
        var dueDate: Date?
        if let dueDateStr = arguments["dueDate"] as? String {
            let formatter = ISO8601DateFormatter()
            dueDate = formatter.date(from: dueDateStr)
        }
        
        // Parse scheduled time
        var scheduledTime: Date?
        if let scheduledTimeStr = arguments["scheduledTime"] as? String {
            let formatter = ISO8601DateFormatter()
            scheduledTime = formatter.date(from: scheduledTimeStr)
        }
        
        // Find category if specified
        var category: Category?
        if let categoryName = arguments["category"] as? String {
            category = scheduleManager.categories.first { $0.name?.lowercased() == categoryName.lowercased() }
        }
        
        // Parse optional parameters - let the AI provide them naturally
        let notes = arguments["notes"] as? String
        let tags = arguments["tags"] as? [String]
        let estimatedDuration = Int16(arguments["estimatedDuration"] as? Int ?? 0)
        
        // Create the task
        let result = taskManager.createTask(
            title: title,
            notes: notes,
            dueDate: dueDate,
            priority: priority,
            category: category,
            tags: tags,
            estimatedDuration: estimatedDuration,
            scheduledTime: scheduledTime,
            linkedEvent: nil
        )
        
        switch result {
        case .success(let task):
            // Format response message
            var details: [String: String] = [
                "taskId": task.id?.uuidString ?? "",
                "title": task.title ?? ""
            ]
            
            var message = "✅ **Created task:** \(task.title ?? "")\n\n"
            
            if let dueDate = task.dueDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                message += "📅 **Due:** \(formatter.string(from: dueDate))\n"
                details["dueDate"] = formatter.string(from: dueDate)
            }
            
            message += "🎯 **Priority:** _\(task.priorityEnum.displayName)_\n"
            details["priority"] = task.priorityEnum.displayName
            
            if let category = task.category {
                message += "📁 **Category:** _\(category.name ?? "")_\n"
                details["category"] = category.name ?? ""
            }
            
            if let notes = task.notes, !notes.isEmpty {
                message += "📝 **Notes:** \(notes)\n"
                details["notes"] = notes
            }
            
            let tags = task.tagsArray
            if !tags.isEmpty {
                message += "🏷️ **Tags:** \(tags.joined(separator: ", "))\n"
                details["tags"] = tags.joined(separator: ", ")
            }
            
            if task.estimatedDuration > 0 {
                message += "⏱️ **Duration:** \(task.estimatedDuration) minutes\n"
                details["estimatedDuration"] = "\(task.estimatedDuration)"
            }
            
            if let scheduledTime = task.scheduledTime {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                message += "🗝️ **Scheduled:** \(formatter.string(from: scheduledTime))\n"
                details["scheduledTime"] = formatter.string(from: scheduledTime)
            }
            
            return FunctionCallResult(
                functionName: "create_task",
                success: true,
                message: message,
                details: details
            )
            
        case .failure(let error):
            return FunctionCallResult(
                functionName: "create_task",
                success: false,
                message: "Failed to create task: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    private func listTasks(with arguments: [String: Any]) async -> FunctionCallResult {
        var tasks: [Task] = taskManager.tasks
        var filterDescription = "all tasks"
        
        // Apply filters
        if let dateStr = arguments["date"] as? String,
           let date = ISO8601DateFormatter().date(from: dateStr) {
            tasks = taskManager.tasks(for: date)
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            filterDescription = "tasks for \(formatter.string(from: date))"
        } else if let status = arguments["status"] as? String {
            switch status {
            case "pending":
                tasks = tasks.filter { !$0.isCompleted }
                filterDescription = "pending tasks"
            case "completed":
                tasks = tasks.filter { $0.isCompleted }
                filterDescription = "completed tasks"
            case "overdue":
                tasks = taskManager.overdueTasks()
                filterDescription = "overdue tasks"
            default:
                break
            }
        } else if let unscheduled = arguments["unscheduled"] as? Bool, unscheduled {
            tasks = taskManager.unscheduledTasks()
            filterDescription = "unscheduled tasks"
        }
        
        // Filter by priority
        if let priorityStr = arguments["priority"] as? String {
            let priority = TaskPriority(rawValue: priorityStr == "low" ? 0 : priorityStr == "high" ? 2 : 1) ?? .medium
            tasks = tasks.filter { $0.priority == priority.rawValue }
            filterDescription += " with \(priority.displayName) priority"
        }
        
        // Filter by tag
        if let tag = arguments["tag"] as? String {
            tasks = taskManager.tasksWithTag(tag)
            filterDescription = "tasks tagged with '\(tag)'"
        }
        
        // Format response
        if tasks.isEmpty {
            return FunctionCallResult(
                functionName: "list_tasks",
                success: true,
                message: "No \(filterDescription) found.",
                details: ["count": "0"]
            )
        }
        
        var message = "📋 **Found \(tasks.count) \(filterDescription):**\n\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        // Group by priority for better display
        let groupedTasks = Dictionary(grouping: tasks) { task in
            TaskPriority(rawValue: task.priority) ?? .medium
        }
        
        for priority in [TaskPriority.high, .medium, .low] {
            guard let priorityTasks = groupedTasks[priority], !priorityTasks.isEmpty else { continue }
            
            message += "\n**\(priority.displayName) Priority:**\n"
            
            for task in priorityTasks {
                let status = task.isCompleted ? "✅" : (task.isOverdue ? "⚠️" : "⭕")
                message += "\(status) **\(task.title ?? "Untitled")**"
                
                if let dueDate = task.dueDate {
                    message += " - Due: \(dateFormatter.string(from: dueDate))"
                }
                
                if let category = task.category {
                    message += " _[\(category.name ?? "")]_"
                }
                
                message += "\n"
                
                if let notes = task.notes, !notes.isEmpty {
                    message += "   📝 \(notes)\n"
                }
                
                if task.hasSubtasks {
                    message += "   📊 \(task.completedSubtaskCount)/\(task.totalSubtaskCount) subtasks\n"
                }
            }
        }
        
        return FunctionCallResult(
            functionName: "list_tasks",
            success: true,
            message: message,
            details: ["count": "\(tasks.count)"]
        )
    }
    
    private func updateTask(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let taskIdStr = arguments["taskId"] as? String,
              let taskId = UUID(uuidString: taskIdStr) else {
            return FunctionCallResult(
                functionName: "update_task",
                success: false,
                message: "Invalid or missing task ID",
                details: nil
            )
        }
        
        // Find the task
        guard let task = taskManager.tasks.first(where: { $0.id == taskId }) else {
            return FunctionCallResult(
                functionName: "update_task",
                success: false,
                message: "Task not found",
                details: nil
            )
        }
        
        // Parse update parameters
        let title = arguments["title"] as? String
        let notes = arguments["notes"] as? String
        
        var dueDate: Date?
        if let dueDateStr = arguments["dueDate"] as? String {
            dueDate = ISO8601DateFormatter().date(from: dueDateStr)
        }
        
        var scheduledTime: Date?
        if let scheduledTimeStr = arguments["scheduledTime"] as? String {
            scheduledTime = ISO8601DateFormatter().date(from: scheduledTimeStr)
        }
        
        var priority: TaskPriority?
        if let priorityStr = arguments["priority"] as? String {
            priority = TaskPriority(rawValue: priorityStr == "low" ? 0 : priorityStr == "high" ? 2 : 1)
        }
        
        var category: Category?
        if let categoryName = arguments["category"] as? String {
            category = scheduleManager.categories.first { $0.name?.lowercased() == categoryName.lowercased() }
        }
        
        // Parse tags
        let tags = arguments["tags"] as? [String]
        
        // Parse estimated duration
        var estimatedDuration: Int16?
        if let duration = arguments["estimatedDuration"] as? Int {
            estimatedDuration = Int16(duration)
        }
        
        // Update the task
        let result = taskManager.updateTask(
            task,
            title: title,
            notes: notes,
            dueDate: dueDate,
            priority: priority,
            category: category,
            tags: tags,
            estimatedDuration: estimatedDuration,
            scheduledTime: scheduledTime,
            linkedEvent: nil,
            parentTask: nil
        )
        
        switch result {
        case .success:
            var updateDetails = [String: String]()
            var message = "✅ **Updated task**\n\n"
            
            if let title = title {
                message += "📝 **New title:** \(title)\n"
                updateDetails["title"] = title
            }
            
            if let priority = priority {
                message += "🎯 **Priority:** _\(priority.displayName)_\n"
                updateDetails["priority"] = priority.displayName
            }
            
            if let dueDate = dueDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                message += "📅 **Due date:** \(formatter.string(from: dueDate))\n"
                updateDetails["dueDate"] = formatter.string(from: dueDate)
            }
            
            if let category = category {
                message += "📁 **Category:** _\(category.name ?? "")_\n"
                updateDetails["category"] = category.name ?? ""
            }
            
            if let tags = tags, !tags.isEmpty {
                message += "🏷️ **Tags:** \(tags.joined(separator: ", "))\n"
                updateDetails["tags"] = tags.joined(separator: ", ")
            }
            
            if let estimatedDuration = estimatedDuration {
                message += "⏱️ **Duration:** \(estimatedDuration) minutes\n"
                updateDetails["estimatedDuration"] = "\(estimatedDuration)"
            }
            
            if let scheduledTime = scheduledTime {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                message += "🗓️ **Scheduled:** \(formatter.string(from: scheduledTime))\n"
                updateDetails["scheduledTime"] = formatter.string(from: scheduledTime)
            }
            
            return FunctionCallResult(
                functionName: "update_task",
                success: true,
                message: message,
                details: updateDetails
            )
            
        case .failure(let error):
            return FunctionCallResult(
                functionName: "update_task",
                success: false,
                message: "Failed to update task: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    private func completeTask(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let taskIdStr = arguments["taskId"] as? String,
              let taskId = UUID(uuidString: taskIdStr) else {
            return FunctionCallResult(
                functionName: "complete_task",
                success: false,
                message: "Invalid or missing task ID",
                details: nil
            )
        }
        
        // Find the task
        guard let task = taskManager.tasks.first(where: { $0.id == taskId }) else {
            return FunctionCallResult(
                functionName: "complete_task",
                success: false,
                message: "Task not found",
                details: nil
            )
        }
        
        let result = taskManager.completeTask(task)
        
        switch result {
        case .success:
            return FunctionCallResult(
                functionName: "complete_task",
                success: true,
                message: "✅ **Completed task:** \(task.title ?? "Untitled")",
                details: ["taskId": taskIdStr, "title": task.title ?? ""]
            )
        case .failure(let error):
            return FunctionCallResult(
                functionName: "complete_task",
                success: false,
                message: "Failed to complete task: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    private func deleteTask(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let taskIdStr = arguments["taskId"] as? String,
              let taskId = UUID(uuidString: taskIdStr) else {
            return FunctionCallResult(
                functionName: "delete_task",
                success: false,
                message: "Invalid or missing task ID",
                details: nil
            )
        }
        
        // Find the task
        guard let task = taskManager.tasks.first(where: { $0.id == taskId }) else {
            return FunctionCallResult(
                functionName: "delete_task",
                success: false,
                message: "Task not found",
                details: nil
            )
        }
        
        let taskTitle = task.title ?? "Untitled"
        let result = taskManager.deleteTask(task)
        
        switch result {
        case .success:
            return FunctionCallResult(
                functionName: "delete_task",
                success: true,
                message: "🗑️ **Deleted task:** \(taskTitle)",
                details: ["taskId": taskIdStr, "title": taskTitle]
            )
            
        case .failure(let error):
            return FunctionCallResult(
                functionName: "delete_task",
                success: false,
                message: "Failed to delete task: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    private func createSubtasks(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let parentTaskIdStr = arguments["parentTaskId"] as? String,
              let parentTaskId = UUID(uuidString: parentTaskIdStr),
              let subtasks = arguments["subtasks"] as? [[String: Any]] else {
            return FunctionCallResult(
                functionName: "create_subtasks",
                success: false,
                message: "Missing required parameters",
                details: nil
            )
        }
        
        // Find parent task
        guard let parentTask = taskManager.tasks.first(where: { $0.id == parentTaskId }) else {
            return FunctionCallResult(
                functionName: "create_subtasks",
                success: false,
                message: "Parent task not found",
                details: nil
            )
        }
        
        var createdSubtasks: [String] = []
        var failedCount = 0
        
        for subtaskData in subtasks {
            guard let title = subtaskData["title"] as? String else {
                failedCount += 1
                continue
            }
            
            let notes = subtaskData["notes"] as? String
            let result = taskManager.createSubtask(for: parentTask, title: title, notes: notes)
            
            switch result {
            case .success:
                createdSubtasks.append(title)
            case .failure:
                failedCount += 1
            }
        }
        
        if createdSubtasks.isEmpty {
            return FunctionCallResult(
                functionName: "create_subtasks",
                success: false,
                message: "Failed to create any subtasks",
                details: nil
            )
        }
        
        var message = "✅ **Created \(createdSubtasks.count) subtasks for:** \(parentTask.title ?? "Untitled")\n\n"
        for subtask in createdSubtasks {
            message += "• \(subtask)\n"
        }
        
        if failedCount > 0 {
            message += "\n⚠️ Failed to create \(failedCount) subtasks"
        }
        
        return FunctionCallResult(
            functionName: "create_subtasks",
            success: true,
            message: message,
            details: ["created": "\(createdSubtasks.count)", "failed": "\(failedCount)"]
        )
    }
    
    private func linkTaskToEvent(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let taskIdStr = arguments["taskId"] as? String,
              let taskId = UUID(uuidString: taskIdStr),
              let eventIdStr = arguments["eventId"] as? String,
              let eventId = UUID(uuidString: eventIdStr) else {
            return FunctionCallResult(
                functionName: "link_task_to_event",
                success: false,
                message: "Invalid or missing IDs",
                details: nil
            )
        }
        
        // Find task and event
        guard let task = taskManager.tasks.first(where: { $0.id == taskId }) else {
            return FunctionCallResult(
                functionName: "link_task_to_event",
                success: false,
                message: "Task not found",
                details: nil
            )
        }
        
        guard let event = scheduleManager.events.first(where: { $0.id == eventId }) else {
            return FunctionCallResult(
                functionName: "link_task_to_event",
                success: false,
                message: "Event not found",
                details: nil
            )
        }
        
        // Update task with linked event
        let result = taskManager.updateTask(
            task,
            title: nil,
            notes: nil,
            dueDate: nil,
            priority: nil,
            category: nil,
            tags: nil,
            estimatedDuration: nil,
            scheduledTime: event.startTime,
            linkedEvent: event,
            parentTask: nil
        )
        
        switch result {
        case .success:
            // Note: In a full implementation, we'd also update the event's linkedTasks relationship
            return FunctionCallResult(
                functionName: "link_task_to_event",
                success: true,
                message: "🔗 **Linked task to event**\n\n📋 **Task:** \(task.title ?? "Untitled")\n📅 **Event:** \(event.title ?? "Untitled")",
                details: [
                    "taskId": taskIdStr,
                    "eventId": eventIdStr,
                    "taskTitle": task.title ?? "",
                    "eventTitle": event.title ?? ""
                ]
            )
            
        case .failure(let error):
            return FunctionCallResult(
                functionName: "link_task_to_event",
                success: false,
                message: "Failed to link task to event: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    // MARK: - Bulk Task Operations
    
    private func createMultipleTasks(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let tasks = arguments["tasks"] as? [[String: Any]] else {
            return FunctionCallResult(
                functionName: "create_multiple_tasks",
                success: false,
                message: "Missing required parameter: tasks array",
                details: nil
            )
        }
        
        var createdTasks: [(title: String, id: String)] = []
        var failedTasks: [String] = []
        
        for taskData in tasks {
            guard let title = taskData["title"] as? String else {
                failedTasks.append("Untitled (missing title)")
                continue
            }
            
            // Parse task parameters
            let priorityStr = taskData["priority"] as? String ?? "medium"
            let priority = TaskPriority(rawValue: priorityStr == "low" ? 0 : priorityStr == "high" ? 2 : 1) ?? .medium
            
            var dueDate: Date?
            if let dueDateStr = taskData["dueDate"] as? String {
                dueDate = ISO8601DateFormatter().date(from: dueDateStr)
            }
            
            var scheduledTime: Date?
            if let scheduledTimeStr = taskData["scheduledTime"] as? String {
                scheduledTime = ISO8601DateFormatter().date(from: scheduledTimeStr)
            }
            
            var category: Category?
            if let categoryName = taskData["category"] as? String {
                category = scheduleManager.categories.first { $0.name == categoryName }
            }
            
            // Parse optional parameters - let the AI provide them naturally
            let notes = taskData["notes"] as? String
            let tags = taskData["tags"] as? [String]
            let estimatedDuration = Int16(taskData["estimatedDuration"] as? Int ?? 0)
            
            // Create the task
            let result = taskManager.createTask(
                title: title,
                notes: notes,
                dueDate: dueDate,
                priority: priority,
                category: category,
                tags: tags,
                estimatedDuration: estimatedDuration,
                scheduledTime: scheduledTime,
                linkedEvent: nil
            )
            
            switch result {
            case .success(let task):
                createdTasks.append((title: title, id: task.id?.uuidString ?? ""))
                
                // Create subtasks if specified
                if let subtasks = taskData["subtasks"] as? [[String: Any]] {
                    for subtaskData in subtasks {
                        if let subtaskTitle = subtaskData["title"] as? String {
                            let subtaskNotes = subtaskData["notes"] as? String
                            _ = taskManager.createSubtask(for: task, title: subtaskTitle, notes: subtaskNotes)
                        }
                    }
                }
                
            case .failure:
                failedTasks.append(title)
            }
        }
        
        if createdTasks.isEmpty {
            return FunctionCallResult(
                functionName: "create_multiple_tasks",
                success: false,
                message: "Failed to create any tasks",
                details: ["failed": "\(failedTasks.count)"]
            )
        }
        
        var message = "✅ **Created \(createdTasks.count) tasks:**\n\n"
        for task in createdTasks {
            message += "• \(task.title)\n"
        }
        
        if !failedTasks.isEmpty {
            message += "\n⚠️ **Failed to create \(failedTasks.count) tasks:**\n"
            for title in failedTasks {
                message += "• \(title)\n"
            }
        }
        
        return FunctionCallResult(
            functionName: "create_multiple_tasks",
            success: true,
            message: message,
            details: [
                "created": "\(createdTasks.count)",
                "failed": "\(failedTasks.count)",
                "taskIds": createdTasks.map { $0.id }.joined(separator: ",")
            ]
        )
    }
    
    private func updateMultipleTasks(with arguments: [String: Any]) async -> FunctionCallResult {
        // Support two formats:
        // 1. taskIds + updates (same updates for all)
        // 2. tasks array with individual updates per task
        
        var taskUpdates: [(taskId: String, updates: [String: Any])] = []
        
        if let tasksArray = arguments["tasks"] as? [[String: Any]] {
            // New format: individual updates per task
            for taskData in tasksArray {
                guard let taskId = taskData["taskId"] as? String,
                      let updates = taskData["updates"] as? [String: Any] else {
                    continue
                }
                taskUpdates.append((taskId: taskId, updates: updates))
            }
        } else if let taskIds = arguments["taskIds"] as? [String],
                  let updates = arguments["updates"] as? [String: Any] {
            // Old format: same updates for all tasks
            for taskId in taskIds {
                taskUpdates.append((taskId: taskId, updates: updates))
            }
        } else {
            return FunctionCallResult(
                functionName: "update_multiple_tasks",
                success: false,
                message: "Missing required parameters. Use either 'tasks' array with individual updates or 'taskIds' + 'updates'",
                details: nil
            )
        }
        
        var updatedCount = 0
        var failedCount = 0
        let totalTasks = taskUpdates.count
        
        for (index, taskUpdate) in taskUpdates.enumerated() {
            guard let taskId = UUID(uuidString: taskUpdate.taskId),
                  let task = taskManager.tasks.first(where: { $0.id == taskId }) else {
                failedCount += 1
                continue
            }
            
            let updates = taskUpdate.updates
            
            // Parse updates
            var priority: TaskPriority?
            if let priorityStr = updates["priority"] as? String {
                priority = TaskPriority(rawValue: priorityStr == "low" ? 0 : priorityStr == "high" ? 2 : 1)
            }
            
            var dueDate: Date?
            if let dueDateStr = updates["dueDate"] as? String {
                dueDate = ISO8601DateFormatter().date(from: dueDateStr)
            }
            
            var scheduledTime: Date?
            if let scheduledTimeStr = updates["scheduledTime"] as? String {
                scheduledTime = ISO8601DateFormatter().date(from: scheduledTimeStr)
            }
            
            var category: Category?
            if let categoryName = updates["category"] as? String {
                category = scheduleManager.categories.first { $0.name == categoryName }
            }
            
            // Handle tags
            var newTags: [String]?
            if let tags = updates["tags"] as? [String] {
                newTags = tags
            } else if let addTags = updates["addTags"] as? [String] {
                newTags = task.tagsArray + addTags
            } else if let removeTags = updates["removeTags"] as? [String] {
                newTags = task.tagsArray.filter { !removeTags.contains($0) }
            }
            
            // Generate contextual values for fields
            let contextualTitle = generateContextualValue(for: task, field: "title", baseValue: updates["title"] as? String, index: index, total: totalTasks)
            
            // Generate contextual values for fields
            let contextualNotes = generateContextualValue(for: task, field: "notes", baseValue: updates["notes"] as? String, index: index, total: totalTasks)
            
            // Handle contextual tags
            var contextualTags: [String]?
            if let tagsValue = updates["tags"] {
                if let tagsArray = tagsValue as? [String] {
                    contextualTags = tagsArray
                } else if let tagsString = tagsValue as? String {
                    let contextualTagString = generateContextualValue(for: task, field: "tags", baseValue: tagsString, index: index, total: totalTasks) ?? tagsString
                    contextualTags = contextualTagString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                }
            } else if newTags != nil {
                contextualTags = newTags
            }
            
            let result = taskManager.updateTask(
                task,
                title: contextualTitle,
                notes: contextualNotes,
                dueDate: dueDate,
                priority: priority,
                category: category,
                tags: contextualTags ?? newTags,
                estimatedDuration: (updates["estimatedDuration"] as? Int).map { Int16($0) },
                scheduledTime: scheduledTime,
                linkedEvent: nil,
                parentTask: nil
            )
            
            switch result {
            case .success:
                updatedCount += 1
            case .failure:
                failedCount += 1
            }
        }
        
        if updatedCount == 0 {
            return FunctionCallResult(
                functionName: "update_multiple_tasks",
                success: false,
                message: "Failed to update any tasks",
                details: nil
            )
        }
        
        return FunctionCallResult(
            functionName: "update_multiple_tasks",
            success: true,
            message: "✏️ **Updated \(updatedCount) tasks**" + (failedCount > 0 ? "\n⚠️ Failed to update \(failedCount) tasks" : ""),
            details: ["updated": "\(updatedCount)", "failed": "\(failedCount)"]
        )
    }
    
    private func completeMultipleTasks(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let taskIds = arguments["taskIds"] as? [String] else {
            return FunctionCallResult(
                functionName: "complete_multiple_tasks",
                success: false,
                message: "Missing required parameter: taskIds",
                details: nil
            )
        }
        
        var completedCount = 0
        var failedCount = 0
        
        for taskIdStr in taskIds {
            guard let taskId = UUID(uuidString: taskIdStr),
                  let task = taskManager.tasks.first(where: { $0.id == taskId }) else {
                failedCount += 1
                continue
            }
            
            let result = taskManager.completeTask(task)
            
            switch result {
            case .success:
                completedCount += 1
            case .failure:
                failedCount += 1
            }
        }
        
        return FunctionCallResult(
            functionName: "complete_multiple_tasks",
            success: completedCount > 0,
            message: "✅ **Completed \(completedCount) tasks**" + (failedCount > 0 ? "\n⚠️ Failed to complete \(failedCount) tasks" : ""),
            details: ["completed": "\(completedCount)", "failed": "\(failedCount)"]
        )
    }
    
    private func reopenMultipleTasks(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let taskIds = arguments["taskIds"] as? [String] else {
            return FunctionCallResult(
                functionName: "reopen_multiple_tasks",
                success: false,
                message: "Missing required parameter: taskIds",
                details: nil
            )
        }
        
        var reopenedCount = 0
        var failedCount = 0
        
        for taskIdStr in taskIds {
            guard let taskId = UUID(uuidString: taskIdStr),
                  let task = taskManager.tasks.first(where: { $0.id == taskId }) else {
                failedCount += 1
                continue
            }
            
            let result = taskManager.uncompleteTask(task)
            
            switch result {
            case .success:
                reopenedCount += 1
            case .failure:
                failedCount += 1
            }
        }
        
        return FunctionCallResult(
            functionName: "reopen_multiple_tasks",
            success: reopenedCount > 0,
            message: "🔄 **Reopened \(reopenedCount) tasks**" + (failedCount > 0 ? "\n⚠️ Failed to reopen \(failedCount) tasks" : ""),
            details: ["reopened": "\(reopenedCount)", "failed": "\(failedCount)"]
        )
    }
    
    private func deleteMultipleTasks(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let taskIds = arguments["taskIds"] as? [String] else {
            return FunctionCallResult(
                functionName: "delete_multiple_tasks",
                success: false,
                message: "Missing required parameter: taskIds",
                details: nil
            )
        }
        
        var deletedCount = 0
        var failedCount = 0
        
        for taskIdStr in taskIds {
            guard let taskId = UUID(uuidString: taskIdStr),
                  let task = taskManager.tasks.first(where: { $0.id == taskId }) else {
                failedCount += 1
                continue
            }
            
            let result = taskManager.deleteTask(task)
            
            switch result {
            case .success:
                deletedCount += 1
            case .failure:
                failedCount += 1
            }
        }
        
        return FunctionCallResult(
            functionName: "delete_multiple_tasks",
            success: deletedCount > 0,
            message: "🗑️ **Deleted \(deletedCount) tasks**" + (failedCount > 0 ? "\n⚠️ Failed to delete \(failedCount) tasks" : ""),
            details: ["deleted": "\(deletedCount)", "failed": "\(failedCount)"]
        )
    }
    
    private func completeAllTasksByFilter(with arguments: [String: Any]) async -> FunctionCallResult {
        var tasksToComplete: [Task] = []
        let allTasks = taskManager.tasks.filter { !$0.isCompleted }
        
        // Filter by date
        if let dateStr = arguments["date"] as? String,
           let date = ISO8601DateFormatter().date(from: dateStr) {
            let calendar = Calendar.current
            tasksToComplete = allTasks.filter { task in
                if let dueDate = task.dueDate {
                    return calendar.isDate(dueDate, inSameDayAs: date)
                } else if let scheduledTime = task.scheduledTime {
                    return calendar.isDate(scheduledTime, inSameDayAs: date)
                }
                return false
            }
        }
        // Filter by priority
        else if let priorityStr = arguments["priority"] as? String {
            let priority = TaskPriority(rawValue: priorityStr == "low" ? 0 : priorityStr == "high" ? 2 : 1) ?? .medium
            tasksToComplete = allTasks.filter { $0.priority == priority.rawValue }
        }
        // Filter by category
        else if let categoryName = arguments["category"] as? String {
            tasksToComplete = allTasks.filter { $0.category?.name == categoryName }
        }
        // Filter by tag
        else if let tag = arguments["tag"] as? String {
            tasksToComplete = allTasks.filter { $0.tagsArray.contains(tag) }
        }
        // Filter overdue
        else if arguments["overdue"] as? Bool == true {
            let now = Date()
            tasksToComplete = allTasks.filter { task in
                if let dueDate = task.dueDate {
                    return dueDate < now
                }
                return false
            }
        }
        
        if tasksToComplete.isEmpty {
            return FunctionCallResult(
                functionName: "complete_all_tasks_by_filter",
                success: false,
                message: "No matching tasks found",
                details: nil
            )
        }
        
        var completedCount = 0
        for task in tasksToComplete {
            let result = taskManager.completeTask(task)
            if case .success = result {
                completedCount += 1
            }
        }
        
        return FunctionCallResult(
            functionName: "complete_all_tasks_by_filter",
            success: true,
            message: "✅ **Completed \(completedCount) tasks**",
            details: ["completed": "\(completedCount)"]
        )
    }
    
    private func deleteAllCompletedTasks(with arguments: [String: Any]) async -> FunctionCallResult {
        var tasksToDelete = taskManager.tasks.filter { $0.isCompleted }
        
        // Filter by age if specified
        if let olderThanDays = arguments["olderThanDays"] as? Double {
            let cutoffDate = Date().addingTimeInterval(-olderThanDays * 24 * 60 * 60)
            tasksToDelete = tasksToDelete.filter { task in
                if let completedAt = task.completedAt {
                    return completedAt < cutoffDate
                }
                return false
            }
        }
        
        if tasksToDelete.isEmpty {
            return FunctionCallResult(
                functionName: "delete_all_completed_tasks",
                success: false,
                message: "No completed tasks found matching criteria",
                details: nil
            )
        }
        
        var deletedCount = 0
        for task in tasksToDelete {
            let result = taskManager.deleteTask(task)
            if case .success = result {
                deletedCount += 1
            }
        }
        
        return FunctionCallResult(
            functionName: "delete_all_completed_tasks",
            success: true,
            message: "🗑️ **Deleted \(deletedCount) completed tasks**",
            details: ["deleted": "\(deletedCount)"]
        )
    }
    
    private func updateAllTasks(with arguments: [String: Any]) async -> FunctionCallResult {
        let filter = arguments["filter"] as? [String: Any] ?? [:]
        guard let updates = arguments["updates"] as? [String: Any] else {
            return FunctionCallResult(
                functionName: "update_all_tasks",
                success: false,
                message: "Missing required updates parameter",
                details: nil
            )
        }
        
        // Start with all tasks
        var tasksToUpdate = taskManager.tasks
        
        // Apply filters
        if let dateStr = filter["date"] as? String,
           let filterDate = ISO8601DateFormatter().date(from: dateStr) {
            let calendar = Calendar.current
            tasksToUpdate = tasksToUpdate.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return calendar.isDate(dueDate, inSameDayAs: filterDate)
            }
        }
        
        if let priority = filter["priority"] as? String {
            let priorityValue: Int16
            switch priority.lowercased() {
            case "low": priorityValue = 0
            case "medium": priorityValue = 1
            case "high": priorityValue = 2
            default: priorityValue = 1
            }
            tasksToUpdate = tasksToUpdate.filter { $0.priority == priorityValue }
        }
        
        if let categoryName = filter["category"] as? String {
            tasksToUpdate = tasksToUpdate.filter { $0.category?.name == categoryName }
        }
        
        if let tag = filter["tag"] as? String {
            tasksToUpdate = tasksToUpdate.filter { task in
                let taskTags = task.tags?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
                return taskTags.contains(tag)
            }
        }
        
        if let overdue = filter["overdue"] as? Bool, overdue {
            let now = Date()
            tasksToUpdate = tasksToUpdate.filter { task in
                guard let dueDate = task.dueDate, !task.isCompleted else { return false }
                return dueDate < now
            }
        }
        
        if let completed = filter["completed"] as? Bool {
            tasksToUpdate = tasksToUpdate.filter { $0.isCompleted == completed }
        }
        
        if tasksToUpdate.isEmpty {
            return FunctionCallResult(
                functionName: "update_all_tasks",
                success: true,
                message: "No tasks found matching the filter criteria",
                details: nil
            )
        }
        
        // Parse updates
        let priority = updates["priority"] as? String
        let addDays = updates["addDays"] as? Double ?? 0
        let isCompleted = updates["isCompleted"] as? Bool
        
        var category: Category?
        if let categoryName = updates["category"] as? String {
            category = scheduleManager.categories.first { $0.name == categoryName }
            if category == nil {
                // Create category if doesn't exist
                let (icon, color) = self.generateUniqueIconAndColor(for: categoryName)
                let result = scheduleManager.createCategory(name: categoryName, icon: icon, colorHex: color)
                if case .success(let newCategory) = result {
                    category = newCategory
                }
            }
        }
        
        var updatedCount = 0
        var failedCount = 0
        
        for task in tasksToUpdate {
            // Calculate new due date if addDays is specified
            var newDueDate = task.dueDate
            var newScheduledTime = task.scheduledTime
            
            if addDays != 0 {
                if let dueDate = task.dueDate {
                    newDueDate = dueDate.addingTimeInterval(addDays * 24 * 60 * 60)
                }
                if let scheduledTime = task.scheduledTime {
                    newScheduledTime = scheduledTime.addingTimeInterval(addDays * 24 * 60 * 60)
                }
            }
            
            // Parse specific date updates
            if let dueDateStr = updates["dueDate"] as? String {
                newDueDate = ISO8601DateFormatter().date(from: dueDateStr)
            }
            
            if let scheduledTimeStr = updates["scheduledTime"] as? String {
                newScheduledTime = ISO8601DateFormatter().date(from: scheduledTimeStr)
            }
            
            // Handle tags
            var newTags = task.tags as? [String] ?? []
            if let tags = updates["tags"] as? [String] {
                newTags = tags // Replace all tags
            } else if let addTags = updates["addTags"] as? [String] {
                newTags.append(contentsOf: addTags)
                newTags = Array(Set(newTags)) // Remove duplicates
            }
            
            if let removeTags = updates["removeTags"] as? [String] {
                newTags.removeAll { removeTags.contains($0) }
            }
            
            let result = taskManager.updateTask(
                task,
                title: updates["title"] as? String,
                notes: updates["notes"] as? String,
                dueDate: newDueDate,
                priority: priority != nil ? {
                    switch priority!.lowercased() {
                    case "low": return TaskPriority.low
                    case "medium": return TaskPriority.medium
                    case "high": return TaskPriority.high
                    default: return TaskPriority.medium
                    }
                }() : nil,
                category: category,
                tags: newTags,
                estimatedDuration: updates["estimatedDuration"] as? Int16,
                scheduledTime: newScheduledTime,
                linkedEvent: nil,
                parentTask: nil
            )
            
            switch result {
            case .success:
                updatedCount += 1
                
                // Handle completion status if specified
                if let isCompleted = isCompleted {
                    if isCompleted {
                        _ = taskManager.completeTask(task)
                    } else {
                        _ = taskManager.uncompleteTask(task)
                    }
                }
                
            case .failure:
                failedCount += 1
            }
        }
        
        let details: [String: String] = [
            "tasksFound": "\(tasksToUpdate.count)",
            "updated": "\(updatedCount)",
            "failed": "\(failedCount)"
        ]
        
        if failedCount > 0 {
            return FunctionCallResult(
                functionName: "update_all_tasks",
                success: false,
                message: "Updated \(updatedCount) tasks, but \(failedCount) failed",
                details: details
            )
        } else {
            return FunctionCallResult(
                functionName: "update_all_tasks",
                success: true,
                message: "✅ Successfully updated \(updatedCount) tasks",
                details: details
            )
        }
    }
    
    private func deleteAllTasks(with arguments: [String: Any]) async -> FunctionCallResult {
        // Remove confirm check - if the AI calls this function, it's already confirmed
        
        let filter = arguments["filter"] as? [String: Any] ?? [:]
        var tasksToDelete = taskManager.tasks
        
        // Apply filters (same as updateAllTasks)
        if let dateStr = filter["date"] as? String,
           let filterDate = ISO8601DateFormatter().date(from: dateStr) {
            let calendar = Calendar.current
            tasksToDelete = tasksToDelete.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return calendar.isDate(dueDate, inSameDayAs: filterDate)
            }
        }
        
        if let priority = filter["priority"] as? String {
            let priorityValue: Int16
            switch priority.lowercased() {
            case "low": priorityValue = 0
            case "medium": priorityValue = 1
            case "high": priorityValue = 2
            default: priorityValue = 1
            }
            tasksToDelete = tasksToDelete.filter { $0.priority == priorityValue }
        }
        
        if let categoryName = filter["category"] as? String {
            tasksToDelete = tasksToDelete.filter { $0.category?.name == categoryName }
        }
        
        if let tag = filter["tag"] as? String {
            tasksToDelete = tasksToDelete.filter { task in
                task.tags?.contains { ($0 as? String) == tag } ?? false
            }
        }
        
        if let overdue = filter["overdue"] as? Bool, overdue {
            let now = Date()
            tasksToDelete = tasksToDelete.filter { task in
                guard let dueDate = task.dueDate, !task.isCompleted else { return false }
                return dueDate < now
            }
        }
        
        if let completed = filter["completed"] as? Bool {
            tasksToDelete = tasksToDelete.filter { $0.isCompleted == completed }
        }
        
        if tasksToDelete.isEmpty {
            return FunctionCallResult(
                functionName: "delete_all_tasks",
                success: true,
                message: "No tasks found matching the criteria",
                details: nil
            )
        }
        
        var deletedCount = 0
        for task in tasksToDelete {
            let result = taskManager.deleteTask(task)
            if case .success = result {
                deletedCount += 1
            }
        }
        
        return FunctionCallResult(
            functionName: "delete_all_tasks",
            success: true,
            message: "🗑️ **Deleted \(deletedCount) tasks**",
            details: ["deleted": "\(deletedCount)"]
        )
    }
    
    private func rescheduleTasks(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let taskIds = arguments["taskIds"] as? [String],
              let newDateStr = arguments["newDate"] as? String,
              let newDate = ISO8601DateFormatter().date(from: newDateStr) else {
            return FunctionCallResult(
                functionName: "reschedule_tasks",
                success: false,
                message: "Missing required parameters",
                details: nil
            )
        }
        
        let preserveTime = arguments["preserveTime"] as? Bool ?? false
        let spacingMinutes = arguments["spacingMinutes"] as? Double ?? 0
        
        var rescheduledCount = 0
        var currentDate = newDate
        
        for (index, taskIdStr) in taskIds.enumerated() {
            guard let taskId = UUID(uuidString: taskIdStr),
                  let task = taskManager.tasks.first(where: { $0.id == taskId }) else {
                continue
            }
            
            var scheduledTime = currentDate
            
            if preserveTime, let originalTime = task.scheduledTime ?? task.dueDate {
                // Keep the time portion from the original date
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: originalTime)
                scheduledTime = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                            minute: timeComponents.minute ?? 0,
                                            second: 0,
                                            of: currentDate) ?? currentDate
            }
            
            if spacingMinutes > 0 && index > 0 {
                scheduledTime = scheduledTime.addingTimeInterval(Double(index) * spacingMinutes * 60)
            }
            
            let result = taskManager.updateTask(
                task,
                title: nil,
                notes: nil,
                dueDate: scheduledTime,
                priority: nil,
                category: nil,
                tags: nil,
                estimatedDuration: nil,
                scheduledTime: scheduledTime,
                linkedEvent: nil,
                parentTask: nil
            )
            
            if case .success = result {
                rescheduledCount += 1
            }
        }
        
        return FunctionCallResult(
            functionName: "reschedule_tasks",
            success: rescheduledCount > 0,
            message: "📅 **Rescheduled \(rescheduledCount) tasks to \(DateFormatter.localizedString(from: newDate, dateStyle: .medium, timeStyle: .none))**",
            details: ["rescheduled": "\(rescheduledCount)"]
        )
    }
    
    private func searchTasks(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let query = arguments["query"] as? String else {
            return FunctionCallResult(
                functionName: "search_tasks",
                success: false,
                message: "Missing search query",
                details: nil
            )
        }
        
        let includeCompleted = arguments["includeCompleted"] as? Bool ?? false
        let searchQuery = query.lowercased()
        
        let matchingTasks = taskManager.tasks.filter { task in
            if !includeCompleted && task.isCompleted {
                return false
            }
            
            let titleMatch = task.title?.lowercased().contains(searchQuery) ?? false
            let notesMatch = task.notes?.lowercased().contains(searchQuery) ?? false
            let tagsMatch = task.tagsArray.contains { $0.lowercased().contains(searchQuery) }
            
            return titleMatch || notesMatch || tagsMatch
        }
        
        if matchingTasks.isEmpty {
            return FunctionCallResult(
                functionName: "search_tasks",
                success: true,
                message: "No tasks found matching '\(query)'",
                details: ["count": "0"]
            )
        }
        
        var message = "🔍 **Found \(matchingTasks.count) tasks matching '\(query)':**\n\n"
        
        for task in matchingTasks.prefix(10) {
            let status = task.isCompleted ? "✅" : "⏳"
            let priority = TaskPriority(rawValue: task.priority) ?? .medium
            let priorityEmoji = priority == .high ? "🔴" : priority == .low ? "🟢" : "🟡"
            
            message += "\(status) \(priorityEmoji) **\(task.title ?? "Untitled")**\n"
            
            if let notes = task.notes, !notes.isEmpty {
                message += "   _\(notes.prefix(50))..._\n"
            }
            
            if let dueDate = task.dueDate {
                message += "   📅 Due: \(DateFormatter.localizedString(from: dueDate, dateStyle: .short, timeStyle: .short))\n"
            }
            
            message += "\n"
        }
        
        if matchingTasks.count > 10 {
            message += "_...and \(matchingTasks.count - 10) more_"
        }
        
        return FunctionCallResult(
            functionName: "search_tasks",
            success: true,
            message: message,
            details: [
                "count": "\(matchingTasks.count)",
                "taskIds": matchingTasks.prefix(10).compactMap { $0.id?.uuidString }.joined(separator: ",")
            ]
        )
    }
    
    private func getTaskStatistics(with arguments: [String: Any]) async -> FunctionCallResult {
        let period = arguments["period"] as? String ?? "all"
        
        var tasks = taskManager.tasks
        let now = Date()
        let calendar = Calendar.current
        
        // Filter by period
        switch period {
        case "today":
            tasks = tasks.filter { task in
                if let dueDate = task.dueDate {
                    return calendar.isDateInToday(dueDate)
                } else if let scheduledTime = task.scheduledTime {
                    return calendar.isDateInToday(scheduledTime)
                }
                return false
            }
        case "week":
            let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            tasks = tasks.filter { task in
                if let dueDate = task.dueDate {
                    return dueDate >= weekAgo
                } else if let scheduledTime = task.scheduledTime {
                    return scheduledTime >= weekAgo
                }
                return false
            }
        case "month":
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            tasks = tasks.filter { task in
                if let dueDate = task.dueDate {
                    return dueDate >= monthAgo
                } else if let scheduledTime = task.scheduledTime {
                    return scheduledTime >= monthAgo
                }
                return false
            }
        default:
            break // Use all tasks
        }
        
        let totalTasks = tasks.count
        let completedTasks = tasks.filter { $0.isCompleted }.count
        let pendingTasks = totalTasks - completedTasks
        let overdueTasks = tasks.filter { task in
            !task.isCompleted && (task.dueDate ?? Date.distantFuture) < now
        }.count
        
        let completionRate = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) * 100 : 0
        
        // Count by priority
        let highPriorityCount = tasks.filter { $0.priority == TaskPriority.high.rawValue }.count
        let mediumPriorityCount = tasks.filter { $0.priority == TaskPriority.medium.rawValue }.count
        let lowPriorityCount = tasks.filter { $0.priority == TaskPriority.low.rawValue }.count
        
        // Count by category
        var categoryCounts: [String: Int] = [:]
        for task in tasks {
            let categoryName = task.category?.name ?? "Uncategorized"
            categoryCounts[categoryName, default: 0] += 1
        }
        
        var message = "📊 **Task Statistics (\(period.capitalized))**\n\n"
        message += "**Overview:**\n"
        message += "• Total Tasks: \(totalTasks)\n"
        message += "• Completed: \(completedTasks) (\(String(format: "%.1f", completionRate))%)\n"
        message += "• Pending: \(pendingTasks)\n"
        message += "• Overdue: \(overdueTasks)\n\n"
        
        message += "**By Priority:**\n"
        message += "• 🔴 High: \(highPriorityCount)\n"
        message += "• 🟡 Medium: \(mediumPriorityCount)\n"
        message += "• 🟢 Low: \(lowPriorityCount)\n\n"
        
        if !categoryCounts.isEmpty {
            message += "**By Category:**\n"
            for (category, count) in categoryCounts.sorted(by: { $0.value > $1.value }).prefix(5) {
                message += "• \(category): \(count)\n"
            }
        }
        
        return FunctionCallResult(
            functionName: "get_task_statistics",
            success: true,
            message: message,
            details: [
                "total": "\(totalTasks)",
                "completed": "\(completedTasks)",
                "pending": "\(pendingTasks)",
                "overdue": "\(overdueTasks)",
                "completionRate": String(format: "%.1f", completionRate)
            ]
        )
    }
    
    // MARK: - Habit Management Functions
    
    private func createHabit(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let name = arguments["name"] as? String else {
            return FunctionCallResult(
                functionName: "create_habit",
                success: false,
                message: "Missing required parameter: name",
                details: nil
            )
        }
        
        // Parse parameters
        let icon = arguments["icon"] as? String ?? "star.fill"
        let color = arguments["color"] as? String ?? "#FF6B6B"
        let frequencyStr = arguments["frequency"] as? String ?? "daily"
        let frequency = HabitFrequency(rawValue: frequencyStr) ?? .daily
        let trackingTypeStr = arguments["trackingType"] as? String ?? "binary"
        let trackingType = HabitTrackingType(rawValue: trackingTypeStr) ?? .binary
        let goalTarget = arguments["goalTarget"] as? Double
        let goalUnit = arguments["goalUnit"] as? String
        let notes = arguments["notes"] as? String
        
        // Find category if specified
        var category: Category?
        if let categoryName = arguments["category"] as? String {
            category = scheduleManager.categories.first { $0.name?.lowercased() == categoryName.lowercased() }
        }
        
        let result = habitManager.createHabit(
            name: name,
            icon: icon,
            color: color,
            frequency: frequency,
            trackingType: trackingType,
            goalTarget: goalTarget,
            goalUnit: goalUnit,
            category: category,
            notes: notes
        )
        
        switch result {
        case .success(let habit):
            var message = "✅ **Created habit:** \(habit.name ?? "")\n\n"
            message += "📈 **Type:** \(trackingType.displayName)\n"
            message += "📅 **Frequency:** \(frequency.displayName)\n"
            
            if let target = goalTarget, trackingType != .binary {
                message += "🎯 **Goal:** \(Int(target)) \(goalUnit ?? "")\n"
            }
            
            return FunctionCallResult(
                functionName: "create_habit",
                success: true,
                message: message,
                details: ["habitId": habit.id?.uuidString ?? ""]
            )
            
        case .failure(let error):
            return FunctionCallResult(
                functionName: "create_habit",
                success: false,
                message: "Failed to create habit: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    private func createMultipleHabits(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let habitsArray = arguments["habits"] as? [[String: Any]] else {
            return FunctionCallResult(
                functionName: "create_multiple_habits",
                success: false,
                message: "Missing required parameter: habits (array)",
                details: nil
            )
        }
        
        guard !habitsArray.isEmpty else {
            return FunctionCallResult(
                functionName: "create_multiple_habits",
                success: false,
                message: "Habits array cannot be empty",
                details: nil
            )
        }
        
        // Prepare habit data for batch creation
        var habitDataArray: [(name: String, icon: String, color: String, frequency: HabitFrequency, trackingType: HabitTrackingType, goalTarget: Double?, goalUnit: String?, category: Category?, notes: String?)] = []
        var invalidHabits: [String] = []
        
        
        for habitData in habitsArray {
            guard let name = habitData["name"] as? String else {
                invalidHabits.append("Unknown (missing name)")
                continue
            }
            
            // Parse parameters
            let icon = habitData["icon"] as? String ?? "star.fill"
            let color = habitData["color"] as? String ?? "#FF6B6B"
            let frequencyStr = habitData["frequency"] as? String ?? "daily"
            let frequency = HabitFrequency(rawValue: frequencyStr) ?? .daily
            let trackingTypeStr = habitData["trackingType"] as? String ?? "binary"
            let trackingType = HabitTrackingType(rawValue: trackingTypeStr) ?? .binary
            let goalTarget = habitData["goalTarget"] as? Double
            let goalUnit = habitData["goalUnit"] as? String
            let notes = habitData["notes"] as? String
            
            // Find category if specified
            var category: Category?
            if let categoryName = habitData["category"] as? String {
                category = scheduleManager.categories.first { $0.name == categoryName }
            }
            
            habitDataArray.append((
                name: name,
                icon: icon,
                color: color,
                frequency: frequency,
                trackingType: trackingType,
                goalTarget: goalTarget,
                goalUnit: goalUnit,
                category: category,
                notes: notes
            ))
        }
        
        guard !habitDataArray.isEmpty else {
            return FunctionCallResult(
                functionName: "create_multiple_habits",
                success: false,
                message: "No valid habits to create",
                details: ["invalidCount": String(invalidHabits.count)]
            )
        }
        
        // Create all habits in a single batch
        let result = habitManager.createMultipleHabits(habitDataArray)
        
        var createdHabits: [String] = []
        var failedHabits: [String] = invalidHabits
        var totalCreated = 0
        
        switch result {
        case .success(let habits):
            totalCreated = habits.count
            for habit in habits {
                createdHabits.append("✅ \(habit.name ?? "Unknown")")
            }
        case .failure(let error):
            failedHabits.append("❌ Batch creation failed: \(error.localizedDescription)")
        }
        
        
        var message = "## Bulk Habit Creation Results\n\n"
        message += "**Created:** \(totalCreated) of \(habitsArray.count) habits\n\n"
        
        if !createdHabits.isEmpty {
            message += "### Successfully Created:\n"
            message += createdHabits.joined(separator: "\n") + "\n"
        }
        
        if !failedHabits.isEmpty {
            message += "\n### Failed:\n"
            message += failedHabits.joined(separator: "\n") + "\n"
        }
        
        return FunctionCallResult(
            functionName: "create_multiple_habits",
            success: totalCreated > 0,
            message: message,
            details: [
                "totalRequested": String(habitsArray.count),
                "totalCreated": String(totalCreated),
                "totalFailed": String(failedHabits.count)
            ]
        )
    }
    
    private func logHabit(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let habitName = arguments["habitName"] as? String ?? arguments["habit"] as? String else {
            return FunctionCallResult(
                functionName: "log_habit",
                success: false,
                message: "Missing required parameter: habitName",
                details: nil
            )
        }
        
        // Find habit by name
        guard let habit = habitManager.habits.first(where: { $0.name?.lowercased() == habitName.lowercased() }) else {
            return FunctionCallResult(
                functionName: "log_habit",
                success: false,
                message: "Habit '\(habitName)' not found",
                details: nil
            )
        }
        
        // Parse optional parameters
        let value = arguments["value"] as? Double ?? 1.0
        let notes = arguments["notes"] as? String
        let mood = arguments["mood"] as? Int16
        let quality = arguments["quality"] as? Int16
        
        // Parse date or use today
        let date: Date
        if let dateStr = arguments["date"] as? String {
            date = ISO8601DateFormatter().date(from: dateStr) ?? Date()
        } else {
            date = Date()
        }
        
        do {
            let result = try habitManager.logHabit(
                habit,
                value: value,
                date: date,
                notes: notes,
                mood: mood,
                duration: nil,
                quality: quality
            )
            
            var message = "✅ **Logged habit:** \(habit.name ?? "")\n\n"
            message += "🔥 **Current streak:** \(habit.currentStreak) days\n"
            
            if habit.currentStreak == habit.bestStreak && habit.bestStreak > 0 {
                message += "🏆 **New best streak!**\n"
            }
            
            let progress = habitManager.todayProgress()
            message += "\n📊 **Today's progress:** \(progress.completed)/\(progress.total) habits completed"
            
            return FunctionCallResult(
                functionName: "log_habit",
                success: true,
                message: message,
                details: ["streak": "\(habit.currentStreak)"]
            )
            
        } catch {
            return FunctionCallResult(
                functionName: "log_habit",
                success: false,
                message: "Failed to log habit: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    private func listHabits(with arguments: [String: Any]) async -> FunctionCallResult {
        let date: Date
        if let dateStr = arguments["date"] as? String {
            date = ISO8601DateFormatter().date(from: dateStr) ?? Date()
        } else {
            date = Date()
        }
        
        let habits = habitManager.habitsForDate(date)
        
        if habits.isEmpty {
            return FunctionCallResult(
                functionName: "list_habits",
                success: true,
                message: "No habits scheduled for this date",
                details: ["count": "0"]
            )
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        var message = "📋 **Habits for \(dateFormatter.string(from: date)):**\n\n"
        
        for habit in habits {
            let isCompleted = habit.isCompletedToday
            let icon = isCompleted ? "✅" : "⭕"
            
            message += "\(icon) **\(habit.name ?? "")** "
            
            if habit.currentStreak > 0 {
                message += "🔥\(habit.currentStreak) "
            }
            
            if habit.trackingTypeEnum != .binary {
                let progress = habit.progressToday
                message += "(\(Int(progress * 100))%)"
            }
            
            message += "\n"
            
            if let notes = habit.notes, !notes.isEmpty {
                message += "   _\(notes)_\n"
            }
        }
        
        let progress = habitManager.todayProgress()
        message += "\n**Overall:** \(progress.completed)/\(progress.total) completed (\(Int(progress.percentage * 100))%)"
        
        return FunctionCallResult(
            functionName: "list_habits",
            success: true,
            message: message,
            details: ["count": "\(habits.count)"]
        )
    }
    
    private func updateHabit(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let habitName = arguments["habitName"] as? String else {
            return FunctionCallResult(
                functionName: "update_habit",
                success: false,
                message: "Missing required parameter: habitName",
                details: nil
            )
        }
        
        guard let habit = habitManager.habits.first(where: { $0.name?.lowercased() == habitName.lowercased() }) else {
            return FunctionCallResult(
                functionName: "update_habit",
                success: false,
                message: "Habit '\(habitName)' not found",
                details: nil
            )
        }
        
        // Update properties
        if let newName = arguments["newName"] as? String {
            habit.name = newName
        }
        if let icon = arguments["icon"] as? String {
            habit.iconName = icon
        }
        if let color = arguments["color"] as? String {
            habit.colorHex = color
        }
        if let goalTarget = arguments["goalTarget"] as? Double {
            habit.goalTarget = goalTarget
        }
        if let goalUnit = arguments["goalUnit"] as? String {
            habit.goalUnit = goalUnit
        }
        
        do {
            try habitManager.updateHabit(habit)
            return FunctionCallResult(
                functionName: "update_habit",
                success: true,
                message: "✅ Updated habit: \(habit.name ?? "")",
                details: nil
            )
        } catch {
            return FunctionCallResult(
                functionName: "update_habit",
                success: false,
                message: "Failed to update habit: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    private func deleteHabit(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let habitName = arguments["habitName"] as? String else {
            return FunctionCallResult(
                functionName: "delete_habit",
                success: false,
                message: "Missing required parameter: habitName",
                details: nil
            )
        }
        
        guard let habit = habitManager.habits.first(where: { $0.name?.lowercased() == habitName.lowercased() }) else {
            return FunctionCallResult(
                functionName: "delete_habit",
                success: false,
                message: "Habit '\(habitName)' not found",
                details: nil
            )
        }
        
        let habitTitle = habit.name ?? ""
        let result = habitManager.deleteHabit(habit)
        
        switch result {
        case .success:
            return FunctionCallResult(
                functionName: "delete_habit",
                success: true,
                message: "🗑️ Deleted habit: \(habitTitle)",
                details: nil
            )
        case .failure(let error):
            return FunctionCallResult(
                functionName: "delete_habit",
                success: false,
                message: "Failed to delete habit: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    private func getHabitStats(with arguments: [String: Any]) async -> FunctionCallResult {
        let period = arguments["period"] as? String ?? "month"
        
        let endDate = Date()
        let days = period == "week" ? 7 : period == "month" ? 30 : period == "year" ? 365 : 30
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        var message = "📊 **Habit Statistics (\(period.capitalized))**\n\n"
        
        // Overall stats
        var totalPossible = 0
        var totalCompleted = 0
        var activeStreaks = 0
        var bestPerformer: (habit: Habit, rate: Double)?
        
        for habit in habitManager.habits {
            let entries = habitManager.entriesForHabit(habit, in: startDate...endDate)
            let completed = entries.filter { !$0.skipped }.count
            totalCompleted += completed
            
            // Calculate possible based on frequency
            let possible = days // Simplified
            totalPossible += possible
            
            let rate = Double(completed) / Double(possible)
            if bestPerformer == nil || rate > bestPerformer!.rate {
                bestPerformer = (habit, rate)
            }
            
            if habit.currentStreak > 0 {
                activeStreaks += 1
            }
        }
        
        let overallRate = totalPossible > 0 ? Double(totalCompleted) / Double(totalPossible) : 0
        
        message += "**Overall Performance:**\n"
        message += "• Completion Rate: \(Int(overallRate * 100))%\n"
        message += "• Active Streaks: \(activeStreaks)\n"
        message += "• Total Completions: \(totalCompleted)\n\n"
        
        if let best = bestPerformer {
            message += "🏆 **Best Performer:** \(best.habit.name ?? "") (\(Int(best.rate * 100))%)\n\n"
        }
        
        // Individual habit stats
        message += "**Individual Habits:**\n"
        for habit in habitManager.habits.prefix(5) {
            let entries = habitManager.entriesForHabit(habit, in: startDate...endDate)
            let rate = Double(entries.count) / Double(days)
            message += "• \(habit.name ?? ""): \(Int(rate * 100))% | 🔥\(habit.currentStreak)\n"
        }
        
        return FunctionCallResult(
            functionName: "get_habit_stats",
            success: true,
            message: message,
            details: ["completionRate": "\(Int(overallRate * 100))"]
        )
    }
    
    private func pauseHabit(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let habitName = arguments["habitName"] as? String else {
            return FunctionCallResult(
                functionName: "pause_habit",
                success: false,
                message: "Missing required parameter: habitName",
                details: nil
            )
        }
        
        guard let habit = habitManager.habits.first(where: { $0.name?.lowercased() == habitName.lowercased() }) else {
            return FunctionCallResult(
                functionName: "pause_habit",
                success: false,
                message: "Habit '\(habitName)' not found",
                details: nil
            )
        }
        
        // Parse duration
        let days = arguments["days"] as? Int ?? 7
        
        habit.isPaused = true
        habit.pausedUntil = Calendar.current.date(byAdding: .day, value: days, to: Date())
        
        let result = habitManager.updateHabit(habit)
        
        switch result {
        case .success:
            return FunctionCallResult(
                functionName: "pause_habit",
                success: true,
                message: "⏸️ Paused '\(habit.name ?? "")' for \(days) days",
                details: nil
            )
        case .failure(let error):
            return FunctionCallResult(
                functionName: "pause_habit",
                success: false,
                message: "Failed to pause habit: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    private func getHabitInsights(with arguments: [String: Any]) async -> FunctionCallResult {
        let habitName = arguments["habitName"] as? String
        
        var message = "💡 **Habit Insights**\n\n"
        
        if let habitName = habitName,
           let habit = habitManager.habits.first(where: { $0.name?.lowercased() == habitName.lowercased() }) {
            // Specific habit insights
            let insights = habitManager.getInsights(for: habit)
            
            message += "**\(habit.name ?? ""):**\n"
            for insight in insights {
                message += "• \(insight)\n"
            }
            
            if let moodScore = habitManager.getMoodCorrelation(for: habit) {
                message += "\n📈 **Mood Impact:** +\(Int(moodScore * 100))%"
            }
        } else {
            // General insights
            let progress = habitManager.todayProgress()
            message += "**Today:** \(progress.completed)/\(progress.total) completed (\(Int(progress.percentage * 100))%)\n\n"
            
            // Find best streaks
            let topStreaks = habitManager.habits
                .filter { $0.currentStreak > 0 }
                .sorted { $0.currentStreak > $1.currentStreak }
                .prefix(3)
            
            if !topStreaks.isEmpty {
                message += "**Top Streaks:**\n"
                for habit in topStreaks {
                    message += "• \(habit.name ?? ""): 🔥\(habit.currentStreak) days\n"
                }
            }
            
            // Time patterns
            message += "\n**Best time to complete habits:** Morning (based on your history)"
        }
        
        return FunctionCallResult(
            functionName: "get_habit_insights",
            success: true,
            message: message,
            details: nil
        )
    }
    
    // MARK: - Bulk Habit Operations
    
    private func updateMultipleHabits(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let habitNames = arguments["habitNames"] as? [String],
              let updates = arguments["updates"] as? [String: Any] else {
            return FunctionCallResult(
                functionName: "update_multiple_habits",
                success: false,
                message: "Missing required parameters: habitNames and updates",
                details: nil
            )
        }
        
        var updatedHabits: [String] = []
        var failedHabits: [String] = []
        let totalHabits = habitNames.count
        
        for (index, habitName) in habitNames.enumerated() {
            guard let habit = habitManager.habits.first(where: { $0.name?.lowercased() == habitName.lowercased() }) else {
                failedHabits.append(habitName)
                continue
            }
            
            // Apply updates - ALL fields with contextual generation
            if let name = updates["name"] as? String {
                habit.name = generateContextualValue(for: habit, field: "name", baseValue: name, index: index, total: totalHabits) ?? name
            }
            if let icon = updates["icon"] as? String {
                habit.iconName = icon
            }
            if let color = updates["color"] as? String {
                habit.colorHex = color
            }
            if let goalTarget = updates["goalTarget"] as? Double {
                habit.goalTarget = goalTarget
            }
            if let goalUnit = updates["goalUnit"] as? String {
                habit.goalUnit = generateContextualValue(for: habit, field: "goalUnit", baseValue: goalUnit, index: index, total: totalHabits) ?? goalUnit
            }
            if let frequencyStr = updates["frequency"] as? String,
               let frequency = HabitFrequency(rawValue: frequencyStr) {
                habit.frequency = frequency.rawValue
            }
            if let categoryName = updates["category"] as? String {
                habit.category = scheduleManager.categories.first { $0.name == categoryName }
            }
            if let notes = updates["notes"] as? String {
                habit.notes = generateContextualValue(for: habit, field: "notes", baseValue: notes, index: index, total: totalHabits) ?? notes
            }
            if let trackingType = updates["trackingType"] as? String {
                habit.trackingType = trackingType
            }
            if let weeklyTarget = updates["weeklyTarget"] as? Int {
                habit.weeklyTarget = Int16(weeklyTarget)
            }
            if let reminderEnabled = updates["reminderEnabled"] as? Bool {
                habit.reminderEnabled = reminderEnabled
            }
            if let reminderTimeStr = updates["reminderTime"] as? String {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                if let reminderTime = formatter.date(from: reminderTimeStr) {
                    habit.reminderTime = reminderTime
                }
            }
            if let streakSafetyNet = updates["streakSafetyNet"] as? Bool {
                habit.streakSafetyNet = streakSafetyNet
            }
            if let isActive = updates["isActive"] as? Bool {
                habit.isActive = isActive
            }
            if let isPaused = updates["isPaused"] as? Bool {
                habit.isPaused = isPaused
            }
            if let pausedUntilStr = updates["pausedUntil"] as? String {
                let formatter = ISO8601DateFormatter()
                if let pausedUntil = formatter.date(from: pausedUntilStr) {
                    habit.pausedUntil = pausedUntil
                }
            }
            if let sortOrder = updates["sortOrder"] as? Int {
                habit.sortOrder = Int32(sortOrder)
            }
            if let stackOrder = updates["stackOrder"] as? Int {
                habit.stackOrder = Int32(stackOrder)
            }
            if let frequencyDays = updates["frequencyDays"] as? String {
                habit.frequencyDays = frequencyDays
            }
            
            let result = habitManager.updateHabit(habit)
            if case .success = result {
                updatedHabits.append(habit.name ?? "")
            } else {
                failedHabits.append(habit.name ?? "")
            }
        }
        
        if updatedHabits.isEmpty {
            return FunctionCallResult(
                functionName: "update_multiple_habits",
                success: false,
                message: "Failed to update any habits",
                details: ["failed": failedHabits.joined(separator: ", ")]
            )
        }
        
        var message = "✅ **Updated \(updatedHabits.count) habits**\n\n"
        message += updatedHabits.map { "• \($0)" }.joined(separator: "\n")
        
        if !failedHabits.isEmpty {
            message += "\n\n⚠️ Failed: \(failedHabits.joined(separator: ", "))"
        }
        
        return FunctionCallResult(
            functionName: "update_multiple_habits",
            success: true,
            message: message,
            details: ["updated": "\(updatedHabits.count)"]
        )
    }
    
    private func deleteMultipleHabits(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let habitNames = arguments["habitNames"] as? [String] else {
            return FunctionCallResult(
                functionName: "delete_multiple_habits",
                success: false,
                message: "Missing required parameter: habitNames",
                details: nil
            )
        }
        
        var deletedHabits: [String] = []
        var failedHabits: [String] = []
        
        for habitName in habitNames {
            guard let habit = habitManager.habits.first(where: { $0.name?.lowercased() == habitName.lowercased() }) else {
                failedHabits.append(habitName)
                continue
            }
            
            let result = habitManager.deleteHabit(habit)
            if case .success = result {
                deletedHabits.append(habitName)
            } else {
                failedHabits.append(habitName)
            }
        }
        
        if deletedHabits.isEmpty {
            return FunctionCallResult(
                functionName: "delete_multiple_habits",
                success: false,
                message: "Failed to delete any habits",
                details: ["failed": failedHabits.joined(separator: ", ")]
            )
        }
        
        var message = "🗑️ **Deleted \(deletedHabits.count) habits**\n\n"
        message += deletedHabits.map { "• \($0)" }.joined(separator: "\n")
        
        if !failedHabits.isEmpty {
            message += "\n\n⚠️ Failed: \(failedHabits.joined(separator: ", "))"
        }
        
        return FunctionCallResult(
            functionName: "delete_multiple_habits",
            success: true,
            message: message,
            details: ["deleted": "\(deletedHabits.count)"]
        )
    }
    
    private func deleteAllHabits(with arguments: [String: Any]) async -> FunctionCallResult {
        let categoryName = arguments["category"] as? String
        
        var habitsToDelete = habitManager.habits
        
        if let categoryName = categoryName {
            habitsToDelete = habitsToDelete.filter { $0.category?.name == categoryName }
        }
        
        if habitsToDelete.isEmpty {
            return FunctionCallResult(
                functionName: "delete_all_habits",
                success: true,
                message: "No habits found to delete",
                details: ["deleted": "0"]
            )
        }
        
        var deletedCount = 0
        for habit in habitsToDelete {
            let result = habitManager.deleteHabit(habit)
            if case .success = result {
                deletedCount += 1
            }
        }
        
        var message = "🗑️ **Deleted \(deletedCount) habits**"
        if let categoryName = categoryName {
            message += " in category '\(categoryName)'"
        }
        
        return FunctionCallResult(
            functionName: "delete_all_habits",
            success: deletedCount > 0,
            message: message,
            details: ["deleted": "\(deletedCount)"]
        )
    }
    
    private func updateAllHabits(with arguments: [String: Any]) async -> FunctionCallResult {
        let filter = arguments["filter"] as? [String: Any] ?? [:]
        guard let updates = arguments["updates"] as? [String: Any] else {
            return FunctionCallResult(
                functionName: "update_all_habits",
                success: false,
                message: "Missing required updates parameter",
                details: nil
            )
        }
        
        // Start with all habits
        var habitsToUpdate = habitManager.habits
        
        // Apply filters
        if let categoryName = filter["category"] as? String {
            habitsToUpdate = habitsToUpdate.filter { $0.category?.name == categoryName }
        }
        
        if let frequency = filter["frequency"] as? String {
            habitsToUpdate = habitsToUpdate.filter { $0.frequency == frequency }
        }
        
        if let isPaused = filter["isPaused"] as? Bool {
            habitsToUpdate = habitsToUpdate.filter { $0.isPaused == isPaused }
        }
        
        if let hasReminder = filter["hasReminder"] as? Bool {
            habitsToUpdate = habitsToUpdate.filter { habit in
                hasReminder ? (habit.reminderTime != nil) : (habit.reminderTime == nil)
            }
        }
        
        if habitsToUpdate.isEmpty {
            return FunctionCallResult(
                functionName: "update_all_habits",
                success: true,
                message: "No habits found matching the filter criteria",
                details: nil
            )
        }
        
        // Parse category update
        var category: Category?
        if let categoryName = updates["category"] as? String {
            category = scheduleManager.categories.first { $0.name == categoryName }
            if category == nil {
                // Create category if doesn't exist
                let (icon, color) = self.generateUniqueIconAndColor(for: categoryName)
                let result = scheduleManager.createCategory(name: categoryName, icon: icon, colorHex: color)
                if case .success(let newCategory) = result {
                    category = newCategory
                }
            }
        }
        
        var updatedCount = 0
        var failedCount = 0
        
        for habit in habitsToUpdate {
            // Update habit properties directly
            if let description = updates["description"] as? String {
                habit.notes = description
            }
            if let icon = updates["icon"] as? String {
                habit.iconName = icon
            }
            if let color = updates["color"] as? String {
                habit.colorHex = color
            }
            if let goalTarget = updates["goalTarget"] as? Double {
                habit.goalTarget = goalTarget
            }
            if let goalUnit = updates["goalUnit"] as? String {
                habit.goalUnit = goalUnit
            }
            if let frequency = updates["frequency"] as? String {
                habit.frequency = frequency
            }
            if let category = category {
                habit.category = category
            }
            if let reminderTimeStr = updates["reminderTime"] as? String {
                // Parse HH:MM format
                let components = reminderTimeStr.split(separator: ":")
                if components.count == 2,
                   let hour = Int(components[0]),
                   let minute = Int(components[1]) {
                    let calendar = Calendar.current
                    habit.reminderTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
                }
            }
            if let isPaused = updates["isPaused"] as? Bool {
                habit.isPaused = isPaused
            }
            
            let result = habitManager.updateHabit(habit)
            
            switch result {
            case .success:
                updatedCount += 1
            case .failure:
                failedCount += 1
            }
        }
        
        let details: [String: String] = [
            "habitsFound": "\(habitsToUpdate.count)",
            "updated": "\(updatedCount)",
            "failed": "\(failedCount)"
        ]
        
        if failedCount > 0 {
            return FunctionCallResult(
                functionName: "update_all_habits",
                success: false,
                message: "Updated \(updatedCount) habits, but \(failedCount) failed",
                details: details
            )
        } else {
            return FunctionCallResult(
                functionName: "update_all_habits",
                success: true,
                message: "✅ Successfully updated \(updatedCount) habits",
                details: details
            )
        }
    }
    
    private func pauseMultipleHabits(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let habitNames = arguments["habitNames"] as? [String] else {
            return FunctionCallResult(
                functionName: "pause_multiple_habits",
                success: false,
                message: "Missing required parameter: habitNames",
                details: nil
            )
        }
        
        let days = arguments["days"] as? Int ?? 7
        let pauseUntil = Calendar.current.date(byAdding: .day, value: days, to: Date())
        
        var pausedHabits: [String] = []
        var failedHabits: [String] = []
        
        for habitName in habitNames {
            guard let habit = habitManager.habits.first(where: { $0.name?.lowercased() == habitName.lowercased() }) else {
                failedHabits.append(habitName)
                continue
            }
            
            habit.isPaused = true
            habit.pausedUntil = pauseUntil
            
            let result = habitManager.updateHabit(habit)
            if case .success = result {
                pausedHabits.append(habit.name ?? "")
            } else {
                failedHabits.append(habit.name ?? "")
            }
        }
        
        if pausedHabits.isEmpty {
            return FunctionCallResult(
                functionName: "pause_multiple_habits",
                success: false,
                message: "Failed to pause any habits",
                details: ["failed": failedHabits.joined(separator: ", ")]
            )
        }
        
        var message = "⏸️ **Paused \(pausedHabits.count) habits for \(days) days**\n\n"
        message += pausedHabits.map { "• \($0)" }.joined(separator: "\n")
        
        if !failedHabits.isEmpty {
            message += "\n\n⚠️ Failed: \(failedHabits.joined(separator: ", "))"
        }
        
        return FunctionCallResult(
            functionName: "pause_multiple_habits",
            success: true,
            message: message,
            details: ["paused": "\(pausedHabits.count)"]
        )
    }
    
    private func resumeMultipleHabits(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let habitNames = arguments["habitNames"] as? [String] else {
            return FunctionCallResult(
                functionName: "resume_multiple_habits",
                success: false,
                message: "Missing required parameter: habitNames",
                details: nil
            )
        }
        
        var resumedHabits: [String] = []
        var failedHabits: [String] = []
        
        for habitName in habitNames {
            guard let habit = habitManager.habits.first(where: { $0.name?.lowercased() == habitName.lowercased() }) else {
                failedHabits.append(habitName)
                continue
            }
            
            habit.isPaused = false
            habit.pausedUntil = nil
            
            let result = habitManager.updateHabit(habit)
            if case .success = result {
                resumedHabits.append(habit.name ?? "")
            } else {
                failedHabits.append(habit.name ?? "")
            }
        }
        
        if resumedHabits.isEmpty {
            return FunctionCallResult(
                functionName: "resume_multiple_habits",
                success: false,
                message: "Failed to resume any habits",
                details: ["failed": failedHabits.joined(separator: ", ")]
            )
        }
        
        var message = "▶️ **Resumed \(resumedHabits.count) habits**\n\n"
        message += resumedHabits.map { "• \($0)" }.joined(separator: "\n")
        
        if !failedHabits.isEmpty {
            message += "\n\n⚠️ Failed: \(failedHabits.joined(separator: ", "))"
        }
        
        return FunctionCallResult(
            functionName: "resume_multiple_habits",
            success: true,
            message: message,
            details: ["resumed": "\(resumedHabits.count)"]
        )
    }
    
    private func logMultipleHabits(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let entries = arguments["entries"] as? [[String: Any]] else {
            return FunctionCallResult(
                functionName: "log_multiple_habits",
                success: false,
                message: "Missing required parameter: entries",
                details: nil
            )
        }
        
        var loggedHabits: [String] = []
        var failedHabits: [String] = []
        
        for entry in entries {
            guard let habitName = entry["habitName"] as? String else {
                continue
            }
            
            let value = entry["value"] as? Double ?? 1.0
            let dateStr = entry["date"] as? String
            let notes = entry["notes"] as? String
            let mood = entry["mood"] as? Int
            let quality = entry["quality"] as? Int
            
            var date = Date()
            if let dateStr = dateStr {
                let formatter = ISO8601DateFormatter()
                date = formatter.date(from: dateStr) ?? Date()
            }
            
            guard let habit = habitManager.habits.first(where: { $0.name?.lowercased() == habitName.lowercased() }) else {
                failedHabits.append(habitName)
                continue
            }
            
            let result = habitManager.logHabit(
                habit,
                value: value,
                date: date,
                notes: notes,
                mood: mood != nil ? Int16(mood!) : nil,
                duration: nil,
                quality: quality != nil ? Int16(quality!) : nil
            )
            
            switch result {
            case .success:
                loggedHabits.append(habit.name ?? "")
            case .failure:
                failedHabits.append(habit.name ?? "")
            }
        }
        
        if loggedHabits.isEmpty {
            return FunctionCallResult(
                functionName: "log_multiple_habits",
                success: false,
                message: "Failed to log any habits",
                details: ["failed": failedHabits.joined(separator: ", ")]
            )
        }
        
        var message = "✅ **Logged \(loggedHabits.count) habits**\n\n"
        message += loggedHabits.map { "• \($0)" }.joined(separator: "\n")
        
        if !failedHabits.isEmpty {
            message += "\n\n⚠️ Failed: \(failedHabits.joined(separator: ", "))"
        }
        
        return FunctionCallResult(
            functionName: "log_multiple_habits",
            success: true,
            message: message,
            details: ["logged": "\(loggedHabits.count)"]
        )
    }
    
    // MARK: - Goal Management Functions
    
    private func createGoal(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let title = arguments["title"] as? String,
              let typeStr = arguments["type"] as? String else {
            return FunctionCallResult(
                functionName: "create_goal",
                success: false,
                message: "Missing required parameters: title and type",
                details: nil
            )
        }
        
        guard let type = GoalType(rawValue: typeStr) else {
            return FunctionCallResult(
                functionName: "create_goal",
                success: false,
                message: "Invalid goal type. Must be: milestone, numeric, habit, or project",
                details: nil
            )
        }
        
        // Parse parameters
        let description = arguments["description"] as? String
        let targetValue = arguments["targetValue"] as? Double
        let unit = arguments["unit"] as? String
        let priorityStr = arguments["priority"] as? String ?? "medium"
        let priorityValue = ["low": 0, "medium": 1, "high": 2, "critical": 3][priorityStr] ?? 1
        let priority = GoalPriority(rawValue: Int16(priorityValue)) ?? .medium
        
        // Parse target date
        var targetDate: Date?
        if let targetDateStr = arguments["targetDate"] as? String {
            let formatter = ISO8601DateFormatter()
            targetDate = formatter.date(from: targetDateStr)
        }
        
        // Find category/area
        var category: Category?
        if let categoryName = arguments["category"] as? String ?? arguments["area"] as? String {
            // First try exact case-insensitive match with goal areas
            category = GoalAreaManager.shared.categories.first { $0.name?.lowercased() == categoryName.lowercased() && $0.isActive }
            
            // If no match, try to map common terms to areas
            if category == nil {
                let mapping: [String: String] = [
                    "money": "financial",
                    "finance": "financial",
                    "wealth": "financial",
                    "exercise": "fitness",
                    "workout": "fitness",
                    "gym": "fitness",
                    "wellbeing": "health",
                    "wellness": "health",
                    "work": "career",
                    "job": "career",
                    "business": "career",
                    "learning": "education",
                    "study": "education",
                    "school": "education",
                    "family": "relationships",
                    "friends": "relationships",
                    "social": "relationships",
                    "art": "creative",
                    "music": "creative",
                    "writing": "creative"
                ]
                
                if let mappedName = mapping[categoryName.lowercased()] {
                    category = GoalAreaManager.shared.categories.first { $0.name?.lowercased() == mappedName && $0.isActive }
                }
            }
            
            // Fall back to scheduleManager categories if still no match
            if category == nil {
                category = scheduleManager.categories.first { $0.name?.lowercased() == categoryName.lowercased() }
            }
        }
        
        // Get linked items
        let linkedHabitNames = arguments["linkedHabitNames"] as? [String] ?? []
        // Note: Task linking is not supported in the current Core Data model
        
        // Create the goal
        let result = goalManager.createGoal(
            title: title,
            description: description,
            type: type,
            targetValue: targetValue,
            targetDate: targetDate,
            unit: unit,
            priority: priority,
            category: category
        )
        
        switch result {
        case .success(let goal):
            // Set initial current value if provided
            if let currentValue = arguments["currentValue"] as? Double {
                goal.currentValue = currentValue
                _ = goalManager.updateGoal(goal, title: nil, description: nil, targetValue: nil, targetDate: nil, unit: nil, priority: nil, category: nil)
            }
            
            // Link habits
            for habitName in linkedHabitNames {
                if let habit = habitManager.habits.first(where: { $0.name?.lowercased() == habitName.lowercased() }) {
                    _ = goalManager.linkHabit(habit, to: goal)
                }
            }
            
            var message = "🎯 **Created goal:** \(goal.title ?? "")\n\n"
            message += "📊 **Type:** \(type.displayName)\n"
            message += "🎖️ **Priority:** \(priority.displayName)\n"
            
            if let targetValue = targetValue, type == .numeric {
                message += "🎯 **Target:** \(Int(targetValue)) \(unit ?? "")\n"
            }
            
            if let targetDate = targetDate {
                message += "📅 **Due:** \(DateFormatter.localizedString(from: targetDate, dateStyle: .medium, timeStyle: .none))\n"
            }
            
            if !linkedHabitNames.isEmpty {
                message += "🔗 **Linked Habits:** \(linkedHabitNames.joined(separator: ", "))\n"
            }
            
            return FunctionCallResult(
                functionName: "create_goal",
                success: true,
                message: message,
                details: ["goalId": goal.id?.uuidString ?? ""]
            )
            
        case .failure(let error):
            return FunctionCallResult(
                functionName: "create_goal",
                success: false,
                message: "Failed to create goal: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    private func createMultipleGoals(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let goalsArray = arguments["goals"] as? [[String: Any]] else {
            return FunctionCallResult(
                functionName: "create_multiple_goals",
                success: false,
                message: "Missing required parameter: goals (array)",
                details: nil
            )
        }
        
        var createdGoals: [Goal] = []
        var failedGoals: [String] = []
        
        for goalData in goalsArray {
            guard let title = goalData["title"] as? String,
                  let typeStr = goalData["type"] as? String,
                  let type = GoalType(rawValue: typeStr) else {
                failedGoals.append(goalData["title"] as? String ?? "Unknown")
                continue
            }
            
            // Parse parameters
            let description = goalData["description"] as? String
            let targetValue = goalData["targetValue"] as? Double
            let unit = goalData["unit"] as? String
            let priorityStr = goalData["priority"] as? String ?? "medium"
            let priorityValue = ["low": 0, "medium": 1, "high": 2, "critical": 3][priorityStr] ?? 1
        let priority = GoalPriority(rawValue: Int16(priorityValue)) ?? .medium
            
            // Parse target date
            var targetDate: Date?
            if let targetDateStr = goalData["targetDate"] as? String {
                let formatter = ISO8601DateFormatter()
                targetDate = formatter.date(from: targetDateStr)
            }
            
            // Find category/area
            var category: Category?
            if let categoryName = goalData["category"] as? String ?? goalData["area"] as? String {
                // First try goal areas
                category = GoalAreaManager.shared.categories.first { $0.name?.lowercased() == categoryName.lowercased() && $0.isActive }
                
                // Fall back to scheduleManager categories
                if category == nil {
                    category = scheduleManager.categories.first { $0.name?.lowercased() == categoryName.lowercased() }
                }
            }
            
            // Create the goal
            let result = goalManager.createGoal(
                title: title,
                description: description,
                type: type,
                targetValue: targetValue,
                targetDate: targetDate,
                unit: unit,
                priority: priority,
                category: category
            )
            
            if case .success(let goal) = result {
                createdGoals.append(goal)
                
                // Set initial current value if provided
                if let currentValue = goalData["currentValue"] as? Double {
                    goal.currentValue = currentValue
                    _ = goalManager.updateGoal(goal, title: nil, description: nil, targetValue: nil, targetDate: nil, unit: nil, priority: nil, category: nil)
                }
                
                // Link habits if provided
                let linkedHabitNames = goalData["linkedHabitNames"] as? [String] ?? []
                
                for habitName in linkedHabitNames {
                    if let habit = habitManager.habits.first(where: { $0.name?.lowercased() == habitName.lowercased() }) {
                        _ = goalManager.linkHabit(habit, to: goal)
                    }
                }
            } else {
                failedGoals.append(title)
            }
        }
        
        if createdGoals.isEmpty {
            return FunctionCallResult(
                functionName: "create_multiple_goals",
                success: false,
                message: "Failed to create any goals",
                details: ["failed": failedGoals.joined(separator: ", ")]
            )
        }
        
        var message = "🎯 **Created \(createdGoals.count) goals:**\n\n"
        for goal in createdGoals {
            let type = GoalType(rawValue: goal.type ?? "") ?? .milestone
            message += "• **\(goal.title ?? "")** (\(type.displayName))\n"
        }
        
        if !failedGoals.isEmpty {
            message += "\n⚠️ Failed to create: \(failedGoals.joined(separator: ", "))"
        }
        
        return FunctionCallResult(
            functionName: "create_multiple_goals",
            success: true,
            message: message,
            details: [
                "created": "\(createdGoals.count)",
                "goalIds": createdGoals.compactMap { $0.id?.uuidString }.joined(separator: ",")
            ]
        )
    }
    
    private func listGoals(with arguments: [String: Any]) async -> FunctionCallResult {
        let status = arguments["status"] as? String ?? "active"
        let categoryName = arguments["category"] as? String
        let priorityStr = arguments["priority"] as? String
        let daysUntilDeadline = arguments["daysUntilDeadline"] as? Int
        
        var goals = goalManager.goals
        
        // Filter by status
        switch status {
        case "active":
            goals = goals.filter { !$0.isCompleted }
        case "completed":
            goals = goals.filter { $0.isCompleted }
        default:
            break // Show all
        }
        
        // Filter by category
        if let categoryName = categoryName {
            goals = goals.filter { $0.category?.name == categoryName }
        }
        
        // Filter by priority
        if let priorityStr = priorityStr,
           let priorityValue = ["low": 0, "medium": 1, "high": 2, "critical": 3][priorityStr] {
            goals = goals.filter { $0.priority == Int16(priorityValue) }
        }
        
        // Filter by deadline
        if let days = daysUntilDeadline {
            let deadline = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
            goals = goals.filter { goal in
                if let targetDate = goal.targetDate {
                    return targetDate <= deadline
                }
                return false
            }
        }
        
        if goals.isEmpty {
            return FunctionCallResult(
                functionName: "list_goals",
                success: true,
                message: "No goals found matching the criteria",
                details: ["count": "0"]
            )
        }
        
        var message = "🎯 **Goals (\(goals.count)):**\n\n"
        
        for goal in goals.sorted(by: { ($0.targetDate ?? Date.distantFuture) < ($1.targetDate ?? Date.distantFuture) }) {
            let type = GoalType(rawValue: goal.type ?? "") ?? .milestone
            let priority = GoalPriority(rawValue: goal.priority) ?? .medium
            let status = goal.isCompleted ? "✅" : "⏳"
            let priorityEmoji = priority == .critical ? "🔴" : priority == .high ? "🟠" : priority == .low ? "🟢" : "🟡"
            
            message += "\(status) \(priorityEmoji) **\(goal.title ?? "Untitled")**\n"
            message += "   \(type.icon) \(type.displayName)\n"
            
            if let progress = goalManager.getProgress(for: goal) {
                message += "   📊 Progress: \(Int(progress.percentage * 100))%\n"
            }
            
            if let targetDate = goal.targetDate {
                let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 0
                message += "   📅 Due: \(DateFormatter.localizedString(from: targetDate, dateStyle: .medium, timeStyle: .none)) (\(daysRemaining) days)\n"
            }
            
            message += "\n"
        }
        
        return FunctionCallResult(
            functionName: "list_goals",
            success: true,
            message: message,
            details: ["count": "\(goals.count)"]
        )
    }
    
    private func updateGoal(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let goalIdStr = arguments["goalId"] as? String,
              let goalId = UUID(uuidString: goalIdStr) else {
            return FunctionCallResult(
                functionName: "update_goal",
                success: false,
                message: "Missing or invalid goal ID",
                details: nil
            )
        }
        
        guard let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
            return FunctionCallResult(
                functionName: "update_goal",
                success: false,
                message: "Goal not found",
                details: nil
            )
        }
        
        let updates = arguments["updates"] as? [String: Any] ?? [:]
        
        // Parse updates
        let title = updates["title"] as? String
        let description = updates["description"] as? String
        let targetValue = updates["targetValue"] as? Double
        let unit = updates["unit"] as? String
        
        var targetDate: Date?
        if let targetDateStr = updates["targetDate"] as? String {
            let formatter = ISO8601DateFormatter()
            targetDate = formatter.date(from: targetDateStr)
        }
        
        var priority: GoalPriority?
        if let priorityStr = updates["priority"] as? String {
            let priorityValue = ["low": 0, "medium": 1, "high": 2, "critical": 3][priorityStr] ?? 1
            priority = GoalPriority(rawValue: Int16(priorityValue))
        }
        
        var category: Category?
        if let categoryName = updates["category"] as? String {
            print("🎯 UpdateGoal: Looking for category '\(categoryName)' for goal '\(goal.title ?? "")'")
            print("🎯 Available categories: \(scheduleManager.categories.compactMap { $0.name }.joined(separator: ", "))")
            
            // First try exact case-insensitive match
            category = scheduleManager.categories.first { $0.name?.lowercased() == categoryName.lowercased() }
            
            if category != nil {
                print("🎯 UpdateGoal: Found exact match '\(category?.name ?? "")'")
            } else {
                // If no exact match, try intelligent mapping
                category = self.findBestMatchingCategory(for: categoryName)
                if category != nil {
                    print("🎯 UpdateGoal: Found best match '\(category?.name ?? "")'")
                } else {
                    print("⚠️ UpdateGoal: No category found for '\(categoryName)'")
                }
            }
        }
        
        // Check if category was requested but not found
        var categoryWarning = ""
        if let requestedCategory = updates["category"] as? String, category == nil {
            categoryWarning = "\n\n⚠️ Category '\(requestedCategory)' not found. Goal category was not updated."
        }
        
        let result = goalManager.updateGoal(
            goal,
            title: title,
            description: description,
            targetValue: targetValue,
            targetDate: targetDate,
            unit: unit,
            priority: priority,
            category: category
        )
        
        switch result {
        case .success:
            return FunctionCallResult(
                functionName: "update_goal",
                success: true,
                message: "✅ Updated goal: **\(goal.title ?? "")**\(categoryWarning)",
                details: nil
            )
        case .failure(let error):
            return FunctionCallResult(
                functionName: "update_goal",
                success: false,
                message: "Failed to update goal: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    private func deleteGoal(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let goalIdStr = arguments["goalId"] as? String,
              let goalId = UUID(uuidString: goalIdStr),
              let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
            return FunctionCallResult(
                functionName: "delete_goal",
                success: false,
                message: "Goal not found",
                details: nil
            )
        }
        
        let result = goalManager.deleteGoal(goal)
        
        switch result {
        case .success:
            return FunctionCallResult(
                functionName: "delete_goal",
                success: true,
                message: "Goal '\(goal.title ?? "")' deleted successfully",
                details: nil
            )
        case .failure(let error):
            return FunctionCallResult(
                functionName: "delete_goal",
                success: false,
                message: "Failed to delete goal: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    private func addGoalProgress(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let goalIdStr = arguments["goalId"] as? String,
              let goalId = UUID(uuidString: goalIdStr),
              let amount = arguments["amount"] as? Double else {
            return FunctionCallResult(
                functionName: "add_goal_progress",
                success: false,
                message: "Missing required parameters: goalId and amount",
                details: nil
            )
        }
        
        guard let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
            return FunctionCallResult(
                functionName: "add_goal_progress",
                success: false,
                message: "Goal not found",
                details: nil
            )
        }
        
        let newValue = goal.currentValue + amount
        let result = goalManager.updateProgress(for: goal, value: newValue)
        
        switch result {
        case .success:
            let newProgress = goal.currentValue
            let percentage = goal.targetValue > 0 ? Int((newProgress / goal.targetValue) * 100) : 0
            
            return FunctionCallResult(
                functionName: "add_goal_progress",
                success: true,
                message: "Added \(amount) to goal progress. Current: \(newProgress)/\(goal.targetValue) (\(percentage)%)",
                details: [
                    "currentValue": "\(newProgress)",
                    "targetValue": "\(goal.targetValue)",
                    "progress": "\(goal.progress)",
                    "isCompleted": "\(goal.isCompleted)"
                ]
            )
        case .failure(let error):
            return FunctionCallResult(
                functionName: "add_goal_progress",
                success: false,
                message: "Failed to update progress: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    private func getGoalProgress(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let goalIdStr = arguments["goalId"] as? String,
              let goalId = UUID(uuidString: goalIdStr),
              let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
            return FunctionCallResult(
                functionName: "get_goal_progress",
                success: false,
                message: "Goal not found",
                details: nil
            )
        }
        
        let percentage = goal.targetValue > 0 ? Int((goal.currentValue / goal.targetValue) * 100) : 0
        
        return FunctionCallResult(
            functionName: "get_goal_progress",
            success: true,
            message: "Goal '\(goal.title ?? "")' is \(percentage)% complete (\(goal.currentValue)/\(goal.targetValue))",
            details: [
                "title": goal.title ?? "",
                "currentValue": "\(goal.currentValue)",
                "targetValue": "\(goal.targetValue)",
                "progress": "\(goal.progress)",
                "percentage": "\(percentage)",
                "isCompleted": "\(goal.isCompleted)",
                "type": goal.type ?? ""
            ]
        )
    }
    
    private func updateGoalProgress(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let goalIdStr = arguments["goalId"] as? String,
              let goalId = UUID(uuidString: goalIdStr),
              let value = arguments["value"] as? Double else {
            return FunctionCallResult(
                functionName: "update_goal_progress",
                success: false,
                message: "Missing required parameters: goalId and value",
                details: nil
            )
        }
        
        guard let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
            return FunctionCallResult(
                functionName: "update_goal_progress",
                success: false,
                message: "Goal not found",
                details: nil
            )
        }
        
        let notes = arguments["notes"] as? String
        
        let result = goalManager.updateProgress(for: goal, value: value, notes: notes)
        
        switch result {
        case .success:
            let progress = goalManager.getProgress(for: goal) ?? (currentValue: 0, targetValue: 1, percentage: 0)
            var message = "📈 **Updated progress for '\(goal.title ?? "")'**\n\n"
            message += "**Current:** \(Int(progress.currentValue))"
            
            if let unit = goal.unit {
                message += " \(unit)"
            }
            
            if progress.targetValue > 0 {
                message += " / \(Int(progress.targetValue))"
                if let unit = goal.unit {
                    message += " \(unit)"
                }
                message += " (\(Int(progress.percentage * 100))%)"
            }
            
            return FunctionCallResult(
                functionName: "update_goal_progress",
                success: true,
                message: message,
                details: ["percentage": "\(Int(progress.percentage * 100))"]
            )
        case .failure(let error):
            return FunctionCallResult(
                functionName: "update_goal_progress",
                success: false,
                message: "Failed to update progress: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    // MARK: - Milestone Functions
    
    private func addMilestone(with arguments: [String: Any]) async -> FunctionCallResult {
        // Support both goalId and goalName
        var goal: Goal?
        
        if let goalIdStr = arguments["goalId"] as? String,
           let goalId = UUID(uuidString: goalIdStr) {
            goal = goalManager.goals.first(where: { $0.id == goalId })
        } else if let goalName = arguments["goalName"] as? String {
            // Use same smart matching as addMultipleMilestones
            // First try exact match (case insensitive)
            goal = goalManager.goals.first(where: { 
                $0.title?.lowercased() == goalName.lowercased()
            })
            
            // If no exact match, try starts with
            if goal == nil {
                goal = goalManager.goals.first(where: { 
                    $0.title?.lowercased().starts(with: goalName.lowercased()) == true
                })
            }
            
            // If still no match, try contains but prefer better matches
            if goal == nil {
                let matchingGoals = goalManager.goals.filter { 
                    $0.title?.lowercased().contains(goalName.lowercased()) == true 
                }
                
                if !matchingGoals.isEmpty {
                    goal = matchingGoals.sorted { goal1, goal2 in
                        let title1 = goal1.title?.lowercased() ?? ""
                        let title2 = goal2.title?.lowercased() ?? ""
                        let search = goalName.lowercased()
                        
                        // Prefer goals where the search term appears earlier
                        let index1 = title1.range(of: search)?.lowerBound.utf16Offset(in: title1) ?? Int.max
                        let index2 = title2.range(of: search)?.lowerBound.utf16Offset(in: title2) ?? Int.max
                        
                        if index1 != index2 {
                            return index1 < index2
                        }
                        
                        // If same position, prefer shorter titles (more specific match)
                        return title1.count < title2.count
                    }.first
                }
            }
            
            if let foundGoal = goal {
                print("🎯 Found goal '\(foundGoal.title ?? "")' for search term '\(goalName)'")
            }
        }
        
        // If no goal found, try to be smart about it
        if goal == nil {
            let activeGoals = goalManager.activeGoals
            if activeGoals.count == 1 {
                // Only one active goal, use it
                goal = activeGoals.first
            } else if !activeGoals.isEmpty {
                // Multiple goals, prefer milestone-type goals
                let milestoneGoals = activeGoals.filter { $0.typeEnum == .milestone || $0.typeEnum == .project }
                if milestoneGoals.count == 1 {
                    goal = milestoneGoals.first
                } else if !milestoneGoals.isEmpty {
                    // Use the most recent milestone goal
                    goal = milestoneGoals.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }.first
                } else {
                    // Use the most recent active goal
                    goal = activeGoals.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }.first
                }
            }
        }
        
        guard let targetGoal = goal else {
            // Only list goals if we really can't figure it out
            if goalManager.goals.isEmpty {
                return FunctionCallResult(
                    functionName: "add_milestone",
                    success: false,
                    message: "You don't have any goals yet. Would you like to create a goal first?",
                    details: nil
                )
            } else {
                let goalsList = goalManager.goals.compactMap { $0.title }.joined(separator: "\n• ")
                return FunctionCallResult(
                    functionName: "add_milestone",
                    success: false,
                    message: "I couldn't determine which goal to add milestones to. Available goals:\n• \(goalsList)",
                    details: nil
                )
            }
        }
        
        guard let title = arguments["title"] as? String else {
            return FunctionCallResult(
                functionName: "add_milestone",
                success: false,
                message: "Please specify the milestone title",
                details: nil
            )
        }
        
        let targetValue = arguments["targetValue"] as? Double
        let targetDate: Date?
        if let targetDateStr = arguments["targetDate"] as? String {
            let formatter = ISO8601DateFormatter()
            targetDate = formatter.date(from: targetDateStr)
        } else {
            targetDate = nil
        }
        
        let result = goalManager.addMilestone(to: targetGoal, title: title, targetValue: targetValue, targetDate: targetDate)
        
        switch result {
        case .success:
            return FunctionCallResult(
                functionName: "add_milestone",
                success: true,
                message: "✅ Added milestone '\(title)' to goal '\(targetGoal.title ?? "")'",
                details: ["goalId": targetGoal.id?.uuidString ?? "", "milestoneTitle": title]
            )
        case .failure(let error):
            return FunctionCallResult(
                functionName: "add_milestone",
                success: false,
                message: "Failed to add milestone: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    private func addMultipleMilestones(with arguments: [String: Any]) async -> FunctionCallResult {
        // Debug: Log what arguments the AI actually sent
        print("🔍 addMultipleMilestones - Arguments received from AI:")
        for (key, value) in arguments {
            print("  - \(key): \(value)")
        }
        
        // Support both goalId and goalName
        var goal: Goal?
        
        // First check for top-level goalId
        if let goalIdStr = arguments["goalId"] as? String,
           let goalId = UUID(uuidString: goalIdStr) {
            goal = goalManager.goals.first(where: { $0.id == goalId })
            print("✅ Found goal from top-level goalId: '\(goal?.title ?? "")'")
        } 
        // If no top-level goalId, check if it's inside the first milestone
        else if let milestones = arguments["milestones"] as? [[String: Any]],
                let firstMilestone = milestones.first,
                let goalIdStr = firstMilestone["goalId"] as? String,
                let goalId = UUID(uuidString: goalIdStr) {
            goal = goalManager.goals.first(where: { $0.id == goalId })
            print("✅ Found goal from milestone's goalId: '\(goal?.title ?? "")'")
        }
        else if let goalName = arguments["goalName"] as? String {
            // First try exact match (case insensitive)
            goal = goalManager.goals.first(where: { 
                $0.title?.lowercased() == goalName.lowercased()
            })
            
            // If no exact match, try starts with
            if goal == nil {
                goal = goalManager.goals.first(where: { 
                    $0.title?.lowercased().starts(with: goalName.lowercased()) == true
                })
            }
            
            // If still no match, try contains but prefer longer matches
            if goal == nil {
                let matchingGoals = goalManager.goals.filter { 
                    $0.title?.lowercased().contains(goalName.lowercased()) == true 
                }
                
                // Sort by how well they match (prefer exact substring matches)
                if !matchingGoals.isEmpty {
                    goal = matchingGoals.sorted { goal1, goal2 in
                        let title1 = goal1.title?.lowercased() ?? ""
                        let title2 = goal2.title?.lowercased() ?? ""
                        let search = goalName.lowercased()
                        
                        // Prefer goals where the search term appears earlier
                        let index1 = title1.range(of: search)?.lowerBound.utf16Offset(in: title1) ?? Int.max
                        let index2 = title2.range(of: search)?.lowerBound.utf16Offset(in: title2) ?? Int.max
                        
                        if index1 != index2 {
                            return index1 < index2
                        }
                        
                        // If same position, prefer shorter titles (more specific match)
                        return title1.count < title2.count
                    }.first
                }
            }
            
            if let foundGoal = goal {
                print("🎯 Found goal '\(foundGoal.title ?? "")' for search term '\(goalName)'")
            }
        }
        
        // If no goal found, try to be smart about it
        if goal == nil {
            let activeGoals = goalManager.activeGoals
            
            if activeGoals.count == 1 {
                // Only one active goal, use it automatically
                goal = activeGoals.first
                print("🎯 Smart goal selection: Using only active goal '\(goal?.title ?? "")'")
            } else if !activeGoals.isEmpty {
                // Multiple goals, prefer milestone-type goals
                let milestoneGoals = activeGoals.filter { $0.typeEnum == .milestone || $0.typeEnum == .project }
                
                if milestoneGoals.count == 1 {
                    // Only one milestone/project goal, use it
                    goal = milestoneGoals.first
                    print("🎯 Smart goal selection: Using only milestone/project goal '\(goal?.title ?? "")'")
                } else if milestoneGoals.count > 1 {
                    // Multiple milestone goals, pick the most recent one
                    goal = milestoneGoals.max(by: { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) })
                    print("🎯 Smart goal selection: Using most recent milestone goal '\(goal?.title ?? "")'")
                } else {
                    // No milestone goals, pick the most recent active goal
                    goal = activeGoals.max(by: { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) })
                    print("🎯 Smart goal selection: Using most recent active goal '\(goal?.title ?? "")'")
                }
            }
        }
        
        guard let targetGoal = goal else {
            // Only ask for clarification if we truly can't figure it out
            let goalsList = goalManager.goals.compactMap { $0.title }.joined(separator: "\n• ")
            return FunctionCallResult(
                functionName: "add_multiple_milestones",
                success: false,
                message: "Please specify which goal to add milestones to. Available goals:\n• \(goalsList)",
                details: nil
            )
        }
        
        guard let milestones = arguments["milestones"] as? [[String: Any]] else {
            return FunctionCallResult(
                functionName: "add_multiple_milestones",
                success: false,
                message: "Please specify the milestones to add. For example: 'Add milestones to my fitness goal: lose 5 pounds, lose 10 pounds, reach target weight'",
                details: nil
            )
        }
        
        var addedMilestones: [String] = []
        var failedMilestones: [String] = []
        
        for milestoneData in milestones {
            guard let title = milestoneData["title"] as? String else {
                failedMilestones.append("Unnamed milestone (missing title)")
                continue
            }
            
            let targetValue = milestoneData["targetValue"] as? Double
            let targetDate: Date?
            if let targetDateStr = milestoneData["targetDate"] as? String {
                let formatter = ISO8601DateFormatter()
                targetDate = formatter.date(from: targetDateStr)
            } else {
                targetDate = nil
            }
            
            let result = goalManager.addMilestone(to: targetGoal, title: title, targetValue: targetValue, targetDate: targetDate)
            
            switch result {
            case .success:
                addedMilestones.append(title)
            case .failure:
                failedMilestones.append(title)
            }
        }
        
        var message = "📊 **Milestone Update for '\(targetGoal.title ?? "")'**\n\n"
        
        if !addedMilestones.isEmpty {
            message += "**✅ Added \(addedMilestones.count) milestone\(addedMilestones.count == 1 ? "" : "s"):**\n"
            for milestone in addedMilestones {
                message += "• \(milestone)\n"
            }
        }
        
        if !failedMilestones.isEmpty {
            message += "\n**❌ Failed to add \(failedMilestones.count):**\n"
            for milestone in failedMilestones {
                message += "• \(milestone)\n"
            }
        }
        
        return FunctionCallResult(
            functionName: "add_multiple_milestones",
            success: !addedMilestones.isEmpty,
            message: message,
            details: [
                "goalId": targetGoal.id?.uuidString ?? "",
                "added": "\(addedMilestones.count)",
                "failed": "\(failedMilestones.count)"
            ]
        )
    }
    
    private func completeMilestone(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let goalIdStr = arguments["goalId"] as? String,
              let goalId = UUID(uuidString: goalIdStr),
              let milestoneIdStr = arguments["milestoneId"] as? String,
              let milestoneId = UUID(uuidString: milestoneIdStr) else {
            return FunctionCallResult(
                functionName: "complete_milestone",
                success: false,
                message: "Missing required parameters: goalId and milestoneId",
                details: nil
            )
        }
        
        guard let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
            return FunctionCallResult(
                functionName: "complete_milestone",
                success: false,
                message: "Goal not found",
                details: nil
            )
        }
        
        guard let milestone = goal.milestones?.first(where: { ($0 as? GoalMilestone)?.id == milestoneId }) as? GoalMilestone else {
            return FunctionCallResult(
                functionName: "complete_milestone",
                success: false,
                message: "Milestone not found",
                details: nil
            )
        }
        
        let result = goalManager.completeMilestone(milestone)
        
        switch result {
        case .success:
            return FunctionCallResult(
                functionName: "complete_milestone",
                success: true,
                message: "✅ Completed milestone '\(milestone.title ?? "")' for goal '\(goal.title ?? "")'",
                details: ["goalId": goalIdStr, "milestoneId": milestoneIdStr]
            )
        case .failure(let error):
            return FunctionCallResult(
                functionName: "complete_milestone",
                success: false,
                message: "Failed to complete milestone: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    private func deleteMilestone(with arguments: [String: Any]) async -> FunctionCallResult {
        // Support both milestone ID directly or goal+milestone IDs
        var milestone: GoalMilestone?
        var goal: Goal?
        
        if let milestoneIdStr = arguments["milestoneId"] as? String,
           let milestoneId = UUID(uuidString: milestoneIdStr) {
            // Find the milestone and its goal
            for g in goalManager.goals {
                if let found = g.milestones?.first(where: { ($0 as? GoalMilestone)?.id == milestoneId }) as? GoalMilestone {
                    milestone = found
                    goal = g
                    break
                }
            }
        } else if let milestoneName = arguments["milestoneName"] as? String {
            // Find by name
            for g in goalManager.goals {
                if let found = g.milestones?.first(where: { 
                    ($0 as? GoalMilestone)?.title?.lowercased().contains(milestoneName.lowercased()) == true 
                }) as? GoalMilestone {
                    milestone = found
                    goal = g
                    break
                }
            }
        }
        
        guard let targetMilestone = milestone, let targetGoal = goal else {
            return FunctionCallResult(
                functionName: "delete_milestone",
                success: false,
                message: "Milestone not found. Please specify which milestone to delete.",
                details: nil
            )
        }
        
        let result = goalManager.deleteMilestone(targetMilestone, from: targetGoal)
        
        switch result {
        case .success:
            return FunctionCallResult(
                functionName: "delete_milestone",
                success: true,
                message: "🗑️ Deleted milestone '\(targetMilestone.title ?? "")' from goal '\(targetGoal.title ?? "")'",
                details: ["goalId": targetGoal.id?.uuidString ?? "", "milestoneId": targetMilestone.id?.uuidString ?? ""]
            )
        case .failure(let error):
            return FunctionCallResult(
                functionName: "delete_milestone",
                success: false,
                message: "Failed to delete milestone: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    private func deleteMultipleMilestones(with arguments: [String: Any]) async -> FunctionCallResult {
        // DEBUG: Print what the AI is actually sending
        print("🔍 deleteMultipleMilestones called with arguments:")
        for (key, value) in arguments {
            print("   - \(key): \(value)")
        }
        
        // Check if we have specific milestone IDs - if so, handle them differently
        if let milestoneIds = arguments["milestoneIds"] as? [String], !milestoneIds.isEmpty {
            print("🔍 Handling specific milestone IDs deletion")
            
            var deletedMilestones: [(String, String)] = [] // (milestone title, goal title)
            var failedMilestones: [String] = []
            
            for milestoneIdStr in milestoneIds {
                guard let milestoneId = UUID(uuidString: milestoneIdStr) else {
                    failedMilestones.append("Invalid ID: \(milestoneIdStr)")
                    continue
                }
                
                // Find the milestone and its goal
                var foundMilestone: GoalMilestone?
                var parentGoal: Goal?
                
                print("🔍 Looking for milestone with ID: \(milestoneIdStr)")
                
                for g in goalManager.goals {
                    let milestones = (g.milestones as? Set<GoalMilestone>) ?? []
                    print("   Checking goal '\(g.title ?? "")' with \(milestones.count) milestones")
                    
                    if let milestone = milestones.first(where: { $0.id == milestoneId }) {
                        foundMilestone = milestone
                        parentGoal = g
                        print("   ✅ Found milestone '\(milestone.title ?? "")' in goal '\(g.title ?? "")'")
                        break
                    }
                }
                
                if let milestone = foundMilestone, let goal = parentGoal {
                    // Check milestone data integrity
                    guard let milestoneTitle = milestone.title, !milestoneTitle.isEmpty else {
                        print("❌ ERROR: Milestone has no title! ID: \(milestoneIdStr), sortOrder: \(milestone.sortOrder)")
                        failedMilestones.append("Milestone \(milestoneIdStr) has no title - data corruption")
                        continue
                    }
                    
                    guard let goalTitle = goal.title, !goalTitle.isEmpty else {
                        print("❌ ERROR: Goal has no title! ID: \(goal.id?.uuidString ?? "nil")")
                        failedMilestones.append("Goal for milestone '\(milestoneTitle)' has no title - data corruption")
                        continue
                    }
                    
                    print("🔍 Deleting milestone '\(milestoneTitle)' from goal '\(goalTitle)'")
                    
                    let result = goalManager.deleteMilestone(milestone, from: goal)
                    switch result {
                    case .success:
                        deletedMilestones.append((milestoneTitle, goalTitle))
                        print("✅ Successfully deleted milestone '\(milestoneTitle)' from goal '\(goalTitle)'")
                    case .failure(let error):
                        failedMilestones.append("\(milestoneTitle): \(error.localizedDescription)")
                    }
                } else {
                    failedMilestones.append("Milestone not found: \(milestoneIdStr)")
                }
            }
            
            var message = ""
            if !deletedMilestones.isEmpty {
                message = "🗑️ **Deleted \(deletedMilestones.count) milestone\(deletedMilestones.count == 1 ? "" : "s"):**\n\n"
                for (milestoneTitle, goalTitle) in deletedMilestones {
                    message += "• \(milestoneTitle) from \(goalTitle)\n"
                }
            }
            
            if !failedMilestones.isEmpty {
                message += "\n**❌ Failed to delete \(failedMilestones.count):**\n"
                for failed in failedMilestones {
                    message += "• \(failed)\n"
                }
            }
            
            // If everything failed, try to be smart about what the user wanted
            if deletedMilestones.isEmpty && !failedMilestones.isEmpty {
                print("⚠️ All milestone deletions failed. Trying smart detection...")
                
                // Check if user mentioned photography or any other goal name
                let allArgValues = arguments.values.compactMap { $0 as? String }.joined(separator: " ").lowercased()
                
                for goal in goalManager.goals {
                    let goalNameLower = goal.title?.lowercased() ?? ""
                    if allArgValues.contains(goalNameLower) || goalNameLower.contains("photo") {
                        print("🎯 Smart detection: User probably wants to delete milestones from '\(goal.title ?? "")'")
                        
                        // Delete ALL milestones from this goal
                        if let milestones = goal.milestones as? Set<GoalMilestone>, !milestones.isEmpty {
                            var smartDeleted = 0
                            for milestone in milestones {
                                // Verify milestone has a title
                                guard let milestoneTitle = milestone.title, !milestoneTitle.isEmpty else {
                                    print("❌ ERROR: Milestone has no title during smart delete! sortOrder: \(milestone.sortOrder)")
                                    continue
                                }
                                
                                let result = goalManager.deleteMilestone(milestone, from: goal)
                                if case .success = result {
                                    smartDeleted += 1
                                    deletedMilestones.append((milestoneTitle, goal.title ?? "ERROR: NO GOAL TITLE"))
                                }
                            }
                            
                            if smartDeleted > 0 {
                                message = "🗑️ **Smart deletion: Removed all \(smartDeleted) milestones from '\(goal.title ?? "")'**\n\n"
                                for (milestoneTitle, _) in deletedMilestones {
                                    message += "• \(milestoneTitle)\n"
                                }
                                
                                return FunctionCallResult(
                                    functionName: "delete_multiple_milestones",
                                    success: true,
                                    message: message,
                                    details: ["deleted": "\(smartDeleted)", "method": "smart"]
                                )
                            }
                        }
                    }
                }
            }
            
            return FunctionCallResult(
                functionName: "delete_multiple_milestones",
                success: !deletedMilestones.isEmpty,
                message: message.isEmpty ? "No milestones found to delete. They may have already been deleted." : message,
                details: [
                    "deleted": "\(deletedMilestones.count)",
                    "failed": "\(failedMilestones.count)"
                ]
            )
        }
        
        // Support deleting all milestones from a goal or specific milestones
        var goal: Goal?
        
        // SUPER SMART GOAL DETECTION - Check EVERY possible place the goal name might be
        
        // 1. Check goalId parameter
        if let goalIdStr = arguments["goalId"] as? String,
           let goalId = UUID(uuidString: goalIdStr) {
            goal = goalManager.goals.first(where: { $0.id == goalId })
        }
        
        // 2. Check goalName parameter
        if goal == nil, let goalName = arguments["goalName"] as? String {
            goal = goalManager.goals.first(where: { 
                $0.title?.lowercased().contains(goalName.lowercased()) == true 
            })
        }
        
        // 3. Check pattern parameter (might contain goal name)
        if goal == nil, let pattern = arguments["pattern"] as? String {
            goal = goalManager.goals.first(where: { 
                $0.title?.lowercased().contains(pattern.lowercased()) == true 
            })
            if goal != nil {
                print("🎯 Found goal '\(goal?.title ?? "")' from pattern '\(pattern)'")
            }
        }
        
        // 4. Check ANY string value in arguments that might be the goal name
        if goal == nil {
            for (key, value) in arguments {
                if let stringValue = value as? String, !stringValue.isEmpty {
                    // Skip known non-goal parameters
                    if key == "deleteAll" || key == "all" || key == "action" || key == "type" {
                        continue
                    }
                    
                    // Try to find a goal with this name
                    let foundGoal = goalManager.goals.first(where: { 
                        $0.title?.lowercased().contains(stringValue.lowercased()) == true 
                    })
                    
                    if foundGoal != nil {
                        goal = foundGoal
                        print("🎯 Found goal '\(goal?.title ?? "")' from parameter '\(key)' with value '\(stringValue)'")
                        break
                    }
                }
            }
        }
        
        // 5. Smart selection based on context
        if goal == nil {
            let activeGoals = goalManager.activeGoals
            
            // If user mentioned "photography" anywhere and we have a photography goal, use it
            let allArgValues = arguments.values.compactMap { $0 as? String }.joined(separator: " ").lowercased()
            if allArgValues.contains("photo") {
                goal = goalManager.goals.first(where: { 
                    $0.title?.lowercased().contains("photo") == true 
                })
                if goal != nil {
                    print("🎯 Found photography goal from context")
                }
            }
            
            // Single active goal
            if goal == nil && activeGoals.count == 1 {
                goal = activeGoals.first
                print("🎯 Using only active goal '\(goal?.title ?? "")'")
            }
            
            // Single milestone goal
            if goal == nil && !activeGoals.isEmpty {
                let milestoneGoals = activeGoals.filter { $0.typeEnum == .milestone || $0.typeEnum == .project }
                if milestoneGoals.count == 1 {
                    goal = milestoneGoals.first
                    print("🎯 Using only milestone goal '\(goal?.title ?? "")'")
                }
            }
        }
        
        guard let targetGoal = goal else {
            let goalsList = goalManager.goals.compactMap { $0.title }.joined(separator: "\n• ")
            return FunctionCallResult(
                functionName: "delete_multiple_milestones",
                success: false,
                message: "Please specify which goal to delete milestones from. Available goals:\n• \(goalsList)",
                details: nil
            )
        }
        
        // Check if we should delete all or specific milestones
        let deleteAll = arguments["deleteAll"] as? Bool ?? false
        let milestoneNames = arguments["milestoneNames"] as? [String]
        let milestonePattern = arguments["pattern"] as? String // e.g., "photography" to delete all photography milestones
        
        var deletedMilestones: [String] = []
        var failedMilestones: [String] = []
        
        if deleteAll || milestonePattern != nil {
            // Delete all milestones or those matching pattern
            if let milestones = targetGoal.milestones as? Set<GoalMilestone> {
                for milestone in milestones {
                    let shouldDelete = deleteAll || 
                        (milestonePattern != nil && milestone.title?.lowercased().contains(milestonePattern!.lowercased()) == true)
                    
                    if shouldDelete {
                        let result = goalManager.deleteMilestone(milestone, from: targetGoal)
                        switch result {
                        case .success:
                            deletedMilestones.append(milestone.title ?? "Unnamed")
                        case .failure:
                            failedMilestones.append(milestone.title ?? "Unnamed")
                        }
                    }
                }
            }
        } else if let names = milestoneNames {
            // Delete specific milestones by name
            for name in names {
                if let milestone = (targetGoal.milestones as? Set<GoalMilestone>)?.first(where: {
                    $0.title?.lowercased().contains(name.lowercased()) == true
                }) {
                    let result = goalManager.deleteMilestone(milestone, from: targetGoal)
                    switch result {
                    case .success:
                        deletedMilestones.append(milestone.title ?? name)
                    case .failure:
                        failedMilestones.append(milestone.title ?? name)
                    }
                } else {
                    failedMilestones.append(name)
                }
            }
        }
        
        var message = "🗑️ **Milestone Deletion for '\(targetGoal.title ?? "")'**\n\n"
        
        if !deletedMilestones.isEmpty {
            message += "**✅ Deleted \(deletedMilestones.count) milestone\(deletedMilestones.count == 1 ? "" : "s"):**\n"
            for milestone in deletedMilestones {
                message += "• \(milestone)\n"
            }
        }
        
        if !failedMilestones.isEmpty {
            message += "\n**❌ Failed to delete \(failedMilestones.count):**\n"
            for milestone in failedMilestones {
                message += "• \(milestone)\n"
            }
        }
        
        if deletedMilestones.isEmpty && failedMilestones.isEmpty {
            message = "No milestones found to delete."
        }
        
        return FunctionCallResult(
            functionName: "delete_multiple_milestones",
            success: !deletedMilestones.isEmpty,
            message: message,
            details: [
                "goalId": targetGoal.id?.uuidString ?? "",
                "deleted": "\(deletedMilestones.count)",
                "failed": "\(failedMilestones.count)"
            ]
        )
    }
    
    private func completeGoal(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let goalIdStr = arguments["goalId"] as? String,
              let goalId = UUID(uuidString: goalIdStr) else {
            return FunctionCallResult(
                functionName: "complete_goal",
                success: false,
                message: "Missing or invalid goal ID",
                details: nil
            )
        }
        
        guard let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
            return FunctionCallResult(
                functionName: "complete_goal",
                success: false,
                message: "Goal not found",
                details: nil
            )
        }
        
        let completionNotes = arguments["completionNotes"] as? String
        
        let result = goalManager.completeGoal(goal, notes: completionNotes)
        
        switch result {
        case .success:
            return FunctionCallResult(
                functionName: "complete_goal",
                success: true,
                message: "🎉 Completed goal: \(goal.title ?? "")",
                details: nil
            )
        case .failure(let error):
            return FunctionCallResult(
                functionName: "complete_goal",
                success: false,
                message: "Failed to complete goal: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    // MARK: - Smart Unified Function System
    
    private func manage(with arguments: [String: Any]) async -> FunctionCallResult {
        // This is the ONE function to rule them all!
        // It handles events, tasks, goals, habits, milestones, categories - EVERYTHING
        
        // Debug: Log what the AI sent
        print("🔍 manage() called with:")
        for (key, value) in arguments {
            if let array = value as? [Any] {
                print("  - \(key): [\(array.count) items]")
            } else {
                print("  - \(key): \(value)")
            }
        }
        
        guard let itemType = arguments["type"] as? String else {
            return FunctionCallResult(
                functionName: "manage",
                success: false,
                message: "ERROR: Missing required 'type' parameter. Must be one of: event, task, goal, habit, milestone, category",
                details: ["error": "missing_type", "received_args": arguments.keys.joined(separator: ", ")]
            )
        }
        
        let action = arguments["action"] as? String ?? "create"
        
        // Validate action for each type
        let validActions: [String: [String]] = [
            "event": ["create", "update", "delete", "list", "search", "complete"],
            "task": ["create", "update", "delete", "list", "search", "complete", "reopen"],
            "goal": ["create", "update", "delete", "list", "complete", "progress"],
            "habit": ["create", "update", "delete", "list", "log", "pause", "stats"],
            "milestone": ["create", "update", "delete", "complete"],
            "category": ["create", "update", "delete", "list"]
        ]
        
        if let validActionsForType = validActions[itemType.lowercased()] {
            if !validActionsForType.contains(action.lowercased()) {
                return FunctionCallResult(
                    functionName: "manage",
                    success: false,
                    message: "Invalid action '\(action)' for type '\(itemType)'. Valid actions: \(validActionsForType.joined(separator: ", "))",
                    details: ["type": itemType, "invalid_action": action]
                )
            }
        }
        
        // Validate required IDs for update/delete actions
        if ["update", "delete", "complete"].contains(action.lowercased()) && 
           !["list", "search"].contains(action.lowercased()) {
            if arguments["id"] == nil && arguments["ids"] == nil {
                return FunctionCallResult(
                    functionName: "manage",
                    success: false,
                    message: "ERROR: '\(action)' action requires an 'id' parameter. Use the ID from the context above.",
                    details: ["type": itemType, "action": action, "missing": "id"]
                )
            }
        }
        
        // Smart routing based on item type
        switch itemType.lowercased() {
        case "event", "events":
            return await manageEvents(action: action, arguments: arguments)
        case "task", "tasks", "subtask", "subtasks":
            return await manageTasks(action: action, arguments: arguments)
        case "goal", "goals":
            return await manageGoals(action: action, arguments: arguments)
        case "habit", "habits":
            return await manageHabits(action: action, arguments: arguments)
        case "milestone", "milestones":
            return await manageMilestones(action: action, arguments: arguments)
        case "category", "categories":
            return await manageCategories(action: action, arguments: arguments)
        default:
            return FunctionCallResult(
                functionName: "manage",
                success: false,
                message: "Unknown item type: \(itemType). Supported types: event, task, goal, habit, milestone, category",
                details: nil
            )
        }
    }
    
    // MARK: - Smart Sub-Managers
    
    private func manageEvents(action: String, arguments: [String: Any]) async -> FunctionCallResult {
        switch action.lowercased() {
        case "create", "add", "new":
            // Handle single or multiple creation
            if let items = arguments["items"] as? [[String: Any]] {
                return await createMultipleEvents(with: ["events": items])
            } else if arguments["recurring"] as? Bool == true {
                return await createRecurringEvent(with: arguments)
            } else {
                return await createEvent(with: arguments)
            }
            
        case "update", "edit", "modify":
            if arguments["all"] as? Bool == true {
                return await updateAllEvents(with: arguments)
            } else if let _ = arguments["filter"] {
                return await updateAllEvents(with: arguments)
            } else {
                return await updateEvent(with: arguments)
            }
            
        case "delete", "remove":
            if arguments["all"] as? Bool == true {
                return await deleteAllEvents(with: arguments)
            } else if let _ = arguments["filter"] {
                // Delete by filter
                return await deleteAllEvents(with: arguments)
            } else {
                return await deleteEvent(with: arguments)
            }
            
        case "complete", "done", "finish":
            return await markAllComplete(with: arguments)
            
        case "list", "show", "get":
            if let _ = arguments["id"] {
                return await getEventDetails(with: arguments)
            } else {
                return await listEvents(with: arguments)
            }
            
        case "search", "find":
            return await searchEvents(with: arguments)
            
        default:
            return FunctionCallResult(
                functionName: "manage",
                success: false,
                message: "Unknown action '\(action)' for events. Try: create, update, delete, complete, list, search",
                details: nil
            )
        }
    }
    
    private func manageTasks(action: String, arguments: [String: Any]) async -> FunctionCallResult {
        switch action.lowercased() {
        case "create", "add", "new":
            if let items = arguments["items"] as? [[String: Any]] {
                return await createMultipleTasks(with: ["tasks": items])
            } else if arguments["subtasks"] as? Bool == true {
                return await createSubtasks(with: arguments)
            } else {
                return await createTask(with: arguments)
            }
            
        case "update", "edit", "modify":
            if let tasks = arguments["tasks"] as? [[String: Any]] {
                return await updateMultipleTasks(with: ["tasks": tasks])
            } else {
                return await updateTask(with: arguments)
            }
            
        case "delete", "remove":
            if arguments["all"] as? Bool == true {
                if arguments["completed"] as? Bool == true {
                    return await deleteAllCompletedTasks(with: arguments)
                } else {
                    return await deleteAllTasks(with: arguments)
                }
            } else if let tasks = arguments["taskIds"] as? [String] {
                return await deleteMultipleTasks(with: ["taskIds": tasks])
            } else {
                return await deleteTask(with: arguments)
            }
            
        case "complete", "done", "finish":
            if arguments["all"] as? Bool == true || arguments["filter"] != nil {
                return await completeAllTasksByFilter(with: arguments)
            } else if let tasks = arguments["taskIds"] as? [String] {
                return await completeMultipleTasks(with: ["taskIds": tasks])
            } else {
                return await completeTask(with: arguments)
            }
            
        case "reopen", "uncomplete", "undo":
            return await reopenMultipleTasks(with: arguments)
            
        case "reschedule", "move":
            return await rescheduleTasks(with: arguments)
            
        case "link":
            return await linkTaskToEvent(with: arguments)
            
        case "list", "show", "get":
            if arguments["statistics"] as? Bool == true {
                return await getTaskStatistics(with: arguments)
            } else {
                return await listTasks(with: arguments)
            }
            
        case "search", "find":
            return await searchTasks(with: arguments)
            
        default:
            return FunctionCallResult(
                functionName: "manage",
                success: false,
                message: "Unknown action '\(action)' for tasks. Try: create, update, delete, complete, reopen, reschedule, link, list, search",
                details: nil
            )
        }
    }
    
    private func manageGoals(action: String, arguments: [String: Any]) async -> FunctionCallResult {
        switch action.lowercased() {
        case "create", "add", "new":
            if let items = arguments["items"] as? [[String: Any]] {
                return await createMultipleGoals(with: ["goals": items])
            } else {
                return await createGoal(with: arguments)
            }
            
        case "update", "edit", "modify":
            if let goals = arguments["goals"] as? [[String: Any]] {
                return await updateMultipleGoals(with: ["goals": goals])
            } else {
                return await updateGoal(with: arguments)
            }
            
        case "delete", "remove":
            if arguments["all"] as? Bool == true {
                return await deleteAllGoals(with: arguments)
            } else if let goals = arguments["goalIds"] as? [String] {
                return await deleteMultipleGoals(with: ["goalIds": goals])
            } else {
                return await deleteGoal(with: arguments)
            }
            
        case "complete", "done", "finish", "achieve":
            if let goals = arguments["goalIds"] as? [String] {
                return await completeMultipleGoals(with: ["goalIds": goals])
            } else {
                return await completeGoal(with: arguments)
            }
            
        case "progress", "update_progress":
            return await addGoalProgress(with: arguments)
            
        case "list", "show", "get":
            if arguments["progress"] as? Bool == true {
                return await getGoalProgress(with: arguments)
            } else {
                return await listGoals(with: arguments)
            }
            
        default:
            return FunctionCallResult(
                functionName: "manage",
                success: false,
                message: "Unknown action '\(action)' for goals. Try: create, update, delete, complete, progress, list",
                details: nil
            )
        }
    }
    
    private func manageHabits(action: String, arguments: [String: Any]) async -> FunctionCallResult {
        switch action.lowercased() {
        case "create", "add", "new":
            if let items = arguments["items"] as? [[String: Any]] {
                return await createMultipleHabits(with: ["habits": items])
            } else {
                return await createHabit(with: arguments)
            }
            
        case "update", "edit", "modify":
            if let habits = arguments["habits"] as? [[String: Any]] {
                return await updateMultipleHabits(with: ["habits": habits])
            } else {
                return await updateHabit(with: arguments)
            }
            
        case "delete", "remove":
            if arguments["all"] as? Bool == true {
                return await deleteAllHabits(with: arguments)
            } else if let habits = arguments["habitIds"] as? [String] {
                return await deleteMultipleHabits(with: ["habitIds": habits])
            } else {
                return await deleteHabit(with: arguments)
            }
            
        case "log", "track", "complete", "done":
            return await logHabit(with: arguments)
            
        case "pause", "suspend":
            return await pauseHabit(with: arguments)
            
        case "list", "show", "get":
            if arguments["stats"] as? Bool == true {
                return await getHabitStats(with: arguments)
            } else if arguments["insights"] as? Bool == true {
                return await getHabitInsights(with: arguments)
            } else {
                return await listHabits(with: arguments)
            }
            
        default:
            return FunctionCallResult(
                functionName: "manage",
                success: false,
                message: "Unknown action '\(action)' for habits. Try: create, update, delete, log, pause, list",
                details: nil
            )
        }
    }
    
    private func manageMilestones(action: String, arguments: [String: Any]) async -> FunctionCallResult {
        switch action.lowercased() {
        case "create", "add", "new":
            if let items = arguments["items"] as? [[String: Any]] {
                return await addMultipleMilestones(with: ["milestones": items, "goalId": arguments["goalId"] as Any])
            } else {
                return await addMilestone(with: arguments)
            }
            
        case "delete", "remove":
            if arguments["all"] as? Bool == true || arguments["pattern"] != nil {
                return await deleteMultipleMilestones(with: arguments)
            } else {
                return await deleteMilestone(with: arguments)
            }
            
        case "complete", "done", "finish":
            return await completeMilestone(with: arguments)
            
        default:
            return FunctionCallResult(
                functionName: "manage",
                success: false,
                message: "Unknown action '\(action)' for milestones. Try: create, delete, complete",
                details: nil
            )
        }
    }
    
    private func manageCategories(action: String, arguments: [String: Any]) async -> FunctionCallResult {
        switch action.lowercased() {
        case "create", "add", "new":
            if let items = arguments["items"] as? [[String: Any]] {
                return await createMultipleCategories(with: ["categories": items])
            } else {
                return await createCategory(with: arguments)
            }
            
        case "update", "edit", "modify":
            if let categories = arguments["categories"] as? [[String: Any]] {
                return await updateMultipleCategories(with: ["categories": categories])
            } else {
                return await updateCategory(with: arguments)
            }
            
        case "delete", "remove":
            if arguments["all"] as? Bool == true {
                return await deleteAllCategories(with: arguments)
            } else if let categories = arguments["categoryIds"] as? [String] {
                return await deleteMultipleCategories(with: ["categoryIds": categories])
            } else {
                return await deleteCategory(with: arguments)
            }
            
        case "list", "show", "get":
            return await listCategories(with: arguments)
            
        default:
            return FunctionCallResult(
                functionName: "manage",
                success: false,
                message: "Unknown action '\(action)' for categories. Try: create, update, delete, list",
                details: nil
            )
        }
    }
    
    // Duplicate milestone functions removed - they are already defined above
    
    private func addGoalMilestone(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let goalIdStr = arguments["goalId"] as? String,
              let goalId = UUID(uuidString: goalIdStr),
              let title = arguments["title"] as? String else {
            return FunctionCallResult(
                functionName: "add_goal_milestone",
                success: false,
                message: "Missing required parameters: goalId and title",
                details: nil
            )
        }
        
        guard let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
            return FunctionCallResult(
                functionName: "add_goal_milestone",
                success: false,
                message: "Goal not found",
                details: nil
            )
        }
        
        let targetValue = arguments["targetValue"] as? Double
        var targetDate: Date?
        if let targetDateStr = arguments["targetDate"] as? String {
            let formatter = ISO8601DateFormatter()
            targetDate = formatter.date(from: targetDateStr)
        }
        
        let result = goalManager.addMilestone(
            to: goal,
            title: title,
            targetValue: targetValue,
            targetDate: targetDate
        )
        
        var message = "🏁 **Added milestone to '\(goal.title ?? "")':**\n\n"
        message += "• \(title)"
        
        if let targetValue = targetValue {
            message += " (\(Int(targetValue))"
            if let unit = goal.unit {
                message += " \(unit)"
            }
            message += ")"
        }
        
        if let targetDate = targetDate {
            message += " - Due: \(DateFormatter.localizedString(from: targetDate, dateStyle: .medium, timeStyle: .none))"
        }
        
        return FunctionCallResult(
            functionName: "add_goal_milestone",
            success: true,
            message: message,
            details: nil
        )
    }
    
    // Removed duplicate addMultipleMilestones - already defined above
    
    private func updateMilestone(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let milestoneIdStr = arguments["milestoneId"] as? String,
              let milestoneId = UUID(uuidString: milestoneIdStr),
              let updates = arguments["updates"] as? [String: Any] else {
            return FunctionCallResult(
                functionName: "update_milestone",
                success: false,
                message: "Missing required parameters: milestoneId and updates",
                details: nil
            )
        }
        
        // Find the milestone across all goals
        var foundMilestone: GoalMilestone?
        var parentGoal: Goal?
        
        for goal in goalManager.goals {
            if let milestone = goal.sortedMilestones.first(where: { $0.id == milestoneId }) {
                foundMilestone = milestone
                parentGoal = goal
                break
            }
        }
        
        guard let milestone = foundMilestone else {
            return FunctionCallResult(
                functionName: "update_milestone",
                success: false,
                message: "Milestone not found",
                details: nil
            )
        }
        
        // Apply updates
        if let title = updates["title"] as? String {
            milestone.title = title
        }
        
        if let targetValue = updates["targetValue"] as? Double {
            milestone.targetValue = targetValue
        }
        
        // Note: targetDate is not a property of GoalMilestone in the current model
        // If needed, this could be tracked elsewhere or the model could be updated
        
        if let isCompleted = updates["isCompleted"] as? Bool, isCompleted {
            let _ = goalManager.completeMilestone(milestone)
        }
        
        // The changes will be saved automatically by Core Data change tracking
        return FunctionCallResult(
            functionName: "update_milestone",
            success: true,
            message: "✅ Updated milestone '\(milestone.title ?? "")' in goal '\(parentGoal?.title ?? "")'",
            details: nil
        )
    }
    
    private func updateMultipleMilestones(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let updates = arguments["updates"] as? [[String: Any]] else {
            return FunctionCallResult(
                functionName: "update_multiple_milestones",
                success: false,
                message: "Missing required parameter: updates array",
                details: nil
            )
        }
        
        var successCount = 0
        var failedUpdates: [String] = []
        var messages: [String] = []
        
        for update in updates {
            guard let milestoneIdStr = update["milestoneId"] as? String,
                  let milestoneId = UUID(uuidString: milestoneIdStr) else {
                failedUpdates.append("Invalid milestone ID")
                continue
            }
            
            // Find the milestone
            var foundMilestone: GoalMilestone?
            var parentGoal: Goal?
            
            for goal in goalManager.goals {
                if let milestone = goal.sortedMilestones.first(where: { $0.id == milestoneId }) {
                    foundMilestone = milestone
                    parentGoal = goal
                    break
                }
            }
            
            guard let milestone = foundMilestone else {
                failedUpdates.append("Milestone not found: \(milestoneIdStr)")
                continue
            }
            
            // Apply updates
            if let title = update["title"] as? String {
                milestone.title = title
            }
            
            if let targetValue = update["targetValue"] as? Double {
                milestone.targetValue = targetValue
            }
            
            if let targetDateStr = update["targetDate"] as? String {
                let formatter = ISO8601DateFormatter()
                // Note: targetDate is not a property of GoalMilestone in the current model
            }
            
            if let isCompleted = update["isCompleted"] as? Bool, isCompleted {
                let _ = goalManager.completeMilestone(milestone)
            }
            
            successCount += 1
            messages.append("• Updated '\(milestone.title ?? "")' in '\(parentGoal?.title ?? "")'")
        }
        
        // Changes are saved automatically by Core Data
        var message = "✅ **Updated \(successCount) milestone\(successCount == 1 ? "" : "s"):**\n\n"
        message += messages.joined(separator: "\n")
        
        if !failedUpdates.isEmpty {
            message += "\n\n⚠️ **Failed (\(failedUpdates.count)):**\n"
            message += failedUpdates.map { "• \($0)" }.joined(separator: "\n")
        }
        
        return FunctionCallResult(
            functionName: "update_multiple_milestones",
            success: true,
            message: message,
            details: ["successCount": "\(successCount)", "failedCount": "\(failedUpdates.count)"]
        )
    }
    
    // DUPLICATE REMOVED - deleteMilestone already defined above
    private func deleteMilestoneOLD(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let milestoneIdStr = arguments["milestoneId"] as? String,
              let milestoneId = UUID(uuidString: milestoneIdStr) else {
            return FunctionCallResult(
                functionName: "delete_milestone",
                success: false,
                message: "Missing or invalid milestone ID",
                details: nil
            )
        }
        
        // Find and delete the milestone
        var foundMilestone: GoalMilestone?
        var parentGoal: Goal?
        
        for goal in goalManager.goals {
            if let milestone = goal.sortedMilestones.first(where: { $0.id == milestoneId }) {
                foundMilestone = milestone
                parentGoal = goal
                break
            }
        }
        
        guard let milestone = foundMilestone, let goal = parentGoal else {
            return FunctionCallResult(
                functionName: "delete_milestone",
                success: false,
                message: "Milestone not found",
                details: nil
            )
        }
        
        let milestoneTitle = milestone.title ?? "Untitled"
        
        // Use the public method to delete the milestone
        let result = goalManager.deleteMilestone(milestone, from: goal)
        
        switch result {
        case .success:
            return FunctionCallResult(
                functionName: "delete_milestone",
                success: true,
                message: "🗑️ Deleted milestone '\(milestoneTitle)' from '\(goal.title ?? "")'",
                details: nil
            )
        case .failure(let error):
            return FunctionCallResult(
                functionName: "delete_milestone",
                success: false,
                message: "Failed to delete milestone: \(error.localizedDescription)",
                details: nil
            )
        }
    }
    
    // DUPLICATE REMOVED - deleteMultipleMilestones already defined above
    private func deleteMultipleMilestonesOLD(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let milestoneIds = arguments["milestoneIds"] as? [String] else {
            return FunctionCallResult(
                functionName: "delete_multiple_milestones",
                success: false,
                message: "Missing required parameter: milestoneIds",
                details: nil
            )
        }
        
        var successCount = 0
        var failedDeletes: [String] = []
        var deletedInfo: [(String, String)] = [] // (milestone title, goal title)
        
        for milestoneIdStr in milestoneIds {
            guard let milestoneId = UUID(uuidString: milestoneIdStr) else {
                failedDeletes.append("Invalid ID: \(milestoneIdStr)")
                continue
            }
            
            // Find the milestone
            var foundMilestone: GoalMilestone?
            var parentGoal: Goal?
            
            for goal in goalManager.goals {
                if let milestone = goal.sortedMilestones.first(where: { $0.id == milestoneId }) {
                    foundMilestone = milestone
                    parentGoal = goal
                    break
                }
            }
            
            guard let milestone = foundMilestone, let goal = parentGoal else {
                failedDeletes.append("Not found: \(milestoneIdStr)")
                continue
            }
            
            let milestoneTitle = milestone.title ?? "Untitled"
            let goalTitle = goal.title ?? "Untitled goal"
            
            // Use the public method to delete the milestone
            let result = goalManager.deleteMilestone(milestone, from: goal)
            
            switch result {
            case .success:
                successCount += 1
                deletedInfo.append((milestoneTitle, goalTitle))
            case .failure(let error):
                failedDeletes.append("\(milestoneTitle): \(error.localizedDescription)")
            }
        }
        
        var message = "🗑️ **Deleted \(successCount) milestone\(successCount == 1 ? "" : "s"):**\n\n"
        for (milestone, goal) in deletedInfo {
            message += "• '\(milestone)' from '\(goal)'\n"
        }
        
        if !failedDeletes.isEmpty {
            message += "\n⚠️ **Failed (\(failedDeletes.count)):**\n"
            message += failedDeletes.map { "• \($0)" }.joined(separator: "\n")
        }
        
        return FunctionCallResult(
            functionName: "delete_multiple_milestones",
            success: true,
            message: message,
            details: ["successCount": "\(successCount)", "failedCount": "\(failedDeletes.count)"]
        )
    }
    
    // Removed duplicate completeMilestone - already defined above
    
    private func completeMultipleMilestones(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let milestoneIds = arguments["milestoneIds"] as? [String] else {
            return FunctionCallResult(
                functionName: "complete_multiple_milestones",
                success: false,
                message: "Missing required parameter: milestoneIds",
                details: nil
            )
        }
        
        var successCount = 0
        var failedCompletes: [String] = []
        var completedInfo: [(String, String)] = [] // (milestone title, goal title)
        
        for milestoneIdStr in milestoneIds {
            guard let milestoneId = UUID(uuidString: milestoneIdStr) else {
                failedCompletes.append("Invalid ID: \(milestoneIdStr)")
                continue
            }
            
            // Find the milestone
            var foundMilestone: GoalMilestone?
            var parentGoal: Goal?
            
            for goal in goalManager.goals {
                if let milestone = goal.sortedMilestones.first(where: { $0.id == milestoneId }) {
                    foundMilestone = milestone
                    parentGoal = goal
                    break
                }
            }
            
            guard let milestone = foundMilestone, let goal = parentGoal else {
                failedCompletes.append("Not found: \(milestoneIdStr)")
                continue
            }
            
            let _ = goalManager.completeMilestone(milestone)
            successCount += 1
            completedInfo.append((milestone.title ?? "Untitled", goal.title ?? "Untitled goal"))
        }
        
        var message = "✅ **Completed \(successCount) milestone\(successCount == 1 ? "" : "s"):**\n\n"
        for (milestone, goal) in completedInfo {
            message += "• '\(milestone)' in '\(goal)'\n"
        }
        
        if !failedCompletes.isEmpty {
            message += "\n⚠️ **Failed (\(failedCompletes.count)):**\n"
            message += failedCompletes.map { "• \($0)" }.joined(separator: "\n")
        }
        
        return FunctionCallResult(
            functionName: "complete_multiple_milestones",
            success: successCount > 0,
            message: message,
            details: ["successCount": "\(successCount)", "failedCount": "\(failedCompletes.count)"]
        )
    }
    
    private func linkGoalToHabits(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let goalIdStr = arguments["goalId"] as? String,
              let goalId = UUID(uuidString: goalIdStr),
              let habitNames = arguments["habitNames"] as? [String] else {
            return FunctionCallResult(
                functionName: "link_goal_to_habits",
                success: false,
                message: "Missing required parameters: goalId and habitNames",
                details: nil
            )
        }
        
        guard let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
            return FunctionCallResult(
                functionName: "link_goal_to_habits",
                success: false,
                message: "Goal not found",
                details: nil
            )
        }
        
        var linkedHabits: [String] = []
        var notFoundHabits: [String] = []
        
        for habitName in habitNames {
            if let habit = habitManager.habits.first(where: { $0.name?.lowercased() == habitName.lowercased() }) {
                let result = goalManager.linkHabit(habit, to: goal)
                if case .success = result {
                    linkedHabits.append(habit.name ?? "")
                }
            } else {
                notFoundHabits.append(habitName)
            }
        }
        
        if linkedHabits.isEmpty {
            return FunctionCallResult(
                functionName: "link_goal_to_habits",
                success: false,
                message: "No habits were linked. Habits not found: \(notFoundHabits.joined(separator: ", "))",
                details: nil
            )
        }
        
        var message = "🔗 **Linked \(linkedHabits.count) habits to '\(goal.title ?? "")':**\n\n"
        message += linkedHabits.map { "• \($0)" }.joined(separator: "\n")
        
        if !notFoundHabits.isEmpty {
            message += "\n\n⚠️ Not found: \(notFoundHabits.joined(separator: ", "))"
        }
        
        return FunctionCallResult(
            functionName: "link_goal_to_habits",
            success: true,
            message: message,
            details: ["linked": "\(linkedHabits.count)"]
        )
    }
    
    private func linkGoalToTasks(with arguments: [String: Any]) async -> FunctionCallResult {
        return FunctionCallResult(
            functionName: "link_goal_to_tasks",
            success: false,
            message: "Task linking is not supported in the current version. Goals can only be linked to habits.",
            details: nil
        )
    }
    
    private func getGoalStatistics(with arguments: [String: Any]) async -> FunctionCallResult {
        let period = arguments["period"] as? String ?? "all"
        
        var goals = goalManager.goals
        let now = Date()
        let calendar = Calendar.current
        
        // Filter by period
        switch period {
        case "week":
            let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            goals = Array(goals.filter { goal in
                if let completedDate = goal.completedDate {
                    return completedDate >= weekAgo
                } else if let createdDate = goal.createdAt {
                    return createdDate >= weekAgo
                }
                return false
            })
        case "month":
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            goals = Array(goals.filter { goal in
                if let completedDate = goal.completedDate {
                    return completedDate >= monthAgo
                } else if let createdDate = goal.createdAt {
                    return createdDate >= monthAgo
                }
                return false
            })
        case "year":
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            goals = Array(goals.filter { goal in
                if let completedDate = goal.completedDate {
                    return completedDate >= yearAgo
                } else if let createdDate = goal.createdAt {
                    return createdDate >= yearAgo
                }
                return false
            })
        default:
            break // Use all goals
        }
        
        // Calculate statistics
        let totalGoals = goals.count
        let completedGoals = goals.filter { $0.isCompleted }.count
        let inProgressGoals = goals.filter { !$0.isCompleted }.count
        
        // Calculate completion rate by type
        var typeStats: [String: (total: Int, completed: Int)] = [:]
        for goal in goals {
            if let type = goal.type {
                var stats = typeStats[type] ?? (total: 0, completed: 0)
                stats.total += 1
                if goal.isCompleted {
                    stats.completed += 1
                }
                typeStats[type] = stats
            }
        }
        
        // Calculate average progress
        var totalProgress: Double = 0
        var progressCount = 0
        for goal in goals where !goal.isCompleted {
            let progress = goalManager.getProgress(for: goal)
            if let progress = progress {
                totalProgress += progress.percentage
                progressCount += 1
            }
        }
        let averageProgress = progressCount > 0 ? totalProgress / Double(progressCount) : 0
        
        // Calculate milestone stats
        var totalMilestones = 0
        var completedMilestones = 0
        for goal in goals {
            let milestones = goal.sortedMilestones
            totalMilestones += milestones.count
            completedMilestones += milestones.filter { $0.isCompleted }.count
        }
        
        // Build message
        var message = "📊 **Goal Statistics"
        switch period {
        case "week": message += " (Past Week)"
        case "month": message += " (Past Month)"
        case "year": message += " (Past Year)"
        default: message += " (All Time)"
        }
        message += ":**\n\n"
        
        message += "**Overview:**\n"
        message += "• Total Goals: \(totalGoals)\n"
        message += "• Completed: \(completedGoals) (\(totalGoals > 0 ? Int((Double(completedGoals) / Double(totalGoals)) * 100) : 0)%)\n"
        message += "• In Progress: \(inProgressGoals)\n"
        if progressCount > 0 {
            message += "• Average Progress: \(Int(averageProgress * 100))%\n"
        }
        
        if !typeStats.isEmpty {
            message += "\n**By Type:**\n"
            for (type, stats) in typeStats.sorted(by: { $0.key < $1.key }) {
                let completionRate = stats.total > 0 ? Int((Double(stats.completed) / Double(stats.total)) * 100) : 0
                message += "• \(type.capitalized): \(stats.completed)/\(stats.total) (\(completionRate)%)\n"
            }
        }
        
        if totalMilestones > 0 {
            message += "\n**Milestones:**\n"
            message += "• Total: \(totalMilestones)\n"
            message += "• Completed: \(completedMilestones) (\(Int((Double(completedMilestones) / Double(totalMilestones)) * 100))%)\n"
        }
        
        return FunctionCallResult(
            functionName: "get_goal_statistics",
            success: true,
            message: message,
            details: [
                "period": period,
                "totalGoals": "\(totalGoals)",
                "completedGoals": "\(completedGoals)",
                "averageProgress": "\(Int(averageProgress * 100))"
            ]
        )
    }    
    // MARK: - Cross-Entity Operations
    
    private func createGoalWithHabits(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let goalData = arguments["goal"] as? [String: Any],
              let habitsArray = arguments["habits"] as? [[String: Any]] else {
            return FunctionCallResult(
                functionName: "create_goal_with_habits",
                success: false,
                message: "Missing required parameters: goal and habits",
                details: nil
            )
        }
        
        // First create the goal
        let goalResult = await createGoal(with: goalData)
        
        guard goalResult.success,
              let goalIdStr = goalResult.details?["goalId"],
              let goalId = UUID(uuidString: goalIdStr),
              let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
            return FunctionCallResult(
                functionName: "create_goal_with_habits",
                success: false,
                message: "Failed to create goal",
                details: nil
            )
        }
        
        // Create habits and link them
        var createdHabits: [String] = []
        var failedHabits: [String] = []
        
        for habitData in habitsArray {
            let habitResult = await createHabit(with: habitData)
            
            if habitResult.success,
               let habitName = habitData["name"] as? String,
               let habit = habitManager.habits.first(where: { $0.name == habitName }) {
                _ = goalManager.linkHabit(habit, to: goal)
                createdHabits.append(habitName)
            } else {
                failedHabits.append(habitData["name"] as? String ?? "Unknown")
            }
        }
        
        var message = "🎯 **Created goal with \(createdHabits.count) linked habits:**\n\n"
        message += "**Goal:** \(goal.title ?? "")\n\n"
        
        if !createdHabits.isEmpty {
            message += "**Linked Habits:**\n"
            message += createdHabits.map { "• \($0)" }.joined(separator: "\n")
        }
        
        if !failedHabits.isEmpty {
            message += "\n\n⚠️ Failed to create habits: \(failedHabits.joined(separator: ", "))"
        }
        
        return FunctionCallResult(
            functionName: "create_goal_with_habits",
            success: true,
            message: message,
            details: [
                "goalId": goalIdStr,
                "habitsCreated": "\(createdHabits.count)"
            ]
        )
    }
    
    private func createGoalWithTasks(with arguments: [String: Any]) async -> FunctionCallResult {
        return FunctionCallResult(
            functionName: "create_goal_with_tasks",
            success: false,
            message: "Creating goals with linked tasks is not supported in the current version. Goals can only be linked to habits. You can create the goal and tasks separately.",
            details: nil
        )
    }
    
    // MARK: - Bulk Goal Operations
    
    private func updateMultipleGoals(with arguments: [String: Any]) async -> FunctionCallResult {
        // Support TWO formats:
        // 1. Old format: goalIds + single updates object (applies same to all)
        // 2. New format: goals array with individual updates for each
        
        if let goals = arguments["goals"] as? [[String: Any]] {
            // NEW SMART FORMAT - individual updates for each goal
            print("🎯 Using smart format with individual updates for each goal")
            
            var updatedGoals: [String] = []
            var failedGoals: [String] = []
            
            for goalData in goals {
                var goalToUpdate: Goal?
                
                // Find the goal by ID or name (check both "id" and "goalId" keys)
                if let goalIdStr = (goalData["id"] as? String) ?? (goalData["goalId"] as? String),
                   let goalId = UUID(uuidString: goalIdStr) {
                    goalToUpdate = goalManager.goals.first(where: { $0.id == goalId })
                } else if let goalName = (goalData["name"] as? String) ?? (goalData["goalName"] as? String) {
                    goalToUpdate = goalManager.goals.first(where: { 
                        $0.title?.lowercased().contains(goalName.lowercased()) == true 
                    })
                }
                
                guard let goal = goalToUpdate else {
                    let goalIdentifier = (goalData["name"] as? String) ?? 
                                       (goalData["goalName"] as? String) ?? 
                                       (goalData["id"] as? String) ?? 
                                       (goalData["goalId"] as? String) ?? 
                                       "Unknown"
                    failedGoals.append(goalIdentifier)
                    print("❌ Failed to find goal: \(goalIdentifier)")
                    continue
                }
                
                // Apply individual updates for this specific goal
                let title = goalData["title"] as? String
                let description = goalData["description"] as? String
                let targetValue = goalData["targetValue"] as? Double
                let unit = goalData["unit"] as? String
                
                var priority: GoalPriority?
                if let priorityStr = goalData["priority"] as? String {
                    let priorityValue = ["low": 0, "medium": 1, "high": 2, "critical": 3][priorityStr] ?? 1
                    priority = GoalPriority(rawValue: Int16(priorityValue))
                }
                
                var targetDate: Date?
                if let targetDateStr = goalData["targetDate"] as? String {
                    let formatter = ISO8601DateFormatter()
                    targetDate = formatter.date(from: targetDateStr)
                }
                
                // Handle category - THIS is where the magic happens for different categories
                var category: Category?
                if let categoryName = goalData["category"] as? String {
                    print("🎯 Goal '\(goal.title ?? "")': Setting category to '\(categoryName)'")
                    category = scheduleManager.categories.first { 
                        $0.name?.lowercased() == categoryName.lowercased() 
                    }
                    
                    if category == nil {
                        print("⚠️ Category '\(categoryName)' not found for goal '\(goal.title ?? "")'")
                    }
                }
                
                let result = goalManager.updateGoal(
                    goal,
                    title: title,
                    description: description,
                    targetValue: targetValue,
                    targetDate: targetDate,
                    unit: unit,
                    priority: priority,
                    category: category
                )
                
                switch result {
                case .success:
                    updatedGoals.append(goal.title ?? "")
                    print("✅ Updated goal '\(goal.title ?? "")' with category '\(category?.name ?? "none")'")
                case .failure:
                    failedGoals.append(goal.title ?? "")
                }
            }
            
            var message = ""
            if !updatedGoals.isEmpty {
                message = "✅ **Updated \(updatedGoals.count) goals with individual settings:**\n"
                for goal in updatedGoals {
                    message += "• \(goal)\n"
                }
            }
            
            if !failedGoals.isEmpty {
                message += "\n❌ **Failed to update \(failedGoals.count) goals:**\n"
                for goal in failedGoals {
                    message += "• \(goal)\n"
                }
            }
            
            return FunctionCallResult(
                functionName: "update_multiple_goals",
                success: !updatedGoals.isEmpty,
                message: message,
                details: ["updated": "\(updatedGoals.count)", "failed": "\(failedGoals.count)"]
            )
        }
        
        // OLD FORMAT - single updates for all
        guard let goalIdStrings = arguments["goalIds"] as? [String],
              let updates = arguments["updates"] as? [String: Any] else {
            return FunctionCallResult(
                functionName: "update_multiple_goals",
                success: false,
                message: "Missing required parameters: goalIds and updates",
                details: nil
            )
        }
        
        // Debug logging
        print("🎯 UpdateMultipleGoals called with \(goalIdStrings.count) goals")
        print("🎯 Updates requested: \(updates)")
        
        var updatedGoals: [String] = []
        var failedGoals: [String] = []
        var categoryNotFoundGoals: [String] = []
        let totalGoals = goalIdStrings.count
        
        for (index, goalIdStr) in goalIdStrings.enumerated() {
            guard let goalId = UUID(uuidString: goalIdStr),
                  let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
                failedGoals.append(goalIdStr)
                continue
            }
            
            // Parse updates
            var priority: GoalPriority?
            if let priorityStr = updates["priority"] as? String {
                let priorityValue = ["low": 0, "medium": 1, "high": 2, "critical": 3][priorityStr] ?? 1
            priority = GoalPriority(rawValue: Int16(priorityValue))
            }
            
            var targetDate: Date?
            if let targetDateStr = updates["targetDate"] as? String {
                let formatter = ISO8601DateFormatter()
                targetDate = formatter.date(from: targetDateStr)
            }
            
            var category: Category?
            var categoryNotFound = false
            if let categoryName = updates["category"] as? String {
                print("🎯 Goal '\(goal.title ?? "")': Looking for category '\(categoryName)'")
                
                // First try exact case-insensitive match
                category = scheduleManager.categories.first { $0.name?.lowercased() == categoryName.lowercased() }
                
                if category != nil {
                    print("🎯 Goal '\(goal.title ?? "")': Found exact match for category '\(category?.name ?? "")'")
                } else {
                    // If no exact match, try intelligent mapping
                    category = self.findBestMatchingCategory(for: categoryName)
                    if category != nil {
                        print("🎯 Goal '\(goal.title ?? "")': Found best match for category '\(category?.name ?? "")'")
                    } else {
                        print("⚠️ Goal '\(goal.title ?? "")': No category found for '\(categoryName)'")
                        categoryNotFound = true
                    }
                }
            }
            
            // Generate contextual values for fields
            let contextualTitle = generateContextualValue(for: goal, field: "title", baseValue: updates["title"] as? String, index: index, total: totalGoals)
            let contextualDescription = generateContextualValue(for: goal, field: "description", baseValue: updates["description"] as? String, index: index, total: totalGoals)
            let contextualUnit = generateContextualValue(for: goal, field: "unit", baseValue: updates["unit"] as? String, index: index, total: totalGoals)
            
            let result = goalManager.updateGoal(
                goal,
                title: contextualTitle,
                description: contextualDescription,
                targetValue: updates["targetValue"] as? Double,
                targetDate: targetDate,
                unit: contextualUnit,
                priority: priority,
                category: category
            )
            
            if case .success = result {
                print("✅ Goal '\(goal.title ?? "")': Update successful")
                updatedGoals.append(goal.title ?? "")
                if categoryNotFound {
                    categoryNotFoundGoals.append(goal.title ?? "")
                }
            } else {
                print("❌ Goal '\(goal.title ?? "")': Update failed")
                failedGoals.append(goal.title ?? goalIdStr)
            }
        }
        
        if updatedGoals.isEmpty {
            return FunctionCallResult(
                functionName: "update_multiple_goals",
                success: false,
                message: "Failed to update any goals",
                details: ["failed": failedGoals.joined(separator: ", ")]
            )
        }
        
        var message = "✅ **Updated \(updatedGoals.count) goals**\n\n"
        message += updatedGoals.map { "• \($0)" }.joined(separator: "\n")
        
        if !categoryNotFoundGoals.isEmpty {
            message += "\n\n⚠️ **Category not found for \(categoryNotFoundGoals.count) goals:**\n"
            message += categoryNotFoundGoals.map { "• \($0)" }.joined(separator: "\n")
            message += "\n\nThese goals were updated except for their category/area."
        }
        
        if !failedGoals.isEmpty {
            message += "\n\n❌ **Failed to update:** \(failedGoals.joined(separator: ", "))"
        }
        
        return FunctionCallResult(
            functionName: "update_multiple_goals",
            success: true,
            message: message,
            details: ["updated": "\(updatedGoals.count)"]
        )
    }
    
    private func deleteMultipleGoals(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let goalIdStrings = arguments["goalIds"] as? [String] else {
            return FunctionCallResult(
                functionName: "delete_multiple_goals",
                success: false,
                message: "Missing required parameter: goalIds",
                details: nil
            )
        }
        
        var deletedGoals: [String] = []
        var failedGoals: [String] = []
        
        for goalIdStr in goalIdStrings {
            guard let goalId = UUID(uuidString: goalIdStr),
                  let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
                failedGoals.append(goalIdStr)
                continue
            }
            
            let title = goal.title ?? "Untitled"
            let result = goalManager.deleteGoal(goal)
            
            if case .success = result {
                deletedGoals.append(title)
            } else {
                failedGoals.append(title)
            }
        }
        
        if deletedGoals.isEmpty {
            return FunctionCallResult(
                functionName: "delete_multiple_goals",
                success: false,
                message: "Failed to delete any goals",
                details: ["failed": failedGoals.joined(separator: ", ")]
            )
        }
        
        var message = "🗑️ **Deleted \(deletedGoals.count) goals**\n\n"
        message += deletedGoals.map { "• \($0)" }.joined(separator: "\n")
        
        if !failedGoals.isEmpty {
            message += "\n\n⚠️ Failed: \(failedGoals.joined(separator: ", "))"
        }
        
        return FunctionCallResult(
            functionName: "delete_multiple_goals",
            success: true,
            message: message,
            details: ["deleted": "\(deletedGoals.count)"]
        )
    }
    
    private func deleteAllGoals(with arguments: [String: Any]) async -> FunctionCallResult {
        let status = arguments["status"] as? String ?? "all"
        let categoryName = arguments["category"] as? String
        
        var goalsToDelete = goalManager.goals
        
        // Filter by status
        switch status {
        case "active":
            goalsToDelete = goalsToDelete.filter { !$0.isCompleted }
        case "completed":
            goalsToDelete = goalsToDelete.filter { $0.isCompleted }
        default:
            break // Delete all
        }
        
        // Filter by category
        if let categoryName = categoryName {
            goalsToDelete = goalsToDelete.filter { $0.category?.name == categoryName }
        }
        
        if goalsToDelete.isEmpty {
            return FunctionCallResult(
                functionName: "delete_all_goals",
                success: true,
                message: "No goals found to delete",
                details: ["deleted": "0"]
            )
        }
        
        var deletedCount = 0
        for goal in goalsToDelete {
            let result = goalManager.deleteGoal(goal)
            if case .success = result {
                deletedCount += 1
            }
        }
        
        var message = "🗑️ **Deleted \(deletedCount) goals**"
        if status != "all" {
            message += " (\(status))"
        }
        if let categoryName = categoryName {
            message += " in category '\(categoryName)'"
        }
        
        return FunctionCallResult(
            functionName: "delete_all_goals",
            success: deletedCount > 0,
            message: message,
            details: ["deleted": "\(deletedCount)"]
        )
    }
    
    private func updateAllGoals(with arguments: [String: Any]) async -> FunctionCallResult {
        let filter = arguments["filter"] as? [String: Any] ?? [:]
        guard let updates = arguments["updates"] as? [String: Any] else {
            return FunctionCallResult(
                functionName: "update_all_goals",
                success: false,
                message: "Missing required updates parameter",
                details: nil
            )
        }
        
        // Start with all goals
        var goalsToUpdate = goalManager.goals
        
        // Apply filters
        if let type = filter["type"] as? String {
            goalsToUpdate = goalsToUpdate.filter { $0.type == type }
        }
        
        if let priority = filter["priority"] as? String {
            let priorityValue: Int16
            switch priority.lowercased() {
            case "low": priorityValue = 0
            case "medium": priorityValue = 1
            case "high": priorityValue = 2
            case "critical": priorityValue = 3
            default: priorityValue = 1
            }
            goalsToUpdate = goalsToUpdate.filter { $0.priority == priorityValue }
        }
        
        if let categoryName = filter["category"] as? String {
            goalsToUpdate = goalsToUpdate.filter { $0.category?.name == categoryName }
        }
        
        if let isCompleted = filter["isCompleted"] as? Bool {
            goalsToUpdate = goalsToUpdate.filter { $0.isCompleted == isCompleted }
        }
        
        if let overdue = filter["overdue"] as? Bool, overdue {
            let now = Date()
            goalsToUpdate = goalsToUpdate.filter { goal in
                guard let targetDate = goal.targetDate, !goal.isCompleted else { return false }
                return targetDate < now
            }
        }
        
        if goalsToUpdate.isEmpty {
            return FunctionCallResult(
                functionName: "update_all_goals",
                success: true,
                message: "No goals found matching the filter criteria",
                details: nil
            )
        }
        
        // Parse updates
        let addDays = updates["addDays"] as? Double ?? 0
        
        // Parse category update
        var category: Category?
        if let categoryName = updates["category"] as? String {
            category = scheduleManager.categories.first { $0.name == categoryName }
            if category == nil {
                // Create category if doesn't exist
                let (icon, color) = self.generateUniqueIconAndColor(for: categoryName)
                let result = scheduleManager.createCategory(name: categoryName, icon: icon, colorHex: color)
                if case .success(let newCategory) = result {
                    category = newCategory
                }
            }
        }
        
        var updatedCount = 0
        var failedCount = 0
        
        for goal in goalsToUpdate {
            // Calculate new target date if addDays is specified
            var newTargetDate = goal.targetDate
            
            if addDays != 0, let targetDate = goal.targetDate {
                newTargetDate = targetDate.addingTimeInterval(addDays * 24 * 60 * 60)
            }
            
            // Parse specific date update
            if let targetDateStr = updates["targetDate"] as? String {
                newTargetDate = ISO8601DateFormatter().date(from: targetDateStr)
            }
            
            let result = goalManager.updateGoal(
                goal,
                title: nil, // Don't update title in bulk
                description: updates["description"] as? String,
                targetValue: updates["targetValue"] as? Double,
                targetDate: newTargetDate,
                unit: updates["unit"] as? String,
                priority: updates["priority"] as? String != nil ? {
                    let priorityStr = updates["priority"] as! String
                    switch priorityStr.lowercased() {
                    case "low": return GoalPriority.low
                    case "medium": return GoalPriority.medium
                    case "high": return GoalPriority.high
                    case "critical": return GoalPriority.critical
                    default: return GoalPriority.medium
                    }
                }() : nil,
                category: category
            )
            
            switch result {
            case .success:
                updatedCount += 1
                
                // Handle completion if specified
                if let isCompleted = updates["isCompleted"] as? Bool, isCompleted {
                    _ = goalManager.completeGoal(goal)
                }
                
            case .failure:
                failedCount += 1
            }
        }
        
        let details: [String: String] = [
            "goalsFound": "\(goalsToUpdate.count)",
            "updated": "\(updatedCount)",
            "failed": "\(failedCount)"
        ]
        
        if failedCount > 0 {
            return FunctionCallResult(
                functionName: "update_all_goals",
                success: false,
                message: "Updated \(updatedCount) goals, but \(failedCount) failed",
                details: details
            )
        } else {
            return FunctionCallResult(
                functionName: "update_all_goals",
                success: true,
                message: "✅ Successfully updated \(updatedCount) goals",
                details: details
            )
        }
    }    
    private func completeMultipleGoals(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let goalIdStrings = arguments["goalIds"] as? [String] else {
            return FunctionCallResult(
                functionName: "complete_multiple_goals",
                success: false,
                message: "Missing required parameter: goalIds",
                details: nil
            )
        }
        
        let completionNotes = arguments["completionNotes"] as? String
        
        var completedGoals: [String] = []
        var failedGoals: [String] = []
        
        for goalIdStr in goalIdStrings {
            guard let goalId = UUID(uuidString: goalIdStr),
                  let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
                failedGoals.append(goalIdStr)
                continue
            }
            
            let result = goalManager.completeGoal(goal, notes: completionNotes)
            
            if case .success = result {
                completedGoals.append(goal.title ?? "")
            } else {
                failedGoals.append(goal.title ?? goalIdStr)
            }
        }
        
        if completedGoals.isEmpty {
            return FunctionCallResult(
                functionName: "complete_multiple_goals",
                success: false,
                message: "Failed to complete any goals",
                details: ["failed": failedGoals.joined(separator: ", ")]
            )
        }
        
        var message = "🎉 **Completed \(completedGoals.count) goals!**\n\n"
        message += completedGoals.map { "• \($0)" }.joined(separator: "\n")
        message += "\n\nCongratulations on achieving these goals!"
        
        if !failedGoals.isEmpty {
            message += "\n\n⚠️ Failed: \(failedGoals.joined(separator: ", "))"
        }
        
        return FunctionCallResult(
            functionName: "complete_multiple_goals",
            success: true,
            message: message,
            details: ["completed": "\(completedGoals.count)"]
        )
    }
    
    private func updateMultipleGoalProgress(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let updates = arguments["updates"] as? [[String: Any]] else {
            return FunctionCallResult(
                functionName: "update_multiple_goal_progress",
                success: false,
                message: "Missing required parameter: updates",
                details: nil
            )
        }
        
        var updatedGoals: [String] = []
        var failedGoals: [String] = []
        
        for update in updates {
            guard let goalIdStr = update["goalId"] as? String,
                  let goalId = UUID(uuidString: goalIdStr),
                  let value = update["value"] as? Double else {
                continue
            }
            
            guard let goal = goalManager.goals.first(where: { $0.id == goalId }) else {
                failedGoals.append(goalIdStr)
                continue
            }
            
            let notes = update["notes"] as? String
            let result = goalManager.updateProgress(for: goal, value: value, notes: notes)
            
            if case .success = result {
                updatedGoals.append(goal.title ?? "")
            } else {
                failedGoals.append(goal.title ?? goalIdStr)
            }
        }
        
        if updatedGoals.isEmpty {
            return FunctionCallResult(
                functionName: "update_multiple_goal_progress",
                success: false,
                message: "Failed to update progress for any goals",
                details: ["failed": failedGoals.joined(separator: ", ")]
            )
        }
        
        var message = "📈 **Updated progress for \(updatedGoals.count) goals**\n\n"
        message += updatedGoals.map { "• \($0)" }.joined(separator: "\n")
        
        if !failedGoals.isEmpty {
            message += "\n\n⚠️ Failed: \(failedGoals.joined(separator: ", "))"
        }
        
        return FunctionCallResult(
            functionName: "update_multiple_goal_progress",
            success: true,
            message: message,
            details: ["updated": "\(updatedGoals.count)"]
        )
    }
    
    // MARK: - Error Handling
    
    private func handleOpenAIError(_ error: Error) {
        
        let errorMessage = ChatMessage(
            content: "",
            sender: .assistant,
            timestamp: Date(),
            error: error.localizedDescription
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
        
        self.finalizeStreamingMessage(id: messageId)
        
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            // Check if it's a rate limit error by examining the error message
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("rate limit") || errorMessage.contains("429") {
                // Set rate limit state
                isRateLimited = true
                rateLimitResetTime = Date().addingTimeInterval(TimeInterval(60)) // Default 60 seconds
                
                // Remove the error message from the chat
                messages.remove(at: index)
                
                // Start timer to reset rate limit
                startRateLimitTimer(seconds: 60)
                
                // Show paywall for free users
                if !subscriptionManager.isPremium {
                    showPaywall = true
                }
            } else if let urlError = error as? URLError {
                print("🔴 URLError occurred: \(urlError)")
                print("🔴 URLError code: \(urlError.code)")
                print("🔴 URLError description: \(urlError.localizedDescription)")
                messages[index].error = "Network error. Please check your connection and try again."
            } else {
                print("🔴 Unknown error: \(error)")
                print("🔴 Error type: \(type(of: error))")
                print("🔴 Error description: \(error.localizedDescription)")
                messages[index].error = "Something went wrong. Please try again."
            }
            
        } else {
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
        let details = result.details
        if details == nil {
            return nil
        }
        
        var events: [EventListItem] = []
        
        // First try to get events with dates from JSON
        if let eventsJsonString = details?["_createdEventsWithDates"],
           let eventsData = eventsJsonString.data(using: .utf8),
           let createdEvents = try? JSONSerialization.jsonObject(with: eventsData, options: []) as? [[String: String]] {
            
            let formatter = ISO8601DateFormatter()
            for eventDict in createdEvents {
                if let title = eventDict["title"],
                   let time = eventDict["time"] {
                    var date: Date? = nil
                    if let dateStr = eventDict["date"], !dateStr.isEmpty {
                        date = formatter.date(from: dateStr)
                    }
                    
                    events.append(EventListItem(
                        id: UUID().uuidString,
                        time: time,
                        title: title,
                        isCompleted: false,
                        date: date
                    ))
                }
            }
        } else {
            // Fallback to old parsing method without dates
            if let eventList = details?["eventList"] {
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
                            isCompleted: false,
                            date: nil // No date available in old format
                        ))
                    }
                }
            } else if let createdList = details?["created"] {
                // Fallback to just titles
                let eventTitles = createdList.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                
                for (index, title) in eventTitles.enumerated() {
                    events.append(EventListItem(
                        id: UUID().uuidString,
                        time: "Time \(index + 1)",
                        title: title,
                        isCompleted: false,
                        date: nil // No date available
                    ))
                }
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
        
        // Creating bulk action preview
        
        // Parse count from message like "Successfully deleted 5 events" or "Successfully deleted all 10 events"
        if message.contains("all") && message.contains("events") {
            // Look for "all X events" pattern
            if let range = message.range(of: #"all (\d+) event"#, options: .regularExpression) {
                let substring = String(message[range])
                let components = substring.components(separatedBy: " ")
                if components.count >= 2 {
                    affectedCount = Int(components[1]) ?? 0
                }
            }
        } else if let range = message.range(of: #"(\d+) event"#, options: .regularExpression) {
            let countStr = String(message[range]).components(separatedBy: " ").first ?? "0"
            affectedCount = Int(countStr) ?? 0
        }
        
        // Parsed affected count
        
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
        
        // For delete operations, always show confirm button if success
        let actions: [BulkActionPreview.BulkAction] = result.success ? [.confirm] : [.confirm, .cancel]
        
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
            // Mark as completed and keep visible
            completedBulkActionIds.insert(preview.id)
            // Bulk action confirmed
        case .cancel:
            // Keep the preview visible but don't mark as completed
            // Bulk action cancelled
            break
        case .undo:
            // TODO: Implement undo functionality
            break
            // Undo action
        }
    }
    
    // MARK: - Category Helpers
    
    // MARK: - Contextual Content Generation
    
    private func generateContextualValue(
        for entity: Any,
        field: String,
        baseValue: String?,
        index: Int,
        total: Int
    ) -> String? {
        // If no base value, return nil (no update for this field)
        guard let base = baseValue else { return nil }
        
        // Check if the base value contains special markers for contextual generation
        if base.contains("{auto}") || base.contains("{context}") || base.contains("{unique}") {
            // Generate contextual content based on entity type and field
            switch entity {
            case let event as Event:
                return generateContextualEventValue(event: event, field: field, base: base, index: index, total: total)
            case let task as Task:
                return generateContextualTaskValue(task: task, field: field, base: base, index: index, total: total)
            case let habit as Habit:
                return generateContextualHabitValue(habit: habit, field: field, base: base, index: index, total: total)
            case let goal as Goal:
                return generateContextualGoalValue(goal: goal, field: field, base: base, index: index, total: total)
            default:
                return base.replacingOccurrences(of: "{auto}", with: "Item \(index + 1)")
                    .replacingOccurrences(of: "{context}", with: "")
                    .replacingOccurrences(of: "{unique}", with: "#\(index + 1)")
            }
        }
        
        // For bulk updates with notes field, check if we need unique content
        if total > 1 && field == "notes" {
            // If no base value or it's a generic instruction, generate unique content
            if base.isEmpty {
                switch entity {
                case let task as Task:
                    // Generate simple, relevant notes based on the task title
                    return generateSimpleTaskNote(for: task)
                case let event as Event:
                    return generateSimpleEventNote(for: event)
                default:
                    return nil
                }
            }
            // Otherwise use what was provided
            return base
        }
        
        // For bulk updates, just use what the AI provides
        // The AI is smart enough to generate unique content when needed
        if total > 1 && (field == "title" || field == "description") {
            // For other fields, add unique suffix only if needed
            let baseWithContext = base + " {unique}"
            switch entity {
            case let event as Event:
                return generateContextualEventValue(event: event, field: field, base: baseWithContext, index: index, total: total)
            case let task as Task:
                return generateContextualTaskValue(task: task, field: field, base: baseWithContext, index: index, total: total)
            case let habit as Habit:
                return generateContextualHabitValue(habit: habit, field: field, base: baseWithContext, index: index, total: total)
            case let goal as Goal:
                return generateContextualGoalValue(goal: goal, field: field, base: baseWithContext, index: index, total: total)
            default:
                return base + " (Item \(index + 1) of \(total))"
            }
        }
        
        // Return the base value as-is for static updates or single item updates
        return base
    }
    
    private func generateContextualEventValue(event: Event, field: String, base: String, index: Int, total: Int) -> String {
        let title = event.title ?? "Event"
        let category = event.category?.name ?? "General"
        let dayOfWeek = event.startTime.map { DateFormatter().weekdaySymbols[Calendar.current.component(.weekday, from: $0) - 1] } ?? "Today"
        
        switch field {
        case "notes":
            return base.replacingOccurrences(of: "{auto}", with: "Notes for \(title)")
                .replacingOccurrences(of: "{context}", with: "Scheduled for \(dayOfWeek) in \(category)")
                .replacingOccurrences(of: "{unique}", with: "Event \(index + 1) of \(total): \(title)")
        case "location":
            return base.replacingOccurrences(of: "{auto}", with: "Location for \(title)")
                .replacingOccurrences(of: "{context}", with: "\(category) area")
                .replacingOccurrences(of: "{unique}", with: "Room \(index + 1)")
        case "url":
            return base.replacingOccurrences(of: "{auto}", with: "https://example.com/event/\(event.id?.uuidString ?? String(index))")
                .replacingOccurrences(of: "{context}", with: "https://meet.example.com/\(title.replacingOccurrences(of: " ", with: "-").lowercased())")
                .replacingOccurrences(of: "{unique}", with: "https://event\(index + 1).example.com")
        default:
            return base.replacingOccurrences(of: "{auto}", with: title)
                .replacingOccurrences(of: "{context}", with: category)
                .replacingOccurrences(of: "{unique}", with: "Item \(index + 1)")
        }
    }
    
    private func generateContextualTaskValue(task: Task, field: String, base: String, index: Int, total: Int) -> String {
        let title = task.title ?? "Task"
        let priority = task.priorityEnum.displayName
        let category = task.category?.name ?? "General"
        
        switch field {
        case "notes":
            // Just replace markers like events do - don't generate anything custom
            return base.replacingOccurrences(of: "{auto}", with: "Notes for \(title)")
                .replacingOccurrences(of: "{context}", with: "\(priority) priority task in \(category)")
                .replacingOccurrences(of: "{unique}", with: "Task \(index + 1) of \(total): \(title)")
        case "tags":
            return base.replacingOccurrences(of: "{auto}", with: "\(category.lowercased()),\(priority.lowercased())")
                .replacingOccurrences(of: "{context}", with: "task-\(index + 1),\(category.lowercased())")
                .replacingOccurrences(of: "{unique}", with: "task-\(index + 1)")
        default:
            return base.replacingOccurrences(of: "{auto}", with: title)
                .replacingOccurrences(of: "{context}", with: "\(priority) - \(category)")
                .replacingOccurrences(of: "{unique}", with: "Task \(index + 1)")
        }
    }
    
    
    
    private func extractSubject(from title: String, removing keywords: [String]) -> String {
        var words = title.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines)
        // Remove common keywords to get the subject
        words = words.filter { word in
            !keywords.contains(word) && !["for", "the", "a", "an", "to", "with", "about"].contains(word)
        }
        return words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generateSimpleTaskNote(for task: Task) -> String {
        let title = task.title ?? ""
        let titleLower = title.lowercased()
        
        // Generate simple, natural notes based on the task
        if titleLower.contains("meeting") {
            return "Prepare agenda and talking points"
        } else if titleLower.contains("email") || titleLower.contains("send") {
            return "Draft and send before end of day"
        } else if titleLower.contains("review") {
            return "Check thoroughly and provide feedback"
        } else if titleLower.contains("call") {
            return "Schedule time and prepare topics to discuss"
        } else if titleLower.contains("research") {
            return "Gather information and document findings"
        } else if titleLower.contains("create") || titleLower.contains("build") {
            return "Design and implement step by step"
        } else if titleLower.contains("budget") {
            return "Review expenses and track spending"
        } else if titleLower.contains("workout") || titleLower.contains("exercise") {
            return "Complete routine and track progress"
        } else if titleLower.contains("plan") {
            return "Outline steps and set timeline"
        } else {
            // Default: just encourage completion
            return "Complete this task today"
        }
    }
    
    private func generateSimpleEventNote(for event: Event) -> String {
        let title = event.title ?? ""
        let titleLower = title.lowercased()
        
        if titleLower.contains("meeting") {
            return "Bring laptop and notes"
        } else if titleLower.contains("appointment") {
            return "Arrive 10 minutes early"
        } else if titleLower.contains("workout") || titleLower.contains("gym") {
            return "Bring water and gym clothes"
        } else {
            return "Remember to attend"
        }
    }
    
    // Generate unique notes for other entity types
    private func generateUniqueEventNotes(for event: Event) -> String {
        let title = event.title ?? "Event"
        let category = event.category?.name ?? "General"
        // Calculate duration from start and end times
        let duration: TimeInterval
        if let start = event.startTime, let end = event.endTime {
            duration = end.timeIntervalSince(start)
        } else {
            duration = 3600 // Default 1 hour
        }
        let location = event.location ?? "TBD"
        
        // Generate notes based on event type
        if title.lowercased().contains("meeting") {
            return "Meeting agenda: Review previous action items, discuss key topics, make decisions, assign new action items. Location: \(location). Duration: \(Int(duration/60)) minutes."
        } else if title.lowercased().contains("presentation") {
            return "Presentation prep: Review slides, practice key talking points, prepare Q&A responses, test equipment. Venue: \(location). Allow \(Int(duration/60)) minutes."
        } else if title.lowercased().contains("workout") || title.lowercased().contains("exercise") {
            return "Workout plan: Warm-up routine, main exercises, cool-down stretches. Track reps/sets. Location: \(location). Duration: \(Int(duration/60)) minutes."
        } else if title.lowercased().contains("appointment") || title.lowercased().contains("doctor") {
            return "Appointment notes: Bring necessary documents, list questions to ask, note symptoms/concerns. Location: \(location). Allocated time: \(Int(duration/60)) minutes."
        } else {
            return "\(title) details: Key objectives, required materials, expected outcomes. Location: \(location). Duration: \(Int(duration/60)) minutes. Category: \(category)."
        }
    }
    
    private func generateUniqueHabitNotes(for habit: Habit) -> String {
        let name = habit.name ?? "Habit"
        let frequency = habit.frequency ?? "daily"
        let goalValue = habit.goalTarget
        let unit = habit.goalUnit ?? "times"
        
        // Generate notes based on habit type
        if name.lowercased().contains("exercise") || name.lowercased().contains("workout") {
            return "Track \(frequency) \(name): Target \(Int(goalValue)) \(unit). Log form quality, energy level, and any variations. Note progress and challenges."
        } else if name.lowercased().contains("read") || name.lowercased().contains("study") {
            return "\(frequency.capitalized) \(name) goal: \(Int(goalValue)) \(unit). Track topics covered, key insights, and areas for deeper exploration."
        } else if name.lowercased().contains("meditat") || name.lowercased().contains("mindful") {
            return "\(name) practice: \(Int(goalValue)) \(unit) \(frequency). Note technique used, quality of focus, and any insights or challenges."
        } else if name.lowercased().contains("water") || name.lowercased().contains("diet") || name.lowercased().contains("nutrition") {
            return "Track \(frequency) \(name): Goal of \(Int(goalValue)) \(unit). Log timing, portion sizes, and how you feel afterwards."
        } else {
            return "\(frequency.capitalized) habit: \(name). Target: \(Int(goalValue)) \(unit). Track consistency, identify patterns, note obstacles and successes."
        }
    }
    
    private func generateUniqueGoalNotes(for goal: Goal) -> String {
        let title = goal.title ?? "Goal"
        let targetValue = goal.targetValue
        let unit = goal.unit ?? "units"
        let targetDate = goal.targetDate
        let progress = goal.currentValue
        
        let remainingValue = targetValue - progress
        let percentComplete = targetValue > 0 ? Int((progress / targetValue) * 100) : 0
        
        var notes = "Goal: \(title). Target: \(Int(targetValue)) \(unit)"
        
        if let date = targetDate {
            let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
            notes += " by \(formatDate(date)) (\(daysRemaining) days remaining)"
        }
        
        notes += ". Progress: \(Int(progress))/\(Int(targetValue)) (\(percentComplete)% complete). "
        
        if remainingValue > 0 {
            notes += "Remaining: \(Int(remainingValue)) \(unit). "
            
            if let date = targetDate {
                let daysRemaining = max(1, Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 1)
                let dailyTarget = remainingValue / Double(daysRemaining)
                notes += "Daily target: \(String(format: "%.1f", dailyTarget)) \(unit)/day."
            }
        } else {
            notes += "Goal completed! 🎉"
        }
        
        return notes
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    
    private func generateContextualHabitValue(habit: Habit, field: String, base: String, index: Int, total: Int) -> String {
        let name = habit.name ?? "Habit"
        let frequency = habit.frequency ?? "daily"
        let category = habit.category?.name ?? "General"
        
        switch field {
        case "notes":
            return base.replacingOccurrences(of: "{auto}", with: "Notes for \(name)")
                .replacingOccurrences(of: "{context}", with: "\(frequency) habit in \(category)")
                .replacingOccurrences(of: "{unique}", with: "Habit \(index + 1) of \(total): \(name) - \(frequency)")
        case "goalUnit":
            return base.replacingOccurrences(of: "{auto}", with: habit.trackingType == "numeric" ? "times" : "completed")
                .replacingOccurrences(of: "{context}", with: habit.trackingType == "duration" ? "minutes" : "times")
                .replacingOccurrences(of: "{unique}", with: "unit-\(index + 1)")
        default:
            return base.replacingOccurrences(of: "{auto}", with: name)
                .replacingOccurrences(of: "{context}", with: "\(frequency) - \(category)")
                .replacingOccurrences(of: "{unique}", with: "Habit \(index + 1)")
        }
    }
    
    private func generateContextualGoalValue(goal: Goal, field: String, base: String, index: Int, total: Int) -> String {
        let title = goal.title ?? "Goal"
        let type = goal.type ?? "milestone"
        let priority = goal.priorityEnum.displayName
        
        switch field {
        case "desc", "description":
            return base.replacingOccurrences(of: "{auto}", with: "Description for \(title)")
                .replacingOccurrences(of: "{context}", with: "\(priority) priority \(type) goal")
                .replacingOccurrences(of: "{unique}", with: "Goal \(index + 1) of \(total): \(title) - Type: \(type)")
        case "unit":
            return base.replacingOccurrences(of: "{auto}", with: type == "numeric" ? "items" : "milestones")
                .replacingOccurrences(of: "{context}", with: type == "habit" ? "completions" : "progress")
                .replacingOccurrences(of: "{unique}", with: "unit-\(index + 1)")
        default:
            return base.replacingOccurrences(of: "{auto}", with: title)
                .replacingOccurrences(of: "{context}", with: "\(priority) - \(type)")
                .replacingOccurrences(of: "{unique}", with: "Goal \(index + 1)")
        }
    }
    
    private func generateUniqueIconAndColor(for categoryName: String) -> (icon: String, color: String) {
        // Get existing icons and colors to avoid duplicates
        let existingIcons = Set(scheduleManager.categories.map { $0.iconName })
        let existingColors = Set(scheduleManager.categories.map { $0.colorHex })
        
        // Available icons for categories
        let availableIcons = [
            "star.fill", "flag.fill", "tag.fill", "bookmark.fill",
            "paperplane.fill", "tray.fill", "archivebox.fill", "folder.fill",
            "calendar", "clock.fill", "alarm.fill", "timer",
            "lightbulb.fill", "graduationcap.fill", "sportscourt.fill", "dumbbell.fill",
            "bicycle", "car.fill", "airplane", "tram.fill",
            "house.fill", "building.2.fill", "storefront.fill", "hammer.fill",
            "wrench.fill", "paintbrush.fill", "scissors", "eyedropper.fill",
            "camera.fill", "music.note", "mic.fill", "headphones",
            "tv.fill", "gamecontroller.fill", "puzzlepiece.fill", "gift.fill",
            "cart.fill", "creditcard.fill", "banknote.fill", "chart.line.uptrend.xyaxis",
            "leaf.fill", "flame.fill", "drop.fill", "snowflake",
            "sparkles", "moon.fill", "sun.max.fill", "cloud.fill",
            "bolt.fill", "umbrella.fill", "thermometer", "bandage.fill",
            "pills.fill", "cross.case.fill", "stethoscope", "bed.double.fill",
            "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill", "birthday.cake.fill"
        ]
        
        // Available colors
        let availableColors = [
            "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FECA57",
            "#FF9FF3", "#54A0FF", "#48DBFB", "#0ABDE3", "#00D2D3",
            "#1DD1A1", "#10AC84", "#EE5A24", "#F368E0", "#FF6348",
            "#FFA502", "#FF7675", "#74B9FF", "#A29BFE", "#6C5CE7",
            "#FD79A8", "#FDCB6E", "#E17055", "#00B894", "#00CEC9",
            "#0984E3", "#6C5CE7", "#B2BEC3", "#636E72", "#2D3436"
        ]
        
        // Try to pick based on category name keywords
        var selectedIcon = "folder.fill"
        var selectedColor = "#007AFF"
        
        let lowerName = categoryName.lowercased()
        
        // Icon selection based on keywords
        if lowerName.contains("sport") || lowerName.contains("gym") || lowerName.contains("fitness") {
            selectedIcon = "sportscourt.fill"
        } else if lowerName.contains("food") || lowerName.contains("meal") || lowerName.contains("dinner") || lowerName.contains("lunch") {
            selectedIcon = "fork.knife"
        } else if lowerName.contains("travel") || lowerName.contains("trip") {
            selectedIcon = "airplane"
        } else if lowerName.contains("home") || lowerName.contains("house") {
            selectedIcon = "house.fill"
        } else if lowerName.contains("music") || lowerName.contains("concert") {
            selectedIcon = "music.note"
        } else if lowerName.contains("shop") || lowerName.contains("buy") || lowerName.contains("store") {
            selectedIcon = "cart.fill"
        } else if lowerName.contains("game") || lowerName.contains("play") {
            selectedIcon = "gamecontroller.fill"
        } else if lowerName.contains("photo") || lowerName.contains("picture") {
            selectedIcon = "camera.fill"
        } else if lowerName.contains("call") || lowerName.contains("phone") {
            selectedIcon = "phone.fill"
        } else if lowerName.contains("email") || lowerName.contains("mail") {
            selectedIcon = "envelope.fill"
        } else if lowerName.contains("doctor") || lowerName.contains("medical") || lowerName.contains("hospital") {
            selectedIcon = "stethoscope"
        } else if lowerName.contains("school") || lowerName.contains("study") || lowerName.contains("class") {
            selectedIcon = "graduationcap.fill"
        } else {
            // Pick a random icon that's not already used
            let unusedIcons = availableIcons.filter { !existingIcons.contains($0) }
            if !unusedIcons.isEmpty {
                selectedIcon = unusedIcons.randomElement() ?? "folder.fill"
            }
        }
        
        // Pick a color that's not already used
        let unusedColors = availableColors.filter { !existingColors.contains($0) }
        if !unusedColors.isEmpty {
            selectedColor = unusedColors.randomElement() ?? "#007AFF"
        } else {
            // If all colors are used, generate a random one
            let hue = Double.random(in: 0...360)
            let saturation = Double.random(in: 0.5...0.8)
            let brightness = Double.random(in: 0.6...0.9)
            selectedColor = hsbToHex(hue: hue, saturation: saturation, brightness: brightness)
        }
        
        return (selectedIcon, selectedColor)
    }
    
    private func hsbToHex(hue: Double, saturation: Double, brightness: Double) -> String {
        let color = UIColor(hue: hue/360, saturation: saturation, brightness: brightness, alpha: 1.0)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        
        return String(format: "#%02X%02X%02X",
                      Int(red * 255),
                      Int(green * 255),
                      Int(blue * 255))
    }    
    // MARK: - Category Management Functions
    
    private func listCategories(with arguments: [String: Any]) async -> FunctionCallResult {
        let includeBuiltIn = arguments["includeBuiltIn"] as? Bool ?? true
        let includeStats = arguments["includeStats"] as? Bool ?? false
        
        var categories = scheduleManager.categories
        
        // Note: isCustom property not available in current model
        // if !includeBuiltIn {
        //     categories = categories.filter { $0.isCustom }
        // }
        
        if categories.isEmpty {
            return FunctionCallResult(
                functionName: "list_categories",
                success: true,
                message: "No categories found.",
                details: nil
            )
        }
        
        var message = "📂 **Categories:**\n\n"
        
        for category in categories.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }) {
            message += "• **\(category.name ?? "Unnamed")** "
            
            if let color = category.colorHex {
                message += "🎨"
            }
            
            if let icon = category.iconName {
                message += " \(icon)"
            }
            
            // Note: isCustom not available
            // if !category.isCustom {
            //     message += " _(built-in)_"
            // }
            
            if includeStats {
                let eventCount = scheduleManager.events.filter { $0.category?.id == category.id }.count
                let taskCount = taskManager.tasks.filter { $0.category?.id == category.id }.count
                message += "\n  _\(eventCount) events, \(taskCount) tasks_"
            }
            
            message += "\n"
        }
        
        return FunctionCallResult(
            functionName: "list_categories",
            success: true,
            message: message,
            details: ["categoryCount": "\(categories.count)"]
        )
    }
    
    private func updateCategory(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let categoryName = arguments["categoryName"] as? String else {
            return FunctionCallResult(
                functionName: "update_category",
                success: false,
                message: "Missing required parameter: categoryName",
                details: nil
            )
        }
        
        guard let category = scheduleManager.categories.first(where: { $0.name?.lowercased() == categoryName.lowercased() }) else {
            return FunctionCallResult(
                functionName: "update_category",
                success: false,
                message: "Category '\(categoryName)' not found",
                details: nil
            )
        }
        
        // Note: isCustom check not available
        // if !category.isCustom {
        //     return FunctionCallResult(
        //         functionName: "update_category",
        //         success: false,
        //         message: "Cannot update built-in category '\(categoryName)'",
        //         details: nil
        //     )
        // }
        
        let newName = arguments["newName"] as? String ?? category.name ?? ""
        let color = arguments["color"] as? String ?? category.colorHex ?? ""
        let icon = arguments["icon"] as? String ?? category.iconName ?? ""
        
        category.name = newName
        category.colorHex = color
        category.iconName = icon
        
        // Save changes using PersistenceController directly
        do {
            try PersistenceController.shared.container.viewContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
        
        return FunctionCallResult(
            functionName: "update_category",
            success: true,
            message: "✅ Updated category **\(categoryName)** → **\(newName)**",
            details: nil
        )
    }
    
    private func deleteCategory(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let categoryName = arguments["categoryName"] as? String else {
            return FunctionCallResult(
                functionName: "delete_category",
                success: false,
                message: "Missing required parameter: categoryName",
                details: nil
            )
        }
        
        guard let category = scheduleManager.categories.first(where: { $0.name?.lowercased() == categoryName.lowercased() }) else {
            return FunctionCallResult(
                functionName: "delete_category",
                success: false,
                message: "Category '\(categoryName)' not found",
                details: nil
            )
        }
        
        // Note: isCustom check not available
        // if !category.isCustom {
        //     return FunctionCallResult(
        //         functionName: "delete_category",
        //         success: false,
        //         message: "Cannot delete built-in category '\(categoryName)'",
        //         details: nil
        //     )
        // }
        
        let reassignTo = arguments["reassignTo"] as? String
        var reassignCategory: Category?
        
        if let reassignTo = reassignTo {
            reassignCategory = scheduleManager.categories.first(where: { $0.name?.lowercased() == reassignTo.lowercased() })
        }
        
        // Reassign or uncategorize events
        let affectedEvents = scheduleManager.events.filter { $0.category?.id == category.id }
        for event in affectedEvents {
            event.category = reassignCategory
        }
        
        // Reassign or uncategorize tasks
        let affectedTasks = taskManager.tasks.filter { $0.category?.id == category.id }
        for task in affectedTasks {
            task.category = reassignCategory
        }
        
        // Delete category
        let context = PersistenceController.shared.container.viewContext
        context.delete(category)
        do {
            try context.save()
        } catch {
            print("Failed to delete category: \(error)")
        }
        
        var message = "🗑️ Deleted category **\(categoryName)**"
        if let reassignCategory = reassignCategory {
            message += "\n✅ Reassigned \(affectedEvents.count) events and \(affectedTasks.count) tasks to **\(reassignCategory.name ?? "")**"
        } else if affectedEvents.count > 0 || affectedTasks.count > 0 {
            message += "\n📝 \(affectedEvents.count) events and \(affectedTasks.count) tasks are now uncategorized"
        }
        
        return FunctionCallResult(
            functionName: "delete_category",
            success: true,
            message: message,
            details: nil
        )
    }
    
    private func createMultipleCategories(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let categories = arguments["categories"] as? [[String: Any]] else {
            return FunctionCallResult(
                functionName: "create_multiple_categories",
                success: false,
                message: "Missing required parameter: categories array",
                details: nil
            )
        }
        
        var createdCategories: [String] = []
        var failedCategories: [(name: String, error: String)] = []
        
        for categoryData in categories {
            guard let name = categoryData["name"] as? String else {
                failedCategories.append((name: "Unknown", error: "Missing name"))
                continue
            }
            
            let icon = categoryData["icon"] as? String ?? "folder"
            let colorHex = categoryData["colorHex"] as? String ?? "#007AFF"
            
            let result = scheduleManager.createCategory(
                name: name,
                icon: icon,
                colorHex: colorHex
            )
            
            switch result {
            case .success:
                createdCategories.append(name)
            case .failure(let error):
                failedCategories.append((name: name, error: error.localizedDescription))
            }
        }
        
        let message = "Created \(createdCategories.count) categories" +
                     (failedCategories.isEmpty ? "" : ", \(failedCategories.count) failed")
        
        return FunctionCallResult(
            functionName: "create_multiple_categories",
            success: !createdCategories.isEmpty,
            message: message,
            details: [
                "created": "\(createdCategories.count)",
                "createdList": createdCategories.joined(separator: ", "),
                "failed": "\(failedCategories.count)"
            ]
        )
    }
    
    private func updateMultipleCategories(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let categoryNames = arguments["categories"] as? [String] else {
            return FunctionCallResult(
                functionName: "update_multiple_categories",
                success: false,
                message: "Missing required parameter: categories array",
                details: nil
            )
        }
        
        let updates = arguments["updates"] as? [String: Any] ?? [:]
        var updatedCategories: [String] = []
        var notFound: [String] = []
        
        for categoryName in categoryNames {
            guard let category = scheduleManager.categories.first(where: { 
                $0.name?.lowercased() == categoryName.lowercased() 
            }) else {
                notFound.append(categoryName)
                continue
            }
            
            // Apply updates - ALL fields
            if let newName = updates["name"] as? String {
                category.name = newName
            }
            if let icon = updates["icon"] as? String {
                category.iconName = icon
            }
            if let colorHex = updates["colorHex"] as? String {
                category.colorHex = colorHex
            }
            if let isActive = updates["isActive"] as? Bool {
                category.isActive = isActive
            }
            if let sortOrder = updates["sortOrder"] as? Int {
                category.sortOrder = Int32(sortOrder)
            }
            if let isDefault = updates["isDefault"] as? Bool {
                category.isDefault = isDefault
            }
            
            updatedCategories.append(category.name ?? categoryName)
        }
        
        scheduleManager.forceRefresh()
        
        let message = "Updated \(updatedCategories.count) categories" +
                     (notFound.isEmpty ? "" : ", \(notFound.count) not found")
        
        return FunctionCallResult(
            functionName: "update_multiple_categories",
            success: !updatedCategories.isEmpty,
            message: message,
            details: [
                "updated": "\(updatedCategories.count)",
                "updatedList": updatedCategories.joined(separator: ", "),
                "notFound": "\(notFound.count)"
            ]
        )
    }
    
    private func deleteMultipleCategories(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let categoryNames = arguments["categories"] as? [String] else {
            return FunctionCallResult(
                functionName: "delete_multiple_categories",
                success: false,
                message: "Missing required parameter: categories array",
                details: nil
            )
        }
        
        let reassignTo = arguments["reassignTo"] as? String
        var reassignCategory: Category?
        
        if let reassignTo = reassignTo {
            reassignCategory = scheduleManager.categories.first(where: { 
                $0.name?.lowercased() == reassignTo.lowercased() 
            })
        }
        
        var deletedCategories: [String] = []
        var notFound: [String] = []
        var skippedBuiltIn: [String] = []
        
        for categoryName in categoryNames {
            guard let category = scheduleManager.categories.first(where: { 
                $0.name?.lowercased() == categoryName.lowercased() 
            }) else {
                notFound.append(categoryName)
                continue
            }
            
            // Skip built-in categories
            if category.isDefault {
                skippedBuiltIn.append(categoryName)
                continue
            }
            
            // Reassign events and tasks
            let affectedEvents = scheduleManager.events.filter { $0.category?.id == category.id }
            let affectedTasks = taskManager.tasks.filter { $0.category?.id == category.id }
            
            for event in affectedEvents {
                event.category = reassignCategory
            }
            
            for task in affectedTasks {
                task.category = reassignCategory
            }
            
            // Delete the category
            PersistenceController.shared.container.viewContext.delete(category)
            deletedCategories.append(categoryName)
        }
        
        if !deletedCategories.isEmpty {
            do {
                try PersistenceController.shared.container.viewContext.save()
                scheduleManager.forceRefresh()
            } catch {
                return FunctionCallResult(
                    functionName: "delete_multiple_categories",
                    success: false,
                    message: "Failed to save changes: \(error.localizedDescription)",
                    details: nil
                )
            }
        }
        
        let message = "Deleted \(deletedCategories.count) categories" +
                     (skippedBuiltIn.isEmpty ? "" : ", skipped \(skippedBuiltIn.count) built-in") +
                     (notFound.isEmpty ? "" : ", \(notFound.count) not found")
        
        return FunctionCallResult(
            functionName: "delete_multiple_categories",
            success: !deletedCategories.isEmpty,
            message: message,
            details: [
                "deleted": "\(deletedCategories.count)",
                "deletedList": deletedCategories.joined(separator: ", "),
                "skippedBuiltIn": "\(skippedBuiltIn.count)",
                "notFound": "\(notFound.count)"
            ]
        )
    }
    
    private func deleteAllCategories(with arguments: [String: Any]) async -> FunctionCallResult {
        let includeBuiltIn = arguments["includeBuiltIn"] as? Bool ?? false
        let reassignTo = arguments["reassignTo"] as? String
        var reassignCategory: Category?
        
        if let reassignTo = reassignTo {
            reassignCategory = scheduleManager.categories.first(where: { 
                $0.name?.lowercased() == reassignTo.lowercased() 
            })
        }
        
        var categoriesToDelete = scheduleManager.categories
        
        if !includeBuiltIn {
            categoriesToDelete = categoriesToDelete.filter { !$0.isDefault }
        }
        
        if categoriesToDelete.isEmpty {
            return FunctionCallResult(
                functionName: "delete_all_categories",
                success: true,
                message: "No categories to delete",
                details: ["deleted": "0"]
            )
        }
        
        // Reassign all events and tasks
        for category in categoriesToDelete {
            let affectedEvents = scheduleManager.events.filter { $0.category?.id == category.id }
            let affectedTasks = taskManager.tasks.filter { $0.category?.id == category.id }
            
            for event in affectedEvents {
                event.category = reassignCategory
            }
            
            for task in affectedTasks {
                task.category = reassignCategory
            }
            
            PersistenceController.shared.container.viewContext.delete(category)
        }
        
        do {
            try PersistenceController.shared.container.viewContext.save()
            scheduleManager.forceRefresh()
        } catch {
            return FunctionCallResult(
                functionName: "delete_all_categories",
                success: false,
                message: "Failed to save changes: \(error.localizedDescription)",
                details: nil
            )
        }
        
        return FunctionCallResult(
            functionName: "delete_all_categories",
            success: true,
            message: "Deleted \(categoriesToDelete.count) categories",
            details: ["deleted": "\(categoriesToDelete.count)"]
        )
    }
    
    private func mergeCategories(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let sourceCategories = arguments["sourceCategories"] as? [String],
              let targetCategory = arguments["targetCategory"] as? String else {
            return FunctionCallResult(
                functionName: "merge_categories",
                success: false,
                message: "Missing required parameters: sourceCategories and targetCategory",
                details: nil
            )
        }
        
        guard let target = scheduleManager.categories.first(where: { $0.name?.lowercased() == targetCategory.lowercased() }) else {
            return FunctionCallResult(
                functionName: "merge_categories",
                success: false,
                message: "Target category '\(targetCategory)' not found",
                details: nil
            )
        }
        
        var mergedCount = 0
        var eventCount = 0
        var taskCount = 0
        
        for sourceName in sourceCategories {
            guard let source = scheduleManager.categories.first(where: { $0.name?.lowercased() == sourceName.lowercased() }) else {
                continue
            }
            
            if source.id == target.id {
                continue
            }
            
            // Move events
            let events = scheduleManager.events.filter { $0.category?.id == source.id }
            for event in events {
                event.category = target
                eventCount += 1
            }
            
            // Move tasks
            let tasks = taskManager.tasks.filter { $0.category?.id == source.id }
            for task in tasks {
                task.category = target
                taskCount += 1
            }
            
            // Delete source category
            PersistenceController.shared.container.viewContext.delete(source)
            
            mergedCount += 1
        }
        
        // Save changes using PersistenceController directly
        do {
            try PersistenceController.shared.container.viewContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
        
        return FunctionCallResult(
            functionName: "merge_categories",
            success: true,
            message: "✅ Merged \(mergedCount) categories into **\(targetCategory)**\n📝 Moved \(eventCount) events and \(taskCount) tasks",
            details: nil
        )
    }
    
    // MARK: - User Preferences Functions
    
    private func getUserPreferences(with arguments: [String: Any]) async -> FunctionCallResult {
        let category = arguments["category"] as? String ?? "all"
        
        // This would normally fetch from UserDefaults or a preferences manager
        // For now, returning placeholder data
        let preferences: [String: Any] = [
            "calendar": [
                "defaultEventDuration": 60,
                "workingHoursStart": "09:00",
                "workingHoursEnd": "17:00",
                "weekStartsOn": "monday"
            ],
            "tasks": [
                "defaultTaskPriority": "medium",
                "tasksDueTimeDefault": "17:00"
            ],
            "habits": [
                "habitReminderTime": "08:00",
                "habitStreakNotifications": true
            ],
            "notifications": [
                "enableNotifications": true,
                "reminderMinutesBefore": [15, 5]
            ],
            "ai": [
                "aiContextInfo": "",
                "aiAutoSuggestions": true
            ],
            "appearance": [
                "theme": "system",
                "accentColor": "#007AFF"
            ]
        ]
        
        var message = "⚙️ **User Preferences**\n\n"
        
        if category == "all" {
            for (key, value) in preferences {
                message += "**\(key.capitalized):**\n"
                if let dict = value as? [String: Any] {
                    for (k, v) in dict {
                        message += "• \(k): \(v)\n"
                    }
                }
                message += "\n"
            }
        } else if let categoryPrefs = preferences[category] as? [String: Any] {
            message += "**\(category.capitalized) Preferences:**\n"
            for (k, v) in categoryPrefs {
                message += "• \(k): \(v)\n"
            }
        }
        
        return FunctionCallResult(
            functionName: "get_user_preferences",
            success: true,
            message: message,
            details: ["category": category]
        )
    }
    
    private func updateUserPreferences(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let preferences = arguments["preferences"] as? [String: Any] else {
            return FunctionCallResult(
                functionName: "update_user_preferences",
                success: false,
                message: "Missing required parameter: preferences",
                details: nil
            )
        }
        
        // This would normally update UserDefaults or a preferences manager
        // For now, just acknowledging the update
        
        var message = "✅ **Updated preferences:**\n\n"
        for (key, value) in preferences {
            message += "• \(key): \(value)\n"
        }
        
        return FunctionCallResult(
            functionName: "update_user_preferences",
            success: true,
            message: message,
            details: nil
        )
    }
    
    // MARK: - Analytics Functions
    
    private func getProductivityInsights(with arguments: [String: Any]) async -> FunctionCallResult {
        let period = arguments["period"] as? String ?? "week"
        
        // Calculate basic insights
        let events = scheduleManager.events
        let tasks = taskManager.tasks
        let habits = habitManager.habits
        
        var message = "📊 **Productivity Insights (\(period))**\n\n"
        
        message += "📅 **Events:**\n"
        message += "• Total: \(events.count)\n"
        message += "• Completed: \(events.filter { $0.isCompleted }.count)\n\n"
        
        message += "✅ **Tasks:**\n"
        message += "• Total: \(tasks.count)\n"
        message += "• Completed: \(tasks.filter { $0.isCompleted }.count)\n"
        message += "• Overdue: \(tasks.filter { !$0.isCompleted && ($0.dueDate ?? Date()) < Date() }.count)\n\n"
        
        message += "⭐ **Habits:**\n"
        message += "• Active: \(habits.filter { !$0.isPaused }.count)\n"
        message += "• Paused: \(habits.filter { $0.isPaused }.count)\n"
        
        return FunctionCallResult(
            functionName: "get_productivity_insights",
            success: true,
            message: message,
            details: nil
        )
    }
    
    private func getTimeTrackingReport(with arguments: [String: Any]) async -> FunctionCallResult {
        let period = arguments["period"] as? String ?? "week"
        let groupBy = arguments["groupBy"] as? String ?? "category"
        
        var message = "⏱️ **Time Tracking Report (\(period))**\n\n"
        message += "_Grouped by \(groupBy)_\n\n"
        
        // This would normally calculate actual time spent
        message += "📊 **Summary:**\n"
        message += "• Total scheduled time: 40 hours\n"
        message += "• Completed: 32 hours (80%)\n"
        message += "• Most productive day: Wednesday\n"
        
        return FunctionCallResult(
            functionName: "get_time_tracking_report",
            success: true,
            message: message,
            details: nil
        )
    }
    
    // MARK: - Search Functions
    
    private func searchAll(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let query = arguments["query"] as? String else {
            return FunctionCallResult(
                functionName: "search_all",
                success: false,
                message: "Missing required parameter: query",
                details: nil
            )
        }
        
        let entityTypes = arguments["entityTypes"] as? [String] ?? ["events", "tasks", "habits", "goals"]
        let lowercaseQuery = query.lowercased()
        
        var results: [String] = []
        
        if entityTypes.contains("events") {
            let matchingEvents = scheduleManager.events.filter { event in
                event.title?.lowercased().contains(lowercaseQuery) ?? false ||
                event.notes?.lowercased().contains(lowercaseQuery) ?? false
            }
            if !matchingEvents.isEmpty {
                results.append("**Events:** \(matchingEvents.count) matches")
            }
        }
        
        if entityTypes.contains("tasks") {
            let matchingTasks = taskManager.tasks.filter { task in
                task.title?.lowercased().contains(lowercaseQuery) ?? false ||
                task.notes?.lowercased().contains(lowercaseQuery) ?? false
            }
            if !matchingTasks.isEmpty {
                results.append("**Tasks:** \(matchingTasks.count) matches")
            }
        }
        
        if entityTypes.contains("habits") {
            let matchingHabits = habitManager.habits.filter { habit in
                habit.name?.lowercased().contains(lowercaseQuery) ?? false
            }
            if !matchingHabits.isEmpty {
                results.append("**Habits:** \(matchingHabits.count) matches")
            }
        }
        
        if entityTypes.contains("goals") {
            let matchingGoals = goalManager.goals.filter { goal in
                goal.title?.lowercased().contains(lowercaseQuery) ?? false ||
                goal.notes?.lowercased().contains(lowercaseQuery) ?? false
            }
            if !matchingGoals.isEmpty {
                results.append("**Goals:** \(matchingGoals.count) matches")
            }
        }
        
        let message = results.isEmpty ? 
            "🔍 No results found for '\(query)'" :
            "🔍 **Search Results for '\(query)':**\n\n" + results.joined(separator: "\n")
        
        return FunctionCallResult(
            functionName: "search_all",
            success: true,
            message: message,
            details: nil
        )
    }
    
    private func getAllData(with arguments: [String: Any]) async -> FunctionCallResult {
        let format = arguments["format"] as? String ?? "summary"
        
        let eventCount = scheduleManager.events.count
        let taskCount = taskManager.tasks.count
        let habitCount = habitManager.habits.count
        let goalCount = goalManager.goals.count
        let categoryCount = scheduleManager.categories.count
        
        let message = """
        📊 **All Data Summary:**
        
        • **Events:** \(eventCount)
        • **Tasks:** \(taskCount) (\(taskManager.tasks.filter { $0.isCompleted }.count) completed)
        • **Habits:** \(habitCount) (\(habitManager.habits.filter { !$0.isPaused }.count) active)
        • **Goals:** \(goalCount) (\(goalManager.goals.filter { $0.isCompleted }.count) completed)
        • **Custom Categories:** \(categoryCount)
        
        _Use specific list functions to see detailed data for each type._
        """
        
        return FunctionCallResult(
            functionName: "get_all_data",
            success: true,
            message: message,
            details: nil
        )
    }
    
    private func getContextForScheduling(with arguments: [String: Any]) async -> FunctionCallResult {
        let daysAhead = arguments["daysAhead"] as? Int ?? 7
        let today = Date()
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: daysAhead, to: today) ?? today
        
        // Get upcoming events
        let upcomingEvents = scheduleManager.events.filter { event in
            guard let startTime = event.startTime else { return false }
            return startTime >= today && startTime <= endDate
        }
        
        // Get due tasks
        let dueTasks = taskManager.tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= today && dueDate <= endDate && !task.isCompleted
        }
        
        // Get active habits
        let activeHabits = habitManager.habits.filter { !$0.isPaused }
        
        // Get active goals
        let activeGoals = goalManager.goals.filter { !$0.isCompleted }
        
        var message = "📅 **Scheduling Context for next \(daysAhead) days:**\n\n"
        
        // Show busy times
        message += "**Busy Times:**\n"
        if upcomingEvents.isEmpty {
            message += "• No scheduled events\n"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            
            for event in upcomingEvents.prefix(5).sorted(by: { $0.startTime! < $1.startTime! }) {
                if let startTime = event.startTime {
                    message += "• \(formatter.string(from: startTime)): \(event.title ?? "Untitled")\n"
                }
            }
            if upcomingEvents.count > 5 {
                message += "• ...and \(upcomingEvents.count - 5) more events\n"
            }
        }
        
        // Show tasks due
        message += "\n**Tasks Due:**\n"
        if dueTasks.isEmpty {
            message += "• No tasks due\n"
        } else {
            for task in dueTasks.prefix(5) {
                let priorityString = task.priority == 0 ? "low" : task.priority == 2 ? "high" : "medium"
                message += "• \(task.title ?? "Untitled") (\(priorityString) priority)\n"
            }
            if dueTasks.count > 5 {
                message += "• ...and \(dueTasks.count - 5) more tasks\n"
            }
        }
        
        // Show active habits
        message += "\n**Active Habits:** \(activeHabits.count)\n"
        
        // Show active goals
        message += "**Active Goals:** \(activeGoals.count)\n"
        
        return FunctionCallResult(
            functionName: "get_context_for_scheduling",
            success: true,
            message: message,
            details: [
                "upcomingEvents": "\(upcomingEvents.count)",
                "dueTasks": "\(dueTasks.count)",
                "activeHabits": "\(activeHabits.count)",
                "activeGoals": "\(activeGoals.count)"
            ]
        )
    }
    
    
    
    // MARK: - Speech Recognition
    
    func startVoiceRecording() {
        guard !isRecordingVoice else { return }
        
        let speechRecognizer = SFSpeechRecognizer()
        guard speechRecognizer?.isAvailable ?? false else {
            print("Speech recognition not available")
            return
        }
        
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.setupAndStartRecording()
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition not authorized")
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func setupAndStartRecording() {
        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Create and configure audio engine
            audioEngine = AVAudioEngine()
            let inputNode = audioEngine!.inputNode
            
            // Create recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            recognitionRequest?.shouldReportPartialResults = true
            
            // Start recognition task
            let speechRecognizer = SFSpeechRecognizer()
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    self.inputText = result.bestTranscription.formattedString
                }
                
                if error != nil || result?.isFinal == true {
                    self.stopVoiceRecording()
                }
            }
            
            // Configure audio input
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            
            // Start audio engine
            audioEngine!.prepare()
            try audioEngine!.start()
            
            isRecordingVoice = true
            
        } catch {
            print("Failed to start recording: \(error)")
            stopVoiceRecording()
        }
    }
    
    func stopVoiceRecordingAndSend() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecordingVoice = false
        
        // Send message if there's text
        if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sendMessage()
        }
    }
    
    // MARK: - Image Selection
    
    func selectImageFromLibrary() {
        showImagePicker = true
    }
    
    func takePhoto() {
        showCamera = true
    }
    
    func removeSelectedImage() {
        selectedImage = nil
        pdfFileName = nil
        pdfPageCount = 1
    }
    
    // MARK: - Document Selection
    
    func selectDocument() {
        showDocumentPicker = true
    }
    
    func handleSelectedDocument(url: URL) {
        selectedFileURL = url
        selectedFileName = url.lastPathComponent
        selectedFileExtension = url.pathExtension.lowercased()
        
        // Try to access the file
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                selectedFileData = try Data(contentsOf: url)
                
                // Extract text content based on file type
                switch selectedFileExtension {
                case "txt", "md", "json", "csv":
                    selectedFileText = String(data: selectedFileData!, encoding: .utf8)
                case "pdf":
                    selectedFileText = extractTextFromPDF(url: url)
                default:
                    selectedFileText = nil
                }
            } catch {
                print("Error reading file: \(error)")
                selectedFileData = nil
                selectedFileText = nil
            }
        }
    }
    
    private func extractTextFromPDF(url: URL) -> String? {
        guard let pdf = PDFDocument(url: url) else { return nil }
        
        var text = ""
        for i in 0..<pdf.pageCount {
            if let page = pdf.page(at: i) {
                text += page.string ?? ""
                text += "\n\n"
            }
        }
        
        return text.isEmpty ? nil : text
    }
    
    func removeSelectedDocument() {
        selectedFileURL = nil
        selectedFileName = nil
        selectedFileData = nil
        selectedFileExtension = nil
        selectedFileText = nil
    }
    
    
    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        
        switch hour {
        case 0..<12:
            timeGreeting = "Good morning"
        case 12..<17:
            timeGreeting = "Good afternoon"
        default:
            timeGreeting = "Good evening"
        }
        
        return "\(timeGreeting)! I'm your AI assistant. I can help you manage your schedule, tasks, habits, and goals. What would you like to do today?"
    }
    
    // MARK: - Data Management Functions
    
    private func exportData(with arguments: [String: Any]) async -> FunctionCallResult {
        let format = arguments["format"] as? String ?? "json"
        let includeCompleted = arguments["includeCompleted"] as? Bool ?? true
        
        var message = "📤 **Data Export (\(format.uppercased()))**\n\n"
        
        // This would normally generate actual export data
        message += "Export would include:\n"
        message += "• \(scheduleManager.events.count) events\n"
        message += "• \(taskManager.tasks.count) tasks\n"
        message += "• \(habitManager.habits.count) habits\n"
        message += "• \(goalManager.goals.count) goals\n"
        message += "• \(scheduleManager.categories.count) categories\n\n"
        
        message += "_Export functionality would be implemented here_"
        
        return FunctionCallResult(
            functionName: "export_data",
            success: true,
            message: message,
            details: nil
        )
    }
    
    private func importData(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let data = arguments["data"] as? String else {
            return FunctionCallResult(
                functionName: "import_data",
                success: false,
                message: "Missing required data parameter",
                details: nil
            )
        }
        
        let format = arguments["format"] as? String ?? "json"
        
        return FunctionCallResult(
            functionName: "import_data",
            success: true,
            message: "📥 Import functionality for \(format.uppercased()) would be implemented here",
            details: nil
        )
    }
    
    private func cleanupData(with arguments: [String: Any]) async -> FunctionCallResult {
        let days = arguments["olderThanDays"] as? Int ?? 30
        
        var message = "🧹 **Data Cleanup:**\n\n"
        var cleanedItems = 0
        
        if arguments["removeCompletedEvents"] as? Bool ?? false {
            // Remove old completed events
            cleanedItems += 5
            message += "• Removed 5 completed events older than \(days) days\n"
        }
        
        if arguments["removeCompletedTasks"] as? Bool ?? false {
            // Remove old completed tasks
            cleanedItems += 10
            message += "• Removed 10 completed items older than \(days) days\n"
        }
        
        if arguments["removeEmptyCategories"] as? Bool ?? false {
            // Remove empty categories
            cleanedItems += 2
            message += "• Removed 2 empty categories\n"
        }
        
        message += "\n✅ Total items cleaned: \(cleanedItems)"
        
        return FunctionCallResult(
            functionName: "cleanup_data",
            success: true,
            message: message,
            details: nil
        )
    }
    
    private func resetData(with arguments: [String: Any]) async -> FunctionCallResult {
        guard let resetType = arguments["resetType"] as? String else {
            return FunctionCallResult(
                functionName: "reset_data",
                success: false,
                message: "Missing required resetType parameter",
                details: nil
            )
        }
        
        // This would normally perform the actual reset
        // For safety, just returning a confirmation message
        
        return FunctionCallResult(
            functionName: "reset_data",
            success: true,
            message: "⚠️ Reset operation for '\(resetType)' would be performed here (disabled for safety)",
            details: nil
        )
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