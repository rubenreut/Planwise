import SwiftUI

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: ChatMessage
    var onRetry: (() -> Void)? = nil
    var onEventAction: ((String, EventAction) -> Void)? = nil
    var onMultiEventAction: ((MultiEventAction) -> Void)? = nil
    var onBulkAction: ((UUID, BulkActionPreview.BulkAction) -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Mathematical Constants
    
    private let φ: Double = 1.618033988749895
    private let baseUnit: Double = 8.0
    
    // MARK: - Computed Properties
    
    private var bubbleColor: Color {
        if message.sender.isUser {
            // User messages use accent color
            return Color.accentColor
        } else {
            // AI messages use secondary background
            return colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95)
        }
    }
    
    private var textColor: Color {
        if message.sender.isUser {
            return .white
        } else {
            return colorScheme == .dark ? .white : .black
        }
    }
    
    private var horizontalPadding: Double {
        baseUnit * 2 // 16px
    }
    
    private var verticalPadding: Double {
        baseUnit * φ // 13px
    }
    
    private var maxWidth: Double {
        return UIScreen.main.bounds.width - (baseUnit * 4) // Full width minus padding for both
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: baseUnit) {
            // Remove spacer to make both user and AI messages full width
            
            VStack(alignment: message.sender.isUser ? .trailing : .leading, spacing: baseUnit / 2) {
                // Show name only for user messages
                if case .user(let name) = message.sender {
                    Text(name)
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundColor(.secondary)
                        .tracking(-0.2)
                }
                
                // Message bubble
                VStack(alignment: .leading, spacing: baseUnit) {
                    // Function call result
                    if let functionCall = message.functionCall {
                        FunctionCallResultView(result: functionCall)
                            .padding(.horizontal, horizontalPadding)
                            .padding(.vertical, verticalPadding)
                    }
                    
                    // Attached image
                    if let image = message.attachedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, verticalPadding)
                            .padding(.bottom, message.content.isEmpty ? verticalPadding : baseUnit / 2)
                    }
                    
                    // Main message content
                    if !message.content.isEmpty {
                        MarkdownText(text: message.content, textColor: textColor)
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, verticalPadding)
                            .padding(.top, message.attachedImage != nil ? 0 : verticalPadding)
                    }
                    
                    // Error state
                    if let error = message.error {
                        HStack(spacing: baseUnit / 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                            
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            if let onRetry = onRetry {
                                Spacer()
                                
                                Button(action: onRetry) {
                                    HStack(spacing: baseUnit / 4) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 12))
                                        Text("Retry")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, baseUnit)
                    }
                    
                    // Rich event preview
                    if let eventPreview = message.eventPreview {
                        EventPreviewView(
                            event: eventPreview,
                            onAction: { action in
                                onEventAction?(eventPreview.id, action)
                            }
                        )
                        .padding(.horizontal, baseUnit)
                        .padding(.bottom, baseUnit)
                    }
                    
                    // Multiple events preview
                    if let multipleEvents = message.multipleEventsPreview {
                        MultipleEventsPreviewView(
                            events: multipleEvents,
                            onAction: { action in
                                onMultiEventAction?(action)
                            }
                        )
                        .padding(.horizontal, baseUnit)
                        .padding(.bottom, baseUnit)
                    }
                    
                    // Bulk action preview
                    if let bulkActionPreview = message.bulkActionPreview {
                        BulkActionPreviewView(
                            preview: bulkActionPreview,
                            onAction: { action in
                                onBulkAction?(message.id, action)
                            }
                        )
                        .padding(.horizontal, baseUnit)
                        .padding(.bottom, baseUnit)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: baseUnit * 2.5) // 20px
                        .fill(bubbleColor)
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.1),
                            radius: baseUnit / 2,
                            x: 0,
                            y: 2
                        )
                )
                .frame(maxWidth: maxWidth, alignment: message.sender.isUser ? .trailing : .leading)
                
                // Streaming indicator
                if message.isStreaming {
                    StreamingIndicator()
                        .padding(.horizontal, baseUnit)
                }
            }
            
            // Remove spacer for AI messages to make them full width
        }
        .padding(.horizontal, baseUnit * 2) // 16px
        .padding(.vertical, baseUnit / 2) // 4px
    }
}

// MARK: - Markdown Text View

struct MarkdownText: View {
    let text: String
    let textColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(text.components(separatedBy: "\n\n").indices, id: \.self) { index in
                let paragraph = text.components(separatedBy: "\n\n")[index]
                if !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if let attributedString = try? AttributedString(markdown: paragraph) {
                        Text(attributedString)
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .foregroundColor(textColor)
                            .tracking(-0.2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        // Fallback for each paragraph
                        Text(processSimpleMarkdown(paragraph))
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .foregroundColor(textColor)
                            .tracking(-0.2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
    
    private func processSimpleMarkdown(_ text: String) -> String {
        var result = text
        
        // Remove bold markers
        result = result.replacingOccurrences(of: "**", with: "")
        
        // Remove italic markers
        result = result.replacingOccurrences(of: "*", with: "")
        
        // Remove code markers
        result = result.replacingOccurrences(of: "`", with: "")
        
        // Remove headers
        result = result.replacingOccurrences(of: "### ", with: "")
        result = result.replacingOccurrences(of: "## ", with: "")
        result = result.replacingOccurrences(of: "# ", with: "")
        
        return result
    }
}

// MARK: - Streaming Indicator

struct StreamingIndicator: View {
    @State private var isAnimating = false
    private let baseUnit: Double = 8.0
    
    var body: some View {
        HStack(spacing: baseUnit / 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Function Call Result View

struct FunctionCallResultView: View {
    let result: FunctionCallResult
    @Environment(\.colorScheme) private var colorScheme
    private let baseUnit: Double = 8.0
    
    var iconName: String {
        switch result.functionName {
        case "create_event":
            return "plus.circle.fill"
        case "update_event":
            return "pencil.circle.fill"
        case "delete_event":
            return "trash.circle.fill"
        case "list_events":
            return "list.bullet.circle.fill"
        case "suggest_schedule":
            return "lightbulb.circle.fill"
        default:
            return "gear.circle.fill"
        }
    }
    
    var iconColor: Color {
        result.success ? .green : .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: baseUnit / 2) {
            HStack(spacing: baseUnit / 2) {
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                
                Text(result.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if result.success {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
            }
            
            Text(result.message)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            if let details = result.details {
                ForEach(Array(details.keys.sorted()), id: \.self) { key in
                    HStack(spacing: baseUnit / 2) {
                        Text("\(key):")
                            .font(.system(size: 12))
                            .foregroundColor(Color.secondary.opacity(0.7))
                        Text(details[key] ?? "")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(baseUnit)
        .background(
            RoundedRectangle(cornerRadius: baseUnit)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        MessageBubbleView(
            message: ChatMessage(
                content: "How can I better manage my time today?",
                sender: .user(name: "Ruben"),
                timestamp: Date()
            )
        )
        
        MessageBubbleView(
            message: ChatMessage(
                content: "Based on your schedule, I recommend time-blocking your morning for deep work. You have a 2-hour window from 9-11 AM that would be perfect for focused tasks.",
                sender: .assistant,
                timestamp: Date()
            )
        )
        
        MessageBubbleView(
            message: ChatMessage(
                content: "I've created a new event for you:",
                sender: .assistant,
                timestamp: Date(),
                functionCall: FunctionCallResult(
                    functionName: "create_event",
                    success: true,
                    message: "Deep Work Session",
                    details: ["Time": "9:00 AM - 11:00 AM", "Category": "Work"]
                )
            )
        )
        
        MessageBubbleView(
            message: ChatMessage(
                content: "Analyzing your productivity patterns...",
                sender: .assistant,
                timestamp: Date(),
                isStreaming: true
            )
        )
        
        MessageBubbleView(
            message: ChatMessage(
                content: "",
                sender: .assistant,
                timestamp: Date(),
                error: "Rate limit exceeded. Please try again in 60 seconds."
            )
        )
    }
    .background(Color(.systemBackground))
}