import SwiftUI
import PhotosUI

// MARK: - AI Chat View

struct AIChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dependencyContainer) private var container
    @State private var scrollProxy: ScrollViewProxy?
    
    init() {
        _viewModel = StateObject(wrappedValue: ChatViewModel())
    }
    
    // MARK: - Mathematical Constants
    
    private let φ: Double = 1.618033988749895
    private let baseUnit: Double = 8.0
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.0) : Color(white: 1.0)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: baseUnit) {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(
                                    message: message,
                                    onRetry: message.error != nil ? { viewModel.retryLastMessage() } : nil,
                                    onEventAction: { eventId, action in
                                        viewModel.handleEventAction(eventId: eventId, action: action)
                                    },
                                    onMultiEventAction: { action in
                                        viewModel.handleMultiEventAction(action)
                                    },
                                    onBulkAction: { messageId, action in
                                        viewModel.handleBulkAction(action, for: messageId)
                                    }
                                )
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .push(from: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }
                            
                            // Typing indicator
                            if viewModel.isTypingIndicatorVisible {
                                TypingIndicatorView()
                                    .id("typing-indicator")
                                    .transition(.asymmetric(
                                        insertion: .push(from: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                            
                            // Bottom padding for last message
                            Color.clear
                                .frame(height: baseUnit * 2)
                                .id("bottom-anchor")
                        }
                        .padding(.top, baseUnit)
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                    .onChange(of: viewModel.messages.last?.id) { _, _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                            proxy.scrollTo("bottom-anchor", anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.isTypingIndicatorVisible) { _, isVisible in
                        if isVisible {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                                proxy.scrollTo("typing-indicator", anchor: .bottom)
                            }
                        }
                    }
                    .onTapGesture {
                        // Dismiss keyboard when tapping on the chat area
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                
                // Message limit indicator (for free users)
                if !subscriptionManager.isPremium && subscriptionManager.remainingFreeMessages > 0 {
                    MessageLimitIndicator(remaining: subscriptionManager.remainingFreeMessages) {
                        viewModel.showPaywall = true
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Rate limit warning
                if viewModel.showRateLimitWarning {
                    RateLimitWarningView(rateLimitInfo: viewModel.rateLimitInfo)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Input area
                ChatInputView(text: $viewModel.inputText, viewModel: viewModel)
            }
            .background(backgroundColor)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Momentum Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button(action: {
                    // Show chat options/settings
                }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                }
            )
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
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallView()
        }
    }
}

// MARK: - Rate Limit Warning View

struct RateLimitWarningView: View {
    let rateLimitInfo: RateLimitInfo?
    @Environment(\.colorScheme) private var colorScheme
    private let baseUnit: Double = 8.0
    
    var body: some View {
        HStack(spacing: baseUnit) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Rate Limit Warning")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                if let info = rateLimitInfo {
                    Text("\(info.remaining) of \(info.limit) requests remaining")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let info = rateLimitInfo {
                Text(timeUntilReset(info.resetTime))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, baseUnit * 2)
        .padding(.vertical, baseUnit)
        .background(
            RoundedRectangle(cornerRadius: baseUnit)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: baseUnit)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, baseUnit * 2)
        .padding(.vertical, baseUnit / 2)
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

// MARK: - Typing Indicator View

struct TypingIndicatorView: View {
    @State private var animationPhase = 0.0
    @Environment(\.colorScheme) private var colorScheme
    
    private let baseUnit: Double = 8.0
    private let φ: Double = 1.618033988749895
    
    var body: some View {
        HStack(alignment: .top, spacing: baseUnit) {
            VStack(alignment: .leading, spacing: baseUnit / 2) {
                Text("Momentum Assistant")
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundColor(.secondary)
                    .tracking(-0.2)
                
                HStack(spacing: baseUnit / 2) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: baseUnit, height: baseUnit)
                            .scaleEffect(animationScale(for: index))
                            .opacity(animationOpacity(for: index))
                    }
                }
                .padding(.horizontal, baseUnit * 2)
                .padding(.vertical, baseUnit * φ)
                .background(
                    RoundedRectangle(cornerRadius: baseUnit * 2.5)
                        .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.1),
                            radius: baseUnit / 2,
                            x: 0,
                            y: 2
                        )
                )
            }
            
            Spacer(minLength: baseUnit * 5)
        }
        .padding(.horizontal, baseUnit * 2)
        .padding(.vertical, baseUnit / 2)
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

// MARK: - Message Limit Indicator

struct MessageLimitIndicator: View {
    let remaining: Int
    let onUpgrade: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    private let baseUnit: Double = 8.0
    
    var body: some View {
        HStack(spacing: baseUnit) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
            
            Text("\(remaining) free messages remaining")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: onUpgrade) {
                Text("Upgrade")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, baseUnit * 1.5)
                    .padding(.vertical, baseUnit / 2)
                    .background(Color.accentColor)
                    .cornerRadius(baseUnit)
            }
        }
        .padding(.horizontal, baseUnit * 2)
        .padding(.vertical, baseUnit)
        .background(
            RoundedRectangle(cornerRadius: baseUnit)
                .fill(Color.accentColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: baseUnit)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, baseUnit * 2)
        .padding(.vertical, baseUnit / 2)
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