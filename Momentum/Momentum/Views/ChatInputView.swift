import SwiftUI

// MARK: - Chat Input View

struct ChatInputView: View {
    @Binding var text: String
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isKeyboardVisible: Bool
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @FocusState private var isTextFieldFocused: Bool
    @State private var showAttachmentMenu = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var attachedImage: UIImage?
    @State private var pulseAnimation = false
    @State private var isTabBarCollapsed = false
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    @State private var isRecording = false
    @State private var showingSuggestions = false
    @State private var messageAnimation = false
    
    // MARK: - Mathematical Constants
    
    private let φ: Double = 1.618033988749895
    private let baseUnit: Double = 8.0
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        Color.clear
    }
    
    private var borderColor: Color {
        isTextFieldFocused ? Color.fromAccentString(selectedAccentColor).opacity(0.5) : Color(UIColor.separator).opacity(0.3)
    }
    
    private var canSendMessage: Bool {
        subscriptionManager.canSendMessage()
    }
    
    @ViewBuilder
    private var recordingIndicator: some View {
        HStack {
            Image(systemName: "mic.fill")
                .scaledIcon()
                .foregroundColor(.red)
                .font(.system(size: 14))
            
            Text("Recording...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
            
            Spacer()
        }
        .padding(.horizontal, baseUnit * 2)
        .padding(.vertical, baseUnit / 2)
        .background(Color.red.opacity(0.1))
    }
    
    @ViewBuilder
    private var inputAreaContent: some View {
        HStack(spacing: baseUnit) {
            // Add button
            Button(action: {
                showAttachmentMenu.toggle()
            }) {
                Image(systemName: "plus.circle.fill")
                    .scaledIcon()
                    .scaledFont(size: 24)
                    .foregroundColor(Color.fromAccentString(selectedAccentColor))
                    .scaleEffect(showAttachmentMenu ? 0.9 : 1.0)
            }
            .accessibilityLabel("Add attachment")
            .accessibilityHint("Show attachment options")
            .animation(.spring(response: 0.3, dampingFraction: 0.86), value: showAttachmentMenu)
            
            // Text field container
            textFieldContainer
        }
        .padding(.horizontal, baseUnit * 2)
        .padding(.vertical, baseUnit)
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var textFieldContainer: some View {
        VStack(alignment: .leading, spacing: baseUnit) {
            attachmentPreviews
            messageInputField
        }
        .background(
            RoundedRectangle(cornerRadius: baseUnit * 2.5)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: baseUnit * 2.5)
                        .stroke(borderColor.opacity(0.3), lineWidth: 0.5)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            isTextFieldFocused = true
        }
    }
    
    @ViewBuilder
    private var attachmentPreviews: some View {
        Group {
            // Image preview
            if let image = viewModel.selectedImage {
                imagePreview(image)
            }
            
            // Document preview
            if let fileName = viewModel.selectedFileName,
               let fileExtension = viewModel.selectedFileExtension {
                documentPreview(fileName: fileName, fileExtension: fileExtension)
            }
        }
    }
    
    @ViewBuilder
    private var messageInputField: some View {
        HStack(spacing: baseUnit) {
            TextField(placeholderText, text: viewModel.isRecordingVoice ? $viewModel.inputText : $text, axis: .vertical)
                .font(.system(size: 16, weight: .regular, design: .default))
                .disabled(!canSendMessage)
                .tracking(-0.2)
                .textFieldStyle(.plain)
                .focused($isTextFieldFocused)
                .lineLimit(1...6)
                .onSubmit {
                    sendMessageWithImage()
                }
                .accessibilityLabel("Message input")
                .accessibilityHint(canSendMessage ? "Type your message to the assistant" : "Upgrade to premium to send messages")
            
            // Send or microphone button
            Button(action: handleSendButtonAction) {
                sendButtonContent
            }
            .accessibilityLabel(viewModel.isRecordingVoice ? "Stop recording" : (text.isEmpty ? "Voice input" : "Send message"))
            .accessibilityHint(viewModel.isRecordingVoice ? "Stop voice recording" : (text.isEmpty ? "Start voice recording" : "Send the typed message"))
        }
        .padding(.horizontal, baseUnit * 1.5)
        .padding(.vertical, baseUnit)
    }
    
    private var placeholderText: String {
        if viewModel.isRateLimited {
            return "Rate limited - please wait"
        } else if !canSendMessage {
            return "Upgrade to continue chatting"
        }
        return "Ask me anything..."
    }
    
    private func sendMessageWithImage() {
        let messageText = text  // Capture the text before clearing
        text = ""
        viewModel.inputText = messageText
        viewModel.sendMessage()
        
        // Ensure keyboard stays visible after sending
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTextFieldFocused = true
        }
    }
    
    @ViewBuilder
    private func imagePreview(_ image: UIImage) -> some View {
        HStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .cornerRadius(8)
                .overlay(
                    Button(action: {
                        viewModel.selectedImage = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .scaledIcon()
                            .scaledFont(size: 22)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    .offset(x: 10, y: -10),
                    alignment: .topTrailing
                )
            
            Spacer()
        }
        .padding(.horizontal, baseUnit * 1.5)
        .padding(.top, baseUnit)
    }
    
    @ViewBuilder
    private func documentPreview(fileName: String, fileExtension: String) -> some View {
        HStack {
            // Document icon
            VStack {
                Image(systemName: documentIcon(for: fileExtension))
                    .font(.system(size: 30))
                    .foregroundColor(documentColor(for: fileExtension))
                Text(fileExtension.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemFill))
            )
            .overlay(
                Button(action: {
                    viewModel.clearFileAttachment()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .scaledIcon()
                        .scaledFont(size: 22)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                }
                .offset(x: 10, y: -10),
                alignment: .topTrailing
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let fileData = viewModel.selectedFileData {
                    Text("\(String(format: "%.1f", Double(fileData.count) / 1024)) KB")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, baseUnit * 1.5)
        .padding(.top, baseUnit)
    }
    
    private func documentIcon(for extension: String) -> String {
        switch `extension`.lowercased() {
        case "pdf":
            return "doc.fill"
        case "doc", "docx":
            return "doc.richtext.fill"
        case "txt":
            return "doc.text.fill"
        default:
            return "doc.fill"
        }
    }
    
    private func documentColor(for extension: String) -> Color {
        switch `extension`.lowercased() {
        case "pdf":
            return .red
        case "doc", "docx":
            return Color.fromAccentString(selectedAccentColor)
        case "txt":
            return .gray
        default:
            return .orange
        }
    }
    
    private func handleSendButtonAction() {
        if viewModel.isRateLimited {
            // Don't do anything when rate limited
            return
        } else if !canSendMessage {
            viewModel.showPaywall = true
        } else if !subscriptionManager.isPremium && text.isEmpty && viewModel.selectedImage == nil && viewModel.selectedFileData == nil {
            // Free user trying to use voice - show paywall
            viewModel.showPaywall = true
        } else if viewModel.isRecordingVoice {
            // Always stop recording when recording is active
            viewModel.handleVoiceInput()
        } else if text.isEmpty && viewModel.selectedImage == nil && viewModel.selectedFileData == nil {
            // Start recording when no text/attachments
            viewModel.handleVoiceInput()
        } else {
            // Send message when there's content
            sendMessageWithImage()
        }
    }
    
    @ViewBuilder
    private var sendButtonContent: some View {
        if viewModel.isRateLimited {
            rateLimitedButton
        } else if viewModel.isRecordingVoice {
            recordingButton
        } else {
            defaultSendButton
        }
    }
    
    @ViewBuilder
    private var rateLimitedButton: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 32, height: 32)
            
            if let resetTime = viewModel.rateLimitResetTime {
                TimeText(targetTime: resetTime)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)
            } else {
                Image(systemName: "clock.fill")
                        .scaledIcon()
                    .scaledFont(size: 16)
                    .foregroundColor(.orange)
            }
        }
    }
    
    @ViewBuilder
    private var recordingButton: some View {
        RecordingButtonView(pulseAnimation: $pulseAnimation)
    }
    
    @ViewBuilder
    private var defaultSendButton: some View {
        if text.isEmpty && viewModel.selectedImage == nil && viewModel.selectedFileData == nil {
            microphoneButton
        } else {
            sendArrowButton
        }
    }
    
    @ViewBuilder
    private var microphoneButton: some View {
        ZStack {
            Circle()
                .fill(Color.fromAccentString(selectedAccentColor).opacity(0.1))
                .frame(width: 36, height: 36)
            
            Image(systemName: isRecording ? "mic.fill" : "mic")
                .scaledIcon()
                .scaledFont(size: 20, weight: .medium)
                .foregroundColor(Color.fromAccentString(selectedAccentColor))
                .symbolEffect(.pulse, value: isRecording)
        }
        .overlay(premiumBadgeOverlay)
        .scaleEffect(isRecording ? 1.2 : 1.0)
        .animation(.spring(response: 0.3), value: isRecording)
    }
    
    @ViewBuilder
    private var sendArrowButton: some View {
        Image(systemName: "arrow.up.circle.fill")
                        .scaledIcon()
                    .scaledFont(size: 26)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.fromAccentString(selectedAccentColor), Color.fromAccentString(selectedAccentColor).opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .scaleEffect(messageAnimation ? 1.1 : 1.0)
            .animation(.spring(response: 0.3), value: messageAnimation)
    }
    
    @ViewBuilder
    private var premiumBadgeOverlay: some View {
        if !subscriptionManager.isPremium && text.isEmpty && viewModel.selectedImage == nil && viewModel.selectedFileData == nil {
            Image(systemName: "crown.fill")
                        .scaledIcon()
                    .scaledFont(size: 10, weight: .bold)
                .foregroundColor(.white)
                .padding(3)
                .background(
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .shadow(color: Color.purple.opacity(0.3), radius: 2, x: 0, y: 1)
                )
                .offset(x: 12, y: -12)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Separator
            Divider()
            
            // Recording indicator
            if viewModel.isRecordingVoice {
                recordingIndicator
            }
            
            // Input area
            inputAreaContent
        }
        .background(Color.clear) // Make entire view background transparent
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TabBarCollapseChanged"))) { notification in
            if let userInfo = notification.userInfo,
               let collapsed = userInfo["isCollapsed"] as? Bool {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isTabBarCollapsed = collapsed
                }
            }
        }
        .sheet(isPresented: $showAttachmentMenu) {
            AttachmentMenuView(viewModel: viewModel)
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .onChange(of: viewModel.inputText) { _, newValue in
            // Sync voice transcription to the text field
            if viewModel.isRecordingVoice {
                text = newValue
            }
        }
    }
}

// MARK: - Attachment Menu View

struct AttachmentMenuView: View {
    @ObservedObject var viewModel: ChatViewModel
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private let baseUnit: Double = 8.0
    private let φ: Double = 1.618033988749895
    
    var body: some View {
        VStack(spacing: baseUnit * 2) {
            HStack(spacing: baseUnit * 4) {
                // Camera
                AttachmentButton(
                    icon: "camera.fill",
                    title: "Camera",
                    color: .blue,
                    showPremium: !subscriptionManager.isPremium
                ) {
                    viewModel.handleCameraAttachment()
                    dismiss()
                }
                
                // Photos
                AttachmentButton(
                    icon: "photo.fill",
                    title: "Photos",
                    color: .green
                ) {
                    viewModel.handleImageAttachment()
                    dismiss()
                }
                
                // Files
                AttachmentButton(
                    icon: "doc.fill",
                    title: "Files",
                    color: .orange
                ) {
                    viewModel.handleFileAttachment()
                    dismiss()
                }
            }
            .padding(.top, baseUnit * 3)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }
}

// MARK: - Attachment Button

struct AttachmentButton: View {
    let icon: String
    let title: String
    let color: Color
    var showPremium: Bool = false
    let action: () -> Void
    
    @State private var isPressed = false
    private let baseUnit: Double = 8.0
    private let φ: Double = 1.618033988749895
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: baseUnit) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: baseUnit * 7, height: baseUnit * 7)
                        .overlay(
                            Image(systemName: icon)
                        .scaledIcon()
                    .scaledFont(size: 24)
                                .foregroundColor(color)
                        )
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                    
                    // Premium badge
                    if showPremium {
                        Image(systemName: "crown.fill")
                        .scaledIcon()
                    .scaledFont(size: 12, weight: .bold)
                            .foregroundColor(.white)
                            .padding(3)
                            .background(
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Color.purple, Color.pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            )
                            .offset(x: baseUnit * 2.5, y: -baseUnit * 2.5)
                    }
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(.primary)
                    .tracking(-0.2)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Time Text View

struct TimeText: View {
    let targetTime: Date
    @State private var timeRemaining = ""
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(timeRemaining)
            .onAppear {
                updateTime()
            }
            .onReceive(timer) { _ in
                updateTime()
            }
    }
    
    private func updateTime() {
        let interval = targetTime.timeIntervalSinceNow
        if interval <= 0 {
            timeRemaining = "0s"
        } else if interval < 60 {
            timeRemaining = "\(Int(interval))s"
        } else {
            let minutes = Int(interval / 60)
            timeRemaining = "\(minutes)m"
        }
    }
}

// MARK: - Preview

// MARK: - Recording Button View

struct RecordingButtonView: View {
    @Binding var pulseAnimation: Bool
    
    var body: some View {
        ZStack {
            // Outer pulsing ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.red, Color.red.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                .opacity(pulseAnimation ? 0.0 : 0.8)
                .animation(
                    Animation.easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false),
                    value: pulseAnimation
                )
                .frame(width: 36, height: 36)
            
            // Middle pulsing ring
            Circle()
                .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                .scaleEffect(pulseAnimation ? 1.3 : 0.9)
                .opacity(pulseAnimation ? 0.0 : 0.6)
                .animation(
                    Animation.easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(0.5),
                    value: pulseAnimation
                )
                .frame(width: 36, height: 36)
            
            // Main button
            mainButton
        }
        .onAppear {
            withAnimation {
                pulseAnimation = true
            }
        }
        .onDisappear {
            pulseAnimation = false
        }
    }
    
    @ViewBuilder
    private var mainButton: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.red, Color.red.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
                .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 2)
            
            // Stop icon
            Image(systemName: "stop.fill")
                        .scaledIcon()
                    .scaledFont(size: 14, weight: .bold)
                .foregroundColor(.white)
        }
    }
}

#Preview {
    VStack {
        Spacer()
        ChatInputView(text: .constant(""), viewModel: ChatViewModel(), isKeyboardVisible: .constant(false))
    }
    .background(Color.clear)
}