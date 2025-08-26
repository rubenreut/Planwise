import Foundation
import SwiftUI
import Combine
import Speech
import AVFoundation
import CoreData
import PhotosUI
import UIKit
import PDFKit

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
        setupInitialGreeting()
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
        var messageContent = inputText
}
