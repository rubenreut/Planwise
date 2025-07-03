import SwiftUI

// MARK: - Chat Input View

struct ChatInputView: View {
    @Binding var text: String
    @ObservedObject var viewModel: ChatViewModel
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @FocusState private var isTextFieldFocused: Bool
    @State private var showAttachmentMenu = false
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Mathematical Constants
    
    private let φ: Double = 1.618033988749895
    private let baseUnit: Double = 8.0
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.11) : Color(white: 0.97)
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.9)
    }
    
    private var canSendMessage: Bool {
        subscriptionManager.canSendMessage()
    }
    
    private var placeholderText: String {
        if !canSendMessage {
            return "Upgrade to continue chatting"
        }
        return "Message"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Separator
            Rectangle()
                .fill(borderColor)
                .frame(height: 1)
            
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
                .animation(.spring(response: 0.3, dampingFraction: 0.86), value: showAttachmentMenu)
                
                // Text field container
                HStack(spacing: baseUnit) {
                    TextField(placeholderText, text: $text, axis: .vertical)
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .disabled(!canSendMessage)
                        .tracking(-0.2)
                        .textFieldStyle(.plain)
                        .focused($isTextFieldFocused)
                        .lineLimit(1...6)
                        .onSubmit {
                            viewModel.sendMessage()
                        }
                    
                    // Send or microphone button
                    Button(action: {
                        if !canSendMessage {
                            viewModel.showPaywall = true
                        } else if text.isEmpty {
                            viewModel.handleVoiceInput()
                        } else {
                            viewModel.sendMessage()
                        }
                    }) {
                        Image(systemName: text.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(text.isEmpty ? .secondary : .accentColor)
                            .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
                    }
                }
                .padding(.horizontal, baseUnit * 1.5)
                .padding(.vertical, baseUnit)
                .background(
                    RoundedRectangle(cornerRadius: baseUnit * 2.5)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: baseUnit * 2.5)
                                .stroke(borderColor, lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, baseUnit * 2)
            .padding(.vertical, baseUnit)
            .background(backgroundColor)
        }
        .sheet(isPresented: $showAttachmentMenu) {
            AttachmentMenuView(viewModel: viewModel)
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
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
                    color: .blue
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
    let action: () -> Void
    
    @State private var isPressed = false
    private let baseUnit: Double = 8.0
    private let φ: Double = 1.618033988749895
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: baseUnit) {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: baseUnit * 7, height: baseUnit * 7)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundColor(color)
                    )
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                
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

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        ChatInputView(text: .constant(""), viewModel: ChatViewModel())
    }
    .background(Color(.systemBackground))
}