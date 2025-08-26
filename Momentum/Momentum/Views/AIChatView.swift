import SwiftUI
import PhotosUI
import Combine

// MARK: - Unified AI Chat View

struct AIChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dependencyContainer) private var container
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showingSettings = false
    @State private var extractedColors: (primary: Color, secondary: Color)? = nil
    @State private var isUserScrolling = false
    @State private var lastMessageCount = 0
    @State private var quickSuggestions: [String] = []
    
    init() {
        _viewModel = StateObject(wrappedValue: ChatViewModel())
    }
    
    // MARK: - Platform Detection
    
    private var deviceType: DeviceType {
        #if targetEnvironment(macCatalyst)
        return .mac
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPad
        } else {
            return .iPhone
        }
        #endif
    }
    
    private enum DeviceType {
        case iPhone, iPad, mac
    }
    
    // MARK: - Adaptive Layout Properties
    
    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }
    
    private var maxChatWidth: CGFloat {
        switch deviceType {
        case .iPhone:
            return .infinity
        case .iPad:
            return isCompact ? .infinity : 800
        case .mac:
            return 800
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch deviceType {
        case .iPhone:
            return 0
        case .iPad:
            return isCompact ? 0 : DesignSystem.Spacing.md
        case .mac:
            return DesignSystem.Spacing.lg
        }
    }
    
    private var messageSpacing: CGFloat {
        switch deviceType {
        case .iPhone:
            return DesignSystem.Spacing.sm
        case .iPad:
            return DesignSystem.Spacing.md - 4
        case .mac:
            return DesignSystem.Spacing.md
        }
    }
    
    private var showsScrollIndicators: Bool {
        deviceType == .mac
    }
    
    private var navigationTitle: String {
        switch deviceType {
        case .iPhone, .iPad:
            return "Planwise Assistant"
        case .mac:
            return "AI Assistant"
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if deviceType == .mac {
                macLayout
            } else {
                iOSLayout
            }
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePicker(image: $viewModel.selectedImage) { image in
                if let image = image {
                    viewModel.processSelectedImage(image)
                }
            }
        }
        .sheet(isPresented: $viewModel.showCamera) {
            CameraPicker(image: $viewModel.selectedImage) { image in
                if let image = image {
                    viewModel.processSelectedImage(image)
                }
            }
        }
        .sheet(isPresented: $viewModel.showDocumentPicker) {
            DocumentPicker(isPresented: $viewModel.showDocumentPicker) { url in
                viewModel.processSelectedFile(url)
            }
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallViewPremium()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            // Load extracted colors from header image
            self.extractedColors = UserDefaults.standard.getExtractedColors()
            
            // If no colors saved but we have an image, extract them
            if extractedColors == nil, let headerData = AppearanceSettingsViewModel.loadHeaderImage() {
                let colors = ColorExtractor.extractColors(from: headerData.image)
                UserDefaults.standard.setExtractedColors(colors)
                self.extractedColors = (colors.primary, colors.secondary)
            }
            
            // Generate initial quick suggestions
            updateQuickSuggestions()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
    
    // MARK: - Quick Suggestions
    
    private func updateQuickSuggestions() {
        withAnimation(.spring()) {
            if viewModel.messages.isEmpty {
                // Initial suggestions
                quickSuggestions = [
                    "What's on my schedule today?",
                    "Create a new task",
                    "Show my habits"
                ]
            } else if let lastMessage = viewModel.messages.last {
                // Context-based suggestions
                let content = lastMessage.content.lowercased()
                
                if content.contains("task") || content.contains("todo") {
                    quickSuggestions = [
                        "Show my tasks",
                        "Create high priority task",
                        "Mark tasks complete"
                    ]
                } else if content.contains("schedule") || content.contains("calendar") {
                    quickSuggestions = [
                        "Show tomorrow's schedule",
                        "Add event",
                        "Check next week"
                    ]
                } else if content.contains("habit") {
                    quickSuggestions = [
                        "Log habit completion",
                        "View habit streaks",
                        "Create new habit"
                    ]
                } else if content.contains("goal") {
                    quickSuggestions = [
                        "Show my goals",
                        "Update goal progress",
                        "Set new goal"
                    ]
                } else {
                    // Default contextual suggestions
                    quickSuggestions = [
                        "What should I focus on?",
                        "Show my progress",
                        "Plan my day"
                    ]
                }
            } else {
                quickSuggestions = []
            }
        }
    }
    
    // MARK: - iOS/iPadOS Layout
    
    @ViewBuilder
    private var iOSLayout: some View {
        VStack(spacing: 0) {
            // Simple modal layout
            chatContent
                .frame(maxWidth: maxChatWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemGroupedBackground))
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        // Quick action suggestions
                        if !quickSuggestions.isEmpty && !viewModel.isLoading {
                            QuickActionButtons(
                                suggestions: quickSuggestions,
                                onSelect: { suggestion in
                                    viewModel.inputText = suggestion
                                    viewModel.sendMessage()
                                    quickSuggestions = []
                                }
                            )
                            .padding(.vertical, 8)
                            .background(Color(UIColor.systemBackground).opacity(0.95))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        chatInputView
                            .background(Color(UIColor.systemBackground))
                    }
                }
        }
    }
    
    // MARK: - macOS Layout
    
    @ViewBuilder
    private var macLayout: some View {
        VStack(spacing: 0) {
            // Mac header
            macHeader
            
            Divider()
            
            // Chat content
            chatContent
        }
        .background(DesignSystem.Colors.background)
    }
    
    // MARK: - Mac Header
    
    @ViewBuilder
    private var macHeader: some View {
        HStack {
            Image(systemName: "cpu")
                .scaledIcon()
                .scaledFont(size: DesignSystem.IconSize.sm, weight: .medium)
                .foregroundColor(.purple)
            
            Text(navigationTitle)
                .font(DesignSystem.Typography.headline)
            
            Spacer()
            
            // Message limit indicator for Mac
            if !subscriptionManager.isPremium && subscriptionManager.remainingFreeMessages <= 5 {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .scaledIcon()
                        .scaledFont(size: DesignSystem.IconSize.xs)
                        .foregroundColor(DesignSystem.Colors.warning)
                    Text("\(subscriptionManager.remainingFreeMessages) messages left")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.warning.opacity(DesignSystem.Opacity.light))
                )
            }
            
            Button(action: {
                showingSettings = true
            }) {
                Image(systemName: "gear")
                    .scaledIcon()
                    .scaledFont(size: DesignSystem.IconSize.sm)
                    .foregroundColor(DesignSystem.Colors.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md - 4)
        .background(DesignSystem.Colors.secondaryBackground)
    }
    
    // MARK: - Chat Content
    
    @ViewBuilder
    private var chatContent: some View {
        // Messages area
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: showsScrollIndicators) {
                LazyVStack(spacing: messageSpacing) {
                    // Empty state
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        emptyState
                    }
                    
                    // Add top padding
                    Color.clear.frame(height: DesignSystem.Spacing.md)
                    
                    ForEach(viewModel.messages) { message in
                        messageView(for: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .push(from: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    
                    // Typing indicator
                    if viewModel.isTypingIndicatorVisible {
                        typingIndicator
                            .id("typing-indicator")
                            .transition(.asymmetric(
                                insertion: .push(from: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    
                    // Bottom padding - adjusted for keyboard and input
                    Color.clear
                        .frame(height: 20) // Minimal padding since input is outside scroll
                        .id("bottom-anchor")
                }
                .padding(.horizontal, horizontalPadding)
            }
            .onAppear {
                scrollProxy = proxy
                lastMessageCount = viewModel.messages.count
            }
            .onChange(of: viewModel.messages.count) { oldCount, newCount in
                // Only auto-scroll if user sent a message (count increased) and not manually scrolling
                if newCount > oldCount && !isUserScrolling {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("bottom-anchor", anchor: .bottom)
                        }
                    }
                }
                lastMessageCount = newCount
                
                // Update suggestions based on conversation
                updateQuickSuggestions()
            }
            .onChange(of: viewModel.isTypingIndicatorVisible) { _, isVisible in
                if isVisible && !isUserScrolling {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("typing-indicator", anchor: .bottom)
                    }
                }
            }
            .onTapGesture {
                // Dismiss keyboard when tapping on the chat area
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in
                        isUserScrolling = true
                    }
                    .onEnded { _ in
                        // Reset user scrolling flag after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            isUserScrolling = false
                        }
                    }
            )
        }
        .overlay {
            // Loading overlay
            if viewModel.isLoading && viewModel.messages.isEmpty {
                LoadingView(
                    message: "Preparing your assistant...",
                    style: .dots
                )
                .transition(.opacity)
            }
        }
        
        // Message limit indicator
        if shouldShowMessageLimit {
            MessageLimitIndicator(
                remaining: subscriptionManager.remainingFreeMessages,
                onUpgrade: {
                    viewModel.showPaywall = true
                },
                subscriptionManager: subscriptionManager
            )
            .padding(.horizontal, deviceType == .mac ? DesignSystem.Spacing.lg : horizontalPadding)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        
        // Rate limit warning
        if viewModel.showRateLimitWarning {
            RateLimitWarningView(rateLimitInfo: viewModel.rateLimitInfo)
                .padding(.horizontal, deviceType == .mac ? DesignSystem.Spacing.lg : horizontalPadding)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
        
        // Error banner for connection issues
        if viewModel.isRateLimited {
            ErrorBanner(
                title: "Rate Limited",
                message: "Too many requests. Please wait a moment before trying again.",
                type: .warning,
                showIcon: true
            )
            .padding(.horizontal, deviceType == .mac ? DesignSystem.Spacing.lg : horizontalPadding)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
    // MARK: - Message View
    
    @ViewBuilder
    private func messageView(for message: ChatMessage) -> some View {
        if deviceType == .mac {
            MacMessageBubble(
                message: message,
                acceptedEventIds: viewModel.acceptedEventIds,
                deletedEventIds: viewModel.deletedEventIds,
                acceptedMultiEventMessageIds: viewModel.acceptedMultiEventMessageIds,
                completedBulkActionIds: viewModel.completedBulkActionIds,
                onRetry: message.error != nil ? { 
                    HapticFeedback.light.trigger()
                    viewModel.retryLastMessage() 
                } : nil,
                onEventAction: { eventId, action in
                    viewModel.handleEventAction(eventId: eventId, action: action)
                },
                onMultiEventAction: { action, messageId in
                    viewModel.handleMultiEventAction(action, messageId: messageId)
                },
                onBulkAction: { messageId, action in
                    viewModel.handleBulkAction(action, for: messageId.uuidString)
                }
            )
        } else {
            MessageBubbleView(
                message: message,
                acceptedEventIds: viewModel.acceptedEventIds,
                deletedEventIds: viewModel.deletedEventIds,
                acceptedMultiEventMessageIds: viewModel.acceptedMultiEventMessageIds,
                completedBulkActionIds: viewModel.completedBulkActionIds,
                onRetry: message.error != nil ? { 
                    HapticFeedback.light.trigger()
                    viewModel.retryLastMessage() 
                } : nil,
                onEventAction: { eventId, action in
                    viewModel.handleEventAction(eventId: eventId, action: action)
                },
                onMultiEventAction: { action, messageId in
                    viewModel.handleMultiEventAction(action, messageId: messageId)
                },
                onBulkAction: { messageId, action in
                    viewModel.handleBulkAction(action, for: messageId.uuidString)
                }
            )
        }
    }
    
    // MARK: - Typing Indicator
    
    @ViewBuilder
    private var typingIndicator: some View {
        HStack {
            if viewModel.isTypingIndicatorVisible {
                AnimatedTypingIndicator()
                    .padding(.vertical, 8)
            }
            Spacer()
        }
    }
    
    // MARK: - Chat Input View
    
    @ViewBuilder
    private var chatInputView: some View {
        if deviceType == .mac {
            Divider()
            MacChatInput(text: $viewModel.inputText, viewModel: viewModel)
        } else {
            ChatInputView(text: $viewModel.inputText, viewModel: viewModel, isKeyboardVisible: .constant(false))
        }
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyState: some View {
        ChatEmptyStateView(onPromptSelect: { prompt in
            // Remove emoji from prompt before sending
            let cleanPrompt = prompt.replacingOccurrences(of: "📅 ", with: "")
                .replacingOccurrences(of: "✅ ", with: "")
                .replacingOccurrences(of: "🎯 ", with: "")
                .replacingOccurrences(of: "📊 ", with: "")
                .replacingOccurrences(of: "💡 ", with: "")
            viewModel.inputText = cleanPrompt
            viewModel.sendMessage()
        })
        .frame(maxHeight: 600)
        .errorOverlay(
            error: viewModel.rateLimitResetTime != nil ? NetworkError.serverError(429) : nil,
            retry: {
                viewModel.showRateLimitWarning = false
                viewModel.isRateLimited = false
            }
        )
    }
    
    // MARK: - Helper Properties
    
    private var shouldShowMessageLimit: Bool {
        (!subscriptionManager.isPremium && subscriptionManager.remainingFreeMessages <= 5) ||
        (subscriptionManager.isPremium && (subscriptionManager.remainingTextMessages < 50 || subscriptionManager.remainingImageMessages < 5))
    }
}

// MARK: - Mac Message Bubble

struct MacMessageBubble: View {
    let message: ChatMessage
    let acceptedEventIds: Set<String>
    let deletedEventIds: Set<String>
    let acceptedMultiEventMessageIds: Set<UUID>
    let completedBulkActionIds: Set<String>
    var onRetry: (() -> Void)?
    var onEventAction: ((String, EventAction) -> Void)?
    var onMultiEventAction: ((MultiEventAction, UUID) -> Void)?
    var onBulkAction: ((UUID, BulkActionPreview.BulkAction) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            if !message.sender.isUser {
                // AI Avatar
                Circle()
                    .fill(Color.purple.opacity(DesignSystem.Opacity.light))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "cpu")
                            .scaledIcon()
                            .scaledFont(size: DesignSystem.IconSize.sm)
                            .foregroundColor(.purple)
                    )
            }
            
            VStack(alignment: message.sender.isUser ? .trailing : .leading, spacing: DesignSystem.Spacing.xxs) {
                // Check if this is a function call card message
                if message.eventPreview != nil || message.multipleEventsPreview != nil || message.bulkActionPreview != nil {
                    // Render event previews without bubble background
                    Group {
                        if let eventPreview = message.eventPreview {
                            EventPreviewView(
                                event: eventPreview,
                                isAccepted: acceptedEventIds.contains(eventPreview.id),
                                isDeleted: deletedEventIds.contains(eventPreview.id),
                                onAction: { action in
                                    onEventAction?(eventPreview.id, action)
                                }
                            )
                        }
                        
                        if let multipleEventsPreview = message.multipleEventsPreview {
                            MultipleEventsPreviewView(
                                events: multipleEventsPreview,
                                isAccepted: acceptedMultiEventMessageIds.contains(message.id),
                                onAction: { action in
                                    onMultiEventAction?(action, message.id)
                                }
                            )
                        }
                        
                        if let bulkActionPreview = message.bulkActionPreview {
                            BulkActionPreviewView(
                                preview: bulkActionPreview,
                                isCompleted: completedBulkActionIds.contains(bulkActionPreview.id),
                                onAction: { action in
                                    onBulkAction?(message.id, action)
                                }
                            )
                        }
                    }
                    .frame(maxWidth: 500, alignment: message.sender.isUser ? .trailing : .leading)
                } else {
                    // Regular message content
                    Text(message.content)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(message.sender.isUser ? .white : DesignSystem.Colors.primary)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(message.sender.isUser ? DesignSystem.Colors.accent : DesignSystem.Colors.secondaryFill)
                        )
                        .frame(maxWidth: 500, alignment: message.sender.isUser ? .trailing : .leading)
                }
                
                // Timestamp
                Text(formatTime(message.timestamp))
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.secondary)
                
                // Error state
                if message.error != nil {
                    Button(action: { onRetry?() }) {
                        HStack(spacing: DesignSystem.Spacing.xxs) {
                            Image(systemName: "exclamationmark.circle")
                                .scaledIcon()
                            Text("Failed. Tap to retry")
                        }
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(DesignSystem.Colors.error)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if message.sender.isUser {
                Spacer(minLength: 40)
            } else {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Mac Typing Indicator

struct MacTypingIndicator: View {
    @State private var animationPhase = 0.0
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Circle()
                .fill(Color.purple.opacity(DesignSystem.Opacity.light))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "cpu")
                        .scaledIcon()
                        .scaledFont(size: DesignSystem.IconSize.sm)
                        .foregroundColor(.purple)
                )
            
            HStack(spacing: DesignSystem.Spacing.xxs) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(DesignSystem.Colors.secondary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(animationScale(for: index))
                        .opacity(animationOpacity(for: index))
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.secondaryFill)
            )
            
            Spacer()
        }
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                animationPhase = 1.0
            }
        }
    }
    
    private func animationScale(for index: Int) -> Double {
        let progress = (animationPhase + Double(index) * 0.33).truncatingRemainder(dividingBy: 1.0)
        let scale = sin(progress * .pi)
        return 0.5 + scale * 0.5
    }
    
    private func animationOpacity(for index: Int) -> Double {
        let progress = (animationPhase + Double(index) * 0.33).truncatingRemainder(dividingBy: 1.0)
        let opacity = sin(progress * .pi)
        return 0.3 + opacity * 0.7
    }
}

// MARK: - Mac Chat Input

struct MacChatInput: View {
    @Binding var text: String
    @ObservedObject var viewModel: ChatViewModel
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @FocusState private var isTextFieldFocused: Bool
    @State private var showAttachmentMenu = false
    
    private var canSendMessage: Bool {
        subscriptionManager.canSendMessage()
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Attachment button
            Button(action: {
                showAttachmentMenu.toggle()
            }) {
                Image(systemName: "paperclip")
                    .scaledIcon()
                    .scaledFont(size: DesignSystem.IconSize.sm)
                    .foregroundColor(DesignSystem.Colors.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showAttachmentMenu) {
                MacAttachmentMenu(viewModel: viewModel)
            }
            
            // Text field
            HStack {
                TextField("Type a message...", text: $text, axis: .vertical)
                    .font(DesignSystem.Typography.callout)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isTextFieldFocused)
                    .disabled(!canSendMessage || viewModel.isRateLimited)
                    .onSubmit {
                        if !text.isEmpty && canSendMessage {
                            sendMessage()
                        }
                    }
                
                // Send button
                Button(action: {
                    if viewModel.isRateLimited || !canSendMessage {
                        viewModel.showPaywall = true
                    } else if text.isEmpty && !subscriptionManager.isPremium {
                        viewModel.showPaywall = true
                    } else if !text.isEmpty {
                        sendMessage()
                    } else {
                        viewModel.handleVoiceInput()
                    }
                }) {
                    Image(systemName: text.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                        .scaledIcon()
                        .scaledFont(size: DesignSystem.IconSize.lg)
                        .foregroundColor(text.isEmpty ? DesignSystem.Colors.secondary : DesignSystem.Colors.accent)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isRateLimited || !canSendMessage)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                    .fill(DesignSystem.Colors.secondaryFill)
            )
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
    }
    
    private func sendMessage() {
        let messageText = text
        text = ""
        viewModel.inputText = messageText
        viewModel.sendMessage()
        
        // Keep focus on text field after sending
        isTextFieldFocused = true
    }
}

// MARK: - Mac Attachment Menu

struct MacAttachmentMenu: View {
    @ObservedObject var viewModel: ChatViewModel
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Attachment")
                    .font(DesignSystem.Typography.footnote.weight(.medium))
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            
            Divider()
            
            VStack(spacing: DesignSystem.Spacing.xxs) {
                MacAttachmentOption(
                    icon: "camera.fill",
                    title: "Take Photo",
                    isPremium: !subscriptionManager.isPremium
                ) {
                    viewModel.handleCameraAttachment()
                    dismiss()
                }
                
                MacAttachmentOption(
                    icon: "photo.fill",
                    title: "Choose Photo"
                ) {
                    viewModel.handleImageAttachment()
                    dismiss()
                }
                
                MacAttachmentOption(
                    icon: "doc.fill",
                    title: "Choose File"
                ) {
                    viewModel.handleFileAttachment()
                    dismiss()
                }
            }
            .padding(DesignSystem.Spacing.sm)
        }
        .frame(width: 200)
    }
}

// MARK: - Mac Attachment Option

struct MacAttachmentOption: View {
    let icon: String
    let title: String
    var isPremium: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .scaledIcon()
                    .scaledFont(size: DesignSystem.IconSize.sm)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .frame(width: DesignSystem.IconSize.md)
                
                Text(title)
                    .font(DesignSystem.Typography.footnote)
                
                Spacer()
                
                if isPremium {
                    Image(systemName: "crown.fill")
                        .scaledIcon()
                        .scaledFont(size: DesignSystem.IconSize.xs - 2)
                        .foregroundColor(DesignSystem.Colors.warning)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs)
                .fill(Color.clear)
        )
    }
}

// MARK: - Typing Indicator View

struct TypingIndicatorView: View {
    @State private var animationPhase = 0.0
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Planwise Assistant")
                    .font(DesignSystem.Typography.caption2.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .tracking(-0.2)
                
                HStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(DesignSystem.Colors.secondary)
                            .frame(width: DesignSystem.Spacing.sm, height: DesignSystem.Spacing.sm)
                            .scaleEffect(animationScale(for: index))
                            .opacity(animationOpacity(for: index))
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.1),
                            radius: DesignSystem.Spacing.xs,
                            x: 0,
                            y: 2
                        )
                )
            }
            
            Spacer(minLength: DesignSystem.Spacing.xl)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                animationPhase = 1.0
            }
        }
    }
    
    private func animationScale(for index: Int) -> Double {
        let progress = (animationPhase + Double(index) * 0.33).truncatingRemainder(dividingBy: 1.0)
        let scale = sin(progress * .pi)
        return 0.5 + scale * 0.5
    }
    
    private func animationOpacity(for index: Int) -> Double {
        let progress = (animationPhase + Double(index) * 0.33).truncatingRemainder(dividingBy: 1.0)
        let opacity = sin(progress * .pi)
        return 0.3 + opacity * 0.7
    }
}

// MARK: - Rate Limit Warning View

struct RateLimitWarningView: View {
    let rateLimitInfo: RateLimitInfo?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .scaledIcon()
                .scaledFont(size: DesignSystem.IconSize.sm)
                .foregroundColor(DesignSystem.Colors.warning)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Rate Limit Warning")
                    .font(DesignSystem.Typography.footnote.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                if let info = rateLimitInfo {
                    Text("\(info.remaining) of \(info.limit) requests remaining")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
            }
            
            Spacer()
            
            if let info = rateLimitInfo {
                Text(timeUntilReset(info.resetTime))
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.secondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(DesignSystem.Colors.warning.opacity(DesignSystem.Opacity.light))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .stroke(DesignSystem.Colors.warning.opacity(DesignSystem.Opacity.medium), lineWidth: 1)
                )
        )
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
    
    private func timeUntilReset(_ resetTime: Date) -> String {
        let interval = resetTime.timeIntervalSinceNow
        if interval <= 0 {
            return "Resets now"
        }
        
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "Resets in \(minutes)m"
        }
        
        let hours = minutes / 60
        return "Resets in \(hours)h"
    }
}

// MARK: - Message Limit Indicator

struct MessageLimitIndicator: View {
    let remaining: Int
    let onUpgrade: () -> Void
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "dollarsign.circle")
                .scaledIcon()
                .scaledFont(size: DesignSystem.IconSize.sm)
                .foregroundColor(DesignSystem.Colors.accent)
            
            Text(subscriptionManager.dailyLimitDescription)
                .font(DesignSystem.Typography.footnote.weight(.medium))
                .foregroundColor(DesignSystem.Colors.primary)
            
            Spacer()
            
            if !subscriptionManager.isPremium {
                Button(action: onUpgrade) {
                    Text("Upgrade")
                        .font(DesignSystem.Typography.caption1.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.accent)
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(DesignSystem.Colors.accent.opacity(DesignSystem.Opacity.light))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .stroke(DesignSystem.Colors.accent.opacity(DesignSystem.Opacity.medium), lineWidth: 1)
                )
        )
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - Preview

#Preview {
    AIChatView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    AIChatView()
        .preferredColorScheme(.dark)
}

#Preview("iPad") {
    AIChatView()
        .environment(\.horizontalSizeClass, .regular)
        // Use device picker at bottom of Canvas instead
}