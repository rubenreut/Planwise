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
    
    // MARK: - Mathematical Constants
    
    private let φ: Double = 1.618033988749895
    private let baseUnit: Double = 8.0
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        Color.clear
    }
    
    private var borderColor: Color {
        Color(UIColor.separator).opacity(0.3)
    }
    
    private var canSendMessage: Bool {
        subscriptionManager.canSendMessage()
    }
    
    private var placeholderText: String {
        if viewModel.isRateLimited {
            return "Rate limited - please wait"
        } else if !canSendMessage {
            return "Upgrade to continue chatting"
        }
        return "Message"
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
            return .blue
        case "txt":
            return .gray
        default:
            return .orange
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Separator
            Rectangle()
                .fill(Color(UIColor.separator).opacity(0.2))
                .frame(height: 1)
            
            // Recording indicator
            if viewModel.isRecordingVoice {
                HStack {
                    Image(systemName: "mic.fill")
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
            
            // Input area
            HStack(spacing: baseUnit) {
                // Add button
                Button(action: {
                    showAttachmentMenu.toggle()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                        .scaleEffect(showAttachmentMenu ? 0.9 : 1.0)
                }
                .accessibilityLabel("Add attachment")
                .accessibilityHint("Show attachment options")
                .animation(.spring(response: 0.3, dampingFraction: 0.86), value: showAttachmentMenu)
                
                // Text field container
                VStack(alignment: .leading, spacing: baseUnit) {
                    // Attached image preview
                    if let image = viewModel.selectedImage {
                        HStack {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                                .overlay(
                                    // X button to remove
                                    Button(action: {
                                        viewModel.selectedImage = nil
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 22))
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
                    
                    // Attached document preview
                    if let fileName = viewModel.selectedFileName,
                       let fileExtension = viewModel.selectedFileExtension {
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
                                // X button to remove
                                Button(action: {
                                    viewModel.clearFileAttachment()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22))
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
                            .simultaneousGesture(
                                TapGesture()
                                    .onEnded { _ in
                                        isTextFieldFocused = true
                                        isKeyboardVisible = true
                                    }
                            )
                        
                        // Send or microphone button
                        Button(action: {
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
                        }) {
                            if viewModel.isRateLimited {
                                // Rate limit indicator
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
                                            .font(.system(size: 16))
                                            .foregroundColor(.orange)
                                    }
                                }
                            } else if viewModel.isRecordingVoice {
                                // Enhanced recording animation
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
                                    
                                    // Main button with gradient
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
                                        
                                        // Rotating gradient overlay
                                        Circle()
                                            .fill(
                                                AngularGradient(
                                                    colors: [
                                                        Color.white.opacity(0.3),
                                                        Color.white.opacity(0.0),
                                                        Color.white.opacity(0.1),
                                                        Color.white.opacity(0.0)
                                                    ],
                                                    center: .center
                                                )
                                            )
                                            .frame(width: 36, height: 36)
                                            .rotationEffect(.degrees(pulseAnimation ? 360 : 0))
                                            .animation(
                                                Animation.linear(duration: 3)
                                                    .repeatForever(autoreverses: false),
                                                value: pulseAnimation
                                            )
                                        
                                        // Stop icon with scale animation
                                        Image(systemName: "stop.fill")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .scaleEffect(pulseAnimation ? 1.1 : 0.9)
                                            .animation(
                                                Animation.easeInOut(duration: 0.6)
                                                    .repeatForever(autoreverses: true),
                                                value: pulseAnimation
                                            )
                                    }
                                    .scaleEffect(1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isRecordingVoice)
                                }
                                .onAppear {
                                    withAnimation {
                                        pulseAnimation = true
                                    }
                                }
                                .onDisappear {
                                    pulseAnimation = false
                                }
                            } else {
                                ZStack {
                                    // Enhanced microphone/send button
                                    if text.isEmpty && viewModel.selectedImage == nil && viewModel.selectedFileData == nil {
                                        // Microphone state with subtle glow
                                        ZStack {
                                            // Subtle background circle
                                            Circle()
                                                .fill(Color.secondary.opacity(0.1))
                                                .frame(width: 36, height: 36)
                                            
                                            Image(systemName: "mic.fill")
                                                .font(.system(size: 20, weight: .medium))
                                                .foregroundStyle(
                                                    LinearGradient(
                                                        colors: [Color.secondary, Color.secondary.opacity(0.8)],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                )
                                                .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                                                .animation(
                                                    Animation.easeInOut(duration: 2)
                                                        .repeatForever(autoreverses: true),
                                                    value: pulseAnimation
                                                )
                                        }
                                        .onAppear {
                                            withAnimation(.easeInOut(duration: 2)) {
                                                pulseAnimation = true
                                            }
                                        }
                                    } else {
                                        // Send button state
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 26))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .scaleEffect(1.0)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .overlay(
                                    // Show crown for voice if user is free
                                    Group {
                                        if !subscriptionManager.isPremium && text.isEmpty && viewModel.selectedImage == nil && viewModel.selectedFileData == nil {
                                            Image(systemName: "crown.fill")
                                                .font(.system(size: 10, weight: .bold))
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
                                )
                            }
                        }
                        .accessibilityLabel(viewModel.isRecordingVoice ? "Stop recording" : (text.isEmpty ? "Voice input" : "Send message"))
                        .accessibilityHint(viewModel.isRecordingVoice ? "Stop voice recording" : (text.isEmpty ? "Start voice recording" : "Send the typed message"))
                    }
                    .padding(.horizontal, baseUnit * 1.5)
                    .padding(.vertical, baseUnit)
                }
                .background(
                    RoundedRectangle(cornerRadius: baseUnit * 2.5)
                        .fill(Color(UIColor.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: baseUnit * 2.5)
                                .stroke(borderColor, lineWidth: 1)
                        )
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    // Make text field focused when tapping anywhere on the input container
                    isTextFieldFocused = true
                    isKeyboardVisible = true
                }
            }
            .padding(.horizontal, baseUnit * 2)
            .padding(.vertical, baseUnit)
            .padding(.bottom, isKeyboardVisible ? 0 : 85) // Add padding when tab bar visible
        }
        .sheet(isPresented: $showAttachmentMenu) {
            AttachmentMenuView(viewModel: viewModel)
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: viewModel.inputText) { _, newValue in
            // Sync voice transcription to the text field
            if viewModel.isRecordingVoice {
                text = newValue
            }
        }
        .onChange(of: isTextFieldFocused) { _, newValue in
            // Immediately update keyboard visibility when focus changes
            DispatchQueue.main.async {
                isKeyboardVisible = newValue
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
        .background(Color(.systemBackground))
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
                                .font(.system(size: 24))
                                .foregroundColor(color)
                        )
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                    
                    // Premium badge
                    if showPremium {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12, weight: .bold))
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

#Preview {
    VStack {
        Spacer()
        ChatInputView(text: .constant(""), viewModel: ChatViewModel(), isKeyboardVisible: .constant(false))
    }
    .background(Color(.systemBackground))
}